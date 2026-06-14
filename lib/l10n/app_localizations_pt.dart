// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Sonarpad';

  @override
  String get appLanguage => 'Idioma da app';

  @override
  String get settingsTheme => 'Tema da app';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Escuro';

  @override
  String get homeSemanticsLabel => 'Sonarpad, ecrã principal';

  @override
  String get settings => 'Definições';

  @override
  String get settingsHint => 'Abrir definições';

  @override
  String get info => 'Informações';

  @override
  String get infoHint => 'Abrir informações sobre a app';

  @override
  String get categoryReading => 'Leitura e documentos';

  @override
  String get categoryMedia => 'Multimédia e entretenimento';

  @override
  String get categoryUtilities => 'Pesquisas e utilitários';

  @override
  String get voiceDictionaryTitle => 'Dicionário de voz';

  @override
  String get voiceDictionaryAdd => 'Adicionar entradas ao dicionário';

  @override
  String get voiceDictionaryOriginalWord => 'Palavra original';

  @override
  String get voiceDictionaryReplacementWord => 'Palavra substituta';

  @override
  String get voiceDictionaryMatchCase => 'Distinguir maiúsculas e minúsculas';

  @override
  String get voiceDictionaryIgnoreCase => 'Ignorar maiúsculas e minúsculas';

  @override
  String get voiceDictionaryEntries => 'Entradas do dicionário';

  @override
  String get voiceDictionaryEmpty => 'Nenhuma entrada no dicionário.';

  @override
  String get voiceDictionaryRemove => 'Remover entrada selecionada';

  @override
  String get voiceDictionaryOriginalRequired => 'Introduza a palavra original.';

  @override
  String get convertMediaTitle => 'Converter multimédia';

  @override
  String get convertMediaInput => 'Ficheiro a converter';

  @override
  String get convertMediaOutput => 'Pasta de gravação';

  @override
  String get convertMediaImage => 'Imagem';

  @override
  String get convertMediaBrowse => 'Procurar...';

  @override
  String get convertMediaFormat => 'Formato';

  @override
  String get convertMediaBitrate => 'Bitrate (kbps)';

  @override
  String get convertMediaOggQuality => 'Qualidade (q)';

  @override
  String get convertMediaFlacCompression => 'Nível de compressão';

  @override
  String get convertMediaWavBitDepth => 'Profundidade de bits WAV';

  @override
  String get convertMediaReady => 'Pronto.';

  @override
  String get convertMediaRunning => 'A converter...';

  @override
  String get convertMediaDone => 'Conversão concluída.';

  @override
  String get convertMediaButton => 'Convertir';

  @override
  String get convertMediaNoInput => 'Selecione um ficheiro para converter.';

  @override
  String get convertMediaNoOutput => 'Selecione uma pasta de gravação.';

  @override
  String get convertMediaNoImage => 'Selecione uma imagem para o vídeo.';

  @override
  String get convertMediaSamePath =>
      'O ficheiro convertido deve ser diferente do ficheiro de origem.';

  @override
  String get convertMediaInvalidBitrate =>
      'Introduza um bitrate válido entre 64 e 320 kbps.';

  @override
  String convertMediaFailed(Object error) {
    return 'A conversão falhou: $error';
  }

  @override
  String get donations => 'Donativos';

  @override
  String get donationsHint => 'Apoiar o desenvolvimento do Sonarpad';

  @override
  String get loading => 'A carregar';

  @override
  String get ttsVoiceLanguage => 'Idioma da voz TTS';

  @override
  String get ttsVoice => 'Voz TTS';

  @override
  String get saveSettings => 'Guardar definições';

  @override
  String get settingsSaved => 'Definições guardadas.';

  @override
  String get settingsSavedTitle => 'Definições guardadas';

  @override
  String get sonarpadCodeValidTitle => 'Código válido';

  @override
  String get sonarpadCodeValidMessage =>
      'El código Sonarpad es correcto. Ajustes guardados.';

  @override
  String get sonarpadCodeInvalidTitle => 'Código inválido';

  @override
  String get sonarpadCodeInvalidMessage =>
      'O código Sonarpad não é válido. Comprueba que lo hayas copiado sin espacios adicionales.';

  @override
  String get infoDescription =>
      'Sonarpad é uma aplicação simples com muitas funções. Pensada para ser acessível com VoiceOver para pessoas cegas ou com deficiência visual, permite ouvir notícias, pesquisar e subscrever podcasts, importar artigos da Wikipédia, adicionar documentos à biblioteca, guardá-los e editá-los. Sonarpad é atualizado constantemente e cada função foi pensada para facilitar a vida diária.';

  @override
  String get infoAuthor => 'Autor: Ambrogio Riili';

  @override
  String get donationsIntro =>
      'Sonarpad foi criado inicialmente para responder a necessidades pessoais, mas com o tempo tornou-se uma aplicação mais completa. O seu desenvolvimento exige trabalho constante: melhorar funções, corrigir erros, explorar novas ideias e testar cuidadosamente cada função.\n\nSe o Sonarpad lhe for útil e quiser apoiar o seu desenvolvimento, pode fazer um donativo.';

  @override
  String get donationsPaypalDesc =>
      'Puedes donar a través de PayPal usando este enlace:\nhttps://www.paypal.me/ambrogio86\nPor favor, si es posible, añade \"Sonarpad\" como nota de pago.';

  @override
  String get donationsBankDesc =>
      'Também pode fazer um donativo por transferência bancária para a conta em nome de Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nSe possível, use uma descrição clara, por exemplo “Sonarpad”.';

  @override
  String get donationsThanks =>
      'Quem apoiar o projeto será mencionado na aplicação e no repositório GitHub, salvo se preferir ficar anónimo ou usar um pseudónimo.\n\nObrigado a Jiri Holzinger e Paola Vagata pela contribuição.\nPela tradução vietnamita, obrigado a Anh Đức Nguyễn.\nPela tradução checa, obrigado a Radek Žalud e Jiri Holzinger.\nPela tradução espanhola, obrigado a Arturo Fernandez Rivas.\nPela tradução sérvia, obrigado a Mila Kuran.\nPela tradução ucraniana, obrigado a Ivan Shtefuriak.';

  @override
  String get news => 'Notícias';

  @override
  String get newsHint => 'Abrir notícias do Google News RSS';

  @override
  String get podcasts => 'Podcasts';

  @override
  String get podcastsHint =>
      'Suscríbete a podcasts, reproduce o descarga episodios';

  @override
  String get importFromWikipedia => 'Wikipedia';

  @override
  String get wikipediaHint =>
      'Pesquisar um artigo da Wikipédia e importar o texto';

  @override
  String get newsCategoryTop => 'Titulares';

  @override
  String get settingsHomeGrouping =>
      'Agrupar os ícones da página inicial em categorias';

  @override
  String get settingsHomeGroupingHint =>
      'Se desativado, os ícones principais aparecem numa única lista sem subpastas.';

  @override
  String get newsCategoryMyCity => 'A minha cidade';

  @override
  String get newsLocalCityLabel => 'Introduza a sua cidade';

  @override
  String get newsLocalCityHint => 'Corrige a cidade usada para notícias locais';

  @override
  String get update => 'Atualizar';

  @override
  String get moveUp => 'Mover hacia arriba';

  @override
  String get moveDown => 'Mover hacia abajo';

  @override
  String get hide => 'Eliminar';

  @override
  String get moveToPosition => 'Mover para a posição';

  @override
  String positionLabel(int position, String targetName) {
    return 'Posição $position: antes de $targetName';
  }

  @override
  String get positionLabelLast => 'Última posição';

  @override
  String get restoreHiddenSources => 'Restaurar fontes eliminadas';

  @override
  String get addCustomNewsSource => 'Adicionar fonte RSS personalizada';

  @override
  String get newsSourceName => 'Nome da fonte ou do site';

  @override
  String get newsSourceUrlOrSearch =>
      'URL do site, feed RSS ou palavra de pesquisa';

  @override
  String get deleteNewsSource => 'Eliminar fonte';

  @override
  String get articleTextSemantics => 'Texto do artigo';

  @override
  String get newsLanguage => 'Idioma das notícias';

  @override
  String get loadingNews => 'A carregar notícias';

  @override
  String error(Object error) {
    return 'Erro: $error';
  }

  @override
  String get noNewsFound => 'Nenhuma notícia encontrada';

  @override
  String get loadingArticle => 'A carregar artigo';

  @override
  String get noFullArticleFound =>
      'Artigo completo indisponível. A mostrar o resumo do feed.';

  @override
  String get italian => 'Italiano';

  @override
  String get english => 'Inglês';

  @override
  String get french => 'Francês';

  @override
  String get spanish => 'Espanhol';

  @override
  String get newsSource => 'Fonte de notícias';

  @override
  String get article => 'Artigo';

  @override
  String get articlePreview => 'Pré-visualização do artigo';

  @override
  String get readFullArticle => 'Ler artigo completo';

  @override
  String get extractingReaderArticleText => 'A extrair texto em modo leitor...';

  @override
  String get extractingVisibleArticleText =>
      'A extrair texto visível da página...';

  @override
  String source(String source) {
    return 'Fonte: $source';
  }

  @override
  String get readyStatus => 'Pronto.';

  @override
  String get preparingEdgeTts => 'A preparar leitura Edge TTS em blocos...';

  @override
  String get noTextToRead => 'Não há texto para ler.';

  @override
  String chunkCreated(int index, int total) {
    return 'Bloco $index de $total creado. Leitura em curso...';
  }

  @override
  String playingChunk(int index, int total, int size) {
    return 'A reproduzir bloque $index de $total ($size bytes)...';
  }

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) {
    return 'Leitura concluída. Blocos criados: $readyChunks/$totalChunks. Biblioteca: $libraryPath';
  }

  @override
  String get libraryNotSpecified => 'não especificada';

  @override
  String get readingStopped => 'Leitura parada.';

  @override
  String edgeTtsError(Object error) {
    return 'Erro de Edge TTS: $error';
  }

  @override
  String audioChunksReady(int readyChunks, int totalChunks) {
    return 'Blocos de áudio listos: $readyChunks / $totalChunks';
  }

  @override
  String get readingInProgress => 'Leitura em curso...';

  @override
  String get readWithEdgeTts => 'Iniciar leitura';

  @override
  String get stopReading => 'Parar leitura';

  @override
  String get startReading => 'Iniciar leitura';

  @override
  String get resumeReading => 'Retomar leitura';

  @override
  String get pauseReading => 'Pausar leitura';

  @override
  String get openOriginalArticle => 'Abrir artigo original';

  @override
  String get searchPodcasts => 'Pesquisar podcasts';

  @override
  String get podcastName => 'Nome do podcast';

  @override
  String get podcastSearchHint =>
      'Exemplo: tecnologia, história, nome do podcast...';

  @override
  String get searchCountry => 'País da pesquisa';

  @override
  String get podcastCategory => 'Categoria de podcast';

  @override
  String get browsePodcastCategories => 'Explorar categorias';

  @override
  String get selectedPodcastCategory => 'Categoria selecionada';

  @override
  String get podcastCategories => 'Categorias de podcasts';

  @override
  String get countryItaly => 'Itália';

  @override
  String get countryUnitedStatesEnglish => 'Estados Unidos / Inglês';

  @override
  String get countryUnitedKingdom => 'Reino Unido';

  @override
  String get countrySpain => 'Espanha';

  @override
  String get countryFrance => 'França';

  @override
  String get searchInProgress => 'Pesquisa em curso...';

  @override
  String get newsReadArticles => 'Artigos lidos';

  @override
  String get weatherRecentCities => 'Cidades recentes';

  @override
  String podcastResultsFound(int count) {
    return '$count podcasts encontrados';
  }

  @override
  String podcastSearchError(Object error) {
    return 'Erro na pesquisa de podcasts: $error';
  }

  @override
  String subscribedTo(String title) {
    return 'Subscrito a $title';
  }

  @override
  String subscriptionError(Object error) {
    return 'Erro de subscrição: $error';
  }

  @override
  String podcastSubscriptionError(Object error) {
    return 'Erro de subscrição de podcast: $error';
  }

  @override
  String get searchResults => 'Resultados da pesquisa';

  @override
  String get podcastInfo => 'Informações do podcast';

  @override
  String get subscribe => 'Subscrever';

  @override
  String get viewEpisodes => 'Ver episódios';

  @override
  String get podcastAuthor => 'Autor';

  @override
  String get noPodcastDescription => 'Nenhuma descrição disponível.';

  @override
  String get noPodcastResults => 'Nenhum podcast encontrado.';

  @override
  String get loadingPodcastInfo => 'A carregar informações do podcast';

  @override
  String get podcastArtwork => 'Imagem do podcast';

  @override
  String get addFeedUrlManually => 'Adicionar URL do feed RSS manualmente';

  @override
  String get podcastFeedUrl => 'URL do feed RSS do podcast';

  @override
  String get subscribeFromUrl => 'Subscrever a partir de URL';

  @override
  String get subscribedPodcasts => 'Podcasts subscritos';

  @override
  String get noSubscribedPodcasts =>
      'Não tem podcasts subscritos. Pesquise um podcast e toque num resultado para subscrever.';

  @override
  String get localAudioFiles => 'Ficheiros de áudio locais';

  @override
  String get noLocalAudioFiles => 'Nenhum ficheiro de áudio local encontrado.';

  @override
  String get importAudioFromITunes =>
      'Importar áudio do iTunes / Apple Devices';

  @override
  String localAudioFilesFound(int count) {
    return 'Ficheiros de áudio locais encontrados: $count';
  }

  @override
  String get importPodcastsFromFile => 'Importar podcasts de ficheiro';

  @override
  String get exportPodcastsToFile => 'Exportar podcasts para ficheiro OPML';

  @override
  String podcastImportComplete(int count) {
    return 'Podcasts importados: $count';
  }

  @override
  String podcastImportError(Object error) {
    return 'Erro al importar podcasts: $error';
  }

  @override
  String get podcastExportComplete => 'Podcasts exportados';

  @override
  String podcastExportError(Object error) {
    return 'Erro al exportar podcasts: $error';
  }

  @override
  String get loadingEpisodes => 'A carregar episodios';

  @override
  String get noAudioEpisodesFound =>
      'Nenhum episódio de áudio encontrado no feed.';

  @override
  String get episodes => 'Episódios';

  @override
  String get episodeActions => 'Ações do episódio';

  @override
  String downloaded(String path) {
    return 'Descarregado: $path';
  }

  @override
  String episodeError(Object error) {
    return 'Erro do episódio: $error';
  }

  @override
  String get play => 'Reproduzir';

  @override
  String get pause => 'Pausar';

  @override
  String get rewind15s => 'Retroceder 15s';

  @override
  String get forward15s => 'Avanzar 15s';

  @override
  String get stop => 'Parar';

  @override
  String get back => 'Voltar';

  @override
  String get episodePlayer => 'Leitor de episódios';

  @override
  String nowPlayingTitle(String title) {
    return 'A reproduzir: $title';
  }

  @override
  String get loadingEpisodeAudio => 'A carregar áudio do episódio';

  @override
  String get playbackPosition => 'Posição';

  @override
  String playbackPositionValue(String position, String duration) {
    return '$position de $duration';
  }

  @override
  String get adjustVolume => 'Ajustar volume';

  @override
  String volumeValue(int percentage) {
    return 'Volume: $percentage%';
  }

  @override
  String get download => 'Descarregar';

  @override
  String get searchWikipedia => 'Pesquisar na Wikipédia';

  @override
  String get wikipediaLanguage => 'Idioma da Wikipédia';

  @override
  String get search => 'Pesquisar';

  @override
  String get wikipediaSearch => 'Pesquisa na Wikipédia';

  @override
  String get wikipediaImporting => 'Importação da Wikipédia';

  @override
  String get noWikipediaResults => 'Nenhum resultado encontrado na Wikipédia';

  @override
  String get wikipediaImportMode => 'Modo de importação';

  @override
  String get wikipediaImportWholeArticle => 'Artigo completo';

  @override
  String get documents => 'Documentos';

  @override
  String get documentsHint => 'Abrir biblioteca de documentos';

  @override
  String get documentLibrary => 'Biblioteca de documentos';

  @override
  String get addToLibrary => 'Adicionar à biblioteca';

  @override
  String get documentImportSelectionMode =>
      'Quer selecionar um documento ou vários documentos?';

  @override
  String get documentImportSingle => 'Um documento';

  @override
  String get documentImportMultiple => 'Vários documentos';

  @override
  String get noDocuments => 'Não há documentos. Adicione um ficheiro.';

  @override
  String get noDocumentsInLibrary => 'Não há documentos na biblioteca.';

  @override
  String get documentAdded => 'Documento adicionado';

  @override
  String get documentsAdded => 'Documentos adicionados';

  @override
  String get importDocumentsFromITunes =>
      'Importar documentos do iTunes / Apple Devices';

  @override
  String sharedDocumentsImportComplete(int count) {
    return 'Documentos importados do iTunes / Apple Devices: $count';
  }

  @override
  String libraryLoadError(Object error) {
    return 'Erro ao carregar a biblioteca: $error';
  }

  @override
  String fileOpenError(Object error) {
    return 'Erro ao abrir o ficheiro: $error';
  }

  @override
  String get filePathUnavailable => 'Caminho do ficheiro indisponível.';

  @override
  String fileInaccessible(String name) {
    return 'Ficheiro inacessível: $name';
  }

  @override
  String documentAddError(Object error) {
    return 'Erro ao adicionar o documento: $error';
  }

  @override
  String documentRemoveError(Object error) {
    return 'Erro al eliminar: $error';
  }

  @override
  String get noExportableTextFound => 'Nenhum texto exportável encontrado.';

  @override
  String get modifiedDocumentNoExportableText =>
      'O documento modificado não contém texto exportável.';

  @override
  String get documentRemoved => 'Documento eliminado';

  @override
  String get folderRemoved => 'Pasta eliminada';

  @override
  String get removeFolder => 'Eliminar pasta';

  @override
  String get removeDocument => 'Eliminar documento';

  @override
  String get writeNewDocument => 'Escribir nuevo documento';

  @override
  String get addDocumentToLibraryHint =>
      'Adicionar documento à biblioteca. Procura os ficheiros do dispositivo e adiciona-os.';

  @override
  String get documentTypeLabel => 'Documento';

  @override
  String get documentPosition => 'Posição do documento';

  @override
  String get folderTypeLabel => 'Pasta';

  @override
  String documentAddedOn(String date) {
    return 'adicionado em $date';
  }

  @override
  String documentTypeDescription(String extension) {
    return 'tipo $extension';
  }

  @override
  String get openFolderHint => 'Toque duas vezes para abrir a pasta';

  @override
  String get openDocumentHint =>
      'Toque duas vezes para abrir e ler o documento';

  @override
  String removeItem(String name) {
    return 'Eliminar $name';
  }

  @override
  String get removePodcast => 'Eliminar podcast';

  @override
  String get podcastRemoved => 'Podcast eliminado';

  @override
  String get documentPickerError => 'Erro ao abrir o ficheiro';

  @override
  String get readDocument => 'Leer documento';

  @override
  String get documentReaderTitle => 'Lector de documentos';

  @override
  String get documentReaderEditHint =>
      'Toque num parágrafo para editá-lo. Deslize para cima ou para baixo para adicionar um marcador.';

  @override
  String get documentBookmarkHintSet =>
      'Deslize para cima ou para baixo para definir um marcador.';

  @override
  String get documentEditParagraphActionHint =>
      'Toca dos veces para editar este párrafo. ';

  @override
  String get documentBookmarkHintReplace =>
      'Deslize para cima ou para baixo para eliminar o marcador existente ou substituí-lo por este parágrafo.';

  @override
  String get documentSetBookmarkAction => 'Adicionar nuevo marcador';

  @override
  String get documentRemoveBookmarkAction => 'Eliminar marcador';

  @override
  String get documentReplaceBookmarkAction =>
      'Eliminar e adicionar um novo marcador';

  @override
  String get searchInDocument => 'Pesquisar no documento';

  @override
  String get documentSearchFieldLabel => 'Texto de pesquisa';

  @override
  String get documentSearchFieldHint => 'Palabra o frase para buscar';

  @override
  String get documentSearchEmptyQuery =>
      'Introduza o texto que quer pesquisar.';

  @override
  String get documentSearchResultsTitle =>
      'Resultados da pesquisa no documento';

  @override
  String noDocumentSearchResults(String query) {
    return 'Não foram encontrados resultados para $query.';
  }

  @override
  String documentSearchResultParagraph(int number) {
    return 'Parágrafo $number';
  }

  @override
  String get edit => 'Editar';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get settingsReadingEngine => 'Motor de leitura';

  @override
  String get settingsEdgeTtsQuality => 'Edge TTS (alta qualidade online)';

  @override
  String get settingsSystemVoices => 'Vozes do sistema (VoiceOver / Google)';

  @override
  String get settingsNoSystemVoices => 'Não há vozes do sistema disponíveis.';

  @override
  String get settingsDefaultVoiceHint => 'Voz predefinida';

  @override
  String get settingsDefaultVoice => 'Predeterminada';

  @override
  String get settingsVoiceSpeed => 'Velocidad: ';

  @override
  String get settingsVoicePitch => 'Tono: ';

  @override
  String get settingsVoiceSpeedLabel => 'Velocidad de leitura';

  @override
  String get settingsVoicePitchLabel => 'Tono';

  @override
  String get settingsTestVoice => 'Testar voz';

  @override
  String get settingsTestingVoice => 'A testar...';

  @override
  String get settingsVoiceTestText =>
      'Olá, este é um teste de leitura do Sonarpad.';

  @override
  String settingsVoiceTestError(Object error) {
    return 'Erro no teste da voz: $error';
  }

  @override
  String settingsVoiceSaveError(Object error) {
    return 'Erro ao guardar a voz TTS: $error';
  }

  @override
  String get settingsUnsavedTitle => 'Alterações não guardadas';

  @override
  String get settingsUnsavedMessage =>
      'Tem alterações não guardadas. Quer guardá-las antes de sair?';

  @override
  String get settingsExitWithoutSaving => 'Sair sem guardar';

  @override
  String get settingsSystemLanguage => 'Idioma do sistema';

  @override
  String get settingsSystemVoice => 'Voz do sistema';

  @override
  String get settingsAutoBookmark => 'Ativar marcador automático em multimédia';

  @override
  String get settingsAutoBookmarkHint =>
      'O áudio ou vídeo continuará a partir do ponto onde ficou.';

  @override
  String get settingsSeekStep => 'Passo de avanço/recuo';

  @override
  String get aiChatIntro =>
      'Sou a inteligência artificial do Sonarpad. Como posso ajudar?';

  @override
  String get meteoTitle => 'Meteorologia';

  @override
  String get weatherCity => 'Cidade';

  @override
  String get weatherCityHint => 'Exemplo: Roma';

  @override
  String get weatherCityNotFound => 'Cidade não encontrada';

  @override
  String get weatherSearchError => 'Erro durante a pesquisa';

  @override
  String get weatherToday => 'Hoje';

  @override
  String get weatherCurrentSituation => 'Situación actual';

  @override
  String get weatherTomorrow => 'Amanhã';

  @override
  String get weatherChooseDay => 'Escolher dia';

  @override
  String get weatherCurrentTemperature => 'Temperatura actual';

  @override
  String get weatherMaxTemperature => 'Temperatura máxima';

  @override
  String get weatherMinTemperature => 'Temperatura mínima';

  @override
  String get weatherPrecipitation => 'Precipitaciones';

  @override
  String get weatherPrecipitationProbability => 'Probabilidad de precipitación';

  @override
  String get weatherWind => 'Viento';

  @override
  String get weatherRelativeHumidity => 'Humedad relativa';

  @override
  String get settingsSecretCode => 'Código secreto Sonarpad';

  @override
  String get settingsRequestCode => 'Solicitar código';

  @override
  String get settingsPasteCode => 'Colar código';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsSend => 'Enviar';

  @override
  String get settingsFillFieldsCode => 'Preencha todos os campos.';

  @override
  String get settingsName => 'Nome';

  @override
  String get settingsSurname => 'Apelido';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsOperatingSystem => 'Sistema operativo';

  @override
  String settingsCodeRequestBody(
      String name, String surname, String email, String os) {
    return 'Nome: $name; Apelido: $surname; E-mail: $email; Sistema operativo: $os';
  }

  @override
  String get settingsNameOptional => 'Nome (opcional)';

  @override
  String get settingsMessageOptional => 'Mensagem (opcional)';

  @override
  String get settingsVerifyCodeAndSave => 'A verificar e guardar...';

  @override
  String get settingsViewSysLog => 'Ver registo do sistema';

  @override
  String settingsMailOpenError(Object error) {
    return 'Erro ao abrir o e-mail: $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get invia => 'Enviar';

  @override
  String get saveArticle => 'Guardar artigo';

  @override
  String get shareArticle => 'Partilhar artigo';

  @override
  String get articleSavedSuccess => 'Artigo guardado em Documentos';

  @override
  String get annulla => 'Cancelar';

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice =>
      'Preencha todos os campos para solicitar o código.';

  @override
  String get selectFolder => 'Selecionar pasta';

  @override
  String get exportDocument => 'Exportar documento';

  @override
  String get exportFormatPrompt => 'Em que formato quer exportar o documento?';

  @override
  String get textFormat => 'Texto (.txt)';

  @override
  String get pdfFormat => 'PDF (.pdf)';

  @override
  String get exportError => 'Erro de exportação';

  @override
  String get newFolder => 'Nova pasta';

  @override
  String get folderNameHint => 'Nome da pasta';

  @override
  String get create => 'Crear';

  @override
  String get createNewFolder => 'Crear nueva pasta';

  @override
  String get importExternalSources => 'Importar de fontes externas';

  @override
  String get importExternalSourcesTitle => 'Fuentes externas';

  @override
  String get importFromDropbox => 'Importar documentos do Dropbox';

  @override
  String get importFromProjectGutenberg => 'Importar do Project Gutenberg';

  @override
  String get projectGutenbergImportUnavailable =>
      'A importação do Project Gutenberg ainda não está disponível.';

  @override
  String get importFromInternetArchive => 'Importar do Internet Archive';

  @override
  String get internetArchiveTitle => 'Internet Archive';

  @override
  String get internetArchiveSearchLabel => 'Pesquisar áudio';

  @override
  String get internetArchiveSourceLabel => 'Fonte';

  @override
  String get internetArchiveOldTimeRadio => 'Rádio antigua';

  @override
  String get internetArchiveSpeeches => 'Discursos históricos';

  @override
  String get internetArchiveLiveMusic => 'Live Music Archive';

  @override
  String get internetArchiveNoItemsFound => 'Nenhum áudio encontrado.';

  @override
  String get saveAudioInDocuments => 'Guardar áudio em Documentos';

  @override
  String get audioSavedInDocuments => 'Áudio guardado em Documentos.';

  @override
  String get noAudioTracksAvailable => 'No hay pistas de áudio disponibles.';

  @override
  String get importFromLibriVox => 'Importar do LibriVox';

  @override
  String get gutenbergSearchLabel => 'Pesquisar libro o autor';

  @override
  String get sourceLanguageLabel => 'Idioma';

  @override
  String get noGutenbergBooksFound => 'Nenhum livro encontrado.';

  @override
  String get loadMore => 'Carregar mais';

  @override
  String sourceLanguageValue(String language) {
    return 'Idioma: $language';
  }

  @override
  String get gutenbergImportAndRead => 'Importar y leer';

  @override
  String get gutenbergImporting => 'Importando...';

  @override
  String get librivoxSearchLabel => 'Pesquisar audiolibro';

  @override
  String get noLibrivoxAudiobooksFound => 'Nenhum audiolivro encontrado.';

  @override
  String get librivoxAudiobookSaved => 'Audiolivro guardado em Documentos.';

  @override
  String get librivoxSaveAudiobook => 'Guardar audiolivro em Documentos';

  @override
  String get librivoxSaving => 'A guardar...';

  @override
  String get librivoxNoAudioTracks => 'No hay pistas de áudio disponibles.';

  @override
  String get librivoxNotTextExportable =>
      'Os audiolivros do LibriVox não podem ser exportados como texto.';

  @override
  String sourceDurationValue(String duration) {
    return 'Duração: $duration';
  }

  @override
  String get importFromPoetryDb => 'Importar do PoetryDB';

  @override
  String get poetryDbSearchLabel => 'Pesquisar poema';

  @override
  String get poetryDbSearchBy => 'Pesquisar por';

  @override
  String get poetryDbSearchByTitle => 'Título';

  @override
  String get poetryDbSearchByAuthor => 'Autor';

  @override
  String get poetryDbNoPoemsFound => 'Nenhum poema encontrado.';

  @override
  String poetryDbLineCount(int count) {
    return '$count versos';
  }

  @override
  String get moveDocument => 'Mover documento';

  @override
  String get documentMoved => 'Movido correctamente';

  @override
  String get outOfFolder => 'Fora da pasta';

  @override
  String get moveToAnotherFolder => 'Mover a otra pasta...';

  @override
  String get ttsError => 'Erro de síntesis de voz';

  @override
  String get editParagraph => 'Editar parágrafo';

  @override
  String get editParagraphTextField => 'Campo de texto para editar o parágrafo';

  @override
  String get editParagraphHint => 'Editar o texto do parágrafo';

  @override
  String get applyAndSave => 'Aplicar e guardar';

  @override
  String get textEditedAndSaved =>
      'Texto editado e guardado no documento atual.';

  @override
  String get saveError => 'Erro ao guardar';

  @override
  String get docSavedInLibrary => 'Documento guardado na biblioteca';

  @override
  String get saveInLibrary => 'Guardar na biblioteca';

  @override
  String get documentTextLabel => 'Texto do documento';

  @override
  String get modifiedInSonarpad => 'Modificado no Sonarpad';

  @override
  String get noTextAvailableForDocument =>
      'Não há texto disponível para este documento.';

  @override
  String bookmarkSet(int index) {
    return 'Marcador definido no parágrafo $index.';
  }

  @override
  String get bookmarkRemoved => 'Marcador eliminado.';

  @override
  String get docEmpty => 'O documento está vazio';

  @override
  String get docSavedSuccessfully => 'Documento guardado com sucesso!';

  @override
  String get writeDocument => 'Escrever documento';

  @override
  String get documentTitleOptional => 'Título (opcional)';

  @override
  String get documentTitleHint => 'Exemplo: Notas de compra';

  @override
  String get documentTextField => 'Texto do documento';

  @override
  String get documentTextHint => 'Comece a escrever aqui...';

  @override
  String get newDocumentDefaultName => 'Nuevo_Documento';

  @override
  String get saving => 'A guardar...';

  @override
  String get saveDocument => 'Guardar documento';

  @override
  String get addRssSource => 'Adicionar fonte RSS';

  @override
  String get add => 'Adicionar';

  @override
  String get errorPrefix => 'Erro';

  @override
  String versionBuild(String version, String buildNumber) {
    return 'Versão $version (Build $buildNumber)';
  }

  @override
  String get whatIsNew => 'Novidades';

  @override
  String whatIsNewInVersion(String version) {
    return 'Novidades da versão $version';
  }

  @override
  String changelogLoadError(Object error) {
    return 'Erro ao carregar as novidades: $error';
  }

  @override
  String get visitSonarpadSite => 'Visitar o site do Sonarpad';

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return 'Visitar o site do Sonarpad: $url';
  }

  @override
  String get nowPlaying => 'A reproduzir';

  @override
  String get fileImported => 'Ficheiro importado';

  @override
  String importZipError(Object error) {
    return 'Erro al importar ZIP: $error';
  }

  @override
  String get dropboxLoginPrompt =>
      'Inicie sessão no Dropbox para importar os seus documentos.';

  @override
  String get loginToDropbox => 'Iniciar sessão no Dropbox';

  @override
  String get logoutFromDropbox => 'Terminar sessão';

  @override
  String get dropboxLoginFailed => 'Início de sessão falhado ou cancelado';

  @override
  String dropboxLoadFolderError(Object error) {
    return 'Erro ao carregar a pasta: $error';
  }

  @override
  String dropboxImportError(Object error) {
    return 'Erro de importação: $error';
  }

  @override
  String get retry => 'Tentar novamente';

  @override
  String get goBack => '.. Voltar';

  @override
  String get noSupportedFilesInFolder =>
      'Não há ficheiros compatíveis nesta pasta.';

  @override
  String get articleNotFound => 'Artigo não encontrado.';

  @override
  String get errorOpening => 'Erro ao abrir';

  @override
  String get recentArticles => 'Artigos recientes';

  @override
  String get clearHistory => 'Limpar histórico';

  @override
  String get confirmClearHistory =>
      'Quer mesmo limpar todas as pesquisas recentes?';

  @override
  String get clear => 'Limpar';

  @override
  String get noRecentSearches => 'Não há pesquisas recentes.';

  @override
  String get logCopiedToClipboard => 'Registro copiado al portapapeles';

  @override
  String get systemLog => 'Registo do sistema';

  @override
  String get clearSystemLog => 'Vaciar registro';

  @override
  String get copySystemLog => 'Copiar registo';

  @override
  String get donateWithPaypal => 'Doar com PayPal';

  @override
  String get bankTransferTitle => 'Transferência bancária';

  @override
  String get enableVideo => 'Ativar vídeo';

  @override
  String get calendar => 'Calendário';

  @override
  String get calendarHint =>
      'Abrir o calendário com santos, feriados e lembretes';

  @override
  String get saintOfTheDay => 'Santo do dia';

  @override
  String get quoteOfTheDay => 'Citação do dia';

  @override
  String get reminders => 'Lembretes';

  @override
  String get addReminder => 'Adicionar lembrete';

  @override
  String get removeReminder => 'Remover lembrete';

  @override
  String get noReminders => 'Sem lembretes';

  @override
  String get writeReminder => 'Escreva o seu lembrete aqui...';

  @override
  String get saveReminder => 'Guardar';

  @override
  String get cancelReminder => 'Cancelar';

  @override
  String get backToToday => 'Voltar a hoje';

  @override
  String get calendarToday => 'Hoje';

  @override
  String get calendarTomorrow => 'Amanhã';

  @override
  String get calendarYesterday => 'Ontem';

  @override
  String get share => 'Partilhar';

  @override
  String get listenToAll => 'Ouvir tudo';

  @override
  String reminderSaved(int count) {
    return '$count lembretes';
  }

  @override
  String get audiodescriptionTitle => 'Audiodescrições';

  @override
  String get audiodescriptionRecent => 'Recentes';

  @override
  String get audiodescriptionAll => 'Todas as audiodescrições';

  @override
  String get audiodescriptionFilm => 'Filmes';

  @override
  String get audiodescriptionSearch => 'Pesquisar...';

  @override
  String get audiodescriptionLoading => 'A carregar...';

  @override
  String get audiodescriptionError => 'Erro ao carregar o catálogo';

  @override
  String get audiodescriptionEmpty => 'Nenhum item encontrado';

  @override
  String get radio => 'Rádio';

  @override
  String get radioHint =>
      'Busca estações de rádio, escucha transmisiones y gestiona favoritos';

  @override
  String get radioTitle => 'Estações de rádio de todo o mundo';

  @override
  String get radioFavoritesButton => 'Emisoras favoritas';

  @override
  String get radioNoFavorites => 'No hay emisoras favoritas.';

  @override
  String get radioSearchText => 'Pesquisar emisoras';

  @override
  String get radioSearchHint => 'Nome da estação ou cidade...';

  @override
  String get radioLanguage => 'Idioma';

  @override
  String get radioBrowseBy => 'Explorar por';

  @override
  String get radioBrowseByLanguage => 'Explorar por idioma';

  @override
  String get radioBrowseByCountry => 'Explorar por país';

  @override
  String get radioCountry => 'País';

  @override
  String get radioGenre => 'Género';

  @override
  String get radioSearch => 'Pesquisar';

  @override
  String get radioSearching => 'A carregar radios...';

  @override
  String get radioSearchResults => 'Resultados de rádio';

  @override
  String get radioNoResults => 'Nenhuma rádio encontrada.';

  @override
  String radioResultsFound(int count) {
    return '$count estações encontradas';
  }

  @override
  String radioSearchError(Object error) {
    return 'Erro na pesquisa de rádio: $error';
  }

  @override
  String radioNowPlaying(String name) {
    return 'A reproduzir $name';
  }

  @override
  String radioPlayError(Object error) {
    return 'Erro na transmissão de rádio: $error';
  }

  @override
  String get radioAddFavorite => 'Adicionar a favoritos';

  @override
  String get radioRemoveFavorite => 'Remover dos favoritos';

  @override
  String radioFavoriteAdded(String name) {
    return '$name adicionada aos favoritos.';
  }

  @override
  String radioFavoriteRemoved(String name) {
    return '$name removida dos favoritos.';
  }

  @override
  String get radioAddCommunity => 'Adicionar rádio à comunidade Sonarpad';

  @override
  String get radioAddName => 'Nome da rádio';

  @override
  String get radioAddUrl => 'Endereço da transmissão';

  @override
  String get radioAddSubmit => 'Verificar e adicionar';

  @override
  String get radioAddMissingFields =>
      'Introduza o nome da rádio e o endereço da transmissão.';

  @override
  String get radioCommunityAdded =>
      'Rádio adicionada com sucesso à comunidade Sonarpad.';

  @override
  String radioCommunityAddError(Object error) {
    return 'Erro ao adicionar a rádio: $error';
  }

  @override
  String get radioPlay => 'Reproduzir';

  @override
  String get startRecording => 'Iniciar gravação';

  @override
  String get stopRecording => 'Parar gravação';

  @override
  String get recordings => 'Gravações';

  @override
  String get noRecordings => 'Nenhuma gravação.';

  @override
  String get recordingStarted => 'Gravação iniciada.';

  @override
  String recordingSaved(Object path) {
    return 'Gravação guardada: $path';
  }

  @override
  String recordingError(Object error) {
    return 'Erro de gravação: $error';
  }

  @override
  String get routeTitle => 'Percursos';

  @override
  String get routeFrom => 'De';

  @override
  String get routeTo => 'A';

  @override
  String get routeCountry => 'País';

  @override
  String get routeCountryItaly => 'Itália';

  @override
  String get routeCountryFrance => 'França';

  @override
  String get routeCountrySpain => 'Espanha';

  @override
  String get routeVehicle => 'Medio de transporte';

  @override
  String get routeType => 'Tipo';

  @override
  String get routeIncludeMunicipalities => 'Incluir os municípios atravessados';

  @override
  String get routeWalking => 'Caminando';

  @override
  String get routeCycling => 'En bicicleta';

  @override
  String get routeDriving => 'En coche';

  @override
  String get routeWheelchair => 'En silla de ruedas';

  @override
  String get routeFastest => 'Mais rápido';

  @override
  String get routeShortest => 'Mais curto';

  @override
  String get routeCalculate => 'Calcular percurso';

  @override
  String get routeCalculating => 'A calcular...';

  @override
  String get routeChooseFrom => 'Escolher ponto de partida';

  @override
  String get routeChooseTo => 'Escolher destino';

  @override
  String get routeCancel => 'Cancelar';

  @override
  String get routeErrorMissingFields =>
      'Introduza o ponto de partida e o destino';

  @override
  String get routeErrorFromNotFound =>
      'Nenhum resultado encontrado para o endereço de partida';

  @override
  String get routeErrorToNotFound =>
      'Nenhum resultado encontrado para o endereço de destino';

  @override
  String get routeResultsTitle => 'Percursos disponibles';

  @override
  String get routeDistance => 'Distância';

  @override
  String get routeDuration => 'Duração';

  @override
  String get routeNavigation => 'Detalhes de navegação';

  @override
  String get routeStartMunicipality => 'Municipio de salida';

  @override
  String get routeEnterMunicipality => 'Entra no município de';

  @override
  String routeError(Object error) {
    return 'Erro: $error';
  }

  @override
  String get radioLanguageIt => 'Itáliano';

  @override
  String get radioLanguageEn => 'Inglês';

  @override
  String get radioLanguageDe => 'Alemão';

  @override
  String get radioLanguageCountryCh => 'Suíça';

  @override
  String get radioLanguageEs => 'Espanhol';

  @override
  String get radioLanguagePt => 'Português';

  @override
  String get radioLanguageSv => 'Sueco';

  @override
  String get radioLanguageVi => 'Vietnamita';

  @override
  String get radioLanguageCs => 'Checo';

  @override
  String get radioLanguagePl => 'Polaco';

  @override
  String get radioLanguageFr => 'Francês';

  @override
  String get radioLanguageSr => 'Sérvio';

  @override
  String get radioLanguageUk => 'Ucraniano';

  @override
  String get radioLanguageHi => 'Hindi';

  @override
  String get radioLanguageLt => 'Lituano';

  @override
  String get radioLanguageRu => 'Russo';

  @override
  String get radioLanguageZh => 'Chinês';

  @override
  String get radioCountryOptionIt => 'Itália';

  @override
  String get radioCountryOptionUs => 'Estados Unidos';

  @override
  String get radioCountryOptionGb => 'Reino Unido';

  @override
  String get radioCountryOptionFr => 'França';

  @override
  String get radioCountryOptionEs => 'Espanha';

  @override
  String get radioCountryOptionDe => 'Alemanha';

  @override
  String get radioCountryOptionCh => 'Suíça';

  @override
  String get radioCountryOptionAt => 'Áustria';

  @override
  String get radioCountryOptionBe => 'Bélgica';

  @override
  String get radioCountryOptionNl => 'Países Baixos';

  @override
  String get radioCountryOptionPt => 'Portugal';

  @override
  String get radioCountryOptionBr => 'Brasil';

  @override
  String get radioCountryOptionAr => 'Argentina';

  @override
  String get radioCountryOptionMx => 'México';

  @override
  String get radioCountryOptionCa => 'Canadá';

  @override
  String get radioCountryOptionAu => 'Austrália';

  @override
  String get radioCountryOptionIe => 'Irlanda';

  @override
  String get radioCountryOptionSe => 'Suécia';

  @override
  String get radioCountryOptionPl => 'Polónia';

  @override
  String get radioCountryOptionJp => 'Japão';

  @override
  String get radioGenreOptionAll => 'Todos os géneros';

  @override
  String get radioGenreOptionNews => 'Notícias';

  @override
  String get radioGenreOptionMusic => 'Música';

  @override
  String get radioGenreOptionSport => 'Desporto';

  @override
  String get radioGenreOptionTalk => 'Charlas y análisis';

  @override
  String get radioGenreOptionPop => 'Pop';

  @override
  String get radioGenreOptionRock => 'Rock';

  @override
  String get radioGenreOptionClassical => 'Clássica';

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
  String get radioGenreOptionElectronic => 'Eletrónica';

  @override
  String get radioGenreOptionLatin => 'Latina';

  @override
  String get radioGenreOptionReggae => 'Reggae';

  @override
  String get radioGenreOptionMetal => 'Metal';

  @override
  String get radioGenreOptionFolk => 'Folk';

  @override
  String get radioGenreOptionReligion => 'Religião';

  @override
  String get radioGenreOptionLocal => 'Local';

  @override
  String get radioGenreOptionCulture => 'Cultura';

  @override
  String get radioGenreOptionOldies => 'Años 70 / 80 / 90';

  @override
  String get radioGenreOptionKids => 'Infantil';

  @override
  String get radioGenreOptionAmbient => 'Ambient';

  @override
  String get radioCommunityLanguageItalian => 'Itáliano';

  @override
  String get radioCommunityLanguageEnglish => 'Inglês';

  @override
  String get radioCommunityLanguageSpanish => 'Espanhol';

  @override
  String get radioCommunityLanguageFrench => 'Francês';

  @override
  String get radioCommunityLanguageGerman => 'Alemão';

  @override
  String get radioCommunityLanguagePortuguese => 'Português';

  @override
  String get radioCommunityLanguageSwedish => 'Sueco';

  @override
  String get radioCommunityLanguageVietnamese => 'Vietnamita';

  @override
  String get radioCommunityLanguageCzech => 'Checo';

  @override
  String get radioCommunityLanguagePolish => 'Polaco';

  @override
  String get radioCommunityLanguageSerbian => 'Sérvio';

  @override
  String get radioCommunityLanguageUkrainian => 'Ucraniano';

  @override
  String get radioCommunityLanguageLithuanian => 'Lituano';

  @override
  String get radioCommunityLanguageRussian => 'Russo';

  @override
  String get radioCommunityLanguageChinese => 'Chinês';

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
  String get cinemaTitle => 'Filmes no cinema';

  @override
  String get cinemaNoMovies => 'Nenhum filme encontrado neste momento.';

  @override
  String get cinemaError => 'Erro ao carregar filmes.';

  @override
  String cinemaReleased(String date) {
    return 'Estreno: $date';
  }

  @override
  String get cinemaOverviewLabel => 'Trama:';

  @override
  String get cinemaUpcomingReleases => 'Próximas estreias';

  @override
  String cinemaWillRelease(String date) {
    return 'Estreará em: $date';
  }

  @override
  String get cinemaOpenTrailer => 'Abrir trailer';

  @override
  String get concertsTitle => 'Concertos e eventos';

  @override
  String get concertsSearchHint => 'Introduza uma cidade (ex.: Lisboa, Porto)';

  @override
  String get concertsSearchLabel => 'Pesquisar concertos por cidade';

  @override
  String get concertsSearchTooltip => 'Pesquisar';

  @override
  String get concertsInitialText =>
      'Escreva acima o nome da sua cidade para ver os concertos musicais programados.';

  @override
  String get concertsEmpty => 'Nenhum concerto encontrado nesta cidade.';

  @override
  String get concertsVenue => 'Local do concerto:';

  @override
  String get concertsBuyTickets => 'Comprar ou ver detalhes no Ticketmaster';

  @override
  String get podcastPlayedEpisodes => 'Não reproduzido';

  @override
  String get podcastUnplayed => 'Não reproduzido';
}
