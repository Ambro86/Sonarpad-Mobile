// TMDB lookup uses the same interface labels on Windows, Mac, and mobile.
class TmdbCharacterStrings {
  static String get(String language, String key) {
    final normalized = language.toLowerCase().replaceAll('_', '-');
    return (_labels[normalized] ??
            _labels[normalized.split('-').first] ??
            _labels['en'])?[key] ??
        key;
  }

  static const Map<String, Map<String, String>> _labels = {
    "cs": {
      "unavailable": "Obrázky postav nejsou dostupné. Pokračuje standardní audiopopis.",
      "title": "Film nebo seriál (volitelné)",
      "year": "Rok (volitelné)",
      "production": "Vyberte film nebo seriál",
      "season": "Vyberte řadu",
      "episode": "Vyberte díl (volitelné)",
      "whole_season": "Celá řada / neznámý díl",
      "movie": "Film",
      "tv": "TV seriál",
      "searching": "Vyhledávání obsazení na TMDB…",
      "invalid_year": "Zadejte čtyřmístný rok nebo nechte pole prázdné.",
      "no_results": "Nebyl nalezen odpovídající film ani seriál.",
      "no_cast": "Informace o obsazení nejsou k dispozici.",
      "continue_without":
          "Vyhledávání TMDB se nezdařilo. Pokračovat se standardním audiopopisem?",
      "animation":
          "Jde o animovaný obsah. Fotografie herců nepomáhají identifikovat animované postavy a nebudou odeslány. Audiopopis bude pokračovat normálně.",
    },
    "de": {
      "unavailable": "Keine Figurenbilder verfügbar. Die normale Audiodeskription wird fortgesetzt.",
      "title": "Film oder Serie (optional)",
      "year": "Jahr (optional)",
      "production": "Film oder Serie auswählen",
      "season": "Staffel auswählen",
      "episode": "Episode auswählen (optional)",
      "whole_season": "Ganze Staffel / Episode unbekannt",
      "movie": "Film",
      "tv": "TV-Serie",
      "searching": "Besetzung auf TMDB suchen…",
      "invalid_year":
          "Geben Sie eine vierstellige Jahreszahl ein oder lassen Sie das Feld leer.",
      "no_results": "Kein passender Film oder keine passende Serie gefunden.",
      "no_cast": "Keine Besetzungsdaten verfügbar.",
      "continue_without":
          "Die TMDB-Suche ist fehlgeschlagen. Mit der normalen Audiodeskription fortfahren?",
      "animation":
          "Dies ist animierter Inhalt. Schauspielerfotos helfen nicht bei der Erkennung animierter Figuren und werden nicht gesendet. Die Audiodeskription wird normal fortgesetzt.",
    },
    "en": {
      "unavailable": "Character reference images unavailable. Continuing with standard audio description.",
      "title": "Film or series (optional)",
      "year": "Year (optional)",
      "production": "Choose film or series",
      "season": "Choose season",
      "episode": "Choose episode (optional)",
      "whole_season": "Entire season / episode unknown",
      "movie": "Film",
      "tv": "TV series",
      "searching": "Looking up cast on TMDB…",
      "invalid_year": "Enter a four-digit year or leave the year empty.",
      "no_results": "No matching film or series found.",
      "no_cast": "No cast information available.",
      "continue_without":
          "TMDB lookup could not be completed. Continue with the standard audio description?",
      "animation":
          "This is animated content. Actor portraits cannot identify animated characters and will not be sent. Audio description will continue normally.",
    },
    "es": {
      "unavailable": "Imágenes de personajes no disponibles. Continúa la audiodescripción estándar.",
      "title": "Película o serie (opcional)",
      "year": "Año (opcional)",
      "production": "Elegir película o serie",
      "season": "Elegir temporada",
      "episode": "Elegir episodio (opcional)",
      "whole_season": "Temporada completa / episodio desconocido",
      "movie": "Película",
      "tv": "Serie de TV",
      "searching": "Buscando reparto en TMDB…",
      "invalid_year":
          "Introduce un año de cuatro cifras o deja el campo vacío.",
      "no_results": "No se encontró ninguna película o serie coincidente.",
      "no_cast": "Información del reparto no disponible.",
      "continue_without":
          "No se pudo completar la búsqueda en TMDB. ¿Continuar con la audiodescripción normal?",
      "animation":
          "Este contenido es animado. Las fotos de los actores no identifican a los personajes animados y no se enviarán. La audiodescripción continuará normalmente.",
    },
    "fr": {
      "unavailable": "Images des personnages indisponibles. L’audiodescription standard continue.",
      "title": "Film ou série (facultatif)",
      "year": "Année (facultatif)",
      "production": "Choisir le film ou la série",
      "season": "Choisir la saison",
      "episode": "Choisir l’épisode (facultatif)",
      "whole_season": "Saison entière / épisode inconnu",
      "movie": "Film",
      "tv": "Série TV",
      "searching": "Recherche de la distribution sur TMDB…",
      "invalid_year":
          "Saisissez une année à quatre chiffres ou laissez le champ vide.",
      "no_results": "Aucun film ou série correspondant.",
      "no_cast": "Distribution indisponible.",
      "continue_without":
          "La recherche TMDB a échoué. Continuer avec l’audiodescription standard ?",
      "animation":
          "Ce contenu est animé. Les photos des acteurs ne permettent pas d’identifier les personnages animés et ne seront pas envoyées. L’audiodescription continuera normalement.",
    },
    "hi": {
      "unavailable": "पात्रों के चित्र उपलब्ध नहीं हैं। सामान्य ऑडियो विवरण जारी रहेगा।",
      "title": "फ़िल्म या सीरीज़ (वैकल्पिक)",
      "year": "वर्ष (वैकल्पिक)",
      "production": "फ़िल्म या सीरीज़ चुनें",
      "season": "सीज़न चुनें",
      "episode": "एपिसोड चुनें (वैकल्पिक)",
      "whole_season": "पूरा सीज़न / एपिसोड अज्ञात",
      "movie": "फ़िल्म",
      "tv": "टीवी सीरीज़",
      "searching": "TMDB पर कलाकार खोजे जा रहे हैं…",
      "invalid_year": "चार अंकों का वर्ष दर्ज करें या खाली छोड़ दें।",
      "no_results": "कोई मेल खाती फ़िल्म या सीरीज़ नहीं मिली।",
      "no_cast": "कलाकारों की जानकारी उपलब्ध नहीं है।",
      "continue_without":
          "TMDB खोज पूरी नहीं हो सकी। क्या सामान्य ऑडियो विवरण जारी रखें?",
      "animation":
          "यह एनिमेशन है। कलाकारों की तस्वीरें एनिमेटेड पात्रों की पहचान नहीं करतीं और नहीं भेजी जाएँगी। ऑडियो विवरण सामान्य रूप से जारी रहेगा।",
    },
    "id": {
      "unavailable": "Gambar karakter tidak tersedia. Deskripsi audio standar dilanjutkan.",
      "title": "Film atau serial (opsional)",
      "year": "Tahun (opsional)",
      "production": "Pilih film atau serial",
      "season": "Pilih musim",
      "episode": "Pilih episode (opsional)",
      "whole_season": "Seluruh musim / episode tidak diketahui",
      "movie": "Film",
      "tv": "Serial TV",
      "searching": "Mencari pemeran di TMDB…",
      "invalid_year": "Masukkan tahun empat digit atau kosongkan kolom.",
      "no_results": "Tidak ditemukan film atau serial yang sesuai.",
      "no_cast": "Informasi pemeran tidak tersedia.",
      "continue_without":
          "Pencarian TMDB tidak dapat diselesaikan. Lanjutkan dengan deskripsi audio biasa?",
      "animation":
          "Ini adalah konten animasi. Foto pemeran tidak mengidentifikasi karakter animasi dan tidak akan dikirim. Deskripsi audio akan berlanjut seperti biasa.",
    },
    "it": {
      "unavailable": "Immagini dei personaggi non disponibili. Proseguo con l’audiodescrizione standard.",
      "title": "Film o serie (facoltativo)",
      "year": "Anno (facoltativo)",
      "production": "Scegli il film o la serie",
      "season": "Scegli la stagione",
      "episode": "Scegli l’episodio (facoltativo)",
      "whole_season": "Intera stagione / episodio non noto",
      "movie": "Film",
      "tv": "Serie TV",
      "searching": "Ricerca del cast su TMDB…",
      "invalid_year":
          "Inserisci un anno di quattro cifre oppure lascia vuoto il campo.",
      "no_results": "Nessun film o serie corrispondente trovato.",
      "no_cast": "Informazioni sul cast non disponibili.",
      "continue_without":
          "Non è stato possibile completare la ricerca TMDB. Vuoi continuare con l’audiodescrizione normale?",
      "animation":
          "Questo contenuto è animato. Le foto degli attori non identificano i personaggi animati e non saranno inviate. L’audiodescrizione continuerà normalmente.",
    },
    "lt": {
      "unavailable": "Veikėjų vaizdų nėra. Tęsiamas įprastas garsinis vaizdavimas.",
      "title": "Filmas arba serialas (nebūtina)",
      "year": "Metai (nebūtina)",
      "production": "Pasirinkite filmą arba serialą",
      "season": "Pasirinkite sezoną",
      "episode": "Pasirinkite seriją (nebūtina)",
      "whole_season": "Visas sezonas / serija nežinoma",
      "movie": "Filmas",
      "tv": "TV serialas",
      "searching": "Ieškoma aktorių TMDB…",
      "invalid_year":
          "Įveskite keturių skaitmenų metus arba palikite lauką tuščią.",
      "no_results": "Atitinkančio filmo ar serialo nerasta.",
      "no_cast": "Aktorių duomenys nepasiekiami.",
      "continue_without":
          "Nepavyko užbaigti TMDB paieškos. Tęsti įprastą garsinį vaizdavimą?",
      "animation":
          "Tai animacinis turinys. Aktorių nuotraukos nepadeda atpažinti animacinių personažų ir nebus siunčiamos. Garsinis vaizdavimas bus tęsiamas įprastai.",
    },
    "pl": {
      "unavailable": "Brak ilustracji postaci. Standardowa audiodeskrypcja będzie kontynuowana.",
      "title": "Film lub serial (opcjonalnie)",
      "year": "Rok (opcjonalnie)",
      "production": "Wybierz film lub serial",
      "season": "Wybierz sezon",
      "episode": "Wybierz odcinek (opcjonalnie)",
      "whole_season": "Cały sezon / nieznany odcinek",
      "movie": "Film",
      "tv": "Serial TV",
      "searching": "Wyszukiwanie obsady w TMDB…",
      "invalid_year": "Wpisz czterocyfrowy rok lub pozostaw pole puste.",
      "no_results": "Nie znaleziono pasującego filmu ani serialu.",
      "no_cast": "Brak informacji o obsadzie.",
      "continue_without":
          "Nie udało się ukończyć wyszukiwania TMDB. Kontynuować standardową audiodeskrypcję?",
      "animation":
          "To treść animowana. Zdjęcia aktorów nie identyfikują animowanych postaci i nie zostaną wysłane. Audiodeskrypcja będzie kontynuowana normalnie.",
    },
    "pt-br": {
      "unavailable": "Imagens das personagens indisponíveis. A audiodescrição normal continua.",
      "title": "Filme ou série (opcional)",
      "year": "Ano (opcional)",
      "production": "Escolher filme ou série",
      "season": "Escolher temporada",
      "episode": "Escolher episódio (opcional)",
      "whole_season": "Temporada completa / episódio desconhecido",
      "movie": "Filme",
      "tv": "Série de TV",
      "searching": "Buscando elenco no TMDB…",
      "invalid_year":
          "Digite um ano com quatro dígitos ou deixe o campo vazio.",
      "no_results": "Nenhum filme ou série correspondente encontrado.",
      "no_cast": "Informações do elenco indisponíveis.",
      "continue_without":
          "Não foi possível concluir a busca no TMDB. Continuar com a audiodescrição normal?",
      "animation":
          "Este conteúdo é animado. As fotos dos atores não identificam personagens animados e não serão enviadas. A audiodescrição continuará normalmente.",
    },
    "pt": {
      "unavailable": "Imagens das personagens indisponíveis. A audiodescrição normal continua.",
      "title": "Filme ou série (opcional)",
      "year": "Ano (opcional)",
      "production": "Escolher filme ou série",
      "season": "Escolher temporada",
      "episode": "Escolher episódio (opcional)",
      "whole_season": "Temporada completa / episódio desconhecido",
      "movie": "Filme",
      "tv": "Série de TV",
      "searching": "A procurar elenco no TMDB…",
      "invalid_year":
          "Introduza um ano com quatro algarismos ou deixe o campo vazio.",
      "no_results": "Nenhum filme ou série correspondente encontrado.",
      "no_cast": "Informações do elenco indisponíveis.",
      "continue_without":
          "Não foi possível concluir a pesquisa no TMDB. Continuar com a audiodescrição normal?",
      "animation":
          "Este conteúdo é animado. As fotografias dos atores não identificam personagens animados e não serão enviadas. A audiodescrição continuará normalmente.",
    },
    "ru": {
      "unavailable": "Изображения персонажей недоступны. Продолжается обычная тифлокомментированная версия.",
      "title": "Фильм или сериал (необязательно)",
      "year": "Год (необязательно)",
      "production": "Выберите фильм или сериал",
      "season": "Выберите сезон",
      "episode": "Выберите эпизод (необязательно)",
      "whole_season": "Весь сезон / эпизод неизвестен",
      "movie": "Фильм",
      "tv": "Сериал",
      "searching": "Поиск актёрского состава в TMDB…",
      "invalid_year": "Введите год из четырёх цифр или оставьте поле пустым.",
      "no_results": "Подходящий фильм или сериал не найден.",
      "no_cast": "Сведения об актёрском составе недоступны.",
      "continue_without":
          "Не удалось завершить поиск TMDB. Продолжить обычное аудиоописание?",
      "animation":
          "Это анимация. Фотографии актёров не позволяют распознать анимационных персонажей и не будут отправлены. Аудиоописание продолжится в обычном режиме.",
    },
    "sr": {
      "unavailable": "Слике ликова нису доступне. Наставља се стандардни аудио-опис.",
      "title": "Film ili serija (opciono)",
      "year": "Godina (opciono)",
      "production": "Izaberite film ili seriju",
      "season": "Izaberite sezonu",
      "episode": "Izaberite epizodu (opciono)",
      "whole_season": "Cela sezona / nepoznata epizoda",
      "movie": "Film",
      "tv": "TV serija",
      "searching": "Pretraga glumačke ekipe na TMDB-u…",
      "invalid_year":
          "Unesite četvorocifrenu godinu ili ostavite polje prazno.",
      "no_results": "Nije pronađen odgovarajući film ili serija.",
      "no_cast": "Podaci o glumačkoj ekipi nisu dostupni.",
      "continue_without":
          "TMDB pretraga nije uspela. Nastaviti sa standardnim audio-opisom?",
      "animation":
          "Ovo je animirani sadržaj. Fotografije glumaca ne identifikuju animirane likove i neće biti poslate. Audio-opis će se nastaviti normalno.",
    },
    "sv": {
      "unavailable": "Figurbilder saknas. Standardiserad syntolkning fortsätter.",
      "title": "Film eller serie (valfritt)",
      "year": "År (valfritt)",
      "production": "Välj film eller serie",
      "season": "Välj säsong",
      "episode": "Välj avsnitt (valfritt)",
      "whole_season": "Hela säsongen / okänt avsnitt",
      "movie": "Film",
      "tv": "TV-serie",
      "searching": "Söker rollista på TMDB…",
      "invalid_year": "Ange ett fyrsiffrigt årtal eller lämna fältet tomt.",
      "no_results": "Ingen matchande film eller serie hittades.",
      "no_cast": "Ingen rollista tillgänglig.",
      "continue_without":
          "TMDB-sökningen kunde inte slutföras. Fortsätt med vanlig syntolkning?",
      "animation":
          "Detta är animerat innehåll. Skådespelarfoton identifierar inte animerade figurer och skickas inte. Syntolkningen fortsätter som vanligt.",
    },
    "uk": {
      "unavailable": "Зображення персонажів недоступні. Продовжується звичайний аудіоопис.",
      "title": "Фільм або серіал (необов’язково)",
      "year": "Рік (необов’язково)",
      "production": "Виберіть фільм або серіал",
      "season": "Виберіть сезон",
      "episode": "Виберіть епізод (необов’язково)",
      "whole_season": "Увесь сезон / епізод невідомий",
      "movie": "Фільм",
      "tv": "Серіал",
      "searching": "Пошук акторського складу в TMDB…",
      "invalid_year": "Введіть рік із чотирьох цифр або залиште поле порожнім.",
      "no_results": "Відповідний фільм або серіал не знайдено.",
      "no_cast": "Відомості про акторський склад недоступні.",
      "continue_without":
          "Не вдалося завершити пошук TMDB. Продовжити звичайний аудіоопис?",
      "animation":
          "Це анімація. Фотографії акторів не ідентифікують анімованих персонажів і не будуть надіслані. Аудіоопис продовжиться у звичайному режимі.",
    },
    "vi": {
      "unavailable": "Không có hình ảnh nhân vật. Tiếp tục mô tả âm thanh thông thường.",
      "title": "Phim hoặc loạt phim (tùy chọn)",
      "year": "Năm (tùy chọn)",
      "production": "Chọn phim hoặc loạt phim",
      "season": "Chọn mùa",
      "episode": "Chọn tập (tùy chọn)",
      "whole_season": "Cả mùa / không rõ tập",
      "movie": "Phim",
      "tv": "Phim truyền hình",
      "searching": "Đang tìm dàn diễn viên trên TMDB…",
      "invalid_year": "Nhập năm gồm bốn chữ số hoặc để trống.",
      "no_results": "Không tìm thấy phim hoặc loạt phim phù hợp.",
      "no_cast": "Không có thông tin dàn diễn viên.",
      "continue_without":
          "Không thể hoàn tất tìm kiếm TMDB. Tiếp tục mô tả âm thanh thông thường?",
      "animation":
          "Đây là nội dung hoạt hình. Ảnh diễn viên không giúp nhận diện nhân vật hoạt hình và sẽ không được gửi. Mô tả âm thanh vẫn tiếp tục bình thường.",
    },
    "zh": {
      "unavailable": "没有可用的角色图片。将继续标准音频描述。",
      "title": "电影或剧集（可选）",
      "year": "年份（可选）",
      "production": "选择电影或剧集",
      "season": "选择季",
      "episode": "选择集（可选）",
      "whole_season": "整季 / 集数未知",
      "movie": "电影",
      "tv": "电视剧",
      "searching": "正在 TMDB 查找演员表…",
      "invalid_year": "请输入四位数年份，或留空。",
      "no_results": "未找到匹配的电影或剧集。",
      "no_cast": "没有可用的演员信息。",
      "continue_without": "无法完成 TMDB 搜索。是否继续使用普通音频描述？",
      "animation": "这是动画内容。演员照片无法用于识别动画角色，因此不会发送。音频描述将正常继续。",
    },
    "nl": {
      "unavailable": "Geen referentiebeelden van personages beschikbaar. De standaard audiodescriptie gaat verder.",
      "title": "Film of serie (optioneel)",
      "year": "Jaar (optioneel)",
      "production": "Kies film of serie",
      "season": "Kies seizoen",
      "episode": "Kies aflevering (optioneel)",
      "whole_season": "Heel seizoen / onbekende aflevering",
      "movie": "Film",
      "tv": "TV-serie",
      "searching": "Cast zoeken op TMDB…",
      "invalid_year":
          "Voer een jaartal van vier cijfers in of laat het veld leeg.",
      "no_results": "Geen passende film of serie gevonden.",
      "no_cast": "Geen castgegevens beschikbaar.",
      "continue_without":
          "TMDB zoeken is niet gelukt. Doorgaan met de normale audiobeschrijving?",
      "animation":
          "Dit is animatie. Acteursfoto’s identificeren geen animatiefiguren en worden niet verzonden. De audiobeschrijving gaat normaal verder.",
    },
    "ro": {
      "unavailable": "Imaginile de referință ale personajelor nu sunt disponibile. Audiodescrierea continuă în modul standard.",
      "title": "Film sau serial (opțional)",
      "year": "An (opțional)",
      "production": "Alegeți filmul sau serialul",
      "season": "Alegeți sezonul",
      "episode": "Alegeți episodul (opțional)",
      "whole_season": "Sezon întreg / episod necunoscut",
      "movie": "Film",
      "tv": "Serial TV",
      "searching": "Se caută distribuția pe TMDB…",
      "invalid_year":
          "Introduceți un an din patru cifre sau lăsați câmpul gol.",
      "no_results": "Nu s-a găsit niciun film sau serial corespunzător.",
      "no_cast": "Distribuția nu este disponibilă.",
      "continue_without":
          "Căutarea TMDB nu a putut fi finalizată. Continuați cu audiodescrierea normală?",
      "animation":
          "Acesta este conținut animat. Fotografiile actorilor nu identifică personajele animate și nu vor fi trimise. Audiodescrierea va continua normal.",
    },
    "tr": {
      "unavailable": "Karakter görselleri kullanılamıyor. Standart sesli betimleme devam ediyor.",
      "title": "Film veya dizi (isteğe bağlı)",
      "year": "Yıl (isteğe bağlı)",
      "production": "Film veya dizi seçin",
      "season": "Sezon seçin",
      "episode": "Bölüm seçin (isteğe bağlı)",
      "whole_season": "Tüm sezon / bölüm bilinmiyor",
      "movie": "Film",
      "tv": "TV dizisi",
      "searching": "TMDB oyuncu kadrosu aranıyor…",
      "invalid_year": "Dört basamaklı bir yıl girin veya boş bırakın.",
      "no_results": "Eşleşen film veya dizi bulunamadı.",
      "no_cast": "Oyuncu kadrosu bilgisi yok.",
      "continue_without":
          "TMDB araması tamamlanamadı. Normal sesli betimlemeyle devam edilsin mi?",
      "animation":
          "Bu bir animasyondur. Oyuncu fotoğrafları animasyon karakterlerini tanımlamaz ve gönderilmez. Sesli betimleme normal şekilde devam eder.",
    },
  };
}
