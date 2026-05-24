import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('it')];

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
  String get homeSemanticsLabel => 'Sonarpad, schermata principale';
  String get settings => 'Impostazioni';
  String get settingsHint => 'Apre le impostazioni';
  String get info => 'Informazioni';
  String get infoHint => 'Apre le informazioni sull\'app';
  String get loading => 'Caricamento';
  String get ttsVoiceLanguage => 'Lingua voci TTS';
  String get ttsVoice => 'Voce TTS';
  String get saveSettings => 'Salva impostazioni';
  String get settingsSaved => 'Impostazioni salvate.';
  String get infoDescription =>
      'Sonarpad è un\'app con cui ascoltare le notizie, iscriversi ai podcast, ascoltare radio e usare altri strumenti di lettura e ascolto.';
  String get infoAuthor => 'Autore: Ambrogio Riili';
  String get news => 'Notizie';
  String get newsHint => 'Apre le notizie da Google News RSS';
  String get podcasts => 'Podcast';
  String get podcastsHint =>
      'Iscriviti ai podcast, riproduci o scarica episodi';
  String get importFromWikipedia => 'Importa da Wikipedia';
  String get wikipediaHint => 'Cerca un articolo Wikipedia e importa il testo';

  String get newsLanguage => 'Lingua notizie';
  String get loadingNews => 'Caricamento notizie';
  String error(Object error) => 'Errore: $error';
  String get noNewsFound => 'Nessuna notizia trovata';
  String get loadingArticle => 'Caricamento articolo';
  String get noFullArticleFound =>
      'Articolo integrale non disponibile. Mostro il riassunto del feed.';
  String get italian => 'Italiano';
  String get english => 'English';
  String get newsSource => 'Fonte notizie';

  String get article => 'Articolo';
  String get articlePreview => 'Anteprima articolo';
  String get readFullArticle => 'Leggi articolo completo';
  String get extractingReaderArticleText =>
      'Estraggo il testo in modalita lettura...';
  String get extractingVisibleArticleText =>
      'Estraggo il testo visibile dalla pagina...';
  String source(String source) => 'Fonte: $source';
  String get readyStatus => 'Pronto.';
  String get preparingEdgeTts => 'Preparo lettura Edge TTS a blocchi...';
  String get noTextToRead => 'Nessun testo da leggere.';
  String chunkCreated(int index, int total) =>
      'Blocco $index di $total creato. Lettura in corso...';
  String playingChunk(int index, int total, int size) =>
      'Riproduco blocco $index di $total ($size byte)...';
  String readingFinished(
          int readyChunks, int totalChunks, String libraryPath) =>
      'Lettura terminata. Blocchi creati: $readyChunks/$totalChunks. '
      'Libreria: $libraryPath';
  String get libraryNotSpecified => 'non indicata';
  String get readingStopped => 'Lettura interrotta.';
  String edgeTtsError(Object error) => 'Errore Edge TTS: $error';
  String audioChunksReady(int readyChunks, int totalChunks) =>
      'Blocchi audio pronti: $readyChunks / $totalChunks';
  String get readingInProgress => 'Lettura in corso...';
  String get readWithEdgeTts => 'Leggi con Edge TTS';
  String get stopReading => 'Interrompi lettura';
  String get openOriginalArticle => 'Apri articolo originale';

  String get searchPodcasts => 'Cerca podcast';
  String get podcastName => 'Nome podcast';
  String get podcastSearchHint =>
      'Esempio: tecnologia, storia, il nome del podcast...';
  String get searchCountry => 'Paese ricerca';
  String get podcastCategory => 'Categoria podcast';
  String get countryItaly => 'Italia';
  String get countryUnitedStatesEnglish => 'Stati Uniti / inglese';
  String get countryUnitedKingdom => 'Regno Unito';
  String get countrySpain => 'Spagna';
  String get countryFrance => 'Francia';
  String get searchInProgress => 'Ricerca in corso...';
  String podcastResultsFound(int count) => 'Trovati $count podcast';
  String podcastSearchError(Object error) => 'Errore ricerca podcast: $error';
  String subscribedTo(String title) => 'Iscritto a $title';
  String subscriptionError(Object error) => 'Errore iscrizione: $error';
  String podcastSubscriptionError(Object error) =>
      'Errore iscrizione podcast: $error';
  String get searchResults => 'Risultati ricerca';
  String get podcastInfo => 'Info podcast';
  String get subscribe => 'Iscriviti';
  String get podcastAuthor => 'Autore';
  String get noPodcastDescription => 'Nessuna descrizione disponibile.';
  String get loadingPodcastInfo => 'Caricamento info podcast';
  String get podcastArtwork => 'Copertina podcast';
  String get addFeedUrlManually => 'Aggiungi manualmente URL feed RSS';
  String get podcastFeedUrl => 'URL feed podcast RSS';
  String get subscribeFromUrl => 'Iscriviti da URL';
  String get subscribedPodcasts => 'Podcast iscritti';
  String get noSubscribedPodcasts =>
      'Nessun podcast iscritto. Cerca un podcast e tocca il risultato per '
      'iscriverti.';
  String get loadingEpisodes => 'Caricamento episodi';
  String get noAudioEpisodesFound => 'Nessun episodio audio trovato nel feed.';
  String get episodes => 'Episodi';
  String get episodeActions => 'Azioni episodio';
  String downloaded(String path) => 'Scaricato: $path';
  String episodeError(Object error) => 'Errore episodio: $error';
  String get play => 'Riproduci';
  String get pause => 'Pausa';
  String get stop => 'Stop';
  String get back => 'Indietro';
  String get episodePlayer => 'Player episodio';
  String get loadingEpisodeAudio => 'Caricamento audio episodio';
  String get download => 'Scarica';

  String get searchWikipedia => 'Cerca su Wikipedia';
  String get wikipediaLanguage => 'Lingua Wikipedia';
  String get search => 'Cerca';
  String get wikipediaSearch => 'Ricerca Wikipedia';
  String get wikipediaImporting => 'Importazione Wikipedia';
  String get noWikipediaResults => 'Nessun risultato Wikipedia trovato';
  String get wikipediaImportMode => 'Importa';
  String get wikipediaImportWholeArticle => 'Tutto l\'articolo';

  // Documenti
  String get documents => 'Documenti';
  String get documentsHint => 'Apre la libreria documenti';
  String get documentLibrary => 'Libreria documenti';
  String get addToLibrary => 'Aggiungi alla libreria';
  String get noDocuments => 'Nessun documento. Aggiungi un file.';
  String get documentAdded => 'Documento aggiunto';
  String get documentRemoved => 'Documento rimosso';
  String get removeDocument => 'Rimuovi documento';
  String get documentPickerError => 'Errore apertura file';
  String get readDocument => 'Leggi documento';
  String get documentReaderTitle => 'Lettore documento';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'it';

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
