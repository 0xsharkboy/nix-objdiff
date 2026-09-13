{
  lib,
  testers,
  objdiff-gui,
  fixture,
  backend,
}:
testers.runNixOSTest {
  name = "objdiff-${backend}";
  enableOCR = true;
  requiredFeatures.kvm = false;
  qemu.forceAccel = false;
  nodes.machine = { pkgs, ... }: {
    virtualisation = {
      memorySize = 4096;
      cores = 2;
      qemu.options = [
        "-machine accel=tcg"
      ]
      ++ lib.optionals (backend == "wayland") [ "-vga none -device virtio-gpu-pci" ];
    };
    users.users.alice = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [ "video" ];
    };
    services.getty.autologinUser = lib.mkIf (backend == "wayland") "alice";
    hardware.graphics.enable = true;
    fonts.packages = [ pkgs.dejavu_fonts ];
    environment.systemPackages = [
      objdiff-gui
      pkgs.jq
      pkgs.xdotool
    ];
    environment.variables = {
      LIBGL_ALWAYS_SOFTWARE = "1";
      WLR_RENDERER = "pixman";
      SWAYSOCK = "/tmp/sway-ipc.sock";
    };
    systemd.tmpfiles.rules = [ "C /home/alice/project - alice users - ${fixture}" ];
    programs.sway.enable = backend == "wayland";
    programs.bash.loginShellInit = lib.optionalString (backend == "wayland") ''
      if [ "$(tty)" = /dev/tty1 ]; then
        exec sway --config /etc/sway-test.conf
      fi
    '';
    environment.etc."sway-test.conf".text = ''
      output * resolution 1280x800
      exec env -u DISPLAY objdiff -p /home/alice/project > /tmp/objdiff.log 2>&1
    '';
    services.xserver = lib.mkIf (backend == "x11") {
      enable = true;
      windowManager.icewm.enable = true;
      displayManager.sessionCommands = ''
        env -u WAYLAND_DISPLAY objdiff -p /home/alice/project > /tmp/objdiff.log 2>&1 &
      '';
    };
    services.displayManager = lib.mkIf (backend == "x11") {
      autoLogin = {
        enable = true;
        user = "alice";
      };
      defaultSession = "none+icewm";
    };
  };
  testScript = ''
    import datetime
    import shlex

    startup_timeout = datetime.timedelta(minutes=5)
    start_all()
    try:
        machine.wait_for_unit("multi-user.target")
        if "${backend}" == "wayland":
            machine.wait_for_file("/tmp/sway-ipc.sock")
            query = "swaymsg -t get_tree | jq -e '.. | objects | select(.app_id? == \"objdiff\")'"
            machine.wait_until_succeeds("su - alice -c " + shlex.quote(query), timeout=startup_timeout)
        else:
            machine.wait_for_x()
            machine.wait_until_succeeds("DISPLAY=:0 XAUTHORITY=/home/alice/.Xauthority xdotool search --onlyvisible --class objdiff", timeout=startup_timeout)
        machine.wait_for_text("example", timeout=startup_timeout)
        machine.screenshot("objdiff-${backend}")
        machine.fail("grep -E 'panicked at|Failed to launch application' /tmp/objdiff.log")
    finally:
        machine.execute("cat /tmp/objdiff.log >&2")
        machine.screenshot("objdiff-${backend}-final")
        machine.copy_from_machine("/tmp/objdiff.log")
  '';
}
