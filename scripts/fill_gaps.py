#!/usr/bin/env python3
"""
Riempe i buchi in EN/FR/ES con due strategie:
  1. Traduzioni hardcoded per festività/santi universalmente noti
  2. Ricerca diretta sulla Wikipedia della lingua target
     (usa il nome italiano senza prefisso come query)
"""
import requests
from bs4 import BeautifulSoup
import json, os, re, time, sys

SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR    = os.path.dirname(SCRIPT_DIR)
CACHE_FILE  = os.path.join(SCRIPT_DIR, "saints_cache.json")
OUTPUT_DART = os.path.join(ROOT_DIR, "lib", "services", "calendar", "saints_data.dart")

HEADERS = {"User-Agent": "SonarpadSaintScraper/1.0 (educational)"}
TIMEOUT = 12
DELAY   = 1.0

# ---------------------------------------------------------------------------
# Hardcode per festività e santi molto noti che la ricerca automatica fatica
# ---------------------------------------------------------------------------
HARDCODED = {
    # key: (en, fr, es)  — None = lascia vuoto se già presente
    "1-1":  ("Solemnity of Mary, Mother of God", "Marie, Mère de Dieu",        "Solemnidad de Santa María, Madre de Dios"),
    "3-1":  ("Most Holy Name of Jesus",           "Très Saint Nom de Jésus",    "Santísimo Nombre de Jesús"),
    "18-2": ("Ash Wednesday",                      "Mercredi des Cendres",       "Miércoles de Ceniza"),
    "24-2": ("Saint Ethelbert of Kent",            "Éthelbert de Kent",           "Etelberto de Kent"),
    "25-3": ("Annunciation of the Lord",           "Annonciation du Seigneur",   "Anunciación del Señor"),
    "5-4":  ("Easter Sunday",                      "Dimanche de Pâques",         "Domingo de Resurrección"),
    "26-4": ("Our Lady of Good Counsel",           "Notre-Dame du Bon Conseil",  "Nuestra Señora del Buen Consejo"),
    "30-4": ("Pope Pius V",                        "Pie V",                      "Pío V"),
    "8-5":  ("Our Lady of the Rosary of Pompei",   "Notre-Dame du Rosaire de Pompéi", "Nuestra Señora del Rosario de Pompeya"),
    "19-5": ("Pope Celestine V",                   "Célestin V",                 "Celestino V"),
    "20-5": ("Bernardino of Siena",                "Bernardin de Sienne",        "Bernardino de Siena"),
    "22-5": ("Rita of Cascia",                     "Rita de Cascia",             "Rita de Casia"),
    "24-5": ("Pentecost",                          "Pentecôte",                  "Pentecostés"),
    "3-6":  ("Charles Lwanga and Companions",      "Charles Lwanga et compagnons","Carlos Lwanga y compañeros"),
    "6-6":  ("Norbert of Xanten",                  "Norbert de Xanten",          "Norberto de Xanten"),
    "16-7": ("Our Lady of Mount Carmel",           "Notre-Dame du Mont-Carmel",  "Nuestra Señora del Monte Carmelo"),
    "23-7": ("Bridget of Sweden",                  "Brigitte de Suède",          "Brígida de Suecia"),
    "26-7": ("Saints Joachim and Anne",            "Saints Joachim et Anne",     "Santos Joaquín y Ana"),
    "2-8":  ("Our Lady of the Angels",             "Notre-Dame des Anges",       "Nuestra Señora de los Ángeles"),
    "5-8":  ("Our Lady of the Snows",              "Notre-Dame des Neiges",      "Nuestra Señora de las Nieves"),
    "6-8":  ("Transfiguration of the Lord",        "Transfiguration du Seigneur","Transfiguración del Señor"),
    "7-8":  ("Gaetano Thiene",                     "Gaétan de Thiene",           "Cayetano de Thiene"),
    "15-8": ("Assumption of Mary",                 "Assomption de Marie",        "Asunción de María"),
    "21-8": ("Pope Pius X",                        "Pie X",                      "Pío X"),
    "23-8": ("Rose of Lima",                       "Rose de Lima",               "Rosa de Lima"),
    "27-8": ("Saint Monica",                       "Monique d'Hippone",          "Mónica de Hipona"),
    "29-8": ("Beheading of John the Baptist",      "Décollation de Jean-Baptiste","Martirio de Juan el Bautista"),
    "2-9":  ("Saint Elpidius",                     "Saint Elpide",               "San Elpidio"),
    "9-9":  ("Peter Claver",                       "Pierre Claver",              "Pedro Claver"),
    "16-9": ("Cyprian and Cornelius",              "Cyprien et Corneille",       "Cipriano y Cornelio"),
    "21-9": ("Matthew the Apostle",               "Matthieu l'Évangéliste",     "Mateo el Evangelista"),
    "23-9": ("Pio of Pietrelcina",                 "Pio de Pietrelcina",         "Pío de Pietrelcina"),
    "2-10": ("Guardian Angels",                   "Saints Anges gardiens",       "Santos Ángeles Custodios"),
    "11-10":("Pope John XXIII",                    "Jean XXIII",                 "Juan XXIII"),
    "19-10":("Paul of the Cross",                  "Paul de la Croix",           "Pablo de la Cruz"),
    "21-10":("Blessed Giuseppe Puglisi",           "Bienheureux Giuseppe Puglisi","Beato Giuseppe Puglisi"),
    "9-11": ("Dedication of the Lateran Basilica", "Dédicace de la basilique du Latran","Dedicación de la Basílica de Letrán"),
    "12-12":("Our Lady of Guadalupe",              "Notre-Dame de Guadalupe",    "Nuestra Señora de Guadalupe"),
    # Santi con timeout o ricerca errata
    "9-1":  ("Marcellinus of Ancona",              "Marcellin d'Ancône",         "Marcelino de Ancona"),
    "10-1": ("Saint Aldo",                         "Saint Aldric",               "San Aldo"),
    "14-1": ("Felix of Nola",                      "Félix de Nole",              "Félix de Nola"),
    "13-4": ("Pope Martin I",                      "Martin Ier",                 "Martín I"),
    "18-4": ("Galdinus of Milan",                  "Galdino de Milan",           "Galdino de Milán"),
    "20-4": ("Sarah of Antioch",                   "Sara d'Antioche",            "Sara de Antioquía"),
    "21-5": ("Victor of Caesarea",                 "Victor de Césarée",          "Víctor de Cesarea"),
    "23-6": ("Lanfranc",                           "Lanfranc de Cantorbéry",     "Lanfranco de Canterbury"),
    "1-7":  ("Saint Aaron",                        "Saint Aaron",                "San Aarón"),
    "6-7":  ("Maria Goretti",                      "Maria Goretti",              "María Goretti"),
    "10-7": ("Rufina and Secunda",                 "Rufine et Seconde",          "Rufina y Segunda"),
    "12-7": ("Hermogoras and Fortunatus",          "Hermagoras et Fortunat",     "Hermágoras y Fortunato"),
    "3-11": ("Saint Sylvia",                       "Silvia de Rome",             "Silvia de Roma"),
    "8-11": ("Geoffrey of Amiens",                 "Geoffroy d'Amiens",          "Godofredo de Amiens"),
    "31-10":("Lucilla of Rome",                    "Lucille de Rome",            "Lucila de Roma"),
    "20-12":("Saint Liberatus",                    "Saint Libérat",              "San Liberato"),
    "24-12":("Delphinus of Bordeaux",              "Delphin de Bordeaux",        "Delfín de Burdeos"),
    "30-12":("Eugene of Milan",                    "Eugène de Milan",            "Eugenio de Milán"),
    "13-2": ("Fosca and Maura",                    "Fosca et Maure",             "Fosca y Maura"),
    "3-3":  ("Cunigunde of Luxembourg",            "Cunégonde de Luxembourg",    "Cunegunda de Luxemburgo"),
    "7-3":  ("Perpetua and Felicity",              "Perpétue et Félicité",       "Perpetua y Felicidad"),
    "11-3": ("Constantine of Scotland",            "Constantin d'Écosse",        "Constantino de Escocia"),
    "20-3": ("Alexandra of Amiso",                 "Alexandra d'Amisos",         "Alejandra de Amiso"),
    "27-3": ("Rupert of Salzburg",                 "Rupert de Salzbourg",        "Ruperto de Salzburgo"),
    "31-3": ("Benjamin the Deacon",                "Benjamin le Diacre",         "Benjamín el Diácono"),
    "11-4": ("Gemma Galgani",                      "Gemma Galgani",              "Gema Galgani"),
    "19-4": ("Emma of Saxony",                     "Emma de Saxe",               "Emma de Sajonia"),
    "22-4": ("Leonidas of Alexandria",             "Léonide d'Alexandrie",       "Leónidas de Alejandría"),
    "15-2": ("Faustinus and Jovita",               "Faustino et Jovite",         "Faustino y Jovita"),
    "27-2": ("Gabriel of Our Lady of Sorrows",     "Gabriel de Notre-Dame des Douleurs","Gabriel de la Dolorosa"),
    "5-3":  ("Adrian of Caesarea",                 "Adrien de Césarée",          "Adriano de Cesarea"),
    "9-3":  ("Frances of Rome",                    "Françoise Romaine",          "Francisca Romana"),
    "25-4": ("Mark the Evangelist",                "Marc l'Évangéliste",         "Marcos el Evangelista"),
    "3-5":  ("Philip and James the Apostles",      "Philippe et Jacques",         "Felipe y Santiago Apóstoles"),
    "4-5":  ("Cyriacus of Jerusalem",              "Cyriaque de Jérusalem",      "Ciriaco de Jerusalén"),
    "18-5": ("Pope John I",                        "Jean Ier",                   "Juan I"),
    "1-6":  ("Justin Martyr",                      "Justin de Naplouse",         "Justino Mártir"),
    "5-6":  ("Boniface of Mainz",                  "Boniface de Mayence",        "Bonifacio de Maguncia"),
    "9-6":  ("Ephrem the Syrian",                  "Éphrem le Syrien",           "Efrén el Sirio"),
    "16-6": ("Quiricus and Julitta",               "Cyr et Julitte",             "Quirico y Julita"),
    "18-6": ("Marina of Antioch",                  "Marina d'Antioche",          "Marina de Antioquía"),
    "24-6": ("Nativity of John the Baptist",       "Nativité de saint Jean-Baptiste","Natividad de Juan el Bautista"),
    "28-7": ("Nazarius and Celsus",                "Nazaire et Celse",           "Nazario y Celso"),
    "30-8": ("Felix and Adauctus",                 "Félix et Adaucte",           "Félix y Adaucto"),
    "11-9": ("Protus and Hyacinth",                "Prote et Hyacinthe",         "Proto e Jacinto"),
    "26-10":("Folco Scotti",                       "Foulques Scotti",            "Folco Scotti"),
    "20-9": ("Korean Martyrs",                     "Martyrs de Corée",           "Mártires de Corea"),
    "10-6": ("Diana degli Andalò",                 "Diane degli Andalò",         "Diana de Andalo"),
    "2-6":  ("Marcellinus and Peter",              "Marcellin et Pierre",        "Marcelino y Pedro"),
    "11-8": ("Clare of Assisi",                    "Claire d'Assise",            "Clara de Asís"),
    "15-2": ("Faustinus and Jovita",               "Faustino et Jovite",         "Faustino y Jovita"),
    "9-12": ("Syrus of Pavia",                     "Syr de Pavie",               "Siro de Pavía"),
    "20-11":("Edmund of Abingdon",                 "Edmond Rich d'Abingdon",     "Edmundo de Abingdon"),
    "24-11":("Flora of Córdoba",                   "Flore de Cordoue",           "Flora de Córdoba"),
}

