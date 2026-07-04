// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Sonarpad';

  @override
  String get appLanguage => 'Langue de l\'application';

  @override
  String get settingsTheme => 'Thème de l\'application';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsWeatherTemperatureUnit => 'Unité de température météo';

  @override
  String get weatherTemperatureCelsius => 'Celsius (°C)';

  @override
  String get weatherTemperatureFahrenheit => 'Fahrenheit (°F)';

  @override
  String get homeSemanticsLabel => 'Sonarpad, écran principal';

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsHint => 'Ouvrir les paramètres';

  @override
  String get info => 'À propos';

  @override
  String get infoHint => 'Ouvrir les informations sur l\'application';

  @override
  String get categoryReading => 'Lecture et documents';

  @override
  String get categoryMedia => 'Médias et divertissement';

  @override
  String get categoryUtilities => 'Recherches et utilitaires';

  @override
  String get voiceDictionaryTitle => 'Dictionnaire vocal';

  @override
  String get voiceDictionaryAdd => 'Ajouter des entrées au dictionnaire';

  @override
  String get voiceDictionaryOriginalWord => 'Mot original';

  @override
  String get voiceDictionaryReplacementWord => 'Mot de remplacement';

  @override
  String get voiceDictionaryMatchCase => 'Respecter la casse';

  @override
  String get voiceDictionaryIgnoreCase => 'Ignorer la casse';

  @override
  String get voiceDictionaryEntries => 'Entrées du dictionnaire';

  @override
  String get voiceDictionaryEmpty => 'Aucune entrée dans le dictionnaire.';

  @override
  String get voiceDictionaryRemove => 'Supprimer l\'entrée sélectionnée';

  @override
  String get voiceDictionaryOriginalRequired => 'Saisissez le mot original.';

  @override
  String get convertMediaTitle => 'Convertir le média';

  @override
  String get convertMediaInput => 'Fichier à convertir';

  @override
  String get convertMediaOutput => 'Dossier d\'enregistrement';

  @override
  String get convertMediaImage => 'Image';

  @override
  String get convertMediaBrowse => 'Parcourir...';

  @override
  String get convertMediaFormat => 'Format';

  @override
  String get convertMediaBitrate => 'Débit (kbps)';

  @override
  String get convertMediaOggQuality => 'Qualité (q)';

  @override
  String get convertMediaFlacCompression => 'Niveau de compression';

  @override
  String get convertMediaWavBitDepth => 'Profondeur de bits WAV';

  @override
  String get convertMediaReady => 'Prêt.';

  @override
  String get convertMediaRunning => 'Conversion en cours...';

  @override
  String get convertMediaDone => 'Conversion terminée.';

  @override
  String get convertMediaButton => 'Convertir';

  @override
  String get convertMediaNoInput => 'Sélectionnez un fichier à convertir.';

  @override
  String get convertMediaNoOutput =>
      'Sélectionnez un dossier d\'enregistrement.';

  @override
  String get convertMediaOutputNotWritable =>
      'Le dossier choisi n’est pas directement accessible. Le fichier sera enregistré dans le dossier interne de Sonarpad ; une fois la conversion terminée, vous pourrez le partager ou l’enregistrer dans l’app Fichiers.';

  @override
  String get convertMediaNoImage => 'Sélectionnez une image pour la vidéo.';

  @override
  String get convertMediaSamePath =>
      'Le fichier converti doit être différent du fichier source.';

  @override
  String get convertMediaInvalidBitrate =>
      'Entrez un débit valide entre 64 et 320 kbps.';

  @override
  String convertMediaFailed(Object error) {
    return 'Échec de la conversion : $error';
  }

  @override
  String get donations => 'Dons';

  @override
  String get donationsHint => 'Soutenir le développement de Sonarpad';

  @override
  String get loading => 'Chargement';

  @override
  String get ttsVoiceLanguage => 'Langue de la voix TTS';

  @override
  String get ttsVoice => 'Voix TTS';

  @override
  String get saveSettings => 'Enregistrer les paramètres';

  @override
  String get settingsSaved => 'Paramètres enregistrés.';

  @override
  String get settingsSavedTitle => 'Paramètres enregistrés';

  @override
  String get sonarpadCodeValidTitle => 'Code valide';

  @override
  String get sonarpadCodeValidMessage =>
      'Le code Sonarpad est correct. Paramètres enregistrés.';

  @override
  String get sonarpadCodeInvalidTitle => 'Code invalide';

  @override
  String get sonarpadCodeInvalidMessage =>
      'Le code Sonarpad n’est pas valide. Vérifiez que vous l’avez copié sans espaces supplémentaires.';

  @override
  String get infoDescription =>
      'Sonarpad est une application simple et riche en fonctionnalités. Conçue pour être accessible avec VoiceOver aux personnes aveugles ou malvoyantes, elle permet d’écouter les actualités, de rechercher des podcasts et de s’y abonner, d’importer des articles Wikipédia, d’ajouter des documents à votre bibliothèque, de les enregistrer et de les modifier. Sonarpad est constamment mise à jour, et chaque fonctionnalité est pensée pour faciliter la vie quotidienne.';

  @override
  String get infoAuthor => 'Auteur : Ambrogio Riili';

  @override
  String get donationsIntro =>
      'Sonarpad a d’abord été créé pour répondre à des besoins personnels, puis l’application s’est développée au fil du temps. Son développement demande un travail constant : améliorer les fonctionnalités, corriger les bogues, explorer de nouvelles idées et tester soigneusement chaque fonction.\n\nSi vous trouvez Sonarpad utile et souhaitez soutenir son développement, vous pouvez faire un don.';

  @override
  String get donationsPaypalDesc =>
      'Vous pouvez faire un don avec PayPal en utilisant ce lien :\nhttps://www.paypal.me/ambrogio86\nVeuillez, si possible, ajouter \"Sonarpad\" comme note de paiement.';

  @override
  String get donationsBankDesc =>
      'Vous pouvez également contribuer par virement bancaire sur le compte au nom d\'Ambrogio Riili.\nIBAN : IT77W0306901020100000064149\nSi possible, indiquez un motif de paiement clair, par exemple \"Sonarpad\".';

  @override
  String get donationsThanks =>
      'Toute personne qui soutient le projet sera mentionnée dans l’application et dans le dépôt GitHub, sauf si elle préfère rester anonyme ou utiliser un pseudonyme.\n\nMerci à Jiri Holzinger et Paola Vagata pour leur contribution.\nPour la traduction en tchèque, merci à Radek Žalud et Jiri Holzinger.\nPour la traduction en espagnol, merci à Arturo Fernandez Rivas.';

  @override
  String get news => 'Actualités';

  @override
  String get newsHint => 'Ouvrir les actualités de Google News RSS';

  @override
  String get podcasts => 'Podcasts';

  @override
  String get podcastsHint =>
      'S\'abonner aux podcasts, lire ou télécharger des épisodes';

  @override
  String get importFromWikipedia => 'Wikipédia';

  @override
  String get wikipediaHint =>
      'Rechercher un article Wikipédia et importer le texte';

  @override
  String get newsCategoryTop => 'À la une';

  @override
  String get settingsHomeGrouping =>
      'Activer le regroupement des icônes d\'accueil en catégories';

  @override
  String get settingsHomeGroupingHint =>
      'Si désactivé, les icônes principales seront affichées sous forme de liste unique sans sous-dossiers';

  @override
  String get newsCategoryMyCity => 'Ma ville';

  @override
  String get newsLocalCityLabel => 'Saisissez votre ville';

  @override
  String get newsLocalCityHint =>
      'Corrigez la ville utilisée pour les actualités locales';

  @override
  String get update => 'Mettre à jour';

  @override
  String get moveUp => 'Déplacer vers le haut';

  @override
  String get moveDown => 'Déplacer vers le bas';

  @override
  String get hide => 'Masquer';

  @override
  String get moveToPosition => 'Déplacer à la position';

  @override
  String get sortPodcastsAlphabetically => 'Trier les podcasts alphabétiquement';

  @override
  String get sortRadioFavoritesAlphabetically => 'Trier les favoris radio alphabétiquement';

  @override
  String get podcastsSortedAlphabetically => 'Podcasts triés par ordre alphabétique.';

  @override
  String get radioFavoritesSortedAlphabetically => 'Radios favorites triées par ordre alphabétique.';

  @override
  String positionLabel(int position, String targetName) {
    return 'Position $position: avant $targetName';
  }

  @override
  String get positionLabelLast => 'Dernière position';

  @override
  String get restoreHiddenSources => 'Restaurer les sources masquées';

  @override
  String get addCustomNewsSource => 'Ajouter une source RSS personnalisée';

  @override
  String get newsSourceName => 'Nom de la source ou du site';

  @override
  String get newsSourceUrlOrSearch =>
      'URL du site, flux RSS ou mot de recherche';

  @override
  String get deleteNewsSource => 'Supprimer la source';

  @override
  String get importRssSourcesFromOpml =>
      'Importer des sources RSS depuis un fichier OPML';

  @override
  String get exportRssSourcesToOpml =>
      'Exporter les sources RSS vers un fichier OPML';

  @override
  String rssImportComplete(int count) {
    return 'Sources RSS importées : $count';
  }

  @override
  String rssImportError(Object error) {
    return 'Erreur d’importation RSS : $error';
  }

  @override
  String get rssExportComplete => 'Sources RSS exportées';

  @override
  String rssExportError(Object error) {
    return 'Erreur d’exportation RSS : $error';
  }

  @override
  String get articleTextSemantics => 'Texte de l\'article';

  @override
  String get newsLanguage => 'Langue des actualités';

  @override
  String get loadingNews => 'Chargement des actualités';

  @override
  String error(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get noNewsFound => 'Aucune actualité trouvée';

  @override
  String get loadingArticle => 'Chargement de l\'article';

  @override
  String get noFullArticleFound =>
      'Article complet indisponible. Affichage du résumé du flux.';

  @override
  String get italian => 'Italien';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get spanish => 'Espagnol';

  @override
  String get newsSource => 'Source d\'actualité';

  @override
  String get article => 'Article';

  @override
  String get articlePreview => 'Aperçu de l\'article';

  @override
  String get readFullArticle => 'Lire l\'article complet';

  @override
  String get extractingReaderArticleText =>
      'Extraction du texte en mode lecteur...';

  @override
  String get extractingVisibleArticleText =>
      'Extraction du texte visible de la page...';

  @override
  String source(String source) {
    return 'Source : $source';
  }

  @override
  String get readyStatus => 'Prêt.';

  @override
  String get preparingEdgeTts =>
      'Préparation de la lecture Edge TTS en blocs...';

  @override
  String get noTextToRead => 'Aucun texte à lire.';

  @override
  String chunkCreated(int index, int total) {
    return 'Bloc $index sur $total créé. Lecture en cours...';
  }

  @override
  String playingChunk(int index, int total, int size) {
    return 'Lecture du bloc $index sur $total ($size octets)...';
  }

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) {
    return 'Lecture terminée. Blocs créés : $readyChunks/$totalChunks. Bibliothèque : $libraryPath';
  }

  @override
  String get libraryNotSpecified => 'non spécifié';

  @override
  String get readingStopped => 'Lecture arrêtée.';

  @override
  String edgeTtsError(Object error) {
    return 'Erreur Edge TTS : $error';
  }

  @override
  String audioChunksReady(int readyChunks, int totalChunks) {
    return 'Blocs audio prêts : $readyChunks / $totalChunks';
  }

  @override
  String get readingInProgress => 'Lecture en cours...';

  @override
  String get readWithEdgeTts => 'Démarrer la lecture';

  @override
  String get stopReading => 'Arrêter la lecture';

  @override
  String get startReading => 'Démarrer la lecture';

  @override
  String get resumeReading => 'Reprendre la lecture';

  @override
  String get pauseReading => 'Mettre la lecture en pause';

  @override
  String get openOriginalArticle => 'Ouvrir l\'article original';

  @override
  String get searchPodcasts => 'Rechercher des podcasts';

  @override
  String get podcastName => 'Nom du podcast';

  @override
  String get podcastSearchHint =>
      'Exemple : technologie, histoire, le nom du podcast...';

  @override
  String get searchCountry => 'Pays de recherche';

  @override
  String get browsePodcastCountries => 'Parcourir par pays';

  @override
  String get podcastCountries => 'Pays des podcasts';

  @override
  String get podcastCategory => 'Catégorie de podcast';

  @override
  String get browsePodcastCategories => 'Parcourir les catégories';

  @override
  String get selectedPodcastCategory => 'Catégorie sélectionnée';

  @override
  String get selectedRecently => 'choix récent';

  @override
  String get podcastCategories => 'Catégories de podcasts';

  @override
  String get countryItaly => 'Italie';

  @override
  String get countryUnitedStatesEnglish => 'États-Unis / Anglais';

  @override
  String get countryUnitedKingdom => 'Royaume-Uni';

  @override
  String get countrySpain => 'Espagne';

  @override
  String get countryFrance => 'France';

  @override
  String get searchInProgress => 'Recherche en cours...';

  @override
  String get newsReadArticles => 'Articles lus';

  @override
  String get weatherRecentCities => 'Villes récentes';

  @override
  String podcastResultsFound(int count) {
    return '$count podcasts trouvés';
  }

  @override
  String podcastSearchError(Object error) {
    return 'Erreur de recherche de podcast : $error';
  }

  @override
  String subscribedTo(String title) {
    return 'Abonné à $title';
  }

  @override
  String subscriptionError(Object error) {
    return 'Erreur d\'abonnement : $error';
  }

  @override
  String podcastSubscriptionError(Object error) {
    return 'Erreur d\'abonnement au podcast : $error';
  }

  @override
  String get searchResults => 'Résultats de recherche';

  @override
  String get podcastInfo => 'Informations sur le podcast';

  @override
  String get subscribe => 'S\'abonner';

  @override
  String get openPodcast => 'Ouvrir le podcast';

  @override
  String get viewEpisodes => 'Voir les épisodes';

  @override
  String get podcastAuthor => 'Auteur';

  @override
  String get noPodcastDescription => 'Aucune description disponible.';

  @override
  String get noPodcastResults => 'Aucun podcast trouvé.';

  @override
  String get loadingPodcastInfo => 'Chargement des infos du podcast';

  @override
  String get podcastArtwork => 'Pochette du podcast';

  @override
  String get addFeedUrlManually => 'Ajouter l\'URL du flux RSS manuellement';

  @override
  String get podcastFeedUrl => 'URL du flux RSS du podcast';

  @override
  String get subscribeFromUrl => 'S\'abonner à partir de l\'URL';

  @override
  String get subscribedPodcasts => 'Abonnements aux podcasts';

  @override
  String get noSubscribedPodcasts =>
      'Aucun abonnement aux podcasts. Recherchez un podcast et touchez un résultat pour vous abonner.';

  @override
  String get localAudioFiles => 'Fichiers audio locaux';

  @override
  String get noLocalAudioFiles => 'Aucun fichier audio local trouvé.';

  @override
  String get importAudioFromITunes => 'Importer des fichiers audio locaux';

  @override
  String localAudioFilesFound(int count) {
    return 'Fichiers audio locaux trouvés : $count';
  }

  @override
  String get importPodcastsFromFile =>
      'Importer des podcasts depuis un fichier';

  @override
  String get exportPodcastsToFile =>
      'Exporter les podcasts vers un fichier OPML';

  @override
  String podcastImportComplete(int count) {
    return 'Podcasts importés : $count';
  }

  @override
  String podcastImportError(Object error) {
    return 'Erreur d\'importation des podcasts : $error';
  }

  @override
  String get podcastInvalidOpmlFile =>
      'Fichier non valide. Sélectionnez un fichier OPML ou XML.';

  @override
  String get podcastExportComplete => 'Podcasts exportés';

  @override
  String podcastExportError(Object error) {
    return 'Erreur d\'exportation des podcasts : $error';
  }

  @override
  String get loadingEpisodes => 'Chargement des épisodes';

  @override
  String get noAudioEpisodesFound => 'Aucun épisode audio trouvé dans le flux.';

  @override
  String get episodes => 'Épisodes';

  @override
  String get episodeActions => 'Actions de l\'épisode';

  @override
  String downloaded(String path) {
    return 'Téléchargé : $path';
  }

  @override
  String episodeError(Object error) {
    return 'Erreur de l\'épisode : $error';
  }

  @override
  String get play => 'Lire';

  @override
  String get pause => 'Pause';

  @override
  String get rewind15s => 'Reculer de 15s';

  @override
  String get forward15s => 'Avancer de 15s';

  @override
  String get stop => 'Arrêter';

  @override
  String get back => 'Retour';

  @override
  String get episodePlayer => 'Lecteur d\'épisode';

  @override
  String nowPlayingTitle(String title) {
    return 'En lecture : $title';
  }

  @override
  String get loadingEpisodeAudio => 'Chargement de l\'audio de l\'épisode';

  @override
  String get playbackPosition => 'Position';

  @override
  String playbackPositionValue(String position, String duration) {
    return '$position sur $duration';
  }

  @override
  String get adjustVolume => 'Régler le volume';

  @override
  String volumeValue(int percentage) {
    return 'Volume : $percentage%';
  }

  @override
  String get download => 'Télécharger';

  @override
  String get searchWikipedia => 'Rechercher sur Wikipédia';

  @override
  String get wikipediaLanguage => 'Langue Wikipédia';

  @override
  String get search => 'Rechercher';

  @override
  String get wikipediaSearch => 'Recherche Wikipédia';

  @override
  String get wikipediaImporting => 'Importation Wikipédia';

  @override
  String get noWikipediaResults => 'Aucun résultat Wikipédia trouvé';

  @override
  String get wikipediaImportMode => 'Mode d\'importation';

  @override
  String get wikipediaImportWholeArticle => 'Article complet';

  @override
  String get documents => 'Documents';

  @override
  String get documentsHint => 'Ouvrir la bibliothèque de documents';

  @override
  String get documentLibrary => 'Bibliothèque de documents';

  @override
  String get addToLibrary => 'Ajouter à la bibliothèque';

  @override
  String get documentImportSelectionMode =>
      'Voulez-vous sélectionner un document ou plusieurs documents ?';

  @override
  String get documentImportSingle => 'Un document';

  @override
  String get documentImportMultiple => 'Plusieurs documents';

  @override
  String get noDocuments => 'Aucun document. Ajoutez un fichier.';

  @override
  String get noDocumentsInLibrary => 'Aucun document dans la bibliothèque.';

  @override
  String get documentAdded => 'Document ajouté';

  @override
  String get documentsAdded => 'Documents ajoutés';

  @override
  String get importDocumentsFromITunes =>
      'Importer des documents depuis iTunes / Apple Devices';

  @override
  String sharedDocumentsImportComplete(int count) {
    return 'Documents importés depuis iTunes / Apple Devices : $count';
  }

  @override
  String libraryLoadError(Object error) {
    return 'Erreur de chargement de la bibliothèque : $error';
  }

  @override
  String fileOpenError(Object error) {
    return 'Erreur d\'ouverture du fichier : $error';
  }

  @override
  String get filePathUnavailable => 'Chemin du fichier indisponible.';

  @override
  String fileInaccessible(String name) {
    return 'Fichier inaccessible : $name';
  }

  @override
  String documentAddError(Object error) {
    return 'Erreur d\'ajout du document : $error';
  }

  @override
  String documentRemoveError(Object error) {
    return 'Erreur de suppression : $error';
  }

  @override
  String get noExportableTextFound => 'Aucun texte exportable trouvé.';

  @override
  String get modifiedDocumentNoExportableText =>
      'Le document modifié ne contient aucun texte exportable.';

  @override
  String get documentRemoved => 'Document supprimé';

  @override
  String get folderRemoved => 'Dossier supprimé';

  @override
  String get removeFolder => 'Supprimer le dossier';

  @override
  String get removeDocument => 'Supprimer le document';

  @override
  String get writeNewDocument => 'Écrire un nouveau document';

  @override
  String get addDocumentToLibraryHint =>
      'Ajouter un document à la bibliothèque. Parcourez les fichiers de l’appareil et ajoutez-les.';

  @override
  String get documentTypeLabel => 'Document';

  @override
  String get documentPosition => 'Position du document';

  @override
  String get folderTypeLabel => 'Dossier';

  @override
  String documentAddedOn(String date) {
    return 'ajouté le $date';
  }

  @override
  String documentTypeDescription(String extension) {
    return 'type $extension';
  }

  @override
  String get openFolderHint => 'Touchez deux fois pour ouvrir le dossier';

  @override
  String get openDocumentHint =>
      'Touchez deux fois pour ouvrir et lire le document';

  @override
  String removeItem(String name) {
    return 'Supprimer $name';
  }

  @override
  String get removePodcast => 'Supprimer le podcast';

  @override
  String get podcastRemoved => 'Podcast supprimé';

  @override
  String get documentPickerError => 'Erreur d\'ouverture du fichier';

  @override
  String get readDocument => 'Lire le document';

  @override
  String get documentReaderTitle => 'Lecteur de document';

  @override
  String get documentReaderEditHint =>
      'Touchez un paragraphe pour le modifier. Balayez vers le haut ou vers le bas pour ajouter un signet.';

  @override
  String get documentBookmarkHintSet =>
      'Balayez vers le haut ou vers le bas pour définir un signet.';

  @override
  String get documentEditParagraphActionHint =>
      'Touchez deux fois pour modifier ce paragraphe. ';

  @override
  String get documentBookmarkHintReplace =>
      'Balayez vers le haut ou vers le bas pour supprimer le signet existant ou le remplacer par ce paragraphe.';

  @override
  String get documentSetBookmarkAction => 'Ajouter un nouveau signet';

  @override
  String get documentRemoveBookmarkAction => 'Supprimer le signet';

  @override
  String get documentReplaceBookmarkAction =>
      'Supprimer et ajouter un nouveau signet';

  @override
  String get searchInDocument => 'Rechercher dans le document';

  @override
  String get documentIndex => 'Table des matières';

  @override
  String get documentFootnoteLabel => 'Note de bas de page';

  @override
  String get documentSearchFieldLabel => 'Texte à rechercher';

  @override
  String get documentSearchFieldHint => 'Mot ou phrase à trouver';

  @override
  String get documentSearchEmptyQuery => 'Saisissez le texte à rechercher.';

  @override
  String get documentSearchResultsTitle => 'Résultats de recherche du document';

  @override
  String noDocumentSearchResults(String query) {
    return 'Aucun résultat trouvé pour $query.';
  }

  @override
  String documentSearchResultParagraph(int number) {
    return 'Paragraphe $number';
  }

  @override
  String get edit => 'Modifier';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get settingsReadingEngine => 'Moteur de lecture';

  @override
  String get settingsEdgeTtsQuality => 'Edge TTS (Haute qualité en ligne)';

  @override
  String get settingsSystemVoices => 'Voix système (VoiceOver / Google)';

  @override
  String get settingsNoSystemVoices => 'Aucune voix système disponible.';

  @override
  String get settingsDefaultVoiceHint => 'Voix par défaut';

  @override
  String get settingsDefaultVoice => 'Défaut';

  @override
  String get settingsVoiceSpeed => 'Vitesse: ';

  @override
  String get settingsVoicePitch => 'Ton: ';

  @override
  String get settingsVoiceSpeedLabel => 'Vitesse de lecture';

  @override
  String get settingsVoicePitchLabel => 'Ton';

  @override
  String get settingsTestVoice => 'Tester la voix';

  @override
  String get settingsTestingVoice => 'Lecture...';

  @override
  String get settingsVoiceTestText =>
      'Ceci est un test de la voix sélectionnée.';

  @override
  String settingsVoiceTestError(Object error) {
    return 'Erreur du test vocal : $error';
  }

  @override
  String settingsVoiceSaveError(Object error) {
    return 'Erreur d’enregistrement de la voix TTS : $error';
  }

  @override
  String get settingsUnsavedTitle => 'Modifications non enregistrées';

  @override
  String get settingsUnsavedMessage =>
      'Voulez-vous enregistrer les modifications avant de quitter les paramètres ?';

  @override
  String get settingsExitWithoutSaving => 'Quitter sans enregistrer';

  @override
  String get settingsSystemLanguage => 'Langue système';

  @override
  String get settingsSystemVoice => 'Voix système';

  @override
  String get settingsAutoBookmark => 'Reprise automatique';

  @override
  String get settingsAutoBookmarkHint =>
      'Reprenez les documents, les podcasts et les contenus multimédias là où vous les aviez laissés.';

  @override
  String get settingsIncludeFootnotesInText => 'Inclure les notes de bas de page dans le texte';

  @override
  String get settingsIncludeFootnotesInTextHint =>
      'Pour les EPUB compatibles, affiche le texte de la note juste après le paragraphe qui la cite.';

  @override
  String get settingsDocumentSliderStep => 'Pas du curseur des documents';

  @override
  String get settingsDocumentSliderStepHint =>
      'Règle de combien le curseur de position du document avance ou recule avec un balayage vers le haut ou vers le bas.';

  @override
  String get settingsReadingSleepTimer => "Minuteur d’arrêt de lecture";

  @override
  String get settingsReadingSleepTimerOff => "Désactivé";

  @override
  String settingsReadingSleepTimerMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get settingsReadingSleepTimerHint => "Arrête automatiquement la lecture du document en cours après la durée choisie et enregistre le point d’arrêt. Le compte à rebours redémarre chaque fois que vous lancez la lecture d’un document.";

  @override
  String get documentReadingSleepTimerStopped => "Minuteur d’arrêt : lecture arrêtée et position enregistrée.";

  @override
  String get settingsSeekStep =>
      'Pas de retour / avance rapide pour les médias';

  @override
  String get aiChatIntro =>
      'Je suis l’intelligence artificielle de Sonarpad. Comment puis-je vous aider ?';

  @override
  String get meteoTitle => 'Météo';

  @override
  String get weatherCity => 'Ville';

  @override
  String get weatherCityHint => 'Exemple : Rome';

  @override
  String get weatherCityNotFound => 'Ville introuvable';

  @override
  String get weatherSearchError => 'Erreur lors de la recherche';

  @override
  String get weatherToday => 'Aujourd\'hui';

  @override
  String get weatherCurrentSituation => 'Situation actuelle';

  @override
  String get weatherTomorrow => 'Demain';

  @override
  String get weatherChooseDay => 'Choisir le jour';

  @override
  String get weatherCurrentTemperature => 'Température actuelle';

  @override
  String get weatherMaxTemperature => 'Température maximale';

  @override
  String get weatherMinTemperature => 'Température minimale';

  @override
  String get weatherPrecipitation => 'Précipitations';

  @override
  String get weatherPrecipitationProbability => 'Probabilité de précipitations';

  @override
  String get weatherWind => 'Vent';

  @override
  String get weatherRelativeHumidity => 'Humidité relative';

  @override
  String get settingsSecretCode =>
      'Code Sonarpad pour les fonctionnalités supplémentaires';

  @override
  String get settingsRequestCode => 'Demander le code à l\'auteur';

  @override
  String get settingsPasteCode => 'Coller le code';

  @override
  String get settingsCancel => 'Annuler';

  @override
  String get settingsSend => 'Envoyer';

  @override
  String get settingsFillFieldsCode =>
      'Remplissez tous les champs pour demander le code.';

  @override
  String get settingsName => 'Prénom';

  @override
  String get settingsSurname => 'Nom';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsOperatingSystem => 'Système d’exploitation';

  @override
  String settingsCodeRequestBody(
      String name, String surname, String email, String os) {
    return 'Prénom: $name; Nom: $surname; E-mail: $email; Système d’exploitation: $os';
  }

  @override
  String get settingsNameOptional => 'Prénom (facultatif)';

  @override
  String get settingsMessageOptional => 'Message (facultatif)';

  @override
  String get settingsVerifyCodeAndSave => 'Vérification et enregistrement...';

  @override
  String get settingsViewSysLog => 'Voir le journal système';

  @override
  String settingsMailOpenError(Object error) {
    return 'Erreur d’ouverture de l’e-mail : $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get invia => 'Envoyer';

  @override
  String get saveArticle => 'Enregistrer l\'article';

  @override
  String get shareArticle => 'Partager l\'article';

  @override
  String get articleSavedSuccess => 'Article enregistré dans les Documents';

  @override
  String get annulla => 'Annuler';

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice =>
      'Remplissez tous les champs pour demander le code.';

  @override
  String get selectFolder => 'Sélectionner le dossier';

  @override
  String get exportDocument => 'Exporter le document';

  @override
  String get exportFormatPrompt =>
      'Dans quel format souhaitez-vous exporter le document ?';

  @override
  String get textFormat => 'Texte (.txt)';

  @override
  String get pdfFormat => 'PDF (.pdf)';

  @override
  String get docxFormat => 'DOCX (.docx)';

  @override
  String get epubFormat => 'EPUB (.epub)';

  @override
  String get exportError => 'Erreur d\'exportation';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get folderNameHint => 'Nom du dossier';

  @override
  String get create => 'Créer';

  @override
  String get createNewFolder => 'Créer un nouveau dossier';

  @override
  String get importExternalSources => 'Importer depuis des sources externes';

  @override
  String get importExternalSourcesTitle => 'Sources externes';

  @override
  String get importFromDropbox => 'Importer des documents depuis Dropbox';

  @override
  String get importFromProjectGutenberg => 'Importer depuis Project Gutenberg';

  @override
  String get projectGutenbergImportUnavailable =>
      'L\'importation depuis Project Gutenberg n\'est pas encore disponible.';

  @override
  String get importFromInternetArchive => 'Importer depuis Internet Archive';

  @override
  String get internetArchiveTitle => 'Internet Archive';

  @override
  String get internetArchiveSearchLabel => 'Rechercher de l\'audio';

  @override
  String get internetArchiveSourceLabel => 'Source';

  @override
  String get internetArchiveOldTimeRadio => 'Old Time Radio';

  @override
  String get internetArchiveSpeeches => 'Discours historiques';

  @override
  String get internetArchiveLiveMusic => 'Live Music Archive';

  @override
  String get internetArchiveNoItemsFound => 'Aucun élément audio trouvé.';

  @override
  String get saveAudioInDocuments => 'Enregistrer l\'audio dans Documents';

  @override
  String get audioSavedInDocuments => 'Audio enregistré dans Documents.';

  @override
  String get noAudioTracksAvailable => 'Aucune piste audio disponible.';

  @override
  String get importFromLibriVox => 'Importer depuis LibriVox';

  @override
  String get gutenbergSearchLabel => 'Rechercher un livre ou un auteur';

  @override
  String get sourceLanguageLabel => 'Langue';

  @override
  String get noGutenbergBooksFound => 'Aucun livre trouvé.';

  @override
  String get loadMore => 'Charger plus';

  @override
  String sourceLanguageValue(String language) {
    return 'Langue : $language';
  }

  @override
  String get gutenbergImportAndRead => 'Importer et lire';

  @override
  String get gutenbergImporting => 'Importation...';

  @override
  String get librivoxSearchLabel => 'Rechercher un livre audio';

  @override
  String get noLibrivoxAudiobooksFound => 'Aucun livre audio trouvé.';

  @override
  String get librivoxAudiobookSaved => 'Livre audio enregistré dans Documents.';

  @override
  String get librivoxSaveAudiobook =>
      'Enregistrer le livre audio dans Documents';

  @override
  String get librivoxSaving => 'Enregistrement...';

  @override
  String get librivoxNoAudioTracks => 'Aucune piste audio disponible.';

  @override
  String get librivoxNotTextExportable =>
      'Les livres audio LibriVox ne peuvent pas être exportés en texte.';

  @override
  String sourceDurationValue(String duration) {
    return 'Durée : $duration';
  }

  @override
  String get importFromPoetryDb => 'Importer depuis PoetryDB';

  @override
  String get poetryDbSearchLabel => 'Rechercher un poème';

  @override
  String get poetryDbSearchBy => 'Rechercher par';

  @override
  String get poetryDbSearchByTitle => 'Titre';

  @override
  String get poetryDbSearchByAuthor => 'Auteur';

  @override
  String get poetryDbNoPoemsFound => 'Aucun poème trouvé.';

  @override
  String poetryDbLineCount(int count) {
    return '$count vers';
  }

  @override
  String get moveDocument => 'Déplacer le document';

  @override
  String get documentMoved => 'Déplacé avec succès';

  @override
  String get outOfFolder => 'Hors du dossier';

  @override
  String get moveToAnotherFolder => 'Déplacer vers un autre dossier...';

  @override
  String get ttsError => 'Erreur de synthèse vocale';

  @override
  String get editParagraph => 'Modifier le paragraphe';

  @override
  String get editParagraphTextField =>
      'Champ de texte pour modifier le paragraphe';

  @override
  String get editParagraphHint => 'Modifier le texte du paragraphe';

  @override
  String get applyAndSave => 'Appliquer et enregistrer';

  @override
  String get textEditedAndSaved =>
      'Texte modifié et enregistré dans le document actuel.';

  @override
  String get saveError => 'Erreur lors de la sauvegarde';

  @override
  String get docSavedInLibrary => 'Document enregistré dans la bibliothèque';

  @override
  String get saveInLibrary => 'Enregistrer dans la bibliothèque';

  @override
  String get documentTextLabel => 'Texte du document';

  @override
  String get modifiedInSonarpad => 'Modifié dans Sonarpad';

  @override
  String get noTextAvailableForDocument =>
      'Aucun texte disponible pour ce document.';

  @override
  String bookmarkSet(int index) {
    return 'Signet défini au paragraphe $index.';
  }

  @override
  String get bookmarkRemoved => 'Signet supprimé.';


  @override
  String get settingsMultipleDocumentBookmarks => 'Autoriser plusieurs signets dans les documents';

  @override
  String get settingsMultipleDocumentBookmarksHint =>
      'Si cette option est désactivée, un seul signet est conservé par document. Si elle est activée, vous pouvez enregistrer plusieurs signets dans le même document.';



  @override
  String get pharmacyFeatureTitle => 'Médicaments, parapharmacie et compléments';

  @override
  String get pharmacyProductsSectionTitle => 'Parapharmacie et compléments';

  @override
  String get pharmacyProductsLoadingTitle => 'Recherche de parapharmacie et de compléments...';

  @override
  String get pharmacyProductsErrorTitle => 'Erreur lors de la recherche de parapharmacie et de compléments';

  @override
  String get pharmacyProductsNoResultsTitle => 'Aucun produit de parapharmacie ou complément trouvé';

  @override
  String get settingsVideoLandscapeFullscreen => 'Vidéo horizontale en plein écran';
  @override
  String get settingsVideoLandscapeFullscreenHint =>
      'Lorsque vous activez la vidéo, elle s’affiche en plein écran en orientation horizontale. Les radios uniquement audio ne changent pas.';

  @override
  String get settingsPodcastCacheTitle => 'Cache des podcasts';

  @override
  String get settingsPodcastCacheHint => 'Videz les fichiers temporaires des podcasts sans supprimer les abonnements, l’historique ou les fichiers audio importés. Sonarpad nettoie aussi automatiquement ce cache lorsqu’il devient trop volumineux ou contient d’anciens fichiers.';

  @override
  String settingsPodcastCacheSize(String size) {
    return 'Espace utilisé : $size';
  }

  @override
  String get clearPodcastCache => 'Vider le cache des podcasts';

  @override
  String get confirmClearPodcastCacheTitle => 'Vider le cache des podcasts ?';

  @override
  String get confirmClearPodcastCacheMessage => 'Les fichiers temporaires des podcasts seront supprimés. Les abonnements et l’historique des épisodes seront conservés.';

  @override
  String podcastCacheCleared(String size) {
    return 'Cache des podcasts vidé : $size libérés.';
  }

  @override
  String get podcastCacheEmpty => 'Le cache des podcasts est déjà vide.';

  @override
  String get documentGoToBookmarkAction => 'Aller au signet';

  @override
  String get documentChooseBookmarkTitle => 'Choisir un signet';

  @override
  String get documentDeleteBookmarkAction => 'Supprimer le signet';

  @override
  String get documentKeepBookmarkTitle => 'Quel signet voulez-vous conserver ?';

  @override
  String get documentKeepBookmarkMessage =>
      'Les signets multiples sont désactivés. Choisissez le signet à conserver : les autres seront supprimés.';

  @override
  String documentBookmarkChoiceLabel(int order, int paragraph) {
    return 'Signet {order}, paragraphe {paragraph}'
        .replaceAll('{order}', '$order')
        .replaceAll('{paragraph}', '$paragraph');
  }

  @override
  String documentBookmarkChoiceLabelWithPreview(
    int order,
    int paragraph,
    String preview,
  ) {
    return 'Signet {order}, paragraphe {paragraph}. {preview}'
        .replaceAll('{order}', '$order')
        .replaceAll('{paragraph}', '$paragraph')
        .replaceAll('{preview}', preview);
  }

  @override
  String get docEmpty => 'Le document est vide';

  @override
  String get docSavedSuccessfully => 'Document enregistré avec succès !';

  @override
  String get writeDocument => 'Écrire un document';

  @override
  String get documentTitleOptional => 'Titre (facultatif)';

  @override
  String get documentTitleHint => 'Exemple : Notes de courses';

  @override
  String get documentTextField => 'Texte du document';

  @override
  String get documentTextHint => 'Commencez à écrire ici...';

  @override
  String get newDocumentDefaultName => 'Nouveau_Document';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get saveDocument => 'Enregistrer le document';

  @override
  String get addRssSource => 'Ajouter une source RSS';

  @override
  String get add => 'Ajouter';

  @override
  String get errorPrefix => 'Erreur';

  @override
  String versionBuild(String version, String buildNumber) {
    return 'Version $version (Build $buildNumber)';
  }

  @override
  String get whatIsNew => 'Nouveautés';

  @override
  String whatIsNewInVersion(String version) {
    return 'Nouveautés de la version $version';
  }

  @override
  String changelogLoadError(Object error) {
    return 'Erreur lors du chargement des nouveautés : $error';
  }

  @override
  String get visitSonarpadSite => 'Visiter le site de Sonarpad';

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return 'Visiter le site de Sonarpad : $url';
  }

  @override
  String get nowPlaying => 'En lecture';

  @override
  String get fileImported => 'Fichier importé';

  @override
  String importZipError(Object error) {
    return 'Erreur d’importation ZIP : $error';
  }

  @override
  String get dropboxLoginPrompt =>
      'Connectez-vous à Dropbox pour importer vos documents.';

  @override
  String get loginToDropbox => 'Se connecter à Dropbox';

  @override
  String get logoutFromDropbox => 'Se déconnecter';

  @override
  String get dropboxLoginFailed => 'Connexion échouée ou annulée';

  @override
  String dropboxLoadFolderError(Object error) {
    return 'Erreur de chargement du dossier : $error';
  }

  @override
  String dropboxImportError(Object error) {
    return 'Erreur d’importation : $error';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String get goBack => 'Retour';

  @override
  String get noSupportedFilesInFolder =>
      'Aucun fichier pris en charge dans ce dossier.';

  @override
  String get articleNotFound => 'Article introuvable.';

  @override
  String get errorOpening => 'Erreur d\'ouverture';

  @override
  String get recentArticles => 'Articles récents';

  @override
  String get clearHistory => 'Effacer l\'historique';

  @override
  String get confirmClearHistory =>
      'Voulez-vous vraiment effacer toutes les recherches récentes ?';

  @override
  String get clear => 'Effacer';

  @override
  String get noRecentSearches => 'Aucune recherche récente.';

  @override
  String get logCopiedToClipboard => 'Journal copié dans le presse-papiers';

  @override
  String get logCleared => 'Log vidé';

  @override
  String get parafarmacoDetailReadyAnnouncement => 'Fiche produit chargée. Balayez vers la droite pour choisir les sections.';

  @override
  String get systemLog => 'Journal système';

  @override
  String get clearSystemLog => 'Vider le journal';

  @override
  String get copySystemLog => 'Copier le journal';

  @override
  String get donateWithPaypal => 'Faire un don avec PayPal';

  @override
  String get bankTransferTitle => 'Virement bancaire';

  @override
  String get enableVideo => 'Activer la vidéo';

  @override
  String get calendar => 'Calendrier';

  @override
  String get calendarHint =>
      'Afficher le calendrier, les jours fériés, le saint du jour et vos rappels';

  @override
  String get saintOfTheDay => 'Saint du jour';

  @override
  String get quoteOfTheDay => 'Citation du jour';

  @override
  String get reminders => 'Rappels';

  @override
  String get addReminder => 'Ajouter un rappel';

  @override
  String get removeReminder => 'Supprimer le rappel';

  @override
  String get noReminders => 'Aucun rappel';

  @override
  String get writeReminder => 'Écrivez votre rappel ici...';

  @override
  String get saveReminder => 'Enregistrer';

  @override
  String get cancelReminder => 'Annuler';

  @override
  String get backToToday => 'Retour à aujourd\'hui';

  @override
  String get calendarToday => 'Aujourd\'hui';

  @override
  String get calendarTomorrow => 'Demain';

  @override
  String get calendarYesterday => 'Hier';

  @override
  String get share => 'Partager';

  @override
  String get shareCalendarDayOptions => 'Options de partage';

  @override
  String get shareCalendarDayOnly => 'Partager uniquement la journée';

  @override
  String get shareCalendarDayWithReminder => 'Partager la journée et le rappel';

  @override
  String get listenToAll => 'Tout écouter';

  @override
  String reminderSaved(int count) {
    return '$count rappels';
  }

  @override
  String get audiodescriptionTitle => 'Audiodescriptions Rai';

  @override
  String get audiodescriptionRecent => 'Récentes';

  @override
  String get audiodescriptionAll => 'Toutes les audiodescriptions';

  @override
  String get audiodescriptionFilm => 'Films';

  @override
  String get audiodescriptionSearch => 'Rechercher...';

  @override
  String get audiodescriptionLoading => 'Chargement en cours...';

  @override
  String get audiodescriptionError => 'Erreur de chargement du catalogue';

  @override
  String get audiodescriptionEmpty => 'Aucun élément trouvé';

  @override
  String get radio => 'Radio';

  @override
  String get radioHint =>
      'Rechercher des stations de radio, écouter des flux et gérer les favoris';

  @override
  String get radioTitle => 'Stations de radio du monde entier';

  @override
  String get radioFavoritesButton => 'Stations de radio favorites';

  @override
  String get radioNoFavorites => 'Aucune station de radio favorite.';

  @override
  String get radioSearchText => 'Rechercher une station de radio';

  @override
  String get radioSearchHint => 'Nom de la station ou ville...';

  @override
  String get radioLanguage => 'Langue';

  @override
  String get radioBrowseBy => 'Parcourir par';

  @override
  String get radioBrowseByLanguage => 'Parcourir par langue';

  @override
  String get radioBrowseByCountry => 'Parcourir par pays';

  @override
  String get radioCountry => 'Pays';

  @override
  String get radioGenre => 'Genre';

  @override
  String get radioActiveFilters => 'Filtres actifs';

  @override
  String get radioResetFilters => 'Réinitialiser les filtres';

  @override
  String get radioFiltersReset => 'Filtres réinitialisés.';

  @override
  String get radioCity => 'Ville';

  @override
  String get radioSearch => 'Recherche';

  @override
  String get radioSearching => 'Chargement des radios...';

  @override
  String get radioSearchResults => 'Résultats radio';

  @override
  String get radioNoResults => 'Aucune radio trouvée.';

  @override
  String radioResultsFound(int count) {
    return '$count stations de radio trouvées';
  }

  @override
  String radioSearchError(Object error) {
    return 'Erreur de recherche radio : $error';
  }

  @override
  String radioNowPlaying(String name) {
    return 'Lecture de $name';
  }

  @override
  String radioPlayError(Object error) {
    return 'Erreur de flux radio : $error';
  }

  @override
  String get radioAddFavorite => 'Ajouter aux favoris';

  @override
  String get radioRemoveFavorite => 'Retirer des favoris';

  @override
  String radioFavoriteAdded(String name) {
    return '$name ajoutée aux favoris.';
  }

  @override
  String radioFavoriteRemoved(String name) {
    return '$name retirée des favoris.';
  }

  @override
  String get tvSearchFieldLabel => 'Rechercher des chaînes TV';

  @override
  String get tvSearchFieldHint => 'Nom de la chaîne...';

  @override
  String get tvSearchButton => 'Rechercher';

  @override
  String get tvSearchResults => 'Résultats des chaînes TV';

  @override
  String get tvSearchEmptyQuery =>
      'Saisissez le nom d’une chaîne TV à rechercher.';

  @override
  String tvSearchNoResults(String query) {
    return 'Aucune chaîne TV trouvée pour $query.';
  }

  @override
  String get tvOpenChannelHint => 'Touchez pour lire la chaîne TV';

  @override
  String tvNowOnAir(String title) {
    return 'En ce moment : $title';
  }

  @override
  String get radioAddCommunity => 'Ajouter une radio à la communauté Sonarpad';

  @override
  String get radioAddName => 'Nom de la radio';

  @override
  String get radioAddUrl => 'Adresse du flux';

  @override
  String get radioAddSubmit => 'Vérifier et ajouter';

  @override
  String get radioAddMissingFields =>
      'Veuillez saisir le nom de la radio et l\'adresse du flux.';

  @override
  String get radioCommunityAdded =>
      'Radio ajoutée avec succès à la communauté Sonarpad.';

  @override
  String radioCommunityAddError(Object error) {
    return 'Erreur lors de l\'ajout de la radio : $error';
  }

  @override
  String get radioPlay => 'Lire';

  @override
  String get startRecording => 'Démarrer l\'enregistrement';

  @override
  String get stopRecording => 'Arrêter l\'enregistrement';

  @override
  String get recordings => 'Enregistrements';

  @override
  String get noRecordings => 'Aucun enregistrement.';

  @override
  String get recordingStarted => 'Enregistrement démarré.';

  @override
  String recordingSaved(Object path) {
    return 'Enregistrement sauvegardé : $path';
  }

  @override
  String recordingError(Object error) {
    return 'Erreur d\'enregistrement : $error';
  }

  @override
  String get routeTitle => 'Itinéraires';

  @override
  String get routeFrom => 'De';

  @override
  String get routeTo => 'À';

  @override
  String get routeCountry => 'Pays';

  @override
  String get routeCountryItaly => 'Italie';

  @override
  String get routeCountryFrance => 'France';

  @override
  String get routeCountrySpain => 'Espagne';

  @override
  String get routeCountryCzechRepublic => 'République tchèque';

  @override
  String get routeVehicle => 'Mode de transport';

  @override
  String get routeType => 'Type';

  @override
  String get routeIncludeMunicipalities => 'Inclure les communes traversées';

  @override
  String get routeWalking => 'À pied';

  @override
  String get routeCycling => 'À vélo';

  @override
  String get routeDriving => 'En voiture';

  @override
  String get routeWheelchair => 'En fauteuil roulant';

  @override
  String get routeFastest => 'Le plus rapide';

  @override
  String get routeShortest => 'Le plus court';

  @override
  String get routeCalculate => 'Calculer l\'itinéraire';

  @override
  String get routeCalculating => 'Calcul en cours...';

  @override
  String get routeChooseFrom => 'Choisir le départ';

  @override
  String get routeChooseTo => 'Choisir la destination';

  @override
  String get routeCancel => 'Annuler';

  @override
  String get routeErrorMissingFields =>
      'Veuillez saisir le point de départ et la destination';

  @override
  String get routeErrorFromNotFound =>
      'Aucun résultat trouvé pour l\'adresse de départ';

  @override
  String get routeErrorToNotFound =>
      'Aucun résultat trouvé pour l\'adresse de destination';

  @override
  String get routeResultsTitle => 'Itinéraires disponibles';

  @override
  String get routeDistance => 'Distance';

  @override
  String get routeDuration => 'Durée';

  @override
  String get routeNavigation => 'Détails de la navigation';

  @override
  String get routeStartMunicipality => 'Commune de départ';

  @override
  String get routeEnterMunicipality => 'Vous entrez dans la commune de';

  @override
  String routeError(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get radioLanguageIt => 'Italien';

  @override
  String get radioLanguageEn => 'Anglais';

  @override
  String get radioLanguageDe => 'Allemand';

  @override
  String get radioLanguageCountryCh => 'Suisse';

  @override
  String get radioLanguageEs => 'Espagnol';

  @override
  String get radioLanguagePt => 'Portugais';

  @override
  String get radioLanguageSv => 'Suédois';

  @override
  String get radioLanguageVi => 'Vietnamien';

  @override
  String get radioLanguageCs => 'Tchèque';

  @override
  String get radioLanguagePl => 'Polonais';

  @override
  String get radioLanguageFr => 'Français';

  @override
  String get radioLanguageSr => 'Serbe';

  @override
  String get radioLanguageUk => 'Ukrainien';

  @override
  String get radioLanguageHi => 'Hindi';

  @override
  String get radioLanguageLt => 'Lituanien';

  @override
  String get radioLanguageRu => 'Russe';

  @override
  String get radioLanguageZh => 'Chinois';

  @override
  String get radioCountryOptionIt => 'Italie';

  @override
  String get radioCountryOptionUs => 'États-Unis';

  @override
  String get radioCountryOptionGb => 'Royaume-Uni';

  @override
  String get radioCountryOptionFr => 'France';

  @override
  String get radioCountryOptionEs => 'Espagne';

  @override
  String get radioCountryOptionDe => 'Allemagne';

  @override
  String get radioCountryOptionCh => 'Suisse';

  @override
  String get radioCountryOptionAt => 'Autriche';

  @override
  String get radioCountryOptionBe => 'Belgique';

  @override
  String get radioCountryOptionNl => 'Pays-Bas';

  @override
  String get radioCountryOptionPt => 'Portugal';

  @override
  String get radioCountryOptionBr => 'Brésil';

  @override
  String get radioCountryOptionAr => 'Argentine';

  @override
  String get radioCountryOptionMx => 'Mexique';

  @override
  String get radioCountryOptionCa => 'Canada';

  @override
  String get radioCountryOptionAu => 'Australie';

  @override
  String get radioCountryOptionIe => 'Irlande';

  @override
  String get radioCountryOptionSe => 'Suède';

  @override
  String get radioCountryOptionPl => 'Pologne';

  @override
  String get radioCountryOptionJp => 'Japon';

  @override
  String get radioGenreOptionAll => 'Tous les genres';

  @override
  String get radioGenreOptionNews => 'Actualités';

  @override
  String get radioGenreOptionMusic => 'Musique';

  @override
  String get radioGenreOptionSport => 'Sport';

  @override
  String get radioGenreOptionTalk => 'Débats et analyses';

  @override
  String get radioGenreOptionPop => 'Pop';

  @override
  String get radioGenreOptionRock => 'Rock';

  @override
  String get radioGenreOptionClassical => 'Classique';

  @override
  String get radioGenreOptionJazz => 'Jazz';

  @override
  String get radioGenreOptionDance => 'Dance / électro';

  @override
  String get radioGenreOptionBlues => 'Blues';

  @override
  String get radioGenreOptionCountry => 'Country / folk';

  @override
  String get radioGenreOptionHiphop => 'Hip hop';

  @override
  String get radioGenreOptionElectronic => 'Électronique';

  @override
  String get radioGenreOptionLatin => 'Latine';

  @override
  String get radioGenreOptionReggae => 'Reggae';

  @override
  String get radioGenreOptionMetal => 'Metal';

  @override
  String get radioGenreOptionFolk => 'Folk';

  @override
  String get radioGenreOptionReligion => 'Religion';

  @override
  String get radioGenreOptionLocal => 'Locale';

  @override
  String get radioGenreOptionCulture => 'Culture';

  @override
  String get radioGenreOptionOldies => 'Années 70 / 80 / 90';

  @override
  String get radioGenreOptionKids => 'Enfants';

  @override
  String get radioGenreOptionAmbient => 'Ambient / relax';

  @override
  String get radioCommunityLanguageItalian => 'Italien';

  @override
  String get radioCommunityLanguageEnglish => 'Anglais';

  @override
  String get radioCommunityLanguageSpanish => 'Espagnol';

  @override
  String get radioCommunityLanguageFrench => 'Français';

  @override
  String get radioCommunityLanguageGerman => 'Allemand';

  @override
  String get radioCommunityLanguagePortuguese => 'Portugais';

  @override
  String get radioCommunityLanguageSwedish => 'Suédois';

  @override
  String get radioCommunityLanguageVietnamese => 'Vietnamien';

  @override
  String get radioCommunityLanguageCzech => 'Tchèque';

  @override
  String get radioCommunityLanguagePolish => 'Polonais';

  @override
  String get radioCommunityLanguageSerbian => 'Serbe';

  @override
  String get radioCommunityLanguageUkrainian => 'Ukrainien';

  @override
  String get radioCommunityLanguageLithuanian => 'Lituanien';

  @override
  String get radioCommunityLanguageRussian => 'Russe';

  @override
  String get radioCommunityLanguageChinese => 'Chinois';

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
  String get cinemaTitle => 'Films au cinéma';

  @override
  String get cinemaNoMovies => 'Aucun film trouvé pour le moment.';

  @override
  String get cinemaError => 'Erreur lors du chargement des films.';

  @override
  String cinemaReleased(String date) {
    return 'Sorti le : $date';
  }

  @override
  String get cinemaOverviewLabel => 'Synopsis :';

  @override
  String get cinemaUpcomingReleases => 'Prochaines sorties';

  @override
  String cinemaWillRelease(String date) {
    return 'Sortira le : $date';
  }

  @override
  String get cinemaOpenTrailer => 'Ouvrir la bande-annonce';

  @override
  String get concertsTitle => 'Concerts et événements';

  @override
  String get concertsSearchHint => 'Entrez une ville (ex. Paris, Lyon)';

  @override
  String get concertsSearchLabel => 'Rechercher des concerts par ville';

  @override
  String get concertsSearchTooltip => 'Rechercher';

  @override
  String get concertsInitialText =>
      'Entrez le nom de votre ville ci-dessus pour voir les prochains concerts de musique.';

  @override
  String get concertsEmpty => 'Aucun concert trouvé dans cette ville.';

  @override
  String get concertsVenue => 'Lieu du concert :';

  @override
  String get concertsBuyTickets =>
      'Acheter ou voir les détails sur Ticketmaster';

  @override
  String get podcastPlayedEpisodes => 'Épisodes écoutés';

  @override
  String get podcastSelectDate => 'Sélectionner une date';

  @override
  String get podcastNoDatesAvailable => 'Aucune date disponible pour ces épisodes.';

  @override
  String get podcastChapters => 'Chapitres';

  @override
  String get podcastChaptersUnavailable => 'Aucun chapitre disponible pour cet épisode.';

  @override
  String get podcastUnplayed => 'Épisodes non écoutés';

  @override
  String get routeReadAction => 'Lire l\'itinéraire';

  @override
  String get routeSaveAction => 'Enregistrer dans les documents';

  @override
  String get routeSaveSuccess => 'Itinéraire enregistré dans les documents';

  @override
  String get deleteItem => 'Supprimer';

  @override
  String get audiobookMp3Format => 'Livre audio MP3 (.mp3)';

  @override
  String get audiobookM4bFormat => 'Livre audio M4B (.m4b)';

  @override
  String get exportCompleteTitle => 'Exportation terminée';

  @override
  String get exportCompleteMessage =>
      'Le fichier a été créé correctement. Voulez-vous l’enregistrer dans Sonarpad ou le partager ?';

  @override
  String get saveInSonarpad => 'Enregistrer dans Sonarpad';

  @override
  String get exportSavedInSonarpad =>
      'Fichier enregistré dans les Documents de Sonarpad.';

  @override
  String get audiobookExportProgressTitle => 'Création du livre audio';

  @override
  String get audiobookExportPreparing => 'Préparation du livre audio...';

  @override
  String get audiobookExportGeneratingAudio => 'Génération de l’audio';

  @override
  String get audiobookExportConvertingAudio =>
      'Conversion finale du fichier audio...';

  @override
  String get audiobookExportFinalizing => 'Finalisation...';

  @override
  String get routeRecentRoutes => 'Itinéraires récents';

  @override
  String get routeRecentRoutesEmpty => 'Aucun itinéraire récent';

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) {
    return 'Détails de navigation de $from à $to - $date';
  }
}
