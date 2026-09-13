#!/usr/bin/env bash
set -euo pipefail

mkdir -p .act-artifacts/vm
# Nix retains failed builds when keep-failed is enabled in the workflow.
# Copy only test diagnostics, never the build environment or arbitrary files.
while IFS= read -r -d '' file; do
  relative=${file#/tmp/}
  destination=".act-artifacts/vm/$relative"
  mkdir -p "$(dirname "$destination")"
  cp "$file" "$destination"
done < <(find /tmp -path '*nix-build-*' -type f \
  \( -name '*.png' -o -name 'objdiff.log' -o -name 'log.xml' \) -print0 2>/dev/null)
