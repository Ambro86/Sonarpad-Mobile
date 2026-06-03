#!/usr/bin/env python3
"""Mostra i giorni con IT presente ma EN/FR/ES mancante."""
import json, os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_FILE = os.path.join(SCRIPT_DIR, "saints_cache.json")

with open(CACHE_FILE, "r", encoding="utf-8") as f:
    cache = json.load(f)

days_in_month = [31,28,31,30,31,30,31,31,30,31,30,31]
missing = {"en": [], "fr": [], "es": []}

for m in range(1, 13):
    for d in range(1, days_in_month[m-1]+1):
        key = f"{d}-{m}"
        entry = cache.get(key, {})
        it = entry.get("it", "")
        if not it:
            continue
        for lang in ("en", "fr", "es"):
            if not entry.get(lang):
                missing[lang].append((key, it))

for lang, items in missing.items():
    print(f"\n{lang.upper()} mancanti ({len(items)}):")
    for key, it in items:
        print(f"  {key:6s}  {it}")
