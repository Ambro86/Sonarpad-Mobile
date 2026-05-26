import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;
  bool get _isEn => locale.languageCode == 'en';
  bool get _isFr => locale.languageCode == 'fr';

  static const supportedLocales = [Locale('it'), Locale('en'), Locale('fr')];

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
  String get appLanguage => _isEn ? 'App Language' : (_isFr ? 'Langue de l\'application' : 'Lingua dell\'app');
  String get homeSemanticsLabel => _isEn ? 'Sonarpad, main screen' : (_isFr ? 'Sonarpad, écran principal' : 'Sonarpad, schermata principale');
  String get settings => _isEn ? 'Settings' : (_isFr ? 'Paramètres' : 'Impostazioni');
  String get settingsHint => _isEn ? 'Open settings' : (_isFr ? 'Ouvrir les paramètres' : 'Apre le impostazioni');
  String get info => _isEn ? 'About' : (_isFr ? 'À propos' : 'Informazioni');
  String get infoHint => _isEn ? 'Open app info' : (_isFr ? 'Ouvrir les informations sur l\'application' : 'Apre le informazioni sull\'app');
  String get donations => _isEn ? 'Donations' : (_isFr ? 'Dons' : 'Donazioni');
  String get donationsHint => _isEn ? 'Support the development of Sonarpad' : (_isFr ? 'Soutenir le développement de Sonarpad' : 'Supporta lo sviluppo di Sonarpad');
  String get loading => _isEn ? 'Loading' : (_isFr ? 'Chargement' : 'Caricamento');
  String get ttsVoiceLanguage => _isEn ? 'TTS Voice Language' : (_isFr ? 'Langue de la voix TTS' : 'Lingua voci TTS');
  String get ttsVoice => _isEn ? 'TTS Voice' : (_isFr ? 'Voix TTS' : 'Voce TTS');
  String get saveSettings => _isEn ? 'Save settings' : (_isFr ? 'Sauvegarder les paramètres' : 'Salva impostazioni');
  String get settingsSaved => _isEn ? 'Settings saved.' : (_isFr ? 'Paramètres sauvegardés.' : 'Impostazioni salvate.');
  String get infoDescription => _isEn
      ? 'Sonarpad is a simple app packed with features. Designed to be accessible for the visually impaired using VoiceOver, here you can listen to news, search and subscribe to podcasts, import Wikipedia articles, add documents to your library, save and edit them. Sonarpad\'s features are constantly updated, and they are all designed to make life easier for the visually impaired.'
      : (_isFr ? 'Sonarpad est une application simple riche en fonctionnalités. Conçue pour être accessible aux personnes malvoyantes à l\'aide de VoiceOver, vous pouvez ici écouter les actualités, rechercher et vous abonner à des podcasts, importer des articles Wikipedia, ajouter des documents à votre bibliothèque, les enregistrer et les modifier. Les fonctionnalités de Sonarpad sont constamment mises à jour, et sont toutes conçues pour faciliter la vie des malvoyants.' : 'Sonarpad è un\'app semplice, ma con tante funzioni. Nata per essere accessibile ai non vedenti usando VoiceOver, qui potrete ascoltare le notizie, cercare e iscriversi ai podcast, importare articoli di Wikipedia, aggiungere i documenti alla vostra libreria, salvarli e modificarli. Le funzioni di Sonarpad sono in continuo aggiornamento, e sono tutte pensate per rendere più facile la vita dei non vedenti.');
  String get infoAuthor => _isEn ? 'Author: Ambrogio Riili' : (_isFr ? 'Auteur : Ambrogio Riili' : 'Autore: Ambrogio Riili');
  String get donationsIntro => _isEn
      ? 'Sonarpad is a program created at first to meet personal needs, but over time it has grown more and more. Developing it requires constant work to improve features, fix bugs, search for new ideas, and carefully test all functions.\n\nIf you find this program useful and want to support its development, you can make a donation.'
      : (_isFr ? 'Sonarpad est un programme créé à l\'origine pour répondre à des besoins personnels, mais au fil du temps, il a de plus en plus grandi. Son développement nécessite un travail constant pour améliorer les fonctionnalités, corriger les bogues, rechercher de nouvelles idées et tester en profondeur chaque partie du programme.\n\nSi vous trouvez ce programme utile et souhaitez soutenir son développement, vous pouvez faire un don.' : 'Sonarpad è un programma creato inizialmente per soddisfare esigenze personali, ma nel tempo è cresciuto sempre di più. Il suo sviluppo richiede un lavoro costante per migliorare le funzionalità, correggere bug, ricercare nuove idee e testare a fondo ogni parte del programma.\n\nSe ritieni utile questo programma e desideri supportarne lo sviluppo, puoi effettuare una donazione.');
  String get donationsPaypalDesc => _isEn
      ? 'You can donate via PayPal using this link:\nhttps://www.paypal.me/ambrogio86\nPlease, if possible, add “Sonarpad” as the payment note.'
      : (_isFr ? 'Vous pouvez faire un don via PayPal via ce lien :\nhttps://www.paypal.me/ambrogio86\nVeuillez, si possible, ajouter "Sonarpad" comme note de paiement.' : 'Puoi donare tramite PayPal al seguente link:\nhttps://www.paypal.me/ambrogio86\nSe possibile, indica come causale “Sonarpad”.');
  String get donationsBankDesc => _isEn
      ? 'You can also donate via bank transfer to the bank account in the name of Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nPlease, if possible, use a clear payment reason, for example “Sonarpad”.'
      : (_isFr ? 'Vous pouvez également contribuer par virement bancaire sur le compte au nom d\'Ambrogio Riili.\nIBAN : IT77W0306901020100000064149\nSi possible, indiquez un motif de paiement clair, par exemple "Sonarpad".' : 'È possibile contribuire anche tramite bonifico bancario sul conto intestato a Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nSe possibile, indica una causale chiara, ad esempio “Sonarpad”.');
  String get donationsThanks => _isEn
      ? 'Anyone who supports the project will be mentioned in the program and on the GitHub repository, unless they prefer to stay anonymous or use a nickname.\n\nThanks to Jiri Holzinger and Paola Vagata for their contribution.\nFor the Vietnamese translation, thanks to Anh Đức Nguyễn.\nFor the Czech translation, thanks to Radek Žalud and Jiri Holzinger.\nFor the Spanish translation, thanks to Arturo Fernandez Rivas.\nFor the Serbian translation, thanks to Mila Kuran.\nFor the Ukrainian translation, thanks to Ivan Shtefuriak.'
      : (_isFr ? 'Quiconque soutient le projet sera mentionné dans le programme et sur le référentiel GitHub, sauf s\'il préfère rester anonyme ou utiliser un surnom.\n\nMerci à Jiri Holzinger et Paola Vagata pour leur contribution.\nPour la traduction en vietnamien, merci à Anh Đức Nguyễn.\nPour la traduction en tchèque, merci à Radek Žalud et Jiri Holzinger.\nPour la traduction en espagnol, merci à Arturo Fernandez Rivas.\nPour la traduction en serbe, merci à Mila Kuran.\nPour la traduction en ukrainien, merci à Ivan Shtefuriak.' : 'Chiunque decida di supportare il progetto verrà ringraziato nel programma e sul repository GitHub, nella sezione sostenitori, salvo richiesta di anonimato o utilizzo di un nickname.\n\nSi ringrazia per il contributo Jiri Holzinger e Paola Vagata.\nPer la traduzione in vietnamita ringrazio Anh Đức Nguyễn.\nPer la traduzione in ceco ringrazio Radek Žalud e Jiri Holzinger.\nPer la traduzione in spagnolo ringrazio Arturo Fernandez Rivas.\nPer la traduzione in serbo ringrazio Mila Kuran.\nPer la traduzione in ucraino ringrazio Ivan Shtefuriak.');
  String get news => _isEn ? 'News' : (_isFr ? 'Actualités' : 'Notizie');
  String get newsHint => _isEn ? 'Open news from Google News RSS' : (_isFr ? 'Ouvrir les actualités de Google News RSS' : 'Apre le notizie da Google News RSS');
  String get podcasts => _isEn ? 'Podcasts' : (_isFr ? 'Podcasts' : 'Podcast');
  String get podcastsHint => _isEn ? 'Subscribe to podcasts, play or download episodes' : (_isFr ? 'S\'abonner aux podcasts, lire ou télécharger des épisodes' : 'Iscriviti ai podcast, riproduci o scarica episodi');
  String get importFromWikipedia => 'Wikipedia';
  String get wikipediaHint => _isEn ? 'Search for a Wikipedia article and import the text' : (_isFr ? 'Rechercher un article Wikipedia et importer le texte' : 'Cerca un articolo Wikipedia e importa il testo');

  String get newsLanguage => _isEn ? 'News Language' : (_isFr ? 'Langue des actualités' : 'Lingua notizie');
  String get loadingNews => _isEn ? 'Loading news' : (_isFr ? 'Chargement des actualités' : 'Caricamento notizie');
  String error(Object error) => _isEn ? 'Error: \$error' : (_isFr ? 'Erreur : \$error' : 'Errore: \$error');
  String get noNewsFound => _isEn ? 'No news found' : (_isFr ? 'Aucune actualité trouvée' : 'Nessuna notizia trovata');
  String get loadingArticle => _isEn ? 'Loading article' : (_isFr ? 'Chargement de l\'article' : 'Caricamento articolo');
  String get noFullArticleFound => _isEn ? 'Full article not available. Showing feed summary.' : (_isFr ? 'Article complet indisponible. Affichage du résumé du flux.' : 'Articolo integrale non disponibile. Mostro il riassunto del feed.');
  String get italian => _isEn ? 'Italian' : (_isFr ? 'Italien' : 'Italiano');
  String get english => _isEn ? 'English' : (_isFr ? 'Anglais' : 'English');
  String get newsSource => _isEn ? 'News source' : (_isFr ? 'Source d\'actualité' : 'Fonte notizie');

  String get article => _isEn ? 'Article' : (_isFr ? 'Article' : 'Articolo');
  String get articlePreview => _isEn ? 'Article preview' : (_isFr ? 'Aperçu de l\'article' : 'Anteprima articolo');
  String get readFullArticle => _isEn ? 'Read full article' : (_isFr ? 'Lire l\'article complet' : 'Leggi articolo completo');
  String get extractingReaderArticleText => _isEn ? 'Extracting text in reader mode...' : (_isFr ? 'Extraction du texte en mode lecteur...' : 'Estraggo il testo in modalita lettura...');
  String get extractingVisibleArticleText => _isEn ? 'Extracting visible text from page...' : (_isFr ? 'Extraction du texte visible de la page...' : 'Estraggo il testo visibile dalla pagina...');
  String source(String source) => _isEn ? 'Source: \$source' : (_isFr ? 'Source : \$source' : 'Fonte: \$source');
  String get readyStatus => _isEn ? 'Ready.' : (_isFr ? 'Prêt.' : 'Pronto.');
  String get preparingEdgeTts => _isEn ? 'Preparing Edge TTS reading in blocks...' : (_isFr ? 'Préparation de la lecture Edge TTS en blocs...' : 'Preparo lettura Edge TTS a blocchi...');
  String get noTextToRead => _isEn ? 'No text to read.' : (_isFr ? 'Aucun texte à lire.' : 'Nessun testo da leggere.');
  String chunkCreated(int index, int total) => _isEn ? 'Block \$index of \$total created. Reading in progress...' : (_isFr ? 'Bloc \$index sur \$total créé. Lecture en cours...' : 'Blocco \$index di \$total creato. Lettura in corso...');
  String playingChunk(int index, int total, int size) => _isEn ? 'Playing block \$index of \$total (\$size bytes)...' : (_isFr ? 'Lecture du bloc \$index sur \$total (\$size octets)...' : 'Riproduco blocco \$index di \$total (\$size byte)...');
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) => _isEn
      ? 'Reading finished. Blocks created: \$readyChunks/\$totalChunks. Library: \$libraryPath'
      : (_isFr ? 'Lecture terminée. Blocs créés : \$readyChunks/\$totalChunks. Bibliothèque : \$libraryPath' : 'Lettura terminata. Blocchi creati: \$readyChunks/\$totalChunks. Libreria: \$libraryPath');
  String get libraryNotSpecified => _isEn ? 'not specified' : (_isFr ? 'non spécifié' : 'non indicata');
  String get readingStopped => _isEn ? 'Reading stopped.' : (_isFr ? 'Lecture arrêtée.' : 'Lettura interrotta.');
  String edgeTtsError(Object error) => _isEn ? 'Edge TTS Error: \$error' : (_isFr ? 'Erreur Edge TTS : \$error' : 'Errore Edge TTS: \$error');
  String audioChunksReady(int readyChunks, int totalChunks) => _isEn ? 'Audio blocks ready: \$readyChunks / \$totalChunks' : (_isFr ? 'Blocs audio prêts : \$readyChunks / \$totalChunks' : 'Blocchi audio pronti: \$readyChunks / \$totalChunks');
  String get readingInProgress => _isEn ? 'Reading in progress...' : (_isFr ? 'Lecture en cours...' : 'Lettura in corso...');
  String get readWithEdgeTts => _isEn ? 'Read with Edge TTS' : (_isFr ? 'Lire avec Edge TTS' : 'Leggi con Edge TTS');
  String get stopReading => _isEn ? 'Stop reading' : (_isFr ? 'Arrêter la lecture' : 'Interrompi lettura');
  String get openOriginalArticle => _isEn ? 'Open original article' : (_isFr ? 'Ouvrir l\'article original' : 'Apri articolo originale');

  String get searchPodcasts => _isEn ? 'Search podcasts' : (_isFr ? 'Rechercher des podcasts' : 'Cerca podcast');
  String get podcastName => _isEn ? 'Podcast name' : (_isFr ? 'Nom du podcast' : 'Nome podcast');
  String get podcastSearchHint => _isEn ? 'Example: technology, history, the podcast name...' : (_isFr ? 'Exemple : technologie, histoire, le nom du podcast...' : 'Esempio: tecnologia, storia, il nome del podcast...');
  String get searchCountry => _isEn ? 'Search country' : (_isFr ? 'Pays de recherche' : 'Paese ricerca');
  String get podcastCategory => _isEn ? 'Podcast category' : (_isFr ? 'Catégorie de podcast' : 'Categoria podcast');
  String get countryItaly => _isEn ? 'Italy' : (_isFr ? 'Italie' : 'Italia');
  String get countryUnitedStatesEnglish => _isEn ? 'United States / English' : (_isFr ? 'États-Unis / Anglais' : 'Stati Uniti / inglese');
  String get countryUnitedKingdom => _isEn ? 'United Kingdom' : (_isFr ? 'Royaume-Uni' : 'Regno Unito');
  String get countrySpain => _isEn ? 'Spain' : (_isFr ? 'Espagne' : 'Spagna');
  String get countryFrance => _isEn ? 'France' : (_isFr ? 'France' : 'Francia');
  String get searchInProgress => _isEn ? 'Search in progress...' : (_isFr ? 'Recherche en cours...' : 'Ricerca in corso...');
  String podcastResultsFound(int count) => _isEn ? 'Found \$count podcasts' : (_isFr ? '\$count podcasts trouvés' : 'Trovati \$count podcast');
  String podcastSearchError(Object error) => _isEn ? 'Podcast search error: \$error' : (_isFr ? 'Erreur de recherche de podcast : \$error' : 'Errore ricerca podcast: \$error');
  String subscribedTo(String title) => _isEn ? 'Subscribed to \$title' : (_isFr ? 'Abonné à \$title' : 'Iscritto a \$title');
  String subscriptionError(Object error) => _isEn ? 'Subscription error: \$error' : (_isFr ? 'Erreur d\'abonnement : \$error' : 'Errore iscrizione: \$error');
  String podcastSubscriptionError(Object error) => _isEn ? 'Podcast subscription error: \$error' : (_isFr ? 'Erreur d\'abonnement au podcast : \$error' : 'Errore iscrizione podcast: \$error');
  String get searchResults => _isEn ? 'Search results' : (_isFr ? 'Résultats de recherche' : 'Risultati ricerca');
  String get podcastInfo => _isEn ? 'Podcast info' : (_isFr ? 'Infos sur le podcast' : 'Info podcast');
  String get subscribe => _isEn ? 'Subscribe' : (_isFr ? 'S\'abonner' : 'Iscriviti');
  String get podcastAuthor => _isEn ? 'Author' : (_isFr ? 'Auteur' : 'Autore');
  String get noPodcastDescription => _isEn ? 'No description available.' : (_isFr ? 'Aucune description disponible.' : 'Nessuna descrizione disponibile.');
  String get loadingPodcastInfo => _isEn ? 'Loading podcast info' : (_isFr ? 'Chargement des infos du podcast' : 'Caricamento info podcast');
  String get podcastArtwork => _isEn ? 'Podcast artwork' : (_isFr ? 'Pochette du podcast' : 'Copertina podcast');
  String get addFeedUrlManually => _isEn ? 'Add RSS feed URL manually' : (_isFr ? 'Ajouter l\'URL du flux RSS manuellement' : 'Aggiungi manualmente URL feed RSS');
  String get podcastFeedUrl => _isEn ? 'Podcast RSS feed URL' : (_isFr ? 'URL du flux RSS du podcast' : 'URL feed podcast RSS');
  String get subscribeFromUrl => _isEn ? 'Subscribe from URL' : (_isFr ? 'S\'abonner à partir de l\'URL' : 'Iscriviti da URL');
  String get subscribedPodcasts => _isEn ? 'Subscribed podcasts' : (_isFr ? 'Podcasts abonnés' : 'Podcast iscritti');
  String get noSubscribedPodcasts => _isEn ? 'No subscribed podcasts. Search for a podcast and tap a result to subscribe.' : (_isFr ? 'Aucun podcast abonné. Recherchez un podcast et appuyez sur un résultat pour vous abonner.' : 'Nessun podcast iscritto. Cerca un podcast e tocca il risultato per iscriverti.');
  String get loadingEpisodes => _isEn ? 'Loading episodes' : (_isFr ? 'Chargement des épisodes' : 'Caricamento episodi');
  String get noAudioEpisodesFound => _isEn ? 'No audio episodes found in the feed.' : (_isFr ? 'Aucun épisode audio trouvé dans le flux.' : 'Nessun episodio audio trovato nel feed.');
  String get episodes => _isEn ? 'Episodes' : (_isFr ? 'Épisodes' : 'Episodi');
  String get episodeActions => _isEn ? 'Episode actions' : (_isFr ? 'Actions de l\'épisode' : 'Azioni episodio');
  String downloaded(String path) => _isEn ? 'Downloaded: \$path' : (_isFr ? 'Téléchargé : \$path' : 'Scaricato: \$path');
  String episodeError(Object error) => _isEn ? 'Episode error: \$error' : (_isFr ? 'Erreur de l\'épisode : \$error' : 'Errore episodio: \$error');
  String get play => _isEn ? 'Play' : (_isFr ? 'Lire' : 'Riproduci');
  String get pause => _isEn ? 'Pause' : (_isFr ? 'Pause' : 'Pausa');
  String get rewind15s => _isEn ? 'Rewind 15s' : (_isFr ? 'Reculer de 15s' : 'Indietro 15s');
  String get forward15s => _isEn ? 'Forward 15s' : (_isFr ? 'Avancer de 15s' : 'Avanti 15s');
  String get stop => 'Stop';
  String get back => _isEn ? 'Back' : (_isFr ? 'Retour' : 'Indietro');
  String get episodePlayer => _isEn ? 'Episode player' : (_isFr ? 'Lecteur d\'épisode' : 'Player episodio');
  String get loadingEpisodeAudio => _isEn ? 'Loading episode audio' : (_isFr ? 'Chargement de l\'audio de l\'épisode' : 'Caricamento audio episodio');
  String get download => _isEn ? 'Download' : (_isFr ? 'Télécharger' : 'Scarica');

  String get searchWikipedia => _isEn ? 'Search on Wikipedia' : (_isFr ? 'Rechercher sur Wikipédia' : 'Cerca su Wikipedia');
  String get wikipediaLanguage => _isEn ? 'Wikipedia language' : (_isFr ? 'Langue Wikipédia' : 'Lingua Wikipedia');
  String get search => _isEn ? 'Search' : (_isFr ? 'Rechercher' : 'Cerca');
  String get wikipediaSearch => _isEn ? 'Wikipedia search' : (_isFr ? 'Recherche Wikipédia' : 'Ricerca Wikipedia');
  String get wikipediaImporting => _isEn ? 'Wikipedia import' : (_isFr ? 'Importation Wikipédia' : 'Importazione Wikipedia');
  String get noWikipediaResults => _isEn ? 'No Wikipedia results found' : (_isFr ? 'Aucun résultat Wikipédia trouvé' : 'Nessun risultato Wikipedia trovato');
  String get wikipediaImportMode => _isEn ? 'Import mode' : (_isFr ? 'Mode d\'importation' : 'Importa');
  String get wikipediaImportWholeArticle => _isEn ? 'Whole article' : (_isFr ? 'Article complet' : 'Tutto l\'articolo');

  // Documenti
  String get documents => _isEn ? 'Documents' : (_isFr ? 'Documents' : 'Documenti');
  String get documentsHint => _isEn ? 'Open document library' : (_isFr ? 'Ouvrir la bibliothèque de documents' : 'Apre la libreria documenti');
  String get documentLibrary => _isEn ? 'Document library' : (_isFr ? 'Bibliothèque de documents' : 'Libreria documenti');
  String get addToLibrary => _isEn ? 'Add to library' : (_isFr ? 'Ajouter à la bibliothèque' : 'Aggiungi alla libreria');
  String get noDocuments => _isEn ? 'No documents. Add a file.' : (_isFr ? 'Aucun document. Ajoutez un fichier.' : 'Nessun documento. Aggiungi un file.');
  String get documentAdded => _isEn ? 'Document added' : (_isFr ? 'Document ajouté' : 'Documento aggiunto');
  String get documentRemoved => _isEn ? 'Document removed' : (_isFr ? 'Document supprimé' : 'Documento rimosso');
  String get removeDocument => _isEn ? 'Remove document' : (_isFr ? 'Supprimer le document' : 'Rimuovi documento');
  String get removePodcast => _isEn ? 'Remove podcast' : (_isFr ? 'Supprimer le podcast' : 'Rimuovi podcast');
  String get podcastRemoved => _isEn ? 'Podcast removed' : (_isFr ? 'Podcast supprimé' : 'Podcast rimosso');
  String get documentPickerError => _isEn ? 'Error opening file' : (_isFr ? 'Erreur d\'ouverture du fichier' : 'Errore apertura file');
  String get readDocument => _isEn ? 'Read document' : (_isFr ? 'Lire le document' : 'Leggi documento');
  String get documentReaderTitle => _isEn ? 'Document reader' : (_isFr ? 'Lecteur de document' : 'Lettore documento');
  String get edit => _isEn ? 'Edit' : (_isFr ? 'Modifier' : 'Modifica');
  String get save => _isEn ? 'Save' : (_isFr ? 'Enregistrer' : 'Salva');
  String get cancel => _isEn ? 'Cancel' : (_isFr ? 'Annuler' : 'Annulla');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'it', 'fr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
