# nix-objdiff

Reproducible Nix packages for [objdiff](https://github.com/encounter/objdiff),
an object-file comparison tool for decompilation projects.

This repository builds stable releases from source for **NixOS on x86_64**.
It provides independent CLI and GUI packages, a flake, and an overlay.
The GUI supports Wayland and X11 and installs a menu launcher and icon.

## Quick start

After this repository is published:

```sh
nix run github:0xsharkboy/nix-objdiff             # GUI: objdiff
nix run github:0xsharkboy/nix-objdiff#objdiff-cli -- --help
nix build github:0xsharkboy/nix-objdiff#objdiff-gui
```

From a local checkout, use `nix run path:.` or
`nix run path:.#objdiff-cli -- --help`. The `path:` form also works before the
initial commit. Both packages may be installed together.

## Add to a flake configuration

Add the input alongside your existing inputs:

```nix
inputs.objdiff.url = "github:0xsharkboy/nix-objdiff";
```

Pass `inputs` to your NixOS modules using `specialArgs = { inherit inputs; };`,
then install either or both packages:

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.objdiff.packages.${pkgs.stdenv.hostPlatform.system}.objdiff-cli
    inputs.objdiff.packages.${pkgs.stdenv.hostPlatform.system}.objdiff-gui
  ];
}
```

For Home Manager, pass `inputs` through `extraSpecialArgs` and use the same
package list in `home.packages`.

Alternatively, install the overlay in the package set consumed by your modules:

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.objdiff.overlays.default ];
  environment.systemPackages = [ pkgs.objdiff-cli pkgs.objdiff-gui ];
}
```

The overlay uses the consuming nixpkgs, including its Rust toolchain. Direct
flake packages use this repository's locked `nixos-unstable`. To share your
configuration's nixpkgs when using direct packages, you can add:

```nix
inputs.objdiff.inputs.nixpkgs.follows = "nixpkgs";
```

Only the committed nixpkgs revision is validated. A different revision may
need a newer Rust compiler or updated package attributes. For standalone
`callPackage` use, the entry point is `pkgs/objdiff` with `gui = true` or `false`.

## Desktop and project requirements

- Enable graphics support in your NixOS configuration. The package supplies
  userspace runtime dependencies; the system supplies the GPU drivers.
- File dialogs use desktop portals. Enable `xdg.portal` with a backend suitable
  for your desktop, including a file chooser implementation. The package does
  not configure system services or select a portal backend for you.
- Run objdiff inside the development environment that supplies your project's
  compiler, `make`/`ninja`, and other build tools. They are not bundled into objdiff.
- GUI preferences remain in the upstream application configuration locations.
  This package does not migrate or overwrite existing preferences.
- Integrated update checks and executable replacement are disabled by a small
  downstream patch, including when old preferences enable them. Update your
  flake input and rebuild your configuration instead:

  ```sh
  nix flake update objdiff
  ```

## Development and validation

```sh
nix develop path:.
nixfmt flake.nix pkgs/objdiff/default.nix tests/*.nix
bash scripts/check.sh
```

`nix flake check path:.` builds both packages, runs upstream CLI/GUI/core tests,
checks packaging and a generated C-object comparison, tests updater failures,
checks Nix formatting, and runs X11 and Wayland NixOS VM tests. The check script
also runs Actionlint and ShellCheck.

After the initial Git commit, `nix fmt` formats the repository using the flake's
`nixfmt-tree` formatter.

The graphical tests require an actual mapped window and visible fixture project,
not just a live process. They use software rendering and force QEMU emulation
without KVM. Initial builds and emulated VM boots can be slow. Use the named
checks to investigate failures:

```sh
nix build path:.#checks.x86_64-linux.packaging -L
nix build path:.#checks.x86_64-linux.gui-x11 -L --keep-failed
nix build path:.#checks.x86_64-linux.gui-wayland -L --keep-failed
```

See [local workflow testing](docs/validation.md) for `act` commands,
diagnostics, and the manual desktop acceptance checklist.

## Updates

GitHub Actions checks weekly on Monday at 06:00 UTC and supports manual dispatch.
Objdiff release updates and nixpkgs lock updates use separate branches and PRs.
PRs are never merged automatically. The updater validates a temporary checkout
before replacing local metadata, and leaves the repository unchanged on failure.

```sh
nix develop path:. --command python3 scripts/update.py objdiff --dry-run
nix develop path:. --command python3 scripts/update.py nixpkgs --dry-run
# Remove --dry-run to apply a successfully validated update locally.
```

The unchanged-version path does not rebuild. Stable release tags resolve to an
immutable commit; source and Cargo hashes are updated together. Release downloads,
hash calculation, and validation must all succeed before metadata is replaced.
An incompatible upstream change requires a manual packaging/patch adjustment.

Enable GitHub Actions and **Allow GitHub Actions to create and approve pull
requests** in the repository's Actions settings after publication. The workflow
uses `GITHUB_TOKEN`; no PAT or Cachix account is required. Preparation has read
permissions; only the separate PR publication job has write permissions.

Candidate validation happens before PR creation because PRs created with the
default token may not trigger another workflow run. Review the update run's
results before merging. Action revisions are pinned and updated by Dependabot.

## Scope and contribution

Keep all repository documentation, comments, scripts, and workflow messages in English.

There is no macOS, ARM, non-NixOS Linux, development-snapshot, or public binary
cache support in v1. There are no NixOS or Home Manager modules to configure.
The expressions use `buildRustPackage` and `callPackage` to make a future nixpkgs
submission straightforward. Submission, nixpkgs maintainer registration, and any
upstream patch discussion are separate work.

Original packaging code is [MIT licensed](LICENSE). Objdiff and its reused icons
and patched source retain their upstream MIT OR Apache-2.0 licensing.
