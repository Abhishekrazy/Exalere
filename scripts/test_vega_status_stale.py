"""The ledger's own honesty check.

A blocker reason is a claim about a moment, not a permanent fact — rounds 59 and
63 both found sites that had come back. The status script therefore names probe
records older than its staleness window, and `--strict-stale` turns that into a
failing exit so a scheduled run can act on it.

Run: python scripts/test_vega_status_stale.py
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "scripts", "vega_status.py")


class StaleProbeReport(unittest.TestCase):
    def run_status(self, blockers_path, out_path, *extra):
        env = dict(os.environ)
        env["VEGA_BLOCKERS"] = blockers_path
        env["VEGA_STATUS_OUT"] = out_path
        return subprocess.run(
            [sys.executable, SCRIPT, *extra],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )

    def load_ledger(self):
        """The real ledger: every blocked provider must stay recorded, so the
        staleness rule is exercised by ageing one entry rather than dropping the
        rest (which the script's completeness guard would reject)."""
        with open(os.path.join(ROOT, "docs", "vega-blockers.json"), encoding="utf-8") as handle:
            return json.load(handle)

    def age(self, ledger, provider_id, checked):
        ledger["providers"][provider_id]["checked"] = checked

    def test_an_old_probe_is_named_and_can_fail_the_run(self):
        blockers = self.load_ledger()
        self.age(blockers, "flixhq", "2020-01-01")
        with tempfile.TemporaryDirectory() as tmp:
            blockers_path = os.path.join(tmp, "blockers.json")
            out_path = os.path.join(tmp, "status.md")
            with open(blockers_path, "w", encoding="utf-8") as handle:
                json.dump(blockers, handle)

            result = self.run_status(blockers_path, out_path)
            self.assertEqual(result.returncode, 0, result.stderr)
            with open(out_path, encoding="utf-8") as handle:
                doc = handle.read()
            self.assertIn("Probes due for another look", doc)
            self.assertIn("flixhq", doc)

            strict = self.run_status(blockers_path, out_path, "--strict-stale")
            self.assertEqual(strict.returncode, 4, strict.stderr)

    def test_a_fresh_probe_is_not_named(self):
        blockers = self.load_ledger()
        for entry in blockers["providers"].values():
            entry["checked"] = "2999-01-01"
        with tempfile.TemporaryDirectory() as tmp:
            blockers_path = os.path.join(tmp, "blockers.json")
            out_path = os.path.join(tmp, "status.md")
            with open(blockers_path, "w", encoding="utf-8") as handle:
                json.dump(blockers, handle)

            result = self.run_status(blockers_path, out_path, "--strict-stale")
            self.assertEqual(result.returncode, 0, result.stderr)
            with open(out_path, encoding="utf-8") as handle:
                self.assertNotIn("Probes due for another look", handle.read())


if __name__ == "__main__":
    unittest.main()
