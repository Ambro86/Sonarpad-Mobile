#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets' / 'calendar'
OUT = ROOT / 'lib' / 'services' / 'calendar' / 'calendar_localization_data.g.dart'

entries=[]
for path in sorted(ASSETS.glob('*.json')):
    data=json.loads(path.read_text(encoding='utf-8'))
    entries.append((data['locale'], data))
# keep the historical ordering used by Sonarpad, then any future locales
order=['it','en','fr','es','pt','pt_BR','pl','cs','de','zh_CN','uk','ro']
rank={v:i for i,v in enumerate(order)}
entries.sort(key=lambda item: rank.get(item[0], 999))

def dart(value):
    return json.dumps(value, ensure_ascii=False)

def emit_map(name, field):
    lines=[f'const Map<String, Map<String, String>> {name} = {{']
    for locale,data in entries:
        lines.append(f'  {dart(locale)}: {{')
        for k,v in data[field].items():
            lines.append(f'    {dart(k)}: {dart(v)},')
        lines.append('  },')
    lines.append('};')
    return '\n'.join(lines)

def emit_lists(name, field):
    lines=[f'const Map<String, List<String>> {name} = {{']
    for locale,data in entries:
        lines.append(f'  {dart(locale)}: [')
        for v in data[field]:
            lines.append(f'    {dart(v)},')
        lines.append('  ],')
    lines.append('};')
    return '\n'.join(lines)

text='\n\n'.join([
    '// GENERATED CODE - DO NOT MODIFY BY HAND.\n// Source: assets/calendar/*.json\n// Run: python tool/generate_calendar_localizations.py',
    emit_map('kCalendarSaintsByLocale','saints'),
    emit_lists('kCalendarQuotesByLocale','quotes'),
    emit_map('kCalendarHolidaysByLocale','holidays'),
])+'\n'
OUT.write_text(text,encoding='utf-8')
print(f'Generated {OUT} with {len(entries)} locales')
