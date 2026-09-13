#!/usr/bin/env bash
set -euo pipefail

# These SDKs are unused: all build and VM dependencies come from Nix.
# Never clean a developer machine, an act container, or a self-hosted runner.
if [[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted && ${ACT:-} != true ]]; then
  echo 'Disk space before removing unused hosted-runner SDKs:'
  df -h / "${RUNNER_TEMP:-/tmp}"
  sudo rm -rf -- \
    /usr/local/lib/android \
    /usr/share/dotnet \
    /usr/share/swift \
    /usr/local/.ghcup \
    /opt/hostedtoolcache/CodeQL
else
  echo 'Skipping SDK cleanup outside GitHub-hosted Actions.'
fi

echo 'Disk space available for Nix builds:'
df -h / "${RUNNER_TEMP:-/tmp}"
