#!/usr/bin/env python3
"""Minimal regression checks for the Android manifest identity gate."""

from __future__ import annotations

import io
import sys
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

from tools import verify_android_manifest


class AndroidManifestVerifierTests(unittest.TestCase):
    def diagnostic_results(self) -> list[tuple[int | None, str, str]]:
        return [
            (0, "package: name='com.jacktzeng.jellycat'\n", "EXITED"),
            (0, "Android Asset Packaging Tool (aapt) 33.0.2\n", "EXITED"),
            (0, "Android Asset Packaging Tool (aapt) 2.19\n", "EXITED"),
            (0, "E: manifest (line=1)\n", "EXITED"),
        ]

    def arguments(self) -> list[str]:
        return [
            "verify_android_manifest.py",
            "--aapt", "aapt",
            "--aapt2", "aapt2",
            "--apk", "pending.apk",
        ]

    def test_aapt2_nonzero_is_not_bypassed_by_legacy_success(self) -> None:
        command_results = [
            (1, "AAPT2 rejected badging\n", "EXITED"),
            *self.diagnostic_results(),
        ]
        output = io.StringIO()

        with patch.object(sys, "argv", self.arguments()), patch.object(
            verify_android_manifest, "run", side_effect=command_results
        ) as run_command, redirect_stdout(output):
            status = verify_android_manifest.main()

        self.assertEqual(status, 1)
        self.assertEqual(run_command.call_count, 5)
        self.assertIn("ANDROID_MANIFEST_AAPT2_BADGING_STATUS exit_code=1", output.getvalue())
        self.assertIn("AAPT2 rejected badging", output.getvalue())
        self.assertIn("ANDROID_MANIFEST_DIAGNOSTIC_STATUS AAPT1_BADGING exit_code=0", output.getvalue())
        self.assertIn("ANDROID_MANIFEST_DIAGNOSTIC_STATUS AAPT2_XMLTREE exit_code=0", output.getvalue())
        self.assertIn("E: manifest (line=1)", output.getvalue())
        self.assertIn("ANDROID_MANIFEST_GATE=FAIL reason=aapt2_dump_badging_failed", output.getvalue())
        self.assertNotIn("ANDROID_MANIFEST_GATE=PASS", output.getvalue())

    def test_correct_aapt2_package_identity_passes(self) -> None:
        output = io.StringIO()

        with patch.object(sys, "argv", self.arguments()), patch.object(
            verify_android_manifest,
            "run",
            return_value=(0, "package: name='com.jacktzeng.jellycat'\n", "EXITED"),
        ) as run_command, redirect_stdout(output):
            status = verify_android_manifest.main()

        self.assertEqual(status, 0)
        run_command.assert_called_once_with(
            ["aapt2", "dump", "badging", "pending.apk"],
            timeout=verify_android_manifest.VALIDATOR_TIMEOUT_SECONDS,
        )
        self.assertIn("ANDROID_MANIFEST_PACKAGE_IDENTITY=PASS package=com.jacktzeng.jellycat", output.getvalue())

    def test_wrong_aapt2_package_identity_fails_even_if_legacy_succeeds(self) -> None:
        command_results = [
            (0, "package: name='com.example.other'\n", "EXITED"),
            *self.diagnostic_results(),
        ]
        output = io.StringIO()

        with patch.object(sys, "argv", self.arguments()), patch.object(
            verify_android_manifest,
            "run",
            side_effect=command_results,
        ) as run_command, redirect_stdout(output):
            status = verify_android_manifest.main()

        self.assertEqual(status, 1)
        self.assertEqual(run_command.call_count, 5)
        self.assertIn("ANDROID_MANIFEST_DIAGNOSTIC_STATUS AAPT1_BADGING exit_code=0", output.getvalue())
        self.assertIn("ANDROID_MANIFEST_GATE=FAIL reason=package_identity_mismatch", output.getvalue())
        self.assertNotIn("ANDROID_MANIFEST_GATE=PASS", output.getvalue())

    def test_missing_or_timed_out_aapt2_never_releases_legacy_success(self) -> None:
        for state in ("NOT_RUN", "TIMEOUT"):
            with self.subTest(state=state):
                command_results = [
                    (None, f"AAPT2 {state.lower()}\n", state),
                    *self.diagnostic_results(),
                ]
                output = io.StringIO()

                with patch.object(sys, "argv", self.arguments()), patch.object(
                    verify_android_manifest, "run", side_effect=command_results
                ), redirect_stdout(output):
                    status = verify_android_manifest.main()

                self.assertEqual(status, 1)
                self.assertIn(f"ANDROID_MANIFEST_AAPT2_BADGING_STATUS {state}", output.getvalue())
                self.assertIn("ANDROID_MANIFEST_DIAGNOSTIC_STATUS AAPT1_BADGING exit_code=0", output.getvalue())
                self.assertIn("ANDROID_MANIFEST_GATE=FAIL reason=aapt2_dump_badging_failed", output.getvalue())
                self.assertNotIn("ANDROID_MANIFEST_GATE=PASS", output.getvalue())


if __name__ == "__main__":
    unittest.main()
