#!/usr/bin/env python3
"""
Scrapa i santi del giorno per tutti i 365 giorni.

Strategia:
  1. Ottieni il nome IT da santodelgiorno.it (fonte autorevole per l'Italia)
  2. Cerca la pagina Wikipedia IT corrispondente (API search)
  3. Leggi i langlinks Wikipedia per ottenere la traduzione esatta in EN, FR, ES
     -> stessa persona, nomi ufficiali nelle rispettive lingue

Questo garantisce coerenza: tutte le lingue mostrano lo stesso santo,
tradotto correttamente, non il primo della lista Wikipedia che può essere
una festività civile o un santo secondario.

Uso:
  pip install requests beautifulsoup4
  python scripts/scrape_saints.py
"""

import requests
from bs4 import BeautifulSoup
import time
import json
import os
import re

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
HEADERS = {
    "User-Agent": (
        "SonarpadSaintScraper/1.0 "
        "(https://github.com/Ambro86/Sonarpad-Mobile; educational use) "
        "Mozilla/5.0"
    )
}
TIMEOUT = 14
DELAY   = 1.5          # pausa tra giornate (secondi) — Wikipedia è gentile ma non troppo

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR   = os.path.dirname(SCRIPT_DIR)

CACHE_FILE  = os.path.join(SCRIPT_DIR, "saints_cache.json")
OUTPUT_DART = os.path.join(ROOT_DIR, "lib", "services", "calendar", "saints_data.dart")

# ---------------------------------------------------------------------------
# Cache
# ---------------------------------------------------------------------------
def load_cache():
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def save_cache(cache):
    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)

# ---------------------------------------------------------------------------
# STEP 1 — Nome italiano da santodelgiorno.it
# ---------------------------------------------------------------------------
MONTHS_IT = [
    "gennaio","febbraio","marzo","aprile","maggio","giugno",
    "luglio","agosto","settembre","ottobre","novembre","dicembre"
]

def get_italian_saint(day: int, month: int) -> str | None:
    url = f"https://www.santodelgiorno.it/{day:02d}/{MONTHS_IT[month-1]}/"
    try:
        res = requests.get(url, timeout=TIMEOUT, headers=HEADERS)
        if res.status_code == 200:
            doc = BeautifulSoup(res.text, "html.parser")
            el = doc.select_one(".NomeSantoDiOggi")
            if el:
                text = el.get_text(" ", strip=True).strip()
                if text and text not in ("Santo del Giorno", "Cerca un santo:"):
                    return text
    except Exception as e:
        print(f"    [santodelgiorno] errore {day}/{month}: {e}")
    return None

# ---------------------------------------------------------------------------
# STEP 2 — Cerca pagina Wikipedia IT
# L'API di ricerca restituisce i risultati per pertinenza.
# Proviamo prima il nome completo, poi senza prefisso San/Sant'/Santa/Santi.
# ---------------------------------------------------------------------------
_PREFIXES = re.compile(
    r"^(Sant[i']?\s*|San\s+|Santa\s+|Santi\s+|Beato\s+|Beata\s+|"
    r"Beati\s+|Venerabile\s+|SS\.\s*|Ss\.\s*)",
    re.IGNORECASE
)

def _strip_prefix(name: str) -> str:
    return _PREFIXES.sub("", name).strip()

# Festività speciali che non sono biografie di santi ma hanno pagine Wikipedia note
_SPECIAL_PAGES = {
    "Natale del Signore":           {"it": "Natale",           "en": "Christmas",     "fr": "Noël",         "es": "Navidad"},
    "Epifania del Signore":         {"it": "Epifania",         "en": "Epiphany",      "fr": "Épiphanie",    "es": "Epifanía"},
    "Presentazione del Signore":    {"it": "Presentazione di Gesù al Tempio", "en": "Candlemas", "fr": "Présentation de Jésus au Temple", "es": "Candelaria"},
    "Assunzione di Maria":          {"it": "Assunzione di Maria","en": "Assumption of Mary","fr": "Assomption de Marie","es": "Asunción de María"},
    "Immacolata Concezione":        {"it": "Immacolata Concezione","en": "Immaculate Conception","fr": "Immaculée Conception","es": "Inmaculada Concepción"},
    "Tutti i Santi":                {"it": "Ognissanti",       "en": "All Saints' Day","fr": "Toussaint",     "es": "Todos los Santos"},
    "Battesimo di Gesù":            {"it": "Battesimo di Gesù","en": "Baptism of the Lord","fr": "Baptême du Seigneur","es": "Bautismo del Señor"},
    "Santissima Trinità":           {"it": "Santissima Trinità","en": "Trinity Sunday", "fr": "Trinité",       "es": "Santísima Trinidad"},
    "Corpus Domini":                {"it": "Corpus Domini",    "en": "Corpus Christi", "fr": "Fête-Dieu",     "es": "Corpus Christi"},
    "Cristo Re":                    {"it": "Cristo Re",        "en": "Christ the King","fr": "Christ Roi",    "es": "Cristo Rey"},
}

