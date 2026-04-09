#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("summarize_import_observations.py")


class ObservationSummaryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.import_log = Path(self.tempdir.name) / "import.jsonl"
        self.register_log = Path(self.tempdir.name) / "register.jsonl"

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def write_records(self, path: Path, records: list[dict]) -> None:
        with path.open("w", encoding="utf-8") as fh:
            for record in records:
                fh.write(json.dumps(record, ensure_ascii=False) + "\n")

    def test_summary_counts_register_and_import_records_and_redacts_detail(self) -> None:
        self.write_records(
            self.register_log,
            [
                {
                    "timestamp": "2026-04-09T10:00:00+00:00",
                    "phase": "register",
                    "outcome": "manual_required",
                    "email": "otp@example.com",
                    "workflow_status": "manual_required",
                    "auth_method": "email_otp",
                    "failure_category": "captcha_challenge",
                    "manual_action": "complete_provider_challenge",
                    "detail": "redirected to https://auth.openai.com/u/login?code=abc123 and mail code 123456",
                }
            ],
        )
        self.write_records(
            self.import_log,
            [
                {
                    "timestamp": "2026-04-09T10:01:00+00:00",
                    "phase": "import",
                    "outcome": "failure",
                    "email": "pwd@example.com",
                    "workflow_status": "retryable_failure",
                    "auth_method": "password",
                    "category": "cdp_race",
                    "manual_action": "retry_after_local_fix",
                    "detail": "access_token=secret retry at https://localhost/callback?code=qwe",
                }
            ],
        )

        env = dict(os.environ)
        env["REGISTER_OBSERVATION_LOG"] = str(self.register_log)
        env["IMPORT_OBSERVATION_LOG"] = str(self.import_log)
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH)],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )

        stdout = result.stdout
        self.assertIn("record_count=2", stdout)
        self.assertIn("failure_records=2", stdout)
        self.assertIn("phase_register=1", stdout)
        self.assertIn("phase_import=1", stdout)
        self.assertIn("auth_method_email_otp=1", stdout)
        self.assertIn("auth_method_password=1", stdout)
        self.assertIn("captcha_challenge=1", stdout)
        self.assertIn("cdp_race=1", stdout)
        self.assertNotIn("https://auth.openai.com", stdout)
        self.assertNotIn("access_token=secret", stdout)
        self.assertNotIn("123456", stdout)
        self.assertIn("[redacted-url]", stdout)


if __name__ == "__main__":
    unittest.main()
