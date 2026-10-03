#!/usr/bin/env python3
"""Keep the legacy APK identity gate and collect AAPT2 diagnostics on failure."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections.abc import Sequence


EXPECTED_PACKAGE = "com.jacktzeng.jellycat"
DIAGNOSTIC_TIMEOUT_SECONDS = 60


def run(command: Sequence[str], timeout: int | None = None) -> tuple[int | None, str, str]:
    try:
        result = subprocess.run(
            list(command),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        return None, output, "TIMEOUT"
    except OSError as error:
        return None, str(error), "NOT_RUN"
    return result.returncode, result.stdout, "EXITED"


def print_output(label: str, output: str) -> None:
    print(f"{label}_OUTPUT_BEGIN")
    if output:
        sys.stdout.write(output)
        if not output.endswith("\n"):
            sys.stdout.write("\n")
    print(f"{label}_OUTPUT_END")


def run_diagnostic(label: str, command: Sequence[str]) -> None:
    print(f"ANDROID_MANIFEST_DIAGNOSTIC_COMMAND {label} {json.dumps(list(command), ensure_ascii=False)}")
    code, output, state = run(command, timeout=DIAGNOSTIC_TIMEOUT_SECONDS)
    status = f"exit_code={code}" if state == "EXITED" else state
    print(f"ANDROID_MANIFEST_DIAGNOSTIC_STATUS {label} {status}")
    print_output(f"ANDROID_MANIFEST_DIAGNOSTIC_{label}", output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aapt", required=True, help="Build Tools 33.0.2 legacy aapt executable")
    parser.add_argument("--aapt2", required=True, help="Build Tools 33.0.2 aapt2 executable")
    parser.add_argument("--apk", required=True, help="Pending APK to inspect")
    args = parser.parse_args()

    legacy_command = [args.aapt, "dump", "badging", args.apk]
    legacy_code, legacy_output, legacy_state = run(legacy_command)
    legacy_status = f"exit_code={legacy_code}" if legacy_state == "EXITED" else legacy_state
    print(f"ANDROID_MANIFEST_AAPT1_BADGING_STATUS {legacy_status}")

    if legacy_state != "EXITED" or legacy_code != 0:
        print_output("ANDROID_MANIFEST_AAPT1_BADGING", legacy_output)
        print("ANDROID_MANIFEST_DIAGNOSTIC_ONLY=yes")
        run_diagnostic("AAPT1_VERSION", [args.aapt, "version"])
        run_diagnostic("AAPT2_VERSION", [args.aapt2, "version"])
        run_diagnostic("AAPT2_BADGING", [args.aapt2, "dump", "badging", args.apk])
        run_diagnostic(
            "AAPT2_XMLTREE",
            [args.aapt2, "dump", "xmltree", args.apk, "--file", "AndroidManifest.xml"],
        )
        print("ANDROID_MANIFEST_DIAGNOSTICS_COMPLETE")
        print("ANDROID_MANIFEST_GATE=FAIL reason=aapt1_dump_badging_failed")
        return 1

    expected_identity = f"package: name='{EXPECTED_PACKAGE}'"
    if expected_identity not in legacy_output:
        print_output("ANDROID_MANIFEST_AAPT1_BADGING", legacy_output)
        print("ANDROID_MANIFEST_GATE=FAIL reason=package_identity_mismatch")
        return 1

    print(f"ANDROID_MANIFEST_PACKAGE_IDENTITY=PASS package={EXPECTED_PACKAGE}")
    print("ANDROID_MANIFEST_GATE=PASS validator=aapt_dump_badging")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
