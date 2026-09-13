import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import update


class UpdateTests(unittest.TestCase):
    def test_rejects_prerelease(self):
        for release in [
            {"tag_name": "v4.0.0-rc.1"},
            {"tag_name": "v4.0.0", "prerelease": True},
            {"tag_name": "v4.0.0", "draft": True},
        ]:
            with self.assertRaises(ValueError):
                update.release_version(release)

    def repository(self, directory):
        root = Path(directory)
        (root / update.METADATA).parent.mkdir(parents=True)
        update.write_metadata(root, {"version": "3.8.1", "rev": "a" * 40,
                                     "hash": "source", "cargoHash": "cargo"})
        return root

    def test_unchanged_release_does_not_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.repository(directory)
            with patch.object(update, "github", return_value={"tag_name": "v3.8.1"}), \
                 patch.object(update, "run") as run:
                self.assertFalse(update.prepare(root, "objdiff"))
                run.assert_not_called()

    def test_failed_update_preserves_original(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.repository(directory)
            original = (root / update.METADATA).read_bytes()
            def fail(candidate):
                update.write_metadata(candidate, {"version": "broken"})
                raise RuntimeError("download failed")
            with patch.object(update, "update_objdiff", side_effect=fail):
                with self.assertRaises(RuntimeError):
                    update.prepare(root, "objdiff")
            self.assertEqual((root / update.METADATA).read_bytes(), original)

    def test_release_hashes_are_verified_together(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.repository(directory)
            cargo_hash = "sha256-" + "B" * 43 + "="
            responses = [
                {"tag_name": "v3.8.2"},
                {"object": {"type": "tag", "sha": "b" * 40}},
                {"object": {"type": "commit", "sha": "c" * 40}},
            ]
            mismatch = subprocess.CalledProcessError(
                1, "nix", stderr=f"error: hash mismatch\n got: {cargo_hash}\n")
            with patch.object(update, "github", side_effect=responses), \
                 patch.object(update, "run", side_effect=[json.dumps({"hash": "source-hash"}), mismatch, ""]) as run:
                self.assertTrue(update.update_objdiff(root))
            self.assertEqual(run.call_count, 3)
            self.assertEqual(json.loads((root / update.METADATA).read_text()), {
                "version": "3.8.2", "rev": "c" * 40,
                "hash": "source-hash", "cargoHash": cargo_hash,
            })

    def test_network_failure_is_not_a_vendor_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.repository(directory)
            responses = [{"tag_name": "v3.8.2"},
                         {"object": {"type": "commit", "sha": "c" * 40}}]
            failure = subprocess.CalledProcessError(1, "nix", stderr="connection failed")
            with patch.object(update, "github", side_effect=responses), \
                 patch.object(update, "run", side_effect=[json.dumps({"hash": "source"}), failure]):
                with self.assertRaises(subprocess.CalledProcessError):
                    update.update_objdiff(root)

    def test_validation_failure_and_dry_run_preserve_original(self):
        for dry_run, failure in [(False, True), (True, False), (False, False)]:
            with self.subTest(dry_run=dry_run, failure=failure), tempfile.TemporaryDirectory() as directory:
                root = self.repository(directory)
                original = (root / update.METADATA).read_bytes()
                def change(candidate):
                    update.write_metadata(candidate, {"version": "3.8.2"})
                    return True
                error = subprocess.CalledProcessError(1, "check") if failure else None
                with patch.object(update, "update_objdiff", side_effect=change), \
                     patch.object(update.subprocess, "run", side_effect=error):
                    if failure:
                        with self.assertRaises(subprocess.CalledProcessError):
                            update.prepare(root, "objdiff", dry_run)
                    else:
                        self.assertTrue(update.prepare(root, "objdiff", dry_run))
                if dry_run or failure:
                    self.assertEqual((root / update.METADATA).read_bytes(), original)
                else:
                    self.assertEqual(json.loads((root / update.METADATA).read_text())["version"], "3.8.2")


if __name__ == "__main__":
    unittest.main()
