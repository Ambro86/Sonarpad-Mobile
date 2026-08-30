// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Sonarpad';

  @override
  String get appLanguage => 'Język aplikacji';

  @override
  String get settingsTheme => 'Motyw aplikacji';

  @override
  String get settingsThemeSystem => 'Systemowy';

  @override
  String get settingsThemeLight => 'Jasny';

  @override
  String get settingsThemeDark => 'Ciemny';

  @override
  String get settingsWeatherTemperatureUnit => 'Jednostka temperatury pogody';

  @override
  String get weatherTemperatureCelsius => 'Celsjusz (°C)';

  @override
  String get weatherTemperatureFahrenheit => 'Fahrenheit (°F)';

  @override
  String get homeSemanticsLabel => 'Sonarpad, ekran główny';

  @override
  String get settings => 'Ustawienia';

  @override
  String get settingsHint => 'Otwórz ustawienia';

  @override
  String get info => 'Informacje';

  @override
  String get infoHint => 'Otwórz informacje o aplikacji';

  @override
  String get categoryReading => 'Czytanie i dokumenty';

  @override
  String get categoryMedia => 'Media i rozrywka';

  @override
  String get sonarTubeTitle => 'SonarTube';

  @override
  String get sonarTubeSearchLabel => 'Szukaj filmów, kanałów lub playlist';

  @override
  String get sonarTubeSearchPrompt =>
      'Wpisz wyszukiwanie, aby znaleźć filmy, kanały i playlisty.';

  @override
  String get sonarTubeNoResults => 'Nie znaleziono filmów.';

  @override
  String get sonarTubeLoadMore => 'Wczytaj więcej wyników';

  @override
  String get sonarTubeVideo => 'Film';

  @override
  String get sonarTubeChannel => 'Kanał';

  @override
  String get sonarTubePlaylist => 'Playlista';

  @override
  String get sonarTubeLive => 'Na żywo';

  @override
  String get sonarTubeResolving => 'Przygotowywanie filmu…';

  @override
  String get sonarTubeFavorites => 'Ulubione';

  @override
  String get sonarTubeVideoFavorites => 'Ulubione filmy';

  @override
  String get sonarTubeChannelFavorites => 'Ulubione kanały';

  @override
  String get sonarTubeNoVideoFavorites => 'Brak ulubionych filmów lub playlist.';

  @override
  String get sonarTubeNoChannelFavorites => 'Brak ulubionych kanałów.';

  @override
  String get sonarTubeAddChannelFavorite => 'Dodaj kanał do ulubionych';

  @override
  String get sonarTubeRemoveChannelFavorite => 'Usuń kanał z ulubionych';

  @override
  String get sonarTubeRecentVideos => 'Ostatnie filmy';

  @override
  String get sonarTubeDeleteRecentVideo => 'Usuń film';

  @override
  String get sonarTubeNoRecentVideos => 'Brak ostatnio oglądanych filmów.';

  @override
  String get sonarTubeConfirmClearHistory => 'Czy na pewno chcesz wyczyścić historię ostatnio oglądanych filmów?';

  @override
  String get sonarTubeNoFavorites => 'Brak ulubionych filmów, kanałów lub playlist.';

  @override
  String get sonarTubeAddFavorite => 'Dodaj do ulubionych';

  @override
  String get sonarTubeShareVideo => 'Udostępnij film';

  @override
  String get sonarTubePreviousTrack => 'Przejdź do poprzedniego filmu';

  @override
  String get sonarTubeNextTrack => 'Przejdź do następnego filmu';

  @override
  String get sonarTubeGoToChannel => 'Przejdź do kanału';

  @override
  String get sonarTubeViewComments => 'Wyświetl komentarze';

  @override
  String get sonarTubeComments => 'Komentarze';

  @override
  String get sonarTubeNoComments => 'Brak dostępnych komentarzy.';

  @override
  String get sonarTubeLoadMoreComments => 'Wczytaj więcej komentarzy';

  @override
  String get sonarTubeTranscribeVideo => 'Transkrybuj film';

  @override
  String get sonarTubeTranscript => 'Transkrypcja';

  @override
  String get sonarTubeNoTranscript => 'Brak dostępnej transkrypcji dla tego filmu.';

  @override
  String get sonarTubeCopyTranscript => 'Kopiuj transkrypcję';

  @override
  String get sonarTubeTranscriptCopied => 'Transkrypcja została skopiowana do schowka';

  @override
  String get sonarTubeTranscriptSavedInDocuments => 'Transkrypcja została zapisana w Dokumentach.';

  @override
  String get sonarTubeShareChannel => 'Udostępnij kanał';

  @override
  String get sonarTubeSharePlaylist => 'Udostępnij playlistę';

  @override
  String get sonarTubeRemoveFavorite => 'Usuń z ulubionych';

  @override
  String sonarTubeFavoriteAdded(String name) {
    return 'Dodano $name do ulubionych.';
  }

  @override
  String sonarTubeFavoriteRemoved(String name) {
    return 'Usunięto $name z ulubionych.';
  }

  @override
  String get categoryUtilities => 'Wyszukiwanie i narzędzia';

  @override
  String get voiceDictionaryTitle => 'Słownik głosowy';

  @override
  String get voiceDictionaryAdd => 'Dodaj wpis do słownika';

  @override
  String get voiceDictionaryOriginalWord => 'Oryginalne słowo';

  @override
  String get voiceDictionaryReplacementWord => 'Słowo zastępcze';

  @override
  String get voiceDictionaryMatchCase => 'Rozróżniaj wielkie i małe litery';

  @override
  String get voiceDictionaryIgnoreCase => 'Ignoruj wielkość liter';

  @override
  String get voiceDictionaryEntries => 'Wpisy słownika';

  @override
  String get voiceDictionaryEmpty => 'Brak wpisów w słowniku.';

  @override
  String get voiceDictionaryRemove => 'Usuń wybrany wpis';

  @override
  String get voiceDictionaryOriginalRequired => 'Wpisz oryginalne słowo.';

  @override
  String get convertMediaTitle => 'Konwertuj multimedia';

  @override
  String get convertMediaInput => 'Plik do konwersji';

  @override
  String get convertMediaOutput => 'Folder zapisu';

  @override
  String get convertMediaImage => 'Obraz';

  @override
  String get convertMediaBrowse => 'Przeglądaj...';

  @override
  String get convertMediaFormat => 'Format';

  @override
  String get convertMediaBitrate => 'Przepływność (kbps)';

  @override
  String get convertMediaOggQuality => 'Jakość (q)';

  @override
  String get convertMediaFlacCompression => 'Poziom kompresji';

  @override
  String get convertMediaWavBitDepth => 'Głębia bitowa WAV';

  @override
  String get convertMediaReady => 'Gotowe.';

  @override
  String get convertMediaRunning => 'Konwersja w toku...';

  @override
  String get convertMediaDone => 'Konwersja zakończona.';

  @override
  String get convertMediaButton => 'Konwertuj';

  @override
  String get convertMediaNoInput => 'Wybierz plik do konwersji.';

  @override
  String get convertMediaNoOutput => 'Wybierz folder zapisu.';

  @override
  String get convertMediaOutputNotWritable =>
      'Wybrany folder nie jest bezpośrednio dostępny. Plik zostanie zapisany w wewnętrznym folderze Sonarpad; po zakończeniu konwersji możesz go udostępnić lub zapisać w aplikacji Pliki.';

  @override
  String get convertMediaNoImage => 'Wybierz obraz dla filmu.';

  @override
  String get convertMediaSamePath =>
      'Plik po konwersji musi być inny niż plik źródłowy.';

  @override
  String get convertMediaInvalidBitrate =>
      'Nieprawidłowa przepływność. Wpisz wartość od 64 do 320 kbps.';

  @override
  String convertMediaFailed(Object error) {
    return 'Konwersja nie powiodła się: $error';
  }

  @override
  String get donations => 'Darowizny';

  @override
  String get donationsHint => 'Wesprzyj rozwój Sonarpad';

  @override
  String get loading => 'Ładowanie';

  @override
  String get ttsVoiceLanguage => 'Język głosu TTS';

  @override
  String get ttsVoice => 'Głos TTS';

  @override
  String get saveSettings => 'Zapisz ustawienia';

  @override
  String get settingsSaved => 'Ustawienia zapisane.';

  @override
  String get settingsSavedTitle => 'Ustawienia zapisane';

  @override
  String get sonarpadCodeValidTitle => 'Kod prawidłowy';

  @override
  String get sonarpadCodeValidMessage =>
      'Kod Sonarpad jest prawidłowy. Ustawienia zapisane.';

  @override
  String get sonarpadCodeInvalidTitle => 'Kod nieprawidłowy';

  @override
  String get sonarpadCodeInvalidMessage =>
      'Wpisany kod Sonarpad jest nieprawidłowy. Sprawdź, czy został skopiowany bez dodatkowych spacji.';

  @override
  String get infoDescription =>
      'Sonarpad to prosta aplikacja, ale bogata w funkcje. Została zaprojektowana tak, aby była dostępna z VoiceOver dla osób niewidomych i słabowidzących: pozwala słuchać wiadomości, wyszukiwać podcasty i subskrybować je, importować artykuły z Wikipedii, dodawać dokumenty do biblioteki, zapisywać je i edytować. Sonarpad jest stale aktualizowany, a każda funkcja ma ułatwiać codzienne życie.';

  @override
  String get infoAuthor => 'Autor: Ambrogio Riili';

  @override
  String get donationsIntro =>
      'Sonarpad powstał początkowo z osobistych potrzeb, ale z czasem stał się bardziej rozbudowaną aplikacją. Jego rozwój wymaga stałej pracy: ulepszania funkcji, poprawiania błędów, szukania nowych pomysłów i dokładnego testowania każdej funkcji.\n\nJeśli Sonarpad jest dla Ciebie przydatny i chcesz wesprzeć jego rozwój, możesz przekazać darowiznę.';

  @override
  String get donationsPaypalDesc =>
      'Możesz przekazać darowiznę przez PayPal pod tym linkiem:\nhttps://www.paypal.me/ambrogio86\nJeśli to możliwe, wpisz w tytule płatności „Sonarpad”.';

  @override
  String get donationsBankDesc =>
      'Możesz także wesprzeć projekt przelewem bankowym na konto należące do Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nJeśli to możliwe, podaj jasny tytuł płatności, na przykład „Sonarpad”.';

  @override
  String get donationsThanks =>
      'Każda osoba wspierająca projekt zostanie wymieniona w aplikacji i w repozytorium GitHub w sekcji wspierających, chyba że poprosi o anonimowość lub użycie pseudonimu.\n\nDziękuję Jiriemu Holzingerowi i Paoli Vagata za ich wkład.\nZa tłumaczenie na czeski dziękuję Radkowi Žaludowi i Jiriemu Holzingerowi.\nZa tłumaczenie na hiszpański dziękuję Arturo Fernandezowi Rivasowi.\n\nOgromne podziękowania dla Leonardo Graziano, Paolo Marcelli, Tiziano Ferraro oraz całej grupy Tecnologia accessibile za całe wsparcie w codziennym ulepszaniu tego wspaniałego projektu.';

  @override
  String get news => 'Wiadomości';

  @override
  String get newsHint => 'Otwórz wiadomości z Google News RSS';

  @override
  String get podcasts => 'Podcasty';

  @override
  String get podcastsHint =>
      'Subskrybuj podcasty, odtwarzaj lub pobieraj odcinki';

  @override
  String get importFromWikipedia => 'Wikipedia';

  @override
  String get wikipediaHint => 'Wyszukaj artykuł w Wikipedii i zaimportuj tekst';

  @override
  String get newsCategoryTop => 'Najważniejsze';

  @override
  String get settingsHomeGrouping =>
      'Włącz grupowanie ikon na ekranie głównym w kategorie';

  @override
  String get settingsHomeGroupingHint =>
      'Po wyłączeniu główne ikony będą pokazane jako jedna lista bez podfolderów';

  @override
  String get newsCategoryMyCity => 'Moje miasto';

  @override
  String get newsLocalCityLabel => 'Wpisz swoje miasto';

  @override
  String get newsLocalCityHint =>
      'Popraw miasto używane dla wiadomości lokalnych';

  @override
  String get update => 'Aktualizuj';

  @override
  String get moveUp => 'Przenieś w górę';

  @override
  String get moveDown => 'Przenieś w dół';

  @override
  String get hide => 'Ukryj';

  @override
  String get moveToPosition => 'Przenieś na pozycję';

  @override
  String positionLabel(int position, String targetName) {
    return 'Pozycja $position: przed $targetName';
  }

  @override
  String get positionLabelLast => 'Ostatnia pozycja';

  @override
  String get restoreHiddenSources => 'Przywróć ukryte źródła';

  @override
  String get addCustomNewsSource => 'Dodaj własne źródło RSS';

  @override
  String get newsSourceName => 'Nazwa źródła lub strony';

  @override
  String get newsSourceUrlOrSearch =>
      'URL strony, kanał RSS albo słowo do wyszukania';

  @override
  String get deleteNewsSource => 'Usuń';

  @override
  String get importRssSourcesFromOpml => 'Importuj źródła RSS z OPML';

  @override
  String get exportRssSourcesToOpml => 'Eksportuj źródła RSS do OPML';

  @override
  String rssImportComplete(int count) {
    return 'Zaimportowane źródła RSS: $count';
  }

  @override
  String rssImportError(Object error) {
    return 'Błąd importu RSS: $error';
  }

  @override
  String get rssExportComplete => 'Źródła RSS wyeksportowane';

  @override
  String rssExportError(Object error) {
    return 'Błąd eksportu RSS: $error';
  }

  @override
  String get articleTextSemantics => 'Tekst artykułu';

  @override
  String get newsLanguage => 'Język wiadomości';

  @override
  String get loadingNews => 'Ładowanie wiadomości';

  @override
  String error(Object error) {
    return 'Błąd: $error';
  }

  @override
  String get noNewsFound => 'Nie znaleziono wiadomości';

  @override
  String get loadingArticle => 'Ładowanie artykułu';

  @override
  String get noFullArticleFound =>
      'Pełny artykuł jest niedostępny. Pokazuję streszczenie z kanału.';

  @override
  String get italian => 'Włoski';

  @override
  String get english => 'Angielski';

  @override
  String get french => 'Francuski';

  @override
  String get spanish => 'Hiszpański';

  @override
  String get german => 'Niemiecki';

  @override
  String get newsSource => 'Źródło wiadomości';

  @override
  String get article => 'Artykuł';

  @override
  String get articlePreview => 'Podgląd artykułu';

  @override
  String get readFullArticle => 'Przeczytaj cały artykuł';

  @override
  String get extractingReaderArticleText =>
      'Wyodrębniam tekst w trybie czytania...';

  @override
  String get extractingVisibleArticleText =>
      'Wyodrębniam widoczny tekst ze strony...';

  @override
  String source(String source) {
    return 'Źródło: $source';
  }

  @override
  String get readyStatus => 'Gotowe.';

  @override
  String get preparingEdgeTts => 'Przygotowuję czytanie Edge TTS w blokach...';

  @override
  String get noTextToRead => 'Brak tekstu do przeczytania.';

  @override
  String chunkCreated(int index, int total) {
    return 'Utworzono blok $index z $total. Trwa czytanie...';
  }

  @override
  String playingChunk(int index, int total, int size) {
    return 'Odtwarzam blok $index z $total ($size bajtów)...';
  }

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) {
    return 'Czytanie zakończone. Utworzone bloki: $readyChunks/$totalChunks. Biblioteka: $libraryPath';
  }

  @override
  String get libraryNotSpecified => 'nie podano';

  @override
  String get readingStopped => 'Czytanie przerwane.';

  @override
  String edgeTtsError(Object error) {
    return 'Błąd Edge TTS: $error';
  }

  @override
  String audioChunksReady(int readyChunks, int totalChunks) {
    return 'Gotowe bloki audio: $readyChunks / $totalChunks';
  }

  @override
  String get readingInProgress => 'Czytanie w toku...';

  @override
  String get readWithEdgeTts => 'Rozpocznij czytanie';

  @override
  String get stopReading => 'Zatrzymaj czytanie';

  @override
  String get startReading => 'Rozpocznij czytanie';

  @override
  String get resumeReading => 'Wznów czytanie';

  @override
  String get pauseReading => 'Pauza';

  @override
  String get openOriginalArticle => 'Otwórz oryginalny artykuł';

  @override
  String get searchPodcasts => 'Szukaj podcastów';

  @override
  String get podcastName => 'Nazwa podcastu';

  @override
  String get podcastSearchHint =>
      'Przykład: technologia, historia, nazwa podcastu...';

  @override
  String get searchCountry => 'Kraj wyszukiwania';

  @override
  String get browsePodcastCountries => 'Przeglądaj według kraju';

  @override
  String get podcastCountries => 'Kraje podcastów';

  @override
  String get podcastCategory => 'Kategoria podcastu';

  @override
  String get browsePodcastCategories => 'Przeglądaj kategorie';

  @override
  String get selectedPodcastCategory => 'Wybrana kategoria';

  @override
  String get selectedRecently => 'ostatnio wybrane';

  @override
  String get podcastCategories => 'Kategorie podcastów';

  @override
  String get countryItaly => 'Włochy';

  @override
  String get countryUnitedStatesEnglish => 'Stany Zjednoczone / angielski';

  @override
  String get countryUnitedKingdom => 'Wielka Brytania';

  @override
  String get countrySpain => 'Hiszpania';

  @override
  String get countryFrance => 'Francja';

  @override
  String get searchInProgress => 'Wyszukiwanie w toku...';

  @override
  String get newsReadArticles => 'Przeczytane artykuły';

  @override
  String get weatherRecentCities => 'Ostatnie miasta';

  @override
  String podcastResultsFound(int count) {
    return 'Znaleziono podcasty: $count';
  }

  @override
  String podcastSearchError(Object error) {
    return 'Błąd wyszukiwania podcastów: $error';
  }

  @override
  String subscribedTo(String title) {
    return 'Zasubskrybowano $title';
  }

  @override
  String subscriptionError(Object error) {
    return 'Błąd subskrypcji: $error';
  }

  @override
  String podcastSubscriptionError(Object error) {
    return 'Błąd subskrypcji podcastu: $error';
  }

  @override
  String get searchResults => 'Wyniki wyszukiwania';

  @override
  String get podcastInfo => 'Informacje o podcaście';

  @override
  String get subscribe => 'Subskrybuj';

  @override
  String get openPodcast => 'Otwórz podcast';

  @override
  String get viewEpisodes => 'Zobacz odcinki';

  @override
  String get podcastAuthor => 'Autor';

  @override
  String get noPodcastDescription => 'Brak opisu.';

  @override
  String get noPodcastResults => 'Nie znaleziono podcastów.';

  @override
  String get loadingPodcastInfo => 'Ładowanie informacji o podcaście';

  @override
  String get podcastArtwork => 'Okładka podcastu';

  @override
  String get addFeedUrlManually => 'Dodaj ręcznie adres kanału RSS';

  @override
  String get podcastFeedUrl => 'Adres kanału RSS podcastu';

  @override
  String get subscribeFromUrl => 'Subskrybuj z URL';

  @override
  String get subscribedPodcasts => 'Subskrybowane podcasty';

  @override
  String get noSubscribedPodcasts =>
      'Brak subskrybowanych podcastów. Wyszukaj podcast i dotknij wyniku, aby go subskrybować.';

  @override
  String get localAudioFiles => 'Lokalne pliki audio';

  @override
  String get noLocalAudioFiles => 'Nie znaleziono lokalnych plików audio.';

  @override
  String get importAudioFromITunes => 'Importuj lokalne pliki audio';

  @override
  String localAudioFilesFound(int count) {
    return 'Znaleziono lokalne pliki audio: $count';
  }

  @override
  String get importPodcastsFromFile => 'Importuj podcasty z pliku';

  @override
  String get exportPodcastsToFile => 'Eksportuj podcasty do pliku OPML';

  @override
  String podcastImportComplete(int count) {
    return 'Zaimportowane podcasty: $count';
  }

  @override
  String podcastImportError(Object error) {
    return 'Błąd importu podcastów: $error';
  }

  @override
  String get podcastInvalidOpmlFile =>
      'Nieprawidłowy plik. Wybierz plik OPML lub XML.';

  @override
  String get podcastExportComplete => 'Podcasty wyeksportowane';

  @override
  String podcastExportError(Object error) {
    return 'Błąd eksportu podcastów: $error';
  }

  @override
  String get loadingEpisodes => 'Ładowanie odcinków';

  @override
  String get noAudioEpisodesFound => 'Nie znaleziono odcinków audio w kanale.';

  @override
  String get episodes => 'Odcinki';

  @override
  String get episodeActions => 'Akcje odcinka';

  @override
  String downloaded(String path) {
    return 'Pobrano: $path';
  }

  @override
  String episodeError(Object error) {
    return 'Błąd odcinka: $error';
  }

  @override
  String get play => 'Odtwórz';

  @override
  String get pause => 'Pauza';

  @override
  String get rewind15s => 'Cofnij 15 s';

  @override
  String get forward15s => 'Do przodu 15 s';

  @override
  String get stop => 'Stop';

  @override
  String get back => 'Wstecz';

  @override
  String get episodePlayer => 'Odtwarzacz odcinka';

  @override
  String nowPlayingTitle(String title) {
    return 'Teraz odtwarzane: $title';
  }

  @override
  String get loadingEpisodeAudio => 'Ładowanie dźwięku odcinka';

  @override
  String get playbackPosition => 'Pozycja';

  @override
  String playbackPositionValue(String position, String duration) {
    return '$position z $duration';
  }

  @override
  String get adjustVolume => 'Reguluj głośność';

  @override
  String volumeValue(int percentage) {
    return 'Głośność: $percentage%';
  }

  @override
  String get download => 'Pobierz';

  @override
  String get searchWikipedia => 'Szukaj w Wikipedii';

  @override
  String get wikipediaLanguage => 'Język Wikipedii';

  @override
  String get search => 'Szukaj';

  @override
  String get wikipediaSearch => 'Wyszukiwanie w Wikipedii';

  @override
  String get wikipediaImporting => 'Import z Wikipedii';

  @override
  String get noWikipediaResults => 'Nie znaleziono wyników w Wikipedii';

  @override
  String get wikipediaImportMode => 'Tryb importu';

  @override
  String get wikipediaImportWholeArticle => 'Cały artykuł';

  @override
  String get documents => 'Dokumenty';

  @override
  String get documentsHint => 'Otwórz bibliotekę dokumentów';

  @override
  String get documentLibrary => 'Biblioteka dokumentów';

  @override
  String get addToLibrary => 'Dodaj do biblioteki';

  @override
  String get documentImportSelectionMode =>
      'Czy chcesz wybrać jeden dokument czy wiele dokumentów?';

  @override
  String get documentImportSingle => 'Jeden dokument';

  @override
  String get documentImportMultiple => 'Wiele dokumentów';

  @override
  String get noDocuments => 'Brak dokumentów. Dodaj plik.';

  @override
  String get noDocumentsInLibrary => 'Brak dokumentów w bibliotece.';

  @override
  String get documentAdded => 'Dokument dodany';

  @override
  String get documentsAdded => 'Dokumenty dodane';

  @override
  String get importDocumentsFromITunes =>
      'Importuj dokumenty z iTunes / Apple Devices';

  @override
  String sharedDocumentsImportComplete(int count) {
    return 'Dokumenty zaimportowane z iTunes / Apple Devices: $count';
  }

  @override
  String libraryLoadError(Object error) {
    return 'Błąd ładowania biblioteki: $error';
  }

  @override
  String fileOpenError(Object error) {
    return 'Błąd otwierania pliku: $error';
  }

  @override
  String get filePathUnavailable => 'Ścieżka pliku niedostępna.';

  @override
  String fileInaccessible(String name) {
    return 'Plik niedostępny: $name';
  }

  @override
  String documentAddError(Object error) {
    return 'Błąd dodawania dokumentu: $error';
  }

  @override
  String documentRemoveError(Object error) {
    return 'Błąd usuwania: $error';
  }

  @override
  String get noExportableTextFound => 'Nie znaleziono tekstu do eksportu.';

  @override
  String get modifiedDocumentNoExportableText =>
      'Zmodyfikowany dokument nie zawiera tekstu do eksportu.';

  @override
  String get documentRemoved => 'Dokument usunięty';

  @override
  String get folderRemoved => 'Folder usunięty';

  @override
  String get removeFolder => 'Usuń folder';

  @override
  String get removeDocument => 'Usuń dokument';

  @override
  String get writeNewDocument => 'Napisz nowy dokument';

  @override
  String get addDocumentToLibraryHint =>
      'Dodaj dokument do biblioteki. Przeglądaj pliki urządzenia i dodaj je.';

  @override
  String get documentTypeLabel => 'Dokument';

  @override
  String get documentPosition => 'Pozycja dokumentu';

  @override
  String get documentRemainingLessThanOneMinute =>
      'pozostało mniej niż 1 minuta';

  @override
  String documentRemainingMinutes(int minutes) {
    return 'pozostało około $minutes minut';
  }

  @override
  String documentRemainingHours(int hours) {
    return 'pozostało około $hours godzin';
  }

  @override
  String documentRemainingHoursMinutes(int hours, int minutes) {
    return 'pozostało około $hours godz. i $minutes min';
  }

  @override
  String get folderTypeLabel => 'Folder';

  @override
  String documentAddedOn(String date) {
    return 'dodano $date';
  }

  @override
  String documentTypeDescription(String extension) {
    return 'typ $extension';
  }

  @override
  String get openFolderHint => 'Dotknij dwukrotnie, aby otworzyć folder';

  @override
  String get openDocumentHint =>
      'Dotknij dwukrotnie, aby otworzyć i przeczytać dokument';

  @override
  String removeItem(String name) {
    return 'Usuń $name';
  }

  @override
  String get removePodcast => 'Usuń podcast';

  @override
  String get podcastRemoved => 'Podcast usunięty';

  @override
  String get documentPickerError => 'Błąd otwierania pliku';

  @override
  String get readDocument => 'Czytaj dokument';

  @override
  String get documentReaderTitle => 'Czytnik dokumentów';

  @override
  String get documentReaderEditHint =>
      'Dotknij akapitu, aby go edytować. Przesuń w górę lub w dół, aby dodać zakładkę.';

  @override
  String get documentParagraphSelectionStartAction =>
      'Rozpocznij zaznaczanie akapitów';

  @override
  String get documentParagraphSelectionTapHint =>
      'Tryb zaznaczania jest aktywny. Stuknij dwukrotnie, aby zaznaczyć lub odznaczyć ten akapit.';

  @override
  String get documentParagraphSelectionStarted =>
      'Tryb zaznaczania jest aktywny. Akapit zaznaczony. Stuknij dwukrotnie inne akapity, aby je zaznaczyć.';

  @override
  String documentParagraphSelectedAnnouncement(int count) {
    return 'Akapit zaznaczony. Łącznie zaznaczono: $count.';
  }

  @override
  String documentParagraphDeselectedAnnouncement(int count) {
    return 'Akapit odznaczony. Łącznie zaznaczono: $count.';
  }

  @override
  String documentParagraphSelectionCount(int count) {
    return 'Zaznaczone: $count';
  }

  @override
  String get documentDeleteSelectedParagraphs => 'Usuń zaznaczone akapity';

  @override
  String documentDeleteSelectedParagraphsConfirmation(int count) {
    return 'Usunąć zaznaczone akapity? Łącznie: $count.';
  }

  @override
  String documentSelectedParagraphsDeleted(int count) {
    return 'Usunięte akapity: $count.';
  }

  @override
  String get documentExitParagraphSelection => 'Zakończ zaznaczanie akapitów';

  @override
  String get documentParagraphSelectionExited => 'Tryb zaznaczania wyłączony.';

  @override
  String get documentBookmarkHintSet =>
      'Przesuń w górę lub w dół, aby ustawić zakładkę.';

  @override
  String get documentEditParagraphActionHint =>
      'Dotknij dwukrotnie, aby edytować ten akapit. ';

  @override
  String get documentBookmarkHintReplace =>
      'Przesuń w górę lub w dół, aby usunąć istniejącą zakładkę albo zastąpić ją tym akapitem.';

  @override
  String get documentSetBookmarkAction => 'Dodaj nową zakładkę';

  @override
  String get documentRemoveBookmarkAction => 'Usuń zakładkę';

  @override
  String get documentReplaceBookmarkAction => 'Usuń i dodaj nową zakładkę';

  @override
  String get searchInDocument => 'Szukaj w dokumencie';

  @override
  String get documentIndex => 'Spis treści';

  @override
  String get documentSearchFieldLabel => 'Szukany tekst';

  @override
  String get documentSearchFieldHint => 'Słowo lub fraza do znalezienia';

  @override
  String get documentSearchEmptyQuery => 'Wpisz tekst do wyszukania.';

  @override
  String get documentSearchResultsTitle => 'Wyniki wyszukiwania w dokumencie';

  @override
  String noDocumentSearchResults(String query) {
    return 'Nie znaleziono wyników dla $query.';
  }

  @override
  String documentSearchResultParagraph(int number) {
    return 'Akapit $number';
  }

  @override
  String get edit => 'Edytuj';

  @override
  String get save => 'Zapisz';

  @override
  String get cancel => 'Anuluj';

  @override
  String get settingsReadingEngine => 'Silnik czytania';

  @override
  String get settingsEdgeTtsQuality => 'Edge TTS (wysoka jakość online)';

  @override
  String get settingsSystemVoices => 'Głosy systemowe (VoiceOver / Google)';

  @override
  String get settingsNoSystemVoices => 'Brak dostępnych głosów systemowych.';

  @override
  String get settingsDefaultVoiceHint => 'Głos domyślny';

  @override
  String get settingsDefaultVoice => 'Domyślny';

  @override
  String get settingsVoiceSpeed => 'Prędkość: ';

  @override
  String get settingsVoicePitch => 'Wysokość głosu: ';

  @override
  String get settingsVoiceSpeedLabel => 'Prędkość czytania';

  @override
  String get settingsVoicePitchLabel => 'Wysokość głosu';

  @override
  String get settingsTestVoice => 'Testuj głos';

  @override
  String get settingsTestingVoice => 'Odtwarzanie...';

  @override
  String get settingsVoiceTestText => 'To jest test wybranego głosu.';

  @override
  String settingsVoiceTestError(Object error) {
    return 'Błąd testu głosu: $error';
  }

  @override
  String settingsVoiceSaveError(Object error) {
    return 'Błąd zapisu głosu TTS: $error';
  }

  @override
  String get settingsUnsavedTitle => 'Niezapisane zmiany';

  @override
  String get settingsUnsavedMessage =>
      'Czy chcesz zapisać zmiany przed opuszczeniem ustawień?';

  @override
  String get settingsExitWithoutSaving => 'Wyjdź bez zapisywania';

  @override
  String get settingsSystemLanguage => 'Język systemowy';

  @override
  String get settingsSystemVoice => 'Głos systemowy';

  @override
  String get settingsAutoBookmark => 'Automatyczne wznawianie';

  @override
  String get settingsAutoBookmarkHint =>
      'Wznawiaj dokumenty, podcasty i multimedia od miejsca przerwania.';

  @override
  String get settingsDocumentSliderStep => 'Krok suwaka dokumentu';

  @override
  String get settingsDocumentSliderStepHint =>
      'Określa, o ile przesuwa się suwak pozycji dokumentu po przesunięciu palcem w górę lub w dół.';

  @override
  String get settingsReadingSleepTimer => 'Timer wyłączania czytania';

  @override
  String get settingsReadingSleepTimerOff => 'Wyłączony';

  @override
  String settingsReadingSleepTimerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsReadingSleepTimerHint =>
      'Automatycznie zatrzymuje czytanie bieżącego dokumentu po wybranym czasie i zapisuje miejsce zatrzymania. Odliczanie zaczyna się od nowa przy każdym uruchomieniu czytania dokumentu.';

  @override
  String get documentReadingSleepTimerStopped =>
      'Timer wyłączania: czytanie zatrzymane, a pozycja zapisana.';

  @override
  String get settingsSeekStep =>
      'Krok przewijania wstecz / do przodu dla mediów';

  @override
  String get aiChatIntro => 'Jestem Sonarpad AI. Jak mogę pomóc?';

  @override
  String get meteoTitle => 'Pogoda';

  @override
  String get weatherCity => 'Miasto';

  @override
  String get weatherCityHint => 'Przykład: Warszawa';

  @override
  String get weatherCityNotFound => 'Nie znaleziono miasta';

  @override
  String get weatherSearchError => 'Błąd podczas wyszukiwania';

  @override
  String get weatherToday => 'Dzisiaj';

  @override
  String get weatherCurrentSituation => 'Aktualna sytuacja';

  @override
  String get weatherTomorrow => 'Jutro';

  @override
  String get weatherChooseDay => 'Wybierz dzień';


  @override
  String get tvRecordingChooseDay => weatherChooseDay;
  @override
  String get weatherCurrentTemperature => 'Aktualna temperatura';

  @override
  String get weatherMaxTemperature => 'Temperatura maksymalna';

  @override
  String get weatherMinTemperature => 'Temperatura minimalna';

  @override
  String get weatherPrecipitation => 'Opady';

  @override
  String get weatherPrecipitationProbability => 'Prawdopodobieństwo opadów';

  @override
  String get weatherWind => 'Wiatr';

  @override
  String get weatherRelativeHumidity => 'Wilgotność względna';

  @override
  String get weatherAirQuality => 'Jakość powietrza';

  @override
  String get weatherAirQualityGood => 'Dobra';

  @override
  String get weatherAirQualityFair => 'Zadowalająca';

  @override
  String get weatherAirQualityModerate => 'Umiarkowana';

  @override
  String get weatherAirQualityPoor => 'Zła';

  @override
  String get weatherAirQualityVeryPoor => 'Bardzo zła';

  @override
  String get weatherAirQualityExtremelyPoor => 'Ekstremalnie zła';

  @override
  String get settingsSecretCode => 'Kod Sonarpad dla dodatkowych funkcji';

  @override
  String get settingsRequestCode => 'Poproś autora o kod';

  @override
  String get settingsPasteCode => 'Wklej kod';

  @override
  String get settingsCancel => 'Anuluj';

  @override
  String get settingsSend => 'Wyślij';

  @override
  String get settingsFillFieldsCode =>
      'Wypełnij wszystkie pola, aby poprosić o kod.';

  @override
  String get settingsName => 'Imię';

  @override
  String get settingsSurname => 'Nazwisko';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsOperatingSystem => 'System operacyjny';

  @override
  String settingsCodeRequestBody(
    String name,
    String surname,
    String email,
    String os,
  ) {
    return 'Imię: $name; Nazwisko: $surname; Email: $email; System operacyjny: $os';
  }

  @override
  String get settingsNameOptional => 'Imię (opcjonalnie)';

  @override
  String get settingsMessageOptional => 'Wiadomość (opcjonalnie)';

  @override
  String get settingsVerifyCodeAndSave => 'Sprawdzanie kodu i zapisywanie...';

  @override
  String get settingsViewSysLog => 'Pokaż dziennik systemowy';

  @override
  String settingsMailOpenError(Object error) {
    return 'Błąd otwierania poczty: $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Tak';

  @override
  String get no => 'Nie';

  @override
  String get invia => 'Wyślij';

  @override
  String get saveArticle => 'Zapisz artykuł';

  @override
  String get shareArticle => 'Udostępnij artykuł';

  @override
  String get shareArticleAsTxt => 'Udostępnij artykuł jako TXT';

  @override
  String get articleSavedSuccess => 'Artykuł zapisany w Dokumentach';

  @override
  String get annulla => 'Anuluj';

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice =>
      'Wypełnij wszystkie pola, aby poprosić o kod.';

  @override
  String get selectFolder => 'Wybierz folder';

  @override
  String get exportDocument => 'Eksportuj dokument';

  @override
  String get exportFormatPrompt =>
      'W jakim formacie chcesz wyeksportować dokument?';

  @override
  String get textFormat => 'Tekst (.txt)';

  @override
  String get pdfFormat => 'PDF (.pdf)';

  @override
  String get docxFormat => 'DOCX (.docx)';

  @override
  String get epubFormat => 'EPUB (.epub)';

  @override
  String get exportError => 'Błąd eksportu';

  @override
  String get newFolder => 'Nowy folder';

  @override
  String get folderNameHint => 'Nazwa folderu';

  @override
  String get create => 'Utwórz';

  @override
  String get createNewFolder => 'Utwórz nowy folder';

  @override
  String get importExternalSources => 'Importuj ze źródeł zewnętrznych';

  @override
  String get importExternalSourcesTitle => 'Źródła zewnętrzne';

  @override
  String get importFromDropbox => 'Importuj dokumenty z Dropbox';

  @override
  String get importFromProjectGutenberg => 'Importuj z Project Gutenberg';

  @override
  String get projectGutenbergImportUnavailable =>
      'Import z Project Gutenberg nie jest jeszcze dostępny.';

  @override
  String get importFromInternetArchive => 'Importuj z Internet Archive';

  @override
  String get internetArchiveTitle => 'Internet Archive';

  @override
  String get internetArchiveSearchLabel => 'Szukaj audio';

  @override
  String get internetArchiveSourceLabel => 'Źródło';

  @override
  String get internetArchiveOldTimeRadio => 'Old Time Radio';

  @override
  String get internetArchiveSpeeches => 'Przemówienia historyczne';

  @override
  String get internetArchiveLiveMusic => 'Live Music Archive';

  @override
  String get internetArchiveNoItemsFound => 'Nie znaleziono elementów audio.';

  @override
  String get saveAudioInDocuments => 'Zapisz dźwięk w Dokumentach';

  @override
  String get audioSavedInDocuments => 'Dźwięk zapisany w Dokumentach.';

  @override
  String get noAudioTracksAvailable => 'Brak dostępnych ścieżek audio.';

  @override
  String get importFromLibriVox => 'Importuj z LibriVox';

  @override
  String get gutenbergSearchLabel => 'Szukaj książki lub autora';

  @override
  String get sourceLanguageLabel => 'Język';

  @override
  String get noGutenbergBooksFound => 'Nie znaleziono książek.';

  @override
  String get loadMore => 'Załaduj więcej';

  @override
  String sourceLanguageValue(String language) {
    return 'Język: $language';
  }

  @override
  String get gutenbergImportAndRead => 'Importuj i czytaj';

  @override
  String get gutenbergImporting => 'Importowanie...';

  @override
  String get librivoxSearchLabel => 'Szukaj audiobooka';

  @override
  String get noLibrivoxAudiobooksFound => 'Nie znaleziono audiobooków.';

  @override
  String get librivoxAudiobookSaved => 'Audiobook zapisany w Dokumentach.';

  @override
  String get librivoxSaveAudiobook => 'Zapisz audiobook w Dokumentach';

  @override
  String get librivoxSaving => 'Zapisywanie...';

  @override
  String get librivoxNoAudioTracks => 'Brak dostępnych ścieżek audio.';

  @override
  String get librivoxNotTextExportable =>
      'Audiobooków LibriVox nie można eksportować jako tekstu.';

  @override
  String sourceDurationValue(String duration) {
    return 'Czas trwania: $duration';
  }

  @override
  String get importFromPoetryDb => 'Importuj z PoetryDB';

  @override
  String get poetryDbSearchLabel => 'Szukaj wiersza';

  @override
  String get poetryDbSearchBy => 'Szukaj według';

  @override
  String get poetryDbSearchByTitle => 'Tytuł';

  @override
  String get poetryDbSearchByAuthor => 'Autor';

  @override
  String get poetryDbNoPoemsFound => 'Nie znaleziono wierszy.';

  @override
  String poetryDbLineCount(int count) {
    return '$count wersów';
  }

  @override
  String get moveDocument => 'Przenieś dokument';

  @override
  String get documentMoved => 'Przeniesiono poprawnie';

  @override
  String get outOfFolder => 'Poza folderem';

  @override
  String get moveToAnotherFolder => 'Przenieś do innego folderu...';

  @override
  String get ttsError => 'Błąd TTS';

  @override
  String get editParagraph => 'Edytuj akapit';

  @override
  String get editParagraphTextField => 'Pole tekstowe do edycji akapitu';

  @override
  String get editParagraphHint => 'Edytuj tekst akapitu';

  @override
  String get applyAndSave => 'Zastosuj i zapisz';

  @override
  String get textEditedAndSaved =>
      'Tekst zmieniony i zapisany w bieżącym dokumencie.';

  @override
  String get saveError => 'Błąd podczas zapisywania';

  @override
  String get docSavedInLibrary => 'Dokument zapisany w bibliotece';

  @override
  String get saveInLibrary => 'Zapisz w bibliotece';

  @override
  String get copyToClipboard => "Kopiuj do schowka";

  @override
  String get textCopiedToClipboard => "Tekst skopiowany do schowka";

  @override
  String get documentTextLabel => 'Tekst dokumentu';

  @override
  String get modifiedInSonarpad => 'Zmodyfikowano w Sonarpad';

  @override
  String get noTextAvailableForDocument => 'Brak tekstu dla tego dokumentu.';

  @override
  String bookmarkSet(int index) {
    return 'Zakładka ustawiona przy akapicie $index.';
  }

  @override
  String get bookmarkRemoved => 'Zakładka usunięta.';

  @override
  String get docEmpty => 'Dokument jest pusty';

  @override
  String get docSavedSuccessfully => 'Dokument zapisany poprawnie!';

  @override
  String get writeDocument => 'Napisz dokument';

  @override
  String get documentTitleOptional => 'Tytuł (opcjonalnie)';

  @override
  String get documentTitleHint => 'Przykład: notatki zakupowe';

  @override
  String get documentTextField => 'Tekst dokumentu';

  @override
  String get documentTextHint => 'Zacznij pisać tutaj...';

  @override
  String get newDocumentDefaultName => 'Nowy_Dokument';

  @override
  String get saving => 'Zapisywanie...';

  @override
  String get saveDocument => 'Zapisz dokument';

  @override
  String get addRssSource => 'Dodaj źródło RSS';

  @override
  String get add => 'Dodaj';

  @override
  String get errorPrefix => 'Błąd';

  @override
  String versionBuild(String version, String buildNumber) {
    return 'Wersja $version (Build $buildNumber)';
  }

  @override
  String get whatIsNew => 'Co nowego';

  @override
  String whatIsNewInVersion(String version) {
    return 'Co nowego w wersji $version';
  }

  @override
  String changelogLoadError(Object error) {
    return 'Błąd ładowania nowości: $error';
  }

  @override
  String get visitSonarpadSite => 'Odwiedź stronę Sonarpad';

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return 'Odwiedź stronę Sonarpad: $url';
  }

  @override
  String get nowPlaying => 'Teraz odtwarzane';

  @override
  String get fileImported => 'Plik zaimportowany';

  @override
  String importZipError(Object error) {
    return 'Błąd importu ZIP: $error';
  }

  @override
  String get dropboxLoginPrompt =>
      'Zaloguj się do Dropbox, aby importować dokumenty.';

  @override
  String get loginToDropbox => 'Zaloguj się do Dropbox';

  @override
  String get logoutFromDropbox => 'Wyloguj';

  @override
  String get dropboxLoginFailed =>
      'Logowanie nie powiodło się albo zostało anulowane';

  @override
  String dropboxLoadFolderError(Object error) {
    return 'Błąd ładowania folderu: $error';
  }

  @override
  String dropboxImportError(Object error) {
    return 'Błąd importu: $error';
  }

  @override
  String get retry => 'Spróbuj ponownie';

  @override
  String get goBack => 'Wróć';

  @override
  String get noSupportedFilesInFolder =>
      'Brak obsługiwanych plików w tym folderze.';

  @override
  String get articleNotFound => 'Nie znaleziono artykułu.';

  @override
  String get errorOpening => 'Błąd podczas otwierania';

  @override
  String get recentArticles => 'Ostatnie artykuły';

  @override
  String get clearHistory => 'Wyczyść historię';

  @override
  String get confirmClearHistory =>
      'Czy na pewno chcesz wyczyścić wszystkie ostatnie wyszukiwania?';

  @override
  String get clear => 'Wyczyść';

  @override
  String get noRecentSearches => 'Brak ostatnich wyszukiwań.';

  @override
  String get logCopiedToClipboard => 'Log skopiowany do schowka';

  @override
  String get logCleared => 'Dziennik wyczyszczony';

  @override
  String get parafarmacoDetailReadyAnnouncement =>
      'Karta produktu wczytana. Przesuń w prawo, aby wybrać sekcje.';

  @override
  String get systemLog => 'Dziennik systemowy';

  @override
  String get clearSystemLog => 'Wyczyść log';

  @override
  String get copySystemLog => 'Kopiuj log';

  @override
  String get donateWithPaypal => 'Przekaż darowiznę przez PayPal';

  @override
  String get bankTransferTitle => 'Przelew bankowy';

  @override
  String get enableVideo => 'Włącz wideo';

  @override
  String get calendar => 'Kalendarz';

  @override
  String get calendarHint =>
      'Otwórz kalendarz ze świętami, świętym dnia i przypomnieniami';

  @override
  String get saintOfTheDay => 'Święty dnia';

  @override
  String get quoteOfTheDay => 'Cytat dnia';

  @override
  String get reminders => 'Przypomnienia';

  @override
  String get addReminder => 'Dodaj przypomnienie';

  @override
  String get removeReminder => 'Usuń przypomnienie';

  @override
  String get noReminders => 'Brak przypomnień';

  @override
  String get writeReminder => 'Wpisz tutaj swoje przypomnienie...';

  @override
  String get saveReminder => 'Zapisz';

  @override
  String get cancelReminder => 'Anuluj';

  @override
  String get backToToday => 'Wróć do dzisiaj';

  @override
  String get calendarToday => 'Dzisiaj';

  @override
  String get calendarTomorrow => 'Jutro';

  @override
  String get calendarYesterday => 'Wczoraj';

  @override
  String get share => 'Udostępnij';

  @override
  String get shareCalendarDayOptions => 'Opcje udostępniania';

  @override
  String get shareCalendarDayOnly => 'Udostępnij tylko dzień';

  @override
  String get shareCalendarDayWithReminder => 'Udostępnij dzień i przypomnienie';

  @override
  String get listenToAll => 'Posłuchaj wszystkiego';

  @override
  String reminderSaved(int count) {
    return '$count przypomnień';
  }

  @override
  String get audiodescriptionTitle => 'Audiodeskrypcje';

  @override
  String get audiodescriptionRecent => 'Ostatnie';

  @override
  String get audiodescriptionAll => 'Wszystkie audiodeskrypcje';

  @override
  String get audiodescriptionFilm => 'Filmy';

  @override
  String get audiodescriptionSearch => 'Szukaj...';

  @override
  String get audiodescriptionLoading => 'Ładowanie...';

  @override
  String get audiodescriptionError => 'Błąd ładowania katalogu';

  @override
  String get audiodescriptionEmpty => 'Nie znaleziono elementów';

  @override
  String get radio => 'Radio';

  @override
  String get radioHint =>
      'Szukaj stacji radiowych, słuchaj strumieni i zarządzaj ulubionymi';

  @override
  String get radioTitle => 'Stacje radiowe z całego świata';

  @override
  String get radioFavoritesButton => 'Ulubione stacje radiowe';

  @override
  String get radioNoFavorites => 'Brak ulubionych stacji radiowych.';

  @override
  String get radioSearchText => 'Szukaj stacji radiowej';

  @override
  String get radioSearchHint => 'Nazwa stacji radiowej albo miasto...';

  @override
  String get radioLanguage => 'Język';

  @override
  String get radioBrowseBy => 'Przeglądaj według';

  @override
  String get radioBrowseByLanguage => 'Przeglądaj według języka';

  @override
  String get radioBrowseByCountry => 'Przeglądaj według kraju';

  @override
  String get radioCountry => 'Kraj';

  @override
  String get radioGenre => 'Gatunek';

  @override
  String get radioActiveFilters => 'Aktywne filtry';

  @override
  String get radioResetFilters => 'Resetuj filtry';

  @override
  String get radioFiltersReset => 'Filtry zresetowane.';

  @override
  String get radioCity => 'Miasto';

  @override
  String get radioSearch => 'Szukaj';

  @override
  String get radioSearching => 'Ładowanie stacji radiowych...';

  @override
  String get radioSearchResults => 'Wyniki wyszukiwania radia';

  @override
  String get radioNoResults => 'Nie znaleziono stacji radiowych.';

  @override
  String radioResultsFound(int count) {
    return 'Znaleziono stacje radiowe: $count';
  }

  @override
  String radioSearchError(Object error) {
    return 'Błąd wyszukiwania radia: $error';
  }

  @override
  String radioNowPlaying(String name) {
    return 'Odtwarzam $name';
  }

  @override
  String radioPlayError(Object error) {
    return 'Błąd strumienia radia: $error';
  }

  @override
  String get radioAddFavorite => 'Dodaj do ulubionych';

  @override
  String get radioRemoveFavorite => 'Usuń z ulubionych';

  @override
  String radioFavoriteAdded(String name) {
    return '$name dodano do ulubionych.';
  }

  @override
  String radioFavoriteRemoved(String name) {
    return '$name usunięto z ulubionych.';
  }

  @override
  String get tvSearchFieldLabel => 'Szukaj kanałów TV';

  @override
  String get tvSearchFieldHint => 'Nazwa kanału...';

  @override
  String get tvSearchButton => 'Szukaj';

  @override
  String get tvSearchResults => 'Wyniki kanałów TV';

  @override
  String get tvSearchEmptyQuery => 'Wpisz nazwę kanału TV do wyszukania.';

  @override
  String tvSearchNoResults(String query) {
    return 'Nie znaleziono kanałów TV dla $query.';
  }

  @override
  String get tvOpenChannelHint => 'Dotknij, aby odtworzyć kanał TV';

  @override
  String tvNowOnAir(String title) {
    return 'Teraz na antenie: $title';
  }

  @override
  String get radioAddCommunity =>
      'Dodaj stację radiową do społeczności Sonarpad';

  @override
  String get radioAddName => 'Nazwa radia';

  @override
  String get radioAddUrl => 'Adres strumienia';

  @override
  String get radioAddSubmit => 'Sprawdź i dodaj';

  @override
  String get radioAddMissingFields => 'Wpisz nazwę radia i adres strumienia.';

  @override
  String get radioCommunityAdded =>
      'Stacja radiowa została poprawnie dodana do społeczności Sonarpad.';

  @override
  String radioCommunityAddError(Object error) {
    return 'Błąd podczas dodawania radia: $error';
  }

  @override
  String get radioPlay => 'Odtwórz';

  @override
  String get tvPlayLive => 'Odtwórz transmisję na żywo';

  @override
  String get playAndRecord => 'Odtwórz i nagrywaj';

  @override
  String get startRecording => 'Rozpocznij nagrywanie';

  @override
  String get stopRecording => 'Zatrzymaj nagrywanie';

  @override
  String get recordings => 'Nagrania';

  @override
  String get recordingInProgressStatus => 'Nagrywanie w toku';

  @override
  String get scheduledRecordingInProgressStatus => 'Trwa zaplanowane nagrywanie';

  @override
  String get recordingCannotOpenWhileInProgress => 'Nie można otworzyć tego nagrania, ponieważ nagrywanie nadal trwa.';

  @override
  String get blindLibrarySearchCatalog => 'Przeszukaj katalog';

  @override
  String get selectRecordings => 'Wybierz nagrania';

  @override
  String get selectAll => 'Zaznacz wszystko';

  @override
  String get deselectAll => 'Odznacz wszystko';

  @override
  String selectionActionCount(String action, int count) {
    return '$action ($count)';
  }

  @override
  String deleteRecordingsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Trwale usunąć $count nagrań?',
      one: 'Trwale usunąć jedno nagranie?',
    );
    return '$_temp0';
  }

  @override
  String get noRecordings => 'Brak nagrań.';

  @override
  String get recordingStarted => 'Nagrywanie rozpoczęte.';

  @override
  String recordingSaved(Object path) {
    return 'Nagranie zapisane: $path';
  }

  @override
  String recordingError(Object error) {
    return 'Błąd nagrywania: $error';
  }

  @override
  String get routeTitle => 'Trasy';

  @override
  String get routeFrom => 'Punkt początkowy';

  @override
  String get routeTo => 'Cel';

  @override
  String get routeCountry => 'Kraj';

  @override
  String get routeCountryItaly => 'Włochy';

  @override
  String get routeCountryFrance => 'Francja';

  @override
  String get routeCountrySpain => 'Hiszpania';

  @override
  String get routeCountryCzechRepublic => 'Czechy';

  @override
  String get routeVehicle => 'Środek transportu';

  @override
  String get routeType => 'Typ';

  @override
  String get routeIncludeMunicipalities => 'Uwzględnij mijane miejscowości';

  @override
  String get routeWalking => 'Pieszo';

  @override
  String get routeCycling => 'Rowerem';

  @override
  String get routeDriving => 'Samochodem';

  @override
  String get routeWheelchair => 'Na wózku inwalidzkim';

  @override
  String get routeFastest => 'Najszybsza';

  @override
  String get routeShortest => 'Najkrótsza';

  @override
  String get routeCalculate => 'Oblicz trasę';

  @override
  String get routeCalculating => 'Obliczanie...';

  @override
  String get routeChooseFrom => 'Wybierz punkt początkowy';

  @override
  String get routeChooseTo => 'Wybierz cel';

  @override
  String get routeCancel => 'Anuluj';

  @override
  String get routeErrorMissingFields => 'Wpisz punkt początkowy i cel';

  @override
  String get routeErrorFromNotFound =>
      'Nie znaleziono wyniku dla adresu początkowego';

  @override
  String get routeErrorToNotFound =>
      'Nie znaleziono wyniku dla adresu docelowego';

  @override
  String get routeResultsTitle => 'Dostępne trasy';

  @override
  String get routeDistance => 'Odległość';

  @override
  String get routeDuration => 'Czas trwania';

  @override
  String get routeNavigation => 'Szczegóły nawigacji';

  @override
  String get routeStartMunicipality => 'Miejscowość początkowa';

  @override
  String get routeEnterMunicipality => 'Wjeżdżasz do miejscowości';

  @override
  String routeError(Object error) {
    return 'Błąd: $error';
  }

  @override
  String get radioLanguageIt => 'Włoski';

  @override
  String get radioLanguageEn => 'Angielski';

  @override
  String get radioLanguageDe => 'Niemiecki';

  @override
  String get radioLanguageCountryCh => 'Szwajcaria';

  @override
  String get radioLanguageEs => 'Hiszpański';

  @override
  String get radioLanguagePt => 'Portugalski';

  @override
  String get radioLanguageSv => 'Szwedzki';

  @override
  String get radioLanguageVi => 'Wietnamski';

  @override
  String get radioLanguageCs => 'Czeski';

  @override
  String get radioLanguagePl => 'Polski';

  @override
  String get radioLanguageFr => 'Francuski';

  @override
  String get radioLanguageSr => 'Serbski';

  @override
  String get radioLanguageUk => 'Ukraiński';

  @override
  String get radioLanguageHi => 'Hindi';

  @override
  String get radioLanguageLt => 'Litewski';

  @override
  String get radioLanguageRu => 'Rosyjski';

  @override
  String get radioLanguageZh => 'Chiński';

  @override
  String get radioCountryOptionIt => 'Włochy';

  @override
  String get radioCountryOptionUs => 'Stany Zjednoczone';

  @override
  String get radioCountryOptionGb => 'Wielka Brytania';

  @override
  String get radioCountryOptionFr => 'Francja';

  @override
  String get radioCountryOptionEs => 'Hiszpania';

  @override
  String get radioCountryOptionDe => 'Niemcy';

  @override
  String get radioCountryOptionCh => 'Szwajcaria';

  @override
  String get radioCountryOptionAt => 'Austria';

  @override
  String get radioCountryOptionBe => 'Belgia';

  @override
  String get radioCountryOptionNl => 'Holandia';

  @override
  String get radioCountryOptionPt => 'Portugalia';

  @override
  String get radioCountryOptionBr => 'Brazylia';

  @override
  String get radioCountryOptionAr => 'Argentyna';

  @override
  String get radioCountryOptionMx => 'Meksyk';

  @override
  String get radioCountryOptionCa => 'Kanada';

  @override
  String get radioCountryOptionAu => 'Australia';

  @override
  String get radioCountryOptionIe => 'Irlandia';

  @override
  String get radioCountryOptionSe => 'Szwecja';

  @override
  String get radioCountryOptionPl => 'Polska';

  @override
  String get radioCountryOptionJp => 'Japonia';

  @override
  String get radioGenreOptionAll => 'Wszystkie gatunki';

  @override
  String get radioGenreOptionNews => 'Wiadomości';

  @override
  String get radioGenreOptionMusic => 'Muzyka';

  @override
  String get radioGenreOptionSport => 'Sport';

  @override
  String get radioGenreOptionTalk => 'Rozmowy i komentarze';

  @override
  String get radioGenreOptionPop => 'Pop';

  @override
  String get radioGenreOptionRock => 'Rock';

  @override
  String get radioGenreOptionClassical => 'Klasyczna';

  @override
  String get radioGenreOptionJazz => 'Jazz';

  @override
  String get radioGenreOptionDance => 'Dance';

  @override
  String get radioGenreOptionBlues => 'Blues';

  @override
  String get radioGenreOptionCountry => 'Country';

  @override
  String get radioGenreOptionHiphop => 'Hip hop';

  @override
  String get radioGenreOptionElectronic => 'Elektronika';

  @override
  String get radioGenreOptionLatin => 'Latynoska';

  @override
  String get radioGenreOptionReggae => 'Reggae';

  @override
  String get radioGenreOptionMetal => 'Metal';

  @override
  String get radioGenreOptionFolk => 'Folk';

  @override
  String get radioGenreOptionReligion => 'Religia';

  @override
  String get radioGenreOptionLocal => 'Lokalne';

  @override
  String get radioGenreOptionCulture => 'Kultura';

  @override
  String get radioGenreOptionOldies => 'Lata 70. / 80. / 90.';

  @override
  String get radioGenreOptionKids => 'Dla dzieci';

  @override
  String get radioGenreOptionAmbient => 'Ambient';

  @override
  String get radioCommunityLanguageItalian => 'Włoski';

  @override
  String get radioCommunityLanguageEnglish => 'Angielski';

  @override
  String get radioCommunityLanguageSpanish => 'Hiszpański';

  @override
  String get radioCommunityLanguageFrench => 'Francuski';

  @override
  String get radioCommunityLanguageGerman => 'Niemiecki';

  @override
  String get radioCommunityLanguagePortuguese => 'Portugalski';

  @override
  String get radioCommunityLanguageSwedish => 'Szwedzki';

  @override
  String get radioCommunityLanguageVietnamese => 'Wietnamski';

  @override
  String get radioCommunityLanguageCzech => 'Czeski';

  @override
  String get radioCommunityLanguagePolish => 'Polski';

  @override
  String get radioCommunityLanguageSerbian => 'Serbski';

  @override
  String get radioCommunityLanguageUkrainian => 'Ukraiński';

  @override
  String get radioCommunityLanguageLithuanian => 'Litewski';

  @override
  String get radioCommunityLanguageRussian => 'Rosyjski';

  @override
  String get radioCommunityLanguageChinese => 'Chiński';

  @override
  String get radioCommunityLanguageHindi => 'Hindi';

  @override
  String routeDistanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String routeDistanceKilometers(String kilometers) {
    return '$kilometers km';
  }

  @override
  String routeDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String routeDurationHoursMinutes(int hours, int minutes) {
    return '$hours godz. $minutes min';
  }

  @override
  String get cinemaTitle => 'Filmy w kinach';

  @override
  String get cinemaNoMovies => 'Obecnie nie znaleziono filmów.';

  @override
  String get cinemaError => 'Błąd podczas ładowania filmów.';

  @override
  String cinemaReleased(String date) {
    return 'Premiera: $date';
  }

  @override
  String get cinemaOverviewLabel => 'Opis:';

  @override
  String get cinemaUpcomingReleases => 'Nadchodzące premiery';

  @override
  String cinemaWillRelease(String date) {
    return 'Premiera: $date';
  }

  @override
  String get cinemaOpenTrailer => 'Otwórz zwiastun';

  @override
  String get concertsTitle => 'Koncerty i wydarzenia';

  @override
  String get concertsSearchHint => 'Wpisz miasto (np. Warszawa, Kraków)';

  @override
  String get concertsSearchLabel => 'Szukaj koncertów według miasta';

  @override
  String get concertsSearchTooltip => 'Szukaj';

  @override
  String get concertsInitialText =>
      'Wpisz u góry nazwę swojego miasta, aby zobaczyć zaplanowane koncerty muzyczne.';

  @override
  String get concertsEmpty => 'Nie znaleziono koncertów w tym mieście.';

  @override
  String get concertsVenue => 'Miejsce koncertu:';

  @override
  String get concertsBuyTickets => 'Kup lub zobacz szczegóły w Ticketmaster';

  @override
  String get podcastPlayedEpisodes => 'Odtworzone odcinki';

  @override
  String get podcastSelectDate => 'Wybierz datę';

  @override
  String get podcastNoDatesAvailable =>
      'Brak dostępnych dat dla tych odcinków.';

  @override
  String get podcastChapters => 'Rozdziały';

  @override
  String get podcastChaptersUnavailable => 'Brak rozdziałów dla tego odcinka.';

  @override
  String get podcastUnplayed => 'Nieodtworzone odcinki';

  @override
  String get routeReadAction => 'Przeczytaj trasę';

  @override
  String get routeSaveAction => 'Zapisz w Dokumentach';

  @override
  String get routeOpenAction => 'Otwórz trasę';

  @override
  String get routeAppleMapsAction => 'Mapy';

  @override
  String get routeGoogleMapsAction => 'Google Maps';

  @override
  String get routeOpenError => 'Nie można otworzyć aplikacji nawigacyjnej.';

  @override
  String get routeSaveSuccess => 'Trasa zapisana w Dokumentach';

  @override
  String get deleteItem => 'Usuń';

  @override
  String get audiobookMp3Format => 'Audiobook MP3 (.mp3)';

  @override
  String get audiobookM4bFormat => 'Audiobook M4B (.m4b)';

  @override
  String get exportCompleteTitle => 'Eksport zakończony';

  @override
  String get exportCompleteMessage =>
      'Plik został utworzony poprawnie. Czy chcesz zapisać go w Sonarpad czy udostępnić?';

  @override
  String get saveInSonarpad => 'Zapisz w Sonarpad';

  @override
  String get exportSavedInSonarpad => 'Plik zapisano w Dokumentach Sonarpad.';

  @override
  String get audiobookExportProgressTitle => 'Tworzenie audiobooka';

  @override
  String get audiobookExportPreparing => 'Przygotowywanie audiobooka...';

  @override
  String get audiobookExportGeneratingAudio => 'Generowanie dźwięku';

  @override
  String get audiobookExportConvertingAudio =>
      'Końcowa konwersja pliku audio...';

  @override
  String get audiobookExportFinalizing => 'Finalizowanie...';

  @override
  String get routeRecentRoutes => 'Ostatnie trasy';

  @override
  String get routeRecentRoutesEmpty => 'Brak ostatnich tras';

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) {
    return 'Szczegóły nawigacji z $from do $to - $date';
  }

  @override
  String get sortPodcastsAlphabetically => 'Sortuj podcasty alfabetycznie';

  @override
  String get sortRadioFavoritesAlphabetically =>
      'Sortuj ulubione alfabetycznie';

  @override
  String get podcastsSortedAlphabetically =>
      'Podcasty posortowane alfabetycznie.';

  @override
  String get radioFavoritesSortedAlphabetically =>
      'Ulubione stacje radiowe posortowane alfabetycznie.';

  @override
  String get settingsIncludeFootnotesInText =>
      'Uwzględniaj przypisy dolne w tekście';

  @override
  String get settingsIncludeFootnotesInTextHint =>
      'W obsługiwanych plikach EPUB pokazuje przypis zaraz po akapicie, który się do niego odwołuje.';

  @override
  String get documentFootnoteLabel => 'Przypis dolny';

  @override
  String get settingsMultipleDocumentBookmarks =>
      'Zezwalaj na wiele zakładek w dokumentach';

  @override
  String get settingsMultipleDocumentBookmarksHint =>
      'Gdy opcja jest wyłączona, każdy dokument ma tylko jedną zakładkę. Gdy jest włączona, możesz zapisać wiele zakładek w tym samym dokumencie.';

  @override
  String get documentGoToBookmarkAction => 'Przejdź do zakładki';

  @override
  String get documentChooseBookmarkTitle => 'Wybierz zakładkę';

  @override
  String get documentDeleteBookmarkAction => 'Usuń zakładkę';

  @override
  String get documentKeepBookmarkTitle => 'Którą zakładkę chcesz zachować?';

  @override
  String get documentKeepBookmarkMessage =>
      'Wiele zakładek jest wyłączone. Wybierz zakładkę do zachowania: pozostałe zostaną usunięte.';

  @override
  String documentBookmarkChoiceLabel(int order, int paragraph) {
    return 'Zakładka $order, akapit $paragraph';
  }

  @override
  String documentBookmarkChoiceLabelWithPreview(
    int order,
    int paragraph,
    String preview,
  ) {
    return 'Zakładka $order, akapit $paragraph. $preview';
  }

  @override
  String get settingsSonarTubePlayerActions => 'Dostosuj przyciski odtwarzacza SonarTube';

  @override
  String get settingsVideoLandscapeFullscreen =>
      'Wideo poziome na pełnym ekranie';

  @override
  String get settingsVideoLandscapeFullscreenHint =>
      'Po włączeniu wideo jest ono wyświetlane na pełnym ekranie w orientacji poziomej. Radia tylko audio pozostają bez zmian.';

  @override
  String get settingsPodcastCacheTitle => 'Pamięć podręczna podcastów';

  @override
  String get settingsPodcastCacheHint =>
      'Usuwa tylko tymczasowe pliki podcastów. Subskrypcje, historia i zaimportowane audio pozostają bez zmian.';

  @override
  String settingsPodcastCacheSize(String size) {
    return 'Zajęte miejsce: $size';
  }

  @override
  String get clearPodcastCache => 'Wyczyść pamięć podręczną podcastów';

  @override
  String get confirmClearPodcastCacheTitle =>
      'Wyczyścić pamięć podręczną podcastów?';

  @override
  String get confirmClearPodcastCacheMessage =>
      'Tymczasowe pliki podcastów zostaną usunięte. Subskrypcje i historia odcinków pozostaną bez zmian.';

  @override
  String podcastCacheCleared(String size) {
    return 'Pamięć podręczna podcastów wyczyszczona: zwolniono $size.';
  }

  @override
  String get podcastCacheEmpty => 'Pamięć podręczna podcastów jest już pusta.';

  @override
  String get pharmacyFeatureTitle => 'Leki, parafarmaceutyki i suplementy';

  @override
  String get pharmacyProductsSectionTitle => 'Parafarmaceutyki i suplementy';

  @override
  String get pharmacyProductsLoadingTitle =>
      'Wyszukiwanie parafarmaceutyków i suplementów...';

  @override
  String get pharmacyProductsErrorTitle =>
      'Błąd podczas wyszukiwania parafarmaceutyków i suplementów';

  @override
  String get pharmacyProductsNoResultsTitle =>
      'Nie znaleziono parafarmaceutyku ani suplementu';

  @override
  String get mediaCutterTitle => 'Przytnij plik multimedialny';

  @override
  String get mediaCutterInstruction1 =>
      'Otwórz plik audio lub wideo, odtwórz go i przejdź do miejsca, w którym chcesz wykonać cięcie.';

  @override
  String get mediaCutterInstruction2 =>
      'Wstrzymaj odtwarzanie, naciśnij Podziel, następnie usuń niepotrzebne części w sekcji Części do zapisania i naciśnij Zapisz.';

  @override
  String get mediaCutterOpenFile => 'Otwórz plik multimedialny';

  @override
  String mediaCutterSelectedFile(String fileName) {
    return 'Wybrany plik: $fileName';
  }

  @override
  String get mediaCutterPosition => 'Pozycja cięcia';

  @override
  String get mediaCutterPositionHint =>
      'Przesuwaj do przodu lub do tyłu o jedną sekundę.';

  @override
  String get mediaCutterHideVideoPreview => 'Ukryj wideo';

  @override
  String get mediaCutterVideoRotation => 'Obrót wideo';

  @override
  String get mediaCutterVideoRotationNone => 'Bez obrotu';

  @override
  String get mediaCutterVideoRotationRight => 'Obróć w prawo';

  @override
  String get mediaCutterVideoRotationLeft => 'Obróć w lewo';

  @override
  String get mediaCutterVideoRotationUpsideDown => 'Obróć o 180 stopni';

  @override
  String get mediaCutterVideoPreview => 'Podgląd wideo';

  @override
  String get mediaCutterSplit => 'Podziel';

  @override
  String get mediaCutterPartsTitle => 'Części do zapisania';

  @override
  String get mediaCutterPartsHint =>
      'Stuknij część, aby jej posłuchać. Usunięte części znikają z listy, są pomijane podczas odtwarzania i nie zostaną zapisane. Efekty są stosowane do całej części dopiero po zapisaniu multimediów.';

  @override
  String mediaCutterPartLabel(int index) {
    return 'Część $index';
  }

  @override
  String mediaCutterPartRange(String start, String end) {
    return 'Od $start do $end';
  }

  @override
  String get mediaCutterSave => 'Zapisz';

  @override
  String get mediaCutterReady => 'Gotowe.';

  @override
  String get mediaCutterUnsavedExitTitle => 'Plik nie został zapisany';

  @override
  String get mediaCutterUnsavedExitMessage =>
      'Plik nie został zapisany. Czy na pewno chcesz wyjść?';

  @override
  String get mediaCutterNoFile => 'Najpierw otwórz plik multimedialny.';

  @override
  String get mediaCutterInvalidSplitPoint =>
      'Wybierz punkt wewnątrz pliku, nie początek ani koniec.';

  @override
  String get mediaCutterSplitAlreadyExists =>
      'W tym miejscu już istnieje podział.';

  @override
  String mediaCutterSplitAdded(String position) {
    return 'Dodano podział w $position.';
  }

  @override
  String get mediaCutterSaving => 'Przetwarzanie...';

  @override
  String mediaCutterSaved(String fileName) {
    return 'Plik zapisany: $fileName';
  }

  @override
  String mediaCutterLoadFailed(Object error) {
    return 'Nie udało się otworzyć pliku: $error';
  }

  @override
  String mediaCutterSaveFailed(Object error) {
    return 'Zapisywanie nie powiodło się: $error';
  }

  @override
  String get mediaCutterNoPartsToSave =>
      'Pozostaw co najmniej jedną część przed zapisaniem.';

  @override
  String get mediaCutterRestoreDeletedPart => 'Przywróć usuniętą część';

  @override
  String get mediaCutterNoDeletedParts =>
      'Nie ma usuniętych części do przywrócenia.';

  @override
  String get mediaCutterPartDeleteAction => 'Usuń';

  @override
  String get mediaCutterPartTapHint =>
      'Stuknij dwukrotnie, aby odsłuchać tę część. Użyj akcji Edytuj część, Usuń albo Dostosuj efekty.';

  @override
  String mediaCutterPartDeleted(String start, String end) {
    return 'Usunięto część od $start do $end.';
  }

  @override
  String mediaCutterPartRestored(String start, String end) {
    return 'Przywrócono część od $start do $end.';
  }

  @override
  String get mediaCutterPartEffectsAction => 'Dostosuj efekty';

  @override
  String get mediaCutterPartEditAction => 'Edytuj część';

  @override
  String get mediaCutterPartEditDescription =>
      'Przesuń początek lub koniec części o 1 sekundę, a potem odsłuchaj zmienioną część.';

  @override
  String mediaCutterPartAdjusted(String start, String end) {
    return 'Część zmieniona od $start do $end.';
  }

  @override
  String get mediaCutterPartEffectsTitle => 'Efekty części';

  @override
  String get mediaCutterPartEffectsDescription =>
      'Dostosuj głośność i efekt tylko dla tej części.';

  @override
  String get mediaCutterPartVolumeLabel => 'Głośność części';

  @override
  String mediaCutterPartVolumeValue(int percent) {
    return 'Głośność części: $percent%';
  }

  @override
  String get mediaCutterPartEffect => 'Efekt audio';

  @override
  String get mediaCutterPartEffectNone => 'Bez efektu';

  @override
  String get mediaCutterPartEffectEcho => 'Lekkie echo';

  @override
  String get mediaCutterPartEffectEchoRoom => 'Echo pokoju';

  @override
  String get mediaCutterPartEffectEchoChamber => 'Echo komory';

  @override
  String get mediaCutterPartEffectEchoCathedral => 'Echo katedry';

  @override
  String get mediaCutterPartEffectLargeRoom => 'Duży pokój';

  @override
  String get mediaCutterPartEffectSmallRoom => 'Mały pokój';

  @override
  String get mediaCutterPartEffectBathroom => 'Łazienka';

  @override
  String get mediaCutterPartEffectTunnel => 'Tunel';

  @override
  String get mediaCutterPartEffectRepeatEcho => 'Powtarzające echo';

  @override
  String get mediaCutterPartEffectCorridor => 'Korytarz';

  @override
  String get mediaCutterPartEffectDelay => 'Delay';

  @override
  String get mediaCutterPartEffectReverb => 'Lekki pogłos';

  @override
  String get mediaCutterPartEffectChorus => 'Chorus';

  @override
  String get mediaCutterPartEffectPitchLow => 'Niski ton';

  @override
  String get mediaCutterPartEffectPitchVeryLow => 'Bardzo niski ton';

  @override
  String get mediaCutterPartEffectPitchHigh => 'Wysoki ton';

  @override
  String get mediaCutterPartEffectPitchVeryHigh => 'Bardzo wysoki ton';

  @override
  String get mediaCutterPartEffectRobot => 'Głos robota';

  @override
  String get mediaCutterPartEffectSuperRobot => 'Super robot';

  @override
  String get mediaCutterPartEffectHelicopter => 'Helikopter';

  @override
  String get mediaCutterPartEffectAlien => 'Obcy vibrato';

  @override
  String get mediaCutterPartEffectBrightVoice => 'Jaśniejszy głos';

  @override
  String get mediaCutterPartEffectDarkVoice => 'Ciemniejszy głos';

  @override
  String get mediaCutterPartEffectGhost => 'Duch';

  @override
  String get mediaCutterPartEffectTelephone => 'Telefon';

  @override
  String get mediaCutterPartEffectOldRadio => 'Stare radio';

  @override
  String get mediaCutterPartEffectMegaphone => 'Megafon';

  @override
  String get mediaCutterPartEffectUnderwater => 'Pod wodą';

  @override
  String get mediaCutterPartEffectMonster => 'Potwór';

  @override
  String get mediaCutterPartEffectChipmunk => 'Wiewiórka';

  @override
  String get mediaCutterPartEffectDream => 'Sen';

  @override
  String get mediaCutterPartEffectDistortion => 'Przester';

  @override
  String get mediaCutterPartEffectLoFi => 'Lo-fi';

  @override
  String get mediaCutterPartEffectReverseEcho => 'Odwrócone echo';

  @override
  String get mediaCutterPartEffectFadeIn => 'Narastanie';

  @override
  String get mediaCutterPartEffectFadeOut => 'Wyciszenie';

  @override
  String get mediaCutterPartEffectAmountLabel => 'Intensywność efektu';

  @override
  String mediaCutterPartEffectAmountValue(int percent) {
    return 'Intensywność efektu: $percent%';
  }

  @override
  String get mediaCutterPartPreviewAction => 'Odsłuchaj podgląd';

  @override
  String get mediaCutterPartEffectsSavedOnly =>
      'Podgląd używa wybranej głośności. Efekty audio zostaną zastosowane podczas zapisywania.';

  @override
  String mediaCutterPartEffectsApplied(String start, String end) {
    return 'Zaktualizowano efekty dla części od $start do $end.';
  }

  @override
  String mediaCutterPartEffectsSummary(int percent, String effect) {
    return 'Głośność $percent%, efekt $effect';
  }

  @override
  String get mediaCutterGuidedModeTitle => 'Cięcie z przewodnikiem';

  @override
  String get mediaCutterGuidedModeDescription =>
      'Dobre dla początkujących. Wybierz punkt początkowy i końcowy, odsłuchaj wycinany fragment, a potem zastosuj cięcie.';

  @override
  String get mediaCutterAdvancedModeTitle => 'Cięcie zaawansowane';

  @override
  String get mediaCutterAdvancedModeDescription =>
      'Inspirowane popularnymi programami do edycji multimediów. Pozwala podzielić plik na części i usunąć niechciane fragmenty.';

  @override
  String get mediaCutterChangeCutMode => 'Zmień typ cięcia';

  @override
  String get mediaCutterGuidedSetStart => 'Początek cięcia';

  @override
  String get mediaCutterGuidedSetEnd => 'Koniec cięcia';

  @override
  String get mediaCutterGuidedApplyCut => 'Zastosuj cięcie';

  @override
  String get mediaCutterGuidedListenCut => 'Odsłuchaj wycinany fragment';

  @override
  String get mediaCutterGuidedModifyCut => 'Edytuj cięcie';

  @override
  String get mediaCutterGuidedMoveStartBackOneSecond =>
      'Przesuń początek cięcia o 1 sekundę wstecz';

  @override
  String get mediaCutterGuidedMoveStartForwardOneSecond =>
      'Przesuń początek cięcia o 1 sekundę do przodu';

  @override
  String get mediaCutterGuidedMoveEndBackOneSecond =>
      'Przesuń koniec cięcia o 1 sekundę wstecz';

  @override
  String get mediaCutterGuidedMoveEndForwardOneSecond =>
      'Przesuń koniec cięcia o 1 sekundę do przodu';

  @override
  String get mediaCutterCutEditPrecisionLabel => 'Precyzja edycji cięcia';

  @override
  String mediaCutterCutEditPrecisionValue(String value) {
    return 'Precyzja edycji cięcia: $value';
  }

  @override
  String get mediaCutterCutEditStepOneSecond => '1 sekunda';

  @override
  String get mediaCutterCutEditStepHalfSecond => '0,5 sekundy';

  @override
  String get mediaCutterCutEditStepQuarterSecond => '0,25 sekundy';

  @override
  String get mediaCutterCutEditStepTenthSecond => '0,10 sekundy';

  @override
  String mediaCutterMoveStartBackBy(String value) {
    return 'Przesuń początek cięcia wstecz o $value';
  }

  @override
  String mediaCutterMoveStartForwardBy(String value) {
    return 'Przesuń początek cięcia do przodu o $value';
  }

  @override
  String mediaCutterMoveEndBackBy(String value) {
    return 'Przesuń koniec cięcia wstecz o $value';
  }

  @override
  String mediaCutterMoveEndForwardBy(String value) {
    return 'Przesuń koniec cięcia do przodu o $value';
  }

  @override
  String mediaCutterGuidedCutAdjusted(String start, String end) {
    return 'Zmieniono cięcie od $start do $end.';
  }

  @override
  String get mediaCutterGuidedNoCut => 'Brak cięcia';

  @override
  String get mediaCutterGuidedEffectsAction => 'Dostosuj efekty pliku';

  @override
  String get mediaCutterGuidedEffectsDescription =>
      'Dostosuj głośność i efekty dla całego pliku wynikowego.';

  @override
  String get mediaCutterGuidedFileTapHint =>
      'Stuknij dwukrotnie, aby odtworzyć wynikowy plik. Użyj opcji dostosowania efektów, aby zastosować je do całego pliku.';

  @override
  String mediaCutterGuidedStartSet(String start) {
    return 'Początek cięcia ustawiony na $start.';
  }

  @override
  String mediaCutterGuidedEndSet(String start, String end) {
    return 'Koniec cięcia ustawiony na $end. Cięcie od $start do $end.';
  }

  @override
  String mediaCutterGuidedCutApplied(String start, String end) {
    return 'Zastosowano cięcie od $start do $end.';
  }

  @override
  String get mediaCutterGuidedNeedStartEnd =>
      'Najpierw ustaw początek i koniec cięcia.';

  @override
  String mediaCutterGuidedCutSummary(String start, String end) {
    return 'Cięcie od $start do $end';
  }

  @override
  String mediaCutterGuidedMultipleCutSummary(int count, String cuts) {
    return '$count cięć: $cuts';
  }

  @override
  String get mediaCutterGuidedPendingCutExitMessage =>
      'Masz niezastosowane cięcie z przewodnikiem. Czy chcesz wyjść bez jego zachowania?';

  @override
  String mediaCutterSplitAddedAnnouncement(int partNumber) {
    return 'Dodano podział. Dodano część $partNumber.';
  }

  @override
  String get newsAddCommunitySource => 'Dodaj źródło do społeczności Sonarpad';

  @override
  String get newsBrowseCommunitySources => 'Źródła społeczności';

  @override
  String get newsAddCommunityInstructions =>
      'Wpisz tytuł źródła oraz adres kanału RSS albo strony internetowej. Sonarpad użyje wybranego języka wiadomości, a jeśli wpiszesz stronę, spróbuje automatycznie znaleźć kanał.';

  @override
  String get newsCommunitySourceName => 'Tytuł źródła';

  @override
  String get newsCommunitySourceUrl => 'Adres kanału RSS lub strony';

  @override
  String get newsCommunitySubmit => 'Sprawdź i dodaj';

  @override
  String get newsCommunityChecking => 'Sprawdzanie kanału lub strony...';

  @override
  String get newsCommunityMissingFields =>
      'Wpisz tytuł i adres kanału lub strony.';

  @override
  String get newsCommunityAdded => 'Źródło dodane do społeczności Sonarpad.';

  @override
  String newsCommunityAddError(Object error) {
    return 'Błąd podczas dodawania źródła: $error';
  }

  @override
  String newsCommunitySelectedLanguage(Object language) {
    return 'Wybrany język: $language';
  }

  @override
  String get newsCommunitySourcesTitle => 'Źródła społeczności';

  @override
  String get newsCommunitySourcesEmpty =>
      'Brak źródeł społeczności dla tego języka.';

  @override
  String newsCommunitySourcesError(Object error) {
    return 'Błąd ładowania źródeł społeczności: $error';
  }

  @override
  String newsCommunitySourceAddedToLibrary(Object name) {
    return 'Dodano $name do biblioteki wiadomości.';
  }

  @override
  String newsCommunityAddToLibraryError(Object error) {
    return 'Błąd podczas dodawania do biblioteki: $error';
  }

  @override
  String get newsCommunitySourceTapHint =>
      'Stuknij, aby dodać do swojej biblioteki wiadomości.';
  @override
  String get developerModeEnabled => 'Tryb programisty włączony.';

  @override
  String get developerModeDisabled => 'Tryb programisty wyłączony.';

  @override
  String get developerSectionTitle => 'Deweloper';

  @override
  String get developerUseExperimentalFlutterRenderer => 'Użyj eksperymentalnego renderera Flutter';

  @override
  String get developerUseExperimentalFlutterRendererHint => 'Tymczasowo wyłącza UIKit, aby porównać VoiceOver z czystym Flutterem.';

  // Shared labels generated from ARB entries.
  @override
  String get letterJumpSelectLetter => 'Wybierz literę';

  @override
  String get letterJumpSelected => 'wybrano';

  @override
  String get settingsToggleOn => 'Włączone';

  @override
  String get settingsToggleOff => 'Wyłączone';

  @override
  String get settingsShowOnlyMultilingualEdgeVoices => 'Pokaż tylko głosy wielojęzyczne';

  @override
  String get radioDirectoryLoading => 'Aktualizuję kraje i języki radia...';

  @override
  String get recentRadios => 'Ostatnie radia';

  @override
  String get radioNextPage => 'Następne';

  @override
  String radioPageOf(int current, int total) {
    return 'Strona $current z $total';
  }

  @override
  String get radioNoResultsWithQuery => 'Nie znaleziono stacji. Spróbuj wpisać tylko nazwę stacji, bez gatunku, albo zmień język/kraj.';

  @override
  String get radioNoResultsGeneric => 'Nie znaleziono stacji. Spróbuj innego języka, kraju albo gatunku.';

  @override
  String radioSearchRawError(Object error) {
    return 'Błąd wyszukiwania radia: $error';
  }

  @override
  String get radioBrowserConnectionError => 'Błąd połączenia z Radio Browser. Spróbuj ponownie później.';

  @override
  String get documentIndexLoadingMessage => 'Ładowanie spisu treści... Proszę czekać.';

  @override
  String get documentIndexUnavailableMessage => 'Spis treści nie jest dostępny dla tego EPUB-a.';

  @override
  String mediaCutterVolumeSummary(int percent) {
    return 'głośność $percent%';
  }

  @override
  String mediaCutterDurationSummary(String duration) {
    return 'czas trwania $duration';
  }

  @override
  String get mediaCutterDurationHourOne => 'godzina';

  @override
  String get mediaCutterDurationHourFew => 'godziny';

  @override
  String get mediaCutterDurationHourMany => 'godzin';

  @override
  String get mediaCutterDurationMinuteOne => 'minuta';

  @override
  String get mediaCutterDurationMinuteFew => 'minuty';

  @override
  String get mediaCutterDurationMinuteMany => 'minut';

  @override
  String get mediaCutterDurationSecondOne => 'sekunda';

  @override
  String get mediaCutterDurationSecondFew => 'sekundy';

  @override
  String get mediaCutterDurationSecondMany => 'sekund';

  @override
  String get mediaCutterDurationAnd => 'i';

  @override
  String mediaCutterSeekStepButton(String step) {
    return 'Dostosuj przesuwanie pliku multimedialnego: $step';
  }

  @override
  String get mediaCutterSeekStepTitle => 'Przesuwanie pliku multimedialnego';

  @override
  String mediaCutterSeekStepSelected(String step) {
    return 'Przesuwanie pliku multimedialnego ustawione na $step.';
  }

  @override
  String get mediaCutterPartEffectBackwards => 'Wstecz';

  @override
  String get mediaCutterPartEffectTalkingGuitar => 'Mówiąca gitara';

  @override
  String get mediaCutterPartEffectMosquito => 'Komar';

  @override
  String get mediaCutterPartEffectOneOfMany => 'Jeden głos, wielu śpiewaków';

  @override
  String get mediaCutterPartEffectOrganVocoder => 'Mówiące organy';

  @override
  String get mediaCutterPartEffectWarped => 'Zniekształcony';

  @override
  String get mediaCutterPartEffectSwirling => 'Wir stereo';

  @override
  String get mediaCutterPartEffectVader => 'Filmowy ciemny głos';

  @override
  String get mediaCutterPartEffectMetallic => 'Metaliczny';

  @override
  String get mediaCutterPartEffectSongbird => 'Ptak śpiewający';

  @override
  String get mediaCutterPartEffectExterminator => 'Eksterminator';

  @override
  String get mediaCutterPartEffectRainAndThunder => 'Deszcz i grzmoty';

  @override
  String get mediaCutterPartEffectJungle => 'Dżungla';

  @override
  String get mediaCutterPartEffectCrowd => 'Tłum';

  @override
  String get mediaCutterPartEffectSlotMachines => 'Automaty do gry';

  @override
  String get mediaCutterPartEffectTraffic => 'Ruch uliczny';

  @override
  String get mediaCutterPartEffectSpaceship => 'Statek kosmiczny';

  @override
  String get mediaCutterPartEffectCricket => 'Świerszcz';

  @override
  String get mediaCutterPartEffectSiren => 'Syrena';

  @override
  String get mediaCutterPartEffectSleighBells => 'Dzwonki sań';

  @override
  String get mediaCutterPartEffectDj => 'DJ i scratch';

  @override
  String get mediaCutterPartEffectApplause => 'Oklaski';

  @override
  String get mediaCutterPartEffectBadMelody => 'Fałszywa melodia';

  @override
  String get mediaCutterPartEffectBadHarmony => 'Dysonansowa harmonia';

  @override
  String get mediaCutterPartEffectWarmVoice => 'Ciepły głos';

  @override
  String get mediaCutterPartEffectTurtle => 'Żółw';

  @override
  String get mediaCutterPartEffectHaunting => 'Nawiedzony';

  @override
  String get radioPreviousPage => 'Poprzednie';

  @override
  String get noRecentRadios => 'Brak ostatnich stacji radiowych.';

  @override
  String get radioBrowseByCity => 'Przeglądaj według miasta';

  @override
  String get radioCityInputHint => 'Wpisz miasto...';

  @override
  String get openItem => 'Otwórz';

  @override
  String get clearSearch => 'Wyczyść wyszukiwanie';

  @override
  String get clearText => 'Wyczyść tekst';

  @override
  String get fileTypeLabel => 'Plik';

  @override
  String get cinemaTrailerLoading => 'Ładowanie zwiastuna';

  @override
  String get cinemaNoTrailer => 'Brak dostępnego zwiastuna dla tego filmu';

  @override
  String get radioScheduleHours => 'Godziny';

  @override
  String get radioScheduleSelectHours => 'Wybierz godziny';

  @override
  String get radioScheduleMinutes => 'Minuty';

  @override
  String get radioScheduleSelectMinutes => 'Wybierz minuty';

  @override
  String radioScheduleLabeledValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get radioScheduleStopCurrentFirst => 'Zakończ bieżące nagrywanie przed zaplanowaniem nowego.';

  @override
  String get radioScheduleStartTime => 'Godzina rozpoczęcia';

  @override
  String get radioScheduleEndTime => 'Godzina zakończenia';

  @override
  String get radioScheduleDialogTitle => 'Zaplanuj nagrywanie';

  @override
  String get radioScheduleOpenRequirement => 'Zaplanowane nagrywanie działa nadal podczas przechodzenia do innych ekranów Sonarpad. Sonarpad musi pozostać otwarty; jeśli aplikacja zostanie zamknięta lub wstrzymana przez system, rozpoczęcie nagrywania nie jest gwarantowane.';

  @override
  String radioScheduleStartTimeValue(String time) {
    return 'Godzina rozpoczęcia: $time';
  }

  @override
  String radioScheduleEndTimeValue(String time) {
    return 'Godzina zakończenia: $time';
  }

  @override
  String get radioScheduleOptionalTitle => 'Tytuł opcjonalny';

  @override
  String get radioScheduleTitleHint => 'Pozostaw puste, aby użyć nazwy radia lub TV';

  @override
  String get radioScheduleAction => 'Zaplanuj';

  @override
  String radioScheduledRecordingRange(String start, String end) {
    return 'Zaplanowane nagrywanie: $start - $end.';
  }

  @override
  String get radioScheduledRecordingAlreadyActive => 'Zaplanowane nagrywanie nie zostało uruchomione: trwa już inne nagrywanie.';

  @override
  String get radioScheduledRecordingStarted => 'Zaplanowane nagrywanie rozpoczęte.';

  @override
  String radioScheduledRecordingError(Object error) {
    return 'Błąd zaplanowanego nagrywania: $error';
  }

  @override
  String get radioScheduledRecordingSaved => 'Zaplanowane nagrywanie zapisane.';

  @override
  String radioScheduledRecordingSaveError(Object error) {
    return 'Błąd zapisywania zaplanowanego nagrywania: $error';
  }

  @override
  String get radioScheduledRecordingCancelled => 'Zaplanowane nagrywanie anulowane.';

  @override
  String radioScheduledRecordingRangeWithTitle(String start, String end, String title) {
    return 'Zaplanowane nagrywanie: $start - $end. Tytuł: $title.';
  }

  @override
  String get radioScheduleCancelAction => 'Anuluj zaplanowane nagrywanie';
  @override
  String get radioLanguageTr => 'Turecki';

  @override
  String get radioCountryOptionTr => 'Turcja';

  @override
  String get radioCommunityLanguageTurkish => 'Turecki';
  @override
  String get simplifiedChineseLanguageName => 'Chiński uproszczony';

  @override
  String get chinaCountryName => 'Chiny';

  @override
  String get technicalErrorGeneric => 'Błąd techniczny. Spróbuj ponownie.';

  @override
  String cinemaTrailerTitle(String title) {
    return 'Zwiastun: $title';
  }

  @override
  String mediaCutterExportPartProgress(int index, int total) {
    return 'Część $index z $total';
  }

  @override
  String get mediaCutterExportFinalVerification => 'Końcowa weryfikacja';

  @override
  String get mediaCutterExportMergeParts => 'Łączenie części';

  @override
  String get mediaCutterExportFileCheck => 'Sprawdzanie pliku';

  @override
  String get mediaCutterExportPublishing => 'Publikowanie';

  @override
  String get mediaCutterExportCompletion => 'Kończenie';


  @override
  String get mediaCutterAddTrack => 'Dodaj nową ścieżkę';

  @override
  String get mediaCutterChooseAudioTrack => 'Wybierz plik audio';

  @override
  String mediaCutterAddedTrackSelected(String name) => 'Wybrany plik audio: $name';

  @override
  String get mediaCutterOriginalTrackVolume => 'Głośność oryginalnej ścieżki';

  @override
  String get mediaCutterNewTrackVolume => 'Głośność nowej ścieżki';

  @override
  String get mediaCutterLoopNewTrack => 'Odtwarzaj nową ścieżkę w pętli';

  @override
  String get mediaCutterPreviewNewTrack => 'Odsłuchaj podgląd';

  @override
  String get mediaCutterFinalizeTrack => 'Zakończ';

  @override
  String mediaCutterAddedTrackApplied(String name) => 'Dodano nową ścieżkę: $name';

  @override
  String get mediaCutterAddedTrackInvalidAudio => 'Wybrany plik nie zawiera prawidłowej ścieżki audio.';

  @override
  String get mediaCutterAddedTrackPreviewPreparing => 'Przygotowywanie podglądu…';

  @override
  String get mediaCutterAddedTrackPreviewFailed => 'Nie można utworzyć podglądu.';

  @override
  String get mediaCutterMixingAddedTrack => 'Miksowanie nowej ścieżki';


  @override
  String get mediaProcessingCompleted => 'Przetwarzanie zakończone.';

  @override
  String get saveInSonarpadDocuments => 'Zapisz w Dokumentach Sonarpad';

  @override
  String get mediaCutterProcess => 'Przetwórz';

  @override
  String get preserveMedia => 'Zachowaj zawartość';

  @override
  String get preserveMediaSaving => 'Zapisywanie zawartości…';

  @override
  String get preserveMediaSaved => 'Zawartość zapisano w Dokumentach Sonarpad.';

  @override
  String get preserveMediaError => 'Nie udało się zachować zawartości.';


  @override
  String get rename => 'Zmień nazwę';

  @override
  String get renameRecording => 'Zmień nazwę nagrania';

  @override
  String get renameDocument => 'Zmień nazwę dokumentu';

  @override
  String get newDocumentName => 'Nowa nazwa dokumentu';

  @override
  String get documentNameAlreadyExists => 'Dokument o tej nazwie już istnieje.';

  @override
  String get newRecordingName => 'Nowa nazwa nagrania';

  @override
  String get recordingCannotRenameWhileInProgress => 'Nie można zmienić nazwy trwającego nagrania.';

  @override
  String get recordingNameAlreadyExists => 'Nagranie o tej nazwie już istnieje.';

  @override
  String get recordingExitPrompt => 'Nagrywanie trwa. Czy chcesz je zatrzymać, czy kontynuować nagrywanie?';

  @override
  String get continueRecording => 'Kontynuuj nagrywanie';

}
