#!/usr/bin/env python3
"""Prepare and validate updates in isolation before changing repository files."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
METADATA = Path("pkgs/objdiff/source.json")
FAKE_HASH = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="


def run(*args, cwd=None):
    return subprocess.run(args, cwd=cwd, text=True, check=True, capture_output=True).stdout


def github(path):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "nix-objdiff-updater"}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(f"https://api.github.com/repos/encounter/objdiff/{path}", headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def release_version(release):
    tag = release["tag_name"]
    if release.get("draft") or release.get("prerelease") or not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError(f"Not a stable release: {tag}")
    return tag[1:]


def write_metadata(root, data):
    (root / METADATA).write_text(json.dumps(data, indent=2) + "\n")


def update_objdiff(candidate):
    old = json.loads((candidate / METADATA).read_text())
    release = github("releases/latest")
    version = release_version(release)
    if version == old["version"]:
        return False
    if tuple(map(int, version.split("."))) < tuple(map(int, old["version"].split("."))):
        raise ValueError("Refusing to downgrade objdiff")
    ref = github(f"git/ref/tags/v{version}")["object"]
    while ref["type"] == "tag":
        ref = github(f"git/tags/{ref['sha']}")["object"]
    if ref["type"] != "commit" or not re.fullmatch(r"[0-9a-f]{40}", ref["sha"]):
        raise ValueError("Release tag does not resolve to a commit")
    revision = ref["sha"]
    source = json.loads(run("nix", "store", "prefetch-file", "--unpack", "--json",
                            f"https://github.com/encounter/objdiff/archive/{revision}.tar.gz"))
    new = {"version": version, "rev": revision, "hash": source["hash"], "cargoHash": FAKE_HASH}
    write_metadata(candidate, new)
    expression = f'(builtins.getFlake {json.dumps("path:" + str(candidate))}).packages.x86_64-linux.objdiff-cli.cargoDeps'
    try:
        run("nix", "build", "--impure", "--no-link", "--expr", expression)
    except subprocess.CalledProcessError as error:
        matches = re.findall(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", error.stderr)
        if len(matches) != 1 or "hash mismatch" not in error.stderr:
            raise
        new["cargoHash"] = matches[0]
    else:
        raise RuntimeError("Expected a Cargo dependency hash mismatch")
    write_metadata(candidate, new)
    # Verify the derived hash before accepting it.
    run("nix", "build", "--impure", "--no-link", "--expr", expression)
    return True


def prepare(root, kind, dry_run=False):
    with tempfile.TemporaryDirectory(prefix="nix-objdiff-update-") as directory:
        candidate = Path(directory) / "repository"
        shutil.copytree(root, candidate, ignore=shutil.ignore_patterns(
            ".git", "result", "result-*", ".act-artifacts", ".act.env", ".act.secrets", "__pycache__"))
        if kind == "objdiff":
            changed = update_objdiff(candidate)
            relative = METADATA
        else:
            relative = Path("flake.lock")
            run("nix", "flake", "update", "nixpkgs", "--flake", f"path:{candidate}")
            changed = (candidate / relative).read_bytes() != (root / relative).read_bytes()
        if not changed:
            print(f"{kind} is already up to date.")
            return False
        print(f"Validating {kind} candidate...", flush=True)
        subprocess.run(["bash", "scripts/check.sh", f"path:{candidate}"], cwd=candidate, check=True)
        print((candidate / relative).read_text())
        if dry_run:
            print("Dry run: candidate validated; repository unchanged.")
        else:
            temporary = root / relative.with_suffix(".tmp")
            temporary.write_bytes((candidate / relative).read_bytes())
            temporary.replace(root / relative)
        return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=["objdiff", "nixpkgs"])
    parser.add_argument("--dry-run", action="store_true", help="Validate without modifying repository files")
    args = parser.parse_args()
    try:
        prepare(ROOT, args.kind, args.dry_run)
    except subprocess.CalledProcessError as error:
        if error.stdout:
            print(error.stdout)
        if error.stderr:
            print(error.stderr)
        raise SystemExit(error.returncode) from error


if __name__ == "__main__":
    main()
