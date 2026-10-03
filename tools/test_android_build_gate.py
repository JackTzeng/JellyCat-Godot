#!/usr/bin/env python3
"""Standalone tests and shared CLI checks for the Android build gate."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
import tempfile
import time
import unittest
from pathlib import Path, PurePosixPath


GODOT_ERROR = re.compile(r"(?im)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)")


def check_godot_step(log: str, exit_code: int, marker: str = "") -> str | None:
    if exit_code != 0:
        return f"Godot exited with status {exit_code}"
    error = GODOT_ERROR.search(log)
    if error:
        line = log[error.start() :].splitlines()[0].strip()
        return f"Godot error output: {line}"
    if marker and not any(line.startswith(marker) for line in log.splitlines()):
        return f"required success marker missing: {marker}"
    return None


def source_sha256(root: Path) -> str:
    digest = hashlib.sha256()
    excluded = {".git", ".godot"}
    ignored_exports = {"exports/builds", "exports/.godot-cli-home"}
    report = "WORKSTREAM_REPORT.md"
    files: list[tuple[str, Path]] = []
    for path in root.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(root).as_posix()
        parts = set(PurePosixPath(relative).parts)
        if parts & excluded or relative == report:
            continue
        if any(relative == prefix or relative.startswith(prefix + "/") for prefix in ignored_exports):
            continue
        files.append((relative, path))

    for relative, path in sorted(files, key=lambda item: item[0]):
        encoded_path = relative.encode("utf-8")
        content = path.read_bytes()
        digest.update(len(encoded_path).to_bytes(8, "big"))
        digest.update(encoded_path)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


def verify_imports(root: Path) -> str | None:
    pngs = [
        root / "assets/backgrounds/aquarium_tank.png",
        *(root / f"assets/jellycats/normal_jellycat/stages/stage_{stage}.png" for stage in range(1, 6)),
    ]
    for png in pngs:
        remap = Path(f"{png}.import")
        if not remap.is_file():
            return f"missing PNG import remap: {remap}"
        match = re.search(r'^path="res://([^"\r\n]+\.ctex)"$', remap.read_text(encoding="utf-8"), re.MULTILINE)
        if not match:
            return f"missing CTEX path in import remap: {remap}"
        imported = root / match.group(1)
        if not imported.is_file() or imported.stat().st_size == 0:
            return f"Godot PNG import output is missing or empty: {imported}"
    cache = root / ".godot/global_script_class_cache.cfg"
    if not cache.is_file():
        return f"Godot global script class cache missing: {cache}"
    cache_text = cache.read_text(encoding="utf-8")
    expected_classes = ("CareSystem", "CurrencySystem", "EggSystem", "HatchSystem", "EvolutionSystem")
    missing = [name for name in expected_classes if name not in cache_text]
    if missing:
        return "Godot global script class cache is incomplete: " + ", ".join(missing)
    return None


def verify_apk(path: Path, started_ns: int) -> tuple[str | None, str | None]:
    if path.suffix.lower() != ".apk":
        return "artifact path must end in .apk", None
    if path.is_symlink():
        return "APK path cannot be a symlink", None
    try:
        stat = path.stat()
    except FileNotFoundError:
        return "APK is missing", None
    if not path.is_file() or stat.st_size == 0:
        return "APK is empty or not a regular file", None
    if stat.st_mtime_ns < started_ns:
        return "APK predates this build run", None
    digest = hashlib.sha256()
    with path.open("rb") as artifact:
        for block in iter(lambda: artifact.read(1024 * 1024), b""):
            digest.update(block)
    return None, digest.hexdigest()


class BuildGateTests(unittest.TestCase):
    def test_source_sha_uses_relative_posix_path_order(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "assets").mkdir()
            payloads = {"README.md": b"root", "assets/a.bin": b"asset"}
            for relative, content in payloads.items():
                (root / relative).write_bytes(content)

            expected = hashlib.sha256()
            for relative, content in sorted(payloads.items()):
                encoded_path = relative.encode("utf-8")
                expected.update(len(encoded_path).to_bytes(8, "big"))
                expected.update(encoded_path)
                expected.update(len(content).to_bytes(8, "big"))
                expected.update(content)

            self.assertEqual(source_sha256(root), expected.hexdigest())

    def test_clean_log_passes_even_when_it_has_no_diagnostic_marker(self) -> None:
        self.assertIsNone(check_godot_step("Godot Engine v4.2.1.stable\n", 0))

    def test_parser_error_fails_even_when_godot_returns_zero(self) -> None:
        log = "SCRIPT ERROR: Parse Error: Too few arguments for feed_food()\n"
        self.assertIsNotNone(check_godot_step(log, 0))

    def test_runtime_error_fails_even_when_godot_returns_zero(self) -> None:
        log = "SCRIPT ERROR: Invalid call. Nonexistent function.\n"
        self.assertIsNotNone(check_godot_step(log, 0))

    def test_scene_load_error_fails_even_when_godot_returns_zero(self) -> None:
        log = "ERROR: Failed loading resource: res://scenes/aquarium/aquarium.tscn\n"
        self.assertIsNotNone(check_godot_step(log, 0))

    def test_missing_success_marker_fails(self) -> None:
        self.assertIsNotNone(check_godot_step("Godot Engine\n", 0, "ANDROID_SCENE_ACCEPTANCE_OK"))

    def test_missing_apk_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            error, digest = verify_apk(Path(temporary) / "missing.apk", time.time_ns())
            self.assertEqual(error, "APK is missing")
            self.assertIsNone(digest)

    def test_stale_apk_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "old.apk"
            path.write_bytes(b"stale artifact")
            started_ns = time.time_ns()
            os.utime(path, ns=(started_ns - 1_000_000, started_ns - 1_000_000))
            error, digest = verify_apk(path, started_ns)
            self.assertEqual(error, "APK predates this build run")
            self.assertIsNone(digest)

    def test_fresh_apk_passes_and_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "fresh.apk"
            started_ns = time.time_ns() - 5_000_000_000
            payload = b"fresh APK fixture"
            path.write_bytes(payload)
            error, digest = verify_apk(path, started_ns)
            self.assertIsNone(error)
            self.assertEqual(digest, hashlib.sha256(payload).hexdigest())


def main() -> int:
    if len(sys.argv) == 1 or sys.argv[1] == "test":
        unittest.main(argv=[sys.argv[0]], verbosity=2)
        return 0

    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    log_parser = commands.add_parser("check-log")
    log_parser.add_argument("--step", required=True)
    log_parser.add_argument("--log", type=Path, required=True)
    log_parser.add_argument("--exit-code", type=int, required=True)
    log_parser.add_argument("--marker", default="")
    hash_parser = commands.add_parser("source-sha")
    hash_parser.add_argument("--root", type=Path, required=True)
    imports_parser = commands.add_parser("verify-imports")
    imports_parser.add_argument("--root", type=Path, required=True)
    apk_parser = commands.add_parser("verify-apk")
    apk_parser.add_argument("--apk", type=Path, required=True)
    apk_parser.add_argument("--started-ns", type=int, required=True)
    apk_parser.add_argument("--sha-file", type=Path)
    apk_parser.add_argument("--sha-name", default="")
    args = parser.parse_args()

    if args.command == "check-log":
        error = check_godot_step(args.log.read_text(encoding="utf-8", errors="replace"), args.exit_code, args.marker)
        if error:
            print(f"ANDROID_GATE_FAIL step={args.step}: {error}", file=sys.stderr)
            return 1
        print(f"ANDROID_GATE_OK step={args.step}")
        return 0

    if args.command == "source-sha":
        print(source_sha256(args.root.resolve()))
        return 0

    if args.command == "verify-imports":
        error = verify_imports(args.root.resolve())
        if error:
            print(f"ANDROID_GATE_FAIL imports: {error}", file=sys.stderr)
            return 1
        print("ANDROID_IMPORT_OK ctex_count=6 global_classes=5")
        return 0

    error, digest = verify_apk(args.apk, args.started_ns)
    if error:
        print(f"ANDROID_GATE_FAIL artifact: {error}", file=sys.stderr)
        return 1
    assert digest is not None
    if args.sha_file:
        args.sha_file.write_text(f"{digest}  {args.sha_name or args.apk.name}\n", encoding="ascii")
    print(f"ANDROID_APK_SHA256={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