# ---------------------------------------------------------------------------
# Ricerca diretta su Wikipedia nella lingua target
# ---------------------------------------------------------------------------
_PREFIXES_IT = re.compile(
    r"^(Sant[i']?\s*|San\s+|Santa\s+|Santi\s+|Sante\s+|Beato\s+|Beata\s+|"
    r"Beati\s+|Venerabile\s+|SS\.\s*|Ss\.\s*)",
    re.IGNORECASE
)
def strip_it(name): return _PREFIXES_IT.sub("", name).strip()

LANG_PREFIX = {"en": "Saint", "fr": "Saint", "es": "San"}

def search_wiki_lang(name_it: str, lang: str) -> str | None:
    """Cerca direttamente su Wikipedia EN/FR/ES."""
    stripped = strip_it(name_it)
    if not stripped:
        return None

    # Parole significative (len > 3)
    STOP = {"degli", "dell", "della", "dello", "delle"}
    sig_words = [w for w in stripped.lower().split() if len(w) > 3 and w not in STOP]
    if not sig_words:
        return None

    prefix = LANG_PREFIX.get(lang, "Saint")
    queries = [stripped, f"{prefix} {stripped}"]

    api = f"https://{lang}.wikipedia.org/w/api.php"
    for q in queries:
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

                # REQUISITO: almeno una parola significativa nel titolo
                matched = sum(1 for w in sig_words if w in tl)
                if matched == 0:
                    continue

                score += matched * 3
                if stripped.lower() in tl:
                    score += 10
                if " of " in tl or " de " in tl or " di " in tl:
                    score += 2
                if len(title.split()) <= 1:
                    score -= 4

                # Penalità istituzioni / persone moderne
                bad = ("church", "chiesa", "basilica", "diocese", "university",
                       "chapel", "parish", "school", "football", "tennis", "actor",
                       "singer", "politician", "player", "club", "museum")
                if any(b in tl for b in bad):
                    score -= 15
                modern = ("footballer", "tennis", "actor", "singer", "politician",
                          "cyclist", "swimmer", "model", "director")
                if any(m in snippet for m in modern):
                    score -= 20

                if score > best_score:
                    best_score = score
                    best = title

            if best and best_score >= 1:
                return best

        except Exception as e:
            print(f"    [{lang}] errore ricerca {q!r}: {e}")
    return None

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def all_days():
    days_in_month = [31,28,31,30,31,30,31,31,30,31,30,31]
    for m in range(1,13):
        for d in range(1, days_in_month[m-1]+1):
            yield d, m

