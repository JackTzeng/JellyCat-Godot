"""Fail-closed checks for the five approved G1 textures and native tank source."""

from __future__ import annotations

import hashlib
import re
import struct
import zlib
from pathlib import Path, PurePosixPath
from zipfile import ZipFile


# Expected values come from ART-DOS-06/MANIFEST.json and the frozen cp02 manifest.
STAGE_PNGS = (
    ("assets/jellycats/normal_jellycat/stages/stage_1.png", 935, "54e88a2fbf4ab705b70d9e3f94c797610f582134e7cfd5bc0eb4d2aab02499a9"),
    ("assets/jellycats/normal_jellycat/stages/stage_2.png", 1089, "434e438c2a3339fe2814ab633491893e4623c54cac6ac86260d1dd91c23685c2"),
    ("assets/jellycats/normal_jellycat/stages/stage_3.png", 1417, "f69a4c34f2dcf70283670b09799fd69acaf57c9b55d025046f8b75fc02d57aea"),
    ("assets/jellycats/normal_jellycat/stages/stage_4.png", 1497, "755995c6f8d5e6473542e164717ccedc73c2ff3d8af9816d8100fdd2cef6949d"),
    ("assets/jellycats/normal_jellycat/stages/stage_5.png", 1546, "5a69746a131eb172968350cc96fe5bf3a0a0c245cf8e0eab3636369bccfbec26"),
)
NATIVE_TANK = (
    "scripts/ui/native_tank.gd",
    1470,
    "a401dea8db5b9cf4af22322443247524cf7257330b61d355631f81c4bb18622d",
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
GLOBAL_CLASSES = ("CareSystem", "CurrencySystem", "EggSystem", "HatchSystem", "EvolutionSystem")


def _png_error(data: bytes, label: str) -> str | None:
    if not data.startswith(PNG_SIGNATURE):
        return f"asset is not a PNG: {label}"

    offset = len(PNG_SIGNATURE)
    seen_header = seen_data = seen_end = False
    while offset < len(data):
        if len(data) - offset < 12:
            return f"PNG chunk is truncated: {label}"
        length = int.from_bytes(data[offset : offset + 4], "big")
        chunk_type = data[offset + 4 : offset + 8]
        chunk_end = offset + 12 + length
        if chunk_end > len(data):
            return f"PNG chunk is truncated: {label}"
        chunk_data = data[offset + 8 : offset + 8 + length]
        chunk_crc = int.from_bytes(data[offset + 8 + length : chunk_end], "big")
        if (zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF) != chunk_crc:
            return f"PNG chunk CRC is invalid: {label}"

        if not seen_header:
            if chunk_type != b"IHDR" or length != 13:
                return f"PNG IHDR is missing or malformed: {label}"
            width, height, depth, color_type, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
            if (width, height) != (64, 64):
                return f"PNG dimensions are not 64x64: {label}"
            if (depth, color_type, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                return f"PNG is not non-interlaced 8-bit RGBA: {label}"
            seen_header = True
        elif chunk_type == b"IHDR":
            return f"PNG has duplicate IHDR: {label}"

        if chunk_type == b"IDAT":
            seen_data = True
        if chunk_type == b"IEND":
            if length != 0 or not seen_data:
                return f"PNG IEND or image data is malformed: {label}"
            seen_end = True
            offset = chunk_end
            break
        offset = chunk_end

    if not seen_header or not seen_data or not seen_end or offset != len(data):
        return f"PNG structure is incomplete: {label}"
    return None


def verify_asset_sources(
    root: Path, *, require_cooked: bool
) -> tuple[str | None, list[tuple[Path, str]]]:
    """Validate approved source bytes and return each stage PNG's CTEX path."""
    imported: list[tuple[Path, str]] = []
    for relative, expected_size, expected_sha in STAGE_PNGS:
        png = root / PurePosixPath(relative)
        if png.is_symlink() or not png.is_file():
            return f"approved stage PNG is missing: {png}", []
        data = png.read_bytes()
        error = _png_error(data, relative)
        if error:
            return error, []
        if len(data) != expected_size:
            return f"approved stage PNG has wrong size: {png}", []
        actual_sha = hashlib.sha256(data).hexdigest()
        if actual_sha != expected_sha:
            return f"approved stage PNG SHA256 mismatch: {png}", []

        remap = Path(f"{png}.import")
        if remap.is_symlink() or not remap.is_file():
            return f"missing PNG import remap: {remap}", []
        matches = re.findall(
            r'^path="res://([^"\r\n]+\.ctex)"$',
            remap.read_text(encoding="utf-8"),
            re.MULTILINE,
        )
        if len(matches) != 1:
            return f"expected one CTEX path in import remap: {remap}", []
        ctex_relative = PurePosixPath(matches[0])
        if ctex_relative.is_absolute() or ".." in ctex_relative.parts:
            return f"unsafe CTEX path in import remap: {remap}", []
        ctex = root.joinpath(*ctex_relative.parts)
        if require_cooked and (ctex.is_symlink() or not ctex.is_file() or ctex.stat().st_size == 0):
            return f"Godot PNG import output is missing or empty: {ctex}", []
        imported.append((png, ctex_relative.as_posix()))

    if len(imported) != 5 or len({ctex for _, ctex in imported}) != 5:
        return "expected five distinct approved stage CTEX remaps", []

    native_path = root / PurePosixPath(NATIVE_TANK[0])
    if native_path.is_symlink() or not native_path.is_file():
        return f"approved native tank source is missing: {native_path}", []
    native_bytes = native_path.read_bytes()
    if len(native_bytes) != NATIVE_TANK[1] or hashlib.sha256(native_bytes).hexdigest() != NATIVE_TANK[2]:
        return f"approved native tank source SHA256 mismatch: {native_path}", []
    return None, imported


def verify_imports(root: Path) -> str | None:
    error, _ = verify_asset_sources(root, require_cooked=True)
    if error:
        return error
    cache = root / ".godot/global_script_class_cache.cfg"
    if not cache.is_file():
        return f"Godot global script class cache missing: {cache}"
    cache_text = cache.read_text(encoding="utf-8")
    missing = [name for name in GLOBAL_CLASSES if name not in cache_text]
    if missing:
        return "Godot global script class cache is incomplete: " + ", ".join(missing)
    return None


def verify_packaged_assets(
    apk: ZipFile, root: Path, imported: list[tuple[Path, str]]
) -> str | None:
    names = set(apk.namelist())
    for png, ctex_relative in imported:
        entry = f"assets/{ctex_relative}"
        if entry not in names:
            return f"APK is missing imported texture for {png}: {entry}"
        if apk.getinfo(entry).file_size == 0:
            return f"APK imported texture is empty: {entry}"

    native_path = root / PurePosixPath(NATIVE_TANK[0])
    native_entry = f"assets/{NATIVE_TANK[0]}"
    compiled_entry = f"assets/{PurePosixPath(NATIVE_TANK[0]).with_suffix('.gdc').as_posix()}"
    if native_entry not in names and compiled_entry not in names:
        return f"APK is missing approved native tank source: {native_entry} or {compiled_entry}"
    if native_entry in names and apk.read(native_entry) != native_path.read_bytes():
        return f"APK native tank source differs from approved source: {native_entry}"
    if compiled_entry in names and apk.getinfo(compiled_entry).file_size == 0:
        return f"APK compiled native tank source is empty: {compiled_entry}"
    return None
