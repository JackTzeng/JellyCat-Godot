#!/usr/bin/env python3
"""Lightweight preflight checker for JellyCat art-production prompts."""

from __future__ import annotations

import argparse
from pathlib import Path

REQUIRED_GROUPS = {
    "subject": ("jellycat", "jelly cat", "aquarium", "ui", "icon", "sprite", "background"),
    "style": ("soft", "healing", "aquatic", "translucent", "gentle", "cute"),
    "production": ("transparent", "background", "resolution", "aspect ratio", "frame", "godot", "sprite"),
}

WARN_TERMS = (
    "random text",
    "watermark",
    "fake ui",
    "generic ai",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("prompt_file", type=Path)
    parser.add_argument("--require-transparent", action="store_true")
    parser.add_argument("--animation", action="store_true")
    args = parser.parse_args()

    text = args.prompt_file.read_text(encoding="utf-8").lower()
    failures: list[str] = []
    warnings: list[str] = []

    for group, terms in REQUIRED_GROUPS.items():
        if not any(term in text for term in terms):
            failures.append(f"missing {group} language")

    if args.require_transparent and "transparent" not in text:
        failures.append("transparent background requirement not found")

    if args.animation:
        for term in ("frame", "anchor", "consistent"):
            if term not in text:
                failures.append(f"animation prompt missing: {term}")

    for term in WARN_TERMS:
        if term in text:
            warnings.append(f"review discouraged phrase: {term}")

    print("JellyCat prompt preflight")
    for item in warnings:
        print(f"WARN: {item}")
    for item in failures:
        print(f"FAIL: {item}")

    if failures:
        return 1

    print("PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
