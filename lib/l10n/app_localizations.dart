import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;
  bool get _isEn => locale.languageCode == 'en';
  bool get _isFr => locale.languageCode == 'fr';
  bool get _isEs => locale.languageCode == 'es';

  static const supportedLocales = [Locale('it'), Locale('en'), Locale('fr'), Locale('es')];

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
  String get appLanguage => _isEn ? 'App Language' : (_isFr ? 'Langue de l\'application' : (_isEs ? 'Idioma de la aplicación' : 'Lingua dell\'app'));
  String get homeSemanticsLabel => _isEn ? 'Sonarpad, main screen' : (_isFr ? 'Sonarpad, écran principal' : (_isEs ? 'Sonarpad, pantalla principal' : 'Sonarpad, schermata principale'));
  String get settings => _isEn ? 'Settings' : (_isFr ? 'Paramètres' : (_isEs ? 'Ajustes' : 'Impostazioni'));
  String get settingsHint => _isEn ? 'Open settings' : (_isFr ? 'Ouvrir les paramètres' : (_isEs ? 'Abrir ajustes' : 'Apre le impostazioni'));
  String get info => _isEn ? 'About' : (_isFr ? 'À propos' : (_isEs ? 'Acerca de' : 'Informazioni'));
  String get infoHint => _isEn ? 'Open app info' : (_isFr ? 'Ouvrir les informations sur l\'application' : (_isEs ? 'Abrir información de la aplicación' : 'Apre le informazioni sull\'app'));
  String get donations => _isEn ? 'Donations' : (_isFr ? 'Dons' : (_isEs ? 'Donaciones' : 'Donazioni'));
  String get donationsHint => _isEn ? 'Support the development of Sonarpad' : (_isFr ? 'Soutenir le développement de Sonarpad' : (_isEs ? 'Apoya el desarrollo de Sonarpad' : 'Supporta lo sviluppo di Sonarpad'));
  String get loading => _isEn ? 'Loading' : (_isFr ? 'Chargement' : (_isEs ? 'Cargando' : 'Caricamento'));
  String get ttsVoiceLanguage => _isEn ? 'TTS Voice Language' : (_isFr ? 'Langue de la voix TTS' : (_isEs ? 'Idioma de la voz TTS' : 'Lingua voci TTS'));
  String get ttsVoice => _isEn ? 'TTS Voice' : (_isFr ? 'Voix TTS' : (_isEs ? 'Voz TTS' : 'Voce TTS'));
  String get saveSettings => _isEn ? 'Save settings' : (_isFr ? 'Sauvegarder les paramètres' : (_isEs ? 'Guardar ajustes' : 'Salva impostazioni'));
  String get settingsSaved => _isEn ? 'Settings saved.' : (_isFr ? 'Paramètres sauvegardés.' : (_isEs ? 'Ajustes guardados.' : 'Impostazioni salvate.'));
  String get infoDescription => _isEn
      ? 'Sonarpad is a simple app packed with features. Designed to be accessible for the visually impaired using VoiceOver, here you can listen to news, search and subscribe to podcasts, import Wikipedia articles, add documents to your library, save and edit them. Sonarpad\'s features are constantly updated, and they are all designed to make life easier for the visually impaired.'
      : (_isFr ? 'Sonarpad est une application simple riche en fonctionnalités. Conçue pour être accessible aux personnes malvoyantes à l\'aide de VoiceOver, vous pouvez ici écouter les actualités, rechercher et vous abonner à des podcasts, importer des articles Wikipedia, ajouter des documents à votre bibliothèque, les enregistrer et les modifier. Les fonctionnalités de Sonarpad sont constamment mises à jour, et sont toutes conçues pour faciliter la vie des malvoyants.' : (_isEs ? 'Sonarpad es una aplicación sencilla repleta de funciones. Diseñada para ser accesible para personas con discapacidad visual a través de VoiceOver, aquí puedes escuchar noticias, buscar y suscribirte a podcasts, importar artículos de Wikipedia, añadir documentos a tu biblioteca, guardarlos y editarlos. Las características de Sonarpad se actualizan constantemente y están diseñadas para facilitar la vida a las personas con discapacidad visual.' : 'Sonarpad è un\'app semplice, ma con tante funzioni. Nata per essere accessibile ai non vedenti usando VoiceOver, qui potrete ascoltare le notizie, cercare e iscriversi ai podcast, importare articoli di Wikipedia, aggiungere i documenti alla vostra libreria, salvarli e modificarli. Le funzioni di Sonarpad sono in continuo aggiornamento, e sono tutte pensate per rendere più facile la vita dei non vedenti.'));
  String get infoAuthor => _isEn ? 'Author: Ambrogio Riili' : (_isFr ? 'Auteur : Ambrogio Riili' : (_isEs ? 'Autor: Ambrogio Riili' : 'Autore: Ambrogio Riili'));
  String get donationsIntro => _isEn
      ? 'Sonarpad is a program created at first to meet personal needs, but over time it has grown more and more. Developing it requires constant work to improve features, fix bugs, search for new ideas, and carefully test all functions.\n\nIf you find this program useful and want to support its development, you can make a donation.'
      : (_isFr ? 'Sonarpad est un programme créé à l\'origine pour répondre à des besoins personnels, mais au fil du temps, il a de plus en plus grandi. Son développement nécessite un travail constant pour améliorer les fonctionnalités, corriger les bogues, rechercher de nouvelles idées et tester en profondeur chaque partie du programme.\n\nSi vous trouvez ce programme utile et souhaitez soutenir son développement, vous pouvez faire un don.' : (_isEs ? 'Sonarpad es un programa creado al principio para satisfacer necesidades personales, pero con el tiempo ha crecido cada vez más. Desarrollarlo requiere un trabajo constante para mejorar funciones, corregir errores, buscar nuevas ideas y probar cuidadosamente todas las funciones.\n\nSi encuentras útil este programa y deseas apoyar su desarrollo, puedes hacer una donación.' : 'Sonarpad è un programma creato inizialmente per soddisfare esigenze personali, ma nel tempo è cresciuto sempre di più. Il suo sviluppo richiede un lavoro costante per migliorare le funzionalità, correggere bug, ricercare nuove idee e testare a fondo ogni parte del programma.\n\nSe ritieni utile questo programma e desideri supportarne lo sviluppo, puoi effettuare una donazione.'));
  String get donationsPaypalDesc => _isEn
      ? 'You can donate via PayPal using this link:\nhttps://www.paypal.me/ambrogio86\nPlease, if possible, add “Sonarpad” as the payment note.'
      : (_isFr ? 'Vous pouvez faire un don via PayPal via ce lien :\nhttps://www.paypal.me/ambrogio86\nVeuillez, si possible, ajouter "Sonarpad" comme note de paiement.' : (_isEs ? 'Puedes donar a través de PayPal usando este enlace:\nhttps://www.paypal.me/ambrogio86\nPor favor, si es posible, añade "Sonarpad" como nota de pago.' : 'Puoi donare tramite PayPal al seguente link:\nhttps://www.paypal.me/ambrogio86\nSe possibile, indica come causale “Sonarpad”.'));
  String get donationsBankDesc => _isEn
      ? 'You can also donate via bank transfer to the bank account in the name of Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nPlease, if possible, use a clear payment reason, for example “Sonarpad”.'
      : (_isFr ? 'Vous pouvez également contribuer par virement bancaire sur le compte au nom d\'Ambrogio Riili.\nIBAN : IT77W0306901020100000064149\nSi possible, indiquez un motif de paiement clair, par exemple "Sonarpad".' : (_isEs ? 'También puedes hacer una donación por transferencia bancaria a la cuenta a nombre de Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nPor favor, si es posible, usa un motivo de pago claro, por ejemplo, "Sonarpad".' : 'È possibile contribuire anche tramite bonifico bancario sul conto intestato a Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nSe possibile, indica una causale chiara, ad esempio “Sonarpad”.'));
  String get donationsThanks => _isEn
      ? 'Anyone who supports the project will be mentioned in the program and on the GitHub repository, unless they prefer to stay anonymous or use a nickname.\n\nThanks to Jiri Holzinger and Paola Vagata for their contribution.\nFor the Vietnamese translation, thanks to Anh Đức Nguyễn.\nFor the Czech translation, thanks to Radek Žalud and Jiri Holzinger.\nFor the Spanish translation, thanks to Arturo Fernandez Rivas.\nFor the Serbian translation, thanks to Mila Kuran.\nFor the Ukrainian translation, thanks to Ivan Shtefuriak.'
      : (_isFr ? 'Quiconque soutient le projet sera mentionné dans le programme et sur le référentiel GitHub, sauf s\'il préfère rester anonyme ou utiliser un surnom.\n\nMerci à Jiri Holzinger et Paola Vagata pour leur contribution.\nPour la traduction en vietnamien, merci à Anh Đức Nguyễn.\nPour la traduction en tchèque, merci à Radek Žalud et Jiri Holzinger.\nPour la traduction en espagnol, merci à Arturo Fernandez Rivas.\nPour la traduction en serbe, merci à Mila Kuran.\nPour la traduction en ukrainien, merci à Ivan Shtefuriak.' : (_isEs ? 'Cualquier persona que apoye el proyecto será mencionada en el programa y en el repositorio de GitHub, a menos que prefiera permanecer en el anonimato o usar un seudónimo.\n\nGracias a Jiri Holzinger y Paola Vagata por su contribución.\nPor la traducción al vietnamita, gracias a Anh Đức Nguyễn.\nPor la traducción al checo, gracias a Radek Žalud y Jiri Holzinger.\nPor la traducción al español, gracias a Arturo Fernandez Rivas.\nPor la traducción al serbio, gracias a Mila Kuran.\nPor la traducción al ucraniano, gracias a Ivan Shtefuriak.' : 'Chiunque decida di supportare il progetto verrà ringraziato nel programma e sul repository GitHub, nella sezione sostenitori, salvo richiesta di anonimato o utilizzo di un nickname.\n\nSi ringrazia per il contributo Jiri Holzinger e Paola Vagata.\nPer la traduzione in vietnamita ringrazio Anh Đức Nguyễn.\nPer la traduzione in ceco ringrazio Radek Žalud e Jiri Holzinger.\nPer la traduzione in spagnolo ringrazio Arturo Fernandez Rivas.\nPer la traduzione in serbo ringrazio Mila Kuran.\nPer la traduzione in ucraino ringrazio Ivan Shtefuriak.'));
  String get news => _isEn ? 'News' : (_isFr ? 'Actualités' : (_isEs ? 'Noticias' : 'Notizie'));
  String get newsHint => _isEn ? 'Open news from Google News RSS' : (_isFr ? 'Ouvrir les actualités de Google News RSS' : (_isEs ? 'Abrir noticias del RSS de Google News' : 'Apre le notizie da Google News RSS'));
  String get podcasts => _isEn ? 'Podcasts' : (_isFr ? 'Podcasts' : (_isEs ? 'Podcasts' : 'Podcast'));
  String get podcastsHint => _isEn ? 'Subscribe to podcasts, play or download episodes' : (_isFr ? 'S\'abonner aux podcasts, lire ou télécharger des épisodes' : (_isEs ? 'Suscríbete a podcasts, reproduce o descarga episodios' : 'Iscriviti ai podcast, riproduci o scarica episodi'));
  String get importFromWikipedia => 'Wikipedia';
  String get wikipediaHint => _isEn ? 'Search for a Wikipedia article and import the text' : (_isFr ? 'Rechercher un article Wikipedia et importer le texte' : (_isEs ? 'Busca un artículo de Wikipedia e importa el texto' : 'Cerca un articolo Wikipedia e importa il testo'));

  String get newsCategoryTop => switch (locale.languageCode) {
        'it' => 'Principali',
        'en' => 'Top stories',
        'fr' => 'À la une',
        'es' => 'Titulares',
        _ => 'Principali',
      };

  String get newsCategoryMyCity => switch (locale.languageCode) {
        'it' => 'La mia città',
        'en' => 'My City',
        'fr' => 'Ma ville',
        'es' => 'Mi ciudad',
        _ => 'La mia città',
      };

  String get moveUp => switch (locale.languageCode) {
        'it' => 'Sposta in alto',
        'en' => 'Move up',
        'fr' => 'Déplacer vers le haut',
        'es' => 'Mover hacia arriba',
        _ => 'Sposta in alto',
      };

  String get moveDown => switch (locale.languageCode) {
        'it' => 'Sposta in basso',
        'en' => 'Move down',
        'fr' => 'Déplacer vers le bas',
        'es' => 'Mover hacia abajo',
        _ => 'Sposta in basso',
      };

  String get hide => switch (locale.languageCode) {
        'it' => 'Elimina',
        'en' => 'Delete',
        'fr' => 'Supprimer',
        'es' => 'Eliminar',
        _ => 'Elimina',
      };

  String get moveToPosition => switch (locale.languageCode) {
        'it' => 'Sposta alla posizione',
        'en' => 'Move to position',
        'fr' => 'Déplacer à la position',
        'es' => 'Mover a la posición',
        _ => 'Sposta alla posizione',
      };

  String positionLabel(int position, String targetName) => switch (locale.languageCode) {
        'it' => 'Posizione $position: prima di $targetName',
        'en' => 'Position $position: before $targetName',
        'fr' => 'Position $position: avant $targetName',
        'es' => 'Posición $position: antes de $targetName',
        _ => 'Posizione $position: prima di $targetName',
      };
      
  String get positionLabelLast => switch (locale.languageCode) {
        'it' => 'Ultima posizione',
        'en' => 'Last position',
        'fr' => 'Dernière position',
        'es' => 'Última posición',
        _ => 'Ultima posizione',
      };

  String get restoreHiddenSources => switch (locale.languageCode) {
        'it' => 'Ripristina testate eliminate',
        'en' => 'Restore deleted sources',
        'fr' => 'Restaurer les sources supprimées',
        'es' => 'Restaurar fuentes eliminadas',
        _ => 'Ripristina testate eliminate',
      };

  String get newsLanguage => _isEn ? 'News Language' : (_isFr ? 'Langue des actualités' : (_isEs ? 'Idioma de las noticias' : 'Lingua notizie'));
  String get loadingNews => _isEn ? 'Loading news' : (_isFr ? 'Chargement des actualités' : (_isEs ? 'Cargando noticias' : 'Caricamento notizie'));
  String error(Object error) => _isEn ? 'Error: $error' : (_isFr ? 'Erreur : $error' : (_isEs ? 'Error: $error' : 'Errore: $error'));
  String get noNewsFound => _isEn ? 'No news found' : (_isFr ? 'Aucune actualité trouvée' : (_isEs ? 'No se encontraron noticias' : 'Nessuna notizia trovata'));
  String get loadingArticle => _isEn ? 'Loading article' : (_isFr ? 'Chargement de l\'article' : (_isEs ? 'Cargando artículo' : 'Caricamento articolo'));
  String get noFullArticleFound => _isEn ? 'Full article not available. Showing feed summary.' : (_isFr ? 'Article complet indisponible. Affichage du résumé du flux.' : (_isEs ? 'Artículo completo no disponible. Mostrando el resumen del feed.' : 'Articolo integrale non disponibile. Mostro il riassunto del feed.'));
  String get italian => _isEn ? 'Italian' : (_isFr ? 'Italien' : (_isEs ? 'Italiano' : 'Italiano'));
  String get english => _isEn ? 'English' : (_isFr ? 'Anglais' : (_isEs ? 'Inglés' : 'English'));
  String get french => _isEn ? 'French' : (_isFr ? 'Français' : (_isEs ? 'Francés' : 'Francese'));
  String get spanish => _isEn ? 'Spanish' : (_isFr ? 'Espagnol' : (_isEs ? 'Español' : 'Spagnolo'));
  String get newsSource => _isEn ? 'News source' : (_isFr ? 'Source d\'actualité' : (_isEs ? 'Fuente de noticias' : 'Fonte notizie'));

  String get article => _isEn ? 'Article' : (_isFr ? 'Article' : (_isEs ? 'Artículo' : 'Articolo'));
  String get articlePreview => _isEn ? 'Article preview' : (_isFr ? 'Aperçu de l\'article' : (_isEs ? 'Vista previa del artículo' : 'Anteprima articolo'));
  String get readFullArticle => _isEn ? 'Read full article' : (_isFr ? 'Lire l\'article complet' : (_isEs ? 'Leer artículo completo' : 'Leggi articolo completo'));
  String get extractingReaderArticleText => _isEn ? 'Extracting text in reader mode...' : (_isFr ? 'Extraction du texte en mode lecteur...' : (_isEs ? 'Extrayendo texto en modo lectura...' : 'Estraggo il testo in modalita lettura...'));
  String get extractingVisibleArticleText => _isEn ? 'Extracting visible text from page...' : (_isFr ? 'Extraction du texte visible de la page...' : (_isEs ? 'Extrayendo texto visible de la página...' : 'Estraggo il testo visibile dalla pagina...'));
  String source(String source) => _isEn ? 'Source: \$source' : (_isFr ? 'Source : \$source' : (_isEs ? 'Fuente: \$source' : 'Fonte: \$source'));
  String get readyStatus => _isEn ? 'Ready.' : (_isFr ? 'Prêt.' : (_isEs ? 'Listo.' : 'Pronto.'));
  String get preparingEdgeTts => _isEn ? 'Preparing Edge TTS reading in blocks...' : (_isFr ? 'Préparation de la lecture Edge TTS en blocs...' : (_isEs ? 'Preparando lectura Edge TTS en bloques...' : 'Preparo lettura Edge TTS a blocchi...'));
  String get noTextToRead => _isEn ? 'No text to read.' : (_isFr ? 'Aucun texte à lire.' : (_isEs ? 'No hay texto para leer.' : 'Nessun testo da leggere.'));
  String chunkCreated(int index, int total) => _isEn ? 'Block \$index of \$total created. Reading in progress...' : (_isFr ? 'Bloc \$index sur \$total créé. Lecture en cours...' : (_isEs ? 'Bloque \$index de \$total creado. Lectura en curso...' : 'Blocco \$index di \$total creato. Lettura in corso...'));
  String playingChunk(int index, int total, int size) => _isEn ? 'Playing block \$index of \$total (\$size bytes)...' : (_isFr ? 'Lecture du bloc \$index sur \$total (\$size octets)...' : (_isEs ? 'Reproduciendo bloque \$index de \$total (\$size bytes)...' : 'Riproduco blocco \$index di \$total (\$size byte)...'));
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) => _isEn
      ? 'Reading finished. Blocks created: \$readyChunks/\$totalChunks. Library: \$libraryPath'
      : (_isFr ? 'Lecture terminée. Blocs créés : \$readyChunks/\$totalChunks. Bibliothèque : \$libraryPath' : (_isEs ? 'Lectura finalizada. Bloques creados: \$readyChunks/\$totalChunks. Biblioteca: \$libraryPath' : 'Lettura terminata. Blocchi creati: \$readyChunks/\$totalChunks. Libreria: \$libraryPath'));
  String get libraryNotSpecified => _isEn ? 'not specified' : (_isFr ? 'non spécifié' : (_isEs ? 'no especificada' : 'non indicata'));
  String get readingStopped => _isEn ? 'Reading stopped.' : (_isFr ? 'Lecture arrêtée.' : (_isEs ? 'Lectura detenida.' : 'Lettura interrotta.'));
  String edgeTtsError(Object error) => _isEn ? 'Edge TTS Error: \$error' : (_isFr ? 'Erreur Edge TTS : \$error' : (_isEs ? 'Error de Edge TTS: \$error' : 'Errore Edge TTS: \$error'));
  String audioChunksReady(int readyChunks, int totalChunks) => _isEn ? 'Audio blocks ready: \$readyChunks / \$totalChunks' : (_isFr ? 'Blocs audio prêts : \$readyChunks / \$totalChunks' : (_isEs ? 'Bloques de audio listos: \$readyChunks / \$totalChunks' : 'Blocchi audio pronti: \$readyChunks / \$totalChunks'));
  String get readingInProgress => _isEn ? 'Reading in progress...' : (_isFr ? 'Lecture en cours...' : (_isEs ? 'Lectura en curso...' : 'Lettura in corso...'));
  String get readWithEdgeTts => _isEn ? 'Read with Edge TTS' : (_isFr ? 'Lire avec Edge TTS' : (_isEs ? 'Leer con Edge TTS' : 'Leggi con Edge TTS'));
  String get stopReading => _isEn ? 'Stop reading' : (_isFr ? 'Arrêter la lecture' : (_isEs ? 'Detener lectura' : 'Interrompi lettura'));
  String get openOriginalArticle => _isEn ? 'Open original article' : (_isFr ? 'Ouvrir l\'article original' : (_isEs ? 'Abrir artículo original' : 'Apri articolo originale'));

  String get searchPodcasts => _isEn ? 'Search podcasts' : (_isFr ? 'Rechercher des podcasts' : (_isEs ? 'Buscar podcasts' : 'Cerca podcast'));
  String get podcastName => _isEn ? 'Podcast name' : (_isFr ? 'Nom du podcast' : (_isEs ? 'Nombre del podcast' : 'Nome podcast'));
  String get podcastSearchHint => _isEn ? 'Example: technology, history, the podcast name...' : (_isFr ? 'Exemple : technologie, histoire, le nom du podcast...' : (_isEs ? 'Ejemplo: tecnología, historia, el nombre del podcast...' : 'Esempio: tecnologia, storia, il nome del podcast...'));
  String get searchCountry => _isEn ? 'Search country' : (_isFr ? 'Pays de recherche' : (_isEs ? 'País de búsqueda' : 'Paese ricerca'));
  String get podcastCategory => _isEn ? 'Podcast category' : (_isFr ? 'Catégorie de podcast' : (_isEs ? 'Categoría de podcast' : 'Categoria podcast'));
  String get countryItaly => _isEn ? 'Italy' : (_isFr ? 'Italie' : (_isEs ? 'Italia' : 'Italia'));
  String get countryUnitedStatesEnglish => _isEn ? 'United States / English' : (_isFr ? 'États-Unis / Anglais' : (_isEs ? 'Estados Unidos / Inglés' : 'Stati Uniti / inglese'));
  String get countryUnitedKingdom => _isEn ? 'United Kingdom' : (_isFr ? 'Royaume-Uni' : (_isEs ? 'Reino Unido' : 'Regno Unito'));
  String get countrySpain => _isEn ? 'Spain' : (_isFr ? 'Espagne' : (_isEs ? 'España' : 'Spagna'));
  String get countryFrance => _isEn ? 'France' : (_isFr ? 'France' : (_isEs ? 'Francia' : 'Francia'));
  String get searchInProgress => _isEn ? 'Search in progress...' : (_isFr ? 'Recherche en cours...' : (_isEs ? 'Búsqueda en curso...' : 'Ricerca in corso...'));
  String podcastResultsFound(int count) => _isEn ? 'Found \$count podcasts' : (_isFr ? '\$count podcasts trouvés' : (_isEs ? '\$count podcasts encontrados' : 'Trovati \$count podcast'));
  String podcastSearchError(Object error) => _isEn ? 'Podcast search error: \$error' : (_isFr ? 'Erreur de recherche de podcast : \$error' : (_isEs ? 'Error en la búsqueda de podcasts: \$error' : 'Errore ricerca podcast: \$error'));
  String subscribedTo(String title) => _isEn ? 'Subscribed to \$title' : (_isFr ? 'Abonné à \$title' : (_isEs ? 'Suscrito a \$title' : 'Iscritto a \$title'));
  String subscriptionError(Object error) => _isEn ? 'Subscription error: \$error' : (_isFr ? 'Erreur d\'abonnement : \$error' : (_isEs ? 'Error de suscripción: \$error' : 'Errore iscrizione: \$error'));
  String podcastSubscriptionError(Object error) => _isEn ? 'Podcast subscription error: \$error' : (_isFr ? 'Erreur d\'abonnement au podcast : \$error' : (_isEs ? 'Error de suscripción de podcast: \$error' : 'Errore iscrizione podcast: \$error'));
  String get searchResults => _isEn ? 'Search results' : (_isFr ? 'Résultats de recherche' : (_isEs ? 'Resultados de la búsqueda' : 'Risultati ricerca'));
  String get podcastInfo => _isEn ? 'Podcast info' : (_isFr ? 'Infos sur le podcast' : (_isEs ? 'Información del podcast' : 'Info podcast'));
  String get subscribe => _isEn ? 'Subscribe' : (_isFr ? 'S\'abonner' : (_isEs ? 'Suscribirse' : 'Iscriviti'));
  String get podcastAuthor => _isEn ? 'Author' : (_isFr ? 'Auteur' : (_isEs ? 'Autor' : 'Autore'));
  String get noPodcastDescription => _isEn ? 'No description available.' : (_isFr ? 'Aucune description disponible.' : (_isEs ? 'No hay descripción disponible.' : 'Nessuna descrizione disponibile.'));
  String get loadingPodcastInfo => _isEn ? 'Loading podcast info' : (_isFr ? 'Chargement des infos du podcast' : (_isEs ? 'Cargando información del podcast' : 'Caricamento info podcast'));
  String get podcastArtwork => _isEn ? 'Podcast artwork' : (_isFr ? 'Pochette du podcast' : (_isEs ? 'Portada del podcast' : 'Copertina podcast'));
  String get addFeedUrlManually => _isEn ? 'Add RSS feed URL manually' : (_isFr ? 'Ajouter l\'URL du flux RSS manuellement' : (_isEs ? 'Añadir URL del feed RSS manualmente' : 'Aggiungi manualmente URL feed RSS'));
  String get podcastFeedUrl => _isEn ? 'Podcast RSS feed URL' : (_isFr ? 'URL du flux RSS du podcast' : (_isEs ? 'URL del feed RSS del podcast' : 'URL feed podcast RSS'));
  String get subscribeFromUrl => _isEn ? 'Subscribe from URL' : (_isFr ? 'S\'abonner à partir de l\'URL' : (_isEs ? 'Suscribirse desde URL' : 'Iscriviti da URL'));
  String get subscribedPodcasts => _isEn ? 'Subscribed podcasts' : (_isFr ? 'Podcasts abonnés' : (_isEs ? 'Podcasts suscritos' : 'Podcast iscritti'));
  String get noSubscribedPodcasts => _isEn ? 'No subscribed podcasts. Search for a podcast and tap a result to subscribe.' : (_isFr ? 'Aucun podcast abonné. Recherchez un podcast et appuyez sur un résultat pour vous abonner.' : (_isEs ? 'No hay podcasts suscritos. Busca un podcast y toca un resultado para suscribirte.' : 'Nessun podcast iscritto. Cerca un podcast e tocca il risultato per iscriverti.'));
  String get loadingEpisodes => _isEn ? 'Loading episodes' : (_isFr ? 'Chargement des épisodes' : (_isEs ? 'Cargando episodios' : 'Caricamento episodi'));
  String get noAudioEpisodesFound => _isEn ? 'No audio episodes found in the feed.' : (_isFr ? 'Aucun épisode audio trouvé dans le flux.' : (_isEs ? 'No se encontraron episodios de audio en el feed.' : 'Nessun episodio audio trovato nel feed.'));
  String get episodes => _isEn ? 'Episodes' : (_isFr ? 'Épisodes' : (_isEs ? 'Episodios' : 'Episodi'));
  String get episodeActions => _isEn ? 'Episode actions' : (_isFr ? 'Actions de l\'épisode' : (_isEs ? 'Acciones del episodio' : 'Azioni episodio'));
  String downloaded(String path) => _isEn ? 'Downloaded: \$path' : (_isFr ? 'Téléchargé : \$path' : (_isEs ? 'Descargado: \$path' : 'Scaricato: \$path'));
  String episodeError(Object error) => _isEn ? 'Episode error: \$error' : (_isFr ? 'Erreur de l\'épisode : \$error' : (_isEs ? 'Error del episodio: \$error' : 'Errore episodio: \$error'));
  String get play => _isEn ? 'Play' : (_isFr ? 'Lire' : (_isEs ? 'Reproducir' : 'Riproduci'));
  String get pause => _isEn ? 'Pause' : (_isFr ? 'Pause' : (_isEs ? 'Pausar' : 'Pausa'));
  String get rewind15s => _isEn ? 'Rewind 15s' : (_isFr ? 'Reculer de 15s' : (_isEs ? 'Retroceder 15s' : 'Indietro 15s'));
  String get forward15s => _isEn ? 'Forward 15s' : (_isFr ? 'Avancer de 15s' : (_isEs ? 'Avanzar 15s' : 'Avanti 15s'));
  String get stop => 'Stop';
  String get back => _isEn ? 'Back' : (_isFr ? 'Retour' : (_isEs ? 'Atrás' : 'Indietro'));
  String get episodePlayer => _isEn ? 'Episode player' : (_isFr ? 'Lecteur d\'épisode' : (_isEs ? 'Reproductor de episodios' : 'Player episodio'));
  String get loadingEpisodeAudio => _isEn ? 'Loading episode audio' : (_isFr ? 'Chargement de l\'audio de l\'épisode' : (_isEs ? 'Cargando audio del episodio' : 'Caricamento audio episodio'));
  String get download => _isEn ? 'Download' : (_isFr ? 'Télécharger' : (_isEs ? 'Descargar' : 'Scarica'));

  String get searchWikipedia => _isEn ? 'Search on Wikipedia' : (_isFr ? 'Rechercher sur Wikipédia' : (_isEs ? 'Buscar en Wikipedia' : 'Cerca su Wikipedia'));
  String get wikipediaLanguage => _isEn ? 'Wikipedia language' : (_isFr ? 'Langue Wikipédia' : (_isEs ? 'Idioma de Wikipedia' : 'Lingua Wikipedia'));
  String get search => _isEn ? 'Search' : (_isFr ? 'Rechercher' : (_isEs ? 'Buscar' : 'Cerca'));
  String get wikipediaSearch => _isEn ? 'Wikipedia search' : (_isFr ? 'Recherche Wikipédia' : (_isEs ? 'Búsqueda en Wikipedia' : 'Ricerca Wikipedia'));
  String get wikipediaImporting => _isEn ? 'Wikipedia import' : (_isFr ? 'Importation Wikipédia' : (_isEs ? 'Importación de Wikipedia' : 'Importazione Wikipedia'));
  String get noWikipediaResults => _isEn ? 'No Wikipedia results found' : (_isFr ? 'Aucun résultat Wikipédia trouvé' : (_isEs ? 'No se encontraron resultados en Wikipedia' : 'Nessun risultato Wikipedia trovato'));
  String get wikipediaImportMode => _isEn ? 'Import mode' : (_isFr ? 'Mode d\'importation' : (_isEs ? 'Modo de importación' : 'Importa'));
  String get wikipediaImportWholeArticle => _isEn ? 'Whole article' : (_isFr ? 'Article complet' : (_isEs ? 'Artículo completo' : 'Tutto l\'articolo'));

  // Documenti
  String get documents => _isEn ? 'Documents' : (_isFr ? 'Documents' : (_isEs ? 'Documentos' : 'Documenti'));
  String get documentsHint => _isEn ? 'Open document library' : (_isFr ? 'Ouvrir la bibliothèque de documents' : (_isEs ? 'Abrir biblioteca de documentos' : 'Apre la libreria documenti'));
  String get documentLibrary => _isEn ? 'Document library' : (_isFr ? 'Bibliothèque de documents' : (_isEs ? 'Biblioteca de documentos' : 'Libreria documenti'));
  String get addToLibrary => _isEn ? 'Add to library' : (_isFr ? 'Ajouter à la bibliothèque' : (_isEs ? 'Añadir a la biblioteca' : 'Aggiungi alla libreria'));
  String get noDocuments => _isEn ? 'No documents. Add a file.' : (_isFr ? 'Aucun document. Ajoutez un fichier.' : (_isEs ? 'No hay documentos. Añade un archivo.' : 'Nessun documento. Aggiungi un file.'));
  String get documentAdded => _isEn ? 'Document added' : (_isFr ? 'Document ajouté' : (_isEs ? 'Documento añadido' : 'Documento aggiunto'));
  String get documentRemoved => _isEn ? 'Document removed' : (_isFr ? 'Document supprimé' : (_isEs ? 'Documento eliminado' : 'Documento rimosso'));
  String get removeDocument => _isEn ? 'Remove document' : (_isFr ? 'Supprimer le document' : (_isEs ? 'Eliminar documento' : 'Rimuovi documento'));
  String get removePodcast => _isEn ? 'Remove podcast' : (_isFr ? 'Supprimer le podcast' : (_isEs ? 'Eliminar podcast' : 'Rimuovi podcast'));
  String get podcastRemoved => _isEn ? 'Podcast removed' : (_isFr ? 'Podcast supprimé' : (_isEs ? 'Podcast eliminado' : 'Podcast rimosso'));
  String get documentPickerError => _isEn ? 'Error opening file' : (_isFr ? 'Erreur d\'ouverture du fichier' : (_isEs ? 'Error al abrir el archivo' : 'Errore apertura file'));
  String get readDocument => _isEn ? 'Read document' : (_isFr ? 'Lire le document' : (_isEs ? 'Leer documento' : 'Leggi documento'));
  String get documentReaderTitle => _isEn ? 'Document reader' : (_isFr ? 'Lecteur de document' : (_isEs ? 'Lector de documentos' : 'Lettore documento'));
  String get edit => _isEn ? 'Edit' : (_isFr ? 'Modifier' : (_isEs ? 'Editar' : 'Modifica'));
  String get save => _isEn ? 'Save' : (_isFr ? 'Enregistrer' : (_isEs ? 'Guardar' : 'Salva'));
  String get cancel => _isEn ? 'Cancel' : (_isFr ? 'Annuler' : (_isEs ? 'Cancelar' : 'Annulla'));
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'it', 'fr', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
