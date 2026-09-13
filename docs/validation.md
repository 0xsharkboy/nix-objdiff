# Validation

## Run workflows locally with act

Requirements: Docker, `act`, network access for GitHub/Nix/Cargo downloads, and
enough disk space for two Rust builds and NixOS VM closures. `nix develop` supplies
`act`; Docker must already be available on the host.

The build workflows remove unused preinstalled SDKs on GitHub-hosted runners
before installing Nix to leave room for Rust builds and VM closures. This cleanup
is skipped under `act` and on self-hosted runners. Local runs use the available
Docker disk space and do not reproduce GitHub-hosted disk limits.

Use an ordinary Git checkout with an initial commit so `act` can resolve HEAD.
The runner image is `catthehacker/ubuntu:act-24.04` on `linux/amd64`.

```sh
act push -W .github/workflows/check.yml \
  -P ubuntu-24.04=catthehacker/ubuntu:act-24.04 \
  --container-architecture linux/amd64 \
  --privileged --container-options '--device=/dev/net/tun' \
  --artifact-server-path /tmp/objdiff-act-artifacts \
  --env-file /dev/null --secret-file /dev/null

act workflow_dispatch -W .github/workflows/update.yml \
  --input dry_run=true \
  -P ubuntu-24.04=catthehacker/ubuntu:act-24.04 \
  --container-architecture linux/amd64 \
  --privileged --container-options '--device=/dev/net/tun' \
  --artifact-server-path /tmp/objdiff-act-artifacts \
  --env-file /dev/null --secret-file /dev/null
```

The privileged container supports the Nix sandbox and VM test infrastructure.
The tests force TCG emulation; `/dev/net/tun` is exposed for the VM network infrastructure.
OCR can take several minutes after the application window appears, particularly
in the X11 test; allow the visual assertion to finish.
No host Nix store or personal credentials are mounted by these commands.
Update preparation forces dry-run behavior under `act`, and publication steps
are skipped even if a caller forgets the dry-run input.

The artifact server collects workflow logs and available VM diagnostics.
Failed builds are retained, and the diagnostic script extracts screenshots,
application logs, and test-driver XML from their temporary build directories.
Successful VM test outputs also contain screenshots and application logs.

`act` validates local execution, not GitHub's cron scheduler, token permissions,
branch protection, or PR creation. After publication, run the Check workflow and
dispatch Update first in dry-run mode, then with publication enabled. Confirm
that unchanged inputs produce no PR and a real candidate produces the expected
dedicated update branch.

## Manual desktop acceptance

Run on NixOS x86_64 with the actual GPU and desktop session:

- Launch the GUI from the terminal and installed menu entry.
- Open a project using the file dialog and select an object.
- Confirm that functions and differences render correctly.
- Change a source file and verify rebuilding and comparison refresh.
- Confirm preferences persist after restarting.
- Confirm update controls display guidance to update through Nix.

These checks cover GPU drivers, portals, and project toolchains that software
rendering in a VM does not establish. Testing Wayland on a real desktop does not
establish real-desktop X11 acceptance.
