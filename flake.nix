{
  description = "Reproducible objdiff CLI and GUI packages for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      overlay = final: prev: {
        objdiff-cli = final.callPackage ./pkgs/objdiff { gui = false; };
        objdiff-gui = final.callPackage ./pkgs/objdiff { gui = true; };
      };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay ];
      };
      fixture = pkgs.callPackage ./tests/fixture.nix { };
    in
    {
      overlays.default = overlay;
      packages.${system} = {
        inherit (pkgs) objdiff-cli objdiff-gui;
        default = pkgs.objdiff-gui;
      };
      apps.${system} = {
        objdiff-cli = {
          type = "app";
          program = "${pkgs.objdiff-cli}/bin/objdiff-cli";
        };
        objdiff-gui = {
          type = "app";
          program = "${pkgs.objdiff-gui}/bin/objdiff";
        };
        default = self.apps.${system}.objdiff-gui;
      };
      checks.${system} = {
        inherit (pkgs) objdiff-cli objdiff-gui;
        packaging = pkgs.callPackage ./tests/packaging.nix { inherit fixture; };
        gui-x11 = pkgs.callPackage ./tests/gui.nix {
          inherit fixture;
          backend = "x11";
        };
        gui-wayland = pkgs.callPackage ./tests/gui.nix {
          inherit fixture;
          backend = "wayland";
        };
        formatting = pkgs.runCommand "formatting" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
          nixfmt --check ${./flake.nix} ${./pkgs/objdiff/default.nix} ${./tests/fixture.nix} ${./tests/packaging.nix} ${./tests/gui.nix}
          touch $out
        '';
        update-tests = pkgs.runCommand "update-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          cp -r ${./scripts} scripts
          python3 -m unittest discover -s scripts -p 'test_*.py' -v
          touch $out
        '';
      };
      formatter.${system} = pkgs.nixfmt-tree;
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          python3
          jq
          git
          curl
          act
          actionlint
          shellcheck
        ];
      };
    };
}
