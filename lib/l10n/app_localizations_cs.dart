// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'Sonarpad';

  @override
  String get appLanguage => 'Jazyk aplikace';

  @override
  String get settingsTheme => 'Vzhled aplikace';

  @override
  String get settingsThemeSystem => 'Podle systému';

  @override
  String get settingsThemeLight => 'Světlý';

  @override
  String get settingsThemeDark => 'Tmavý';

  @override
  String get homeSemanticsLabel => 'Sonarpad, hlavní obrazovka';

  @override
  String get settings => 'Nastavení';

  @override
  String get settingsHint => 'Otevřít nastavení';

  @override
  String get info => 'Informace';

  @override
  String get infoHint => 'Otevřít informace o aplikaci';

  @override
  String get categoryReading => 'Čtení a dokumenty';

  @override
  String get categoryMedia => 'Média a zábava';

  @override
  String get categoryUtilities => 'Vyhledávání a nástroje';

  @override
  String get voiceDictionaryTitle => 'Hlasový slovník';

  @override
  String get voiceDictionaryAdd => 'Přidat položky do slovníku';

  @override
  String get voiceDictionaryOriginalWord => 'Původní slovo';

  @override
  String get voiceDictionaryReplacementWord => 'Náhradní slovo';

  @override
  String get voiceDictionaryMatchCase => 'Rozlišovat velikost písmen';

  @override
  String get voiceDictionaryIgnoreCase => 'Nerozlišovat velikost písmen';

  @override
  String get voiceDictionaryEntries => 'Položky slovníku';

  @override
  String get voiceDictionaryEmpty => 'Žádné položky ve slovníku.';

  @override
  String get voiceDictionaryRemove => 'Odebrat vybranou položku';

  @override
  String get voiceDictionaryOriginalRequired => 'Zadejte původní slovo.';

  @override
  String get convertMediaTitle => 'Převést média';

  @override
  String get convertMediaInput => 'Vstupní soubor';

  @override
  String get convertMediaOutput => 'Výstupní soubor';

  @override
  String get convertMediaImage => 'Obrázek';

  @override
  String get convertMediaBrowse => 'Procházet...';

  @override
  String get convertMediaFormat => 'Formát';

  @override
  String get convertMediaBitrate => 'Datový tok (kb/s)';

  @override
  String get convertMediaOggQuality => 'Kvalita (q)';

  @override
  String get convertMediaFlacCompression => 'Úroveň komprese';

  @override
  String get convertMediaWavBitDepth => 'WAV bit depth';

  @override
  String get convertMediaReady => 'Připraveno.';

  @override
  String get convertMediaRunning => 'Převádím...';

  @override
  String get convertMediaDone => 'Převod dokončen.';

  @override
  String get convertMediaButton => 'Převést média';

  @override
  String get convertMediaNoInput => 'Vyberte vstupní soubor.';

  @override
  String get convertMediaNoOutput => 'Vyberte výstupní soubor.';

  @override
  String get convertMediaNoImage => 'Vyberte obrázek pro video.';

  @override
  String get convertMediaSamePath =>
      'Výstupní soubor musí být jiný než vstupní.';

  @override
  String get convertMediaInvalidBitrate =>
      'Neplatný datový tok. Zadejte hodnotu mezi 64 a 320 kb/s.';

  @override
  String convertMediaFailed(Object error) {
    return 'Převod se nezdařil: $error';
  }

  @override
  String get donations => 'Dary';

  @override
  String get donationsHint => 'Podpořit vývoj Sonarpadu';

  @override
  String get loading => 'Načítání';

  @override
  String get ttsVoiceLanguage => 'Jazyk hlasu TTS';

  @override
  String get ttsVoice => 'Hlas TTS';

  @override
  String get saveSettings => 'Uložit nastavení';

  @override
  String get settingsSaved => 'Nastavení uloženo.';

  @override
  String get settingsSavedTitle => 'Nastavení uloženo';

  @override
  String get sonarpadCodeValidTitle => 'Platný kód';

  @override
  String get sonarpadCodeValidMessage =>
      'Kód Sonarpadu je správný. Nastavení uloženo.';

  @override
  String get sonarpadCodeInvalidTitle => 'Neplatný kód';

  @override
  String get sonarpadCodeInvalidMessage =>
      'Kód Sonarpadu není platný. Zkontrolujte, zda jste ho zkopírovali bez mezer navíc.';

  @override
  String get infoDescription =>
      'Sonarpad je jednoduchá aplikace s mnoha funkcemi. Je navržena tak, aby byla přístupná s VoiceOverem pro nevidomé a slabozraké uživatele. Umožňuje poslouchat zprávy, vyhledávat a odebírat podcasty, importovat články z Wikipedie, přidávat dokumenty do knihovny, ukládat je a upravovat. Sonarpad je průběžně aktualizován a každá funkce je navržena tak, aby usnadnila každodenní používání.';

  @override
  String get infoAuthor => 'Autor: Ambrogio Riili';

  @override
  String get donationsIntro =>
      'Sonarpad vznikl původně pro osobní potřeby, ale postupně se rozrostl v širší aplikaci. Jeho vývoj vyžaduje stálou práci: zlepšování funkcí, opravy chyb, hledání nových nápadů a pečlivé testování každé části.\n\nPokud je pro vás Sonarpad užitečný a chcete podpořit jeho vývoj, můžete přispět darem.';

  @override
  String get donationsPaypalDesc =>
      'Dar můžete poslat přes PayPal pomocí tohoto odkazu:\nhttps://www.paypal.me/ambrogio86\nPokud je to možné, přidejte do poznámky platby slovo „Sonarpad“.';

  @override
  String get donationsBankDesc =>
      'Dar můžete poslat také bankovním převodem na účet vedený na jméno Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nPokud je to možné, použijte jasný důvod platby, například „Sonarpad“.';

  @override
  String get donationsThanks =>
      'Anyone who supports the project will be mentioned in the program and on the GitHub repository, unless they prefer to stay anonymous or use a nickname.\n\nThanks to Jiri Holzinger and Paola Vagata for their contribution.\nFor the Vietnamese translation, thanks to Anh Đức Nguyễn.\nFor the Czech translation, thanks to Radek Žalud and Jiri Holzinger.\nFor the Spanish translation, thanks to Arturo Fernandez Rivas.\nFor the Serbian translation, thanks to Mila Kuran.\nFor the Ukrainian translation, thanks to Ivan Shtefuriak.';

  @override
  String get news => 'Zprávy';

  @override
  String get newsHint => 'Otevřít zprávy z RSS a Google News';

  @override
  String get podcasts => 'Podcasts';

  @override
  String get podcastsHint => 'Subscribe to podcasts, play or download episodes';

  @override
  String get importFromWikipedia => 'Wikipedia';

  @override
  String get wikipediaHint =>
      'Search for a Wikipedia article and import the text';

  @override
  String get newsCategoryTop => 'Hlavní zprávy';

  @override
  String get settingsHomeGrouping =>
      'Seskupovat ikony domovské obrazovky do kategorií';

  @override
  String get settingsHomeGroupingHint =>
      'Pokud je vypnuto, hlavní ikony se zobrazí jako jeden seznam bez složek';

  @override
  String get newsCategoryMyCity => 'Moje město';

  @override
  String get newsLocalCityLabel => 'Zadejte město';

  @override
  String get newsLocalCityHint => 'Upravte město použité pro místní zprávy';

  @override
  String get update => 'Update';

  @override
  String get moveUp => 'Přesunout nahoru';

  @override
  String get moveDown => 'Přesunout dolů';

  @override
  String get hide => 'Smazat';

  @override
  String get moveToPosition => 'Přesunout na pozici';

  @override
  String positionLabel(int position, String targetName) {
    return 'Pozice $position: před $targetName';
  }

  @override
  String get positionLabelLast => 'Poslední pozice';

  @override
  String get restoreHiddenSources => 'Obnovit smazané zdroje';

  @override
  String get addCustomNewsSource => 'Přidat vlastní RSS zdroj';

  @override
  String get newsSourceName => 'Název zdroje nebo webu';

  @override
  String get newsSourceUrlOrSearch =>
      'Adresa webu, RSS kanál nebo hledané slovo';

  @override
  String get deleteNewsSource => 'Smazat zdroj';

  @override
  String get articleTextSemantics => 'Text článku';

  @override
  String get newsLanguage => 'Jazyk zpráv';

  @override
  String get loadingNews => 'Načítání zpráv';

  @override
  String error(Object error) {
    return 'Chyba: $error';
  }

  @override
  String get noNewsFound => 'Nebyly nalezeny žádné zprávy';

  @override
  String get loadingArticle => 'Načítání článku';

  @override
  String get noFullArticleFound =>
      'Celý článek není k dispozici. Zobrazuje se souhrn z kanálu.';

  @override
  String get italian => 'Italština';

  @override
  String get english => 'Angličtina';

  @override
  String get french => 'Francouzština';

  @override
  String get spanish => 'Španělština';

  @override
  String get newsSource => 'Zdroj zpráv';

  @override
  String get article => 'Článek';

  @override
  String get articlePreview => 'Náhled článku';

  @override
  String get readFullArticle => 'Přečíst celý článek';

  @override
  String get extractingReaderArticleText => 'Načítám text v režimu čtení...';

  @override
  String get extractingVisibleArticleText =>
      'Načítám viditelný text ze stránky...';

  @override
  String source(String source) {
    return 'Zdroj: $source';
  }

  @override
  String get readyStatus => 'Připraveno.';

  @override
  String get preparingEdgeTts => 'Připravuji čtení Edge TTS po blocích...';

  @override
  String get noTextToRead => 'Není žádný text ke čtení.';

  @override
  String chunkCreated(int index, int total) {
    return 'Blok $index z $total vytvořen. Čtení probíhá...';
  }

  @override
  String playingChunk(int index, int total, int size) {
    return 'Přehrávám blok $index z $total ($size bajtů)...';
  }

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) {
    return 'Čtení dokončeno. Vytvořené bloky: $readyChunks/$totalChunks. Knihovna: $libraryPath';
  }

  @override
  String get libraryNotSpecified => 'není zadáno';

  @override
  String get readingStopped => 'Čtení zastaveno.';

  @override
  String edgeTtsError(Object error) {
    return 'Chyba Edge TTS: $error';
  }

  @override
  String audioChunksReady(int readyChunks, int totalChunks) {
    return 'Zvukové bloky připraveny: $readyChunks / $totalChunks';
  }

  @override
  String get readingInProgress => 'Čtení probíhá...';

  @override
  String get readWithEdgeTts => 'Spustit čtení';

  @override
  String get stopReading => 'Zastavit čtení';

  @override
  String get startReading => 'Spustit čtení';

  @override
  String get resumeReading => 'Pokračovat ve čtení';

  @override
  String get pauseReading => 'Pozastavit čtení';

  @override
  String get openOriginalArticle => 'Otevřít původní článek';

  @override
  String get searchPodcasts => 'Hledat podcasty';

  @override
  String get podcastName => 'Název podcastu';

  @override
  String get podcastSearchHint =>
      'Příklad: technologie, historie, název podcastu...';

  @override
  String get searchCountry => 'Země hledání';

  @override
  String get podcastCategory => 'Kategorie podcastu';

  @override
  String get browsePodcastCategories => 'Procházet kategorie';

  @override
  String get selectedPodcastCategory => 'Vybraná kategorie';

  @override
  String get podcastCategories => 'Kategorie podcastů';

  @override
  String get countryItaly => 'Itálie';

  @override
  String get countryUnitedStatesEnglish => 'Spojené státy / angličtina';

  @override
  String get countryUnitedKingdom => 'Spojené království';

  @override
  String get countrySpain => 'Španělsko';

  @override
  String get countryFrance => 'Francie';

  @override
  String get searchInProgress => 'Vyhledávání probíhá...';

  @override
  String get newsReadArticles => 'Read articles';

  @override
  String get weatherRecentCities => 'Recent cities';

  @override
  String podcastResultsFound(int count) {
    return 'Nalezeno podcastů: $count';
  }

  @override
  String podcastSearchError(Object error) {
    return 'Chyba vyhledávání podcastů: $error';
  }

  @override
  String subscribedTo(String title) {
    return 'Odebíráno: $title';
  }

  @override
  String subscriptionError(Object error) {
    return 'Chyba odběru: $error';
  }

  @override
  String podcastSubscriptionError(Object error) {
    return 'Chyba odběru podcastu: $error';
  }

  @override
  String get searchResults => 'Výsledky hledání';

  @override
  String get podcastInfo => 'Informace o podcastu';

  @override
  String get subscribe => 'Odebírat';

  @override
  String get viewEpisodes => 'Zobrazit epizody';

  @override
  String get podcastAuthor => 'Autor';

  @override
  String get noPodcastDescription => 'Popis není k dispozici.';

  @override
  String get noPodcastResults => 'Nebyly nalezeny žádné podcasty.';

  @override
  String get loadingPodcastInfo => 'Načítání informací o podcastu';

  @override
  String get podcastArtwork => 'Obrázek podcastu';

  @override
  String get addFeedUrlManually => 'Přidat adresu RSS kanálu ručně';

  @override
  String get podcastFeedUrl => 'RSS adresa podcastu';

  @override
  String get subscribeFromUrl => 'Odebírat z adresy';

  @override
  String get subscribedPodcasts => 'Odebírané podcasty';

  @override
  String get noSubscribedPodcasts =>
      'Žádné odebírané podcasty. Vyhledejte podcast a klepnutím na výsledek ho začněte odebírat.';

  @override
  String get localAudioFiles => 'Local audio files';

  @override
  String get noLocalAudioFiles => 'No local audio files found.';

  @override
  String get importAudioFromITunes =>
      'Import audio from iTunes / Apple Devices';

  @override
  String localAudioFilesFound(int count) {
    return 'Local audio files found: $count';
  }

  @override
  String get importPodcastsFromFile => 'Importovat podcasty ze souboru';

  @override
  String get exportPodcastsToFile => 'Exportovat podcasty do souboru OPML';

  @override
  String podcastImportComplete(int count) {
    return 'Importované podcasty: $count';
  }

  @override
  String podcastImportError(Object error) {
    return 'Chyba importu podcastů: $error';
  }

  @override
  String get podcastExportComplete => 'Podcasty exportovány';

  @override
  String podcastExportError(Object error) {
    return 'Chyba exportu podcastů: $error';
  }

  @override
  String get loadingEpisodes => 'Načítání epizod';

  @override
  String get noAudioEpisodesFound =>
      'V kanálu nebyly nalezeny žádné zvukové epizody.';

  @override
  String get episodes => 'Epizody';

  @override
  String get episodeActions => 'Akce epizody';

  @override
  String downloaded(String path) {
    return 'Staženo: $path';
  }

  @override
  String episodeError(Object error) {
    return 'Chyba epizody: $error';
  }

  @override
  String get play => 'Přehrát';

  @override
  String get pause => 'Pozastavit';

  @override
  String get rewind15s => 'Zpět o 15 s';

  @override
  String get forward15s => 'Vpřed o 15 s';

  @override
  String get stop => 'Zastavit';

  @override
  String get back => 'Zpět';

  @override
  String get episodePlayer => 'Přehrávač epizody';

  @override
  String nowPlayingTitle(String title) {
    return 'Nyní se přehrává: $title';
  }

  @override
  String get loadingEpisodeAudio => 'Načítání zvuku epizody';

  @override
  String get playbackPosition => 'Pozice';

  @override
  String playbackPositionValue(String position, String duration) {
    return '$position z $duration';
  }

  @override
  String get adjustVolume => 'Adjust volume';

  @override
  String volumeValue(int percentage) {
    return 'Volume: $percentage%';
  }

  @override
  String get download => 'Stáhnout';

  @override
  String get searchWikipedia => 'Hledat na Wikipedii';

  @override
  String get wikipediaLanguage => 'Jazyk Wikipedie';

  @override
  String get search => 'Hledat';

  @override
  String get wikipediaSearch => 'Vyhledávání na Wikipedii';

  @override
  String get wikipediaImporting => 'Import z Wikipedie';

  @override
  String get noWikipediaResults =>
      'Nebyly nalezeny žádné výsledky na Wikipedii';

  @override
  String get wikipediaImportMode => 'Režim importu';

  @override
  String get wikipediaImportWholeArticle => 'Celý článek';

  @override
  String get documents => 'Dokumenty';

  @override
  String get documentsHint => 'Otevřít knihovnu dokumentů';

  @override
  String get documentLibrary => 'Knihovna dokumentů';

  @override
  String get addToLibrary => 'Přidat do knihovny';

  @override
  String get documentImportSelectionMode =>
      'Chcete vybrat jeden dokument, nebo více dokumentů?';

  @override
  String get documentImportSingle => 'Jeden dokument';

  @override
  String get documentImportMultiple => 'Více dokumentů';

  @override
  String get noDocuments => 'Žádné dokumenty. Přidejte soubor.';

  @override
  String get noDocumentsInLibrary => 'V knihovně nejsou žádné dokumenty.';

  @override
  String get documentAdded => 'Dokument přidán';

  @override
  String get documentsAdded => 'Dokumenty přidány';

  @override
  String get importDocumentsFromITunes =>
      'Import documents from iTunes / Apple Devices';

  @override
  String sharedDocumentsImportComplete(int count) {
    return 'Documents imported from iTunes / Apple Devices: $count';
  }

  @override
  String libraryLoadError(Object error) {
    return 'Chyba načítání knihovny: $error';
  }

  @override
  String fileOpenError(Object error) {
    return 'Chyba otevření souboru: $error';
  }

  @override
  String get filePathUnavailable => 'Cesta k souboru není k dispozici.';

  @override
  String fileInaccessible(String name) {
    return 'Soubor není přístupný: $name';
  }

  @override
  String documentAddError(Object error) {
    return 'Chyba přidání dokumentu: $error';
  }

  @override
  String documentRemoveError(Object error) {
    return 'Chyba odebrání: $error';
  }

  @override
  String get noExportableTextFound =>
      'Nebyl nalezen žádný exportovatelný text.';

  @override
  String get modifiedDocumentNoExportableText =>
      'Upravený dokument neobsahuje žádný exportovatelný text.';

  @override
  String get documentRemoved => 'Dokument odebrán';

  @override
  String get folderRemoved => 'Složka odebrána';

  @override
  String get removeFolder => 'Odebrat složku';

  @override
  String get removeDocument => 'Odebrat dokument';

  @override
  String get writeNewDocument => 'Napsat nový dokument';

  @override
  String get addDocumentToLibraryHint =>
      'Přidat dokument do knihovny. Procházejte soubory v zařízení a přidejte je.';

  @override
  String get documentTypeLabel => 'Dokument';

  @override
  String get documentPosition => 'Pozice dokumentu';

  @override
  String get folderTypeLabel => 'Složka';

  @override
  String documentAddedOn(String date) {
    return 'přidáno dne $date';
  }

  @override
  String documentTypeDescription(String extension) {
    return 'typ $extension';
  }

  @override
  String get openFolderHint => 'Dvojitým klepnutím otevřete složku';

  @override
  String get openDocumentHint =>
      'Dvojitým klepnutím otevřete a přečtete dokument';

  @override
  String removeItem(String name) {
    return 'Odebrat $name';
  }

  @override
  String get removePodcast => 'Odebrat podcast';

  @override
  String get podcastRemoved => 'Podcast odebrán';

  @override
  String get documentPickerError => 'Chyba při otevírání souboru';

  @override
  String get readDocument => 'Číst dokument';

  @override
  String get documentReaderTitle => 'Čtečka dokumentů';

  @override
  String get documentReaderEditHint =>
      'Klepnutím na odstavec ho upravíte. Přejetím nahoru nebo dolů přidáte záložku.';

  @override
  String get documentBookmarkHintSet =>
      'Přejetím nahoru nebo dolů nastavíte záložku.';

  @override
  String get documentEditParagraphActionHint =>
      'Dvojitým klepnutím upravíte tento odstavec. ';

  @override
  String get documentBookmarkHintReplace =>
      'Přejetím nahoru nebo dolů odeberete stávající záložku nebo ji nahradíte tímto odstavcem.';

  @override
  String get documentSetBookmarkAction => 'Nastavit záložku';

  @override
  String get documentRemoveBookmarkAction => 'Odebrat záložku';

  @override
  String get documentReplaceBookmarkAction => 'Odebrat a přidat novou záložku';

  @override
  String get searchInDocument => 'Hledat v dokumentu';

  @override
  String get documentSearchFieldLabel => 'Search text';

  @override
  String get documentSearchFieldHint => 'Word or phrase to find';

  @override
  String get documentSearchEmptyQuery => 'Enter text to search for.';

  @override
  String get documentSearchResultsTitle => 'Document search results';

  @override
  String noDocumentSearchResults(String query) {
    return 'No results found for $query.';
  }

  @override
  String documentSearchResultParagraph(int number) {
    return 'Paragraph $number';
  }

  @override
  String get edit => 'Upravit';

  @override
  String get save => 'Uložit';

  @override
  String get cancel => 'Zrušit';

  @override
  String get settingsReadingEngine => 'Modul čtení';

  @override
  String get settingsEdgeTtsQuality => 'Edge TTS (vysoká online kvalita)';

  @override
  String get settingsSystemVoices => 'Systémové hlasy (VoiceOver / Google)';

  @override
  String get settingsNoSystemVoices => 'Nejsou dostupné žádné systémové hlasy.';

  @override
  String get settingsDefaultVoiceHint => 'Výchozí hlas';

  @override
  String get settingsDefaultVoice => 'Výchozí';

  @override
  String get settingsVoiceSpeed => 'Rychlost: ';

  @override
  String get settingsVoicePitch => 'Výška: ';

  @override
  String get settingsVoiceSpeedLabel => 'Rychlost čtení';

  @override
  String get settingsVoicePitchLabel => 'Výška hlasu';

  @override
  String get settingsTestVoice => 'Otestovat hlas';

  @override
  String get settingsTestingVoice => 'Přehrávání...';

  @override
  String get settingsVoiceTestText => 'Toto je test vybraného hlasu.';

  @override
  String settingsVoiceTestError(Object error) {
    return 'Chyba testu hlasu: $error';
  }

  @override
  String settingsVoiceSaveError(Object error) {
    return 'Chyba uložení hlasu TTS: $error';
  }

  @override
  String get settingsUnsavedTitle => 'Neuložené změny';

  @override
  String get settingsUnsavedMessage =>
      'Chcete před odchodem z nastavení uložit změny?';

  @override
  String get settingsExitWithoutSaving => 'Odejít bez uložení';

  @override
  String get settingsSystemLanguage => 'Jazyk systému';

  @override
  String get settingsSystemVoice => 'Systémový hlas';

  @override
  String get settingsAutoBookmark => 'Automatická záložka';

  @override
  String get settingsAutoBookmarkHint =>
      'Pokračovat v dokumentech, podcastech, RaiPlay a audiopopisech tam, kde jste skončili.';

  @override
  String get settingsSeekStep => 'Krok zpět / vpřed pro média';

  @override
  String get aiChatIntro => 'Jsem Sonarpad AI. Jak vám mohu pomoci?';

  @override
  String get meteoTitle => 'Počasí';

  @override
  String get weatherCity => 'Město';

  @override
  String get weatherCityHint => 'Příklad: Praha';

  @override
  String get weatherCityNotFound => 'Město nebylo nalezeno';

  @override
  String get weatherSearchError => 'Chyba při hledání';

  @override
  String get weatherToday => 'Dnes';

  @override
  String get weatherCurrentSituation => 'Current situation';

  @override
  String get weatherTomorrow => 'Zítra';

  @override
  String get weatherChooseDay => 'Vyberte den';

  @override
  String get weatherCurrentTemperature => 'Aktuální teplota';

  @override
  String get weatherMaxTemperature => 'Maximální teplota';

  @override
  String get weatherMinTemperature => 'Minimální teplota';

  @override
  String get weatherPrecipitation => 'Srážky';

  @override
  String get weatherPrecipitationProbability => 'Pravděpodobnost srážek';

  @override
  String get weatherWind => 'Vítr';

  @override
  String get weatherRelativeHumidity => 'Relativní vlhkost';

  @override
  String get settingsSecretCode => 'Kód Sonarpadu pro další funkce';

  @override
  String get settingsRequestCode => 'Vyžádat kód od autora';

  @override
  String get settingsPasteCode => 'Paste code';

  @override
  String get settingsCancel => 'Zrušit';

  @override
  String get settingsSend => 'Odeslat';

  @override
  String get settingsFillFieldsCode =>
      'Vyplňte všechna pole pro vyžádání kódu.';

  @override
  String get settingsName => 'Jméno';

  @override
  String get settingsSurname => 'Příjmení';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsOperatingSystem => 'Operační systém';

  @override
  String settingsCodeRequestBody(
      String name, String surname, String email, String os) {
    return 'Jméno: $name; Příjmení: $surname; E-mail: $email; Operační systém: $os';
  }

  @override
  String get settingsNameOptional => 'Jméno (volitelné)';

  @override
  String get settingsMessageOptional => 'Zpráva (volitelná)';

  @override
  String get settingsVerifyCodeAndSave => 'Ověřuji kód a ukládám...';

  @override
  String get settingsViewSysLog => 'Zobrazit systémový protokol';

  @override
  String settingsMailOpenError(Object error) {
    return 'Chyba při otevírání e-mailu: $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get invia => 'Odeslat';

  @override
  String get saveArticle => 'Uložit článek';

  @override
  String get shareArticle => 'Sdílet článek';

  @override
  String get articleSavedSuccess => 'Článek uložen do Dokumentů';

  @override
  String get annulla => 'Zrušit';

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice =>
      'Vyplňte všechna pole pro vyžádání kódu.';

  @override
  String get selectFolder => 'Vybrat složku';

  @override
  String get exportDocument => 'Exportovat dokument';

  @override
  String get exportFormatPrompt =>
      'V jakém formátu chcete dokument exportovat?';

  @override
  String get textFormat => 'Text (.txt)';

  @override
  String get pdfFormat => 'PDF (.pdf)';

  @override
  String get exportError => 'Chyba exportu';

  @override
  String get newFolder => 'Nová složka';

  @override
  String get folderNameHint => 'Název složky';

  @override
  String get create => 'Vytvořit';

  @override
  String get createNewFolder => 'Vytvořit novou složku';

  @override
  String get importExternalSources => 'Import from external sources';

  @override
  String get importExternalSourcesTitle => 'External sources';

  @override
  String get importFromDropbox => 'Importovat dokumenty z Dropboxu';

  @override
  String get importFromProjectGutenberg => 'Import from Project Gutenberg';

  @override
  String get projectGutenbergImportUnavailable =>
      'Project Gutenberg import is not available yet.';

  @override
  String get importFromInternetArchive => 'Import from Internet Archive';

  @override
  String get internetArchiveTitle => 'Internet Archive';

  @override
  String get internetArchiveSearchLabel => 'Search audio';

  @override
  String get internetArchiveSourceLabel => 'Source';

  @override
  String get internetArchiveOldTimeRadio => 'Old Time Radio';

  @override
  String get internetArchiveSpeeches => 'Historical speeches';

  @override
  String get internetArchiveLiveMusic => 'Live Music Archive';

  @override
  String get internetArchiveNoItemsFound => 'No audio items found.';

  @override
  String get saveAudioInDocuments => 'Save audio in Documents';

  @override
  String get audioSavedInDocuments => 'Audio saved in Documents.';

  @override
  String get noAudioTracksAvailable => 'No audio tracks available.';

  @override
  String get importFromLibriVox => 'Import from LibriVox';

  @override
  String get gutenbergSearchLabel => 'Search book or author';

  @override
  String get sourceLanguageLabel => 'Language';

  @override
  String get noGutenbergBooksFound => 'No books found.';

  @override
  String get loadMore => 'Load more';

  @override
  String sourceLanguageValue(String language) {
    return 'Language: $language';
  }

  @override
  String get gutenbergImportAndRead => 'Import and read';

  @override
  String get gutenbergImporting => 'Importing...';

  @override
  String get librivoxSearchLabel => 'Search audiobook';

  @override
  String get noLibrivoxAudiobooksFound => 'No audiobooks found.';

  @override
  String get librivoxAudiobookSaved => 'Audiobook saved in Documents.';

  @override
  String get librivoxSaveAudiobook => 'Save audiobook in Documents';

  @override
  String get librivoxSaving => 'Saving...';

  @override
  String get librivoxNoAudioTracks => 'No audio tracks available.';

  @override
  String get librivoxNotTextExportable =>
      'LibriVox audiobooks cannot be exported as text.';

  @override
  String sourceDurationValue(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get importFromPoetryDb => 'Import from PoetryDB';

  @override
  String get poetryDbSearchLabel => 'Search poem';

  @override
  String get poetryDbSearchBy => 'Search by';

  @override
  String get poetryDbSearchByTitle => 'Title';

  @override
  String get poetryDbSearchByAuthor => 'Author';

  @override
  String get poetryDbNoPoemsFound => 'No poems found.';

  @override
  String poetryDbLineCount(int count) {
    return '$count lines';
  }

  @override
  String get moveDocument => 'Přesunout dokument';

  @override
  String get documentMoved => 'Úspěšně přesunuto';

  @override
  String get outOfFolder => 'Mimo složku';

  @override
  String get moveToAnotherFolder => 'Přesunout do jiné složky...';

  @override
  String get ttsError => 'Chyba TTS';

  @override
  String get editParagraph => 'Upravit odstavec';

  @override
  String get editParagraphTextField => 'Textové pole pro úpravu odstavce';

  @override
  String get editParagraphHint => 'Upravte text odstavce';

  @override
  String get applyAndSave => 'Použít a uložit';

  @override
  String get textEditedAndSaved => 'Text edited and saved in current document.';

  @override
  String get saveError => 'Error while saving';

  @override
  String get docSavedInLibrary => 'Document saved in library';

  @override
  String get saveInLibrary => 'Save in library';

  @override
  String get documentTextLabel => 'Document text';

  @override
  String get modifiedInSonarpad => 'Modified in Sonarpad';

  @override
  String get noTextAvailableForDocument =>
      'No text available for this document.';

  @override
  String bookmarkSet(int index) {
    return 'Bookmark set at paragraph $index.';
  }

  @override
  String get bookmarkRemoved => 'Bookmark removed.';

  @override
  String get docEmpty => 'Document is empty';

  @override
  String get docSavedSuccessfully => 'Document saved successfully!';

  @override
  String get writeDocument => 'Write document';

  @override
  String get documentTitleOptional => 'Title (optional)';

  @override
  String get documentTitleHint => 'Example: Shopping notes';

  @override
  String get documentTextField => 'Document text';

  @override
  String get documentTextHint => 'Start writing here...';

  @override
  String get newDocumentDefaultName => 'New_Document';

  @override
  String get saving => 'Saving...';

  @override
  String get saveDocument => 'Save document';

  @override
  String get addRssSource => 'Přidat RSS zdroj';

  @override
  String get add => 'Add';

  @override
  String get errorPrefix => 'Error';

  @override
  String versionBuild(String version, String buildNumber) {
    return 'Version $version (Build $buildNumber)';
  }

  @override
  String get whatIsNew => 'What’s new';

  @override
  String whatIsNewInVersion(String version) {
    return 'What’s new in version $version';
  }

  @override
  String changelogLoadError(Object error) {
    return 'Error loading what is new: $error';
  }

  @override
  String get visitSonarpadSite => 'Visit the Sonarpad website';

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return 'Visit the Sonarpad website: $url';
  }

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get fileImported => 'File imported';

  @override
  String importZipError(Object error) {
    return 'ZIP import error: $error';
  }

  @override
  String get dropboxLoginPrompt =>
      'Log in to Dropbox to import your documents.';

  @override
  String get loginToDropbox => 'Log in to Dropbox';

  @override
  String get logoutFromDropbox => 'Log out';

  @override
  String get dropboxLoginFailed => 'Login failed or cancelled';

  @override
  String dropboxLoadFolderError(Object error) {
    return 'Folder loading error: $error';
  }

  @override
  String dropboxImportError(Object error) {
    return 'Import error: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get goBack => '.. Go back';

  @override
  String get noSupportedFilesInFolder => 'No supported files in this folder.';

  @override
  String get articleNotFound => 'Article not found.';

  @override
  String get errorOpening => 'Error opening';

  @override
  String get recentArticles => 'Recent articles';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get confirmClearHistory =>
      'Do you really want to clear all recent searches?';

  @override
  String get clear => 'Clear';

  @override
  String get noRecentSearches => 'No recent searches.';

  @override
  String get logCopiedToClipboard => 'Log copied to clipboard';

  @override
  String get systemLog => 'System log';

  @override
  String get clearSystemLog => 'Clear log';

  @override
  String get copySystemLog => 'Copy log';

  @override
  String get donateWithPaypal => 'Donate with PayPal';

  @override
  String get bankTransferTitle => 'Bank transfer';

  @override
  String get enableVideo => 'Enable video';

  @override
  String get calendar => 'Kalendář';

  @override
  String get calendarHint =>
      'Otevřít kalendář se svátky, světcem dne a připomínkami';

  @override
  String get saintOfTheDay => 'Světec dne';

  @override
  String get quoteOfTheDay => 'Citát dne';

  @override
  String get reminders => 'Připomínky';

  @override
  String get addReminder => 'Přidat připomínku';

  @override
  String get removeReminder => 'Odstranit připomínku';

  @override
  String get noReminders => 'Žádné připomínky';

  @override
  String get writeReminder => 'Sem napište připomínku...';

  @override
  String get saveReminder => 'Uložit';

  @override
  String get cancelReminder => 'Zrušit';

  @override
  String get backToToday => 'Zpět na dnešek';

  @override
  String get calendarToday => 'Dnes';

  @override
  String get calendarTomorrow => 'Zítra';

  @override
  String get calendarYesterday => 'Včera';

  @override
  String get share => 'Sdílet';

  @override
  String get listenToAll => 'Přečíst vše';

  @override
  String reminderSaved(int count) {
    return '$count připomínek';
  }

  @override
  String get audiodescriptionTitle => 'Audio descriptions';

  @override
  String get audiodescriptionRecent => 'Recent';

  @override
  String get audiodescriptionAll => 'All audio descriptions';

  @override
  String get audiodescriptionFilm => 'Movies';

  @override
  String get audiodescriptionSearch => 'Search...';

  @override
  String get audiodescriptionLoading => 'Loading...';

  @override
  String get audiodescriptionError => 'Error loading catalog';

  @override
  String get audiodescriptionEmpty => 'No items found';

  @override
  String get radio => 'Rádio';

  @override
  String get radioHint => 'Poslouchat rádia a spravovat stanice';

  @override
  String get radioTitle => 'Radio stations from around the world';

  @override
  String get radioFavoritesButton => 'Favorite radio stations';

  @override
  String get radioNoFavorites => 'No favorite radio stations.';

  @override
  String get radioSearchText => 'Search radio stations';

  @override
  String get radioSearchHint => 'Radio station name or city...';

  @override
  String get radioLanguage => 'Language';

  @override
  String get radioBrowseBy => 'Browse by';

  @override
  String get radioBrowseByLanguage => 'Browse by language';

  @override
  String get radioBrowseByCountry => 'Browse by country';

  @override
  String get radioCountry => 'Country';

  @override
  String get radioGenre => 'Genre';

  @override
  String get radioSearch => 'Search';

  @override
  String get radioSearching => 'Loading radios...';

  @override
  String get radioSearchResults => 'Radio results';

  @override
  String get radioNoResults => 'No radios found.';

  @override
  String radioResultsFound(int count) {
    return 'Found $count radio stations';
  }

  @override
  String radioSearchError(Object error) {
    return 'Radio search error: $error';
  }

  @override
  String radioNowPlaying(String name) {
    return 'Playing $name';
  }

  @override
  String radioPlayError(Object error) {
    return 'Radio stream error: $error';
  }

  @override
  String get radioAddFavorite => 'Add to favorites';

  @override
  String get radioRemoveFavorite => 'Remove from favorites';

  @override
  String radioFavoriteAdded(String name) {
    return '$name added to favorites.';
  }

  @override
  String radioFavoriteRemoved(String name) {
    return '$name removed from favorites.';
  }

  @override
  String get radioAddCommunity => 'Add radio to Sonarpad community';

  @override
  String get radioAddName => 'Radio name';

  @override
  String get radioAddUrl => 'Stream address';

  @override
  String get radioAddSubmit => 'Verify and add';

  @override
  String get radioAddMissingFields =>
      'Please enter radio name and stream address.';

  @override
  String get radioCommunityAdded =>
      'Radio successfully added to Sonarpad community.';

  @override
  String radioCommunityAddError(Object error) {
    return 'Error adding radio: $error';
  }

  @override
  String get radioPlay => 'Play';

  @override
  String get startRecording => 'Start recording';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get recordings => 'Recordings';

  @override
  String get noRecordings => 'No recordings.';

  @override
  String get recordingStarted => 'Recording started.';

  @override
  String recordingSaved(Object path) {
    return 'Recording saved: $path';
  }

  @override
  String recordingError(Object error) {
    return 'Recording error: $error';
  }

  @override
  String get routeTitle => 'Routes';

  @override
  String get routeFrom => 'From';

  @override
  String get routeTo => 'To';

  @override
  String get routeCountry => 'Country';

  @override
  String get routeCountryItaly => 'Italy';

  @override
  String get routeCountryFrance => 'France';

  @override
  String get routeCountrySpain => 'Spain';

  @override
  String get routeVehicle => 'Transport mode';

  @override
  String get routeType => 'Type';

  @override
  String get routeIncludeMunicipalities => 'Include towns crossed';

  @override
  String get routeWalking => 'Walking';

  @override
  String get routeCycling => 'Cycling';

  @override
  String get routeDriving => 'Driving';

  @override
  String get routeWheelchair => 'Wheelchair';

  @override
  String get routeFastest => 'Fastest';

  @override
  String get routeShortest => 'Shortest';

  @override
  String get routeCalculate => 'Calculate route';

  @override
  String get routeCalculating => 'Calculating...';

  @override
  String get routeChooseFrom => 'Choose starting point';

  @override
  String get routeChooseTo => 'Choose destination';

  @override
  String get routeCancel => 'Cancel';

  @override
  String get routeErrorMissingFields =>
      'Please enter starting point and destination';

  @override
  String get routeErrorFromNotFound =>
      'No result found for the starting address';

  @override
  String get routeErrorToNotFound =>
      'No result found for the destination address';

  @override
  String get routeResultsTitle => 'Available routes';

  @override
  String get routeDistance => 'Distance';

  @override
  String get routeDuration => 'Duration';

  @override
  String get routeNavigation => 'Navigation details';

  @override
  String get routeStartMunicipality => 'Starting municipality';

  @override
  String get routeEnterMunicipality => 'You enter the municipality of';

  @override
  String routeError(Object error) {
    return 'Error: $error';
  }

  @override
  String get radioLanguageIt => 'Italština';

  @override
  String get radioLanguageEn => 'Angličtina';

  @override
  String get radioLanguageDe => 'Němčina';

  @override
  String get radioLanguageCountryCh => 'Switzerland';

  @override
  String get radioLanguageEs => 'Španělština';

  @override
  String get radioLanguagePt => 'Portugalština';

  @override
  String get radioLanguageSv => 'Švédština';

  @override
  String get radioLanguageVi => 'Vietnamština';

  @override
  String get radioLanguageCs => 'Čeština';

  @override
  String get radioLanguagePl => 'Polština';

  @override
  String get radioLanguageFr => 'Francouzština';

  @override
  String get radioLanguageSr => 'Srbština';

  @override
  String get radioLanguageUk => 'Ukrajinština';

  @override
  String get radioLanguageHi => 'Hindština';

  @override
  String get radioLanguageLt => 'Litevština';

  @override
  String get radioLanguageRu => 'Ruština';

  @override
  String get radioLanguageZh => 'Čínština';

  @override
  String get radioCountryOptionIt => 'Italy';

  @override
  String get radioCountryOptionUs => 'United States';

  @override
  String get radioCountryOptionGb => 'United Kingdom';

  @override
  String get radioCountryOptionFr => 'France';

  @override
  String get radioCountryOptionEs => 'Spain';

  @override
  String get radioCountryOptionDe => 'Germany';

  @override
  String get radioCountryOptionCh => 'Switzerland';

  @override
  String get radioCountryOptionAt => 'Austria';

  @override
  String get radioCountryOptionBe => 'Belgium';

  @override
  String get radioCountryOptionNl => 'Netherlands';

  @override
  String get radioCountryOptionPt => 'Portugal';

  @override
  String get radioCountryOptionBr => 'Brazil';

  @override
  String get radioCountryOptionAr => 'Argentina';

  @override
  String get radioCountryOptionMx => 'Mexico';

  @override
  String get radioCountryOptionCa => 'Canada';

  @override
  String get radioCountryOptionAu => 'Australia';

  @override
  String get radioCountryOptionIe => 'Ireland';

  @override
  String get radioCountryOptionSe => 'Sweden';

  @override
  String get radioCountryOptionPl => 'Poland';

  @override
  String get radioCountryOptionJp => 'Japan';

  @override
  String get radioGenreOptionAll => 'All genres';

  @override
  String get radioGenreOptionNews => 'Zprávy';

  @override
  String get radioGenreOptionMusic => 'Hudba';

  @override
  String get radioGenreOptionSport => 'Sport';

  @override
  String get radioGenreOptionTalk => 'Mluvené slovo';

  @override
  String get radioGenreOptionPop => 'Pop';

  @override
  String get radioGenreOptionRock => 'Rock';

  @override
  String get radioGenreOptionClassical => 'Classical';

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
  String get radioGenreOptionElectronic => 'Electronic';

  @override
  String get radioGenreOptionLatin => 'Latin';

  @override
  String get radioGenreOptionReggae => 'Reggae';

  @override
  String get radioGenreOptionMetal => 'Metal';

  @override
  String get radioGenreOptionFolk => 'Folk';

  @override
  String get radioGenreOptionReligion => 'Religion';

  @override
  String get radioGenreOptionLocal => 'Místní';

  @override
  String get radioGenreOptionCulture => 'Kultura';

  @override
  String get radioGenreOptionOldies => '70s / 80s / 90s';

  @override
  String get radioGenreOptionKids => 'Kids';

  @override
  String get radioGenreOptionAmbient => 'Ambient';

  @override
  String get radioCommunityLanguageItalian => 'Italian';

  @override
  String get radioCommunityLanguageEnglish => 'English';

  @override
  String get radioCommunityLanguageSpanish => 'Spanish';

  @override
  String get radioCommunityLanguageFrench => 'French';

  @override
  String get radioCommunityLanguageGerman => 'German';

  @override
  String get radioCommunityLanguagePortuguese => 'Portuguese';

  @override
  String get radioCommunityLanguageSwedish => 'Swedish';

  @override
  String get radioCommunityLanguageVietnamese => 'Vietnamese';

  @override
  String get radioCommunityLanguageCzech => 'Czech';

  @override
  String get radioCommunityLanguagePolish => 'Polish';

  @override
  String get radioCommunityLanguageSerbian => 'Serbian';

  @override
  String get radioCommunityLanguageUkrainian => 'Ukrainian';

  @override
  String get radioCommunityLanguageLithuanian => 'Lithuanian';

  @override
  String get radioCommunityLanguageRussian => 'Russian';

  @override
  String get radioCommunityLanguageChinese => 'Chinese';

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
    return '${hours}h ${minutes}m';
  }

  @override
  String get cinemaTitle => 'Movies in Theaters';

  @override
  String get cinemaNoMovies => 'No movies found at the moment.';

  @override
  String get cinemaError => 'Error loading movies.';

  @override
  String cinemaReleased(String date) {
    return 'Released on: $date';
  }

  @override
  String get cinemaOverviewLabel => 'Overview:';

  @override
  String get cinemaUpcomingReleases => 'Upcoming releases';

  @override
  String cinemaWillRelease(String date) {
    return 'Will be released on: $date';
  }

  @override
  String get cinemaOpenTrailer => 'Open trailer';

  @override
  String get concertsTitle => 'Concerts & Events';

  @override
  String get concertsSearchHint => 'Enter a city (e.g. London, New York)';

  @override
  String get concertsSearchLabel => 'Search concerts by city';

  @override
  String get concertsSearchTooltip => 'Search';

  @override
  String get concertsInitialText =>
      'Enter the name of your city above to see upcoming music concerts.';

  @override
  String get concertsEmpty => 'No concerts found in this city.';

  @override
  String get concertsVenue => 'Concert venue:';

  @override
  String get concertsBuyTickets => 'Buy or see details on Ticketmaster';

  @override
  String get podcastPlayedEpisodes => 'Unplayed';

  @override
  String get podcastUnplayed => 'Unplayed';
}
