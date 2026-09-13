{
  runCommand,
  objdiff-cli,
  objdiff-gui,
  fixture,
  jq,
  desktop-file-utils,
  binutils,
  buildEnv,
}:
let
  combined = buildEnv {
    name = "objdiff-both";
    paths = [
      objdiff-cli
      objdiff-gui
    ];
  };
in
runCommand "objdiff-packaging"
  {
    nativeBuildInputs = [
      objdiff-cli
      objdiff-gui
      jq
      desktop-file-utils
      binutils
    ];
  }
  ''
    export HOME=$TMPDIR/home
    mkdir -p "$HOME" $out
    objdiff-cli --help > $out/cli-help.txt
    objdiff-cli --version | grep -F '${objdiff-cli.version}'
    objdiff --help > $out/gui-help.txt
    objdiff --version | grep -F '${objdiff-gui.version}'
    test -x ${combined}/bin/objdiff
    test -x ${combined}/bin/objdiff-cli
    desktop-file-validate ${objdiff-gui}/share/applications/objdiff.desktop
    test -s ${objdiff-gui}/share/icons/hicolor/64x64/apps/objdiff.png
    strings ${objdiff-gui}/bin/.objdiff-wrapped | grep -F 'Update this application through Nix.'
    cp -r ${fixture} project
    chmod -R u+w project
    objdiff-cli report generate -p project -o $out/identical.json
    jq -e '.measures.fuzzy_match_percent == 100 and (.units | length == 1)' $out/identical.json
    cp project/changed.o project/base.o
    objdiff-cli report generate -p project -o $out/changed.json
    jq -e '.measures.fuzzy_match_percent < 100' $out/changed.json
  ''
