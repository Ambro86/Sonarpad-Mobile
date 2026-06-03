#!/usr/bin/env python3
"""Quick test: prova il nuovo scraper interwiki su 3 date."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "scripts"))
from scrape_saints import get_italian_saint, search_wikipedia_it, get_langlinks

tests = [
    (13, 1,  "Sant'Ilario di Poitiers"),
    (14, 2,  "San Valentino"),
    (13, 6,  "Sant'Antonio di Padova"),
    (25, 12, "Natale del Signore"),
]

for d, m, expected in tests:
    print(f"\n--- {d:02d}/{m:02d} (atteso: {expected}) ---")
    it = get_italian_saint(d, m)
    print(f"  IT (santodelgiorno): {it!r}")
    if it:
        wiki = search_wikipedia_it(it)
        print(f"  Wikipedia IT page:   {wiki!r}")
        if wiki:
            links = get_langlinks(wiki)
            print(f"  EN: {links.get('en','—')!r}")
            print(f"  FR: {links.get('fr','—')!r}")
            print(f"  ES: {links.get('es','—')!r}")

print("\nTest completato.")
