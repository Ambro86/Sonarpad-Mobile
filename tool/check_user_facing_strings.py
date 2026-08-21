#!/usr/bin/env python3
"""Detect new likely user-facing string literals outside the localization layer.

The current legacy baseline is stored in test/fixtures/localization_hardcoded_allowlist.json.
The baseline should shrink over time. New shared UI strings must go through ARB/localized data.
"""
from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SCAN_DIRS = [ROOT / "lib" / "screens", ROOT / "lib" / "widgets"]
SERVICE_DIR = ROOT / "lib" / "services"
ALLOWLIST = ROOT / "test" / "fixtures" / "localization_hardcoded_allowlist.json"

UI_PATTERNS = [
    re.compile(r"\bText\(\s*(['\"])(.*?)\1"),
    re.compile(r"\b(?:tooltip|labelText|hintText|semanticLabel|title|subtitle|label|message):\s*(['\"])(.*?)\1"),
]

SERVICE_PATTERNS = [
    re.compile(r"throw\s+(?:Exception|StateError|ArgumentError|FormatException)\(\s*(['\"])(.*?)\1"),
    re.compile(r"Future\.error\(\s*(['\"])(.*?)\1"),
]


def should_ignore(value: str) -> bool:
    text = value.strip()
    if not text:
        return True
    if text.startswith(("http://", "https://", "/")):
        return True
    if re.fullmatch(r"[A-Za-z0-9_.:/+%-]+", text) and not re.search(r"\s", text):
        # IDs, route names, extensions, short technical tokens and brand-only values.
        return True
    if re.fullmatch(r"[\W_\d$]+", text):
        return True
    return False


def scan() -> Counter[str]:
    found: Counter[str] = Counter()
    for directory in SCAN_DIRS:
        for path in sorted(directory.rglob("*.dart")):
            source = path.read_text(encoding="utf-8", errors="ignore")
            rel = path.relative_to(ROOT).as_posix()
            for line in source.splitlines():
                for pattern in UI_PATTERNS:
                    for match in pattern.finditer(line):
                        value = match.group(2)
                        if should_ignore(value):
                            continue
                        found[f"ui\t{rel}\t{value}"] += 1

    # Legacy services still throw text in several places. Keep a baseline so
    # new service errors cannot silently become another localization burden.
    for path in sorted(SERVICE_DIR.rglob("*.dart")):
        source = path.read_text(encoding="utf-8", errors="ignore")
        rel = path.relative_to(ROOT).as_posix()
        for line in source.splitlines():
            for pattern in SERVICE_PATTERNS:
                for match in pattern.finditer(line):
                    value = match.group(2)
                    if should_ignore(value):
                        continue
                    found[f"service-error\t{rel}\t{value}"] += 1
    return found


def main() -> int:
    actual = scan()
    expected = Counter(json.loads(ALLOWLIST.read_text(encoding="utf-8")))
    additions = actual - expected
    if additions:
        print("New likely user-facing hard-coded strings or raw service errors found:", file=sys.stderr)
        for key, count in sorted(additions.items()):
            print(f"  {count}x {key}", file=sys.stderr)
        print("Move them to ARB/localized data. Do not grow the allowlist for shared UI.", file=sys.stderr)
        return 1
    print(f"Localization hard-code guard passed ({sum(actual.values())} legacy occurrences, no additions).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
