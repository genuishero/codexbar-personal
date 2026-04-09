#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


HELPER_PATH = Path(__file__).with_name("import_auth_mode.sh")


class ImportAuthModeTests(unittest.TestCase):
    def run_helper(self, command: str) -> str:
        result = subprocess.run(
            ["bash", "-lc", f'source "{HELPER_PATH}"; {command}'],
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout.strip()

    def test_password_accounts_default_to_password_flow(self) -> None:
        prefer = self.run_helper('resolve_prefer_email_otp_login "" "secret-pass"')
        auth_method = self.run_helper(
            'resolve_import_auth_method "secret-pass" "$(resolve_prefer_email_otp_login "" "secret-pass")" "1"'
        )

        self.assertEqual(prefer, "0")
        self.assertEqual(auth_method, "password")

    def test_passwordless_accounts_default_to_email_otp_flow(self) -> None:
        prefer = self.run_helper('resolve_prefer_email_otp_login "" ""')
        auth_method = self.run_helper(
            'resolve_import_auth_method "" "$(resolve_prefer_email_otp_login "" "")" "1"'
        )

        self.assertEqual(prefer, "1")
        self.assertEqual(auth_method, "email_otp")

    def test_explicit_override_can_force_email_otp(self) -> None:
        prefer = self.run_helper('resolve_prefer_email_otp_login "1" "secret-pass"')
        auth_method = self.run_helper('resolve_import_auth_method "secret-pass" "1" "1"')

        self.assertEqual(prefer, "1")
        self.assertEqual(auth_method, "email_otp")
