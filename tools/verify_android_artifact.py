#!/usr/bin/env python3
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

with zipfile.ZipFile(apk_path) as apk:
    bad_member = apk.testzip()
    if bad_member:
        fail(f"APK ZIP CRC failed for {bad_member}")
    pck_names = [name for name in apk.namelist() if name.lower().endswith(".pck")]
    if not pck_names:
        fail("APK contains no Godot PCK")
    pck_payload = b"".join(apk.read(name) for name in pck_names)

game_app = (project_root / "scripts/core/game_app.gd").read_text(encoding="utf-8")
table_names = re.findall(r'load_json_file\("res://data/([A-Za-z0-9_]+\.json)"\)', game_app)
if not table_names:
    fail("Could not identify GameApp JSON tables")
for table_name in table_names:
    table_path = project_root / "data" / table_name
    if not table_path.is_file():
        fail(f"GameApp table missing from source checkout: {table_path}")
    try:
        table_data = json.loads(table_path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"GameApp table is invalid JSON: {table_name}: {exc}")
    if not isinstance(table_data, dict):
        fail(f"GameApp table root is not an object: {table_name}")
    pck_path = f"res://data/{table_name}".encode("utf-8")
    if pck_path not in pck_payload:
        fail(f"APK PCK does not contain {pck_path.decode('utf-8')}")

png_paths = [
    project_root / "assets/backgrounds/aquarium_tank.png",
    *(project_root / f"assets/jellycats/normal_jellycat/stages/stage_{stage}.png" for stage in range(1, 6)),
]
png_signature = b"\x89PNG\r\n\x1a\n"
for png_path in png_paths:
    if not png_path.is_file() or png_path.stat().st_size < 100_000:
        fail(f"Full-resolution project PNG is missing: {png_path}")
    with png_path.open("rb") as source:
        if source.read(8) != png_signature:
            fail(f"Project asset is not a PNG: {png_path}")

print(
    "ANDROID_ARTIFACT_OK "
    f"pck={','.join(pck_names)} "
    f"tables={','.join(table_names)} "
    f"source_pngs={len(png_paths)}"
)