def main():
    with open(CACHE_FILE, "r", encoding="utf-8") as f:
        cache = json.load(f)

    # Step 1: applica hardcoded
    added_hard = 0
    for key, (en, fr, es) in HARDCODED.items():
        if key not in cache:
            cache[key] = {}
        for lang, val in (("en", en), ("fr", fr), ("es", es)):
            if not cache[key].get(lang) and val:
                cache[key][lang] = val
                added_hard += 1
    print(f"Hardcoded aggiunti: {added_hard}")

    # Step 2: cerca su Wikipedia target per i rimasti
    total_filled = 0
    for day, month in all_days():
        key = f"{day}-{month}"
        entry = cache.get(key, {})
        it = entry.get("it", "")
        if not it:
            continue

        needs = [l for l in ("en","fr","es") if not entry.get(l)]
        if not needs:
            continue

        print(f"  [{key}] {it}")
        changed = False
        for lang in needs:
            result = search_wiki_lang(it, lang)
            if result:
                entry[lang] = result
                print(f"    {lang.upper()}: {result!r}")
                total_filled += 1
                changed = True
            time.sleep(0.8)

        if changed:
            cache[key] = entry

    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)
    print(f"\nVoci trovate tramite ricerca: {total_filled}")

    # Step 3: rigenera Dart
    sys.path.insert(0, SCRIPT_DIR)
    from scrape_saints import generate_dart
    dart = generate_dart(cache)
    os.makedirs(os.path.dirname(OUTPUT_DART), exist_ok=True)
    with open(OUTPUT_DART, "w", encoding="utf-8") as f:
        f.write(dart)
    print(f"Rigenerato: {OUTPUT_DART}")

    # Statistiche
    total = sum(1 for _ in all_days())
    filled = {"it":0,"en":0,"fr":0,"es":0}
    for entry in cache.values():
        for lang in filled:
            if entry.get(lang): filled[lang] += 1
    print("\nStatistiche finali:")
    for lang, count in filled.items():
        pct = count*100//total
        bar = "#"*(pct//5) + "."*(20-pct//5)
        print(f"  {lang.upper()}: [{bar}] {count}/{total} ({pct}%)")

if __name__ == "__main__":
    main()
