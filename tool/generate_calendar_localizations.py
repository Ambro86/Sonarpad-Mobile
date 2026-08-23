#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CALENDAR_DIR = ROOT / 'assets' / 'calendar'
OUTPUT = ROOT / 'lib' / 'services' / 'calendar' / 'calendar_localization_data.g.dart'

# Preserve the established Sonarpad locale order so regeneration is stable.
SOURCE_ORDER = [
    'it', 'en', 'fr', 'es', 'pt_PT', 'pt_BR', 'pl', 'cs', 'de', 'zh_CN', 'uk'
]

locales = {}
for stem in SOURCE_ORDER:
    path = CALENDAR_DIR / f'{stem}.json'
    if not path.exists():
        continue
    data = json.loads(path.read_text(encoding='utf-8'))
    locales[data.get('locale') or stem] = data

parts = [
    '// GENERATED CODE - DO NOT MODIFY BY HAND.\n',
    '// Source: assets/calendar/*.json\n',
    '// Run: python tool/generate_calendar_localizations.py\n\n',
]
sections = [
    ('kCalendarSaintsByLocale', 'saints', 'Map<String, Map<String, String>>'),
    ('kCalendarQuotesByLocale', 'quotes', 'Map<String, List<String>>'),
    ('kCalendarHolidaysByLocale', 'holidays', 'Map<String, Map<String, String>>'),
]
for index, (name, field, dart_type) in enumerate(sections):
    values = {locale: data[field] for locale, data in locales.items()}
    parts.append(f'const {dart_type} {name} = ')
    parts.append(json.dumps(values, ensure_ascii=False, indent=2))
    parts.append(';\n' if index == len(sections) - 1 else ';\n\n')

OUTPUT.write_text(''.join(parts), encoding='utf-8')
print(f'Generated {OUTPUT} for {len(locales)} locales: {", ".join(locales)}')
