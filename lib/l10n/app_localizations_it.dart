// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => '''Sonarpad''';

  @override
  String get appLanguage => '''Lingua dell'app''';

  @override
  String get settingsTheme => '''Tema app''';

  @override
  String get settingsThemeSystem => '''Sistema''';

  @override
  String get settingsThemeLight => '''Chiaro''';

  @override
  String get settingsThemeDark => '''Scuro''';

  @override
  String get settingsWeatherTemperatureUnit => '''Unità temperatura meteo''';

  @override
  String get weatherTemperatureCelsius => '''Celsius (°C)''';

  @override
  String get weatherTemperatureFahrenheit => '''Fahrenheit (°F)''';


  @override
  String get homeSemanticsLabel => '''Sonarpad, schermata principale''';

  @override
  String get settings => '''Impostazioni''';

  @override
  String get settingsHint => '''Apre le impostazioni''';

  @override
  String get info => '''Informazioni''';

  @override
  String get infoHint => '''Apre le informazioni sull'app''';

  @override
  String get categoryReading => '''Lettura e documenti''';

  @override
  String get categoryMedia => '''Media e intrattenimento''';

  @override
  String get categoryUtilities => '''Ricerche e utilità''';

  @override
  String get voiceDictionaryTitle => '''Dizionario vocale''';

  @override
  String get voiceDictionaryAdd => '''Aggiungi voci al dizionario''';

  @override
  String get voiceDictionaryOriginalWord => '''Parola originale''';

  @override
  String get voiceDictionaryReplacementWord => '''Parola sostitutiva''';

  @override
  String get voiceDictionaryMatchCase => '''Distingui maiuscole e minuscole''';

  @override
  String get voiceDictionaryIgnoreCase => '''Ignora maiuscole e minuscole''';

  @override
  String get voiceDictionaryEntries => '''Voci del dizionario''';

  @override
  String get voiceDictionaryEmpty => '''Nessuna voce nel dizionario.''';

  @override
  String get voiceDictionaryRemove => '''Rimuovi voce selezionata''';

  @override
  String get voiceDictionaryOriginalRequired => '''Inserisci la parola originale.''';

  @override
  String get convertMediaTitle => '''Converti media''';

  @override
  String get convertMediaInput => '''File da convertire''';

  @override
  String get convertMediaOutput => '''Cartella di salvataggio''';

  @override
  String get convertMediaImage => '''Immagine''';

  @override
  String get convertMediaBrowse => '''Sfoglia...''';

  @override
  String get convertMediaFormat => '''Formato''';

  @override
  String get convertMediaBitrate => '''Bitrate (kbps)''';

  @override
  String get convertMediaOggQuality => '''Qualità (q)''';

  @override
  String get convertMediaFlacCompression => '''Livello di compressione''';

  @override
  String get convertMediaWavBitDepth => '''Profondità bit WAV''';

  @override
  String get convertMediaReady => '''Pronto.''';

  @override
  String get convertMediaRunning => '''Conversione in corso...''';

  @override
  String get convertMediaDone => '''Conversione completata.''';

  @override
  String get convertMediaButton => '''Converti''';

  @override
  String get convertMediaNoInput => '''Seleziona un file da convertire.''';

  @override
  String get convertMediaNoOutput => '''Scegli una cartella di salvataggio.''';

  @override
  String get convertMediaOutputNotWritable => '''La cartella scelta non è accessibile direttamente. Il file verrà salvato nella cartella interna di Sonarpad; al termine potrai condividerlo o salvarlo nell’app File.''';

  @override
  String get convertMediaNoImage => '''Seleziona un'immagine per il video.''';

  @override
  String get convertMediaSamePath => '''Il file convertito deve essere diverso dal file sorgente.''';

  @override
  String get convertMediaInvalidBitrate => '''Bitrate non valido. Inserisci un valore tra 64 e 320 kbps.''';

  @override
  String convertMediaFailed(Object error) {
    return '''Conversione non riuscita: ${error}''';
  }

  @override
  String get donations => '''Donazioni''';

  @override
  String get donationsHint => '''Sostieni lo sviluppo di Sonarpad''';

  @override
  String get loading => '''Caricamento''';

  @override
  String get ttsVoiceLanguage => '''Lingua della voce TTS''';

  @override
  String get ttsVoice => '''Voce TTS''';

  @override
  String get saveSettings => '''Salva impostazioni''';

  @override
  String get settingsSaved => '''Impostazioni salvate.''';

  @override
  String get settingsSavedTitle => '''Impostazioni salvate''';

  @override
  String get sonarpadCodeValidTitle => '''Codice valido''';

  @override
  String get sonarpadCodeValidMessage => '''Il codice Sonarpad è corretto. Impostazioni salvate.''';

  @override
  String get sonarpadCodeInvalidTitle => '''Codice non valido''';

  @override
  String get sonarpadCodeInvalidMessage => '''Il codice Sonarpad inserito non è valido. Verifica di averlo copiato senza spazi aggiuntivi.''';

  @override
  String get infoDescription => '''Sonarpad è un’app semplice, ma ricca di funzioni. È pensata per essere accessibile con VoiceOver alle persone non vedenti e ipovedenti: permette di ascoltare le notizie, cercare podcast e iscriversi, importare articoli da Wikipedia, aggiungere documenti alla libreria, salvarli e modificarli. Sonarpad è in continuo aggiornamento e ogni funzione è progettata per rendere più semplice la vita quotidiana.''';

  @override
  String get infoAuthor => '''Autore: Ambrogio Riili''';

  @override
  String get donationsIntro => '''Sonarpad è nato inizialmente per rispondere a esigenze personali, ma nel tempo è diventato un’app più completa. Il suo sviluppo richiede un lavoro costante: migliorare le funzionalità, correggere bug, cercare nuove idee e testare con attenzione ogni funzione.

Se Sonarpad ti è utile e vuoi sostenerne lo sviluppo, puoi effettuare una donazione.''';

  @override
  String get donationsPaypalDesc => '''Puoi donare tramite PayPal al seguente link:
https://www.paypal.me/ambrogio86
Se possibile, indica come causale “Sonarpad”.''';

  @override
  String get donationsBankDesc => '''È possibile contribuire anche tramite bonifico bancario sul conto intestato a Ambrogio Riili.
IBAN: IT77W0306901020100000064149
Se possibile, indica una causale chiara, ad esempio “Sonarpad”.''';

  @override
  String get donationsThanks => '''Chiunque decida di sostenere il progetto verrà ringraziato nell’app e nel repository GitHub, nella sezione sostenitori, salvo richiesta di anonimato o utilizzo di un nickname.

Ringrazio Jiri Holzinger e Paola Vagata per il loro contributo.
Per la traduzione in ceco ringrazio Radek Žalud e Jiri Holzinger.
Per la traduzione in spagnolo ringrazio Arturo Fernandez Rivas.''';

  @override
  String get news => '''Notizie''';

  @override
  String get newsHint => '''Apre le notizie da Google News RSS''';

  @override
  String get podcasts => '''Podcast''';

  @override
  String get podcastsHint => '''Iscriviti ai podcast, riproduci o scarica episodi''';

  @override
  String get importFromWikipedia => '''Wikipedia''';

  @override
  String get wikipediaHint => '''Cerca un articolo Wikipedia e importa il testo''';

  @override
  String get newsCategoryTop => '''Principali''';

  @override
  String get settingsHomeGrouping => '''Attiva il raggruppamento delle icone in categorie''';

  @override
  String get settingsHomeGroupingHint => '''Se disattivato, le icone principali saranno mostrate come elenco singolo senza sottocartelle''';

  @override
  String get newsCategoryMyCity => '''La mia città''';

  @override
  String get newsLocalCityLabel => '''Inserisci la tua città''';

  @override
  String get newsLocalCityHint => '''Correggi la città usata per le notizie locali''';

  @override
  String get update => '''Aggiorna''';

  @override
  String get moveUp => '''Sposta in alto''';

  @override
  String get moveDown => '''Sposta in basso''';

  @override
  String get hide => '''Elimina''';

  @override
  String get moveToPosition => '''Sposta alla posizione''';

  @override
  String positionLabel(int position, String targetName) {
    return '''Posizione ${position}: prima di ${targetName}''';
  }

  @override
  String get positionLabelLast => '''Ultima posizione''';

  @override
  String get restoreHiddenSources => '''Ripristina testate eliminate''';

  @override
  String get addCustomNewsSource => '''Aggiungi sorgente RSS personalizzata''';

  @override
  String get newsSourceName => '''Nome testata/sito''';

  @override
  String get newsSourceUrlOrSearch => '''URL sito, feed RSS o parola di ricerca''';

  @override
  String get deleteNewsSource => '''Elimina sorgente''';

  @override
  String get importRssSourcesFromOpml => '''Importa sorgenti RSS da OPML''';

  @override
  String get exportRssSourcesToOpml => '''Esporta sorgenti RSS in OPML''';

  @override
  String rssImportComplete(int count) {
    return '''Sorgenti RSS importate: ${count}''';
  }

  @override
  String rssImportError(Object error) {
    return '''Errore importazione RSS: ${error}''';
  }

  @override
  String get rssExportComplete => '''Sorgenti RSS esportate''';

  @override
  String rssExportError(Object error) {
    return '''Errore esportazione RSS: ${error}''';
  }

  @override
  String get deleteItem => '''Elimina''';

  @override
  String get articleTextSemantics => '''Testo articolo''';

  @override
  String get newsLanguage => '''Lingua notizie''';

  @override
  String get loadingNews => '''Caricamento notizie''';

  @override
  String error(Object error) {
    return '''Errore: ${error}''';
  }

  @override
  String get noNewsFound => '''Nessuna notizia trovata''';

  @override
  String get loadingArticle => '''Caricamento articolo''';

  @override
  String get noFullArticleFound => '''Articolo integrale non disponibile. Mostro il riassunto del feed.''';

  @override
  String get italian => '''Italiano''';

  @override
  String get english => '''Inglese''';

  @override
  String get french => '''Francese''';

  @override
  String get spanish => '''Spagnolo''';

  @override
  String get newsSource => '''Fonte notizie''';

  @override
  String get article => '''Articolo''';

  @override
  String get articlePreview => '''Anteprima articolo''';

  @override
  String get readFullArticle => '''Leggi articolo completo''';

  @override
  String get extractingReaderArticleText => '''Estraggo il testo in modalità lettura...''';

  @override
  String get extractingVisibleArticleText => '''Estraggo il testo visibile dalla pagina...''';

  @override
  String source(String source) {
    return '''Fonte: ${source}''';
  }

  @override
  String get readyStatus => '''Pronto.''';

  @override
  String get preparingEdgeTts => '''Preparo lettura Edge TTS a blocchi...''';

  @override
  String get noTextToRead => '''Nessun testo da leggere.''';

  @override
  String chunkCreated(int index, int total) {
    return '''Blocco ${index} di ${total} creato. Lettura in corso...''';
  }

  @override
  String playingChunk(int index, int total, int size) {
    return '''Riproduco blocco ${index} di ${total} (${size} byte)...''';
  }

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) {
    return '''Lettura terminata. Blocchi creati: ${readyChunks}/${totalChunks}. Libreria: ${libraryPath}''';
  }

  @override
  String get libraryNotSpecified => '''non indicata''';

  @override
  String get readingStopped => '''Lettura interrotta.''';

  @override
  String edgeTtsError(Object error) {
    return '''Errore Edge TTS: ${error}''';
  }

  @override
  String audioChunksReady(int readyChunks, int totalChunks) {
    return '''Blocchi audio pronti: ${readyChunks} / ${totalChunks}''';
  }

  @override
  String get readingInProgress => '''Lettura in corso...''';

  @override
  String get readWithEdgeTts => '''Avvia lettura''';

  @override
  String get stopReading => '''Interrompi lettura''';

  @override
  String get startReading => '''Avvia lettura''';

  @override
  String get resumeReading => '''Riprendi lettura''';

  @override
  String get pauseReading => '''Pausa lettura''';

  @override
  String get openOriginalArticle => '''Apri articolo originale''';

  @override
  String get searchPodcasts => '''Cerca podcast''';

  @override
  String get podcastName => '''Nome podcast''';

  @override
  String get podcastSearchHint => '''Esempio: tecnologia, storia, il nome del podcast...''';

  @override
  String get searchCountry => '''Paese di ricerca''';

  @override
  String get browsePodcastCountries => '''Sfoglia per nazione''';

  @override
  String get podcastCountries => '''Nazioni podcast''';

  @override
  String get podcastCategory => '''Categoria podcast''';

  @override
  String get browsePodcastCategories => '''Sfoglia categorie''';

  @override
  String get selectedPodcastCategory => '''Categoria selezionata''';

  @override
  String get selectedRecently => '''scelta recente''';

  @override
  String get podcastCategories => '''Categorie podcast''';

  @override
  String get countryItaly => '''Italia''';

  @override
  String get countryUnitedStatesEnglish => '''Stati Uniti / inglese''';

  @override
  String get countryUnitedKingdom => '''Regno Unito''';

  @override
  String get countrySpain => '''Spagna''';

  @override
  String get countryFrance => '''Francia''';

  @override
  String get searchInProgress => '''Ricerca in corso...''';

  @override
  String get newsReadArticles => '''Articoli letti''';

  @override
  String get weatherRecentCities => '''Città recenti''';

  @override
  String podcastResultsFound(int count) {
    return '''Trovati ${count} podcast''';
  }

  @override
  String podcastSearchError(Object error) {
    return '''Errore ricerca podcast: ${error}''';
  }

  @override
  String subscribedTo(String title) {
    return '''Iscritto a ${title}''';
  }

  @override
  String subscriptionError(Object error) {
    return '''Errore iscrizione: ${error}''';
  }

  @override
  String podcastSubscriptionError(Object error) {
    return '''Errore iscrizione podcast: ${error}''';
  }

  @override
  String get searchResults => '''Risultati ricerca''';

  @override
  String get podcastInfo => '''Informazioni sul podcast''';

  @override
  String get subscribe => '''Iscriviti''';

  @override
  String get openPodcast => '''Apri podcast''';

  @override
  String get viewEpisodes => '''Vedi episodi''';

  @override
  String get podcastAuthor => '''Autore''';

  @override
  String get noPodcastDescription => '''Nessuna descrizione disponibile.''';

  @override
  String get noPodcastResults => '''Nessun podcast trovato.''';

  @override
  String get loadingPodcastInfo => '''Caricamento info podcast''';

  @override
  String get podcastArtwork => '''Copertina podcast''';

  @override
  String get addFeedUrlManually => '''Aggiungi manualmente URL feed RSS''';

  @override
  String get podcastFeedUrl => '''URL feed podcast RSS''';

  @override
  String get subscribeFromUrl => '''Iscriviti da URL''';

  @override
  String get subscribedPodcasts => '''Podcast sottoscritti''';

  @override
  String get noSubscribedPodcasts => '''Nessun podcast sottoscritto. Cerca un podcast e tocca un risultato per iscriverti.''';

  @override
  String get localAudioFiles => '''File audio locali''';

  @override
  String get noLocalAudioFiles => '''Nessun file audio locale trovato.''';

  @override
  String get importAudioFromITunes => '''Importa audio da iTunes / Apple Devices''';

  @override
  String localAudioFilesFound(int count) {
    return '''File audio locali trovati: ${count}''';
  }

  @override
  String get importPodcastsFromFile => '''Importa podcast da file''';

  @override
  String get exportPodcastsToFile => '''Esporta podcast in file OPML''';

  @override
  String podcastImportComplete(int count) {
    return '''Podcast importati: ${count}''';
  }

  @override
  String podcastImportError(Object error) {
    return '''Errore importazione podcast: ${error}''';
  }

  @override
  String get podcastInvalidOpmlFile => '''File non valido. Seleziona un file OPML o XML.''';

  @override
  String get podcastExportComplete => '''Podcast esportati''';

  @override
  String podcastExportError(Object error) {
    return '''Errore esportazione podcast: ${error}''';
  }

  @override
  String get loadingEpisodes => '''Caricamento episodi''';

  @override
  String get noAudioEpisodesFound => '''Nessun episodio audio trovato nel feed.''';

  @override
  String get episodes => '''Episodi''';

  @override
  String get episodeActions => '''Azioni episodio''';

  @override
  String downloaded(String path) {
    return '''Scaricato: ${path}''';
  }

  @override
  String episodeError(Object error) {
    return '''Errore episodio: ${error}''';
  }

  @override
  String get play => '''Riproduci''';

  @override
  String get pause => '''Pausa''';

  @override
  String get rewind15s => '''Indietro 15s''';

  @override
  String get forward15s => '''Avanti 15s''';

  @override
  String get stop => '''Stop''';

  @override
  String get back => '''Indietro''';

  @override
  String get episodePlayer => '''Lettore episodio''';

  @override
  String nowPlayingTitle(String title) {
    return '''In riproduzione: ${title}''';
  }

  @override
  String get loadingEpisodeAudio => '''Caricamento audio episodio''';

  @override
  String get playbackPosition => '''Posizione''';

  @override
  String playbackPositionValue(String position, String duration) {
    return '''${position} di ${duration}''';
  }

  @override
  String get adjustVolume => '''Regola il volume''';

  @override
  String volumeValue(int percentage) {
    return '''Volume: ${percentage}%''';
  }

  @override
  String get download => '''Scarica''';

  @override
  String get searchWikipedia => '''Cerca su Wikipedia''';

  @override
  String get wikipediaLanguage => '''Lingua Wikipedia''';

  @override
  String get search => '''Cerca''';

  @override
  String get wikipediaSearch => '''Ricerca Wikipedia''';

  @override
  String get wikipediaImporting => '''Importazione Wikipedia''';

  @override
  String get noWikipediaResults => '''Nessun risultato Wikipedia trovato''';

  @override
  String get wikipediaImportMode => '''Modalità di importazione''';

  @override
  String get wikipediaImportWholeArticle => '''Tutto l'articolo''';

  @override
  String get documents => '''Documenti''';

  @override
  String get documentsHint => '''Apre la libreria documenti''';

  @override
  String get documentLibrary => '''Libreria documenti''';

  @override
  String get addToLibrary => '''Aggiungi alla libreria''';

  @override
  String get documentImportSelectionMode => '''Vuoi selezionare un solo documento o più documenti?''';

  @override
  String get documentImportSingle => '''Un documento''';

  @override
  String get documentImportMultiple => '''Più documenti''';

  @override
  String get noDocuments => '''Nessun documento. Aggiungi un file.''';

  @override
  String get noDocumentsInLibrary => '''Nessun documento presente nella libreria.''';

  @override
  String get documentAdded => '''Documento aggiunto''';

  @override
  String get documentsAdded => '''Documenti aggiunti''';

  @override
  String get importDocumentsFromITunes => '''Importa documenti da iTunes / Apple Devices''';

  @override
  String sharedDocumentsImportComplete(int count) {
    return '''Documenti importati da iTunes / Apple Devices: ${count}''';
  }

  @override
  String libraryLoadError(Object error) {
    return '''Errore caricamento libreria: ${error}''';
  }

  @override
  String fileOpenError(Object error) {
    return '''Errore apertura file: ${error}''';
  }

  @override
  String get filePathUnavailable => '''Percorso file non disponibile.''';

  @override
  String fileInaccessible(String name) {
    return '''File inaccessibile: ${name}''';
  }

  @override
  String documentAddError(Object error) {
    return '''Errore aggiunta documento: ${error}''';
  }

  @override
  String documentRemoveError(Object error) {
    return '''Errore rimozione: ${error}''';
  }

  @override
  String get noExportableTextFound => '''Nessun testo esportabile trovato.''';

  @override
  String get modifiedDocumentNoExportableText => '''Il documento modificato non contiene testo esportabile.''';

  @override
  String get documentRemoved => '''Documento rimosso''';

  @override
  String get folderRemoved => '''Cartella rimossa''';

  @override
  String get removeFolder => '''Rimuovi cartella''';

  @override
  String get removeDocument => '''Rimuovi documento''';

  @override
  String get writeNewDocument => '''Scrivi nuovo documento''';

  @override
  String get addDocumentToLibraryHint => '''Aggiungi documento alla libreria. Sfoglia i file del dispositivo e aggiungili.''';

  @override
  String get documentTypeLabel => '''Documento''';

  @override
  String get documentPosition => '''Posizione documento''';

  @override
  String get folderTypeLabel => '''Cartella''';

  @override
  String documentAddedOn(String date) {
    return '''aggiunto il ${date}''';
  }

  @override
  String documentTypeDescription(String extension) {
    return '''tipo ${extension}''';
  }

  @override
  String get openFolderHint => '''Tocca due volte per aprire la cartella''';

  @override
  String get openDocumentHint => '''Tocca due volte per aprire e leggere il documento''';

  @override
  String removeItem(String name) {
    return '''Rimuovi ${name}''';
  }

  @override
  String get removePodcast => '''Rimuovi podcast''';

  @override
  String get podcastRemoved => '''Podcast rimosso''';

  @override
  String get documentPickerError => '''Errore apertura file''';

  @override
  String get readDocument => '''Leggi documento''';

  @override
  String get documentReaderTitle => '''Lettore documento''';

  @override
  String get documentReaderEditHint => '''Tocca un paragrafo per modificarlo. Scorri verso l’alto o verso il basso per aggiungere un segnalibro.''';

  @override
  String get documentBookmarkHintSet => '''Scorri verso l’alto o verso il basso per impostare un segnalibro.''';

  @override
  String get documentEditParagraphActionHint => '''Tocca due volte per modificare questo paragrafo. ''';

  @override
  String get documentBookmarkHintReplace => '''Scorri verso l’alto o verso il basso per rimuovere il segnalibro esistente o sostituirlo con questo paragrafo.''';

  @override
  String get documentSetBookmarkAction => '''Aggiungi nuovo segnalibro''';

  @override
  String get documentRemoveBookmarkAction => '''Rimuovi segnalibro''';

  @override
  String get documentReplaceBookmarkAction => '''Rimuovi e aggiungi un nuovo segnalibro''';

  @override
  String get searchInDocument => '''Cerca nel documento''';

  @override
  String get documentSearchFieldLabel => '''Testo da cercare''';

  @override
  String get documentSearchFieldHint => '''Parola o frase da trovare''';

  @override
  String get documentSearchEmptyQuery => '''Inserisci il testo da cercare.''';

  @override
  String get documentSearchResultsTitle => '''Risultati ricerca nel documento''';

  @override
  String noDocumentSearchResults(String query) {
    return '''Nessun risultato trovato per ${query}.''';
  }

  @override
  String documentSearchResultParagraph(int number) {
    return '''Paragrafo ${number}''';
  }

  @override
  String get edit => '''Modifica''';

  @override
  String get save => '''Salva''';

  @override
  String get cancel => '''Annulla''';

  @override
  String get settingsReadingEngine => '''Motore di lettura''';

  @override
  String get settingsEdgeTtsQuality => '''Edge TTS (Alta qualità online)''';

  @override
  String get settingsSystemVoices => '''Voci di sistema (VoiceOver / Google)''';

  @override
  String get settingsNoSystemVoices => '''Nessuna voce di sistema disponibile.''';

  @override
  String get settingsDefaultVoiceHint => '''Voce predefinita''';

  @override
  String get settingsDefaultVoice => '''Predefinita''';

  @override
  String get settingsVoiceSpeed => '''Velocità lettura: ''';

  @override
  String get settingsVoicePitch => '''Tono: ''';

  @override
  String get settingsVoiceSpeedLabel => '''Velocità lettura''';

  @override
  String get settingsVoicePitchLabel => '''Tono''';

  @override
  String get settingsTestVoice => '''Testa voce''';

  @override
  String get settingsTestingVoice => '''Riproduzione in corso...''';

  @override
  String get settingsVoiceTestText => '''Questo è un test della voce selezionata.''';

  @override
  String settingsVoiceTestError(Object error) {
    return '''Errore test voce: ${error}''';
  }

  @override
  String settingsVoiceSaveError(Object error) {
    return '''Errore salvataggio voce TTS: ${error}''';
  }

  @override
  String get settingsUnsavedTitle => '''Modifiche non salvate''';

  @override
  String get settingsUnsavedMessage => '''Vuoi salvare le modifiche prima di uscire dalle impostazioni?''';

  @override
  String get settingsExitWithoutSaving => '''Esci senza salvare''';

  @override
  String get settingsSystemLanguage => '''Lingua di sistema''';

  @override
  String get settingsSystemVoice => '''Voce di sistema''';

  @override
  String get settingsAutoBookmark => '''Segnalibro automatico''';

  @override
  String get settingsAutoBookmarkHint => '''Riprendi documenti, podcast, RaiPlay e audiodescrizioni dal punto interrotto.''';

  @override
  String get settingsSeekStep => '''Intervallo indietro / avanti nei media''';

  @override
  String get aiChatIntro => '''Sono l’intelligenza artificiale di Sonarpad. Come posso aiutarti?''';

  @override
  String get meteoTitle => '''Meteo''';

  @override
  String get weatherCity => '''Città''';

  @override
  String get weatherCityHint => '''Esempio: Roma''';

  @override
  String get weatherCityNotFound => '''Città non trovata''';

  @override
  String get weatherSearchError => '''Errore durante la ricerca''';

  @override
  String get weatherToday => '''Oggi''';

  @override
  String get weatherCurrentSituation => '''Situazione attuale''';

  @override
  String get weatherTomorrow => '''Domani''';

  @override
  String get weatherChooseDay => '''Scegli il giorno''';

  @override
  String get weatherCurrentTemperature => '''Temperatura attuale''';

  @override
  String get weatherMaxTemperature => '''Temperatura massima''';

  @override
  String get weatherMinTemperature => '''Temperatura minima''';

  @override
  String get weatherPrecipitation => '''Precipitazioni''';

  @override
  String get weatherPrecipitationProbability => '''Probabilità di precipitazioni''';

  @override
  String get weatherWind => '''Vento''';

  @override
  String get weatherRelativeHumidity => '''Umidità relativa''';

  @override
  String get settingsSecretCode => '''Codice Sonarpad per funzioni aggiuntive''';

  @override
  String get settingsRequestCode => '''Richiedi codice all'autore''';

  @override
  String get settingsPasteCode => '''Incolla codice''';

  @override
  String get settingsCancel => '''Annulla''';

  @override
  String get settingsSend => '''Invia''';

  @override
  String get settingsFillFieldsCode => '''Compila tutti i campi per richiedere il codice.''';

  @override
  String get settingsName => '''Nome''';

  @override
  String get settingsSurname => '''Cognome''';

  @override
  String get settingsEmail => '''Email''';

  @override
  String get settingsOperatingSystem => '''Sistema operativo''';

  @override
  String settingsCodeRequestBody(String name, String surname, String email, String os) {
    return '''Nome: ${name}; Cognome: ${surname}; Email: ${email}; Sistema operativo: ${os}''';
  }

  @override
  String get settingsNameOptional => '''Nome (opzionale)''';

  @override
  String get settingsMessageOptional => '''Messaggio (opzionale)''';

  @override
  String get settingsVerifyCodeAndSave => '''Verifica codice e salvataggio...''';

  @override
  String get settingsViewSysLog => '''Visualizza log di sistema''';

  @override
  String settingsMailOpenError(Object error) {
    return '''Errore apertura mail: ${error}''';
  }

  @override
  String get ok => '''OK''';

  @override
  String get invia => '''Invia''';

  @override
  String get saveArticle => '''Salva l'articolo''';

  @override
  String get shareArticle => '''Condividi l'articolo''';

  @override
  String get articleSavedSuccess => '''Articolo salvato nei Documenti''';

  @override
  String get annulla => '''Annulla''';

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice => '''Compila tutti i campi per richiedere il codice.''';

  @override
  String get selectFolder => '''Seleziona cartella''';

  @override
  String get exportDocument => '''Esporta documento''';

  @override
  String get exportFormatPrompt => '''In quale formato desideri esportare il documento?''';

  @override
  String get textFormat => '''Testo (.txt)''';

  @override
  String get pdfFormat => '''PDF (.pdf)''';

  @override
  String get docxFormat => '''DOCX (.docx)''';

  @override
  String get epubFormat => '''EPUB (.epub)''';

  @override
  String get audiobookMp3Format => '''Audiolibro MP3 (.mp3)''';

  @override
  String get audiobookM4bFormat => '''Audiolibro M4B (.m4b)''';

  @override
  String get exportCompleteTitle => '''Esportazione completata''';

  @override
  String get exportCompleteMessage => '''Il file è stato creato correttamente. Vuoi salvarlo in Sonarpad o condividerlo?''';

  @override
  String get saveInSonarpad => '''Salva in Sonarpad''';

  @override
  String get exportSavedInSonarpad => '''File salvato nei Documenti di Sonarpad.''';


  @override
  String get audiobookExportProgressTitle => '''Creazione audiolibro''';

  @override
  String get audiobookExportPreparing => '''Preparazione dell’audiolibro...''';

  @override
  String get audiobookExportGeneratingAudio => '''Generazione audio''';

  @override
  String get audiobookExportConvertingAudio => '''Conversione finale del file audio...''';

  @override
  String get audiobookExportFinalizing => '''Finalizzazione...''';


  @override
  String get exportError => '''Errore esportazione''';

  @override
  String get newFolder => '''Nuova cartella''';

  @override
  String get folderNameHint => '''Nome cartella''';

  @override
  String get create => '''Crea''';

  @override
  String get createNewFolder => '''Crea nuova cartella''';

  @override
  String get importExternalSources => '''Importa da fonti esterne''';

  @override
  String get importExternalSourcesTitle => '''Fonti esterne''';

  @override
  String get importFromDropbox => '''Importa documenti da Dropbox''';

  @override
  String get importFromProjectGutenberg => '''Importa da Project Gutenberg''';

  @override
  String get projectGutenbergImportUnavailable => '''L'importazione da Project Gutenberg non è ancora disponibile.''';

  @override
  String get importFromInternetArchive => '''Importa da Internet Archive''';

  @override
  String get internetArchiveTitle => '''Internet Archive''';

  @override
  String get internetArchiveSearchLabel => '''Cerca audio''';

  @override
  String get internetArchiveSourceLabel => '''Fonte''';

  @override
  String get internetArchiveOldTimeRadio => '''Old Time Radio''';

  @override
  String get internetArchiveSpeeches => '''Discorsi storici''';

  @override
  String get internetArchiveLiveMusic => '''Live Music Archive''';

  @override
  String get internetArchiveNoItemsFound => '''Nessun elemento audio trovato.''';

  @override
  String get saveAudioInDocuments => '''Salva audio nei Documenti''';

  @override
  String get audioSavedInDocuments => '''Audio salvato nei Documenti.''';

  @override
  String get noAudioTracksAvailable => '''Nessuna traccia audio disponibile.''';

  @override
  String get importFromLibriVox => '''Importa da LibriVox''';

  @override
  String get gutenbergSearchLabel => '''Cerca libro o autore''';

  @override
  String get sourceLanguageLabel => '''Lingua''';

  @override
  String get noGutenbergBooksFound => '''Nessun libro trovato.''';

  @override
  String get loadMore => '''Carica altri''';

  @override
  String sourceLanguageValue(String language) {
    return '''Lingua: ${language}''';
  }

  @override
  String get gutenbergImportAndRead => '''Importa e leggi''';

  @override
  String get gutenbergImporting => '''Importazione...''';

  @override
  String get librivoxSearchLabel => '''Cerca audiolibro''';

  @override
  String get noLibrivoxAudiobooksFound => '''Nessun audiolibro trovato.''';

  @override
  String get librivoxAudiobookSaved => '''Audiolibro salvato nei Documenti.''';

  @override
  String get librivoxSaveAudiobook => '''Salva audiolibro nei Documenti''';

  @override
  String get librivoxSaving => '''Salvataggio...''';

  @override
  String get librivoxNoAudioTracks => '''Nessuna traccia audio disponibile.''';

  @override
  String get librivoxNotTextExportable => '''Gli audiolibri LibriVox non sono esportabili come testo.''';

  @override
  String sourceDurationValue(String duration) {
    return '''Durata: ${duration}''';
  }

  @override
  String get importFromPoetryDb => '''Importa da PoetryDB''';

  @override
  String get poetryDbSearchLabel => '''Cerca poesia''';

  @override
  String get poetryDbSearchBy => '''Cerca per''';

  @override
  String get poetryDbSearchByTitle => '''Titolo''';

  @override
  String get poetryDbSearchByAuthor => '''Autore''';

  @override
  String get poetryDbNoPoemsFound => '''Nessuna poesia trovata.''';

  @override
  String poetryDbLineCount(int count) {
    return '''${count} versi''';
  }

  @override
  String get moveDocument => '''Sposta documento''';

  @override
  String get documentMoved => '''Spostato correttamente''';

  @override
  String get outOfFolder => '''Fuori dalla cartella''';

  @override
  String get moveToAnotherFolder => '''Sposta in un'altra cartella...''';

  @override
  String get ttsError => '''Errore sintesi vocale''';

  @override
  String get editParagraph => '''Modifica paragrafo''';

  @override
  String get editParagraphTextField => '''Campo di testo per la modifica del paragrafo''';

  @override
  String get editParagraphHint => '''Modifica il testo del paragrafo''';

  @override
  String get applyAndSave => '''Applica e salva''';

  @override
  String get textEditedAndSaved => '''Testo modificato e salvato nel documento corrente.''';

  @override
  String get saveError => '''Errore durante il salvataggio''';

  @override
  String get docSavedInLibrary => '''Documento salvato nella libreria''';

  @override
  String get saveInLibrary => '''Salva nella libreria''';

  @override
  String get documentTextLabel => '''Testo documento''';

  @override
  String get modifiedInSonarpad => '''Modificato in Sonarpad''';

  @override
  String get noTextAvailableForDocument => '''Nessun testo disponibile per questo documento.''';

  @override
  String bookmarkSet(int index) {
    return '''Segnalibro impostato al paragrafo ${index}.''';
  }

  @override
  String get bookmarkRemoved => '''Segnalibro rimosso.''';

  @override
  String get docEmpty => '''Il documento è vuoto''';

  @override
  String get docSavedSuccessfully => '''Documento salvato correttamente.''';

  @override
  String get writeDocument => '''Scrivi documento''';

  @override
  String get documentTitleOptional => '''Titolo (opzionale)''';

  @override
  String get documentTitleHint => '''Esempio: lista della spesa''';

  @override
  String get documentTextField => '''Testo del documento''';

  @override
  String get documentTextHint => '''Inizia a scrivere qui...''';

  @override
  String get newDocumentDefaultName => '''Nuovo_Documento''';

  @override
  String get saving => '''Salvataggio...''';

  @override
  String get saveDocument => '''Salva documento''';

  @override
  String get addRssSource => '''Aggiungi sorgente RSS''';

  @override
  String get add => '''Aggiungi''';

  @override
  String get errorPrefix => '''Errore''';

  @override
  String versionBuild(String version, String buildNumber) {
    return '''Versione ${version} (Build ${buildNumber})''';
  }

  @override
  String get whatIsNew => '''Novità''';

  @override
  String whatIsNewInVersion(String version) {
    return '''Novità della versione ${version}''';
  }

  @override
  String changelogLoadError(Object error) {
    return '''Errore caricamento novità: ${error}''';
  }

  @override
  String get visitSonarpadSite => '''Visita il sito di Sonarpad''';

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return '''Visita il sito di Sonarpad: ${url}''';
  }

  @override
  String get nowPlaying => '''In riproduzione''';

  @override
  String get fileImported => '''File importato''';

  @override
  String importZipError(Object error) {
    return '''Errore importazione zip: ${error}''';
  }

  @override
  String get dropboxLoginPrompt => '''Accedi a Dropbox per importare i tuoi documenti.''';

  @override
  String get loginToDropbox => '''Accedi a Dropbox''';

  @override
  String get logoutFromDropbox => '''Disconnetti''';

  @override
  String get dropboxLoginFailed => '''Accesso fallito o annullato''';

  @override
  String dropboxLoadFolderError(Object error) {
    return '''Errore caricamento cartella: ${error}''';
  }

  @override
  String dropboxImportError(Object error) {
    return '''Errore importazione: ${error}''';
  }

  @override
  String get retry => '''Riprova''';

  @override
  String get goBack => '''.. Torna indietro''';

  @override
  String get noSupportedFilesInFolder => '''Nessun file supportato in questa cartella.''';

  @override
  String get articleNotFound => '''Articolo non trovato.''';

  @override
  String get errorOpening => '''Errore durante l'apertura''';

  @override
  String get recentArticles => '''Articoli recenti''';

  @override
  String get clearHistory => '''Cancella cronologia''';

  @override
  String get confirmClearHistory => '''Vuoi davvero cancellare tutte le ricerche recenti?''';

  @override
  String get clear => '''Cancella''';

  @override
  String get noRecentSearches => '''Nessuna ricerca recente.''';

  @override
  String get logCopiedToClipboard => '''Log copiato negli appunti''';

  @override
  String get systemLog => '''Log di sistema''';

  @override
  String get clearSystemLog => '''Svuota log''';

  @override
  String get copySystemLog => '''Copia log''';

  @override
  String get donateWithPaypal => '''Dona con PayPal''';

  @override
  String get bankTransferTitle => '''Bonifico bancario''';

  @override
  String get enableVideo => '''Attiva video''';

  @override
  String get calendar => '''Calendario''';

  @override
  String get calendarHint => '''Apri il calendario con santi, festività e promemoria''';

  @override
  String get saintOfTheDay => '''Santo del giorno''';

  @override
  String get quoteOfTheDay => '''Citazione del giorno''';

  @override
  String get reminders => '''Promemoria''';

  @override
  String get addReminder => '''Aggiungi promemoria''';

  @override
  String get removeReminder => '''Rimuovi promemoria''';

  @override
  String get noReminders => '''Nessun promemoria''';

  @override
  String get writeReminder => '''Scrivi qui il tuo promemoria...''';

  @override
  String get saveReminder => '''Salva''';

  @override
  String get cancelReminder => '''Annulla''';

  @override
  String get backToToday => '''Torna a oggi''';

  @override
  String get calendarToday => '''Oggi''';

  @override
  String get calendarTomorrow => '''Domani''';

  @override
  String get calendarYesterday => '''Ieri''';

  @override
  String get share => '''Condividi''';

  @override
  String get shareCalendarDayOptions => '''Opzioni di condivisione''';

  @override
  String get shareCalendarDayOnly => '''Condividi solo il giorno''';

  @override
  String get shareCalendarDayWithReminder => '''Condividi giorno e promemoria''';

  @override
  String get listenToAll => '''Ascolta tutto''';

  @override
  String reminderSaved(int count) {
    return '''${count} promemoria''';
  }

  @override
  String get audiodescriptionTitle => '''Audiodescrizioni Rai''';

  @override
  String get audiodescriptionRecent => '''Recenti''';

  @override
  String get audiodescriptionAll => '''Tutte le audiodescrizioni''';



  @override
  String get audiodescriptionFilm => '''Film''';

  @override
  String get audiodescriptionSearch => '''Cerca...''';

  @override
  String get audiodescriptionLoading => '''Caricamento in corso...''';

  @override
  String get audiodescriptionError => '''Errore nel caricamento del catalogo''';

  @override
  String get audiodescriptionEmpty => '''Nessun elemento trovato''';

  @override
  String get radio => '''Radio''';

  @override
  String get radioHint => '''Cerca stazioni radio, ascolta streaming e gestisci le preferite''';

  @override
  String get radioTitle => '''Radio da tutto il mondo''';

  @override
  String get radioFavoritesButton => '''Radio preferite''';

  @override
  String get radioNoFavorites => '''Nessuna radio preferita.''';

  @override
  String get radioSearchText => '''Cerca radio''';

  @override
  String get radioSearchHint => '''Nome della stazione o città...''';

  @override
  String get radioLanguage => '''Lingua''';

  @override
  String get radioBrowseBy => '''Sfoglia per''';

  @override
  String get radioBrowseByLanguage => '''Sfoglia per lingua''';

  @override
  String get radioBrowseByCountry => '''Sfoglia per nazione''';

  @override
  String get radioCountry => '''Nazione''';

  @override
  String get radioGenre => '''Genere''';


  @override
  String get radioActiveFilters => '''Filtri attivi''';

  @override
  String get radioResetFilters => '''Reimposta filtri''';

  @override
  String get radioFiltersReset => '''Filtri reimpostati.''';

  @override
  String get radioCity => '''Città''';
  @override
  String get radioSearch => '''Ricerca''';

  @override
  String get radioSearching => '''Caricamento radio...''';

  @override
  String get radioSearchResults => '''Risultati radio''';

  @override
  String get radioNoResults => '''Nessuna radio trovata.''';

  @override
  String radioResultsFound(int count) {
    return '''Trovate ${count} radio''';
  }

  @override
  String radioSearchError(Object error) {
    return '''Errore ricerca radio: ${error}''';
  }

  @override
  String radioNowPlaying(String name) {
    return '''Riproduco ${name}''';
  }

  @override
  String radioPlayError(Object error) {
    return '''Errore streaming radio: ${error}''';
  }

  @override
  String get radioAddFavorite => '''Aggiungi ai preferiti''';

  @override
  String get radioRemoveFavorite => '''Rimuovi dai preferiti''';

  @override
  String radioFavoriteAdded(String name) {
    return '''${name} aggiunta ai preferiti.''';
  }

  @override
  String radioFavoriteRemoved(String name) {
    return '''${name} rimossa dai preferiti.''';
  }

  @override
  String get tvSearchFieldLabel => '''Cerca canali TV''';

  @override
  String get tvSearchFieldHint => '''Nome del canale...''';

  @override
  String get tvSearchButton => '''Cerca''';

  @override
  String get tvSearchResults => '''Risultati canali TV''';

  @override
  String get tvSearchEmptyQuery => '''Inserisci il nome di un canale TV da cercare.''';

  @override
  String tvSearchNoResults(String query) {
    return '''Nessun canale TV trovato per ${query}.''';
  }

  @override
  String get tvOpenChannelHint => '''Tocca per riprodurre il canale TV''';

  @override
  String tvNowOnAir(String title) {
    return '''Ora in onda: ${title}''';
  }

  @override
  String get radioAddCommunity => '''Aggiungi radio alla comunità Sonarpad''';

  @override
  String get radioAddName => '''Nome radio''';

  @override
  String get radioAddUrl => '''Indirizzo streaming''';

  @override
  String get radioAddSubmit => '''Verifica e aggiungi''';

  @override
  String get radioAddMissingFields => '''Inserisci nome radio e indirizzo streaming.''';

  @override
  String get radioCommunityAdded => '''Radio aggiunta correttamente alla comunità Sonarpad.''';

  @override
  String radioCommunityAddError(Object error) {
    return '''Errore durante l'aggiunta della radio: ${error}''';
  }

  @override
  String get radioPlay => '''Riproduci''';

  @override
  String get startRecording => '''Avvia registrazione''';

  @override
  String get stopRecording => '''Ferma registrazione''';

  @override
  String get recordings => '''Registrazioni''';

  @override
  String get noRecordings => '''Nessuna registrazione.''';

  @override
  String get recordingStarted => '''Registrazione avviata.''';

  @override
  String recordingSaved(Object path) {
    return '''Registrazione salvata: ${path}''';
  }

  @override
  String recordingError(Object error) {
    return '''Errore registrazione: ${error}''';
  }

  @override
  String get routeTitle => '''Percorsi''';

  @override
  String get routeFrom => '''Partenza''';

  @override
  String get routeTo => '''Destinazione''';

  @override
  String get routeCountry => '''Paese''';

  @override
  String get routeCountryItaly => '''Italia''';

  @override
  String get routeCountryFrance => '''Francia''';

  @override
  String get routeCountrySpain => '''Spagna''';

  @override
  String get routeCountryCzechRepublic => '''Repubblica Ceca''';

  @override
  String get routeVehicle => '''Mezzo di trasporto''';

  @override
  String get routeType => '''Tipo''';

  @override
  String get routeIncludeMunicipalities => '''Includi comuni attraversati''';

  @override
  String get routeWalking => '''A piedi''';

  @override
  String get routeCycling => '''In bicicletta''';

  @override
  String get routeDriving => '''In auto''';

  @override
  String get routeWheelchair => '''In sedia a rotelle''';

  @override
  String get routeFastest => '''Più veloce''';

  @override
  String get routeShortest => '''Più corto''';

  @override
  String get routeCalculate => '''Calcola percorso''';

  @override
  String get routeCalculating => '''Calcolo in corso...''';

  @override
  String get routeChooseFrom => '''Scegli il punto di partenza''';

  @override
  String get routeChooseTo => '''Scegli la destinazione''';

  @override
  String get routeCancel => '''Annulla''';

  @override
  String get routeErrorMissingFields => '''Inserisci punto di partenza e destinazione''';

  @override
  String get routeErrorFromNotFound => '''Nessun risultato trovato per l'indirizzo di partenza''';

  @override
  String get routeErrorToNotFound => '''Nessun risultato trovato per l'indirizzo di arrivo''';

  @override
  String get routeResultsTitle => '''Percorsi disponibili''';

  @override
  String get routeDistance => '''Distanza''';

  @override
  String get routeDuration => '''Durata''';

  @override
  String get routeNavigation => '''Dettagli navigazione''';

  @override
  String get routeStartMunicipality => '''Comune di partenza''';

  @override
  String get routeEnterMunicipality => '''Entri nel comune di''';

  @override
  String routeError(Object error) {
    return '''Errore: ${error}''';
  }

  @override
  String get radioLanguageIt => '''Italiano''';

  @override
  String get radioLanguageEn => '''Inglese''';

  @override
  String get radioLanguageDe => '''Tedesco''';

  @override
  String get radioLanguageCountryCh => '''Svizzera''';

  @override
  String get radioLanguageEs => '''Spagnolo''';

  @override
  String get radioLanguagePt => '''Portoghese''';

  @override
  String get radioLanguageSv => '''Svedese''';

  @override
  String get radioLanguageVi => '''Vietnamita''';

  @override
  String get radioLanguageCs => '''Ceco''';

  @override
  String get radioLanguagePl => '''Polacco''';

  @override
  String get radioLanguageFr => '''Francese''';

  @override
  String get radioLanguageSr => '''Serbo''';

  @override
  String get radioLanguageUk => '''Ucraino''';

  @override
  String get radioLanguageHi => '''Hindi''';

  @override
  String get radioLanguageLt => '''Lituano''';

  @override
  String get radioLanguageRu => '''Russo''';

  @override
  String get radioLanguageZh => '''Cinese''';

  @override
  String get radioCountryOptionIt => '''Italia''';

  @override
  String get radioCountryOptionUs => '''Stati Uniti''';

  @override
  String get radioCountryOptionGb => '''Regno Unito''';

  @override
  String get radioCountryOptionFr => '''Francia''';

  @override
  String get radioCountryOptionEs => '''Spagna''';

  @override
  String get radioCountryOptionDe => '''Germania''';

  @override
  String get radioCountryOptionCh => '''Svizzera''';

  @override
  String get radioCountryOptionAt => '''Austria''';

  @override
  String get radioCountryOptionBe => '''Belgio''';

  @override
  String get radioCountryOptionNl => '''Paesi Bassi''';

  @override
  String get radioCountryOptionPt => '''Portogallo''';

  @override
  String get radioCountryOptionBr => '''Brasile''';

  @override
  String get radioCountryOptionAr => '''Argentina''';

  @override
  String get radioCountryOptionMx => '''Messico''';

  @override
  String get radioCountryOptionCa => '''Canada''';

  @override
  String get radioCountryOptionAu => '''Australia''';

  @override
  String get radioCountryOptionIe => '''Irlanda''';

  @override
  String get radioCountryOptionSe => '''Svezia''';

  @override
  String get radioCountryOptionPl => '''Polonia''';

  @override
  String get radioCountryOptionJp => '''Giappone''';

  @override
  String get radioGenreOptionAll => '''Tutti i generi''';

  @override
  String get radioGenreOptionNews => '''Notizie''';

  @override
  String get radioGenreOptionMusic => '''Musica''';

  @override
  String get radioGenreOptionSport => '''Sport''';

  @override
  String get radioGenreOptionTalk => '''Talk e approfondimenti''';

  @override
  String get radioGenreOptionPop => '''Pop''';

  @override
  String get radioGenreOptionRock => '''Rock''';

  @override
  String get radioGenreOptionClassical => '''Classica''';

  @override
  String get radioGenreOptionJazz => '''Jazz''';

  @override
  String get radioGenreOptionDance => '''Dance''';

  @override
  String get radioGenreOptionBlues => '''Blues''';

  @override
  String get radioGenreOptionCountry => '''Country''';

  @override
  String get radioGenreOptionHiphop => '''Hip hop''';

  @override
  String get radioGenreOptionElectronic => '''Elettronica''';

  @override
  String get radioGenreOptionLatin => '''Latina''';

  @override
  String get radioGenreOptionReggae => '''Reggae''';

  @override
  String get radioGenreOptionMetal => '''Metal''';

  @override
  String get radioGenreOptionFolk => '''Folk''';

  @override
  String get radioGenreOptionReligion => '''Religione''';

  @override
  String get radioGenreOptionLocal => '''Locale''';

  @override
  String get radioGenreOptionCulture => '''Cultura''';

  @override
  String get radioGenreOptionOldies => '''Anni 70 / 80 / 90''';

  @override
  String get radioGenreOptionKids => '''Bambini''';

  @override
  String get radioGenreOptionAmbient => '''Ambient''';

  @override
  String get radioCommunityLanguageItalian => '''Italiano''';

  @override
  String get radioCommunityLanguageEnglish => '''Inglese''';

  @override
  String get radioCommunityLanguageSpanish => '''Spagnolo''';

  @override
  String get radioCommunityLanguageFrench => '''Francese''';

  @override
  String get radioCommunityLanguageGerman => '''Tedesco''';

  @override
  String get radioCommunityLanguagePortuguese => '''Portoghese''';

  @override
  String get radioCommunityLanguageSwedish => '''Svedese''';

  @override
  String get radioCommunityLanguageVietnamese => '''Vietnamita''';

  @override
  String get radioCommunityLanguageCzech => '''Ceco''';

  @override
  String get radioCommunityLanguagePolish => '''Polacco''';

  @override
  String get radioCommunityLanguageSerbian => '''Serbo''';

  @override
  String get radioCommunityLanguageUkrainian => '''Ucraino''';

  @override
  String get radioCommunityLanguageLithuanian => '''Lituano''';

  @override
  String get radioCommunityLanguageRussian => '''Russo''';

  @override
  String get radioCommunityLanguageChinese => '''Cinese''';

  @override
  String get radioCommunityLanguageHindi => '''Hindi''';

  @override
  String routeDistanceMeters(int meters) {
    return '''${meters} m''';
  }

  @override
  String routeDistanceKilometers(String kilometers) {
    return '''${kilometers} km''';
  }

  @override
  String routeDurationMinutes(int minutes) {
    return '''${minutes} min''';
  }

  @override
  String routeDurationHoursMinutes(int hours, int minutes) {
    return '''${hours}h ${minutes}m''';
  }

  @override
  String get cinemaTitle => '''Film al cinema''';

  @override
  String get cinemaNoMovies => '''Nessun film trovato al momento.''';

  @override
  String get cinemaError => '''Errore durante il caricamento dei film.''';

  @override
  String cinemaReleased(String date) {
    return '''Uscito il: ${date}''';
  }

  @override
  String get cinemaOverviewLabel => '''Trama:''';

  @override
  String get cinemaUpcomingReleases => '''Prossime uscite''';

  @override
  String cinemaWillRelease(String date) {
    return '''Uscirà il: ${date}''';
  }

  @override
  String get cinemaOpenTrailer => '''Apri trailer''';

  @override
  String get concertsTitle => '''Concerti ed eventi''';

  @override
  String get concertsSearchHint => '''Inserisci una città (es. Milano, Roma)''';

  @override
  String get concertsSearchLabel => '''Cerca concerti per città''';

  @override
  String get concertsSearchTooltip => '''Cerca''';

  @override
  String get concertsInitialText => '''Scrivi il nome della tua città in alto per vedere i concerti musicali in programma.''';

  @override
  String get concertsEmpty => '''Nessun concerto trovato in questa città.''';

  @override
  String get concertsVenue => '''Luogo del concerto:''';

  @override
  String get concertsBuyTickets => '''Acquista o vedi dettagli su Ticketmaster''';

  @override
  String get podcastPlayedEpisodes => '''Episodi ascoltati''';

  @override
  String get podcastUnplayed => '''Episodi non ascoltati''';

  @override
  String get routeReadAction => '''Leggi percorso''';

  @override
  String get routeSaveAction => '''Salva nei documenti''';

  @override
  String get routeSaveSuccess => '''Percorso salvato nei documenti''';


  @override
  String get routeRecentRoutes => '''Percorsi recenti''';

  @override
  String get routeRecentRoutesEmpty => '''Nessun percorso recente''';

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) {
    return '''Dettagli navigazione da ${from} a ${to} - ${date}''';
  }

}
