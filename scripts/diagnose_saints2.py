#!/usr/bin/env python3
"""
Diagnosi dettagliata per EN, FR, ES: stampa struttura DOM attorno alle sezioni rilevanti.
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

def diagnose_en_deep(day=1, month=1):
    month_names = ["January","February","March","April","May","June",
                   "July","August","September","October","November","December"]
    url = f"https://en.wikipedia.org/wiki/{month_names[month-1]}_{day}"
    print(f"\n{'='*60}")
    print(f"[EN DEEP] {url}")
    res = requests.get(url, timeout=12, headers=HEADERS)
    doc = BeautifulSoup(res.text, "html.parser")
    
    # Cerca "Holidays and observances"
    for header in doc.find_all(["h2","h3"]):
        ht = header.get_text(strip=True).lower()
        if "holiday" in ht or "observance" in ht:
            print(f"\nFound section: {header.get_text(strip=True)!r}")
            # Stampa i prossimi 10 sibling
            sib = header.find_next_sibling()
            count = 0
            while sib and count < 15:
                print(f"  sibling tag={sib.name!r} class={sib.get('class')} text={sib.get_text(' ',strip=True)[:100]!r}")
                if sib.name == "ul":
                    for li in sib.find_all("li")[:10]:
                        print(f"    li: {li.get_text(' ',strip=True)!r}")
                    break
                sib = sib.find_next_sibling()
                count += 1

def diagnose_fr_urls(day=1, month=1):
    """Prova diversi URL per nominis.cef.fr"""
    urls = [
        f"https://nominis.cef.fr/contenus/saint/fete.php?fete={day:02d}-{month:02d}",
        f"https://nominis.cef.fr/contenus/saint/saint-du-jour.html",
        f"https://nominis.cef.fr/contenus/saint/{day:02d}-{month:02d}.html",
        f"https://nominis.cef.fr/contenus/saint/fete/{day:02d}-{month:02d}",
        # Altra idea: calendario.unitingchurch.org.au, o catholicsaints.info
        f"https://www.catholicsaints.info/calendar/{month_names_fr_url(month)}-{day}/",
        f"https://www.universalis.fr/calendrier/{month:02d}{day:02d}/",
    ]
    print(f"\n{'='*60}")
    print(f"[FR] Prova URL per {day:02d}/{month:02d}")
    for url in urls:
        try:
            res = requests.get(url, timeout=10, headers=HEADERS)
            print(f"  {res.status_code} -> {url}")
            if res.status_code == 200:
                doc = BeautifulSoup(res.text, "html.parser")
                # Stampa h1 e prime righe body
                h1 = doc.find("h1")
                h1_text = h1.get_text(strip=True) if h1 else 'None'
                print(f"    h1: {h1_text!r}")
                body = doc.body.get_text(" ",strip=True)[:300] if doc.body else ""
                print(f"    body: {body!r}")
        except Exception as e:
            print(f"  ERR -> {url}: {e}")

def month_names_fr_url(month):
    names = ["january","february","march","april","may","june",
             "july","august","september","october","november","december"]
    return names[month-1]

def diagnose_es_deep(day=1, month=1):
    month_names = ["enero","febrero","marzo","abril","mayo","junio",
                   "julio","agosto","septiembre","octubre","noviembre","diciembre"]
    url = f"https://es.wikipedia.org/wiki/{day}_de_{month_names[month-1]}"
    print(f"\n{'='*60}")
    print(f"[ES DEEP] {url}")
    res = requests.get(url, timeout=12, headers=HEADERS)
    doc = BeautifulSoup(res.text, "html.parser")
    
    # Cerca "Santoral" o "Celebraciones"
    for header in doc.find_all(["h2","h3"]):
        ht = header.get_text(strip=True).lower()
        if any(kw in ht for kw in ("santoral","celebraciones","santos","fiestas")):
            print(f"\nFound section: {header.get_text(strip=True)!r}")
            print(f"  header.parent tag={header.parent.name!r}")
            # Stampa i prossimi 15 sibling e parent children
            sib = header.find_next_sibling()
            count = 0
            while sib and count < 15:
                print(f"  sibling tag={sib.name!r} class={sib.get('class')} text={sib.get_text(' ',strip=True)[:100]!r}")
                if sib.name in ("ul","ol"):
                    for li in sib.find_all("li")[:5]:
                        print(f"    li: {li.get_text(' ',strip=True)!r}")
                    break
                # Cerca ul dentro il sibling
                inner_ul = sib.find("ul") if hasattr(sib,'find') else None
                if inner_ul:
                    print(f"  INNER ul found!")
                    for li in inner_ul.find_all("li")[:5]:
                        print(f"    li: {li.get_text(' ',strip=True)!r}")
                    break
                sib = sib.find_next_sibling()
                count += 1

if __name__ == "__main__":
    diagnose_en_deep(1, 1)
    diagnose_fr_urls(1, 1)
    diagnose_es_deep(1, 1)
    print("\nDone.")
