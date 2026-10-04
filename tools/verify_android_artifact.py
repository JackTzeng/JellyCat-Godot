#!/usr/bin/env python3
"""Verify that the Android APK contains the actual Godot runtime assets.

Godot 4.2.1's non-Gradle Android exporter stores project files as individual
``assets/...`` ZIP entries. It does not produce a standalone PCK in the APK.
The JSON tables are ordinary files and must be included explicitly; imported
textures are packaged from their generated ``.ctex`` remaps.
"""

import json
import re
import sys
import zipfile
from pathlib import Path

# Avoid generated .pyc files entering the measured source tree.
sys.dont_write_bytecode = True

from android_asset_gate import verify_asset_sources, verify_packaged_assets


def fail(message: str) -> None:
    raise SystemExit(f"ANDROID_ARTIFACT_FAIL: {message}")


apk_path = Path(sys.argv[1])
project_root = Path(sys.argv[2])
if not apk_path.is_file() or apk_path.stat().st_size < 100_000:
    fail("APK is missing or unexpectedly small")

asset_error, source_imported_textures = verify_asset_sources(project_root, require_cooked=False)
if asset_error:
    fail(asset_error)

game_app_path = project_root / "scripts/core/game_app.gd"
if not game_app_path.is_file():
    fail(f"GameApp source is missing: {game_app_path}")
game_app = game_app_path.read_text(encoding="utf-8")
table_names = sorted(set(re.findall(
    r'load_json_file\("res://data/([A-Za-z0-9_]+\.json)"\)', game_app
)))
if not table_names:
    fail("Could not identify GameApp JSON tables")

source_tables: dict[str, bytes] = {}
for table_name in table_names:
    table_path = project_root / "data" / table_name
    if not table_path.is_file():
        fail(f"GameApp table missing from source checkout: {table_path}")
    table_bytes = table_path.read_bytes()
    try:
        table_data = json.loads(table_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"GameApp table is invalid JSON: {table_name}: {exc}")
    if not isinstance(table_data, dict):
        fail(f"GameApp table root is not an object: {table_name}")
    source_tables[f"assets/data/{table_name}"] = table_bytes

with zipfile.ZipFile(apk_path) as apk:
    bad_member = apk.testzip()
    if bad_member:
        fail(f"APK ZIP CRC failed for {bad_member}")
    names = set(apk.namelist())

    for apk_entry, source_bytes in source_tables.items():
        if apk_entry not in names:
            fail(f"APK is missing GameApp JSON table: {apk_entry}")
        packed_bytes = apk.read(apk_entry)
        if packed_bytes != source_bytes:
            fail(f"APK JSON table differs from source checkout: {apk_entry}")
        try:
            packed_json = json.loads(packed_bytes.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            fail(f"APK JSON table is invalid: {apk_entry}: {exc}")
        if not isinstance(packed_json, dict):
            fail(f"APK JSON table root is not an object: {apk_entry}")

    asset_error = verify_packaged_assets(apk, project_root, source_imported_textures)
    if asset_error:
        fail(asset_error)

print(
    "ANDROID_ARTIFACT_OK "
    f"tables={','.join(table_names)} "
    f"source_pngs={len(source_imported_textures)} "
    f"packaged_imported_textures={len(source_imported_textures)} native_tank=1"
)
