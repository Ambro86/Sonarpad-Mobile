#!/usr/bin/env python3
"""
Fix manuale della cache: corregge voci palesemente sbagliate
e aggiunge traduzione hardcoded per santi noti con timeout o fallimento.
"""
import json, os, sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR   = os.path.dirname(SCRIPT_DIR)
CACHE_FILE = os.path.join(SCRIPT_DIR, "saints_cache.json")
OUTPUT_DART = os.path.join(ROOT_DIR, "lib", "services", "calendar", "saints_data.dart")

# ---------------------------------------------------------------------------
# Voci da azzerare (contenuto chiaramente sbagliato)
# ---------------------------------------------------------------------------
BAD_PATTERNS = [
    # persone moderne/famose non santi
    "palvin", "bandecchi", "banzato", "scaglione", "navratilova",
    # istituzioni/luoghi/opere d'arte
    "spedale degli innocenti", "ospedale degli innocenti",
    "spedale degli", "cappellone", "colosso di san",
    "caravaggio",           # dipinto, non il santo
    "gita scolastica", "school outing", "balade inoubliable",
    "università", "diocesi", "pozzo di san",
    "incontro di leone",    # dipinto storico
    "salesiana", "salesians", "salesiens",
    # pagine di disambiguazione inutili
    "della vittoria",       # non il santo Vittoria
    "ambrogio (disambigua)",
    # quadri/statue che hanno preso il posto del santo
    "cristo di san giovanni",
    "suore francescane della sacra famiglia",
]

def is_bad(val: str) -> bool:
    vl = val.lower()
    return any(p in vl for p in BAD_PATTERNS)

# ---------------------------------------------------------------------------
# Correzioni hardcoded per santi noti che hanno fallito
# chiave = "giorno-mese"
# ---------------------------------------------------------------------------
MANUAL_FIXES = {
    # timeout o ricerca sbagliata
    "10-11": {"en": "Pope Leo I",           "fr": "Léon Ier",               "es": "León I"},
    "17-11": {"en": "Elizabeth of Hungary", "fr": "Élisabeth de Hongrie",   "es": "Isabel de Hungría"},
    "4-11":  {"en": "Charles Borromeo",     "fr": "Charles Borromée",       "es": "Carlos Borromeo"},
    "26-12": {"en": "Saint Stephen",        "fr": "Saint Étienne",          "es": "San Esteban"},
    "28-12": {"en": "Holy Innocents",       "fr": "Saints Innocents",       "es": "Santos Inocentes"},
    "25-11": {"en": "Catherine of Alexandria", "fr": "Catherine d'Alexandrie", "es": "Catalina de Alejandría"},
    "4-12":  {"en": "Saint Barbara",        "fr": "Barbe de Nicomédie",     "es": "Bárbara de Nicomedia"},
    "7-12":  {"en": "Ambrose of Milan",     "fr": "Ambroise de Milan",      "es": "Ambrosio de Milán"},
    "13-11": {"en": "Didacus of Alcalá",    "fr": "Didace d'Alcalá",        "es": "Diego de Alcalá"},
    "14-12": {"en": "John of the Cross",    "fr": "Jean de la Croix",       "es": "Juan de la Cruz"},
    "17-3":  {"en": "Saint Patrick",        "fr": "Saint Patrick",          "es": "San Patricio"},
    "15-1":  {"en": "Saint Maurus",         "fr": "Saint Maur",             "es": "San Mauro"},
    "21-1":  {"en": "Saint Agnes",          "fr": "Agnès de Rome",          "es": "Inés de Roma"},
    "30-1":  {"en": "Martina of Rome",      "fr": "Martine de Rome",        "es": "Martina de Roma"},
    "31-1":  {"en": "John Bosco",           "fr": "Jean Bosco",             "es": "Juan Bosco"},
    "8-2":   {"en": "Jerome Emiliani",      "fr": "Jérôme Émilien",         "es": "Jerónimo Emiliani"},
    "9-2":   {"en": "Saint Apollonia",      "fr": "Apolline d'Alexandrie",  "es": "Apolonia de Alejandría"},
    "10-2":  {"en": "Scholastica of Nursia","fr": "Scholastique de Nursie", "es": "Escolástica de Nursia"},
    "20-1":  {"en": "Sebastian of Milan",   "fr": "Sébastien de Milan",     "es": "Sebastián de Milán"},
    "8-1":   {"en": "Maximus of Pavia",     "fr": "Maxime de Pavie",        "es": "Máximo de Pavía"},
    "25-1":  {"en": "Conversion of Paul the Apostle", "fr": "Conversion de Paul de Tarse", "es": "Conversión de Pablo de Tarso"},
    "29-12": {"en": "Saint David",          "fr": "Saint David",            "es": "San David"},
    "23-12": {"en": "Victoria of Rome",     "fr": "Victoire de Rome",       "es": "Victoria de Roma"},
    "19-12": {"en": "Darius of Nicomedia",  "fr": "Darius de Nicomédie",    "es": "Darío de Nicomedia"},
    "27-12": {"en": "Holy Family",          "fr": "Sainte Famille",         "es": "Sagrada Familia"},
    "10-12": {"en": "Our Lady of Loreto",   "fr": "Notre-Dame de Lorète",   "es": "Nuestra Señora de Loreto"},
    "28-11": {"en": "James of the Marches", "fr": "Jacques de la Marche",   "es": "Jaime de la Marca"},
}

# ---------------------------------------------------------------------------
# Carica cache, applica fix e rigenera Dart
# ---------------------------------------------------------------------------
with open(CACHE_FILE, "r", encoding="utf-8") as f:
    cache = json.load(f)

# Step 1: azzera valori sbagliati
fixed = 0
for key, entry in cache.items():
    for lang in ("en", "fr", "es"):
        val = entry.get(lang, "")
        if val and is_bad(val):
            print(f"  Azzero [{key}][{lang}] = {val!r}")
            entry[lang] = ""
            fixed += 1

# Step 2: applica correzioni manuali (solo se il campo è vuoto)
added = 0
for key, fixes in MANUAL_FIXES.items():
    if key not in cache:
        cache[key] = {}
    for lang, val in fixes.items():
        if not cache[key].get(lang):
            cache[key][lang] = val
            added += 1

print(f"\nVoci azzerate: {fixed}")
print(f"Voci aggiunte manualmente: {added}")

with open(CACHE_FILE, "w", encoding="utf-8") as f:
    json.dump(cache, f, ensure_ascii=False, indent=2)
print("Cache aggiornata.")

# Step 3: rigenera il file Dart
sys.path.insert(0, SCRIPT_DIR)
from scrape_saints import generate_dart, all_days

dart_content = generate_dart(cache)
os.makedirs(os.path.dirname(OUTPUT_DART), exist_ok=True)
with open(OUTPUT_DART, "w", encoding="utf-8") as f:
    f.write(dart_content)
print(f"Rigenerato: {OUTPUT_DART}")

# Statistiche finali
total  = sum(1 for _ in all_days())
filled = {"it": 0, "en": 0, "fr": 0, "es": 0}
for entry in cache.values():
    for lang in filled:
        if entry.get(lang):
            filled[lang] += 1

print("\nStatistiche copertura finale:")
for lang, count in filled.items():
    pct = count * 100 // total if total else 0
    bar = "#" * (pct // 5) + "." * (20 - pct // 5)
    print(f"  {lang.upper()}: [{bar}] {count}/{total} ({pct}%)")
