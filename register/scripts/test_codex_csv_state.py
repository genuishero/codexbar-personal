#!/usr/bin/env python3

from __future__ import annotations

import contextlib
import csv
import importlib.util
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("codex_csv_state.py")
SPEC = importlib.util.spec_from_file_location("codex_csv_state", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("failed to load codex_csv_state module")
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class CodexCSVStateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.csv_path = Path(self.tempdir.name) / "codex.csv"

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def read_rows(self):
        with self.csv_path.open("r", encoding="utf-8", newline="") as fh:
            return list(csv.DictReader(fh))

    def write_legacy_rows(self, rows):
        with self.csv_path.open("w", encoding="utf-8", newline="") as fh:
            writer = csv.writer(fh)
            writer.writerow(["email", "password", "status", "url"])
            writer.writerows(rows)

    def write_rows(self, rows):
        MODULE.atomic_write_rows(str(self.csv_path), rows)

    def test_ensure_migrates_legacy_rows(self):
        self.write_legacy_rows(
            [
                ["a@example.com", "secret", "registered", ""],
                ["b@example.com", "", "import_failed", "https://example.com/path"],
            ]
        )

        MODULE.ensure_file(str(self.csv_path))
        rows = self.read_rows()

        self.assertEqual(rows[0]["schema_version"], MODULE.SCHEMA_VERSION)
        self.assertEqual(rows[0]["phase"], "register")
        self.assertEqual(rows[0]["status"], "completed")
        self.assertEqual(rows[0]["auth_method"], "password")

        self.assertEqual(rows[1]["phase"], "import")
        self.assertEqual(rows[1]["status"], "retryable_failure")
        self.assertEqual(rows[1]["failure_category"], "legacy_import_failure")

    def test_upsert_preserves_schema_and_sets_retry(self):
        MODULE.ensure_file(str(self.csv_path))
        fake_args = type(
            "Args",
            (),
            {
                "email": "a@example.com",
                "password": "secret",
                "status": "retryable_failure",
                "url": "",
                "auth_method": "password",
                "phase": "import",
                "failure_category": "cdp_race",
                "manual_action": "retry_after_local_fix",
                "retry_count": MODULE.KEEP,
                "updated_at": MODULE.KEEP,
                "increment_retry_count": True,
            },
        )()

        MODULE.upsert_row(str(self.csv_path), "a@example.com", fake_args)
        rows = self.read_rows()

        self.assertEqual(rows[0]["retry_count"], "1")
        self.assertEqual(rows[0]["failure_category"], "cdp_race")
        self.assertEqual(rows[0]["phase"], "import")

    def test_auto_import_eligibility_requires_password_completed_register(self):
        eligible = MODULE.default_row()
        eligible.update(
            {
                "email": "a@example.com",
                "password": "secret",
                "phase": "register",
                "status": "completed",
                "auth_method": "password",
                "manual_action": "none",
                "failure_category": "",
            }
        )
        otp = dict(eligible, auth_method="email_otp", password="")

        self.assertTrue(MODULE.is_auto_import_eligible(eligible))
        self.assertFalse(MODULE.is_auto_import_eligible(otp))

    def test_retry_eligibility_respects_matrix(self):
        local_retry = MODULE.default_row()
        local_retry.update(
            {
                "phase": "import",
                "status": "retryable_failure",
                "failure_category": "cdp_race",
                "retry_count": "1",
            }
        )
        exhausted = dict(local_retry, retry_count="3")
        invalid_state_retry = dict(
            local_retry,
            failure_category="invalid_state",
            retry_count="1",
        )
        invalid_state_exhausted = dict(invalid_state_retry, retry_count="2")
        provider_block = dict(local_retry, status="manual_required", failure_category="phone_verification")

        self.assertTrue(MODULE.is_retry_eligible(local_retry))
        self.assertTrue(MODULE.is_retry_eligible(invalid_state_retry))
        self.assertFalse(MODULE.is_retry_eligible(exhausted))
        self.assertFalse(MODULE.is_retry_eligible(invalid_state_exhausted))
        self.assertFalse(MODULE.is_retry_eligible(provider_block))

    def test_reconcile_imported_marks_rows_completed(self):
        self.write_legacy_rows([["a@example.com", "secret", "registered", ""]])
        config_path = Path(self.tempdir.name) / "config.json"
        config_path.write_text(
            '{"providers":[{"kind":"openai_oauth","accounts":[{"email":"a@example.com"}]}]}',
            encoding="utf-8",
        )

        updated = MODULE.reconcile_imported(str(self.csv_path), str(config_path), "")
        rows = self.read_rows()

        self.assertEqual(updated, 1)
        self.assertEqual(rows[0]["phase"], "import")
        self.assertEqual(rows[0]["status"], "completed")
        self.assertEqual(rows[0]["manual_action"], "none")

    def test_emit_candidates_respects_import_and_retry_gates(self):
        eligible = MODULE.default_row()
        eligible.update(
            {
                "email": "eligible@example.com",
                "password": "secret",
                "phase": "register",
                "status": "completed",
                "auth_method": "password",
                "manual_action": "none",
            }
        )
        passwordless = MODULE.default_row()
        passwordless.update(
            {
                "email": "otp@example.com",
                "phase": "register",
                "status": "completed",
                "auth_method": "email_otp",
                "manual_action": "review_passwordless_account",
            }
        )
        retryable = MODULE.default_row()
        retryable.update(
            {
                "email": "retry@example.com",
                "password": "secret",
                "phase": "import",
                "status": "retryable_failure",
                "failure_category": "cdp_race",
                "manual_action": "retry_after_local_fix",
                "retry_count": "0",
            }
        )
        imported = MODULE.default_row()
        imported.update(
            {
                "email": "imported@example.com",
                "password": "secret",
                "phase": "register",
                "status": "completed",
                "auth_method": "password",
                "manual_action": "none",
            }
        )
        self.write_rows([eligible, passwordless, retryable, imported])

        imported_accounts = MODULE.ImportedAccounts(emails={"imported@example.com"})
        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            MODULE.emit_candidates(
                rows=MODULE.load_rows(str(self.csv_path)),
                imported=imported_accounts,
                email_filter="",
                mode="import",
            )
            import_output = buffer.getvalue().splitlines()

        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            MODULE.emit_candidates(
                rows=MODULE.load_rows(str(self.csv_path)),
                imported=imported_accounts,
                email_filter="",
                mode="retry",
            )
            retry_output = buffer.getvalue().splitlines()

        self.assertEqual(import_output, ["eligible@example.com", "secret"])
        self.assertEqual(retry_output, ["retry@example.com", "secret"])


if __name__ == "__main__":
    unittest.main()
