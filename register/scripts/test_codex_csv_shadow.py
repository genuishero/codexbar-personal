#!/usr/bin/env python3

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


HELPER_PATH = Path(__file__).with_name("codex_csv_shadow.sh")
STATE_HELPER_PATH = Path(__file__).with_name("codex_csv_state.py")


class CodexCSVShadowTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.csv_path = Path(self.tempdir.name) / "codex.csv"
        self.shadow_path = Path(self.tempdir.name) / "shadow.csv"
        self.snapshot_dir = Path(self.tempdir.name) / "snapshots"
        self.csv_path.write_text(
            "schema_version,email,password,status,url,auth_method,phase,failure_category,manual_action,retry_count,updated_at\n"
            "v2,seed@example.com,secret,completed,,password,register,,none,0,2026-04-09T00:00:00+00:00\n",
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def run_helper(self, script: str) -> None:
        env = dict(os.environ)
        env["CODEX_CSV_SHADOW_PATH"] = str(self.shadow_path)
        env["CODEX_CSV_SNAPSHOT_DIR"] = str(self.snapshot_dir)
        subprocess.run(
            ["bash", "-lc", script],
            check=True,
            text=True,
            env=env,
        )

    def test_shadow_sync_and_restore_round_trip(self) -> None:
        self.run_helper(
            f'''
set -euo pipefail
source "{HELPER_PATH}"
codex_csv_sync_shadow "{self.csv_path}"
rm "{self.csv_path}"
codex_csv_begin_mutation "{self.csv_path}"
python3 "{STATE_HELPER_PATH}" ensure "{self.csv_path}" >/dev/null
'''
        )

        restored = self.csv_path.read_text(encoding="utf-8")
        self.assertIn("seed@example.com", restored)
        self.assertTrue(self.shadow_path.exists())
        self.assertIn("seed@example.com", self.shadow_path.read_text(encoding="utf-8"))

        self.csv_path.write_text(
            "schema_version,email,password,status,url,auth_method,phase,failure_category,manual_action,retry_count,updated_at\n"
            "v2,updated@example.com,secret,completed,,password,import,,none,0,2026-04-09T00:00:00+00:00\n",
            encoding="utf-8",
        )
        self.run_helper(
            f'''
set -euo pipefail
source "{HELPER_PATH}"
codex_csv_sync_shadow "{self.csv_path}"
'''
        )

        shadow = self.shadow_path.read_text(encoding="utf-8")
        self.assertIn("updated@example.com", shadow)
        self.assertNotIn("seed@example.com", shadow)


if __name__ == "__main__":
    unittest.main()
