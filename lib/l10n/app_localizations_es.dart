// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => '''Sonarpad''';

  @override
  String get appLanguage => '''Idioma de la aplicación''';

  @override
  String get settingsTheme => '''Tema de la aplicación''';

  @override
  String get settingsThemeSystem => '''Sistema''';

  @override
  String get settingsThemeLight => '''Claro''';

  @override
  String get settingsThemeDark => '''Oscuro''';

  @override
  String get homeSemanticsLabel => '''Sonarpad, pantalla principal''';

  @override
  String get settings => '''Ajustes''';

  @override
  String get settingsHint => '''Abrir ajustes''';

  @override
  String get info => '''Acerca de''';

  @override
  String get infoHint => '''Abrir información de la aplicación''';

  @override
  String get categoryReading => '''Lectura y documentos''';

  @override
  String get categoryMedia => '''Medios y entretenimiento''';

  @override
  String get categoryUtilities => '''Búsquedas y utilidades''';

  @override
  String get voiceDictionaryTitle => '''Diccionario y voz''';

  @override
  String get voiceDictionaryAdd => '''Agregar entradas al diccionario''';

  @override
  String get voiceDictionaryOriginalWord => '''Palabra original''';

  @override
  String get voiceDictionaryReplacementWord => '''Palabra de reemplazo''';

  @override
  String get voiceDictionaryMatchCase => '''Distinguir mayúsculas y minúsculas''';

  @override
  String get voiceDictionaryIgnoreCase => '''Ignorar mayúsculas y minúsculas''';

  @override
  String get voiceDictionaryEntries => '''Entradas del diccionario''';

  @override
  String get voiceDictionaryEmpty => '''No hay entradas en el diccionario.''';

  @override
  String get voiceDictionaryRemove => '''Eliminar entrada seleccionada''';

  @override
  String get voiceDictionaryOriginalRequired => '''Introduce la palabra original.''';

  @override
  String get convertMediaTitle => '''Convertir medios''';

  @override
  String get convertMediaInput => '''Archivo para convertir''';

  @override
  String get convertMediaOutput => '''Carpeta de guardado''';

  @override
  String get convertMediaImage => '''Imagen''';

  @override
  String get convertMediaBrowse => '''Examinar...''';

  @override
  String get convertMediaFormat => '''Formato''';

  @override
  String get convertMediaBitrate => '''Bitrate (kbps)''';

  @override
  String get convertMediaOggQuality => '''Calidad (q)''';

  @override
  String get convertMediaFlacCompression => '''Nivel de compresión''';

  @override
  String get convertMediaWavBitDepth => '''Profundidad de bits WAV''';

  @override
  String get convertMediaReady => '''Listo.''';

  @override
  String get convertMediaRunning => '''Convirtiendo...''';

  @override
  String get convertMediaDone => '''Conversión completada.''';

  @override
  String get convertMediaButton => '''Convertir''';

  @override
  String get convertMediaNoInput => '''Selecciona un archivo para convertir.''';

  @override
  String get convertMediaNoOutput => '''Selecciona una carpeta de guardado.''';

  @override
  String get convertMediaOutputNotWritable => '''La carpeta elegida no es accesible directamente. El archivo se guardará en la carpeta interna de Sonarpad; cuando termine la conversión, podrás compartirlo o guardarlo en la app Archivos.''';

  @override
  String get convertMediaNoImage => '''Selecciona una imagen para el vídeo.''';

  @override
  String get convertMediaSamePath => '''El archivo convertido debe ser diferente del archivo de origen.''';

  @override
  String get convertMediaInvalidBitrate => '''Introduce un bitrate válido entre 64 y 320 kbps.''';

  @override
  String convertMediaFailed(Object error) {
    return '''La conversión falló: ${error}''';
  }

  @override
  String get donations => '''Donaciones''';

  @override
  String get donationsHint => '''Apoya el desarrollo de Sonarpad''';

  @override
  String get loading => '''Cargando''';

  @override
  String get ttsVoiceLanguage => '''Idioma de la voz TTS''';

  @override
  String get ttsVoice => '''Voz TTS''';

  @override
  String get saveSettings => '''Guardar ajustes''';

  @override
  String get settingsSaved => '''Ajustes guardados.''';

  @override
  String get settingsSavedTitle => '''Ajustes guardados''';

  @override
  String get sonarpadCodeValidTitle => '''Código válido''';

  @override
  String get sonarpadCodeValidMessage => '''El código Sonarpad es correcto. Ajustes guardados.''';

  @override
  String get sonarpadCodeInvalidTitle => '''Código no válido''';

  @override
  String get sonarpadCodeInvalidMessage => '''El código Sonarpad no es válido. Comprueba que lo hayas copiado sin espacios adicionales.''';

  @override
  String get infoDescription => '''Sonarpad es una aplicación sencilla con muchas funciones. Diseñada para ser accesible con VoiceOver para personas ciegas o con discapacidad visual, permite escuchar noticias, buscar podcasts y suscribirse a ellos, importar artículos de Wikipedia, añadir documentos a la biblioteca, guardarlos y editarlos. Sonarpad se actualiza constantemente y cada función está pensada para facilitar la vida diaria.''';

  @override
  String get infoAuthor => '''Autor: Ambrogio Riili''';

  @override
  String get donationsIntro => '''Sonarpad se creó inicialmente para responder a necesidades personales, pero con el tiempo se ha convertido en una aplicación más completa. Su desarrollo requiere un trabajo constante: mejorar funciones, corregir errores, explorar nuevas ideas y probar cuidadosamente cada función.

Si Sonarpad te resulta útil y quieres apoyar su desarrollo, puedes hacer una donación.''';

  @override
  String get donationsPaypalDesc => '''Puedes donar a través de PayPal usando este enlace:
https://www.paypal.me/ambrogio86
Por favor, si es posible, añade "Sonarpad" como nota de pago.''';

  @override
  String get donationsBankDesc => '''También puedes hacer una donación por transferencia bancaria a la cuenta a nombre de Ambrogio Riili.
IBAN: IT77W0306901020100000064149
Por favor, si es posible, usa un motivo de pago claro, por ejemplo, "Sonarpad".''';

  @override
  String get donationsThanks => '''Toda persona que apoye el proyecto será mencionada en la aplicación y en el repositorio de GitHub, salvo que prefiera permanecer en el anonimato o usar un seudónimo.

Gracias a Jiri Holzinger y Paola Vagata por su contribución.
Por la traducción al checo, gracias a Radek Žalud y Jiri Holzinger.
Por la traducción al español, gracias a Arturo Fernandez Rivas.''';

  @override
  String get news => '''Noticias''';

  @override
  String get newsHint => '''Abrir noticias del RSS de Google News''';

  @override
  String get podcasts => '''Podcasts''';

  @override
  String get podcastsHint => '''Suscríbete a podcasts, reproduce o descarga episodios''';

  @override
  String get importFromWikipedia => '''Wikipedia''';

  @override
  String get wikipediaHint => '''Busca un artículo de Wikipedia e importa el texto''';

  @override
  String get newsCategoryTop => '''Titulares''';

  @override
  String get settingsHomeGrouping => '''Habilitar la agrupación de iconos de inicio en categorías''';

  @override
  String get settingsHomeGroupingHint => '''Si está deshabilitado, los iconos principales se mostrarán como una lista única sin subcarpetas''';

  @override
  String get newsCategoryMyCity => '''Mi ciudad''';

  @override
  String get newsLocalCityLabel => '''Introduce tu ciudad''';

  @override
  String get newsLocalCityHint => '''Corrige la ciudad usada para las noticias locales''';

  @override
  String get update => '''Actualizar''';

  @override
  String get moveUp => '''Mover hacia arriba''';

  @override
  String get moveDown => '''Mover hacia abajo''';

  @override
  String get hide => '''Eliminar''';

  @override
  String get moveToPosition => '''Mover a la posición''';

  @override
  String positionLabel(int position, String targetName) {
    return '''Posición ${position}: antes de ${targetName}''';
  }

  @override
  String get positionLabelLast => '''Última posición''';

  @override
  String get restoreHiddenSources => '''Restaurar fuentes eliminadas''';

  @override
  String get addCustomNewsSource => '''Añadir fuente RSS personalizada''';

  @override
  String get newsSourceName => '''Nombre de la fuente o del sitio''';

  @override
  String get newsSourceUrlOrSearch => '''URL del sitio, feed RSS o palabra de búsqueda''';

  @override
  String get deleteNewsSource => '''Eliminar fuente''';

  @override
  String get importRssSourcesFromOpml => '''Importar fuentes RSS desde OPML''';

  @override
  String get exportRssSourcesToOpml => '''Exportar fuentes RSS a OPML''';

  @override
  String rssImportComplete(int count) {
    return '''Fuentes RSS importadas: ${count}''';
  }

  @override
  String rssImportError(Object error) {
    return '''Error al importar RSS: ${error}''';
  }

  @override
  String get rssExportComplete => '''Fuentes RSS exportadas''';

  @override
  String rssExportError(Object error) {
    return '''Error al exportar RSS: ${error}''';
  }

  @override
  String get deleteItem => '''Eliminar''';

  @override
  String get articleTextSemantics => '''Texto del artículo''';

  @override
  String get newsLanguage => '''Idioma de las noticias''';

  @override
  String get loadingNews => '''Cargando noticias''';

  @override
  String error(Object error) {
    return '''Error: ${error}''';
  }

  @override
  String get noNewsFound => '''No se encontraron noticias''';

  @override
  String get loadingArticle => '''Cargando artículo''';

  @override
  String get noFullArticleFound => '''Artículo completo no disponible. Mostrando el resumen del feed.''';

  @override
  String get italian => '''Italiano''';

  @override
  String get english => '''Inglés''';

  @override
  String get french => '''Francés''';

  @override
  String get spanish => '''Español''';

  @override
  String get newsSource => '''Fuente de noticias''';

  @override
  String get article => '''Artículo''';

  @override
  String get articlePreview => '''Vista previa del artículo''';

  @override
  String get readFullArticle => '''Leer artículo completo''';

  @override
  String get extractingReaderArticleText => '''Extrayendo texto en modo lectura...''';

  @override
  String get extractingVisibleArticleText => '''Extrayendo texto visible de la página...''';

  @override
  String source(String source) {
    return '''Fuente: ${source}''';
  }

  @override
  String get readyStatus => '''Listo.''';

  @override
  String get preparingEdgeTts => '''Preparando lectura Edge TTS en bloques...''';

  @override
  String get noTextToRead => '''No hay texto para leer.''';

  @override
  String chunkCreated(int index, int total) {
    return '''Bloque ${index} de ${total} creado. Lectura en curso...''';
  }

  @override
  String playingChunk(int index, int total, int size) {
    return '''Reproduciendo bloque ${index} de ${total} (${size} bytes)...''';
  }

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) {
    return '''Lectura finalizada. Bloques creados: ${readyChunks}/${totalChunks}. Biblioteca: ${libraryPath}''';
  }

  @override
  String get libraryNotSpecified => '''no especificada''';

  @override
  String get readingStopped => '''Lectura detenida.''';

  @override
  String edgeTtsError(Object error) {
    return '''Error de Edge TTS: ${error}''';
  }

  @override
  String audioChunksReady(int readyChunks, int totalChunks) {
    return '''Bloques de audio listos: ${readyChunks} / ${totalChunks}''';
  }

  @override
  String get readingInProgress => '''Lectura en curso...''';

  @override
  String get readWithEdgeTts => '''Iniciar lectura''';

  @override
  String get stopReading => '''Detener lectura''';

  @override
  String get startReading => '''Iniciar lectura''';

  @override
  String get resumeReading => '''Reanudar lectura''';

  @override
  String get pauseReading => '''Pausar lectura''';

  @override
  String get openOriginalArticle => '''Abrir artículo original''';

  @override
  String get searchPodcasts => '''Buscar podcasts''';

  @override
  String get podcastName => '''Nombre del podcast''';

  @override
  String get podcastSearchHint => '''Ejemplo: tecnología, historia, el nombre del podcast...''';

  @override
  String get searchCountry => '''País de búsqueda''';

  @override
  String get browsePodcastCountries => '''Explorar por país''';

  @override
  String get podcastCountries => '''Países de podcasts''';

  @override
  String get podcastCategory => '''Categoría de podcast''';

  @override
  String get browsePodcastCategories => '''Explorar categorías''';

  @override
  String get selectedPodcastCategory => '''Categoría seleccionada''';

  @override
  String get selectedRecently => '''elección reciente''';

  @override
  String get podcastCategories => '''Categorías de podcasts''';

  @override
  String get countryItaly => '''Italia''';

  @override
  String get countryUnitedStatesEnglish => '''Estados Unidos / Inglés''';

  @override
  String get countryUnitedKingdom => '''Reino Unido''';

  @override
  String get countrySpain => '''España''';

  @override
  String get countryFrance => '''Francia''';

  @override
  String get searchInProgress => '''Búsqueda en curso...''';

  @override
  String get newsReadArticles => '''Artículos leídos''';

  @override
  String get weatherRecentCities => '''Ciudades recientes''';

  @override
  String podcastResultsFound(int count) {
    return '''${count} podcasts encontrados''';
  }

  @override
  String podcastSearchError(Object error) {
    return '''Error en la búsqueda de podcasts: ${error}''';
  }

  @override
  String subscribedTo(String title) {
    return '''Suscrito a ${title}''';
  }

  @override
  String subscriptionError(Object error) {
    return '''Error de suscripción: ${error}''';
  }

  @override
  String podcastSubscriptionError(Object error) {
    return '''Error de suscripción de podcast: ${error}''';
  }

  @override
  String get searchResults => '''Resultados de la búsqueda''';

  @override
  String get podcastInfo => '''Información del podcast''';

  @override
  String get subscribe => '''Suscribirse''';

  @override
  String get viewEpisodes => '''Ver episodios''';

  @override
  String get podcastAuthor => '''Autor''';

  @override
  String get noPodcastDescription => '''No hay descripción disponible.''';

  @override
  String get noPodcastResults => '''No se encontraron podcasts.''';

  @override
  String get loadingPodcastInfo => '''Cargando información del podcast''';

  @override
  String get podcastArtwork => '''Portada del podcast''';

  @override
  String get addFeedUrlManually => '''Añadir URL del feed RSS manualmente''';

  @override
  String get podcastFeedUrl => '''URL del feed RSS del podcast''';

  @override
  String get subscribeFromUrl => '''Suscribirse desde URL''';

  @override
  String get subscribedPodcasts => '''Podcasts suscritos''';

  @override
  String get noSubscribedPodcasts => '''No tienes podcasts suscritos. Busca un podcast y toca un resultado para suscribirte.''';

  @override
  String get localAudioFiles => '''Archivos de audio locales''';

  @override
  String get noLocalAudioFiles => '''No se encontraron archivos de audio locales.''';

  @override
  String get importAudioFromITunes => '''Importar audio desde iTunes / Apple Devices''';

  @override
  String localAudioFilesFound(int count) {
    return '''Archivos de audio locales encontrados: ${count}''';
  }

  @override
  String get importPodcastsFromFile => '''Importar podcasts desde archivo''';

  @override
  String get exportPodcastsToFile => '''Exportar podcasts a archivo OPML''';

  @override
  String podcastImportComplete(int count) {
    return '''Podcasts importados: ${count}''';
  }

  @override
  String podcastImportError(Object error) {
    return '''Error al importar podcasts: ${error}''';
  }

  @override
  String get podcastExportComplete => '''Podcasts exportados''';

  @override
  String podcastExportError(Object error) {
    return '''Error al exportar podcasts: ${error}''';
  }

  @override
  String get loadingEpisodes => '''Cargando episodios''';

  @override
  String get noAudioEpisodesFound => '''No se encontraron episodios de audio en el feed.''';

  @override
  String get episodes => '''Episodios''';

  @override
  String get episodeActions => '''Acciones del episodio''';

  @override
  String downloaded(String path) {
    return '''Descargado: ${path}''';
  }

  @override
  String episodeError(Object error) {
    return '''Error del episodio: ${error}''';
  }

  @override
  String get play => '''Reproducir''';

  @override
  String get pause => '''Pausar''';

  @override
  String get rewind15s => '''Retroceder 15s''';

  @override
  String get forward15s => '''Avanzar 15s''';

  @override
  String get stop => '''Stop''';

  @override
  String get back => '''Atrás''';

  @override
  String get episodePlayer => '''Reproductor de episodios''';

  @override
  String nowPlayingTitle(String title) {
    return '''Reproduciendo: ${title}''';
  }

  @override
  String get loadingEpisodeAudio => '''Cargando audio del episodio''';

  @override
  String get playbackPosition => '''Posición''';

  @override
  String playbackPositionValue(String position, String duration) {
    return '''${position} de ${duration}''';
  }

  @override
  String get adjustVolume => '''Ajustar volumen''';

  @override
  String volumeValue(int percentage) {
    return '''Volumen: ${percentage}%''';
  }

  @override
  String get download => '''Descargar''';

  @override
  String get searchWikipedia => '''Buscar en Wikipedia''';

  @override
  String get wikipediaLanguage => '''Idioma de Wikipedia''';

  @override
  String get search => '''Buscar''';

  @override
  String get wikipediaSearch => '''Búsqueda en Wikipedia''';

  @override
  String get wikipediaImporting => '''Importación de Wikipedia''';

  @override
  String get noWikipediaResults => '''No se encontraron resultados en Wikipedia''';

  @override
  String get wikipediaImportMode => '''Modo de importación''';

  @override
  String get wikipediaImportWholeArticle => '''Artículo completo''';

  @override
  String get documents => '''Documentos''';

  @override
  String get documentsHint => '''Abrir biblioteca de documentos''';

  @override
  String get documentLibrary => '''Biblioteca de documentos''';

  @override
  String get addToLibrary => '''Añadir a la biblioteca''';

  @override
  String get documentImportSelectionMode => '''¿Quieres seleccionar un documento o varios documentos?''';

  @override
  String get documentImportSingle => '''Un documento''';

  @override
  String get documentImportMultiple => '''Varios documentos''';

  @override
  String get noDocuments => '''No hay documentos. Añade un archivo.''';

  @override
  String get noDocumentsInLibrary => '''No hay documentos en la biblioteca.''';

  @override
  String get documentAdded => '''Documento añadido''';

  @override
  String get documentsAdded => '''Documentos añadidos''';

  @override
  String get importDocumentsFromITunes => '''Importar documentos desde iTunes / Apple Devices''';

  @override
  String sharedDocumentsImportComplete(int count) {
    return '''Documentos importados desde iTunes / Apple Devices: ${count}''';
  }

  @override
  String libraryLoadError(Object error) {
    return '''Error al cargar la biblioteca: ${error}''';
  }

  @override
  String fileOpenError(Object error) {
    return '''Error al abrir el archivo: ${error}''';
  }

  @override
  String get filePathUnavailable => '''Ruta del archivo no disponible.''';

  @override
  String fileInaccessible(String name) {
    return '''Archivo inaccesible: ${name}''';
  }

  @override
  String documentAddError(Object error) {
    return '''Error al añadir el documento: ${error}''';
  }

  @override
  String documentRemoveError(Object error) {
    return '''Error al eliminar: ${error}''';
  }

  @override
  String get noExportableTextFound => '''No se encontró texto exportable.''';

  @override
  String get modifiedDocumentNoExportableText => '''El documento modificado no contiene texto exportable.''';

  @override
  String get documentRemoved => '''Documento eliminado''';

  @override
  String get folderRemoved => '''Carpeta eliminada''';

  @override
  String get removeFolder => '''Eliminar carpeta''';

  @override
  String get removeDocument => '''Eliminar documento''';

  @override
  String get writeNewDocument => '''Escribir nuevo documento''';

  @override
  String get addDocumentToLibraryHint => '''Añadir documento a la biblioteca. Explora los archivos del dispositivo y añádelos.''';

  @override
  String get documentTypeLabel => '''Documento''';

  @override
  String get documentPosition => '''Posición del documento''';

  @override
  String get folderTypeLabel => '''Carpeta''';

  @override
  String documentAddedOn(String date) {
    return '''añadido el ${date}''';
  }

  @override
  String documentTypeDescription(String extension) {
    return '''tipo ${extension}''';
  }

  @override
  String get openFolderHint => '''Toca dos veces para abrir la carpeta''';

  @override
  String get openDocumentHint => '''Toca dos veces para abrir y leer el documento''';

  @override
  String removeItem(String name) {
    return '''Eliminar ${name}''';
  }

  @override
  String get removePodcast => '''Eliminar podcast''';

  @override
  String get podcastRemoved => '''Podcast eliminado''';

  @override
  String get documentPickerError => '''Error al abrir el archivo''';

  @override
  String get readDocument => '''Leer documento''';

  @override
  String get documentReaderTitle => '''Lector de documentos''';

  @override
  String get documentReaderEditHint => '''Toca un párrafo para editarlo. Desliza hacia arriba o hacia abajo para añadir un marcador.''';

  @override
  String get documentBookmarkHintSet => '''Desliza hacia arriba o hacia abajo para establecer un marcador.''';

  @override
  String get documentEditParagraphActionHint => '''Toca dos veces para editar este párrafo. ''';

  @override
  String get documentBookmarkHintReplace => '''Desliza hacia arriba o hacia abajo para eliminar el marcador existente o reemplazarlo por este párrafo.''';

  @override
  String get documentSetBookmarkAction => '''Añadir nuevo marcador''';

  @override
  String get documentRemoveBookmarkAction => '''Eliminar marcador''';

  @override
  String get documentReplaceBookmarkAction => '''Eliminar y añadir un nuevo marcador''';

  @override
  String get searchInDocument => '''Buscar en el documento''';

  @override
  String get documentSearchFieldLabel => '''Texto de búsqueda''';

  @override
  String get documentSearchFieldHint => '''Palabra o frase para buscar''';

  @override
  String get documentSearchEmptyQuery => '''Introduce el texto que quieres buscar.''';

  @override
  String get documentSearchResultsTitle => '''Resultados de búsqueda del documento''';

  @override
  String noDocumentSearchResults(String query) {
    return '''No se encontraron resultados para ${query}.''';
  }

  @override
  String documentSearchResultParagraph(int number) {
    return '''Párrafo ${number}''';
  }

  @override
  String get edit => '''Editar''';

  @override
  String get save => '''Guardar''';

  @override
  String get cancel => '''Cancelar''';

  @override
  String get settingsReadingEngine => '''Motor de lectura''';

  @override
  String get settingsEdgeTtsQuality => '''Edge TTS (Alta calidad en línea)''';

  @override
  String get settingsSystemVoices => '''Voces del sistema (VoiceOver / Google)''';

  @override
  String get settingsNoSystemVoices => '''No hay voces del sistema disponibles.''';

  @override
  String get settingsDefaultVoiceHint => '''Voz predeterminada''';

  @override
  String get settingsDefaultVoice => '''Predeterminada''';

  @override
  String get settingsVoiceSpeed => '''Velocidad: ''';

  @override
  String get settingsVoicePitch => '''Tono: ''';

  @override
  String get settingsVoiceSpeedLabel => '''Velocidad de lectura''';

  @override
  String get settingsVoicePitchLabel => '''Tono''';

  @override
  String get settingsTestVoice => '''Probar voz''';

  @override
  String get settingsTestingVoice => '''Reproduciendo...''';

  @override
  String get settingsVoiceTestText => '''Esta es una prueba de la voz seleccionada.''';

  @override
  String settingsVoiceTestError(Object error) {
    return '''Error de prueba de voz: ${error}''';
  }

  @override
  String settingsVoiceSaveError(Object error) {
    return '''Error al guardar la voz TTS: ${error}''';
  }

  @override
  String get settingsUnsavedTitle => '''Cambios sin guardar''';

  @override
  String get settingsUnsavedMessage => '''¿Quieres guardar los cambios antes de salir de ajustes?''';

  @override
  String get settingsExitWithoutSaving => '''Salir sin guardar''';

  @override
  String get settingsSystemLanguage => '''Idioma del sistema''';

  @override
  String get settingsSystemVoice => '''Voz del sistema''';

  @override
  String get settingsAutoBookmark => '''Reanudación automática''';

  @override
  String get settingsAutoBookmarkHint => '''Reanuda documentos, podcasts y contenido multimedia desde donde lo dejaste.''';

  @override
  String get settingsSeekStep => '''Intervalo de retroceso / avance rápido para multimedia''';

  @override
  String get aiChatIntro => '''Soy la inteligencia artificial de Sonarpad. ¿Cómo puedo ayudarte?''';

  @override
  String get meteoTitle => '''Tiempo''';

  @override
  String get weatherCity => '''Ciudad''';

  @override
  String get weatherCityHint => '''Ejemplo: Roma''';

  @override
  String get weatherCityNotFound => '''Ciudad no encontrada''';

  @override
  String get weatherSearchError => '''Error durante la búsqueda''';

  @override
  String get weatherToday => '''Hoy''';

  @override
  String get weatherCurrentSituation => '''Situación actual''';

  @override
  String get weatherTomorrow => '''Mañana''';

  @override
  String get weatherChooseDay => '''Elegir día''';

  @override
  String get weatherCurrentTemperature => '''Temperatura actual''';

  @override
  String get weatherMaxTemperature => '''Temperatura máxima''';

  @override
  String get weatherMinTemperature => '''Temperatura mínima''';

  @override
  String get weatherPrecipitation => '''Precipitaciones''';

  @override
  String get weatherPrecipitationProbability => '''Probabilidad de precipitación''';

  @override
  String get weatherWind => '''Viento''';

  @override
  String get weatherRelativeHumidity => '''Humedad relativa''';

  @override
  String get settingsSecretCode => '''Código Sonarpad para funciones extra''';

  @override
  String get settingsRequestCode => '''Solicitar código al autor''';

  @override
  String get settingsPasteCode => '''Pegar código''';

  @override
  String get settingsCancel => '''Cancelar''';

  @override
  String get settingsSend => '''Enviar''';

  @override
  String get settingsFillFieldsCode => '''Rellena todos los campos para solicitar el código.''';

  @override
  String get settingsName => '''Nombre''';

  @override
  String get settingsSurname => '''Apellido''';

  @override
  String get settingsEmail => '''Correo electrónico''';

  @override
  String get settingsOperatingSystem => '''Sistema operativo''';

  @override
  String settingsCodeRequestBody(String name, String surname, String email, String os) {
    return '''Nombre: ${name}; Apellido: ${surname}; Correo electrónico: ${email}; Sistema operativo: ${os}''';
  }

  @override
  String get settingsNameOptional => '''Nombre (opcional)''';

  @override
  String get settingsMessageOptional => '''Mensaje (opcional)''';

  @override
  String get settingsVerifyCodeAndSave => '''Verificando y guardando...''';

  @override
  String get settingsViewSysLog => '''Ver registro del sistema''';

  @override
  String settingsMailOpenError(Object error) {
    return '''Error al abrir el correo: ${error}''';
  }

  @override
  String get ok => '''OK''';

  @override
  String get invia => '''Enviar''';

  @override
  String get saveArticle => '''Guardar artículo''';

  @override
  String get shareArticle => '''Compartir artículo''';

  @override
  String get articleSavedSuccess => '''Artículo guardado en Documentos''';

  @override
  String get annulla => '''Cancelar''';

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice => '''Rellena todos los campos para solicitar el código.''';

  @override
  String get selectFolder => '''Seleccionar carpeta''';

  @override
  String get exportDocument => '''Exportar documento''';

  @override
  String get exportFormatPrompt => '''¿En qué formato deseas exportar el documento?''';

  @override
  String get textFormat => '''Texto (.txt)''';

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
  String get exportCompleteTitle => '''Exportación completada''';

  @override
  String get exportCompleteMessage => '''El archivo se creó correctamente. ¿Quieres guardarlo en Sonarpad o compartirlo?''';

  @override
  String get saveInSonarpad => '''Guardar en Sonarpad''';

  @override
  String get exportSavedInSonarpad => '''Archivo guardado en Documentos de Sonarpad.''';


  @override
  String get audiobookExportProgressTitle => '''Creación del audiolibro''';

  @override
  String get audiobookExportPreparing => '''Preparando el audiolibro...''';

  @override
  String get audiobookExportGeneratingAudio => '''Generando audio''';

  @override
  String get audiobookExportConvertingAudio => '''Conversión final del archivo de audio...''';

  @override
  String get audiobookExportFinalizing => '''Finalizando...''';


  @override
  String get exportError => '''Error de exportación''';

  @override
  String get newFolder => '''Nueva carpeta''';

  @override
  String get folderNameHint => '''Nombre de la carpeta''';

  @override
  String get create => '''Crear''';

  @override
  String get createNewFolder => '''Crear nueva carpeta''';

  @override
  String get importExternalSources => '''Importar desde fuentes externas''';

  @override
  String get importExternalSourcesTitle => '''Fuentes externas''';

  @override
  String get importFromDropbox => '''Importar documentos desde Dropbox''';

  @override
  String get importFromProjectGutenberg => '''Importar desde Project Gutenberg''';

  @override
  String get projectGutenbergImportUnavailable => '''La importación desde Project Gutenberg aún no está disponible.''';

  @override
  String get importFromInternetArchive => '''Importar desde Internet Archive''';

  @override
  String get internetArchiveTitle => '''Internet Archive''';

  @override
  String get internetArchiveSearchLabel => '''Buscar audio''';

  @override
  String get internetArchiveSourceLabel => '''Fuente''';

  @override
  String get internetArchiveOldTimeRadio => '''Radio antigua''';

  @override
  String get internetArchiveSpeeches => '''Discursos históricos''';

  @override
  String get internetArchiveLiveMusic => '''Live Music Archive''';

  @override
  String get internetArchiveNoItemsFound => '''No se encontraron audios.''';

  @override
  String get saveAudioInDocuments => '''Guardar audio en Documentos''';

  @override
  String get audioSavedInDocuments => '''Audio guardado en Documentos.''';

  @override
  String get noAudioTracksAvailable => '''No hay pistas de audio disponibles.''';

  @override
  String get importFromLibriVox => '''Importar desde LibriVox''';

  @override
  String get gutenbergSearchLabel => '''Buscar libro o autor''';

  @override
  String get sourceLanguageLabel => '''Idioma''';

  @override
  String get noGutenbergBooksFound => '''No se encontraron libros.''';

  @override
  String get loadMore => '''Cargar más''';

  @override
  String sourceLanguageValue(String language) {
    return '''Idioma: ${language}''';
  }

  @override
  String get gutenbergImportAndRead => '''Importar y leer''';

  @override
  String get gutenbergImporting => '''Importando...''';

  @override
  String get librivoxSearchLabel => '''Buscar audiolibro''';

  @override
  String get noLibrivoxAudiobooksFound => '''No se encontraron audiolibros.''';

  @override
  String get librivoxAudiobookSaved => '''Audiolibro guardado en Documentos.''';

  @override
  String get librivoxSaveAudiobook => '''Guardar audiolibro en Documentos''';

  @override
  String get librivoxSaving => '''Guardando...''';

  @override
  String get librivoxNoAudioTracks => '''No hay pistas de audio disponibles.''';

  @override
  String get librivoxNotTextExportable => '''Los audiolibros de LibriVox no se pueden exportar como texto.''';

  @override
  String sourceDurationValue(String duration) {
    return '''Duración: ${duration}''';
  }

  @override
  String get importFromPoetryDb => '''Importar desde PoetryDB''';

  @override
  String get poetryDbSearchLabel => '''Buscar poema''';

  @override
  String get poetryDbSearchBy => '''Buscar por''';

  @override
  String get poetryDbSearchByTitle => '''Título''';

  @override
  String get poetryDbSearchByAuthor => '''Autor''';

  @override
  String get poetryDbNoPoemsFound => '''No se encontraron poemas.''';

  @override
  String poetryDbLineCount(int count) {
    return '''${count} versos''';
  }

  @override
  String get moveDocument => '''Mover documento''';

  @override
  String get documentMoved => '''Movido correctamente''';

  @override
  String get outOfFolder => '''Fuera de la carpeta''';

  @override
  String get moveToAnotherFolder => '''Mover a otra carpeta...''';

  @override
  String get ttsError => '''Error de síntesis de voz''';

  @override
  String get editParagraph => '''Editar párrafo''';

  @override
  String get editParagraphTextField => '''Campo de texto para editar el párrafo''';

  @override
  String get editParagraphHint => '''Editar el texto del párrafo''';

  @override
  String get applyAndSave => '''Aplicar y guardar''';

  @override
  String get textEditedAndSaved => '''Texto editado y guardado en el documento actual.''';

  @override
  String get saveError => '''Error al guardar''';

  @override
  String get docSavedInLibrary => '''Documento guardado en la biblioteca''';

  @override
  String get saveInLibrary => '''Guardar en la biblioteca''';

  @override
  String get documentTextLabel => '''Texto del documento''';

  @override
  String get modifiedInSonarpad => '''Modificado en Sonarpad''';

  @override
  String get noTextAvailableForDocument => '''No hay texto disponible para este documento.''';

  @override
  String bookmarkSet(int index) {
    return '''Marcador establecido en el párrafo ${index}.''';
  }

  @override
  String get bookmarkRemoved => '''Marcador eliminado.''';

  @override
  String get docEmpty => '''El documento está vacío''';

  @override
  String get docSavedSuccessfully => '''¡Documento guardado con éxito!''';

  @override
  String get writeDocument => '''Escribir documento''';

  @override
  String get documentTitleOptional => '''Título (opcional)''';

  @override
  String get documentTitleHint => '''Ejemplo: Notas de compra''';

  @override
  String get documentTextField => '''Texto del documento''';

  @override
  String get documentTextHint => '''Empieza a escribir aquí...''';

  @override
  String get newDocumentDefaultName => '''Nuevo_Documento''';

  @override
  String get saving => '''Guardando...''';

  @override
  String get saveDocument => '''Guardar documento''';

  @override
  String get addRssSource => '''Agregar fuente RSS''';

  @override
  String get add => '''Agregar''';

  @override
  String get errorPrefix => '''Error''';

  @override
  String versionBuild(String version, String buildNumber) {
    return '''Versión ${version} (Build ${buildNumber})''';
  }

  @override
  String get whatIsNew => '''Novedades''';

  @override
  String whatIsNewInVersion(String version) {
    return '''Novedades de la versión ${version}''';
  }

  @override
  String changelogLoadError(Object error) {
    return '''Error al cargar las novedades: ${error}''';
  }

  @override
  String get visitSonarpadSite => '''Visitar el sitio de Sonarpad''';

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return '''Visitar el sitio de Sonarpad: ${url}''';
  }

  @override
  String get nowPlaying => '''Reproduciendo''';

  @override
  String get fileImported => '''Archivo importado''';

  @override
  String importZipError(Object error) {
    return '''Error al importar ZIP: ${error}''';
  }

  @override
  String get dropboxLoginPrompt => '''Inicia sesión en Dropbox para importar tus documentos.''';

  @override
  String get loginToDropbox => '''Iniciar sesión en Dropbox''';

  @override
  String get logoutFromDropbox => '''Cerrar sesión''';

  @override
  String get dropboxLoginFailed => '''Inicio de sesión fallido o cancelado''';

  @override
  String dropboxLoadFolderError(Object error) {
    return '''Error al cargar la carpeta: ${error}''';
  }

  @override
  String dropboxImportError(Object error) {
    return '''Error de importación: ${error}''';
  }

  @override
  String get retry => '''Reintentar''';

  @override
  String get goBack => '''.. Volver''';

  @override
  String get noSupportedFilesInFolder => '''No hay archivos compatibles en esta carpeta.''';

  @override
  String get articleNotFound => '''Artículo no encontrado.''';

  @override
  String get errorOpening => '''Error al abrir''';

  @override
  String get recentArticles => '''Artículos recientes''';

  @override
  String get clearHistory => '''Borrar historial''';

  @override
  String get confirmClearHistory => '''¿Realmente deseas borrar todas las búsquedas recientes?''';

  @override
  String get clear => '''Borrar''';

  @override
  String get noRecentSearches => '''No hay búsquedas recientes.''';

  @override
  String get logCopiedToClipboard => '''Registro copiado al portapapeles''';

  @override
  String get systemLog => '''Registro del sistema''';

  @override
  String get clearSystemLog => '''Vaciar registro''';

  @override
  String get copySystemLog => '''Copiar registro''';

  @override
  String get donateWithPaypal => '''Donar con PayPal''';

  @override
  String get bankTransferTitle => '''Transferencia bancaria''';

  @override
  String get enableVideo => '''Activar vídeo''';

  @override
  String get calendar => '''Calendario''';

  @override
  String get calendarHint => '''Ver calendario, festivos, santo del día y tus recordatorios''';

  @override
  String get saintOfTheDay => '''Santo del día''';

  @override
  String get quoteOfTheDay => '''Cita del día''';

  @override
  String get reminders => '''Recordatorios''';

  @override
  String get addReminder => '''Añadir recordatorio''';

  @override
  String get removeReminder => '''Eliminar recordatorio''';

  @override
  String get noReminders => '''Sin recordatorios''';

  @override
  String get writeReminder => '''Escribe aquí tu recordatorio...''';

  @override
  String get saveReminder => '''Guardar''';

  @override
  String get cancelReminder => '''Cancelar''';

  @override
  String get backToToday => '''Volver a hoy''';

  @override
  String get calendarToday => '''Hoy''';

  @override
  String get calendarTomorrow => '''Mañana''';

  @override
  String get calendarYesterday => '''Ayer''';

  @override
  String get share => '''Compartir''';

  @override
  String get shareCalendarDayOptions => '''Opciones para compartir''';

  @override
  String get shareCalendarDayOnly => '''Compartir solo el día''';

  @override
  String get shareCalendarDayWithReminder => '''Compartir día y recordatorio''';

  @override
  String get listenToAll => '''Escuchar todo''';

  @override
  String reminderSaved(int count) {
    return '''${count} recordatorios''';
  }

  @override
  String get audiodescriptionTitle => '''Audiodescripciones''';

  @override
  String get audiodescriptionRecent => '''Recientes''';

  @override
  String get audiodescriptionAll => '''Todas las audiodescripciones''';



  @override
  String get audiodescriptionFilm => '''Películas''';

  @override
  String get audiodescriptionSearch => '''Buscar...''';

  @override
  String get audiodescriptionLoading => '''Cargando...''';

  @override
  String get audiodescriptionError => '''Error al cargar el catálogo''';

  @override
  String get audiodescriptionEmpty => '''No se encontraron elementos''';

  @override
  String get radio => '''Radio''';

  @override
  String get radioHint => '''Busca emisoras de radio, escucha transmisiones y gestiona favoritos''';

  @override
  String get radioTitle => '''Emisoras de radio de todo el mundo''';

  @override
  String get radioFavoritesButton => '''Emisoras favoritas''';

  @override
  String get radioNoFavorites => '''No hay emisoras favoritas.''';

  @override
  String get radioSearchText => '''Buscar emisoras''';

  @override
  String get radioSearchHint => '''Nombre de la emisora o ciudad...''';

  @override
  String get radioLanguage => '''Idioma''';

  @override
  String get radioBrowseBy => '''Explorar por''';

  @override
  String get radioBrowseByLanguage => '''Explorar por idioma''';

  @override
  String get radioBrowseByCountry => '''Explorar por país''';

  @override
  String get radioCountry => '''País''';

  @override
  String get radioGenre => '''Género''';

  @override
  String get radioSearch => '''Buscar''';

  @override
  String get radioSearching => '''Cargando radios...''';

  @override
  String get radioSearchResults => '''Resultados de radio''';

  @override
  String get radioNoResults => '''No se encontraron radios.''';

  @override
  String radioResultsFound(int count) {
    return '''${count} emisoras encontradas''';
  }

  @override
  String radioSearchError(Object error) {
    return '''Error en la búsqueda de radio: ${error}''';
  }

  @override
  String radioNowPlaying(String name) {
    return '''Reproduciendo ${name}''';
  }

  @override
  String radioPlayError(Object error) {
    return '''Error en la transmisión de radio: ${error}''';
  }

  @override
  String get radioAddFavorite => '''Añadir a favoritos''';

  @override
  String get radioRemoveFavorite => '''Eliminar de favoritos''';

  @override
  String radioFavoriteAdded(String name) {
    return '''${name} añadida a favoritos.''';
  }

  @override
  String radioFavoriteRemoved(String name) {
    return '''${name} eliminada de favoritos.''';
  }

  @override
  String get tvSearchFieldLabel => '''Buscar canales de TV''';

  @override
  String get tvSearchFieldHint => '''Nombre del canal...''';

  @override
  String get tvSearchButton => '''Buscar''';

  @override
  String get tvSearchResults => '''Resultados de canales de TV''';

  @override
  String get tvSearchEmptyQuery => '''Introduce el nombre de un canal de TV para buscarlo.''';

  @override
  String tvSearchNoResults(String query) {
    return '''No se encontraron canales de TV para ${query}.''';
  }

  @override
  String get tvOpenChannelHint => '''Toca para reproducir el canal de TV''';

  @override
  String tvNowOnAir(String title) {
    return '''Ahora en emisión: ${title}''';
  }

  @override
  String get radioAddCommunity => '''Añadir radio a la comunidad Sonarpad''';

  @override
  String get radioAddName => '''Nombre de la radio''';

  @override
  String get radioAddUrl => '''Dirección de la transmisión''';

  @override
  String get radioAddSubmit => '''Verificar y añadir''';

  @override
  String get radioAddMissingFields => '''Por favor ingresa el nombre de la radio y la dirección de la transmisión.''';

  @override
  String get radioCommunityAdded => '''Radio añadida con éxito a la comunidad Sonarpad.''';

  @override
  String radioCommunityAddError(Object error) {
    return '''Error al añadir la radio: ${error}''';
  }

  @override
  String get radioPlay => '''Reproducir''';

  @override
  String get startRecording => '''Iniciar grabación''';

  @override
  String get stopRecording => '''Detener grabación''';

  @override
  String get recordings => '''Grabaciones''';

  @override
  String get noRecordings => '''No hay grabaciones.''';

  @override
  String get recordingStarted => '''Grabación iniciada.''';

  @override
  String recordingSaved(Object path) {
    return '''Grabación guardada: ${path}''';
  }

  @override
  String recordingError(Object error) {
    return '''Error de grabación: ${error}''';
  }

  @override
  String get routeTitle => '''Rutas''';

  @override
  String get routeFrom => '''De''';

  @override
  String get routeTo => '''A''';

  @override
  String get routeCountry => '''País''';

  @override
  String get routeCountryItaly => '''Italia''';

  @override
  String get routeCountryFrance => '''Francia''';

  @override
  String get routeCountrySpain => '''España''';

  @override
  String get routeVehicle => '''Medio de transporte''';

  @override
  String get routeType => '''Tipo''';

  @override
  String get routeIncludeMunicipalities => '''Incluir los municipios atravesados''';

  @override
  String get routeWalking => '''Caminando''';

  @override
  String get routeCycling => '''En bicicleta''';

  @override
  String get routeDriving => '''En coche''';

  @override
  String get routeWheelchair => '''En silla de ruedas''';

  @override
  String get routeFastest => '''Más rápido''';

  @override
  String get routeShortest => '''Más corto''';

  @override
  String get routeCalculate => '''Calcular ruta''';

  @override
  String get routeCalculating => '''Calculando...''';

  @override
  String get routeChooseFrom => '''Elige el punto de partida''';

  @override
  String get routeChooseTo => '''Elige el destino''';

  @override
  String get routeCancel => '''Cancelar''';

  @override
  String get routeErrorMissingFields => '''Introduce el punto de partida y el destino''';

  @override
  String get routeErrorFromNotFound => '''No se encontró ningún resultado para la dirección de salida''';

  @override
  String get routeErrorToNotFound => '''No se encontró ningún resultado para la dirección de llegada''';

  @override
  String get routeResultsTitle => '''Rutas disponibles''';

  @override
  String get routeDistance => '''Distancia''';

  @override
  String get routeDuration => '''Duración''';

  @override
  String get routeNavigation => '''Detalles de navegación''';

  @override
  String get routeStartMunicipality => '''Municipio de salida''';

  @override
  String get routeEnterMunicipality => '''Entras en el municipio de''';

  @override
  String routeError(Object error) {
    return '''Error: ${error}''';
  }

  @override
  String get radioLanguageIt => '''Italiano''';

  @override
  String get radioLanguageEn => '''Inglés''';

  @override
  String get radioLanguageDe => '''Alemán''';

  @override
  String get radioLanguageCountryCh => '''Suiza''';

  @override
  String get radioLanguageEs => '''Español''';

  @override
  String get radioLanguagePt => '''Portugués''';

  @override
  String get radioLanguageSv => '''Sueco''';

  @override
  String get radioLanguageVi => '''Vietnamita''';

  @override
  String get radioLanguageCs => '''Checo''';

  @override
  String get radioLanguagePl => '''Polaco''';

  @override
  String get radioLanguageFr => '''Francés''';

  @override
  String get radioLanguageSr => '''Serbio''';

  @override
  String get radioLanguageUk => '''Ucraniano''';

  @override
  String get radioLanguageHi => '''Hindi''';

  @override
  String get radioLanguageLt => '''Lituano''';

  @override
  String get radioLanguageRu => '''Ruso''';

  @override
  String get radioLanguageZh => '''Chino''';

  @override
  String get radioCountryOptionIt => '''Italia''';

  @override
  String get radioCountryOptionUs => '''Estados Unidos''';

  @override
  String get radioCountryOptionGb => '''Reino Unido''';

  @override
  String get radioCountryOptionFr => '''Francia''';

  @override
  String get radioCountryOptionEs => '''España''';

  @override
  String get radioCountryOptionDe => '''Alemania''';

  @override
  String get radioCountryOptionCh => '''Suiza''';

  @override
  String get radioCountryOptionAt => '''Austria''';

  @override
  String get radioCountryOptionBe => '''Bélgica''';

  @override
  String get radioCountryOptionNl => '''Países Bajos''';

  @override
  String get radioCountryOptionPt => '''Portugal''';

  @override
  String get radioCountryOptionBr => '''Brasil''';

  @override
  String get radioCountryOptionAr => '''Argentina''';

  @override
  String get radioCountryOptionMx => '''México''';

  @override
  String get radioCountryOptionCa => '''Canadá''';

  @override
  String get radioCountryOptionAu => '''Australia''';

  @override
  String get radioCountryOptionIe => '''Irlanda''';

  @override
  String get radioCountryOptionSe => '''Suecia''';

  @override
  String get radioCountryOptionPl => '''Polonia''';

  @override
  String get radioCountryOptionJp => '''Japón''';

  @override
  String get radioGenreOptionAll => '''Todos los géneros''';

  @override
  String get radioGenreOptionNews => '''Noticias''';

  @override
  String get radioGenreOptionMusic => '''Música''';

  @override
  String get radioGenreOptionSport => '''Deporte''';

  @override
  String get radioGenreOptionTalk => '''Charlas y análisis''';

  @override
  String get radioGenreOptionPop => '''Pop''';

  @override
  String get radioGenreOptionRock => '''Rock''';

  @override
  String get radioGenreOptionClassical => '''Clásica''';

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
  String get radioGenreOptionElectronic => '''Electrónica''';

  @override
  String get radioGenreOptionLatin => '''Latina''';

  @override
  String get radioGenreOptionReggae => '''Reggae''';

  @override
  String get radioGenreOptionMetal => '''Metal''';

  @override
  String get radioGenreOptionFolk => '''Folk''';

  @override
  String get radioGenreOptionReligion => '''Religión''';

  @override
  String get radioGenreOptionLocal => '''Local''';

  @override
  String get radioGenreOptionCulture => '''Cultura''';

  @override
  String get radioGenreOptionOldies => '''Años 70 / 80 / 90''';

  @override
  String get radioGenreOptionKids => '''Infantil''';

  @override
  String get radioGenreOptionAmbient => '''Ambient''';

  @override
  String get radioCommunityLanguageItalian => '''Italiano''';

  @override
  String get radioCommunityLanguageEnglish => '''Inglés''';

  @override
  String get radioCommunityLanguageSpanish => '''Español''';

  @override
  String get radioCommunityLanguageFrench => '''Francés''';

  @override
  String get radioCommunityLanguageGerman => '''Alemán''';

  @override
  String get radioCommunityLanguagePortuguese => '''Portugués''';

  @override
  String get radioCommunityLanguageSwedish => '''Sueco''';

  @override
  String get radioCommunityLanguageVietnamese => '''Vietnamita''';

  @override
  String get radioCommunityLanguageCzech => '''Checo''';

  @override
  String get radioCommunityLanguagePolish => '''Polaco''';

  @override
  String get radioCommunityLanguageSerbian => '''Serbio''';

  @override
  String get radioCommunityLanguageUkrainian => '''Ucraniano''';

  @override
  String get radioCommunityLanguageLithuanian => '''Lituano''';

  @override
  String get radioCommunityLanguageRussian => '''Ruso''';

  @override
  String get radioCommunityLanguageChinese => '''Chino''';

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
  String get cinemaTitle => '''Películas en cines''';

  @override
  String get cinemaNoMovies => '''No se encontraron películas en este momento.''';

  @override
  String get cinemaError => '''Error al cargar las películas.''';

  @override
  String cinemaReleased(String date) {
    return '''Estreno: ${date}''';
  }

  @override
  String get cinemaOverviewLabel => '''Trama:''';

  @override
  String get cinemaUpcomingReleases => '''Próximos estrenos''';

  @override
  String cinemaWillRelease(String date) {
    return '''Se estrenará el: ${date}''';
  }

  @override
  String get cinemaOpenTrailer => '''Ver tráiler''';

  @override
  String get concertsTitle => '''Conciertos y eventos''';

  @override
  String get concertsSearchHint => '''Introduce una ciudad (ej. Madrid, Barcelona)''';

  @override
  String get concertsSearchLabel => '''Buscar conciertos por ciudad''';

  @override
  String get concertsSearchTooltip => '''Buscar''';

  @override
  String get concertsInitialText => '''Escribe el nombre de tu ciudad arriba para ver los próximos conciertos musicales.''';

  @override
  String get concertsEmpty => '''No se encontraron conciertos en esta ciudad.''';

  @override
  String get concertsVenue => '''Lugar del concierto:''';

  @override
  String get concertsBuyTickets => '''Comprar o ver detalles en Ticketmaster''';

  @override
  String get podcastPlayedEpisodes => '''Episodios reproducidos''';

  @override
  String get podcastUnplayed => '''Episodios no reproducidos''';

  @override
  String get routeReadAction => '''Leer ruta''';

  @override
  String get routeSaveAction => '''Guardar en documentos''';

  @override
  String get routeSaveSuccess => '''Ruta guardada en documentos''';


  @override
  String get routeRecentRoutes => '''Rutas recientes''';

  @override
  String get routeRecentRoutesEmpty => '''No hay rutas recientes''';

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) {
    return '''Detalles de navegación de ${from} a ${to} - ${date}''';
  }

}
