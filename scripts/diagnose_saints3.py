#!/usr/bin/env python3
"""
Diagnosi finale: stampa HTML grezzo attorno alle sezioni trovate.
"""
import requests
from bs4 import BeautifulSoup

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )
}

def diagnose_en_raw():
    url = "https://en.wikipedia.org/wiki/January_1"
    res = requests.get(url, timeout=12, headers=HEADERS)
    doc = BeautifulSoup(res.text, "html.parser")
    for header in doc.find_all(["h2","h3"]):
        if "holiday" in header.get_text(strip=True).lower():
            print("[EN] Header found:", header.get_text(strip=True))
            # Stampa i prossimi 800 chars di HTML grezzo
            raw = str(header)
            sib = header.find_next_sibling()
            for _ in range(20):
                if sib is None:
                    break
                raw += str(sib)
                if sib.name in ("h2",):
                    break
                sib = sib.find_next_sibling()
            print(raw[:2000])
            break

def diagnose_es_raw():
    url = "https://es.wikipedia.org/wiki/1_de_enero"
    res = requests.get(url, timeout=12, headers=HEADERS)
    doc = BeautifulSoup(res.text, "html.parser")
    for header in doc.find_all(["h2","h3"]):
        if "santoral" in header.get_text(strip=True).lower():
            print("\n[ES] Header found:", header.get_text(strip=True))
            # Stampa raw HTML del parent e del parent.parent
            parent = header.parent
            print("Parent tag:", parent.name, "class:", parent.get("class"))
            print("Parent HTML:", str(parent)[:2000])
            break

def diagnose_fr_alternatives():
    """Prova fonti alternative per il francese"""
    print("\n[FR] Prova fonti alternative:")
    tests = [
        ("universalis.fr", "https://www.universalis.fr/calendrier/"),
        ("aelf.org", "https://www.aelf.org/calendrier-liturgique/"),
        ("jesuites.com", "https://www.jesuites.com/saint-du-jour/"),
        ("croire.com", "https://croire.la-croix.com/Definitions/Fetes-et-saints/Saints/"),
    ]
    for name, url in tests:
        try:
            res = requests.get(url, timeout=8, headers=HEADERS)
            doc = BeautifulSoup(res.text, "html.parser")
            h1 = doc.find("h1")
            h1_text = h1.get_text(strip=True) if h1 else "None"
            print(f"  {res.status_code} {name}: h1={h1_text!r}")
            if res.status_code == 200:
                body = doc.body.get_text(" ", strip=True)[:200] if doc.body else ""
                print(f"    body: {body!r}")
        except Exception as e:
            print(f"  ERR {name}: {e}")
    
    # Prova anche Wikipedia FR che è sempre affidabile
    print("\n[FR via Wikipedia FR]")
    url = "https://fr.wikipedia.org/wiki/1er_janvier"
    res = requests.get(url, timeout=12, headers=HEADERS)
    doc = BeautifulSoup(res.text, "html.parser")
    print("Status:", res.status_code)
    for header in doc.find_all(["h2","h3"]):
        ht = header.get_text(strip=True).lower()
        print(f"  h: {header.get_text(strip=True)!r}")
        if any(kw in ht for kw in ("saint","fête","liturgi","culte","religion")):
            print("  *** INTERESSANTE ***")
            sib = header.find_next_sibling()
            count = 0
            while sib and count < 10:
                print(f"    sib: {sib.name!r} -> {sib.get_text(' ',strip=True)[:150]!r}")
                if sib.name in ("ul","ol"):
                    for li in sib.find_all("li")[:5]:
                        print(f"      li: {li.get_text(' ',strip=True)!r}")
                sib = sib.find_next_sibling()
                count += 1

if __name__ == "__main__":
    diagnose_en_raw()
    diagnose_es_raw()
    diagnose_fr_alternatives()
    print("\nDone.")
