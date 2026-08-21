#!/usr/bin/env python3
"""Generate runtime Dart calendar localization data from assets/calendar/*.json.

The JSON files are the source of truth for translators. Do not edit the generated
Dart file manually.
"""
from __future__ import annotations

import calendar
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "calendar"
OUTPUT = ROOT / "lib" / "services" / "calendar" / "calendar_localization_data.g.dart"
EXPECTED_FILES = [
    "it.json", "en.json", "fr.json", "es.json", "pt_PT.json",
    "pt_BR.json", "pl.json", "cs.json", "de.json", "zh_CN.json",
]
EXPECTED_LOCALES = {
    "it.json": "it", "en.json": "en", "fr.json": "fr", "es.json": "es",
    "pt_PT.json": "pt", "pt_BR.json": "pt_BR", "pl.json": "pl",
    "cs.json": "cs", "de.json": "de", "zh_CN.json": "zh_CN",
}

def expected_day_keys() -> set[str]:
    result: set[str] = set()
    for month in range(1, 13):
        for day in range(1, calendar.monthrange(2025, month)[1] + 1):
            result.add(f"{day}-{month}")
    return result


def validate_locale(path: Path, data: dict) -> None:
    expected_locale = EXPECTED_LOCALES[path.name]
    if data.get("locale") != expected_locale:
        raise ValueError(f"{path.name}: locale must be {expected_locale!r}")
    saints = data.get("saints")
    quotes = data.get("quotes")
    holidays = data.get("holidays")
    if not isinstance(saints, dict):
        raise ValueError(f"{path.name}: saints must be an object")
    expected = expected_day_keys()
    actual = set(saints)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise ValueError(f"{path.name}: saints must contain exactly 365 days; missing={missing[:5]} extra={extra[:5]}")
    if any(not isinstance(value, str) or not value.strip() for value in saints.values()):
        raise ValueError(f"{path.name}: every saint entry must be a non-empty string")
    if not isinstance(quotes, list) or len(quotes) != 128:
        raise ValueError(f"{path.name}: quotes must contain exactly 128 strings")
    if any(not isinstance(value, str) or not value.strip() for value in quotes):
        raise ValueError(f"{path.name}: every quote must be a non-empty string")
    if not isinstance(holidays, dict):
        raise ValueError(f"{path.name}: holidays must be an object")
    if any(not isinstance(value, str) or not value.strip() for value in holidays.values()):
        raise ValueError(f"{path.name}: every holiday must be a non-empty string")


def dart_json(value) -> str:
    # JSON object/list/string syntax is valid for the const Dart literals used here.
    return json.dumps(value, ensure_ascii=False, indent=2)


def main() -> int:
    missing_files = [name for name in EXPECTED_FILES if not (ASSET_DIR / name).is_file()]
    if missing_files:
        raise FileNotFoundError(f"Missing calendar localization files: {', '.join(missing_files)}")

    saints_by_locale: dict[str, dict[str, str]] = {}
    quotes_by_locale: dict[str, list[str]] = {}
    holidays_by_locale: dict[str, dict[str, str]] = {}

    for name in EXPECTED_FILES:
        path = ASSET_DIR / name
        data = json.loads(path.read_text(encoding="utf-8"))
        validate_locale(path, data)
        locale = data["locale"]
        saints_by_locale[locale] = data["saints"]
        quotes_by_locale[locale] = data["quotes"]
        holidays_by_locale[locale] = data["holidays"]

    generated = f'''// GENERATED CODE - DO NOT MODIFY BY HAND.\n// Source: assets/calendar/*.json\n// Run: python tool/generate_calendar_localizations.py\n\nconst Map<String, Map<String, String>> kCalendarSaintsByLocale = {dart_json(saints_by_locale)};\n\nconst Map<String, List<String>> kCalendarQuotesByLocale = {dart_json(quotes_by_locale)};\n\nconst Map<String, Map<String, String>> kCalendarHolidaysByLocale = {dart_json(holidays_by_locale)};\n'''
    OUTPUT.write_text(generated, encoding="utf-8")
    print(f"Generated {OUTPUT.relative_to(ROOT)} from {len(EXPECTED_FILES)} locale files")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"calendar localization generation failed: {exc}", file=sys.stderr)
        raise
