#!/usr/bin/env python3
"""Generate the calendar's Dart constants from its UTF-8 JSON sources.

Run from any directory. Use --check to verify synchronization without writing.
The legacy locale order is retained so adding a locale does not rewrite the
existing translations. New locales are appended in alphabetical order.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = PROJECT_ROOT / "assets" / "calendar"
OUTPUT_PATH = (
    PROJECT_ROOT / "lib" / "services" / "calendar"
    / "calendar_localization_data.g.dart"
)
LEGACY_LOCALE_ORDER = (
    "it", "en", "fr", "es", "pt", "pt_BR", "pl", "cs", "de", "zh_CN",
    "uk", "ro",
)
HEADER = (
    "// GENERATED CODE - DO NOT MODIFY BY HAND.\n"
    "// Source: assets/calendar/*.json\n"
    "// Run: python tool/generate_calendar_localizations.py\n\n"
)


def dart_string(value: str) -> str:
    """Escape JSON strings plus Dart's interpolation marker."""
    return json.dumps(value, ensure_ascii=False).replace("$", "\\$")


def read_sources() -> dict[str, dict]:
    locales = {}
    for path in sorted(SOURCE_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        locale = data.get("locale")
        if not isinstance(locale, str) or not locale or locale in locales:
            raise ValueError(f"{path.name}: missing or duplicate locale")
        for field in ("saints", "holidays"):
            values = data.get(field)
            if not isinstance(values, dict) or any(
                not isinstance(key, str) or not isinstance(value, str)
                or not value.strip() for key, value in values.items()
            ):
                raise ValueError(f"{path.name}: invalid {field} map")
        quotes = data.get("quotes")
        if not isinstance(quotes, list) or any(
            not isinstance(value, str) or not value.strip() for value in quotes
        ):
            raise ValueError(f"{path.name}: invalid quotes list")
        locales[locale] = data

    reference = locales["en"]
    for locale, data in locales.items():
        if set(data["saints"]) != set(reference["saints"]):
            raise ValueError(f"{locale}: saint date keys differ from English")
        if len(data["quotes"]) != len(reference["quotes"]):
            raise ValueError(f"{locale}: quote count differs from English")
    order = [locale for locale in LEGACY_LOCALE_ORDER if locale in locales]
    order.extend(sorted(set(locales) - set(order)))
    return {locale: locales[locale] for locale in order}


def render(locales: dict[str, dict]) -> str:
    sections = []
    for field, name, value_type in (
        ("saints", "kCalendarSaintsByLocale", "Map<String, String>"),
        ("quotes", "kCalendarQuotesByLocale", "List<String>"),
        ("holidays", "kCalendarHolidaysByLocale", "Map<String, String>"),
    ):
        lines = [f"const Map<String, {value_type}> {name} = {{"]
        is_list = field == "quotes"
        for locale, data in locales.items():
            lines.append(f"  {dart_string(locale)}: {'[' if is_list else '{'}")
            if is_list:
                lines.extend(f"    {dart_string(value)}," for value in data[field])
            else:
                lines.extend(
                    f"    {dart_string(key)}: {dart_string(value)},"
                    for key, value in data[field].items()
                )
            lines.append("  ]," if is_list else "  },")
        lines.append("};")
        sections.append("\n".join(lines))
    return HEADER + "\n\n".join(sections) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = render(read_sources())
    current = OUTPUT_PATH.read_text(encoding="utf-8") if OUTPUT_PATH.exists() else ""
    if args.check:
        if current != expected:
            print("Calendar data is out of date; run this script without --check.")
            return 1
        print("Calendar data is synchronized.")
        return 0
    if current != expected:
        OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT_PATH.write_text(expected, encoding="utf-8", newline="\n")
    print("Calendar data generated from JSON sources.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