def _lookup_special(saint_name: str) -> dict | None:
    """Controlla se il nome corrisponde a una festività speciale."""
    name_clean = saint_name.strip()
    for key, vals in _SPECIAL_PAGES.items():
        if key.lower() in name_clean.lower() or name_clean.lower() in key.lower():
            return vals
    return None

def search_wikipedia_it(saint_name: str) -> str | None:
    """Restituisce il titolo della pagina Wikipedia IT più pertinente."""
    api = "https://it.wikipedia.org/w/api.php"
    stripped = _strip_prefix(saint_name)

    # Parole significative del nome (len > 3, escluse preposizioni comuni)
    STOP = {"degli", "dell", "della", "dello", "dalle", "alla", "alle"}
    sig_words = [w for w in stripped.lower().split() if len(w) > 3 and w not in STOP]

    # Se il nome stripped è una sola parola aggiungi "santo" per disambiguare
    if len(stripped.split()) == 1:
        queries = [f"santo {stripped}", saint_name]
    else:
        queries = [stripped, saint_name] if stripped != saint_name else [saint_name]

    for q in queries:
        if not q:
            continue
        params = {
            "action": "query",
            "list": "search",
            "srsearch": q,
            "format": "json",
            "srlimit": 5,
            "srnamespace": 0,
        }
        try:
            res = requests.get(api, params=params, timeout=TIMEOUT, headers=HEADERS)
            data = res.json()
            hits = data.get("query", {}).get("search", [])

            best = None
            best_score = -1

            for hit in hits:
                title = hit["title"]
                tl = title.lower()
                snippet = hit.get("snippet", "").lower()
                score = 0

                # REQUISITO MINIMO: almeno una parola significativa nel titolo
                words_in_title = sum(1 for w in sig_words if w in tl)
                if words_in_title == 0:
                    continue  # titolo completamente non correlato

                # Preferenza 1: nome intero nel titolo
                if stripped.lower() in tl:
                    score += 10
                # Preferenza 2: quante parole significative ci sono
                score += words_in_title * 3
                # Preferenza 3: titolo specifico (Nome di Luogo)
                if " di " in tl or " de " in tl:
                    score += 2
                # Penalità: titolo di una sola parola
                if len(title.split()) <= 1:
                    score -= 4
                # Penalità forte: è un luogo/istituzione, non una persona
                bad_kw = ("chiesa", "basilica", "diocesi", "università", "società",
                          "comune di", "provincia", "gita", "scuola", "stadio")
                if any(kw in tl for kw in bad_kw):
                    score -= 15
                # Penalità forte: persona moderna
                modern_kw = ("pilota", "calciatore", "attore", "cantante", "politico",
                             "tennista", "nuotatrice", "regista", "ciclista")
                if any(kw in snippet for kw in modern_kw):
                    score -= 20

                if score > best_score:
                    best_score = score
                    best = title

            if best and best_score >= 1:
                return best

        except Exception as e:
            print(f"    [wiki-search] errore per {q!r}: {e}")
    return None

# ---------------------------------------------------------------------------
# STEP 3 — Leggi langlinks Wikipedia IT per EN, FR, ES
# ---------------------------------------------------------------------------
TARGET_LANGS = ("en", "fr", "es")

def get_langlinks(page_title: str) -> dict:
    """
    Dato un titolo di pagina Wikipedia IT, restituisce un dict
    {lang: nome_nella_lingua} per EN, FR, ES.
    """
    api = "https://it.wikipedia.org/w/api.php"
    params = {
        "action": "query",
        "titles": page_title,
        "prop": "langlinks",
        "lllimit": 500,
        "format": "json",
    }
    try:
        res = requests.get(api, params=params, timeout=TIMEOUT, headers=HEADERS)
        data = res.json()
        pages = data.get("query", {}).get("pages", {})
        result = {}
        for page in pages.values():
            for ll in page.get("langlinks", []):
                if ll["lang"] in TARGET_LANGS:
                    result[ll["lang"]] = ll["*"]
        return result
    except Exception as e:
        print(f"    [langlinks] errore per {page_title!r}: {e}")
    return {}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
def all_days():
    days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    for m in range(1, 13):
        for d in range(1, days_in_month[m-1] + 1):
            yield d, m

