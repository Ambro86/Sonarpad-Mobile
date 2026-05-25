import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;
  bool get _isEn => locale.languageCode == 'en';

  static const supportedLocales = [Locale('it'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  String get appTitle => 'Sonarpad';
  String get appLanguage => _isEn ? 'App Language' : 'Lingua dell\'app';
  String get homeSemanticsLabel => _isEn ? 'Sonarpad, main screen' : 'Sonarpad, schermata principale';
  String get settings => _isEn ? 'Settings' : 'Impostazioni';
  String get settingsHint => _isEn ? 'Open settings' : 'Apre le impostazioni';
  String get info => _isEn ? 'About' : 'Informazioni';
  String get infoHint => _isEn ? 'Open app info' : 'Apre le informazioni sull\'app';
  String get loading => _isEn ? 'Loading' : 'Caricamento';
  String get ttsVoiceLanguage => _isEn ? 'TTS Voice Language' : 'Lingua voci TTS';
  String get ttsVoice => _isEn ? 'TTS Voice' : 'Voce TTS';
  String get saveSettings => _isEn ? 'Save settings' : 'Salva impostazioni';
  String get settingsSaved => _isEn ? 'Settings saved.' : 'Impostazioni salvate.';
  String get infoDescription => _isEn
      ? 'Sonarpad is a simple app packed with features. Designed to be accessible for the visually impaired using VoiceOver, here you can listen to news, search and subscribe to podcasts, import Wikipedia articles, add documents to your library, save and edit them. Sonarpad\'s features are constantly updated, and they are all designed to make life easier for the visually impaired.'
      : 'Sonarpad è un\'app semplice, ma con tante funzioni. Nata per essere accessibile ai non vedenti usando VoiceOver, qui potrete ascoltare le notizie, cercare e iscriversi ai podcast, importare articoli di Wikipedia, aggiungere i documenti alla vostra libreria, salvarli e modificarli. Le funzioni di Sonarpad sono in continuo aggiornamento, e sono tutte pensate per rendere più facile la vita dei non vedenti.';
  String get infoAuthor => _isEn ? 'Author: Ambrogio Riili' : 'Autore: Ambrogio Riili';
  String get news => _isEn ? 'News' : 'Notizie';
  String get newsHint => _isEn ? 'Open news from Google News RSS' : 'Apre le notizie da Google News RSS';
  String get podcasts => _isEn ? 'Podcasts' : 'Podcast';
  String get podcastsHint => _isEn ? 'Subscribe to podcasts, play or download episodes' : 'Iscriviti ai podcast, riproduci o scarica episodi';
  String get importFromWikipedia => 'Wikipedia';
  String get wikipediaHint => _isEn ? 'Search for a Wikipedia article and import the text' : 'Cerca un articolo Wikipedia e importa il testo';

  String get newsLanguage => _isEn ? 'News Language' : 'Lingua notizie';
  String get loadingNews => _isEn ? 'Loading news' : 'Caricamento notizie';
  String error(Object error) => _isEn ? 'Error: $error' : 'Errore: $error';
  String get noNewsFound => _isEn ? 'No news found' : 'Nessuna notizia trovata';
  String get loadingArticle => _isEn ? 'Loading article' : 'Caricamento articolo';
  String get noFullArticleFound => _isEn ? 'Full article not available. Showing feed summary.' : 'Articolo integrale non disponibile. Mostro il riassunto del feed.';
  String get italian => _isEn ? 'Italian' : 'Italiano';
  String get english => 'English';
  String get newsSource => _isEn ? 'News source' : 'Fonte notizie';

  String get article => _isEn ? 'Article' : 'Articolo';
  String get articlePreview => _isEn ? 'Article preview' : 'Anteprima articolo';
  String get readFullArticle => _isEn ? 'Read full article' : 'Leggi articolo completo';
  String get extractingReaderArticleText => _isEn ? 'Extracting text in reader mode...' : 'Estraggo il testo in modalita lettura...';
  String get extractingVisibleArticleText => _isEn ? 'Extracting visible text from page...' : 'Estraggo il testo visibile dalla pagina...';
  String source(String source) => _isEn ? 'Source: $source' : 'Fonte: $source';
  String get readyStatus => _isEn ? 'Ready.' : 'Pronto.';
  String get preparingEdgeTts => _isEn ? 'Preparing Edge TTS reading in blocks...' : 'Preparo lettura Edge TTS a blocchi...';
  String get noTextToRead => _isEn ? 'No text to read.' : 'Nessun testo da leggere.';
  String chunkCreated(int index, int total) => _isEn ? 'Block $index of $total created. Reading in progress...' : 'Blocco $index di $total creato. Lettura in corso...';
  String playingChunk(int index, int total, int size) => _isEn ? 'Playing block $index of $total ($size bytes)...' : 'Riproduco blocco $index di $total ($size byte)...';
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) => _isEn
      ? 'Reading finished. Blocks created: $readyChunks/$totalChunks. Library: $libraryPath'
      : 'Lettura terminata. Blocchi creati: $readyChunks/$totalChunks. Libreria: $libraryPath';
  String get libraryNotSpecified => _isEn ? 'not specified' : 'non indicata';
  String get readingStopped => _isEn ? 'Reading stopped.' : 'Lettura interrotta.';
  String edgeTtsError(Object error) => _isEn ? 'Edge TTS Error: $error' : 'Errore Edge TTS: $error';
  String audioChunksReady(int readyChunks, int totalChunks) => _isEn ? 'Audio blocks ready: $readyChunks / $totalChunks' : 'Blocchi audio pronti: $readyChunks / $totalChunks';
  String get readingInProgress => _isEn ? 'Reading in progress...' : 'Lettura in corso...';
  String get readWithEdgeTts => _isEn ? 'Read with Edge TTS' : 'Leggi con Edge TTS';
  String get stopReading => _isEn ? 'Stop reading' : 'Interrompi lettura';
  String get openOriginalArticle => _isEn ? 'Open original article' : 'Apri articolo originale';

  String get searchPodcasts => _isEn ? 'Search podcasts' : 'Cerca podcast';
  String get podcastName => _isEn ? 'Podcast name' : 'Nome podcast';
  String get podcastSearchHint => _isEn ? 'Example: technology, history, the podcast name...' : 'Esempio: tecnologia, storia, il nome del podcast...';
  String get searchCountry => _isEn ? 'Search country' : 'Paese ricerca';
  String get podcastCategory => _isEn ? 'Podcast category' : 'Categoria podcast';
  String get countryItaly => _isEn ? 'Italy' : 'Italia';
  String get countryUnitedStatesEnglish => _isEn ? 'United States / English' : 'Stati Uniti / inglese';
  String get countryUnitedKingdom => _isEn ? 'United Kingdom' : 'Regno Unito';
  String get countrySpain => _isEn ? 'Spain' : 'Spagna';
  String get countryFrance => _isEn ? 'France' : 'Francia';
  String get searchInProgress => _isEn ? 'Search in progress...' : 'Ricerca in corso...';
  String podcastResultsFound(int count) => _isEn ? 'Found $count podcasts' : 'Trovati $count podcast';
  String podcastSearchError(Object error) => _isEn ? 'Podcast search error: $error' : 'Errore ricerca podcast: $error';
  String subscribedTo(String title) => _isEn ? 'Subscribed to $title' : 'Iscritto a $title';
  String subscriptionError(Object error) => _isEn ? 'Subscription error: $error' : 'Errore iscrizione: $error';
  String podcastSubscriptionError(Object error) => _isEn ? 'Podcast subscription error: $error' : 'Errore iscrizione podcast: $error';
  String get searchResults => _isEn ? 'Search results' : 'Risultati ricerca';
  String get podcastInfo => _isEn ? 'Podcast info' : 'Info podcast';
  String get subscribe => _isEn ? 'Subscribe' : 'Iscriviti';
  String get podcastAuthor => _isEn ? 'Author' : 'Autore';
  String get noPodcastDescription => _isEn ? 'No description available.' : 'Nessuna descrizione disponibile.';
  String get loadingPodcastInfo => _isEn ? 'Loading podcast info' : 'Caricamento info podcast';
  String get podcastArtwork => _isEn ? 'Podcast artwork' : 'Copertina podcast';
  String get addFeedUrlManually => _isEn ? 'Add RSS feed URL manually' : 'Aggiungi manualmente URL feed RSS';
  String get podcastFeedUrl => _isEn ? 'Podcast RSS feed URL' : 'URL feed podcast RSS';
  String get subscribeFromUrl => _isEn ? 'Subscribe from URL' : 'Iscriviti da URL';
  String get subscribedPodcasts => _isEn ? 'Subscribed podcasts' : 'Podcast iscritti';
  String get noSubscribedPodcasts => _isEn ? 'No subscribed podcasts. Search for a podcast and tap a result to subscribe.' : 'Nessun podcast iscritto. Cerca un podcast e tocca il risultato per iscriverti.';
  String get loadingEpisodes => _isEn ? 'Loading episodes' : 'Caricamento episodi';
  String get noAudioEpisodesFound => _isEn ? 'No audio episodes found in the feed.' : 'Nessun episodio audio trovato nel feed.';
  String get episodes => _isEn ? 'Episodes' : 'Episodi';
  String get episodeActions => _isEn ? 'Episode actions' : 'Azioni episodio';
  String downloaded(String path) => _isEn ? 'Downloaded: $path' : 'Scaricato: $path';
  String episodeError(Object error) => _isEn ? 'Episode error: $error' : 'Errore episodio: $error';
  String get play => _isEn ? 'Play' : 'Riproduci';
  String get pause => _isEn ? 'Pause' : 'Pausa';
  String get rewind15s => _isEn ? 'Rewind 15s' : 'Indietro 15s';
  String get forward15s => _isEn ? 'Forward 15s' : 'Avanti 15s';
  String get stop => 'Stop';
  String get back => _isEn ? 'Back' : 'Indietro';
  String get episodePlayer => _isEn ? 'Episode player' : 'Player episodio';
  String get loadingEpisodeAudio => _isEn ? 'Loading episode audio' : 'Caricamento audio episodio';
  String get download => _isEn ? 'Download' : 'Scarica';

  String get searchWikipedia => _isEn ? 'Search on Wikipedia' : 'Cerca su Wikipedia';
  String get wikipediaLanguage => _isEn ? 'Wikipedia language' : 'Lingua Wikipedia';
  String get search => _isEn ? 'Search' : 'Cerca';
  String get wikipediaSearch => _isEn ? 'Wikipedia search' : 'Ricerca Wikipedia';
  String get wikipediaImporting => _isEn ? 'Wikipedia import' : 'Importazione Wikipedia';
  String get noWikipediaResults => _isEn ? 'No Wikipedia results found' : 'Nessun risultato Wikipedia trovato';
  String get wikipediaImportMode => _isEn ? 'Import mode' : 'Importa';
  String get wikipediaImportWholeArticle => _isEn ? 'Whole article' : 'Tutto l\'articolo';

  // Documenti
  String get documents => _isEn ? 'Documents' : 'Documenti';
  String get documentsHint => _isEn ? 'Open document library' : 'Apre la libreria documenti';
  String get documentLibrary => _isEn ? 'Document library' : 'Libreria documenti';
  String get addToLibrary => _isEn ? 'Add to library' : 'Aggiungi alla libreria';
  String get noDocuments => _isEn ? 'No documents. Add a file.' : 'Nessun documento. Aggiungi un file.';
  String get documentAdded => _isEn ? 'Document added' : 'Documento aggiunto';
  String get documentRemoved => _isEn ? 'Document removed' : 'Documento rimosso';
  String get removeDocument => _isEn ? 'Remove document' : 'Rimuovi documento';
  String get removePodcast => _isEn ? 'Remove podcast' : 'Rimuovi podcast';
  String get podcastRemoved => _isEn ? 'Podcast removed' : 'Podcast rimosso';
  String get documentPickerError => _isEn ? 'Error opening file' : 'Errore apertura file';
  String get readDocument => _isEn ? 'Read document' : 'Leggi documento';
  String get documentReaderTitle => _isEn ? 'Document reader' : 'Lettore documento';
  String get edit => _isEn ? 'Edit' : 'Modifica';
  String get save => _isEn ? 'Save' : 'Salva';
  String get cancel => _isEn ? 'Cancel' : 'Annulla';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'it'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
