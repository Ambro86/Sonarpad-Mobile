#!/usr/bin/env python3
"""
Script di diagnosi: testa i selettori per EN, FR, ES
su una data specifica (1 gennaio) e stampa i risultati.
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

def diagnose_en(day=1, month=1):
    month_names = ["January","February","March","April","May","June",
                   "July","August","September","October","November","December"]
    url = f"https://en.wikipedia.org/wiki/{month_names[month-1]}_{day}"
    print(f"\n{'='*60}")
    print(f"[EN] URL: {url}")
    res = requests.get(url, timeout=12, headers=HEADERS)
    print(f"Status: {res.status_code}")
    doc = BeautifulSoup(res.text, "html.parser")
    
    print("\n--- Tutte le h2/h3 nella pagina ---")
    for h in doc.find_all(["h2","h3"]):
        print(f"  {h.name}: {h.get_text(strip=True)!r}")
    
    print("\n--- Cerca 'Feast' o 'Saint' nelle h2/h3 ---")
    for header in doc.find_all(["h2","h3"]):
        ht = header.get_text(strip=True).lower()
        if "feast" in ht or "saint" in ht:
            print(f"  TROVATO header: {header.get_text(strip=True)!r}")
            sib = header.find_next_sibling()
            while sib and sib.name not in ("ul","h2"):
                sib = sib.find_next_sibling()
            if sib and sib.name == "ul":
                for li in sib.find_all("li")[:5]:
                    print(f"    li: {li.get_text(' ',strip=True)!r}")
            else:
                print(f"  Nessuna ul trovata, prossimo sibling: {sib}")

def diagnose_fr(day=1, month=1):
    url = f"https://nominis.cef.fr/contenus/saint/fete.php?fete={day:02d}-{month:02d}"
    print(f"\n{'='*60}")
    print(f"[FR] URL: {url}")
    res = requests.get(url, timeout=12, headers=HEADERS)
    print(f"Status: {res.status_code}")
    doc = BeautifulSoup(res.text, "html.parser")
    
    print("\n--- Tutti gli h1/h2/h3 ---")
    for h in doc.find_all(["h1","h2","h3"]):
        print(f"  {h.name}: {h.get_text(strip=True)!r}")
    
    print("\n--- Classi interessanti ---")
    for cls in ["nomSaint","nom_saint","titreSaint","titre","saint","nom","fete"]:
        els = doc.select(f".{cls}")
        if els:
            for el in els[:3]:
                print(f"  .{cls}: {el.get_text(' ',strip=True)!r}")
    
    print("\n--- Prima 500 chars del body ---")
    body_text = doc.body.get_text(" ", strip=True) if doc.body else ""
    print(body_text[:500])

def diagnose_es(day=1, month=1):
    month_names = ["enero","febrero","marzo","abril","mayo","junio",
                   "julio","agosto","septiembre","octubre","noviembre","diciembre"]
    url = f"https://es.wikipedia.org/wiki/{day}_de_{month_names[month-1]}"
    print(f"\n{'='*60}")
    print(f"[ES] URL: {url}")
    res = requests.get(url, timeout=12, headers=HEADERS)
    print(f"Status: {res.status_code}")
    doc = BeautifulSoup(res.text, "html.parser")
    
    print("\n--- Tutte le h2/h3 nella pagina ---")
    for h in doc.find_all(["h2","h3"]):
        print(f"  {h.name}: {h.get_text(strip=True)!r}")
    
    print("\n--- Cerca 'santoral'/'santos'/'fiestas' nelle h2/h3 ---")
    for header in doc.find_all(["h2","h3"]):
        ht = header.get_text(strip=True).lower()
        if any(kw in ht for kw in ("santoral","santos","fiestas","celebraciones")):
            print(f"  TROVATO header: {header.get_text(strip=True)!r}")
            sib = header.find_next_sibling()
            while sib and sib.name not in ("ul","h2"):
                sib = sib.find_next_sibling()
            if sib and sib.name == "ul":
                for li in sib.find_all("li")[:5]:
                    print(f"    li: {li.get_text(' ',strip=True)!r}")
            else:
                print(f"  Nessuna ul trovata, prossimo sibling: {sib}")

if __name__ == "__main__":
    diagnose_en(1, 1)
    diagnose_fr(1, 1)
    diagnose_es(1, 1)
    print("\nDone.")
