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
    def test_aapt2_diagnostics_do_not_bypass_aapt1_failure(self) -> None:
        command_results = [
            (1, "AndroidManifest.xml:0: error: invalid android:required type\n", "EXITED"),
            (0, "Android Asset Packaging Tool (aapt) 33.0.2\n", "EXITED"),
            (0, "Android Asset Packaging Tool (aapt) 2.19\n", "EXITED"),
            (0, "package: name='com.jacktzeng.jellycat'\n", "EXITED"),
            (0, "E: manifest (line=1)\n", "EXITED"),
        ]
        output = io.StringIO()
        args = [
            "verify_android_manifest.py",
            "--aapt", "aapt",
            "--aapt2", "aapt2",
            "--apk", "pending.apk",
        ]

        with patch.object(sys, "argv", args), patch.object(
            verify_android_manifest, "run", side_effect=command_results
        ) as run_command, redirect_stdout(output):
            status = verify_android_manifest.main()

        self.assertEqual(status, 1)
        self.assertEqual(run_command.call_count, 5)
        self.assertIn("ANDROID_MANIFEST_DIAGNOSTIC_STATUS AAPT2_BADGING exit_code=0", output.getvalue())
        self.assertIn("ANDROID_MANIFEST_DIAGNOSTIC_STATUS AAPT2_XMLTREE exit_code=0", output.getvalue())
        self.assertIn("ANDROID_MANIFEST_GATE=FAIL reason=aapt1_dump_badging_failed", output.getvalue())
        self.assertNotIn("ANDROID_MANIFEST_GATE=PASS", output.getvalue())

    def test_success_still_requires_the_expected_package_identity(self) -> None:
        output = io.StringIO()
        args = [
            "verify_android_manifest.py",
            "--aapt", "aapt",
            "--aapt2", "aapt2",
            "--apk", "pending.apk",
        ]

        with patch.object(sys, "argv", args), patch.object(
            verify_android_manifest,
            "run",
            return_value=(0, "package: name='com.jacktzeng.jellycat'\n", "EXITED"),
        ) as run_command, redirect_stdout(output):
            status = verify_android_manifest.main()

        self.assertEqual(status, 0)
        run_command.assert_called_once_with(["aapt", "dump", "badging", "pending.apk"])
        self.assertIn("ANDROID_MANIFEST_PACKAGE_IDENTITY=PASS package=com.jacktzeng.jellycat", output.getvalue())

    def test_success_rejects_a_different_package_identity(self) -> None:
        output = io.StringIO()
        args = [
            "verify_android_manifest.py",
            "--aapt", "aapt",
            "--aapt2", "aapt2",
            "--apk", "pending.apk",
        ]

        with patch.object(sys, "argv", args), patch.object(
            verify_android_manifest,
            "run",
            return_value=(0, "package: name='com.example.other'\n", "EXITED"),
        ) as run_command, redirect_stdout(output):
            status = verify_android_manifest.main()

        self.assertEqual(status, 1)
        run_command.assert_called_once_with(["aapt", "dump", "badging", "pending.apk"])
        self.assertIn("ANDROID_MANIFEST_GATE=FAIL reason=package_identity_mismatch", output.getvalue())


if __name__ == "__main__":
    unittest.main()
