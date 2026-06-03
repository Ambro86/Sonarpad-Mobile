#!/usr/bin/env python3
"""
Test finale dei selettori corretti per EN, FR, ES.
"""
import requests
from bs4 import BeautifulSoup
import re

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )
}

# ---------------------------------------------------------------------------
# EN: Wikipedia inglese — "Holidays and observances" -> ul con "Christian feast day"
# La struttura è: h2 -> (nessun sibling diretto ul) -> dobbiamo trovare
# il div.mw-heading che wrappa h2, e poi il suo next sibling
# ---------------------------------------------------------------------------
def test_en():
    url = "https://en.wikipedia.org/wiki/January_1"
    res = requests.get(url, timeout=12, headers=HEADERS)
    doc = BeautifulSoup(res.text, "html.parser")
    
    print("[EN] Strategia 1: cerco div.mw-heading contenente 'holiday'")
    for div in doc.find_all("div", class_="mw-heading"):
        text = div.get_text(strip=True).lower()
        if "holiday" in text or "observance" in text:
            print(f"  Trovato div: {div.get_text(strip=True)!r}")
            sib = div.find_next_sibling()
            count = 0
            while sib and count < 10:
                print(f"  sib: {sib.name!r} class={sib.get('class')} -> {sib.get_text(' ',strip=True)[:100]!r}")
                if sib.name == "ul":
                    for li in sib.find_all("li")[:8]:
                        print(f"    li: {li.get_text(' ',strip=True)!r}")
                    break
                sib = sib.find_next_sibling()
                count += 1

    print("\n[EN] Strategia 2: cerco 'Christian feast day' o simile nel testo")
    # Cerca direttamente le ul che contengono testo "feast"
    for ul in doc.find_all("ul"):
        text = ul.get_text(" ", strip=True).lower()
        if "feast" in text or "saint" in text:
            items = ul.find_all("li")
            for li in items[:3]:
                t = li.get_text(" ", strip=True)
                if "saint" in t.lower() or "feast" in t.lower() or "blessed" in t.lower():
                    print(f"  li: {t!r}")


# ---------------------------------------------------------------------------
# FR: Wikipedia francese — "Saints des Églises chrétiennes"
# ---------------------------------------------------------------------------
def test_fr():
    url = "https://fr.wikipedia.org/wiki/1er_janvier"
    res = requests.get(url, timeout=12, headers=HEADERS)
    doc = BeautifulSoup(res.text, "html.parser")
    
    print("\n[FR] Cerco div.mw-heading contenente 'saints' o 'religieux'")
    for div in doc.find_all("div", class_="mw-heading"):
        text = div.get_text(strip=True).lower()
        if any(kw in text for kw in ("saints", "religieux", "fête", "liturgi", "chrétien")):
            print(f"  Trovato div: {div.get_text(strip=True)!r}")
            sib = div.find_next_sibling()
            count = 0
            while sib and count < 10:
                print(f"  sib: {sib.name!r} -> {sib.get_text(' ',strip=True)[:120]!r}")
                if sib.name == "ul":
                    for li in sib.find_all("li")[:5]:
                        print(f"    li: {li.get_text(' ',strip=True)!r}")
                    break
                sib = sib.find_next_sibling()
                count += 1

# ---------------------------------------------------------------------------
# ES: Wikipedia spagnola — "Santoral católico"
# La struttura: h3 è dentro div.mw-heading -> il sibling del div è la ul
# ---------------------------------------------------------------------------
def test_es():
    url = "https://es.wikipedia.org/wiki/1_de_enero"
    res = requests.get(url, timeout=12, headers=HEADERS)
    doc = BeautifulSoup(res.text, "html.parser")
    
    print("\n[ES] Cerco div.mw-heading contenente 'santoral' o 'santos'")
    for div in doc.find_all("div", class_="mw-heading"):
        text = div.get_text(strip=True).lower()
        if any(kw in text for kw in ("santoral", "santos", "fiestas", "celebraciones")):
            print(f"  Trovato div: {div.get_text(strip=True)!r}")
            sib = div.find_next_sibling()
            count = 0
            while sib and count < 10:
                print(f"  sib: {sib.name!r} -> {sib.get_text(' ',strip=True)[:120]!r}")
                if sib.name == "ul":
                    for li in sib.find_all("li")[:5]:
                        print(f"    li: {li.get_text(' ',strip=True)!r}")
                    break
                sib = sib.find_next_sibling()
                count += 1

if __name__ == "__main__":
    test_en()
    test_fr()
    test_es()
    print("\nDone.")
