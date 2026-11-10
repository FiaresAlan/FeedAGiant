#!/usr/bin/env python3
"""Validate downloaded Kenney/Quaternius ZIP filenames without extracting or uploading.

Usage:
    python tools/check_art_archives.py \
      --kenney "C:/Users/Administrador/Downloads/kenney_food-kit.zip" \
      --fantasy "C:/Users/Administrador/Downloads/Fantasy Props MegaKit[Standard].zip"

Only reads archive directories and the text-based ArtManifest.lua in the repo.
Does NOT write, execute, extract, or publish anything. Exits non-zero on missing Tier 1.
"""
from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path


def parse_manifest(source: Path) -> list[dict[str, str | int]]:
    content = source.read_text(encoding="utf-8")
    records: list[dict[str, str | int]] = []
    for line in content.splitlines():
        if 'key = "' not in line:
            continue
        fields = dict(re.findall(r'(key|pack|file|template|purpose) = "([^"]+)"', line))
        tier = re.search(r"tier = ([123])", line)
        if len(fields) != 5 or tier is None:
            raise ValueError(f"Invalid manifest entry: {line.strip()}")
        fields["tier"] = int(tier.group(1))
        records.append(fields)
    if len(records) != 22:
        raise ValueError(f"Expected 22 curated items, found {len(records)}")
    return records


def inspect_zip(path: Path) -> dict[str, list[str]]:
    if not path.is_file():
        raise FileNotFoundError(str(path))
    entries: dict[str, list[str]] = {}
    with zipfile.ZipFile(path, "r") as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
            name = info.filename.replace("\\", "/")
            if name.startswith("/") or "../" in name or "/.." in name:
                raise ValueError(f"Unsafe path in archive: {name}")
            if info.file_size > 200 * 1024 * 1024:
                raise ValueError(f"Unexpected 200 MB single file: {name}")
            if info.compress_size and info.file_size / info.compress_size > 3000:
                raise ValueError(f"Suspicious compression ratio: {name}")
            basename = name.rsplit("/", 1)[-1].casefold()
            entries.setdefault(basename, []).append(name)
    return entries


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--kenney", required=True, type=Path)
    parser.add_argument("--fantasy", required=True, type=Path)
    args = parser.parse_args()

    manifest = parse_manifest(root / "src" / "shared" / "ArtManifest.lua")
    available = {
        "Kenney Food Kit": inspect_zip(args.kenney),
        "Quaternius Fantasy Props": inspect_zip(args.fantasy),
    }
    kenney = available["Kenney Food Kit"]
    fantasy = available["Quaternius Fantasy Props"]
    print(f"Kenney: {sum(x.endswith('.fbx') for x in kenney)} distinct FBX names")
    print(f"Fantasy Props: {sum(x.endswith('.fbx') for x in fantasy)} distinct FBX names")
    print("Kenney colormap:", "PRESENT" if "colormap.png" in kenney else "NOT FOUND")

    missing_essential = []
    missing_optional = []
    for item in sorted(manifest, key=lambda entry: entry["tier"]):
        record = item
        files = available[str(record["pack"])].get(str(record["file"]).casefold(), [])
        label = "[OK]" if len(files) == 1 else "[MISSING]" if not files else "[DUPLICATE]"
        print(f"{label} Tier {record['tier']}  {record['template']}  -> {record['file']}")
        if len(files) != 1:
            if record["tier"] == 1:
                missing_essential.append(str(record["file"]))
            else:
                missing_optional.append(str(record["file"]))

    if missing_essential:
        print("Tier 1 missing or duplicated: " + ", ".join(missing_essential), file=sys.stderr)
        return 2
    if missing_optional:
        print("Optional missing: " + ", ".join(missing_optional))
    print("Tier 1 imports are present. No files have been extracted or uploaded.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, zipfile.BadZipFile, ValueError) as exc:
        print(f"Archive validation error: {exc}", file=sys.stderr)
        raise SystemExit(3) from exc
