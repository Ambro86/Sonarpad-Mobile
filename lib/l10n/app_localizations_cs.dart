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
  String get settingsWeatherTemperatureUnit => 'Jednotka teploty počasí';

  @override
  String get weatherTemperatureCelsius => 'Celsius (°C)';

  @override
  String get weatherTemperatureFahrenheit => 'Fahrenheit (°F)';

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
  String get sonarTubeTitle => 'SonarTube';

  @override
  String get sonarTubeSearchLabel => 'Hledat videa, kanály nebo playlisty';

  @override
  String get sonarTubeSearchPrompt =>
      'Zadejte hledání videí, kanálů a playlistů.';

  @override
  String get sonarTubeNoResults => 'Nebyla nalezena žádná videa.';

  @override
  String get sonarTubeLoadMore => 'Načíst další výsledky';

  @override
  String get sonarTubeVideo => 'Video';

  @override
  String get sonarTubeChannel => 'Kanál';

  @override
  String get sonarTubePlaylist => 'Playlist';

  @override
  String get sonarTubeLive => 'Živě';

  @override
  String get sonarTubeResolving => 'Příprava videa…';

  @override
  String get sonarTubeFavorites => 'Oblíbené';

  @override
  String get sonarTubeVideoFavorites => 'Oblíbená videa';

  @override
  String get sonarTubeChannelFavorites => 'Oblíbené kanály';

  @override
  String get sonarTubeNoVideoFavorites => 'Žádná oblíbená videa ani playlisty.';

  @override
  String get sonarTubeNoChannelFavorites => 'Žádné oblíbené kanály.';

  @override
  String get sonarTubeAddChannelFavorite => 'Přidat kanál do oblíbených';

  @override
  String get sonarTubeRemoveChannelFavorite => 'Odebrat kanál z oblíbených';

  @override
  String get sonarTubeRecentVideos => 'Nedávná videa';

  @override
  String get sonarTubeDeleteRecentVideo => 'Smazat video';

  @override
  String get sonarTubeNoRecentVideos => 'Žádná nedávná videa.';

  @override
  String get sonarTubeConfirmClearHistory => 'Opravdu chcete vymazat historii nedávných videí?';

  @override
  String get sonarTubeNoFavorites => 'Žádná oblíbená videa, kanály ani playlisty.';

  @override
  String get sonarTubeAddFavorite => 'Přidat do oblíbených';

  @override
  String get sonarTubeShareVideo => 'Sdílet video';

  @override
  String get sonarTubePreviousTrack => 'Přejít na předchozí video';

  @override
  String get sonarTubeNextTrack => 'Přejít na následující video';

  @override
  String get sonarTubeGoToChannel => 'Přejít na kanál';

  @override
  String get sonarTubeViewComments => 'Zobrazit komentáře';

  @override
  String get sonarTubeComments => 'Komentáře';

  @override
  String get sonarTubeNoComments => 'Nejsou k dispozici žádné komentáře.';

  @override
  String get sonarTubeLoadMoreComments => 'Načíst další komentáře';

  @override
  String get sonarTubeTranscribeVideo => 'Přepsat video';

  @override
  String get sonarTubeTranscript => 'Přepis';

  @override
  String get sonarTubeNoTranscript => 'Pro toto video není k dispozici žádný přepis.';

  @override
  String get sonarTubeCopyTranscript => 'Kopírovat přepis';

  @override
  String get sonarTubeTranscriptCopied => 'Přepis byl zkopírován do schránky';

  @override
  String get sonarTubeTranscriptSavedInDocuments => 'Přepis byl uložen do Dokumentů.';

  @override
  String get sonarTubeShareChannel => 'Sdílet kanál';

  @override
  String get sonarTubeSharePlaylist => 'Sdílet playlist';

  @override
  String get sonarTubeRemoveFavorite => 'Odebrat z oblíbených';

  @override
  String sonarTubeFavoriteAdded(String name) {
    return '$name přidáno do oblíbených.';
  }

  @override
  String sonarTubeFavoriteRemoved(String name) {
    return '$name odebráno z oblíbených.';
  }

  @override
  String get categoryUtilities => 'Vyhledávání a nástroje';

  @override
  String get voiceDictionaryTitle => 'Hlasový slovník';

  @override
  String get voiceDictionaryAdd => 'Přidat položku do slovníku';

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
  String get convertMediaWavBitDepth => 'Bitová hloubka WAV';

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
  String get convertMediaOutputNotWritable =>
      'Vybraná složka není přímo přístupná. Soubor bude uložen do interní složky Sonarpadu; po dokončení převodu jej můžete sdílet nebo uložit v aplikaci Soubory.';

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
      'Každý, kdo projekt podpoří, bude uveden v programu a v repozitáři GitHub, pokud si nepřeje zůstat anonymní nebo použít přezdívku.\n\nDěkujeme Jirimu Holzingerovi a Paole Vagatě za jejich příspěvek.\nZa český překlad děkujeme Radku Žaludovi a Jirimu Holzingerovi.\nZa španělský překlad děkujeme Arturovi Fernandezovi Rivasovi.\n\nVelké poděkování Leonardu Grazianovi, Paolu Marcellimu, Tizianu Ferrarovi a celé skupině Tecnologia accessibile za veškerou podporu při každodenním zlepšování tohoto skvělého projektu.';

  @override
  String get news => 'Zprávy';

  @override
  String get newsHint => 'Otevřít zprávy z RSS a Google News';

  @override
  String get podcasts => 'Podcasty';

  @override
  String get podcastsHint =>
      'Odebírat podcasty, přehrávat nebo stahovat epizody';

  @override
  String get importFromWikipedia => 'Wikipedie';

  @override
  String get wikipediaHint =>
      'Vyhledejte článek na Wikipedii a importujte text';

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
  String get update => 'Aktualizovat';

  @override
  String get moveUp => 'Přesunout nahoru';

  @override
  String get moveDown => 'Přesunout dolů';

  @override
  String get hide => 'Skrýt';

  @override
  String get moveToPosition => 'Přesunout na pozici';

  @override
  String positionLabel(int position, String targetName) {
    return 'Pozice $position: před $targetName';
  }

  @override
  String get positionLabelLast => 'Poslední pozice';

  @override
  String get restoreHiddenSources => 'Obnovit skryté zdroje';

  @override
  String get addCustomNewsSource => 'Přidat vlastní RSS zdroj';

  @override
  String get newsSourceName => 'Název zdroje nebo webu';

  @override
  String get newsSourceUrlOrSearch =>
      'Adresa webu, RSS kanál nebo hledané slovo';

  @override
  String get deleteNewsSource => 'Odebrat';

  @override
  String get importRssSourcesFromOpml => 'Importovat zdroje RSS z OPML';

  @override
  String get exportRssSourcesToOpml => 'Exportovat zdroje RSS do OPML';

  @override
  String rssImportComplete(int count) {
    return 'Importované zdroje RSS: $count';
  }

  @override
  String rssImportError(Object error) {
    return 'Chyba importu RSS: $error';
  }

  @override
  String get rssExportComplete => 'Zdroje RSS byly exportovány';

  @override
  String rssExportError(Object error) {
    return 'Chyba exportu RSS: $error';
  }

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
  String get german => 'Němčina';

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
  String get browsePodcastCountries => 'Procházet podle země';

  @override
  String get podcastCountries => 'Země podcastů';

  @override
  String get podcastCategory => 'Kategorie podcastu';

  @override
  String get browsePodcastCategories => 'Procházet kategorie';

  @override
  String get selectedPodcastCategory => 'Vybraná kategorie';

  @override
  String get selectedRecently => 'Naposledy vybrané';

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
  String get newsReadArticles => 'Přečtené články';

  @override
  String get weatherRecentCities => 'Nedávná města';

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
  String get openPodcast => 'Otevřít podcast';

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
  String get localAudioFiles => 'Místní audio soubory';

  @override
  String get noLocalAudioFiles => 'Nebyly nalezeny žádné místní audio soubory.';

  @override
  String get importAudioFromITunes => 'Importovat místní audio soubory';

  @override
  String localAudioFilesFound(int count) {
    return 'Nalezené místní audio soubory: $count';
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
  String get podcastInvalidOpmlFile =>
      'Neplatný soubor. Vyberte soubor OPML nebo XML.';

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
  String get adjustVolume => 'Upravit hlasitost';

  @override
  String volumeValue(int percentage) {
    return 'Hlasitost: $percentage%';
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
      'Importovat dokumenty z iTunes / Apple Devices';

  @override
  String sharedDocumentsImportComplete(int count) {
    return 'Dokumenty importované z iTunes / Apple Devices: $count';
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
  String get documentRemainingLessThanOneMinute => 'zbývá méně než 1 minuta';

  @override
  String documentRemainingMinutes(int minutes) {
    return 'zbývá přibližně $minutes minut';
  }

  @override
  String documentRemainingHours(int hours) {
    return 'zbývá přibližně $hours hodin';
  }

  @override
  String documentRemainingHoursMinutes(int hours, int minutes) {
    return 'zbývá přibližně $hours h a $minutes min';
  }

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
  String get documentParagraphSelectionStartAction => 'Spustit výběr odstavců';

  @override
  String get documentParagraphSelectionTapHint =>
      'Režim výběru je aktivní. Dvojitým klepnutím tento odstavec vyberete nebo zrušíte jeho výběr.';

  @override
  String get documentParagraphSelectionStarted =>
      'Režim výběru je aktivní. Odstavec byl vybrán. Dvojitým klepnutím vyberte další odstavce.';

  @override
  String documentParagraphSelectedAnnouncement(int count) {
    return 'Odstavec vybrán. Celkem vybráno: $count.';
  }

  @override
  String documentParagraphDeselectedAnnouncement(int count) {
    return 'Výběr odstavce zrušen. Celkem vybráno: $count.';
  }

  @override
  String documentParagraphSelectionCount(int count) {
    return 'Vybráno: $count';
  }

  @override
  String get documentDeleteSelectedParagraphs => 'Odstranit vybrané odstavce';

  @override
  String documentDeleteSelectedParagraphsConfirmation(int count) {
    return 'Odstranit vybrané odstavce? Celkem: $count.';
  }

  @override
  String documentSelectedParagraphsDeleted(int count) {
    return 'Odstraněné odstavce: $count.';
  }

  @override
  String get documentExitParagraphSelection => 'Ukončit výběr odstavců';

  @override
  String get documentParagraphSelectionExited => 'Režim výběru byl vypnut.';

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
  String get documentIndex => 'Obsah';

  @override
  String get documentSearchFieldLabel => 'Hledat text';

  @override
  String get documentSearchFieldHint => 'Slovo nebo fráze k vyhledání';

  @override
  String get documentSearchEmptyQuery => 'Zadejte text k vyhledání.';

  @override
  String get documentSearchResultsTitle => 'Výsledky hledání v dokumentu';

  @override
  String noDocumentSearchResults(String query) {
    return 'Pro $query nebyly nalezeny žádné výsledky.';
  }

  @override
  String documentSearchResultParagraph(int number) {
    return 'Odstavec $number';
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
  String get settingsEdgeTtsQuality => 'Edge TTS (vysoká kvalita online)';

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
  String get settingsDocumentSliderStep => 'Krok posuvníku dokumentu';

  @override
  String get settingsDocumentSliderStepHint =>
      'Určuje, o kolik se posune posuvník pozice dokumentu při přejetí nahoru nebo dolů.';

  @override
  String get settingsReadingSleepTimer => 'Časovač vypnutí čtení';

  @override
  String get settingsReadingSleepTimerOff => 'Vypnuto';

  @override
  String settingsReadingSleepTimerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsReadingSleepTimerHint =>
      'Po zvolené době automaticky zastaví čtení aktuálního dokumentu a uloží místo zastavení. Odpočítávání začne znovu při každém spuštění čtení dokumentu.';

  @override
  String get documentReadingSleepTimerStopped =>
      'Časovač vypnutí: čtení zastaveno a poloha uložena.';

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
  String get weatherCurrentSituation => 'Aktuální situace';

  @override
  String get weatherTomorrow => 'Zítra';

  @override
  String get weatherChooseDay => 'Vyberte den';


  @override
  String get tvRecordingChooseDay => weatherChooseDay;
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
  String get settingsPasteCode => 'Vložit kód';

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
    String name,
    String surname,
    String email,
    String os,
  ) {
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
  String get yes => 'Ano';

  @override
  String get no => 'Ne';

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
  String get docxFormat => 'DOCX (.docx)';

  @override
  String get epubFormat => 'EPUB (.epub)';

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
  String get importExternalSources => 'Import z externích zdrojů';

  @override
  String get importExternalSourcesTitle => 'Externí zdroje';

  @override
  String get importFromDropbox => 'Importovat dokumenty z Dropboxu';

  @override
  String get importFromProjectGutenberg => 'Import z Project Gutenberg';

  @override
  String get projectGutenbergImportUnavailable =>
      'Import z Project Gutenberg zatím není k dispozici.';

  @override
  String get importFromInternetArchive => 'Import z Internet Archive';

  @override
  String get internetArchiveTitle => 'Internet Archive';

  @override
  String get internetArchiveSearchLabel => 'Hledat audio';

  @override
  String get internetArchiveSourceLabel => 'Zdroj';

  @override
  String get internetArchiveOldTimeRadio => 'Staré rozhlasové pořady';

  @override
  String get internetArchiveSpeeches => 'Historické projevy';

  @override
  String get internetArchiveLiveMusic => 'Live Music Archive';

  @override
  String get internetArchiveNoItemsFound =>
      'Nebyly nalezeny žádné zvukové položky.';

  @override
  String get saveAudioInDocuments => 'Uložit audio do Dokumentů';

  @override
  String get audioSavedInDocuments => 'Audio bylo uloženo do Dokumentů.';

  @override
  String get noAudioTracksAvailable => 'Nejsou k dispozici žádné audio stopy.';

  @override
  String get importFromLibriVox => 'Import z LibriVox';

  @override
  String get gutenbergSearchLabel => 'Hledat knihu nebo autora';

  @override
  String get sourceLanguageLabel => 'Jazyk';

  @override
  String get noGutenbergBooksFound => 'Nebyly nalezeny žádné knihy.';

  @override
  String get loadMore => 'Načíst další';

  @override
  String sourceLanguageValue(String language) {
    return 'Jazyk: $language';
  }

  @override
  String get gutenbergImportAndRead => 'Importovat a číst';

  @override
  String get gutenbergImporting => 'Importuji...';

  @override
  String get librivoxSearchLabel => 'Hledat audioknihu';

  @override
  String get noLibrivoxAudiobooksFound => 'Nebyly nalezeny žádné audioknihy.';

  @override
  String get librivoxAudiobookSaved => 'Audiokniha byla uložena do Dokumentů.';

  @override
  String get librivoxSaveAudiobook => 'Uložit audioknihu do Dokumentů';

  @override
  String get librivoxSaving => 'Ukládám...';

  @override
  String get librivoxNoAudioTracks => 'Nejsou k dispozici žádné audio stopy.';

  @override
  String get librivoxNotTextExportable =>
      'Audioknihy LibriVox nelze exportovat jako text.';

  @override
  String sourceDurationValue(String duration) {
    return 'Délka: $duration';
  }

  @override
  String get importFromPoetryDb => 'Import z PoetryDB';

  @override
  String get poetryDbSearchLabel => 'Hledat báseň';

  @override
  String get poetryDbSearchBy => 'Hledat podle';

  @override
  String get poetryDbSearchByTitle => 'Název';

  @override
  String get poetryDbSearchByAuthor => 'Autor';

  @override
  String get poetryDbNoPoemsFound => 'Nebyly nalezeny žádné básně.';

  @override
  String poetryDbLineCount(int count) {
    return '$count řádků';
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
  String get textEditedAndSaved =>
      'Text byl upraven a uložen v aktuálním dokumentu.';

  @override
  String get saveError => 'Chyba při ukládání';

  @override
  String get docSavedInLibrary => 'Dokument byl uložen do knihovny';

  @override
  String get saveInLibrary => 'Uložit do knihovny';

  @override
  String get copyToClipboard => "Kopírovat do schránky";

  @override
  String get textCopiedToClipboard => "Text byl zkopírován do schránky";

  @override
  String get documentTextLabel => 'Text dokumentu';

  @override
  String get modifiedInSonarpad => 'Upraveno v Sonarpadu';

  @override
  String get noTextAvailableForDocument =>
      'Pro tento dokument není k dispozici žádný text.';

  @override
  String bookmarkSet(int index) {
    return 'Záložka nastavena na odstavec $index.';
  }

  @override
  String get bookmarkRemoved => 'Záložka odstraněna.';

  @override
  String get docEmpty => 'Dokument je prázdný';

  @override
  String get docSavedSuccessfully => 'Dokument byl úspěšně uložen!';

  @override
  String get writeDocument => 'Napsat dokument';

  @override
  String get documentTitleOptional => 'Název (volitelný)';

  @override
  String get documentTitleHint => 'Příklad: Nákupní poznámky';

  @override
  String get documentTextField => 'Text dokumentu';

  @override
  String get documentTextHint => 'Začněte psát zde...';

  @override
  String get newDocumentDefaultName => 'Nový_dokument';

  @override
  String get saving => 'Ukládám...';

  @override
  String get saveDocument => 'Uložit dokument';

  @override
  String get addRssSource => 'Přidat RSS zdroj';

  @override
  String get add => 'Přidat';

  @override
  String get errorPrefix => 'Chyba';

  @override
  String versionBuild(String version, String buildNumber) {
    return 'Verze $version (sestavení $buildNumber)';
  }

  @override
  String get whatIsNew => 'Co je nového';

  @override
  String whatIsNewInVersion(String version) {
    return 'Co je nového ve verzi $version';
  }

  @override
  String changelogLoadError(Object error) {
    return 'Chyba při načítání novinek: $error';
  }

  @override
  String get visitSonarpadSite => 'Navštívit web Sonarpad';

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return 'Navštívit web Sonarpad: $url';
  }

  @override
  String get nowPlaying => 'Právě se přehrává';

  @override
  String get fileImported => 'Soubor importován';

  @override
  String importZipError(Object error) {
    return 'Chyba importu ZIP: $error';
  }

  @override
  String get dropboxLoginPrompt =>
      'Přihlaste se k Dropboxu, abyste mohli importovat dokumenty.';

  @override
  String get loginToDropbox => 'Přihlásit se k Dropboxu';

  @override
  String get logoutFromDropbox => 'Odhlásit se';

  @override
  String get dropboxLoginFailed => 'Přihlášení se nezdařilo nebo bylo zrušeno';

  @override
  String dropboxLoadFolderError(Object error) {
    return 'Chyba při načítání složky: $error';
  }

  @override
  String dropboxImportError(Object error) {
    return 'Chyba importu: $error';
  }

  @override
  String get retry => 'Zkusit znovu';

  @override
  String get goBack => 'Zpět';

  @override
  String get noSupportedFilesInFolder =>
      'V této složce nejsou žádné podporované soubory.';

  @override
  String get articleNotFound => 'Článek nebyl nalezen.';

  @override
  String get errorOpening => 'Chyba při otevírání';

  @override
  String get recentArticles => 'Nedávné články';

  @override
  String get clearHistory => 'Vymazat historii';

  @override
  String get confirmClearHistory =>
      'Opravdu chcete vymazat všechny nedávné položky?';

  @override
  String get clear => 'Vymazat';

  @override
  String get noRecentSearches => 'Žádná nedávná hledání.';

  @override
  String get logCopiedToClipboard => 'Protokol byl zkopírován do schránky';

  @override
  String get logCleared => 'Log vymazán';

  @override
  String get parafarmacoDetailReadyAnnouncement =>
      'Karta produktu byla načtena. Přejetím doprava vyberte sekce.';

  @override
  String get systemLog => 'Systémový protokol';

  @override
  String get clearSystemLog => 'Vymazat protokol';

  @override
  String get copySystemLog => 'Kopírovat protokol';

  @override
  String get donateWithPaypal => 'Darovat přes PayPal';

  @override
  String get bankTransferTitle => 'Bankovní převod';

  @override
  String get enableVideo => 'Povolit video';

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
  String get shareCalendarDayOptions => 'Možnosti sdílení';

  @override
  String get shareCalendarDayOnly => 'Sdílet pouze den';

  @override
  String get shareCalendarDayWithReminder => 'Sdílet den a připomínku';

  @override
  String get listenToAll => 'Přečíst vše';

  @override
  String reminderSaved(int count) {
    return '$count připomínek';
  }

  @override
  String get audiodescriptionTitle => 'Audiopopisy';

  @override
  String get audiodescriptionRecent => 'Nedávné';

  @override
  String get audiodescriptionAll => 'Všechny audiopopisy';

  @override
  String get audiodescriptionFilm => 'Filmy';

  @override
  String get audiodescriptionSearch => 'Hledat...';

  @override
  String get audiodescriptionLoading => 'Načítám...';

  @override
  String get audiodescriptionError => 'Chyba při načítání katalogu';

  @override
  String get audiodescriptionEmpty => 'Nebyly nalezeny žádné položky';

  @override
  String get radio => 'Rádio';

  @override
  String get radioHint => 'Poslouchat rádia a spravovat stanice';

  @override
  String get radioTitle => 'Rádia z celého světa';

  @override
  String get radioFavoritesButton => 'Oblíbená rádia';

  @override
  String get radioNoFavorites => 'Žádná oblíbená rádia.';

  @override
  String get radioSearchText => 'Hledat stanice';

  @override
  String get radioSearchHint => 'Název stanice nebo město...';

  @override
  String get radioLanguage => 'Jazyk';

  @override
  String get radioBrowseBy => 'Procházet podle';

  @override
  String get radioBrowseByLanguage => 'Procházet podle jazyka';

  @override
  String get radioBrowseByCountry => 'Procházet podle země';

  @override
  String get radioCountry => 'Země';

  @override
  String get radioGenre => 'Žánr';

  @override
  String get radioActiveFilters => 'Aktivní filtry';

  @override
  String get radioResetFilters => 'Obnovit filtry';

  @override
  String get radioFiltersReset => 'Filtry obnoveny.';

  @override
  String get radioCity => 'Město';

  @override
  String get radioSearch => 'Hledat';

  @override
  String get radioSearching => 'Načítám rádia...';

  @override
  String get radioSearchResults => 'Výsledky hledání rádia';

  @override
  String get radioNoResults => 'Nebyly nalezeny žádné stanice.';

  @override
  String radioResultsFound(int count) {
    return 'Nalezeno stanic: $count';
  }

  @override
  String radioSearchError(Object error) {
    return 'Chyba při hledání stanic: $error';
  }

  @override
  String radioNowPlaying(String name) {
    return 'Přehrává se $name';
  }

  @override
  String radioPlayError(Object error) {
    return 'Chyba streamu rádia: $error';
  }

  @override
  String get radioAddFavorite => 'Přidat do oblíbených';

  @override
  String get radioRemoveFavorite => 'Odebrat z oblíbených';

  @override
  String radioFavoriteAdded(String name) {
    return 'Stanice $name byla přidána do oblíbených.';
  }

  @override
  String radioFavoriteRemoved(String name) {
    return 'Stanice $name byla odebrána z oblíbených.';
  }

  @override
  String get tvSearchFieldLabel => 'Hledat TV kanály';

  @override
  String get tvSearchFieldHint => 'Název kanálu...';

  @override
  String get tvSearchButton => 'Hledat';

  @override
  String get tvSearchResults => 'Výsledky TV kanálů';

  @override
  String get tvSearchEmptyQuery =>
      'Zadejte název TV kanálu, který chcete hledat.';

  @override
  String tvSearchNoResults(String query) {
    return 'Pro $query nebyly nalezeny žádné TV kanály.';
  }

  @override
  String get tvOpenChannelHint => 'Klepnutím přehrajete TV kanál';

  @override
  String tvNowOnAir(String title) {
    return 'Právě vysílá: $title';
  }

  @override
  String get radioAddCommunity => 'Přidat stanici do komunity Sonarpad';

  @override
  String get radioAddName => 'Název stanice';

  @override
  String get radioAddUrl => 'Adresa streamu';

  @override
  String get radioAddSubmit => 'Ověřit a přidat';

  @override
  String get radioAddMissingFields => 'Zadejte název stanice a adresu streamu.';

  @override
  String get radioCommunityAdded =>
      'Stanice byla úspěšně přidána do komunity Sonarpad.';

  @override
  String radioCommunityAddError(Object error) {
    return 'Chyba při přidávání stanice: $error';
  }

  @override
  String get radioPlay => 'Přehrát';

  @override
  String get tvPlayLive => 'Přehrát živé vysílání';

  @override
  String get playAndRecord => 'Přehrát a nahrávat';

  @override
  String get startRecording => 'Spustit nahrávání';

  @override
  String get stopRecording => 'Zastavit nahrávání';

  @override
  String get recordings => 'Nahrávky';

  @override
  String get recordingInProgressStatus => 'Probíhá nahrávání';

  @override
  String get scheduledRecordingInProgressStatus => 'Probíhá naplánované nahrávání';

  @override
  String get recordingCannotOpenWhileInProgress => 'Tuto nahrávku nelze otevřít, protože nahrávání stále probíhá.';

  @override
  String get blindLibrarySearchCatalog => 'Prohledat katalog';

  @override
  String get selectRecordings => 'Vybrat nahrávky';

  @override
  String deleteRecordingsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Trvale odstranit $count nahrávek?',
      one: 'Trvale odstranit jednu nahrávku?',
    );
    return '$_temp0';
  }

  @override
  String get noRecordings => 'Žádné nahrávky.';

  @override
  String get recordingStarted => 'Nahrávání spuštěno.';

  @override
  String recordingSaved(Object path) {
    return 'Nahrávka uložena: $path';
  }

  @override
  String recordingError(Object error) {
    return 'Chyba nahrávání: $error';
  }

  @override
  String get routeTitle => 'Trasy';

  @override
  String get routeFrom => 'Odkud';

  @override
  String get routeTo => 'Kam';

  @override
  String get routeCountry => 'Země';

  @override
  String get routeCountryItaly => 'Itálie';

  @override
  String get routeCountryFrance => 'Francie';

  @override
  String get routeCountrySpain => 'Španělsko';

  @override
  String get routeCountryCzechRepublic => 'Česko';

  @override
  String get routeVehicle => 'Způsob dopravy';

  @override
  String get routeType => 'Typ';

  @override
  String get routeIncludeMunicipalities => 'Zahrnout obce na trase';

  @override
  String get routeWalking => 'Pěšky';

  @override
  String get routeCycling => 'Na kole';

  @override
  String get routeDriving => 'Autem';

  @override
  String get routeWheelchair => 'Vozík';

  @override
  String get routeFastest => 'Nejrychlejší';

  @override
  String get routeShortest => 'Nejkratší';

  @override
  String get routeCalculate => 'Vypočítat trasu';

  @override
  String get routeCalculating => 'Počítám...';

  @override
  String get routeChooseFrom => 'Vyberte výchozí bod';

  @override
  String get routeChooseTo => 'Vyberte cíl';

  @override
  String get routeCancel => 'Zrušit';

  @override
  String get routeErrorMissingFields => 'Zadejte výchozí bod a cíl';

  @override
  String get routeErrorFromNotFound =>
      'Pro výchozí adresu nebyl nalezen žádný výsledek';

  @override
  String get routeErrorToNotFound =>
      'Pro cílovou adresu nebyl nalezen žádný výsledek';

  @override
  String get routeResultsTitle => 'Dostupné trasy';

  @override
  String get routeDistance => 'Vzdálenost';

  @override
  String get routeDuration => 'Doba trvání';

  @override
  String get routeNavigation => 'Podrobnosti navigace';

  @override
  String get routeStartMunicipality => 'Výchozí obec';

  @override
  String get routeEnterMunicipality => 'Vstupujete do obce';

  @override
  String routeError(Object error) {
    return 'Chyba: $error';
  }

  @override
  String get radioLanguageIt => 'Italština';

  @override
  String get radioLanguageEn => 'Angličtina';

  @override
  String get radioLanguageDe => 'Němčina';

  @override
  String get radioLanguageCountryCh => 'Švýcarsko';

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
  String get radioCountryOptionIt => 'Itálie';

  @override
  String get radioCountryOptionUs => 'Spojené státy';

  @override
  String get radioCountryOptionGb => 'Spojené království';

  @override
  String get radioCountryOptionFr => 'Francie';

  @override
  String get radioCountryOptionEs => 'Španělsko';

  @override
  String get radioCountryOptionDe => 'Německo';

  @override
  String get radioCountryOptionCh => 'Švýcarsko';

  @override
  String get radioCountryOptionAt => 'Rakousko';

  @override
  String get radioCountryOptionBe => 'Belgie';

  @override
  String get radioCountryOptionNl => 'Nizozemsko';

  @override
  String get radioCountryOptionPt => 'Portugalsko';

  @override
  String get radioCountryOptionBr => 'Brazílie';

  @override
  String get radioCountryOptionAr => 'Argentina';

  @override
  String get radioCountryOptionMx => 'Mexiko';

  @override
  String get radioCountryOptionCa => 'Kanada';

  @override
  String get radioCountryOptionAu => 'Austrálie';

  @override
  String get radioCountryOptionIe => 'Irsko';

  @override
  String get radioCountryOptionSe => 'Švédsko';

  @override
  String get radioCountryOptionPl => 'Polsko';

  @override
  String get radioCountryOptionJp => 'Japonsko';

  @override
  String get radioGenreOptionAll => 'Všechny žánry';

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
  String get radioGenreOptionClassical => 'Klasická hudba';

  @override
  String get radioGenreOptionJazz => 'Jazz';

  @override
  String get radioGenreOptionDance => 'Dance / elektronika';

  @override
  String get radioGenreOptionBlues => 'Blues';

  @override
  String get radioGenreOptionCountry => 'Country / folk';

  @override
  String get radioGenreOptionHiphop => 'Hip hop';

  @override
  String get radioGenreOptionElectronic => 'Elektronická hudba';

  @override
  String get radioGenreOptionLatin => 'Latinská hudba';

  @override
  String get radioGenreOptionReggae => 'Reggae';

  @override
  String get radioGenreOptionMetal => 'Metal';

  @override
  String get radioGenreOptionFolk => 'Folk';

  @override
  String get radioGenreOptionReligion => 'Náboženství';

  @override
  String get radioGenreOptionLocal => 'Místní';

  @override
  String get radioGenreOptionCulture => 'Kultura';

  @override
  String get radioGenreOptionOldies => '70. / 80. / 90. léta';

  @override
  String get radioGenreOptionKids => 'Pro děti';

  @override
  String get radioGenreOptionAmbient => 'Ambientní hudba';

  @override
  String get radioCommunityLanguageItalian => 'Italština';

  @override
  String get radioCommunityLanguageEnglish => 'Angličtina';

  @override
  String get radioCommunityLanguageSpanish => 'Španělština';

  @override
  String get radioCommunityLanguageFrench => 'Francouzština';

  @override
  String get radioCommunityLanguageGerman => 'Němčina';

  @override
  String get radioCommunityLanguagePortuguese => 'Portugalština';

  @override
  String get radioCommunityLanguageSwedish => 'Švédština';

  @override
  String get radioCommunityLanguageVietnamese => 'Vietnamština';

  @override
  String get radioCommunityLanguageCzech => 'Čeština';

  @override
  String get radioCommunityLanguagePolish => 'Polština';

  @override
  String get radioCommunityLanguageSerbian => 'Srbština';

  @override
  String get radioCommunityLanguageUkrainian => 'Ukrajinština';

  @override
  String get radioCommunityLanguageLithuanian => 'Litevština';

  @override
  String get radioCommunityLanguageRussian => 'Ruština';

  @override
  String get radioCommunityLanguageChinese => 'Čínština';

  @override
  String get radioCommunityLanguageHindi => 'Hindština';

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
  String get cinemaTitle => 'Filmy v kinech';

  @override
  String get cinemaNoMovies => 'Momentálně nebyly nalezeny žádné filmy.';

  @override
  String get cinemaError => 'Chyba při načítání filmů.';

  @override
  String cinemaReleased(String date) {
    return 'Premiéra: $date';
  }

  @override
  String get cinemaOverviewLabel => 'Obsah:';

  @override
  String get cinemaUpcomingReleases => 'Připravované premiéry';

  @override
  String cinemaWillRelease(String date) {
    return 'Bude uvedeno: $date';
  }

  @override
  String get cinemaOpenTrailer => 'Otevřít trailer';

  @override
  String get concertsTitle => 'Koncerty a události';

  @override
  String get concertsSearchHint => 'Zadejte město (např. Praha, Brno)';

  @override
  String get concertsSearchLabel => 'Hledat koncerty podle města';

  @override
  String get concertsSearchTooltip => 'Hledat';

  @override
  String get concertsInitialText =>
      'Zadejte nahoře název města, abyste viděli nadcházející hudební koncerty.';

  @override
  String get concertsEmpty => 'V tomto městě nebyly nalezeny žádné koncerty.';

  @override
  String get concertsVenue => 'Místo koncertu:';

  @override
  String get concertsBuyTickets =>
      'Koupit nebo zobrazit podrobnosti na Ticketmasteru';

  @override
  String get podcastPlayedEpisodes => 'Přehrané epizody';

  @override
  String get podcastSelectDate => 'Vybrat datum';

  @override
  String get podcastNoDatesAvailable =>
      'Pro tyto epizody nejsou k dispozici žádná data.';

  @override
  String get podcastChapters => 'Kapitoly';

  @override
  String get podcastChaptersUnavailable =>
      'Pro tuto epizodu nejsou dostupné žádné kapitoly.';

  @override
  String get podcastUnplayed => 'Nepřehrané epizody';

  @override
  String get routeReadAction => 'Přečíst trasu';

  @override
  String get routeSaveAction => 'Uložit do Dokumentů';

  @override
  String get routeSaveSuccess => 'Trasa uložena do Dokumentů';

  @override
  String get deleteItem => 'Smazat';

  @override
  String get audiobookMp3Format => 'Audiokniha MP3 (.mp3)';

  @override
  String get audiobookM4bFormat => 'Audiokniha M4B (.m4b)';

  @override
  String get exportCompleteTitle => 'Export dokončen';

  @override
  String get exportCompleteMessage =>
      'Soubor byl úspěšně vytvořen. Chcete ho uložit do Sonarpadu nebo sdílet?';

  @override
  String get saveInSonarpad => 'Uložit do Sonarpadu';

  @override
  String get exportSavedInSonarpad => 'Soubor uložen do Dokumentů Sonarpadu.';

  @override
  String get audiobookExportProgressTitle => 'Vytváření audioknihy';

  @override
  String get audiobookExportPreparing => 'Příprava audioknihy...';

  @override
  String get audiobookExportGeneratingAudio => 'Generování zvuku';

  @override
  String get audiobookExportConvertingAudio =>
      'Konečný převod zvukového souboru...';

  @override
  String get audiobookExportFinalizing => 'Dokončování...';

  @override
  String get routeRecentRoutes => 'Nedávné trasy';

  @override
  String get routeRecentRoutesEmpty => 'Žádné nedávné trasy';

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) {
    return 'Podrobnosti navigace z $from do $to - $date';
  }

  @override
  String get sortPodcastsAlphabetically => 'Seřadit podcasty abecedně';

  @override
  String get sortRadioFavoritesAlphabetically => 'Seřadit oblíbené abecedně';

  @override
  String get podcastsSortedAlphabetically => 'Podcasty seřazeny abecedně.';

  @override
  String get radioFavoritesSortedAlphabetically =>
      'Oblíbené stanice seřazeny abecedně.';

  @override
  String get settingsIncludeFootnotesInText =>
      'Zahrnout poznámky pod čarou do textu';

  @override
  String get settingsIncludeFootnotesInTextHint =>
      'U podporovaných knih EPUB zobrazí poznámku hned za odstavcem, který na ni odkazuje.';

  @override
  String get documentFootnoteLabel => 'Poznámka pod čarou';

  @override
  String get settingsMultipleDocumentBookmarks =>
      'Povolit více záložek v dokumentech';

  @override
  String get settingsMultipleDocumentBookmarksHint =>
      'Pokud je vypnuto, každý dokument má jen jednu záložku. Pokud je zapnuto, můžete uložit více záložek ve stejném dokumentu.';

  @override
  String get documentGoToBookmarkAction => 'Přejít na záložku';

  @override
  String get documentChooseBookmarkTitle => 'Vyberte záložku';

  @override
  String get documentDeleteBookmarkAction => 'Smazat záložku';

  @override
  String get documentKeepBookmarkTitle => 'Kterou záložku chcete ponechat?';

  @override
  String get documentKeepBookmarkMessage =>
      'Více záložek je vypnuto. Vyberte záložku, kterou chcete ponechat: ostatní budou odstraněny.';

  @override
  String documentBookmarkChoiceLabel(int order, int paragraph) {
    return 'Záložka $order, odstavec $paragraph';
  }

  @override
  String documentBookmarkChoiceLabelWithPreview(
    int order,
    int paragraph,
    String preview,
  ) {
    return 'Záložka $order, odstavec $paragraph. $preview';
  }

  @override
  String get settingsSonarTubePlayerActions => 'Přizpůsobit tlačítka přehrávače SonarTube';

  @override
  String get settingsVideoLandscapeFullscreen =>
      'Vodorovné video přes celou obrazovku';

  @override
  String get settingsVideoLandscapeFullscreenHint =>
      'Když zapnete video, zobrazí se přes celou obrazovku na šířku. Rádia pouze se zvukem se nemění.';

  @override
  String get settingsPodcastCacheTitle => 'Mezipaměť podcastů';

  @override
  String get settingsPodcastCacheHint =>
      'Vymaže jen dočasné soubory podcastů. Odběry, historie a importované audio zůstanou zachovány.';

  @override
  String settingsPodcastCacheSize(String size) {
    return 'Využité místo: $size';
  }

  @override
  String get clearPodcastCache => 'Vymazat mezipaměť podcastů';

  @override
  String get confirmClearPodcastCacheTitle => 'Vymazat mezipaměť podcastů?';

  @override
  String get confirmClearPodcastCacheMessage =>
      'Dočasné soubory podcastů budou odstraněny. Odběry a historie epizod zůstanou zachovány.';

  @override
  String podcastCacheCleared(String size) {
    return 'Mezipaměť podcastů vymazána: uvolněno $size.';
  }

  @override
  String get podcastCacheEmpty => 'Mezipaměť podcastů je už prázdná.';

  @override
  String get pharmacyFeatureTitle => 'Léky, parafarmaka a doplňky';

  @override
  String get pharmacyProductsSectionTitle => 'Parafarmaka a doplňky';

  @override
  String get pharmacyProductsLoadingTitle =>
      'Hledají se parafarmaka a doplňky...';

  @override
  String get pharmacyProductsErrorTitle =>
      'Chyba při hledání parafarmak a doplňků';

  @override
  String get pharmacyProductsNoResultsTitle =>
      'Nebylo nalezeno žádné parafarmakum ani doplněk';

  @override
  String get mediaCutterTitle => 'Oříznout mediální soubor';

  @override
  String get mediaCutterInstruction1 =>
      'Otevři zvukový nebo video soubor, přehraj ho a přejdi na místo, kde chceš střihnout.';

  @override
  String get mediaCutterInstruction2 =>
      'Pozastavte přehrávání, stiskněte Rozdělit, potom v části Části k uložení odstraňte části, které nechcete, a stiskněte Uložit.';

  @override
  String get mediaCutterOpenFile => 'Otevřít mediální soubor';

  @override
  String mediaCutterSelectedFile(String fileName) {
    return 'Vybraný soubor: $fileName';
  }

  @override
  String get mediaCutterPosition => 'Pozice střihu';

  @override
  String get mediaCutterPositionHint =>
      'Posouvej se vpřed nebo zpět po jedné sekundě.';

  @override
  String get mediaCutterHideVideoPreview => 'Skrýt video';

  @override
  String get mediaCutterVideoRotation => 'Otočení videa';

  @override
  String get mediaCutterVideoRotationNone => 'Bez otočení';

  @override
  String get mediaCutterVideoRotationRight => 'Otočit doprava';

  @override
  String get mediaCutterVideoRotationLeft => 'Otočit doleva';

  @override
  String get mediaCutterVideoRotationUpsideDown => 'Otočit o 180 stupňů';

  @override
  String get mediaCutterVideoPreview => 'Náhled videa';

  @override
  String get mediaCutterSplit => 'Rozdělit';

  @override
  String get mediaCutterPartsTitle => 'Části k uložení';

  @override
  String get mediaCutterPartsHint =>
      'Klepnutím si část poslechnete. Odstraněné části zmizí ze seznamu, při přehrávání se přeskočí a neuloží se. Efekty se použijí na celou část až při uložení média.';

  @override
  String mediaCutterPartLabel(int index) {
    return 'Část $index';
  }

  @override
  String mediaCutterPartRange(String start, String end) {
    return 'Od $start do $end';
  }

  @override
  String get mediaCutterSave => 'Uložit';

  @override
  String get mediaCutterReady => 'Připraveno.';

  @override
  String get mediaCutterUnsavedExitTitle => 'Soubor není uložen';

  @override
  String get mediaCutterUnsavedExitMessage =>
      'Soubor nebyl uložen. Opravdu chcete odejít?';

  @override
  String get mediaCutterNoFile => 'Nejprve otevři mediální soubor.';

  @override
  String get mediaCutterInvalidSplitPoint =>
      'Vyber místo uvnitř souboru, ne začátek ani konec.';

  @override
  String get mediaCutterSplitAlreadyExists =>
      'V tomto místě už rozdělení existuje.';

  @override
  String mediaCutterSplitAdded(String position) {
    return 'Rozdělení přidáno v $position.';
  }

  @override
  String get mediaCutterSaving => 'Zpracování...';

  @override
  String mediaCutterSaved(String fileName) {
    return 'Soubor uložen: $fileName';
  }

  @override
  String mediaCutterLoadFailed(Object error) {
    return 'Soubor nelze otevřít: $error';
  }

  @override
  String mediaCutterSaveFailed(Object error) {
    return 'Uložení se nezdařilo: $error';
  }

  @override
  String get mediaCutterNoPartsToSave =>
      'Před uložením ponechte alespoň jednu část.';

  @override
  String get mediaCutterRestoreDeletedPart => 'Obnovit odstraněnou část';

  @override
  String get mediaCutterNoDeletedParts =>
      'Nejsou zde žádné odstraněné části k obnovení.';

  @override
  String get mediaCutterPartDeleteAction => 'Odstranit';

  @override
  String get mediaCutterPartTapHint =>
      'Dvojitým klepnutím si tuto část poslechnete. Použijte akce Upravit část, Odstranit nebo Upravit efekty.';

  @override
  String mediaCutterPartDeleted(String start, String end) {
    return 'Část od $start do $end byla odstraněna.';
  }

  @override
  String mediaCutterPartRestored(String start, String end) {
    return 'Část od $start do $end byla obnovena.';
  }

  @override
  String get mediaCutterPartEffectsAction => 'Upravit efekty';

  @override
  String get mediaCutterPartEditAction => 'Upravit část';

  @override
  String get mediaCutterPartEditDescription =>
      'Posuňte začátek nebo konec části o 1 sekundu a potom si upravenou část poslechněte.';

  @override
  String mediaCutterPartAdjusted(String start, String end) {
    return 'Část upravena od $start do $end.';
  }

  @override
  String get mediaCutterPartEffectsTitle => 'Efekty části';

  @override
  String get mediaCutterPartEffectsDescription =>
      'Upravte hlasitost a efekt pouze pro tuto část.';

  @override
  String get mediaCutterPartVolumeLabel => 'Hlasitost části';

  @override
  String mediaCutterPartVolumeValue(int percent) {
    return 'Hlasitost části: $percent %';
  }

  @override
  String get mediaCutterPartEffect => 'Zvukový efekt';

  @override
  String get mediaCutterPartEffectNone => 'Žádný efekt';

  @override
  String get mediaCutterPartEffectEcho => 'Lehké echo';

  @override
  String get mediaCutterPartEffectEchoRoom => 'Ozvěna místnosti';

  @override
  String get mediaCutterPartEffectEchoChamber => 'Ozvěna komory';

  @override
  String get mediaCutterPartEffectEchoCathedral => 'Ozvěna katedrály';

  @override
  String get mediaCutterPartEffectLargeRoom => 'Velká místnost';

  @override
  String get mediaCutterPartEffectSmallRoom => 'Malá místnost';

  @override
  String get mediaCutterPartEffectBathroom => 'Koupelna';

  @override
  String get mediaCutterPartEffectTunnel => 'Tunel';

  @override
  String get mediaCutterPartEffectRepeatEcho => 'Opakovaná ozvěna';

  @override
  String get mediaCutterPartEffectCorridor => 'Chodba';

  @override
  String get mediaCutterPartEffectDelay => 'Delay';

  @override
  String get mediaCutterPartEffectReverb => 'Lehký dozvuk';

  @override
  String get mediaCutterPartEffectChorus => 'Chorus';

  @override
  String get mediaCutterPartEffectPitchLow => 'Nízká výška';

  @override
  String get mediaCutterPartEffectPitchVeryLow => 'Velmi nízká výška';

  @override
  String get mediaCutterPartEffectPitchHigh => 'Vysoká výška';

  @override
  String get mediaCutterPartEffectPitchVeryHigh => 'Velmi vysoká výška';

  @override
  String get mediaCutterPartEffectRobot => 'Robotický hlas';

  @override
  String get mediaCutterPartEffectSuperRobot => 'Super robot';

  @override
  String get mediaCutterPartEffectHelicopter => 'Vrtulník';

  @override
  String get mediaCutterPartEffectAlien => 'Mimozemské vibrato';

  @override
  String get mediaCutterPartEffectBrightVoice => 'Jasnější hlas';

  @override
  String get mediaCutterPartEffectDarkVoice => 'Tmavší hlas';

  @override
  String get mediaCutterPartEffectGhost => 'Duch';

  @override
  String get mediaCutterPartEffectTelephone => 'Telefon';

  @override
  String get mediaCutterPartEffectOldRadio => 'Staré rádio';

  @override
  String get mediaCutterPartEffectMegaphone => 'Megafon';

  @override
  String get mediaCutterPartEffectUnderwater => 'Pod vodou';

  @override
  String get mediaCutterPartEffectMonster => 'Příšera';

  @override
  String get mediaCutterPartEffectChipmunk => 'Vysoký hlas';

  @override
  String get mediaCutterPartEffectDream => 'Sen';

  @override
  String get mediaCutterPartEffectDistortion => 'Zkreslení';

  @override
  String get mediaCutterPartEffectLoFi => 'Lo-fi';

  @override
  String get mediaCutterPartEffectReverseEcho => 'Obrácená ozvěna';

  @override
  String get mediaCutterPartEffectFadeIn => 'Zesílení na začátku';

  @override
  String get mediaCutterPartEffectFadeOut => 'Zeslabení na konci';

  @override
  String get mediaCutterPartEffectAmountLabel => 'Intenzita efektu';

  @override
  String mediaCutterPartEffectAmountValue(int percent) {
    return 'Intenzita efektu: $percent %';
  }

  @override
  String get mediaCutterPartPreviewAction => 'Přehrát náhled';

  @override
  String get mediaCutterPartEffectsSavedOnly =>
      'Náhled používá zvolenou hlasitost. Zvukové efekty se použijí při ukládání.';

  @override
  String mediaCutterPartEffectsApplied(String start, String end) {
    return 'Efekty aktualizovány pro část od $start do $end.';
  }

  @override
  String mediaCutterPartEffectsSummary(int percent, String effect) {
    return 'Hlasitost $percent %, efekt $effect';
  }

  @override
  String get mediaCutterGuidedModeTitle => 'Průvodce střihem';

  @override
  String get mediaCutterGuidedModeDescription =>
      'Vhodné pro začátečníky. Vyberte začátek a konec, poslechněte si střih a potom jej použijte.';

  @override
  String get mediaCutterAdvancedModeTitle => 'Pokročilý střih';

  @override
  String get mediaCutterAdvancedModeDescription =>
      'Inspirováno známými programy pro úpravu médií. Umožňuje rozdělit soubor na více částí a odstranit nechtěné části.';

  @override
  String get mediaCutterChangeCutMode => 'Změnit typ střihu';

  @override
  String get mediaCutterGuidedSetStart => 'Začátek střihu';

  @override
  String get mediaCutterGuidedSetEnd => 'Konec střihu';

  @override
  String get mediaCutterGuidedApplyCut => 'Použít střih';

  @override
  String get mediaCutterGuidedListenCut => 'Poslechnout střih';

  @override
  String get mediaCutterGuidedModifyCut => 'Upravit střih';

  @override
  String get mediaCutterGuidedMoveStartBackOneSecond =>
      'Posunout začátek střihu o 1 sekundu zpět';

  @override
  String get mediaCutterGuidedMoveStartForwardOneSecond =>
      'Posunout začátek střihu o 1 sekundu vpřed';

  @override
  String get mediaCutterGuidedMoveEndBackOneSecond =>
      'Posunout konec střihu o 1 sekundu zpět';

  @override
  String get mediaCutterGuidedMoveEndForwardOneSecond =>
      'Posunout konec střihu o 1 sekundu vpřed';

  @override
  String get mediaCutterCutEditPrecisionLabel => 'Přesnost úpravy střihu';

  @override
  String mediaCutterCutEditPrecisionValue(String value) {
    return 'Přesnost úpravy střihu: $value';
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
    return 'Posunout začátek střihu zpět o $value';
  }

  @override
  String mediaCutterMoveStartForwardBy(String value) {
    return 'Posunout začátek střihu vpřed o $value';
  }

  @override
  String mediaCutterMoveEndBackBy(String value) {
    return 'Posunout konec střihu zpět o $value';
  }

  @override
  String mediaCutterMoveEndForwardBy(String value) {
    return 'Posunout konec střihu vpřed o $value';
  }

  @override
  String mediaCutterGuidedCutAdjusted(String start, String end) {
    return 'Střih změněn od $start do $end.';
  }

  @override
  String get mediaCutterGuidedNoCut => 'Žádný střih';

  @override
  String get mediaCutterGuidedEffectsAction => 'Upravit efekty souboru';

  @override
  String get mediaCutterGuidedEffectsDescription =>
      'Upravte hlasitost a efekty pro celý výsledný soubor.';

  @override
  String get mediaCutterGuidedFileTapHint =>
      'Dvojitým klepnutím přehrajete výsledný soubor. Pomocí úpravy efektů použijete efekty na celý soubor.';

  @override
  String mediaCutterGuidedStartSet(String start) {
    return 'Začátek střihu nastaven na $start.';
  }

  @override
  String mediaCutterGuidedEndSet(String start, String end) {
    return 'Konec střihu nastaven na $end. Střih od $start do $end.';
  }

  @override
  String mediaCutterGuidedCutApplied(String start, String end) {
    return 'Střih použit od $start do $end.';
  }

  @override
  String get mediaCutterGuidedNeedStartEnd =>
      'Nejprve nastavte začátek a konec střihu.';

  @override
  String mediaCutterGuidedCutSummary(String start, String end) {
    return 'Střih od $start do $end';
  }

  @override
  String mediaCutterGuidedMultipleCutSummary(int count, String cuts) {
    return '$count střihů: $cuts';
  }

  @override
  String get mediaCutterGuidedPendingCutExitMessage =>
      'Máte nepoužitý střih z průvodce. Chcete odejít bez jeho zachování?';

  @override
  String mediaCutterSplitAddedAnnouncement(int partNumber) {
    return 'Rozdělení přidáno. Část $partNumber přidána.';
  }

  @override
  String get newsAddCommunitySource => 'Přidat zdroj do komunity Sonarpad';

  @override
  String get newsBrowseCommunitySources => 'Komunitní zdroje';

  @override
  String get newsAddCommunityInstructions =>
      'Zadejte název zdroje a URL RSS kanálu nebo webu. Sonarpad použije vybraný jazyk zpráv a pokud zadáte web, pokusí se automaticky najít kanál.';

  @override
  String get newsCommunitySourceName => 'Název zdroje';

  @override
  String get newsCommunitySourceUrl => 'URL RSS kanálu nebo webu';

  @override
  String get newsCommunitySubmit => 'Zkontrolovat a přidat';

  @override
  String get newsCommunityChecking => 'Kontroluji kanál nebo web...';

  @override
  String get newsCommunityMissingFields =>
      'Zadejte název a URL kanálu nebo webu.';

  @override
  String get newsCommunityAdded =>
      'Zdroj byl úspěšně přidán do komunity Sonarpad.';

  @override
  String newsCommunityAddError(Object error) {
    return 'Chyba při přidávání zdroje: $error';
  }

  @override
  String newsCommunitySelectedLanguage(Object language) {
    return 'Vybraný jazyk: $language';
  }

  @override
  String get newsCommunitySourcesTitle => 'Komunitní zdroje';

  @override
  String get newsCommunitySourcesEmpty =>
      'Pro tento jazyk nejsou dostupné žádné komunitní zdroje.';

  @override
  String newsCommunitySourcesError(Object error) {
    return 'Chyba při načítání komunitních zdrojů: $error';
  }

  @override
  String newsCommunitySourceAddedToLibrary(Object name) {
    return '$name byl přidán do vaší knihovny zpráv.';
  }

  @override
  String newsCommunityAddToLibraryError(Object error) {
    return 'Chyba při přidávání do knihovny: $error';
  }

  @override
  String get newsCommunitySourceTapHint =>
      'Klepnutím přidáte zdroj do své knihovny zpráv.';
  @override
  String get developerModeEnabled => 'Vývojářský režim zapnut.';

  @override
  String get developerModeDisabled => 'Vývojářský režim vypnut.';

  @override
  String get developerSectionTitle => 'Vývojář';

  @override
  String get developerUseExperimentalFlutterRenderer => 'Použít experimentální renderer Flutteru';

  @override
  String get developerUseExperimentalFlutterRendererHint =>
      'Dočasně vypne UIKit, abyste mohli porovnat VoiceOver s čistým Flutterem.';

  // Shared labels generated from ARB entries.
  @override
  String get letterJumpSelectLetter => 'Vybrat písmeno';

  @override
  String get letterJumpSelected => 'vybráno';

  @override
  String get settingsToggleOn => 'Zapnuto';

  @override
  String get settingsToggleOff => 'Vypnuto';

  @override
  String get settingsShowOnlyMultilingualEdgeVoices => 'Zobrazit pouze vícejazyčné hlasy';

  @override
  String get radioDirectoryLoading => 'Aktualizuji země a jazyky rádia...';

  @override
  String get recentRadios => 'Nedávná rádia';

  @override
  String get radioNextPage => 'Další';

  @override
  String radioPageOf(int current, int total) {
    return 'Stránka $current z $total';
  }

  @override
  String get radioNoResultsWithQuery => 'Nebyly nalezeny žádné stanice. Zkuste zadat pouze název stanice bez žánru nebo změňte jazyk či zemi.';

  @override
  String get radioNoResultsGeneric => 'Nebyly nalezeny žádné stanice. Zkuste jiný jazyk, zemi nebo žánr.';

  @override
  String radioSearchRawError(Object error) {
    return 'Chyba při hledání rádia: $error';
  }

  @override
  String get radioBrowserConnectionError => 'Chyba připojení k Radio Browseru. Zkuste to prosím později.';

  @override
  String get documentIndexLoadingMessage => 'Načítání obsahu... Čekejte prosím.';

  @override
  String get documentIndexUnavailableMessage => 'Obsah není pro tento EPUB dostupný.';

  @override
  String mediaCutterVolumeSummary(int percent) {
    return 'hlasitost $percent %';
  }

  @override
  String mediaCutterDurationSummary(String duration) {
    return 'délka $duration';
  }

  @override
  String get mediaCutterDurationHourOne => 'hodina';

  @override
  String get mediaCutterDurationHourFew => 'hodiny';

  @override
  String get mediaCutterDurationHourMany => 'hodin';

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
  String get mediaCutterDurationAnd => 'a';

  @override
  String mediaCutterSeekStepButton(String step) {
    return 'Nastavit posun mediálního souboru: $step';
  }

  @override
  String get mediaCutterSeekStepTitle => 'Posun mediálního souboru';

  @override
  String mediaCutterSeekStepSelected(String step) {
    return 'Posun mediálního souboru nastaven na $step.';
  }

  @override
  String get mediaCutterPartEffectBackwards => 'Pozpátku';

  @override
  String get mediaCutterPartEffectTalkingGuitar => 'Mluvící kytara';

  @override
  String get mediaCutterPartEffectMosquito => 'Komár';

  @override
  String get mediaCutterPartEffectOneOfMany => 'Jeden hlas, mnoho zpěváků';

  @override
  String get mediaCutterPartEffectOrganVocoder => 'Mluvící varhany';

  @override
  String get mediaCutterPartEffectWarped => 'Deformovaný';

  @override
  String get mediaCutterPartEffectSwirling => 'Stereo vír';

  @override
  String get mediaCutterPartEffectVader => 'Filmový temný hlas';

  @override
  String get mediaCutterPartEffectMetallic => 'Kovový';

  @override
  String get mediaCutterPartEffectSongbird => 'Zpěvný pták';

  @override
  String get mediaCutterPartEffectExterminator => 'Likvidátor';

  @override
  String get mediaCutterPartEffectRainAndThunder => 'Déšť a hromy';

  @override
  String get mediaCutterPartEffectJungle => 'Džungle';

  @override
  String get mediaCutterPartEffectCrowd => 'Dav';

  @override
  String get mediaCutterPartEffectSlotMachines => 'Výherní automaty';

  @override
  String get mediaCutterPartEffectTraffic => 'Doprava';

  @override
  String get mediaCutterPartEffectSpaceship => 'Vesmírná loď';

  @override
  String get mediaCutterPartEffectCricket => 'Cvrček';

  @override
  String get mediaCutterPartEffectSiren => 'Siréna';

  @override
  String get mediaCutterPartEffectSleighBells => 'Rolničky';

  @override
  String get mediaCutterPartEffectDj => 'DJ a scratch';

  @override
  String get mediaCutterPartEffectApplause => 'Potlesk';

  @override
  String get mediaCutterPartEffectBadMelody => 'Falešná melodie';

  @override
  String get mediaCutterPartEffectBadHarmony => 'Disonantní harmonie';

  @override
  String get mediaCutterPartEffectWarmVoice => 'Teplý hlas';

  @override
  String get mediaCutterPartEffectTurtle => 'Želva';

  @override
  String get mediaCutterPartEffectHaunting => 'Strašidelný';

  @override
  String get radioPreviousPage => 'Předchozí';

  @override
  String get noRecentRadios => 'Žádné nedávno poslouchané rádio.';

  @override
  String get radioBrowseByCity => 'Procházet podle města';

  @override
  String get radioCityInputHint => 'Zadejte město...';

  @override
  String get openItem => 'Otevřít';

  @override
  String get clearSearch => 'Vymazat hledání';

  @override
  String get clearText => 'Vymazat text';

  @override
  String get fileTypeLabel => 'Soubor';

  @override
  String get cinemaTrailerLoading => 'Načítání upoutávky';

  @override
  String get cinemaNoTrailer => 'Pro tento film není k dispozici žádná upoutávka';

  @override
  String get radioScheduleHours => 'Hodiny';

  @override
  String get radioScheduleSelectHours => 'Vyberte hodiny';

  @override
  String get radioScheduleMinutes => 'Minuty';

  @override
  String get radioScheduleSelectMinutes => 'Vyberte minuty';

  @override
  String radioScheduleLabeledValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get radioScheduleStopCurrentFirst => 'Před naplánováním nového záznamu ukončete probíhající nahrávání.';

  @override
  String get radioScheduleStartTime => 'Čas začátku';

  @override
  String get radioScheduleEndTime => 'Čas konce';

  @override
  String get radioScheduleDialogTitle => 'Naplánovat nahrávání';

  @override
  String get radioScheduleOpenRequirement => 'Naplánované nahrávání funguje i při přechodu na jiné obrazovky Sonarpadu. Sonarpad musí zůstat otevřený; pokud je aplikace zavřena nebo pozastavena systémem, spuštění nahrávání není zaručeno.';

  @override
  String radioScheduleStartTimeValue(String time) {
    return 'Čas začátku: $time';
  }

  @override
  String radioScheduleEndTimeValue(String time) {
    return 'Čas konce: $time';
  }

  @override
  String get radioScheduleOptionalTitle => 'Volitelný název';

  @override
  String get radioScheduleTitleHint => 'Ponechte prázdné pro použití názvu rádia nebo TV';

  @override
  String get radioScheduleAction => 'Naplánovat';

  @override
  String radioScheduledRecordingRange(String start, String end) {
    return 'Naplánované nahrávání: $start - $end.';
  }

  @override
  String get radioScheduledRecordingAlreadyActive => 'Naplánované nahrávání nebylo spuštěno: již probíhá jiné nahrávání.';

  @override
  String get radioScheduledRecordingStarted => 'Naplánované nahrávání spuštěno.';

  @override
  String radioScheduledRecordingError(Object error) {
    return 'Chyba naplánovaného nahrávání: $error';
  }

  @override
  String get radioScheduledRecordingSaved => 'Naplánované nahrávání uloženo.';

  @override
  String radioScheduledRecordingSaveError(Object error) {
    return 'Chyba při ukládání naplánovaného nahrávání: $error';
  }

  @override
  String get radioScheduledRecordingCancelled => 'Naplánované nahrávání zrušeno.';

  @override
  String radioScheduledRecordingRangeWithTitle(String start, String end, String title) {
    return 'Naplánované nahrávání: $start - $end. Název: $title.';
  }

  @override
  String get radioScheduleCancelAction => 'Zrušit naplánované nahrávání';
  @override
  String get radioLanguageTr => 'Turečtina';

  @override
  String get radioCountryOptionTr => 'Turecko';

  @override
  String get radioCommunityLanguageTurkish => 'Turečtina';
  @override
  String get simplifiedChineseLanguageName => 'Zjednodušená čínština';

  @override
  String get chinaCountryName => 'Čína';

  @override
  String get technicalErrorGeneric => 'Technická chyba. Zkuste to znovu.';

  @override
  String cinemaTrailerTitle(String title) {
    return 'Upoutávka: $title';
  }

  @override
  String mediaCutterExportPartProgress(int index, int total) {
    return 'Část $index z $total';
  }

  @override
  String get mediaCutterExportFinalVerification => 'Závěrečná kontrola';

  @override
  String get mediaCutterExportMergeParts => 'Slučování částí';

  @override
  String get mediaCutterExportFileCheck => 'Kontrola souboru';

  @override
  String get mediaCutterExportPublishing => 'Publikování';

  @override
  String get mediaCutterExportCompletion => 'Dokončení';


  @override
  String get mediaCutterAddTrack => 'Přidat novou stopu';

  @override
  String get mediaCutterChooseAudioTrack => 'Vybrat zvukový soubor';

  @override
  String mediaCutterAddedTrackSelected(String name) => 'Vybraný zvukový soubor: $name';

  @override
  String get mediaCutterOriginalTrackVolume => 'Hlasitost původní stopy';

  @override
  String get mediaCutterNewTrackVolume => 'Hlasitost nové stopy';

  @override
  String get mediaCutterLoopNewTrack => 'Přehrávat novou stopu ve smyčce';

  @override
  String get mediaCutterPreviewNewTrack => 'Poslechnout náhled';

  @override
  String get mediaCutterFinalizeTrack => 'Dokončit';

  @override
  String mediaCutterAddedTrackApplied(String name) => 'Nová stopa přidána: $name';

  @override
  String get mediaCutterAddedTrackInvalidAudio => 'Vybraný soubor neobsahuje platnou zvukovou stopu.';

  @override
  String get mediaCutterAddedTrackPreviewPreparing => 'Příprava náhledu…';

  @override
  String get mediaCutterAddedTrackPreviewFailed => 'Náhled se nepodařilo vytvořit.';

  @override
  String get mediaCutterMixingAddedTrack => 'Míchání nové stopy';


  @override
  String get mediaProcessingCompleted => 'Zpracování dokončeno.';

  @override
  String get saveInSonarpadDocuments => 'Uložit do Dokumentů Sonarpadu';

  @override
  String get mediaCutterProcess => 'Zpracovat';

  @override
  String get preserveMedia => 'Uchovat obsah';

  @override
  String get preserveMediaSaving => 'Ukládání obsahu…';

  @override
  String get preserveMediaSaved => 'Obsah byl uložen do Dokumentů Sonarpadu.';

  @override
  String get preserveMediaError => 'Obsah se nepodařilo uchovat.';


  @override
  String get rename => 'Přejmenovat';

  @override
  String get renameRecording => 'Přejmenovat nahrávku';

  @override
  String get renameDocument => 'Přejmenovat dokument';

  @override
  String get newDocumentName => 'Nový název dokumentu';

  @override
  String get documentNameAlreadyExists => 'Dokument s tímto názvem již existuje.';

  @override
  String get newRecordingName => 'Nový název nahrávky';

  @override
  String get recordingCannotRenameWhileInProgress => 'Probíhající nahrávku nelze přejmenovat.';

  @override
  String get recordingNameAlreadyExists => 'Nahrávka s tímto názvem již existuje.';

  @override
  String get recordingExitPrompt => 'Nahrávání probíhá. Chcete ho zastavit, nebo pokračovat v nahrávání?';

  @override
  String get continueRecording => 'Pokračovat v nahrávání';

}
