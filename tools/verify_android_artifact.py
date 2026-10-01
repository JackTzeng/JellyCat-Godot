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


def fail(message: str) -> None:
    raise SystemExit(f"ANDROID_ARTIFACT_FAIL: {message}")


apk_path = Path(sys.argv[1])
project_root = Path(sys.argv[2])
if not apk_path.is_file() or apk_path.stat().st_size < 100_000:
    fail("APK is missing or unexpectedly small")

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

png_paths = [
    project_root / "assets/backgrounds/aquarium_tank.png",
    *(
        project_root / f"assets/jellycats/normal_jellycat/stages/stage_{stage}.png"
        for stage in range(1, 6)
    ),
]
png_signature = b"\x89PNG\r\n\x1a\n"
source_imported_textures: dict[Path, str] = {}
for png_path in png_paths:
    if not png_path.is_file() or png_path.stat().st_size < 100_000:
        fail(f"Full-resolution project PNG is missing: {png_path}")
    if png_path.read_bytes()[:8] != png_signature:
        fail(f"Project asset is not a PNG: {png_path}")
    import_path = Path(f"{png_path}.import")
    if not import_path.is_file():
        fail(f"Godot import remap is missing for source PNG: {import_path}")
    import_text = import_path.read_text(encoding="utf-8")
    match = re.search(r'^path="res://([^"\r\n]+\.ctex)"$', import_text, re.MULTILINE)
    if not match:
        fail(f"Godot import remap has no CTEX output path: {import_path}")
    source_imported_textures[png_path] = f"assets/{match.group(1)}"

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

    packaged_textures = []
    for png_path, texture_entry in source_imported_textures.items():
        if texture_entry not in names:
            fail(f"APK is missing imported texture for {png_path}: {texture_entry}")
        if apk.getinfo(texture_entry).file_size == 0:
            fail(f"APK imported texture is empty: {texture_entry}")
        packaged_textures.append(texture_entry)

print(
    "ANDROID_ARTIFACT_OK "
    f"tables={','.join(table_names)} "
    f"source_pngs={len(png_paths)} "
    f"packaged_imported_textures={len(packaged_textures)}"
)
