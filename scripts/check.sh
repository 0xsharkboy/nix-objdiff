#!/usr/bin/env bash
set -euo pipefail

flake=${1:-path:.}
nix flake check --print-build-logs "$flake"
nix develop "$flake" --command actionlint .github/workflows/*.yml
nix develop "$flake" --command shellcheck scripts/*.sh