def scrape_all(cache: dict) -> dict:
    total = sum(1 for _ in all_days())
    done  = 0

    for day, month in all_days():
        done += 1
        key = f"{day}-{month}"

        # Se già completo (it + almeno una lingua) salta
        if key in cache and cache[key].get("it") and any(
            cache[key].get(l) for l in TARGET_LANGS
        ):
            if done % 40 == 0:
                pct = done * 100 // total
                print(f"  >> Cache: {done}/{total} ({pct}%)")
            continue

        print(f"  [{day:02d}/{month:02d}] ...", end=" ", flush=True)

        entry = cache.get(key, {})

        # STEP 1: nome italiano
        it_name = entry.get("it") or get_italian_saint(day, month)
        if not it_name:
            print("IT=—")
            entry["it"] = ""
            cache[key] = entry
            save_cache(cache)
            time.sleep(DELAY)
            continue

        entry["it"] = it_name
        print(f"IT={it_name!r}", end=" ", flush=True)

        # STEP 2: controlla prima se è una festività speciale hardcoded
        special = _lookup_special(it_name)
        if special:
            for lang in TARGET_LANGS:
                if lang not in entry:
                    entry[lang] = special.get(lang, "")
            print(f"[special] EN={entry.get('en','')!r} FR={entry.get('fr','')!r} ES={entry.get('es','')!r}")
        else:
            # STEP 3: cerca pagina Wikipedia IT
            wiki_title = search_wikipedia_it(it_name)
            print(f"wiki={wiki_title!r}", end=" ", flush=True)

            # STEP 4: langlinks
            if wiki_title:
                links = get_langlinks(wiki_title)
                for lang in TARGET_LANGS:
                    if lang not in entry:
                        entry[lang] = links.get(lang, "")
                print(f"EN={entry.get('en','')!r} FR={entry.get('fr','')!r} ES={entry.get('es','')!r}")
            else:
                print("(nessuna pagina wiki trovata)")
                for lang in TARGET_LANGS:
                    if lang not in entry:
                        entry[lang] = ""


        cache[key] = entry
        save_cache(cache)

        if done % 40 == 0:
            pct = done * 100 // total
            # Statistiche veloce
            ok_en = sum(1 for e in cache.values() if e.get("en"))
            ok_fr = sum(1 for e in cache.values() if e.get("fr"))
            ok_es = sum(1 for e in cache.values() if e.get("es"))
            print(f"\n  >> Progresso: {done}/{total} ({pct}%) — EN:{ok_en} FR:{ok_fr} ES:{ok_es}\n")

        time.sleep(DELAY)

    return cache

# ---------------------------------------------------------------------------
# Generazione file Dart
# ---------------------------------------------------------------------------
def dart_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$")

def generate_dart(cache: dict) -> str:
    lines = [
        "// AUTO-GENERATED — non modificare manualmente.",
        "// Generato da scripts/scrape_saints.py",
        "//",
        "// Strategia:",
        "//   IT  -> santodelgiorno.it (fonte autorevole italiana)",
        "//   EN/FR/ES -> Wikipedia interwiki della pagina IT",
        "//              (stessa persona, nome ufficiale nella lingua)",
        "",
        "const Map<String, Map<String, String>> kSaintsData = {",
    ]

    days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    for m in range(1, 13):
        for d in range(1, days_in_month[m-1] + 1):
            key = f"{d}-{m}"
            entry = cache.get(key, {})
            it = dart_escape(entry.get("it", ""))
            en = dart_escape(entry.get("en", ""))
            fr = dart_escape(entry.get("fr", ""))
            es = dart_escape(entry.get("es", ""))
            if not any([it, en, fr, es]):
                continue
            lines.append(f'  "{key}": {{')
            if it:  lines.append(f'    "it": "{it}",')
            if en:  lines.append(f'    "en": "{en}",')
            if fr:  lines.append(f'    "fr": "{fr}",')
            if es:  lines.append(f'    "es": "{es}",')
            lines.append("  },")

    lines.append("};")
    lines.append("")
    return "\n".join(lines)

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    print("=" * 60)
    print("  Scraping santi — IT (santodelgiorno.it) + EN/FR/ES (Wikipedia interwiki)")
    print("=" * 60)
    print(f"  Cache:  {CACHE_FILE}")
    print(f"  Output: {OUTPUT_DART}")
    print()

    cache = load_cache()
    # Pulisce la cache vecchia che aveva dati sbagliati da Wikipedia diretta
    stale = [k for k, v in cache.items() if v.get("en") and "feast" in v["en"].lower()]
    if stale:
        print(f"  Rimozione {len(stale)} voci con dati sbagliati dalla cache precedente...")
        for k in stale:
            del cache[k]
        save_cache(cache)

    already = sum(1 for v in cache.values() if v.get("it") and any(v.get(l) for l in TARGET_LANGS))
    print(f"  Cache esistente: {already} giorni già completi")
    print()

    cache = scrape_all(cache)

    print()
    print("  Generazione saints_data.dart ...")
    dart_content = generate_dart(cache)

    os.makedirs(os.path.dirname(OUTPUT_DART), exist_ok=True)
    with open(OUTPUT_DART, "w", encoding="utf-8") as f:
        f.write(dart_content)

    print(f"  Salvato: {OUTPUT_DART}")

    # Statistiche finali
    total  = sum(1 for _ in all_days())
    filled = {"it": 0, "en": 0, "fr": 0, "es": 0}
    for entry in cache.values():
        for lang in filled:
            if entry.get(lang):
                filled[lang] += 1

    print()
    print("  Statistiche copertura:")
    for lang, count in filled.items():
        pct = count * 100 // total if total else 0
        bar = "#" * (pct // 5) + "." * (20 - pct // 5)
        print(f"    {lang.upper()}: [{bar}] {count}/{total} ({pct}%)")

if __name__ == "__main__":
    main()
