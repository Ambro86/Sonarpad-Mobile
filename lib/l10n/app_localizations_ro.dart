// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The Romanian translations (`ro`) — phase 3 (partial).
/// Remaining untranslated messages temporarily keep their English text until the next phase.
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Sonarpad';

  @override
  String get appLanguage => 'Limba aplicației';

  @override
  String get settingsTheme => 'Tema aplicației';

  @override
  String get settingsThemeSystem => 'Sistem';

  @override
  String get settingsThemeLight => 'Luminoasă';

  @override
  String get settingsThemeDark => 'Întunecată';

  @override
  String get settingsWeatherTemperatureUnit => 'Unitatea de temperatură pentru vreme';

  @override
  String get weatherTemperatureCelsius => 'Celsius (°C)';

  @override
  String get weatherTemperatureFahrenheit => 'Fahrenheit (°F)';

  @override
  String get homeSemanticsLabel => 'Sonarpad, ecran principal';

  @override
  String get settings => 'Setări';

  @override
  String get settingsHint => 'Deschide setările';

  @override
  String get info => 'Despre';

  @override
  String get infoHint => 'Deschide informațiile despre aplicație';

  @override
  String get categoryReading => 'Lectură și documente';

  @override
  String get categoryMedia => 'Media și divertisment';

  @override
  String get sonarTubeTitle => 'SonarTube';

  @override
  String get sonarTubeSearchLabel => 'Caută videoclipuri, canale sau liste de redare';

  @override
  String get sonarTubeSearchPrompt =>
      'Introdu o căutare pentru a găsi videoclipuri, canale și liste de redare.';

  @override
  String get sonarTubeNoResults => 'Nu s-au găsit videoclipuri.';

  @override
  String get sonarTubeLoadMore => 'Încarcă mai multe rezultate';

  @override
  String get sonarTubeVideo => 'Videoclip';

  @override
  String get sonarTubeChannel => 'Canal';

  @override
  String get sonarTubePlaylist => 'Listă de redare';

  @override
  String get sonarTubeLive => 'În direct';

  @override
  String get sonarTubeResolving => 'Se pregătește videoclipul…';

  @override
  String get sonarTubeFavorites => 'Favorite';

  @override
  String get sonarTubeSortVideos => 'Sortează videoclipurile';

  @override
  String get sonarTubeSortNewest => 'Cele mai noi';

  @override
  String get sonarTubeSortOldest => 'Cele mai vechi';

  @override
  String get sonarTubeSortPopular => 'Populare';

  @override
  String get sonarTubeVideoFavorites => 'Videoclipuri favorite';

  @override
  String get sonarTubeChannelFavorites => 'Canale favorite';

  @override
  String get sonarTubeNoVideoFavorites => 'Nu există videoclipuri sau liste de redare favorite.';

  @override
  String get sonarTubeNoChannelFavorites => 'Nu există canale favorite.';

  @override
  String get sonarTubeAddChannelFavorite => 'Adaugă canalul la favorite';

  @override
  String get sonarTubeRemoveChannelFavorite => 'Elimină canalul din favorite';

  @override
  String get sonarTubeRecentVideos => 'Videoclipuri recente';

  @override
  String get sonarTubeDeleteRecentVideo => 'Șterge videoclipul';

  @override
  String get sonarTubeNoRecentVideos => 'Nu există videoclipuri recente.';

  @override
  String get sonarTubeConfirmClearHistory =>
      'Sigur vrei să ștergi istoricul videoclipurilor recente?';

  @override
  String get sonarTubeNoFavorites =>
      'Nu există videoclipuri, canale sau liste de redare favorite.';

  @override
  String get sonarTubeAddFavorite => 'Adaugă la favorite';

  @override
  String get sonarTubeShareVideo => 'Distribuie videoclipul';

  @override
  String get sonarTubePreviousTrack => 'Mergi la videoclipul anterior';

  @override
  String get sonarTubeNextTrack => 'Mergi la videoclipul următor';

  @override
  String get sonarTubeShareChannel => 'Distribuie canalul';

  @override
  String get sonarTubeSharePlaylist => 'Distribuie lista de redare';

  @override
  String get sonarTubeRemoveFavorite => 'Elimină din favorite';

  @override
  String sonarTubeFavoriteAdded(String name) {
    return '$name added to favorites.';
  }

  @override
  String sonarTubeFavoriteRemoved(String name) {
    return '$name removed from favorites.';
  }

  @override
  String get categoryUtilities => 'Căutări și utilitare';

  @override
  String get voiceDictionaryTitle => 'Dicționar de pronunție';

  @override
  String get voiceDictionaryAdd => 'Adaugă intrări în dicționar';

  @override
  String get voiceDictionaryOriginalWord => 'Cuvânt original';

  @override
  String get voiceDictionaryReplacementWord => 'Cuvânt de înlocuire';

  @override
  String get voiceDictionaryMatchCase => 'Respectă majusculele și minusculele';

  @override
  String get voiceDictionaryIgnoreCase => 'Ignoră majusculele și minusculele';

  @override
  String get voiceDictionaryEntries => 'Intrări din dicționar';

  @override
  String get voiceDictionaryEmpty => 'Nu există intrări în dicționar.';

  @override
  String get voiceDictionaryRemove => 'Elimină intrarea selectată';

  @override
  String get voiceDictionaryOriginalRequired => 'Introdu cuvântul original.';

  @override
  String get convertMediaTitle => 'Convertește media';

  @override
  String get convertMediaInput => 'Fișier de convertit';

  @override
  String get convertMediaOutput => 'Folder de salvare';

  @override
  String get convertMediaImage => 'Imagine';

  @override
  String get convertMediaBrowse => 'Răsfoiește...';

  @override
  String get convertMediaFormat => 'Format';

  @override
  String get convertMediaBitrate => 'Rată de biți (kbps)';

  @override
  String get convertMediaOggQuality => 'Calitate (q)';

  @override
  String get convertMediaFlacCompression => 'Nivel de compresie';

  @override
  String get convertMediaWavBitDepth => 'Adâncime de biți WAV';

  @override
  String get convertMediaReady => 'Gata.';

  @override
  String get convertMediaRunning => 'Se convertește...';

  @override
  String get convertMediaDone => 'Conversie finalizată.';

  @override
  String get convertMediaButton => 'Convertește media';

  @override
  String get convertMediaNoInput => 'Selectează un fișier de convertit.';

  @override
  String get convertMediaNoOutput => 'Selectează un folder de salvare.';

  @override
  String get convertMediaOutputNotWritable => 'Folderul selectat nu este accesibil direct. Fișierul va fi salvat în folderul intern Sonarpad; după terminarea conversiei îl poți distribui sau salva în aplicația Fișiere.';

  @override
  String get convertMediaNoImage => 'Selectează o imagine pentru videoclip.';

  @override
  String get convertMediaSamePath => 'Fișierul convertit trebuie să fie diferit de fișierul sursă.';

  @override
  String get convertMediaInvalidBitrate => 'Rată de biți nevalidă. Introdu o valoare între 64 și 320 kbps.';

  @override
  String convertMediaFailed(Object error) {
    return 'Conversia a eșuat: $error';
  }

  @override
  String get donations => 'Donații';

  @override
  String get donationsHint => 'Sprijină dezvoltarea Sonarpad';

  @override
  String get loading => 'Se încarcă';

  @override
  String get ttsVoiceLanguage => 'Limba vocii TTS';

  @override
  String get ttsVoice => 'Voce TTS';

  @override
  String get saveSettings => 'Salvează setările';

  @override
  String get settingsSaved => 'Setări salvate.';

  @override
  String get settingsSavedTitle => 'Setări salvate';

  @override
  String get sonarpadCodeValidTitle => 'Cod valid';

  @override
  String get sonarpadCodeValidMessage =>
      'Codul Sonarpad este corect. Setările au fost salvate.';

  @override
  String get sonarpadCodeInvalidTitle => 'Cod nevalid';

  @override
  String get sonarpadCodeInvalidMessage =>
      'Codul Sonarpad nu este valid. Verifică dacă l-ai copiat fără spații suplimentare.';

  @override
  String get infoDescription =>
      'Sonarpad este o aplicație simplă, cu multe funcții. Concepută pentru a fi accesibilă cu VoiceOver persoanelor nevăzătoare și cu deficiențe de vedere, îți permite să asculți știri, să cauți și să urmărești podcasturi, să imporți articole Wikipedia, să adaugi documente în bibliotecă, să le salvezi și să le editezi. Sonarpad este actualizat constant, iar fiecare funcție este gândită pentru a face viața de zi cu zi mai ușoară.';

  @override
  String get infoAuthor => 'Autor: Ambrogio Riili';

  @override
  String get donationsIntro => 'Sonarpad a fost creat inițial pentru a răspunde unor nevoi personale, dar în timp a devenit o aplicație mult mai amplă. Dezvoltarea sa necesită muncă permanentă: îmbunătățirea funcțiilor, corectarea erorilor, explorarea unor idei noi și testarea atentă a fiecărei funcții.\n\nDacă Sonarpad îți este util și dorești să îi sprijini dezvoltarea, poți face o donație.';

  @override
  String get donationsPaypalDesc => 'Poți dona prin PayPal folosind acest link:\nhttps://www.paypal.me/ambrogio86\nDacă este posibil, adaugă „Sonarpad” ca notă a plății.';

  @override
  String get donationsBankDesc => 'Poți dona și prin transfer bancar în contul pe numele Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nDacă este posibil, folosește o explicație clară a plății, de exemplu „Sonarpad”.';

  @override
  String get donationsThanks => 'Oricine sprijină proiectul va fi menționat în aplicație și în depozitul GitHub, cu excepția cazului în care preferă să rămână anonim sau să folosească o poreclă.\n\nMulțumiri lui Jiri Holzinger și Paola Vagata pentru contribuția lor.\nPentru traducerea în cehă, mulțumiri lui Radek Žalud și Jiri Holzinger.\nPentru traducerea în spaniolă, mulțumiri lui Arturo Fernandez Rivas.\n\nMulțumiri enorme lui Leonardo Graziano, Paolo Marcelli, Tiziano Ferraro și întregului grup Tecnologia accessibile pentru tot sprijinul oferit în îmbunătățirea zilnică a acestui minunat proiect.';

  @override
  String get news => 'Știri';

  @override
  String get newsHint => 'Deschide știrile din Google News RSS';

  @override
  String get podcasts => 'Podcasturi';

  @override
  String get podcastsHint => 'Urmărește podcasturi, redă sau descarcă episoade';

  @override
  String get importFromWikipedia => 'Wikipedia';

  @override
  String get wikipediaHint => 'Caută un articol Wikipedia și importă textul';

  @override
  String get newsCategoryTop => 'Principalele știri';

  @override
  String get settingsHomeGrouping =>
      'Activează gruparea pictogramelor de pe ecranul principal în categorii';

  @override
  String get settingsHomeGroupingHint =>
      'Dacă este dezactivată, pictogramele principale vor fi afișate într-o singură listă, fără subfoldere';

  @override
  String get newsCategoryMyCity => 'Orașul meu';

  @override
  String get newsLocalCityLabel => 'Introdu orașul';

  @override
  String get newsLocalCityHint => 'Corectează orașul folosit pentru știrile locale';

  @override
  String get update => 'Actualizare';

  @override
  String get moveUp => 'Mută în sus';

  @override
  String get moveDown => 'Mută în jos';

  @override
  String get hide => 'Șterge';

  @override
  String get moveToPosition => 'Mută la poziție';

  @override
  String positionLabel(int position, String targetName) {
    return 'Poziția $position: înainte de $targetName';
  }

  @override
  String get positionLabelLast => 'Ultima poziție';

  @override
  String get restoreHiddenSources => 'Restaurează sursele șterse';

  @override
  String get addCustomNewsSource => 'Adaugă o sursă RSS personalizată';

  @override
  String get newsSourceName => 'Numele sursei sau al site-ului';

  @override
  String get newsSourceUrlOrSearch => 'URL site, flux RSS sau termen de căutare';

  @override
  String get deleteNewsSource => 'Elimină';

  @override
  String get importRssSourcesFromOpml => 'Importă surse RSS din OPML';

  @override
  String get exportRssSourcesToOpml => 'Exportă sursele RSS în OPML';

  @override
  String rssImportComplete(int count) {
    return 'Surse RSS importate: $count';
  }

  @override
  String rssImportError(Object error) {
    return 'Eroare la importul RSS: $error';
  }

  @override
  String get rssExportComplete => 'Sursele RSS au fost exportate';

  @override
  String rssExportError(Object error) {
    return 'Eroare la exportul RSS: $error';
  }

  @override
  String get articleTextSemantics => 'Textul articolului';

  @override
  String get newsLanguage => 'Limba știrilor';

  @override
  String get loadingNews => 'Se încarcă știrile';

  @override
  String error(Object error) {
    return 'Error: $error';
  }

  @override
  String get noNewsFound => 'Nu s-au găsit știri';

  @override
  String get loadingArticle => 'Se încarcă articolul';

  @override
  String get noFullArticleFound =>
      'Articolul complet nu este disponibil. Se afișează rezumatul fluxului.';

  @override
  String get italian => 'Italiană';

  @override
  String get english => 'Engleză';

  @override
  String get french => 'Franceză';

  @override
  String get spanish => 'Spaniolă';

  @override
  String get german => 'Germană';

  @override
  String get newsSource => 'Sursa știrii';

  @override
  String get article => 'Articol';

  @override
  String get articlePreview => 'Previzualizare articol';

  @override
  String get readFullArticle => 'Citește articolul complet';

  @override
  String get extractingReaderArticleText => 'Se extrage textul în modul de citire...';

  @override
  String get extractingVisibleArticleText => 'Se extrage textul vizibil din pagină...';

  @override
  String source(String source) {
    return 'Sursă: $source';
  }

  @override
  String get readyStatus => 'Gata.';

  @override
  String get preparingEdgeTts => 'Se pregătește lectura Edge TTS în blocuri...';

  @override
  String get noTextToRead => 'Nu există text de citit.';

  @override
  String chunkCreated(int index, int total) {
    return 'Blocul $index din $total a fost creat. Lectură în curs...';
  }

  @override
  String playingChunk(int index, int total, int size) {
    return 'Se redă blocul $index din $total ($size octeți)...';
  }

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) {
    return 'Lectura s-a încheiat. Blocuri create: $readyChunks/$totalChunks. Bibliotecă: $libraryPath';
  }

  @override
  String get libraryNotSpecified => 'nespecificată';

  @override
  String get readingStopped => 'Lectura a fost oprită.';

  @override
  String edgeTtsError(Object error) {
    return 'Eroare Edge TTS: $error';
  }

  @override
  String audioChunksReady(int readyChunks, int totalChunks) {
    return 'Blocuri audio gata: $readyChunks / $totalChunks';
  }

  @override
  String get readingInProgress => 'Lectură în curs...';

  @override
  String get readWithEdgeTts => 'Începe lectura';

  @override
  String get stopReading => 'Oprește citirea';

  @override
  String get startReading => 'Începe lectura';

  @override
  String get resumeReading => 'Reia lectura';

  @override
  String get pauseReading => 'Pune citirea pe pauză';

  @override
  String get openOriginalArticle => 'Deschide articolul original';

  @override
  String get searchPodcasts => 'Caută podcasturi';

  @override
  String get podcastName => 'Numele podcastului';

  @override
  String get podcastSearchHint =>
      'Exemplu: tehnologie, istorie, numele podcastului...';

  @override
  String get searchCountry => 'Caută țara';

  @override
  String get browsePodcastCountries => 'Răsfoiește după țară';

  @override
  String get podcastCountries => 'Țări pentru podcasturi';

  @override
  String get podcastCategory => 'Categoria podcastului';

  @override
  String get browsePodcastCategories => 'Răsfoiește categoriile';

  @override
  String get selectedPodcastCategory => 'Categoria selectată';

  @override
  String get selectedRecently => 'alegere recentă';

  @override
  String get podcastCategories => 'Categorii de podcasturi';

  @override
  String get countryItaly => 'Italia';

  @override
  String get countryUnitedStatesEnglish => 'Statele Unite / Engleză';

  @override
  String get countryUnitedKingdom => 'Regatul Unit';

  @override
  String get countrySpain => 'Spania';

  @override
  String get countryFrance => 'Franța';

  @override
  String get searchInProgress => 'Căutare în curs...';

  @override
  String get newsReadArticles => 'Articole citite';

  @override
  String get weatherRecentCities => 'Orașe recente';

  @override
  String podcastResultsFound(int count) {
    return 'Found $count podcasts';
  }

  @override
  String podcastSearchError(Object error) {
    return 'Podcast search error: $error';
  }

  @override
  String subscribedTo(String title) {
    return 'Abonat la $title';
  }

  @override
  String subscriptionError(Object error) {
    return 'Eroare la abonare: $error';
  }

  @override
  String podcastSubscriptionError(Object error) {
    return 'Podcast subscription error: $error';
  }

  @override
  String get searchResults => 'Rezultatele căutării';

  @override
  String get podcastInfo => 'Informații despre podcast';

  @override
  String get subscribe => 'Abonează-te';

  @override
  String get openPodcast => 'Deschide podcastul';

  @override
  String get viewEpisodes => 'Vezi episoadele';

  @override
  String get podcastAuthor => 'Autor';

  @override
  String get noPodcastDescription => 'Nu există descriere.';

  @override
  String get noPodcastResults => 'Nu s-au găsit podcasturi.';

  @override
  String get loadingPodcastInfo => 'Se încarcă informațiile podcastului';

  @override
  String get podcastArtwork => 'Coperta podcastului';

  @override
  String get addFeedUrlManually => 'Adaugă manual adresa fluxului RSS';

  @override
  String get podcastFeedUrl => 'URL flux RSS podcast';

  @override
  String get subscribeFromUrl => 'Abonează-te din URL';

  @override
  String get subscribedPodcasts => 'Podcasturi urmărite';

  @override
  String get noSubscribedPodcasts =>
      'Nu există podcasturi urmărite. Caută un podcast și atinge un rezultat pentru a-l urmări.';

  @override
  String get localAudioFiles => 'Fișiere audio locale';

  @override
  String get noLocalAudioFiles => 'Nu s-au găsit fișiere audio locale.';

  @override
  String get importAudioFromITunes => 'Importă fișiere audio locale';

  @override
  String localAudioFilesFound(int count) {
    return 'Fișiere audio locale găsite: $count';
  }

  @override
  String get importPodcastsFromFile => 'Importă podcasturi din fișier';

  @override
  String get exportPodcastsToFile => 'Exportă podcasturile într-un fișier OPML';

  @override
  String podcastImportComplete(int count) {
    return 'Imported podcasts: $count';
  }

  @override
  String podcastImportError(Object error) {
    return 'Podcast import error: $error';
  }

  @override
  String get podcastInvalidOpmlFile => 'Fișier OPML nevalid';

  @override
  String get podcastExportComplete => 'Podcasturile au fost exportate';

  @override
  String podcastExportError(Object error) {
    return 'Podcast export error: $error';
  }

  @override
  String get loadingEpisodes => 'Se încarcă episoadele';

  @override
  String get noAudioEpisodesFound => 'Nu s-au găsit episoade audio în flux.';

  @override
  String get episodes => 'Episoade';

  @override
  String get episodeActions => 'Acțiuni episod';

  @override
  String downloaded(String path) {
    return 'Descărcat: $path';
  }

  @override
  String episodeError(Object error) {
    return 'Eroare episod: $error';
  }

  @override
  String get play => 'Redă';

  @override
  String get pause => 'Pauză';

  @override
  String get rewind15s => 'Înapoi 15 s';

  @override
  String get forward15s => 'Înainte 15 s';

  @override
  String get stop => 'Oprește';

  @override
  String get back => 'Înapoi';

  @override
  String get episodePlayer => 'Player episod';

  @override
  String nowPlayingTitle(String title) {
    return 'Now playing: $title';
  }

  @override
  String get loadingEpisodeAudio => 'Se încarcă sunetul episodului';

  @override
  String get playbackPosition => 'Poziție';

  @override
  String playbackPositionValue(String position, String duration) {
    return '$position of $duration';
  }

  @override
  String get adjustVolume => 'Reglează volumul';

  @override
  String volumeValue(int percentage) {
    return 'Volume: $percentage%';
  }

  @override
  String get download => 'Descarcă';

  @override
  String get searchWikipedia => 'Caută pe Wikipedia';

  @override
  String get wikipediaLanguage => 'Limba Wikipedia';

  @override
  String get search => 'Caută';

  @override
  String get wikipediaSearch => 'Căutare Wikipedia';

  @override
  String get wikipediaImporting => 'Import Wikipedia';

  @override
  String get noWikipediaResults => 'Nu s-au găsit rezultate pe Wikipedia';

  @override
  String get wikipediaImportMode => 'Mod de import';

  @override
  String get wikipediaImportWholeArticle => 'Articol complet';

  @override
  String get documents => 'Documente';

  @override
  String get documentsHint => 'Deschide biblioteca de documente';

  @override
  String get documentLibrary => 'Biblioteca de documente';

  @override
  String get addToLibrary => 'Adaugă în bibliotecă';

  @override
  String get documentImportSelectionMode => 'Dorești să selectezi un singur document sau mai multe documente?';

  @override
  String get documentImportSingle => 'Un document';

  @override
  String get documentImportMultiple => 'Mai multe documente';

  @override
  String get noDocuments => 'Nu există documente. Adaugă un fișier.';

  @override
  String get noDocumentsInLibrary => 'Nu există documente în bibliotecă.';

  @override
  String get documentAdded => 'Document adăugat';

  @override
  String get documentsAdded => 'Documente adăugate';

  @override
  String get importDocumentsFromITunes => 'Importă documente din iTunes / Apple Devices';

  @override
  String sharedDocumentsImportComplete(int count) {
    return 'Documente importate din iTunes / Apple Devices: $count';
  }

  @override
  String libraryLoadError(Object error) {
    return 'Eroare la încărcarea bibliotecii: $error';
  }

  @override
  String fileOpenError(Object error) {
    return 'Eroare la deschiderea fișierului: $error';
  }

  @override
  String get filePathUnavailable => 'Calea fișierului nu este disponibilă.';

  @override
  String fileInaccessible(String name) {
    return 'Fișier inaccesibil: $name';
  }

  @override
  String documentAddError(Object error) {
    return 'Eroare la adăugarea documentului: $error';
  }

  @override
  String documentRemoveError(Object error) {
    return 'Eroare la eliminare: $error';
  }

  @override
  String get noExportableTextFound => 'Nu s-a găsit text care poate fi exportat.';

  @override
  String get modifiedDocumentNoExportableText => 'Documentul modificat nu conține text care poate fi exportat.';

  @override
  String get documentRemoved => 'Document eliminat';

  @override
  String get folderRemoved => 'Folder eliminat';

  @override
  String get removeFolder => 'Elimină folderul';

  @override
  String get removeDocument => 'Elimină documentul';

  @override
  String get writeNewDocument => 'Scrie un document nou';

  @override
  String get addDocumentToLibraryHint => 'Adaugă documentul în bibliotecă. Răsfoiește fișierele dispozitivului și adaugă-l.';

  @override
  String get documentTypeLabel => 'Document';

  @override
  String get documentPosition => 'Poziția în document';

  @override
  String get documentRemainingLessThanOneMinute => 'mai puțin de 1 minut rămas';

  @override
  String documentRemainingMinutes(int minutes) {
    return 'aproximativ $minutes minute rămase';
  }

  @override
  String documentRemainingHours(int hours) {
    return 'aproximativ $hours ore rămase';
  }

  @override
  String documentRemainingHoursMinutes(int hours, int minutes) {
    return 'aproximativ $hours ore și $minutes minute rămase';
  }

  @override
  String get folderTypeLabel => 'Dosar';

  @override
  String documentAddedOn(String date) {
    return 'adăugat la $date';
  }

  @override
  String documentTypeDescription(String extension) {
    return 'tip $extension';
  }

  @override
  String get openFolderHint => 'Atinge de două ori pentru a deschide folderul';

  @override
  String get openDocumentHint => 'Atinge de două ori pentru a deschide și citi documentul';

  @override
  String removeItem(String name) {
    return 'Remove $name';
  }

  @override
  String get removePodcast => 'Elimină podcastul';

  @override
  String get podcastRemoved => 'Podcast eliminat';

  @override
  String get documentPickerError => 'Eroare la deschiderea fișierului';

  @override
  String get readDocument => 'Citește documentul';

  @override
  String get documentReaderTitle => 'Cititor de documente';

  @override
  String get documentReaderEditHint => 'Atinge un paragraf pentru a-l edita. Glisează în sus sau în jos pentru a adăuga un semn de carte.';

  @override
  String get documentParagraphSelectionStartAction => 'Începe selectarea paragrafelor';

  @override
  String get documentParagraphSelectionTapHint => 'Modul de selectare este activ. Atinge de două ori pentru a selecta sau deselecta acest paragraf.';

  @override
  String get documentParagraphSelectionStarted => 'Modul de selectare este activ. Paragraf selectat. Atinge de două ori alte paragrafe pentru a le selecta.';

  @override
  String documentParagraphSelectedAnnouncement(int count) {
    return 'Paragraf selectat. Total selectate: $count.';
  }

  @override
  String documentParagraphDeselectedAnnouncement(int count) {
    return 'Paragraf deselectat. Total selectate: $count.';
  }

  @override
  String documentParagraphSelectionCount(int count) {
    return 'Selectate: $count';
  }

  @override
  String get documentDeleteSelectedParagraphs => 'Șterge paragrafele selectate';

  @override
  String documentDeleteSelectedParagraphsConfirmation(int count) {
    return 'Ștergi paragrafele selectate? Total: $count.';
  }

  @override
  String documentSelectedParagraphsDeleted(int count) {
    return 'Paragrafe șterse: $count.';
  }

  @override
  String get documentExitParagraphSelection => 'Ieși din selectarea paragrafelor';

  @override
  String get documentParagraphSelectionExited => 'Modul de selectare a fost dezactivat.';

  @override
  String get documentBookmarkHintSet => 'Glisează în sus sau în jos pentru a seta un semn de carte.';

  @override
  String get documentEditParagraphActionHint => 'Atinge de două ori pentru a edita acest paragraf. ';

  @override
  String get documentBookmarkHintReplace => 'Glisează în sus sau în jos pentru a elimina semnul de carte existent sau pentru a-l înlocui cu acest paragraf.';

  @override
  String get documentSetBookmarkAction => 'Adaugă un semn de carte nou';

  @override
  String get documentRemoveBookmarkAction => 'Elimină semnul de carte';

  @override
  String get documentReplaceBookmarkAction => 'Elimină și adaugă un semn de carte nou';

  @override
  String get searchInDocument => 'Caută în document';

  @override
  String get documentIndex => 'Cuprins';

  @override
  String get documentSearchFieldLabel => 'Caută text';

  @override
  String get documentSearchFieldHint => 'Cuvânt sau expresie de găsit';

  @override
  String get documentSearchEmptyQuery => 'Introdu textul de căutat.';

  @override
  String get documentSearchResultsTitle => 'Rezultatele căutării în document';

  @override
  String noDocumentSearchResults(String query) {
    return 'No results found for $query.';
  }

  @override
  String documentSearchResultParagraph(int number) {
    return 'Paragraful $number';
  }

  @override
  String get edit => 'Editează';

  @override
  String get save => 'Salvează';

  @override
  String get cancel => 'Anulează';

  @override
  String get settingsReadingEngine => 'Motor de citire';

  @override
  String get settingsEdgeTtsQuality => 'Edge TTS (online, calitate înaltă)';

  @override
  String get settingsSystemVoices => 'Voci de sistem (VoiceOver / Google)';

  @override
  String get settingsNoSystemVoices => 'Nu există voci de sistem disponibile.';

  @override
  String get settingsDefaultVoiceHint => 'Voce implicită';

  @override
  String get settingsDefaultVoice => 'Implicită';

  @override
  String get settingsVoiceSpeed => 'Viteză: ';

  @override
  String get settingsVoicePitch => 'Ton: ';

  @override
  String get settingsVoiceSpeedLabel => 'Viteza de citire';

  @override
  String get settingsVoicePitchLabel => 'Înălțimea vocii';

  @override
  String get settingsTestVoice => 'Testează vocea';

  @override
  String get settingsTestingVoice => 'Se redă...';

  @override
  String get settingsVoiceTestText => 'Acesta este un test al vocii selectate.';

  @override
  String settingsVoiceTestError(Object error) {
    return 'Voice test error: $error';
  }

  @override
  String settingsVoiceSaveError(Object error) {
    return 'TTS voice save error: $error';
  }

  @override
  String get settingsUnsavedTitle => 'Modificări nesalvate';

  @override
  String get settingsUnsavedMessage =>
      'Vrei să salvezi modificările înainte de a părăsi setările?';

  @override
  String get settingsExitWithoutSaving => 'Ieși fără să salvezi';

  @override
  String get settingsSystemLanguage => 'Limba sistemului';

  @override
  String get settingsSystemVoice => 'Vocea sistemului';

  @override
  String get settingsAutoBookmark => 'Reluare automată';

  @override
  String get settingsAutoBookmarkHint =>
      'Reia documentele, podcasturile și conținutul media de unde ai rămas.';

  @override
  String get settingsDocumentSliderStep => 'Pasul glisorului documentului';

  @override
  String get settingsDocumentSliderStepHint => 'Controlează cât de mult se deplasează glisorul poziției în document când glisezi în sus sau în jos.';

  @override
  String get settingsReadingSleepTimer => 'Temporizator de oprire a citirii';

  @override
  String get settingsReadingSleepTimerOff => 'Dezactivat';

  @override
  String settingsReadingSleepTimerMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get settingsReadingSleepTimerHint => 'Oprește automat lectura documentului curent după timpul selectat și salvează poziția. Numărătoarea inversă repornește de fiecare dată când începi lectura unui document.';

  @override
  String get documentReadingSleepTimerStopped => 'Temporizator de somn: lectura a fost oprită și poziția a fost salvată.';

  @override
  String get settingsSeekStep => 'Pas pentru derulare înapoi / înainte la media';

  @override
  String get aiChatIntro => 'Sunt Sonarpad AI. Cum te pot ajuta?';

  @override
  String get meteoTitle => 'Vreme';

  @override
  String get weatherCity => 'Oraș';

  @override
  String get weatherCityHint => 'Exemplu: București';

  @override
  String get weatherCityNotFound => 'Orașul nu a fost găsit';

  @override
  String get weatherSearchError => 'Eroare în timpul căutării';

  @override
  String get weatherToday => 'Astăzi';

  @override
  String get weatherCurrentSituation => 'Situația actuală';

  @override
  String get weatherTomorrow => 'Mâine';

  @override
  String get weatherChooseDay => 'Alege ziua';

  @override
  String get tvRecordingChooseDay => 'Alege ziua';

  @override
  String get weatherCurrentTemperature => 'Temperatura actuală';

  @override
  String get weatherMaxTemperature => 'Temperatura maximă';

  @override
  String get weatherMinTemperature => 'Temperatura minimă';

  @override
  String get weatherPrecipitation => 'Precipitații';

  @override
  String get weatherPrecipitationProbability => 'Probabilitatea precipitațiilor';

  @override
  String get weatherWind => 'Vânt';

  @override
  String get weatherRelativeHumidity => 'Umiditate relativă';

  @override
  String get settingsSecretCode => 'Cod Sonarpad pentru funcții suplimentare';

  @override
  String get settingsRequestCode => 'Solicită codul de la autor';

  @override
  String get settingsPasteCode => 'Lipește codul';

  @override
  String get settingsCancel => 'Anulează';

  @override
  String get settingsSend => 'Trimite';

  @override
  String get settingsFillFieldsCode => 'Completează toate câmpurile pentru a solicita codul.';

  @override
  String get settingsName => 'Prenume';

  @override
  String get settingsSurname => 'Nume';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsOperatingSystem => 'Sistem de operare';

  @override
  String settingsCodeRequestBody(
    String name,
    String surname,
    String email,
    String os,
  ) {
    return 'Nume: $name; Prenume: $surname; E-mail: $email; Sistem de operare: $os';
  }

  @override
  String get settingsNameOptional => 'Nume (opțional)';

  @override
  String get settingsMessageOptional => 'Mesaj (opțional)';

  @override
  String get settingsVerifyCodeAndSave => 'Se verifică codul și se salvează...';

  @override
  String get settingsViewSysLog => 'Vezi jurnalul sistemului';

  @override
  String settingsMailOpenError(Object error) {
    return 'Eroare la deschiderea e-mailului: $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Da';

  @override
  String get no => 'Nu';

  @override
  String get invia => 'Trimite';

  @override
  String get saveArticle => 'Salvează articolul';

  @override
  String get shareArticle => 'Distribuie articolul';

  @override
  String get shareArticleAsTxt => 'Distribuie articolul ca TXT';

  @override
  String get articleSavedSuccess => 'Articol salvat în Documente';

  @override
  String get annulla => 'Anulează';

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice => 'Completează toate câmpurile pentru a solicita codul.';

  @override
  String get selectFolder => 'Selectează folderul';

  @override
  String get exportDocument => 'Exportă documentul';

  @override
  String get exportFormatPrompt => 'În ce format dorești să exporți documentul?';

  @override
  String get textFormat => 'Text (.txt)';

  @override
  String get pdfFormat => 'PDF (.pdf)';

  @override
  String get docxFormat => 'DOCX (.docx)';

  @override
  String get epubFormat => 'EPUB (.epub)';

  @override
  String get exportError => 'Eroare la export';

  @override
  String get newFolder => 'Folder nou';

  @override
  String get folderNameHint => 'Numele folderului';

  @override
  String get create => 'Creează';

  @override
  String get createNewFolder => 'Creează folder nou';

  @override
  String get importExternalSources => 'Importă din surse externe';

  @override
  String get importExternalSourcesTitle => 'Surse externe';

  @override
  String get importFromDropbox => 'Importă documente din Dropbox';

  @override
  String get importFromProjectGutenberg => 'Importă din Project Gutenberg';

  @override
  String get projectGutenbergImportUnavailable => 'Importul din Project Gutenberg nu este încă disponibil.';

  @override
  String get importFromInternetArchive => 'Importă din Internet Archive';

  @override
  String get internetArchiveTitle => 'Internet Archive';

  @override
  String get internetArchiveSearchLabel => 'Caută audio';

  @override
  String get internetArchiveSourceLabel => 'Sursă';

  @override
  String get internetArchiveOldTimeRadio => 'Emisiuni radio de epocă';

  @override
  String get internetArchiveSpeeches => 'Discursuri istorice';

  @override
  String get internetArchiveLiveMusic => 'Arhivă de muzică live';

  @override
  String get internetArchiveNoItemsFound => 'Nu s-au găsit elemente audio.';

  @override
  String get saveAudioInDocuments => 'Salvează audio în Documente';

  @override
  String get audioSavedInDocuments => 'Audio salvat în Documente.';

  @override
  String get noAudioTracksAvailable => 'Nu sunt disponibile piste audio.';

  @override
  String get importFromLibriVox => 'Importă din LibriVox';

  @override
  String get gutenbergSearchLabel => 'Caută carte sau autor';

  @override
  String get sourceLanguageLabel => 'Limbă';

  @override
  String get noGutenbergBooksFound => 'Nu s-au găsit cărți.';

  @override
  String get loadMore => 'Încarcă mai multe';

  @override
  String sourceLanguageValue(String language) {
    return 'Limbă: $language';
  }

  @override
  String get gutenbergImportAndRead => 'Importă și citește';

  @override
  String get gutenbergImporting => 'Se importă...';

  @override
  String get librivoxSearchLabel => 'Caută carte audio';

  @override
  String get noLibrivoxAudiobooksFound => 'Nu s-au găsit cărți audio.';

  @override
  String get librivoxAudiobookSaved => 'Cartea audio a fost salvată în Documente.';

  @override
  String get librivoxSaveAudiobook => 'Salvează cartea audio în Documente';

  @override
  String get librivoxSaving => 'Se salvează...';

  @override
  String get librivoxNoAudioTracks => 'Nu sunt disponibile piste audio.';

  @override
  String get librivoxNotTextExportable => 'Cărțile audio LibriVox nu pot fi exportate ca text.';

  @override
  String sourceDurationValue(String duration) {
    return 'Durată: $duration';
  }

  @override
  String get importFromPoetryDb => 'Importă din PoetryDB';

  @override
  String get poetryDbSearchLabel => 'Caută poezie';

  @override
  String get poetryDbSearchBy => 'Caută după';

  @override
  String get poetryDbSearchByTitle => 'Titlu';

  @override
  String get poetryDbSearchByAuthor => 'Autor';

  @override
  String get poetryDbNoPoemsFound => 'Nu s-au găsit poezii.';

  @override
  String poetryDbLineCount(int count) {
    return '$count versuri';
  }

  @override
  String get moveDocument => 'Mută documentul';

  @override
  String get documentMoved => 'Mutat cu succes';

  @override
  String get outOfFolder => 'În afara folderului';

  @override
  String get moveToAnotherFolder => 'Mută în alt folder...';

  @override
  String get ttsError => 'Eroare TTS';

  @override
  String get editParagraph => 'Editează paragraful';

  @override
  String get editParagraphTextField => 'Câmp text pentru editarea paragrafului';

  @override
  String get editParagraphHint => 'Editează textul paragrafului';

  @override
  String get applyAndSave => 'Aplică și salvează';

  @override
  String get textEditedAndSaved => 'Text editat și salvat în documentul curent.';

  @override
  String get saveError => 'Eroare la salvare';

  @override
  String get docSavedInLibrary => 'Document salvat în bibliotecă';

  @override
  String get saveInLibrary => 'Salvează în bibliotecă';

  @override
  String get documentTextLabel => 'Textul documentului';

  @override
  String get modifiedInSonarpad => 'Modificat în Sonarpad';

  @override
  String get noTextAvailableForDocument => 'Nu există text disponibil pentru acest document.';

  @override
  String bookmarkSet(int index) {
    return 'Semn de carte setat la paragraful $index.';
  }

  @override
  String get bookmarkRemoved => 'Semn de carte eliminat.';

  @override
  String get docEmpty => 'Documentul este gol';

  @override
  String get docSavedSuccessfully => 'Document salvat cu succes!';

  @override
  String get writeDocument => 'Scrie document';

  @override
  String get documentTitleOptional => 'Titlu (opțional)';

  @override
  String get documentTitleHint => 'Exemplu: Notițe pentru cumpărături';

  @override
  String get documentTextField => 'Textul documentului';

  @override
  String get documentTextHint => 'Începe să scrii aici...';

  @override
  String get newDocumentDefaultName => 'Document_nou';

  @override
  String get saving => 'Se salvează...';

  @override
  String get saveDocument => 'Salvează documentul';

  @override
  String get addRssSource => 'Adaugă sursă RSS';

  @override
  String get add => 'Adaugă';

  @override
  String get errorPrefix => 'Eroare';

  @override
  String versionBuild(String version, String buildNumber) {
    return 'Versiunea $version (Build $buildNumber)';
  }

  @override
  String get whatIsNew => 'Noutăți';

  @override
  String whatIsNewInVersion(String version) {
    return 'Noutăți în versiunea $version';
  }

  @override
  String changelogLoadError(Object error) {
    return 'Eroare la încărcarea noutăților: $error';
  }

  @override
  String get visitSonarpadSite => 'Vizitează site-ul Sonarpad';

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return 'Vizitează site-ul Sonarpad: $url';
  }

  @override
  String get nowPlaying => 'În redare';

  @override
  String get fileImported => 'Fișier importat';

  @override
  String importZipError(Object error) {
    return 'Eroare la importul ZIP: $error';
  }

  @override
  String get dropboxLoginPrompt => 'Autentifică-te în Dropbox pentru a importa documentele.';

  @override
  String get loginToDropbox => 'Autentifică-te în Dropbox';

  @override
  String get logoutFromDropbox => 'Deconectează-te';

  @override
  String get dropboxLoginFailed => 'Autentificare eșuată sau anulată';

  @override
  String dropboxLoadFolderError(Object error) {
    return 'Eroare la încărcarea folderului: $error';
  }

  @override
  String dropboxImportError(Object error) {
    return 'Eroare la import: $error';
  }

  @override
  String get retry => 'Reîncearcă';

  @override
  String get goBack => 'Înapoi';

  @override
  String get noSupportedFilesInFolder => 'Nu există fișiere compatibile în acest folder.';

  @override
  String get articleNotFound => 'Articolul nu a fost găsit.';

  @override
  String get errorOpening => 'Eroare la deschidere';

  @override
  String get recentArticles => 'Articole recente';

  @override
  String get clearHistory => 'Șterge istoricul';

  @override
  String get confirmClearHistory =>
      'Sigur vrei să ștergi toate căutările recente?';

  @override
  String get clear => 'Șterge';

  @override
  String get noRecentSearches => 'Nu există căutări recente.';

  @override
  String get logCopiedToClipboard => 'Jurnal copiat în clipboard';

  @override
  String get logCleared => 'Jurnal șters';

  @override
  String get parafarmacoDetailReadyAnnouncement => 'Fișa produsului a fost încărcată. Glisează spre dreapta pentru a alege secțiunile.';

  @override
  String get systemLog => 'Jurnal de sistem';

  @override
  String get clearSystemLog => 'Șterge jurnalul';

  @override
  String get copySystemLog => 'Copiază jurnalul';

  @override
  String get sendLogToDeveloper => 'Trimite raportul';

  @override
  String get developerLogNameOptional => 'Nume (opțional)';

  @override
  String get developerReportText => 'Detaliile raportului';

  @override
  String get developerLogSend => 'Trimite';

  @override
  String get developerLogSending => 'Se trimite raportul...';

  @override
  String get developerLogSent => 'Raport trimis dezvoltatorului.';

  @override
  String get developerLogSendFailed => 'Raportul nu a putut fi trimis. Încearcă din nou mai târziu.';

  @override
  String get donateWithPaypal => 'Donează prin PayPal';

  @override
  String get bankTransferTitle => 'Transfer bancar';

  @override
  String get enableVideo => 'Activează videoclipul';

  @override
  String get calendar => 'Calendar';

  @override
  String get calendarHint =>
      'Vezi calendarul, sărbătorile, sfântul zilei și mementourile tale';

  @override
  String get saintOfTheDay => 'Sfântul zilei';

  @override
  String get quoteOfTheDay => 'Citatul zilei';

  @override
  String get reminders => 'Mementouri';

  @override
  String get addReminder => 'Adaugă memento';

  @override
  String get removeReminder => 'Elimină mementoul';

  @override
  String get noReminders => 'Nu există mementouri';

  @override
  String get writeReminder => 'Scrie mementoul aici...';

  @override
  String get saveReminder => 'Salvează';

  @override
  String get cancelReminder => 'Anulează';

  @override
  String get backToToday => 'Înapoi la astăzi';

  @override
  String get calendarToday => 'Astăzi';

  @override
  String get calendarTomorrow => 'Mâine';

  @override
  String get calendarYesterday => 'Ieri';

  @override
  String get share => 'Distribuie';

  @override
  String get shareCalendarDayOptions => 'Opțiuni de distribuire';

  @override
  String get shareCalendarDayOnly => 'Distribuie doar ziua';

  @override
  String get shareCalendarDayWithReminder => 'Distribuie ziua și mementoul';

  @override
  String get listenToAll => 'Ascultă tot';

  @override
  String reminderSaved(int count) {
    return '$count mementouri';
  }

  @override
  String get audiodescriptionTitle => 'Audiodescrieri';

  @override
  String get audiodescriptionRecent => 'Recente';

  @override
  String get audiodescriptionAll => 'Toate audiodescrierile';

  @override
  String get audiodescriptionFilm => 'Filme';

  @override
  String get audiodescriptionSearch => 'Caută...';

  @override
  String get audiodescriptionLoading => 'Se încarcă...';

  @override
  String get audiodescriptionError => 'Eroare la încărcarea catalogului';

  @override
  String get audiodescriptionEmpty => 'Nu s-au găsit elemente';

  @override
  String get radio => 'Radio';

  @override
  String get radioHint => 'Caută posturi de radio, ascultă transmisiuni și gestionează favoritele';

  @override
  String get radioTitle => 'Posturi de radio din întreaga lume';

  @override
  String get radioFavoritesButton => 'Posturi de radio favorite';

  @override
  String get radioNoFavorites => 'Nu există posturi de radio favorite.';

  @override
  String get radioSearchText => 'Caută posturi de radio';

  @override
  String get radioSearchHint => 'Numele postului sau orașul...';

  @override
  String get radioLanguage => 'Limbă';

  @override
  String get radioBrowseBy => 'Răsfoiește după';

  @override
  String get radioBrowseByLanguage => 'Răsfoiește după limbă';

  @override
  String get radioBrowseByCountry => 'Răsfoiește după țară';

  @override
  String get radioCountry => 'Țară';

  @override
  String get radioGenre => 'Gen';

  @override
  String get radioActiveFilters => 'Filtre active';

  @override
  String get radioResetFilters => 'Resetează filtrele';

  @override
  String get radioFiltersReset => 'Filtre resetate.';

  @override
  String get radioCity => 'Oraș';

  @override
  String get radioSearch => 'Caută';

  @override
  String get radioSearching => 'Se încarcă posturile...';

  @override
  String get radioSearchResults => 'Rezultate radio';

  @override
  String get radioNoResults => 'Nu s-au găsit posturi de radio.';

  @override
  String radioResultsFound(int count) {
    return 'Au fost găsite $count posturi de radio';
  }

  @override
  String radioSearchError(Object error) {
    return 'Eroare la căutarea posturilor: $error';
  }

  @override
  String radioNowPlaying(String name) {
    return 'Se redă $name';
  }

  @override
  String radioPlayError(Object error) {
    return 'Eroare la redarea fluxului radio: $error';
  }

  @override
  String get radioAddFavorite => 'Adaugă la favorite';

  @override
  String get radioRemoveFavorite => 'Elimină din favorite';

  @override
  String radioFavoriteAdded(String name) {
    return '$name a fost adăugat la favorite.';
  }

  @override
  String radioFavoriteRemoved(String name) {
    return '$name a fost eliminat din favorite.';
  }

  @override
  String get tvSearchFieldLabel => 'Caută canale TV';

  @override
  String get tvSearchFieldHint => 'Numele canalului...';

  @override
  String get tvSearchButton => 'Caută';

  @override
  String get tvSearchResults => 'Rezultate canale TV';

  @override
  String get tvSearchEmptyQuery => 'Introdu numele unui canal TV de căutat.';

  @override
  String tvSearchNoResults(String query) {
    return 'Nu s-au găsit canale TV pentru $query.';
  }

  @override
  String get tvOpenChannelHint => 'Atinge pentru a reda canalul TV';

  @override
  String tvNowOnAir(String title) {
    return 'Acum în direct: $title';
  }

  @override
  String get radioAddCommunity => 'Adaugă postul în comunitatea Sonarpad';

  @override
  String get radioAddName => 'Numele postului';

  @override
  String get radioAddUrl => 'Adresa fluxului';

  @override
  String get radioAddSubmit => 'Verifică și adaugă';

  @override
  String get radioAddMissingFields => 'Introdu numele postului și adresa fluxului.';

  @override
  String get radioCommunityAdded => 'Postul a fost adăugat cu succes în comunitatea Sonarpad.';

  @override
  String radioCommunityAddError(Object error) {
    return 'Eroare la adăugarea postului: $error';
  }

  @override
  String get radioPlay => 'Redă';

  @override
  String get tvPlayLive => 'Redă transmisia în direct';

  @override
  String get playAndRecord => 'Redă și înregistrează';

  @override
  String get startRecording => 'Începe înregistrarea';

  @override
  String get stopRecording => 'Oprește înregistrarea';

  @override
  String get recordings => 'Înregistrări';

  @override
  String get recordingInProgressStatus => 'Înregistrare în curs';

  @override
  String get scheduledRecordingInProgressStatus => 'Înregistrare programată în curs';

  @override
  String scheduledRecordingPendingStatus(String dateTime) {
    return 'Programată pentru $dateTime';
  }

  @override
  String recordingCannotOpenBeforeScheduledStart(String dateTime) {
    return 'Această înregistrare nu a început încă. Va începe la $dateTime.';
  }

  @override
  String get recordingCannotOpenWhileInProgress => 'Această înregistrare nu poate fi deschisă deoarece este încă în curs.';

  @override
  String get blindLibrarySearchCatalog => 'Caută în catalog';

  @override
  String get selectRecordings => 'Selectează înregistrările';

  @override
  String get selectAll => 'Selectează tot';

  @override
  String get deselectAll => 'Deselectează tot';

  @override
  String selectionActionCount(String action, int count) {
    return '$action ($count)';
  }

  @override
  String deleteRecordingsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ștergi definitiv $count înregistrări?',
      one: 'Ștergi definitiv o înregistrare?',
    );
    return '$_temp0';
  }

  @override
  String get recordingDeleted => 'Înregistrare ștearsă.';

  @override
  String get recordingsDeleted => 'Înregistrări șterse.';

  @override
  String get noRecordings => 'Nu există înregistrări.';

  @override
  String get recordingStarted => 'Înregistrarea a început.';

  @override
  String recordingSaved(Object path) {
    return 'Înregistrare salvată: $path';
  }

  @override
  String recordingError(Object error) {
    return 'Eroare la înregistrare: $error';
  }

  @override
  String get routeTitle => 'Rute';

  @override
  String get routeFrom => 'De la';

  @override
  String get routeTo => 'Până la';

  @override
  String get routeCountry => 'Țară';

  @override
  String get routeCountryItaly => 'Italia';

  @override
  String get routeCountryFrance => 'Franța';

  @override
  String get routeCountrySpain => 'Spania';

  @override
  String get routeCountryCzechRepublic => 'Cehia';

  @override
  String get routeVehicle => 'Mijloc de transport';

  @override
  String get routeType => 'Tip';

  @override
  String get routeIncludeMunicipalities => 'Include localitățile traversate';

  @override
  String get routeWalking => 'Pe jos';

  @override
  String get routeCycling => 'Bicicletă';

  @override
  String get routeDriving => 'Mașină';

  @override
  String get routeWheelchair => 'Scaun rulant';

  @override
  String get routeFastest => 'Cea mai rapidă';

  @override
  String get routeShortest => 'Cea mai scurtă';

  @override
  String get routeCalculate => 'Calculează ruta';

  @override
  String get routeCalculating => 'Se calculează...';

  @override
  String get routeChooseFrom => 'Alege punctul de plecare';

  @override
  String get routeChooseTo => 'Alege destinația';

  @override
  String get routeCancel => 'Anulează';

  @override
  String get routeErrorMissingFields =>
      'Introdu punctul de plecare și destinația';

  @override
  String get routeErrorFromNotFound =>
      'Nu s-a găsit niciun rezultat pentru adresa de plecare';

  @override
  String get routeErrorToNotFound =>
      'Nu s-a găsit niciun rezultat pentru adresa de destinație';

  @override
  String get routeResultsTitle => 'Rute disponibile';

  @override
  String get routeDistance => 'Distanță';

  @override
  String get routeDuration => 'Durată';

  @override
  String get routeNavigation => 'Detalii de navigare';

  @override
  String get routeStartMunicipality => 'Localitatea de plecare';

  @override
  String get routeEnterMunicipality => 'Intri în localitatea';

  @override
  String routeError(Object error) {
    return 'Error: $error';
  }

  @override
  String get radioLanguageIt => 'Italiană';

  @override
  String get radioLanguageEn => 'Engleză';

  @override
  String get radioLanguageDe => 'Germană';

  @override
  String get radioLanguageCountryCh => 'Elveția';

  @override
  String get radioLanguageEs => 'Spaniolă';

  @override
  String get radioLanguagePt => 'Portugheză';

  @override
  String get radioLanguageSv => 'Suedeză';

  @override
  String get radioLanguageVi => 'Vietnameză';

  @override
  String get radioLanguageCs => 'Cehă';

  @override
  String get radioLanguagePl => 'Poloneză';

  @override
  String get radioLanguageFr => 'Franceză';

  @override
  String get radioLanguageSr => 'Sârbă';

  @override
  String get radioLanguageUk => 'Ucraineană';

  @override
  String get radioLanguageHi => 'Hindi';

  @override
  String get radioLanguageLt => 'Lituaniană';

  @override
  String get radioLanguageRu => 'Rusă';

  @override
  String get radioLanguageZh => 'Chineză';

  @override
  String get radioCountryOptionIt => 'Italia';

  @override
  String get radioCountryOptionUs => 'Statele Unite';

  @override
  String get radioCountryOptionGb => 'Regatul Unit';

  @override
  String get radioCountryOptionFr => 'Franța';

  @override
  String get radioCountryOptionEs => 'Spania';

  @override
  String get radioCountryOptionDe => 'Germania';

  @override
  String get radioCountryOptionCh => 'Elveția';

  @override
  String get radioCountryOptionAt => 'Austria';

  @override
  String get radioCountryOptionBe => 'Belgia';

  @override
  String get radioCountryOptionNl => 'Țările de Jos';

  @override
  String get radioCountryOptionPt => 'Portugalia';

  @override
  String get radioCountryOptionBr => 'Brazilia';

  @override
  String get radioCountryOptionAr => 'Argentina';

  @override
  String get radioCountryOptionMx => 'Mexic';

  @override
  String get radioCountryOptionCa => 'Canada';

  @override
  String get radioCountryOptionAu => 'Australia';

  @override
  String get radioCountryOptionIe => 'Irlanda';

  @override
  String get radioCountryOptionSe => 'Suedia';

  @override
  String get radioCountryOptionPl => 'Polonia';

  @override
  String get radioCountryOptionJp => 'Japonia';

  @override
  String get radioGenreOptionAll => 'Toate genurile';

  @override
  String get radioGenreOptionNews => 'Știri';

  @override
  String get radioGenreOptionMusic => 'Muzică';

  @override
  String get radioGenreOptionSport => 'Sport';

  @override
  String get radioGenreOptionTalk => 'Discuții și analiză';

  @override
  String get radioGenreOptionPop => 'Pop';

  @override
  String get radioGenreOptionRock => 'Rock';

  @override
  String get radioGenreOptionClassical => 'Clasică';

  @override
  String get radioGenreOptionJazz => 'Jazz';

  @override
  String get radioGenreOptionDance => 'Dans';

  @override
  String get radioGenreOptionBlues => 'Blues';

  @override
  String get radioGenreOptionCountry => 'Country';

  @override
  String get radioGenreOptionHiphop => 'Hip-hop';

  @override
  String get radioGenreOptionElectronic => 'Electronică';

  @override
  String get radioGenreOptionLatin => 'Latină';

  @override
  String get radioGenreOptionReggae => 'Reggae';

  @override
  String get radioGenreOptionMetal => 'Metal';

  @override
  String get radioGenreOptionFolk => 'Folk';

  @override
  String get radioGenreOptionReligion => 'Religie';

  @override
  String get radioGenreOptionLocal => 'Local';

  @override
  String get radioGenreOptionCulture => 'Cultură';

  @override
  String get radioGenreOptionOldies => 'Anii ’70 / ’80 / ’90';

  @override
  String get radioGenreOptionKids => 'Copii';

  @override
  String get radioGenreOptionAmbient => 'Ambient';

  @override
  String get radioCommunityLanguageItalian => 'Italiană';

  @override
  String get radioCommunityLanguageEnglish => 'Engleză';

  @override
  String get radioCommunityLanguageSpanish => 'Spaniolă';

  @override
  String get radioCommunityLanguageFrench => 'Franceză';

  @override
  String get radioCommunityLanguageGerman => 'Germană';

  @override
  String get radioCommunityLanguagePortuguese => 'Portugheză';

  @override
  String get radioCommunityLanguageSwedish => 'Suedeză';

  @override
  String get radioCommunityLanguageVietnamese => 'Vietnameză';

  @override
  String get radioCommunityLanguageCzech => 'Cehă';

  @override
  String get radioCommunityLanguagePolish => 'Poloneză';

  @override
  String get radioCommunityLanguageSerbian => 'Sârbă';

  @override
  String get radioCommunityLanguageUkrainian => 'Ucraineană';

  @override
  String get radioCommunityLanguageLithuanian => 'Lituaniană';

  @override
  String get radioCommunityLanguageRussian => 'Rusă';

  @override
  String get radioCommunityLanguageChinese => 'Chineză';

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
    return '$hours h $minutes min';
  }

  @override
  String get cinemaTitle => 'Filme la cinema';

  @override
  String get cinemaNoMovies => 'Momentan nu s-au găsit filme.';

  @override
  String get cinemaError => 'Eroare la încărcarea filmelor.';

  @override
  String cinemaReleased(String date) {
    return 'Lansat la: $date';
  }

  @override
  String get cinemaOverviewLabel => 'Prezentare generală:';

  @override
  String get cinemaUpcomingReleases => 'Lansări viitoare';

  @override
  String cinemaWillRelease(String date) {
    return 'Va fi lansat la: $date';
  }

  @override
  String get cinemaOpenTrailer => 'Deschide trailerul';

  @override
  String get concertsTitle => 'Concerte și evenimente';

  @override
  String get concertsSearchHint => 'Introdu un oraș (de ex. București, Londra)';

  @override
  String get concertsSearchLabel => 'Caută concerte după oraș';

  @override
  String get concertsSearchTooltip => 'Caută';

  @override
  String get concertsInitialText => 'Introdu mai sus numele orașului pentru a vedea concertele muzicale viitoare.';

  @override
  String get concertsEmpty => 'Nu s-au găsit concerte în acest oraș.';

  @override
  String get concertsVenue => 'Locul concertului:';

  @override
  String get concertsBuyTickets => 'Cumpără bilete sau vezi detalii pe Ticketmaster';

  @override
  String get podcastPlayedEpisodes => 'Episoade redate';

  @override
  String get podcastSelectDate => 'Selectează data';

  @override
  String get podcastNoDatesAvailable =>
      'Nu există date disponibile pentru aceste episoade.';

  @override
  String get podcastChapters => 'Capitole';

  @override
  String get podcastChaptersUnavailable =>
      'Nu există capitole disponibile pentru acest episod.';

  @override
  String get podcastUnplayed => 'Episoade neredate';

  @override
  String get routeReadAction => 'Citește ruta';

  @override
  String get routeSaveAction => 'Salvează în documente';

  @override
  String get routeOpenAction => 'Deschide ruta';

  @override
  String get routeAppleMapsAction => 'Hărți';

  @override
  String get routeGoogleMapsAction => 'Google Maps';

  @override
  String get routeOpenError => 'Nu se poate deschide aplicația de navigare.';

  @override
  String get routeSaveSuccess => 'Ruta a fost salvată în documente';

  @override
  String get deleteItem => 'Șterge';

  @override
  String get audiobookMp3Format => 'Carte audio MP3 (.mp3)';

  @override
  String get audiobookM4bFormat => 'Carte audio M4B (.m4b)';

  @override
  String get exportCompleteTitle => 'Export finalizat';

  @override
  String get exportCompleteMessage => 'Fișierul a fost creat cu succes. Dorești să îl salvezi în Sonarpad sau să îl distribui?';

  @override
  String get saveInSonarpad => 'Salvează în Sonarpad';

  @override
  String get exportSavedInSonarpad => 'Fișier salvat în Documentele Sonarpad.';

  @override
  String get audiobookExportProgressTitle => 'Se creează cartea audio';

  @override
  String get audiobookExportPreparing => 'Se pregătește cartea audio...';

  @override
  String get audiobookExportGeneratingAudio => 'Se generează sunetul';

  @override
  String get audiobookExportConvertingAudio => 'Conversie audio finală...';

  @override
  String get audiobookExportFinalizing => 'Se finalizează...';

  @override
  String get routeRecentRoutes => 'Rute recente';

  @override
  String get routeRecentRoutesEmpty => 'Nu există rute recente';

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) {
    return 'Navigation details from $from to $to - $date';
  }

  @override
  String get sortPodcastsAlphabetically => 'Sortează podcasturile alfabetic';

  @override
  String get sortRadioFavoritesAlphabetically => 'Sortează favoritele alfabetic';

  @override
  String get podcastsSortedAlphabetically => 'Podcasturile au fost sortate alfabetic.';

  @override
  String get radioFavoritesSortedAlphabetically => 'Favoritele radio au fost sortate alfabetic.';

  @override
  String get settingsIncludeFootnotesInText => 'Include notele de subsol în text';

  @override
  String get settingsIncludeFootnotesInTextHint => 'Pentru cărțile EPUB compatibile, afișează fiecare notă imediat după paragraful care face trimitere la ea.';

  @override
  String get documentFootnoteLabel => 'Notă de subsol';

  @override
  String get settingsMultipleDocumentBookmarks =>
      'Permite mai multe semne de carte în documente';

  @override
  String get settingsMultipleDocumentBookmarksHint => 'Când opțiunea este dezactivată, fiecare document păstrează un singur semn de carte. Când este activată, poți salva mai multe semne de carte în același document.';

  @override
  String get documentGoToBookmarkAction => 'Mergi la semnul de carte';

  @override
  String get documentChooseBookmarkTitle => 'Alege semnul de carte';

  @override
  String get documentDeleteBookmarkAction => 'Șterge semnul de carte';

  @override
  String get documentKeepBookmarkTitle => 'Ce semn de carte dorești să păstrezi?';

  @override
  String get documentKeepBookmarkMessage => 'Semnele de carte multiple sunt dezactivate. Alege un semn de carte de păstrat; celelalte vor fi șterse.';

  @override
  String documentBookmarkChoiceLabel(int order, int paragraph) {
    return 'Semnul de carte $order, paragraful $paragraph';
  }

  @override
  String documentBookmarkChoiceLabelWithPreview(
    int order,
    int paragraph,
    String preview,
  ) {
    return 'Semnul de carte $order, paragraful $paragraph. $preview';
  }

  @override
  String get settingsSonarTubePlayerActions => 'Butoane și comportament SonarTube';

  @override
  String get settingsSonarTubeAutoplay => 'Redare automată';

  @override
  String get settingsSonarTubeAutoplayHint =>
      'Când se termină un videoclip sau o piesă, SonarTube îl redă automat pe următorul, dacă este disponibil.';

  @override
  String get settingsVideoLandscapeFullscreen => 'Videoclip pe tot ecranul în modul peisaj';

  @override
  String get settingsVideoLandscapeFullscreenHint => 'Când activezi videoclipul, acesta este afișat pe tot ecranul în orientare peisaj. Posturile radio doar audio nu sunt afectate.';

  @override
  String get settingsPodcastCacheTitle => 'Cache podcasturi';

  @override
  String get settingsPodcastCacheHint => 'Șterge doar fișierele temporare ale podcasturilor. Abonamentele, istoricul și fișierele audio importate rămân intacte.';

  @override
  String settingsPodcastCacheSize(String size) {
    return 'Space used: $size';
  }

  @override
  String get clearPodcastCache => 'Șterge memoria cache a podcasturilor';

  @override
  String get confirmClearPodcastCacheTitle => 'Ștergi memoria cache a podcasturilor?';

  @override
  String get confirmClearPodcastCacheMessage => 'Fișierele temporare ale podcasturilor vor fi șterse. Abonamentele și istoricul episoadelor nu vor fi eliminate.';

  @override
  String podcastCacheCleared(String size) {
    return 'Cache-ul podcasturilor a fost golit: s-au eliberat $size.';
  }

  @override
  String get podcastCacheEmpty => 'Cache-ul podcasturilor este deja gol.';

  @override
  String get pharmacyFeatureTitle => 'Medicamente, parafarmaceutice și suplimente';

  @override
  String get pharmacyProductsSectionTitle => 'Parafarmaceutice și suplimente';

  @override
  String get pharmacyProductsLoadingTitle => 'Se caută parafarmaceutice și suplimente...';

  @override
  String get pharmacyProductsErrorTitle => 'Eroare la căutarea parafarmaceuticelor și suplimentelor';

  @override
  String get pharmacyProductsNoResultsTitle => 'Nu s-a găsit niciun parafarmaceutic sau supliment';

  @override
  String get mediaCutterTitle => 'Taie fișier media';

  @override
  String get mediaCutterInstruction1 => 'Deschide un fișier audio sau video, redă-l și deplasează-te la punctul unde dorești să tai.';

  @override
  String get mediaCutterInstruction2 => 'Pune pe pauză, apasă Împarte, apoi șterge părțile pe care nu le dorești din secțiunea Părți de salvat și apasă Salvează.';

  @override
  String get mediaCutterOpenFile => 'Deschide fișier media';

  @override
  String mediaCutterSelectedFile(String fileName) {
    return 'Fișier selectat: $fileName';
  }

  @override
  String get mediaCutterPosition => 'Poziția tăierii';

  @override
  String get mediaCutterPositionHint => 'Deplasează-te înainte sau înapoi câte o secundă.';

  @override
  String get mediaCutterHideVideoPreview => 'Ascunde videoclipul';

  @override
  String get mediaCutterVideoRotation => 'Rotirea videoclipului';

  @override
  String get mediaCutterVideoRotationNone => 'Fără rotire';

  @override
  String get mediaCutterVideoRotationRight => 'Rotește la dreapta';

  @override
  String get mediaCutterVideoRotationLeft => 'Rotește la stânga';

  @override
  String get mediaCutterVideoRotationUpsideDown => 'Rotește cu 180 de grade';

  @override
  String get mediaCutterVideoPreview => 'Previzualizare video';

  @override
  String get mediaCutterSplit => 'Împarte';

  @override
  String get mediaCutterPartsTitle => 'Părți de salvat';

  @override
  String get mediaCutterPartsHint => 'Atinge o parte pentru a o asculta. Părțile șterse dispar din listă, sunt omise la redare și nu vor fi salvate. Efectele se aplică întregii părți doar când fișierul media este salvat.';

  @override
  String mediaCutterPartLabel(int index) {
    return 'Partea $index';
  }

  @override
  String mediaCutterPartRange(String start, String end) {
    return 'De la $start la $end';
  }

  @override
  String get mediaCutterSave => 'Salvează';

  @override
  String get mediaCutterReady => 'Gata.';

  @override
  String get mediaCutterUnsavedExitTitle => 'Fișier nesalvat';

  @override
  String get mediaCutterUnsavedExitMessage => 'Fișierul nu a fost salvat. Sigur dorești să ieși?';

  @override
  String get mediaCutterNoFile => 'Deschide mai întâi un fișier media.';

  @override
  String get mediaCutterInvalidSplitPoint => 'Alege un punct din interiorul fișierului, nu începutul sau sfârșitul.';

  @override
  String get mediaCutterSplitAlreadyExists => 'Există deja o împărțire în acest punct.';

  @override
  String mediaCutterSplitAdded(String position) {
    return 'Împărțire adăugată la $position.';
  }

  @override
  String get mediaCutterSaving => 'Se procesează...';

  @override
  String mediaCutterSaved(String fileName) {
    return 'Fișier salvat: $fileName';
  }

  @override
  String mediaCutterLoadFailed(Object error) {
    return 'Fișierul nu a putut fi deschis: $error';
  }

  @override
  String mediaCutterSaveFailed(Object error) {
    return 'Salvarea a eșuat: $error';
  }

  @override
  String get mediaCutterNoPartsToSave => 'Păstrează cel puțin o parte înainte de salvare.';

  @override
  String get mediaCutterRestoreDeletedPart => 'Restaurează partea ștersă';

  @override
  String get mediaCutterNoDeletedParts => 'Nu există părți șterse de restaurat.';

  @override
  String get mediaCutterPartDeleteAction => 'Șterge';

  @override
  String get mediaCutterPartTapHint => 'Atinge de două ori pentru a previzualiza această parte. Folosește acțiunile Editează partea, Șterge sau Reglează efectele.';

  @override
  String mediaCutterPartDeleted(String start, String end) {
    return 'Parte ștearsă de la $start la $end.';
  }

  @override
  String mediaCutterPartRestored(String start, String end) {
    return 'Parte restaurată de la $start la $end.';
  }

  @override
  String get mediaCutterPartEffectsAction => 'Reglează efectele';

  @override
  String get mediaCutterPartEditAction => 'Editează partea';

  @override
  String get mediaCutterPartEditDescription => 'Mută începutul sau sfârșitul părții cu 1 secundă, apoi ascultă partea editată.';

  @override
  String mediaCutterPartAdjusted(String start, String end) {
    return 'Parte editată de la $start la $end.';
  }

  @override
  String get mediaCutterPartEffectsTitle => 'Efecte pentru parte';

  @override
  String get mediaCutterPartEffectsDescription => 'Reglează volumul și efectul doar pentru această parte.';

  @override
  String get mediaCutterPartVolumeLabel => 'Volumul părții';

  @override
  String mediaCutterPartVolumeValue(int percent) {
    return 'Volumul părții: $percent%';
  }

  @override
  String get mediaCutterPartEffect => 'Efect audio';

  @override
  String get mediaCutterPartEffectNone => 'Fără efect';

  @override
  String get mediaCutterPartEffectEcho => 'Ecou ușor';

  @override
  String get mediaCutterPartEffectEchoRoom => 'Ecou de cameră';

  @override
  String get mediaCutterPartEffectEchoChamber => 'Ecou de sală';

  @override
  String get mediaCutterPartEffectEchoCathedral => 'Ecou de catedrală';

  @override
  String get mediaCutterPartEffectLargeRoom => 'Cameră mare';

  @override
  String get mediaCutterPartEffectSmallRoom => 'Cameră mică';

  @override
  String get mediaCutterPartEffectBathroom => 'Baie';

  @override
  String get mediaCutterPartEffectTunnel => 'Tunel';

  @override
  String get mediaCutterPartEffectRepeatEcho => 'Ecou repetat';

  @override
  String get mediaCutterPartEffectCorridor => 'Coridor';

  @override
  String get mediaCutterPartEffectDelay => 'Întârziere';

  @override
  String get mediaCutterPartEffectReverb => 'Reverberație ușoară';

  @override
  String get mediaCutterPartEffectChorus => 'Cor';

  @override
  String get mediaCutterPartEffectPitchLow => 'Ton jos';

  @override
  String get mediaCutterPartEffectPitchVeryLow => 'Ton foarte jos';

  @override
  String get mediaCutterPartEffectPitchHigh => 'Ton înalt';

  @override
  String get mediaCutterPartEffectPitchVeryHigh => 'Ton foarte înalt';

  @override
  String get mediaCutterPartEffectRobot => 'Voce de robot';

  @override
  String get mediaCutterPartEffectSuperRobot => 'Super robot';

  @override
  String get mediaCutterPartEffectHelicopter => 'Elicopter';

  @override
  String get mediaCutterPartEffectAlien => 'Vibrato extraterestru';

  @override
  String get mediaCutterPartEffectBrightVoice => 'Voce clară';

  @override
  String get mediaCutterPartEffectDarkVoice => 'Voce întunecată';

  @override
  String get mediaCutterPartEffectGhost => 'Fantomă';

  @override
  String get mediaCutterPartEffectTelephone => 'Telefon';

  @override
  String get mediaCutterPartEffectOldRadio => 'Radio vechi';

  @override
  String get mediaCutterPartEffectMegaphone => 'Megafon';

  @override
  String get mediaCutterPartEffectUnderwater => 'Sub apă';

  @override
  String get mediaCutterPartEffectMonster => 'Monstru';

  @override
  String get mediaCutterPartEffectChipmunk => 'Veveriță';

  @override
  String get mediaCutterPartEffectDream => 'Vis';

  @override
  String get mediaCutterPartEffectDistortion => 'Distorsiune';

  @override
  String get mediaCutterPartEffectLoFi => 'Lo-fi';

  @override
  String get mediaCutterPartEffectReverseEcho => 'Ecou invers';

  @override
  String get mediaCutterPartEffectFadeIn => 'Creștere treptată';

  @override
  String get mediaCutterPartEffectFadeOut => 'Scădere treptată';

  @override
  String get mediaCutterPartEffectAmountLabel => 'Intensitatea efectului';

  @override
  String mediaCutterPartEffectAmountValue(int percent) {
    return 'Intensitatea efectului: $percent%';
  }

  @override
  String get mediaCutterPartPreviewAction => 'Previzualizare';

  @override
  String get mediaCutterPartEffectsSavedOnly => 'Previzualizarea folosește volumul selectat. Efectele audio sunt aplicate la salvare.';

  @override
  String mediaCutterPartEffectsApplied(String start, String end) {
    return 'Efectele au fost actualizate pentru partea de la $start la $end.';
  }

  @override
  String mediaCutterPartEffectsSummary(int percent, String effect) {
    return 'Volum $percent%, efect $effect';
  }

  @override
  String get mediaCutterGuidedModeTitle => 'Tăiere ghidată';

  @override
  String get mediaCutterGuidedModeDescription => 'Potrivită pentru începători. Selectează un punct de început și unul de sfârșit, ascultă tăierea, apoi aplic-o.';

  @override
  String get mediaCutterAdvancedModeTitle => 'Tăiere avansată';

  @override
  String get mediaCutterAdvancedModeDescription => 'Inspirată de programele populare de editare media. Îți permite să împarți un fișier media în mai multe părți și să elimini părțile pe care nu le dorești.';

  @override
  String get mediaCutterChangeCutMode => 'Schimbă tipul de tăiere';

  @override
  String get mediaCutterGuidedSetStart => 'Începutul tăierii';

  @override
  String get mediaCutterGuidedSetEnd => 'Sfârșitul tăierii';

  @override
  String get mediaCutterGuidedApplyCut => 'Aplică tăierea';

  @override
  String get mediaCutterGuidedListenCut => 'Ascultă tăierea';

  @override
  String get mediaCutterGuidedModifyCut => 'Editează tăierea';

  @override
  String get mediaCutterGuidedMoveStartBackOneSecond => 'Mută începutul tăierii înapoi cu 1 secundă';

  @override
  String get mediaCutterGuidedMoveStartForwardOneSecond => 'Mută începutul tăierii înainte cu 1 secundă';

  @override
  String get mediaCutterGuidedMoveEndBackOneSecond => 'Mută sfârșitul tăierii înapoi cu 1 secundă';

  @override
  String get mediaCutterGuidedMoveEndForwardOneSecond => 'Mută sfârșitul tăierii înainte cu 1 secundă';

  @override
  String get mediaCutterCutEditPrecisionLabel => 'Precizia editării tăierii';

  @override
  String mediaCutterCutEditPrecisionValue(String value) {
    return 'Precizia editării tăierii: $value';
  }

  @override
  String get mediaCutterCutEditStepOneSecond => '1 secundă';

  @override
  String get mediaCutterCutEditStepHalfSecond => '0,5 secunde';

  @override
  String get mediaCutterCutEditStepQuarterSecond => '0,25 secunde';

  @override
  String get mediaCutterCutEditStepTenthSecond => '0,10 secunde';

  @override
  String mediaCutterMoveStartBackBy(String value) {
    return 'Mută începutul tăierii înapoi cu $value';
  }

  @override
  String mediaCutterMoveStartForwardBy(String value) {
    return 'Mută începutul tăierii înainte cu $value';
  }

  @override
  String mediaCutterMoveEndBackBy(String value) {
    return 'Mută sfârșitul tăierii înapoi cu $value';
  }

  @override
  String mediaCutterMoveEndForwardBy(String value) {
    return 'Mută sfârșitul tăierii înainte cu $value';
  }

  @override
  String mediaCutterGuidedCutAdjusted(String start, String end) {
    return 'Tăiere schimbată de la $start la $end.';
  }

  @override
  String get mediaCutterGuidedNoCut => 'Fără tăiere';

  @override
  String get mediaCutterGuidedEffectsAction => 'Reglează efectele fișierului';

  @override
  String get mediaCutterGuidedEffectsDescription => 'Reglează volumul și efectele pentru întregul fișier rezultat.';

  @override
  String get mediaCutterGuidedFileTapHint => 'Atinge de două ori pentru a reda fișierul rezultat. Folosește Reglează efectele fișierului pentru a aplica efecte întregului fișier.';

  @override
  String mediaCutterGuidedStartSet(String start) {
    return 'Începutul tăierii a fost setat la $start.';
  }

  @override
  String mediaCutterGuidedEndSet(String start, String end) {
    return 'Sfârșitul tăierii a fost setat la $end. Tăiere de la $start la $end.';
  }

  @override
  String mediaCutterGuidedCutApplied(String start, String end) {
    return 'Tăiere aplicată de la $start la $end.';
  }

  @override
  String get mediaCutterGuidedNeedStartEnd => 'Setează mai întâi începutul și sfârșitul tăierii.';

  @override
  String mediaCutterGuidedCutSummary(String start, String end) {
    return 'Tăiere de la $start la $end';
  }

  @override
  String mediaCutterGuidedMultipleCutSummary(int count, String cuts) {
    return '$count tăieri: $cuts';
  }

  @override
  String get mediaCutterGuidedPendingCutExitMessage => 'Ai o tăiere ghidată care nu a fost aplicată. Dorești să ieși fără să o păstrezi?';

  @override
  String mediaCutterSplitAddedAnnouncement(int partNumber) {
    return 'Împărțire adăugată. Partea $partNumber a fost adăugată.';
  }

  @override
  String get newsAddCommunitySource => 'Adaugă o sursă de știri în comunitatea Sonarpad';

  @override
  String get newsBrowseCommunitySources => 'Surse de știri ale comunității';

  @override
  String get newsAddCommunityInstructions =>
      'Introdu titlul sursei și un URL RSS sau al unui site. Sonarpad va folosi limba de știri selectată și, dacă introduci un site, va încerca să găsească automat fluxul.';

  @override
  String get newsCommunitySourceName => 'Titlul sursei';

  @override
  String get newsCommunitySourceUrl => 'URL RSS sau al site-ului';

  @override
  String get newsCommunitySubmit => 'Verifică și adaugă';

  @override
  String get newsCommunityChecking => 'Se verifică fluxul sau site-ul...';

  @override
  String get newsCommunityMissingFields =>
      'Introdu titlul și URL-ul fluxului sau al site-ului.';

  @override
  String get newsCommunityAdded =>
      'Sursa de știri a fost adăugată cu succes în comunitatea Sonarpad.';

  @override
  String newsCommunityAddError(Object error) {
    return 'Error while adding the news source: $error';
  }

  @override
  String newsCommunitySelectedLanguage(Object language) {
    return 'Selected language: $language';
  }

  @override
  String get newsCommunitySourcesTitle => 'Surse de știri ale comunității';

  @override
  String get newsCommunitySourcesEmpty =>
      'Nu există surse de știri ale comunității pentru această limbă.';

  @override
  String newsCommunitySourcesError(Object error) {
    return 'Error loading community news sources: $error';
  }

  @override
  String newsCommunitySourceAddedToLibrary(Object name) {
    return '$name added to your news library.';
  }

  @override
  String newsCommunityAddToLibraryError(Object error) {
    return 'Error while adding to the library: $error';
  }

  @override
  String get newsCommunitySourceTapHint =>
      'Atinge pentru a o adăuga în biblioteca ta de știri.';

  @override
  String get developerModeEnabled => 'Mod dezvoltator activat.';

  @override
  String get developerModeDisabled => 'Mod dezvoltator dezactivat.';

  @override
  String get developerSectionTitle => 'Dezvoltator';

  @override
  String get developerUseExperimentalFlutterRenderer => 'Folosește rendererul Flutter experimental';

  @override
  String get developerUseExperimentalFlutterRendererHint => 'Dezactivează temporar UIKit pentru a compara VoiceOver cu Flutter pur.';

  @override
  String get letterJumpSelectLetter => 'Selectează litera';

  @override
  String get letterJumpSelected => 'selectată';

  @override
  String get settingsToggleOn => 'Activat';

  @override
  String get settingsToggleOff => 'Dezactivat';

  @override
  String get radioDirectoryLoading => 'Se actualizează țările și limbile pentru radio...';

  @override
  String get recentRadios => 'Posturi radio recente';

  @override
  String get radioNextPage => 'Următoarea';

  @override
  String radioPageOf(Object current, Object total) {
    return 'Pagina $current din $total';
  }

  @override
  String get radioNoResultsWithQuery => 'Nu s-au găsit posturi. Încearcă doar numele postului, fără gen, sau schimbă limba/țara.';

  @override
  String get radioNoResultsGeneric => 'Nu s-au găsit posturi. Încearcă altă limbă, țară sau alt gen.';

  @override
  String radioSearchRawError(Object error) {
    return 'Eroare la căutarea posturilor: $error';
  }

  @override
  String get radioBrowserConnectionError => 'Eroare de conexiune la Radio Browser. Încearcă din nou mai târziu.';

  @override
  String get documentIndexLoadingMessage => 'Se încarcă cuprinsul... Te rugăm să aștepți.';

  @override
  String get documentIndexUnavailableMessage => 'Cuprinsul nu este disponibil pentru acest EPUB.';

  @override
  String mediaCutterVolumeSummary(Object percent) {
    return 'volum $percent%';
  }

  @override
  String mediaCutterDurationSummary(Object duration) {
    return 'durată $duration';
  }

  @override
  String get mediaCutterDurationHourOne => 'oră';

  @override
  String get mediaCutterDurationHourFew => 'ore';

  @override
  String get mediaCutterDurationHourMany => 'ore';

  @override
  String get mediaCutterDurationMinuteOne => 'minut';

  @override
  String get mediaCutterDurationMinuteFew => 'minute';

  @override
  String get mediaCutterDurationMinuteMany => 'minute';

  @override
  String get mediaCutterDurationSecondOne => 'secundă';

  @override
  String get mediaCutterDurationSecondFew => 'secunde';

  @override
  String get mediaCutterDurationSecondMany => 'secunde';

  @override
  String get mediaCutterDurationAnd => 'și';

  @override
  String mediaCutterSeekStepButton(Object step) {
    return 'Reglează deplasarea în fișierul media: $step';
  }

  @override
  String get mediaCutterSeekStepTitle => 'Deplasarea în fișierul media';

  @override
  String mediaCutterSeekStepSelected(Object step) {
    return 'Deplasarea în fișierul media a fost setată la $step.';
  }

  @override
  String get mediaCutterPartEffectBackwards => 'Redare inversă';

  @override
  String get mediaCutterPartEffectTalkingGuitar => 'Chitară vorbitoare';

  @override
  String get mediaCutterPartEffectMosquito => 'Țânțar';

  @override
  String get mediaCutterPartEffectOneOfMany => 'O voce, mulți cântăreți';

  @override
  String get mediaCutterPartEffectOrganVocoder => 'Orgă vorbitoare';

  @override
  String get mediaCutterPartEffectWarped => 'Deformat';

  @override
  String get mediaCutterPartEffectSwirling => 'Vârtej stereo';

  @override
  String get mediaCutterPartEffectVader => 'Voce întunecată cinematografică';

  @override
  String get mediaCutterPartEffectMetallic => 'Metalic';

  @override
  String get mediaCutterPartEffectSongbird => 'Pasăre cântătoare';

  @override
  String get mediaCutterPartEffectExterminator => 'Exterminator';

  @override
  String get mediaCutterPartEffectRainAndThunder => 'Ploaie și tunete';

  @override
  String get mediaCutterPartEffectJungle => 'Junglă';

  @override
  String get mediaCutterPartEffectCrowd => 'Mulțime';

  @override
  String get mediaCutterPartEffectSlotMachines => 'Aparate de joc';

  @override
  String get mediaCutterPartEffectTraffic => 'Trafic';

  @override
  String get mediaCutterPartEffectSpaceship => 'Navă spațială';

  @override
  String get mediaCutterPartEffectCricket => 'Greieri';

  @override
  String get mediaCutterPartEffectSiren => 'Sirenă';

  @override
  String get mediaCutterPartEffectSleighBells => 'Clopoței de sanie';

  @override
  String get mediaCutterPartEffectDj => 'Scratch de DJ';

  @override
  String get mediaCutterPartEffectApplause => 'Aplauze';

  @override
  String get mediaCutterPartEffectBadMelody => 'Melodie falsă';

  @override
  String get mediaCutterPartEffectBadHarmony => 'Armonie disonantă';

  @override
  String get mediaCutterPartEffectWarmVoice => 'Voce caldă';

  @override
  String get mediaCutterPartEffectTurtle => 'Broască țestoasă';

  @override
  String get mediaCutterPartEffectHaunting => 'Bântuitor';

  @override
  String get radioPreviousPage => 'Anterioara';

  @override
  String get noRecentRadios => 'Nu există posturi radio recente.';

  @override
  String get radioBrowseByCity => 'Răsfoiește după oraș';

  @override
  String get radioCityInputHint => 'Introdu numele orașului...';

  @override
  String get openItem => 'Deschide';

  @override
  String get clearSearch => 'Șterge căutarea';

  @override
  String get clearText => 'Șterge textul';

  @override
  String clearedTextAnnouncement(String value) {
    return '$value șters.';
  }

  @override
  String get textDeletedAnnouncement => 'Text șters.';

  @override
  String get fileTypeLabel => 'Fișier';

  @override
  String get cinemaTrailerLoading => 'Se încarcă trailerul';

  @override
  String get cinemaNoTrailer => 'Nu este disponibil niciun trailer pentru acest film';

  @override
  String get radioScheduleHours => 'Ore';

  @override
  String get radioScheduleSelectHours => 'Selectează orele';

  @override
  String get radioScheduleMinutes => 'Minute';

  @override
  String get radioScheduleSelectMinutes => 'Selectează minutele';

  @override
  String radioScheduleLabeledValue(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get radioScheduleStopCurrentFirst => 'Oprește înregistrarea curentă înainte de a programa una nouă.';

  @override
  String get radioScheduleStartTime => 'Ora de început';

  @override
  String get radioScheduleEndTime => 'Ora de sfârșit';

  @override
  String get radioScheduleDialogTitle => 'Programează înregistrarea';

  @override
  String get radioScheduleOpenRequirement => 'Înregistrarea programată continuă să funcționeze în timp ce navighezi prin alte ecrane Sonarpad. Sonarpad trebuie să rămână deschis; dacă aplicația este închisă sau suspendată de sistem, pornirea înregistrării nu este garantată.';

  @override
  String radioScheduleStartTimeValue(Object time) {
    return 'Ora de început: $time';
  }

  @override
  String radioScheduleEndTimeValue(Object time) {
    return 'Ora de sfârșit: $time';
  }

  @override
  String get radioScheduleOptionalTitle => 'Titlu opțional';

  @override
  String get radioScheduleTitleHint => 'Lasă gol pentru a folosi numele postului radio sau al canalului TV';

  @override
  String get radioScheduleAction => 'Programează';

  @override
  String radioScheduledRecordingRange(Object start, Object end) {
    return 'Înregistrare programată: $start - $end.';
  }

  @override
  String get radioScheduledRecordingAlreadyActive => 'Înregistrarea programată nu a pornit: o altă înregistrare este deja în curs.';

  @override
  String get radioScheduledRecordingStarted => 'Înregistrarea programată a început.';

  @override
  String radioScheduledRecordingError(Object error) {
    return 'Eroare la înregistrarea programată: $error';
  }

  @override
  String get radioScheduledRecordingSaved => 'Înregistrarea programată a fost salvată.';

  @override
  String radioScheduledRecordingSaveError(Object error) {
    return 'Eroare la salvarea înregistrării programate: $error';
  }

  @override
  String get radioScheduledRecordingCancelled => 'Înregistrarea programată a fost anulată.';

  @override
  String radioScheduledRecordingRangeWithTitle(
    Object start,
    Object end,
    Object title,
  ) {
    return 'Înregistrare programată: $start - $end. Titlu: $title.';
  }

  @override
  String get radioScheduleCancelAction => 'Anulează înregistrarea programată';

  @override
  String get radioLanguageTr => 'Turcă';

  @override
  String get radioCountryOptionTr => 'Turcia';

  @override
  String get radioCommunityLanguageTurkish => 'Turcă';

  @override
  String get simplifiedChineseLanguageName => 'Chineză simplificată';

  @override
  String get chinaCountryName => 'China';

  @override
  String get technicalErrorGeneric => 'Eroare tehnică. Încearcă din nou.';

  @override
  String get onlineVideoPreparationFailed => 'Videoclipul nu a putut fi pregătit.';

  @override
  String cinemaTrailerTitle(String title) {
    return 'Trailer: $title';
  }

  @override
  String mediaCutterExportPartProgress(int index, int total) {
    return 'Partea $index din $total';
  }

  @override
  String get mediaCutterExportFinalVerification => 'Verificare finală';

  @override
  String get mediaCutterExportMergeParts => 'Se îmbină părțile';

  @override
  String get mediaCutterExportFileCheck => 'Verificarea fișierului';

  @override
  String get mediaCutterExportPublishing => 'Publicare';

  @override
  String get mediaCutterExportCompletion => 'Finalizare';

  @override
  String get mediaCutterAddTrack => 'Adaugă o pistă nouă';

  @override
  String get mediaCutterChooseAudioTrack => 'Alege fișierul audio';

  @override
  String mediaCutterAddedTrackSelected(String name) {
    return 'Fișier audio selectat: $name';
  }

  @override
  String get mediaCutterOriginalTrackVolume => 'Volumul pistei originale';

  @override
  String get mediaCutterNewTrackVolume => 'Volumul pistei noi';

  @override
  String get mediaCutterLoopNewTrack => 'Repetă pista nouă';

  @override
  String get mediaCutterPreviewNewTrack => 'Ascultă previzualizarea';

  @override
  String get mediaCutterFinalizeTrack => 'Finalizează';

  @override
  String mediaCutterAddedTrackApplied(String name) {
    return 'Pistă nouă adăugată: $name';
  }

  @override
  String get mediaCutterAddedTrackInvalidAudio => 'Fișierul selectat nu conține o pistă audio validă.';

  @override
  String get mediaCutterAddedTrackPreviewPreparing => 'Se pregătește previzualizarea…';

  @override
  String get mediaCutterAddedTrackPreviewFailed => 'Previzualizarea nu a putut fi creată.';

  @override
  String get mediaCutterMixingAddedTrack => 'Se mixează pista nouă';

  @override
  String get preserveMedia => 'Păstrează conținutul';

  @override
  String get preserveMediaSaving => 'Se salvează conținutul…';

  @override
  String get preserveMediaSaved => 'Conținut salvat în Documentele Sonarpad.';

  @override
  String get preserveMediaError => 'Conținutul nu a putut fi păstrat.';

  @override
  String get mediaProcessingCompleted => 'Procesare finalizată.';

  @override
  String get saveInSonarpadDocuments => 'Salvează în Documentele Sonarpad';

  @override
  String get mediaCutterProcess => 'Procesează';

  @override
  String get sonarTubeGoToChannel => 'Mergi la canal';

  @override
  String get sonarTubeViewComments => 'Vezi comentariile';

  @override
  String get sonarTubeComments => 'Comentarii';

  @override
  String get sonarTubeNoComments => 'Nu există comentarii disponibile.';

  @override
  String get sonarTubeLoadMoreComments => 'Încarcă mai multe comentarii';

  @override
  String get sonarTubeTranscribeVideo => 'Transcrie videoclipul';

  @override
  String get sonarTubeTranscript => 'Transcriere';

  @override
  String get sonarTubeNoTranscript =>
      'Nu există transcriere disponibilă pentru acest videoclip.';

  @override
  String get sonarTubeCopyTranscript => 'Copiază transcrierea';

  @override
  String get sonarTubeTranscriptCopied => 'Transcriere copiată în clipboard';

  @override
  String get sonarTubeTranscriptSavedInDocuments =>
      'Transcrierea a fost salvată în Documente.';

  @override
  String get copyToClipboard => 'Copiază în clipboard';

  @override
  String get textCopiedToClipboard => 'Text copiat în clipboard';

  @override
  String get protectDocumentWithPassword => 'Protejează cu parolă';

  @override
  String get removeDocumentPasswordProtection => 'Elimină protecția cu parolă';

  @override
  String get documentPassword => 'Parolă';

  @override
  String get confirmDocumentPassword => 'Confirmă parola';

  @override
  String get chooseDocumentPassword => 'Introdu o parolă și confirm-o. Parola va fi necesară înainte de deschiderea sau distribuirea acestui document.';

  @override
  String get enterCurrentDocumentPassword => 'Introdu parola curentă pentru a elimina protecția.';

  @override
  String get documentPasswordRequired => 'Introdu o parolă.';

  @override
  String get documentPasswordsDoNotMatch => 'Parolele nu coincid.';

  @override
  String get incorrectDocumentPassword => 'Parolă incorectă.';

  @override
  String get documentPasswordProtectionEnabled => 'Protecția cu parolă a fost activată.';

  @override
  String get documentPasswordProtectionRemoved => 'Protecția cu parolă a fost eliminată.';

  @override
  String get documentPasswordRequiredTitle => 'Parolă necesară';

  @override
  String get enterDocumentPasswordToShare => 'Acest document este protejat. Introdu parola pentru a continua distribuirea.';

  @override
  String get enterDocumentPasswordToOpen => 'Acest document este protejat. Introdu parola pentru a-l deschide.';

  @override
  String get documentPasswordProtectedStatus => 'Protejat cu parolă';

  @override
  String get rename => 'Redenumește';

  @override
  String get renameRecording => 'Redenumește înregistrarea';

  @override
  String get newRecordingName => 'Noul nume al înregistrării';

  @override
  String get recordingCannotRenameWhileInProgress => 'O înregistrare în curs nu poate fi redenumită.';

  @override
  String get recordingNameAlreadyExists => 'Există deja o înregistrare cu acest nume.';

  @override
  String get renameDocument => 'Redenumește documentul';

  @override
  String get newDocumentName => 'Noul nume al documentului';

  @override
  String get documentNameAlreadyExists => 'Există deja un document cu acest nume.';

  @override
  String get recordingExitPrompt => 'Înregistrarea este în curs. Vrei să o oprești sau să continui înregistrarea?';

  @override
  String get continueRecording => 'Continuă înregistrarea';

  @override
  String get settingsShowOnlyMultilingualEdgeVoices => 'Afișează doar vocile multilingve';

  @override
  String get weatherAirQuality => 'Calitatea aerului';

  @override
  String get weatherAirQualityGood => 'Bună';

  @override
  String get weatherAirQualityFair => 'Acceptabilă';

  @override
  String get weatherAirQualityModerate => 'Moderată';

  @override
  String get weatherAirQualityPoor => 'Slabă';

  @override
  String get weatherAirQualityVeryPoor => 'Foarte slabă';

  @override
  String get weatherAirQualityExtremelyPoor => 'Extrem de slabă';

  @override
  String get sonarpadAudiodescriptionsTitle => 'Audiodescrieri Sonarpad';

  @override
  String get sonarpadAudiodescriptionsAll => 'Toate audiodescrierile Sonarpad';

  @override
  String get sonarpadAudiodescriptionsSearchHint =>
      'Caută un film, serial sau episod';

  @override
  String get sortBy => 'Sortează după';

  @override
  String get sortAlphabetical => 'Alfabetic';

  @override
  String get sortChronological => 'Cronologic';

  @override
  String get contentUnavailable => 'Conținut indisponibil.';

  @override
  String get downloadUnavailable => 'Descărcare indisponibilă.';

  @override
  String get sonarTubeChannelPlaylists => 'Liste de redare';

  @override
  String get sonarTubeChannelShorts => 'Videoclipuri scurte';

  @override
  String sonarTubeVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videoclipuri',
      one: '1 videoclip',
    );
    return '$_temp0';
  }

  @override
  String get sonarTubeViewDescription => 'Vezi descrierea';

  @override
  String get sonarTubeDescription => 'Descriere';

  @override
  String get sonarTubeNoDescription =>
      'Nu există o descriere disponibilă pentru acest videoclip.';

  @override
  String get pyannoteTestTitle => 'Test pyannote pe mobil';

  @override
  String get pyannoteTestInstructions =>
      'Acest test folosește același model ONNX pyannote ca pe Windows. Pentru prima comparație, folosește testul rapid pe primele 2 minute.';

  @override
  String get pyannoteQuickTest => 'Test rapid pyannote: primele 2 minute';

  @override
  String get pyannoteFullTest => 'Test complet pyannote: întregul fișier';

  @override
  String get pyannoteShareArtifacts =>
      'Partajează WAV-ul canonic și rezultatul JSON de pe mobil';

  @override
  String get pyannoteInitialStatus =>
      'Alege un fișier audio sau video. Pentru prima comparație, folosește testul rapid.';

  @override
  String get pyannotePreparingQuick =>
      'Se pregătește testul rapid pe primele 2 minute...';

  @override
  String get pyannotePreparingFull => 'Se pregătește testul complet...';

  @override
  String get pyannoteCompletedStatus =>
      'Testul pe mobil s-a încheiat. Partajează WAV-ul și JSON-ul și folosește același WAV și în testul Windows.';

  @override
  String get pyannoteFilesUnavailable =>
      'Fișierele ultimului test nu mai sunt disponibile.';

  @override
  String get pyannoteFailure => 'Testul pyannote a eșuat.';

  @override
  String get pyannoteShareText =>
      'Sonarpad: test de paritate pyannote pe mobil. Folosește WAV-ul canonic atașat și în testul Windows.';

  @override
  String get pyannoteShareSubject => 'Test pyannote Sonarpad';

  @override
  String get pyannoteBenchmark10Min => 'Test de performanță pyannote: primele 10 minute';

  @override
  String get pyannoteBenchmarkPreparing =>
      'Se rulează testul de performanță pyannote pe primele 10 minute...';

  @override
  String get pyannoteBenchmarkCompleted =>
      'Testul de performanță s-a încheiat. Rezultatele detaliate au fost înregistrate în jurnalul Sonarpad.';

  @override
  String get pyannoteCandidateValidation5x10m =>
      'Validează pasul 2 + margine 0,35 pe cinci segmente de câte 10 minute';

  @override
  String get pyannoteCandidateValidationPreparing =>
      'Se rulează validarea pyannote pe cinci segmente din film...';

  @override
  String get pyannoteCandidateValidationPassed =>
      'Validare finalizată: pasul 2 + margine 0,35 a îndeplinit criteriile de siguranță. Verifică jurnalul pentru detalii.';

  @override
  String get pyannoteCandidateValidationFailed =>
      'Validare finalizată: pasul 2 + margine 0,35 nu a îndeplinit toate criteriile de siguranță. Verifică jurnalul pentru detalii.';

  @override
  String get pyannoteXnnpackBenchmark10Min =>
      'Test de performanță CPU vs XNNPACK: primele 10 minute';

  @override
  String get pyannoteXnnpackBenchmarkPreparing =>
      'Se compară performanța CPU și XNNPACK pe primele 10 minute...';

  @override
  String get pyannoteXnnpackBenchmarkCompleted =>
      'Testul de performanță CPU vs XNNPACK s-a încheiat. Verifică jurnalul pentru paritate și viteză.';

  @override
  String get audioDescriptionCreateAiTitle => 'Creează audiodescriere cu IA';

  @override
  String get audioDescriptionChooseVideo => 'Alege videoclipul';

  @override
  String get audioDescriptionAiService => 'Serviciu IA';

  @override
  String get audioDescriptionUseGeminiKey => 'Folosește cheia API Gemini';

  @override
  String get audioDescriptionUseSonarpadAi => 'Folosește serviciul IA Sonarpad';

  @override
  String get audioDescriptionGeminiApiKey => 'Cheie API Gemini';

  @override
  String get audioDescriptionGeminiModel => 'Model Gemini';

  @override
  String get audioDescriptionRefreshModels => 'Actualizează lista de modele';

  @override
  String get audioDescriptionRefreshingModels => 'Se actualizează modelele...';

  @override
  String get audioDescriptionSonarpadCode => 'Cod personal IA Sonarpad';

  @override
  String get audioDescriptionActivateSonarpad => 'Activează / verifică IA Sonarpad';

  @override
  String get audioDescriptionActivatingSonarpad => 'Se activează IA Sonarpad...';

  @override
  String get audioDescriptionServerManagedModel => 'Gestionat de serviciul IA Sonarpad';

  @override
  String get audioDescriptionLanguage => 'Limba audiodescrierii';

  @override
  String get audioDescriptionDetailLevel => 'Nivel de detaliu';

  @override
  String get audioDescriptionDetailConcise => 'Concis';

  @override
  String get audioDescriptionDetailNormal => 'Normal';

  @override
  String get audioDescriptionDetailDetailed => 'Detaliat';

  @override
  String get audioDescriptionDetailIntensive => 'Intensiv';

  @override
  String get audioDescriptionExtendedPauses => 'Activează pauze extinse când o descriere nu încape într-un interval de liniște';

  @override
  String get audioDescriptionRecognizeCharacters => 'Încearcă să recunoască personajele și să le folosească numele';

  @override
  String get audioDescriptionSaveProject => 'Salvează și proiectul pentru editare ulterioară';

  @override
  String get audioDescriptionCreate => 'Creează audiodescrierea';

  @override
  String get audioDescriptionVoiceTesting => 'Se testează vocea...';

  @override
  String get audioDescriptionApiKeyRequired => 'Introdu o cheie API Gemini.';

  @override
  String get audioDescriptionModelsUpdated => 'Lista modelelor Gemini a fost actualizată.';

  @override
  String get audioDescriptionModelsError => 'Lista modelelor Gemini nu a putut fi actualizată.';

  @override
  String get audioDescriptionSonarpadCodeRequired => 'Introdu codul personal IA Sonarpad.';

  @override
  String get audioDescriptionSonarpadActivated => 'IA Sonarpad este activă pe acest dispozitiv.';

  @override
  String get audioDescriptionSonarpadActivationError => 'IA Sonarpad nu a putut fi activată sau verificată.';

  @override
  String get audioDescriptionSonarpadDeviceLimitReached => 'A fost atins numărul maxim de dispozitive asociate acestui cod IA Sonarpad. Elimină un dispozitiv deja asociat sau contactează asistența.';

  @override
  String get audioDescriptionSonarpadBalance => 'Credit IA Sonarpad';

  @override
  String get audioDescriptionSonarpadBalanceUnavailable => 'Credit indisponibil.';

  @override
  String get audioDescriptionEdgeVoiceReady => 'Vocea Edge selectată este disponibilă.';

  @override
  String get audioDescriptionChooseVideoFirst => 'Alege mai întâi un fișier video.';

  @override
  String get audioDescriptionStagePreparing => 'Se pregătește videoclipul...';

  @override
  String get audioDescriptionStageDialogue => 'Se detectează dialogurile cu pyannote...';

  @override
  String get audioDescriptionStageVideo => 'Se pregătesc segmentele video...';

  @override
  String get audioDescriptionStageGemini => 'Se generează audiodescrierile cu IA...';

  @override
  String get audioDescriptionStageTts => 'Se creează vocile...';

  @override
  String get audioDescriptionStageMixing => 'Se creează MP3-ul audiodescris...';

  @override
  String get audioDescriptionCompleted => 'Audiodescriere finalizată.';

  @override
  String get audioDescriptionCancelled => 'Crearea audiodescrierii a fost anulată.';

  @override
  String get audioDescriptionCancelling => 'Se anulează...';

  @override
  String get audioDescriptionGenerationFailed => 'Crearea audiodescrierii a eșuat.';

  @override
  String get audioDescriptionGetGeminiKey => 'Obține o cheie API Gemini';

  @override
  String get audioDescriptionKeepCharacterCatalog => 'Salvează și actualizează catalogul de personaje: util pentru un serial';

  @override
  String get audioDescriptionCharacterCatalogChoose => 'Alege un catalog de personaje salvat';

  @override
  String get audioDescriptionCharacterCatalogNew => 'Catalog nou';

  @override
  String get audioDescriptionCharacterCatalogNameTitle => 'Catalog de personaje';

  @override
  String get audioDescriptionCharacterCatalogNamePrompt => 'Cum vrei să numești catalogul de personaje?';

  @override
  String get audioDescriptionCharacterCatalogNameError => 'Introdu un nume pentru catalogul de personaje.';

  @override
  String get audioDescriptionCharacterCatalogSaved => 'Catalogul de personaje a fost actualizat.';

  @override
  String get audioDescriptionCharacterCatalogSaveWarning => 'Audiodescrierea a fost creată, dar catalogul de personaje nu a putut fi salvat:';

  @override
  String get audioDescriptionRecognizeScreenText => 'Recunoaște textul de pe ecran important pentru narațiune';

  @override
  String get audioDescriptionHighDemandTitle => 'Serviciul IA este ocupat';

  @override
  String get audioDescriptionHighDemandMessage => 'Serviciul IA este încă indisponibil după mai multe încercări. Vrei să continui să aștepți și să reîncerci?';

  @override
  String get audioDescriptionContinueWaiting => 'Continuă să aștepți';

  @override
  String get audioDescriptionStopGeneration => 'Oprește';

  @override
  String get audioDescriptionQuotaTitle => 'Cota Gemini a fost epuizată';

  @override
  String get audioDescriptionQuotaMessage => 'Modelul Gemini curent și-a epuizat cota. Poți alege alt model, poți continua să aștepți sau poți opri.';

  @override
  String get audioDescriptionSwitchModel => 'Alege alt model';

  @override
  String get audioDescriptionOverlapTitle => 'Soluție de rezervă finală';

  @override
  String get audioDescriptionOverlapMessage => 'Nicio descriere generată nu încape în siguranță în spațiile fără dialog. Vrei să folosești soluția finală de rezervă, care poate suprapune narațiunea peste dialog? Aceasta nu este activată niciodată automat.';

  @override
  String get audioDescriptionAllowOverlap => 'Folosește soluția finală de rezervă';

  @override
  String get audioDescriptionResumeTitle => 'A fost găsită o audiodescriere începută anterior';

  @override
  String get audioDescriptionResumeMessage => 'Sonarpad a găsit un punct de reluare compatibil. Continui de la ultimul segment finalizat sau reîncepi de la început?';

  @override
  String get audioDescriptionResume => 'Continuă';

  @override
  String get audioDescriptionRestart => 'Reîncepe';

  @override
  String get audioDescriptionStageBriefRetry => 'Se reia analiza cu descrieri scurte...';

  @override
  String get audioDescriptionBriefRetryTitle => 'Reîncearcă folosind descrieri scurte';

  @override
  String get audioDescriptionBriefRetryMessage => 'Nicio descriere generată nu încape în siguranță în spațiile fără dialog. Înainte de a permite narațiunea peste dialog, vrei să reîncerci o dată analiza cu descrieri foarte scurte?';

  @override
  String get audioDescriptionRetryBrief => 'Reîncearcă în modul Scurt';

  @override
  String audioDescriptionProjectEditorDescriptionOption(
    String index,
    String time,
    String text,
  ) {
    return '$index. $time s. $text';
  }

  @override
  String audioDescriptionLanguageCountry(String language, String country) {
    return '$language ($country)';
  }

  @override
  String get audioDescriptionCancelConfirmation => 'Sigur vrei să anulezi crearea audiodescrierii?';

  @override
  String get audioDescriptionEditProject => 'Editează proiectul existent';

  @override
  String get audioDescriptionFindProject => 'Caută în Documentele Sonarpad';

  @override
  String get audioDescriptionBrowseProject => 'Răsfoiește…';

  @override
  String get audioDescriptionNoSavedProjects => 'Nu s-au găsit proiecte în Documentele Sonarpad.';

  @override
  String get audioDescriptionContinueAi => 'Continuă audiodescrierea cu IA';

  @override
  String get audioDescriptionNoCheckpoint => 'Nu a fost găsită nicio audiodescriere întreruptă pentru acest videoclip. Selectează videoclipul original folosit anterior.';

  @override
  String get sonarTubeSaveFormatPrompt => 'Alege formatul de salvare';

  @override
  String get sonarTubeSaveAsMp4 => 'Salvează ca MP4';

  @override
  String get sonarTubeSaveAsMp3 => 'Salvează ca MP3';

  @override
  String get audioDescriptionCreateVideoOutput => 'Salvează audiodescrierea în videoclip';

  @override
  String get audioDescriptionLoadCharacterCatalog => 'Încarcă catalogul de personaje';

  @override
  String get audioDescriptionImportCharacterCatalog => 'Importă catalogul din fișier';

  @override
  String get audioDescriptionCharacterCatalogLoaded => 'Catalogul de personaje a fost încărcat.';

  @override
  String get audioDescriptionCreateWithAi => 'Creează audiodescriere cu IA';

  @override
  String get settingsHomeCustomization => 'Personalizează ecranul principal';

  @override
  String get settingsHomeCustomizationHint => 'Alege elementele care se afișează și, când categoriile sunt dezactivate, ordinea lor.';

  @override
  String get homeCategories => 'Categorii';

  @override
  String get homeCategoriesHint => 'Grupează elementele ecranului principal în categorii.';

  @override
  String get homeVisibleItems => 'Elemente vizibile';

  @override
  String get homeReorderItems => 'Reordonează elementele';

  @override
  String get homeResetDefaults => 'Restabilește valorile implicite';

  @override
  String get homeResetDefaultsConfirmTitle => 'Restabilești ecranul principal?';

  @override
  String get homeResetDefaultsConfirmMessage => 'Toate funcțiile disponibile vor fi afișate din nou, categoriile vor fi activate și ordinea personalizată va fi ștearsă.';

  @override
  String get homeResetDefaultsDone => 'Ecranul principal a fost restabilit la valorile implicite.';

  @override
  String get homeReorderTitle => 'Reordonează ecranul principal';

  @override
  String get homeMoveItem => 'Mută elementul';

  @override
  String get homeDigitalLibrary => 'Bibliotecă digitală';

  @override
  String get homeTv => 'TV';

  @override
  String get homeRaiPlay => 'RaiPlay';

  @override
  String get homeLa7Play => 'LA7 Play';

  @override
  String get homeRaiPlaySound => 'RaiPlay Sound';

  @override
  String get homeOpeningHours => 'Program de funcționare';

  @override
  String get homeDirectory => 'Pagini Albe și Pagini Aurii';
}
