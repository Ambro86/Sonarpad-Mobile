#!/usr/bin/env python3
"""
Pulisce dalla cache i giorni con risultati palesemente sbagliati:
- EN/FR/ES che non corrispondono al santo IT (nomi completamente diversi)
- Risultati di istituzioni, luoghi, persone moderne ecc.
"""
import json, os, re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_FILE = os.path.join(SCRIPT_DIR, "saints_cache.json")

# Parole che indicano un risultato chiaramente sbagliato nel titolo
BAD_TITLES = [
    "navratilova", "gita scolastica", "università", "diocesi",
    "salesiana", "salesians", "salesiens", "chiesa di", "basilica di",
    "comune di", "provincia di", "squadra", "municipio",
    "a school outing", "la balade", "christmastide", "temps de noël",
    "tiempo de navidad",  # questi li gestisce _lookup_special
]

def is_bad(val: str) -> bool:
    vl = val.lower()
    return any(bad in vl for bad in BAD_TITLES)

with open(CACHE_FILE, "r", encoding="utf-8") as f:
    cache = json.load(f)

cleaned = 0
for key, entry in cache.items():
    changed = False
    for lang in ("en", "fr", "es"):
        val = entry.get(lang, "")
        if val and is_bad(val):
            print(f"  Rimuovo [{key}][{lang}] = {val!r}")
            entry[lang] = ""
            changed = True
    if changed:
        cleaned += 1

print(f"\nVoci corrette: {cleaned}")

with open(CACHE_FILE, "w", encoding="utf-8") as f:
    json.dump(cache, f, ensure_ascii=False, indent=2)

print("Cache aggiornata.")
