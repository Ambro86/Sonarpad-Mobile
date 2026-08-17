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
  String get settingsWeatherTemperatureUnit =>
      'Unidade de temperatura da meteorologia';

  @override
  String get weatherTemperatureCelsius => 'Celsius (°C)';

  @override
  String get weatherTemperatureFahrenheit => 'Fahrenheit (°F)';

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
  String get sonarTubeTitle => 'SonarTube';

  @override
  String get sonarTubeSearchLabel => 'Pesquisar vídeos, canais ou listas';

  @override
  String get sonarTubeSearchPrompt =>
      'Introduza uma pesquisa para encontrar vídeos, canais e listas.';

  @override
  String get sonarTubeNoResults => 'Nenhum vídeo encontrado.';

  @override
  String get sonarTubeLoadMore => 'Carregar mais resultados';

  @override
  String get sonarTubeChannel => 'Canal';

  @override
  String get sonarTubePlaylist => 'Lista de reprodução';

  @override
  String get sonarTubeLive => 'Em direto';

  @override
  String get sonarTubeResolving => 'A preparar o vídeo…';

  @override
  String get sonarTubeFavorites => 'Favoritos';

  @override
  String get sonarTubeNoFavorites => 'Nenhum canal ou lista favorito.';

  @override
  String get sonarTubeAddFavorite => 'Adicionar aos favoritos';

  @override
  String get sonarTubeRemoveFavorite => 'Remover dos favoritos';

  @override
  String sonarTubeFavoriteAdded(String name) {
    return '$name foi adicionado aos favoritos.';
  }

  @override
  String sonarTubeFavoriteRemoved(String name) {
    return '$name foi removido dos favoritos.';
  }

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
  String get convertMediaButton => 'Converter';

  @override
  String get convertMediaNoInput => 'Selecione um ficheiro para converter.';

  @override
  String get convertMediaNoOutput => 'Selecione uma pasta de gravação.';

  @override
  String get convertMediaOutputNotWritable =>
      'A pasta escolhida não está diretamente acessível. O ficheiro será guardado na pasta interna do Sonarpad; quando a conversão terminar, poderá partilhá-lo ou guardá-lo na app Ficheiros.';

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
      'O código Sonarpad está correto. Definições guardadas.';

  @override
  String get sonarpadCodeInvalidTitle => 'Código inválido';

  @override
  String get sonarpadCodeInvalidMessage =>
      'O código Sonarpad não é válido. Verifique se o copiou sem espaços adicionais.';

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
      'Pode doar através do PayPal usando este link:\nhttps://www.paypal.me/ambrogio86\nPor favor, se possível, adicione \"Sonarpad\" como nota de pagamento.';

  @override
  String get donationsBankDesc =>
      'Também pode fazer um donativo por transferência bancária para a conta em nome de Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nSe possível, use uma descrição clara, por exemplo “Sonarpad”.';

  @override
  String get donationsThanks =>
      'Quem apoiar o projeto será mencionado na aplicação e no repositório GitHub, salvo se preferir ficar anónimo ou usar um pseudónimo.\n\nObrigado a Jiri Holzinger e Paola Vagata pela contribuição.\nPela tradução checa, obrigado a Radek Žalud e Jiri Holzinger.\nPela tradução espanhola, obrigado a Arturo Fernandez Rivas.';

  @override
  String get news => 'Notícias';

  @override
  String get newsHint => 'Abrir notícias do Google News RSS';

  @override
  String get podcasts => 'Podcasts';

  @override
  String get podcastsHint =>
      'Subscreva podcasts, reproduza ou descarregue episódios';

  @override
  String get importFromWikipedia => 'Wikipedia';

  @override
  String get wikipediaHint =>
      'Pesquisar um artigo da Wikipédia e importar o texto';

  @override
  String get newsCategoryTop => 'Destaques';

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
  String get moveUp => 'Mover para cima';

  @override
  String get moveDown => 'Mover para baixo';

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
  String get importRssSourcesFromOpml => 'Importar fontes RSS de OPML';

  @override
  String get exportRssSourcesToOpml => 'Exportar fontes RSS para OPML';

  @override
  String rssImportComplete(int count) {
    return 'Fontes RSS importadas: $count';
  }

  @override
  String rssImportError(Object error) {
    return 'Erro ao importar RSS: $error';
  }

  @override
  String get rssExportComplete => 'Fontes RSS exportadas';

  @override
  String rssExportError(Object error) {
    return 'Erro ao exportar RSS: $error';
  }

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
  String get browsePodcastCountries => 'Explorar por país';

  @override
  String get podcastCountries => 'Países dos podcasts';

  @override
  String get podcastCategory => 'Categoria de podcast';

  @override
  String get browsePodcastCategories => 'Explorar categorias';

  @override
  String get selectedPodcastCategory => 'Categoria selecionada';

  @override
  String get selectedRecently => 'escolha recente';

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
  String get openPodcast => 'Abrir podcast';

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
  String get importAudioFromITunes => 'Importar ficheiros de áudio locais';

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
    return 'Erro ao importar podcasts: $error';
  }

  @override
  String get podcastInvalidOpmlFile =>
      'Ficheiro inválido. Selecione um ficheiro OPML ou XML.';

  @override
  String get podcastExportComplete => 'Podcasts exportados';

  @override
  String podcastExportError(Object error) {
    return 'Erro ao exportar podcasts: $error';
  }

  @override
  String get loadingEpisodes => 'A carregar episódios';

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
  String get rewind15s => 'Recuar 15s';

  @override
  String get forward15s => 'Avançar 15s';

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
    return 'Erro ao eliminar: $error';
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
  String get writeNewDocument => 'Escrever novo documento';

  @override
  String get addDocumentToLibraryHint =>
      'Adicionar documento à biblioteca. Procura os ficheiros do dispositivo e adiciona-os.';

  @override
  String get documentTypeLabel => 'Documento';

  @override
  String get documentPosition => 'Posição do documento';

  @override
  String get documentRemainingLessThanOneMinute => 'menos de 1 minuto restante';

  @override
  String documentRemainingMinutes(int minutes) {
    return 'cerca de $minutes minutos restantes';
  }

  @override
  String documentRemainingHours(int hours) {
    return 'cerca de $hours horas restantes';
  }

  @override
  String documentRemainingHoursMinutes(int hours, int minutes) {
    return 'cerca de $hours horas e $minutes minutos restantes';
  }

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
  String get readDocument => 'Ler documento';

  @override
  String get documentReaderTitle => 'Leitor de documentos';

  @override
  String get documentReaderEditHint =>
      'Toque num parágrafo para editá-lo. Deslize para cima ou para baixo para adicionar um marcador.';

  @override
  String get documentParagraphSelectionStartAction =>
      'Iniciar seleção de parágrafos';

  @override
  String get documentParagraphSelectionTapHint =>
      'O modo de seleção está ativo. Toque duas vezes para selecionar ou desmarcar este parágrafo.';

  @override
  String get documentParagraphSelectionStarted =>
      'O modo de seleção está ativo. Parágrafo selecionado. Toque duas vezes nos outros parágrafos para selecioná-los.';

  @override
  String documentParagraphSelectedAnnouncement(int count) {
    return 'Parágrafo selecionado. Total selecionado: $count.';
  }

  @override
  String documentParagraphDeselectedAnnouncement(int count) {
    return 'Parágrafo desmarcado. Total selecionado: $count.';
  }

  @override
  String documentParagraphSelectionCount(int count) {
    return 'Selecionados: $count';
  }

  @override
  String get documentDeleteSelectedParagraphs =>
      'Eliminar parágrafos selecionados';

  @override
  String documentDeleteSelectedParagraphsConfirmation(int count) {
    return 'Eliminar os parágrafos selecionados? Total: $count.';
  }

  @override
  String documentSelectedParagraphsDeleted(int count) {
    return 'Parágrafos eliminados: $count.';
  }

  @override
  String get documentExitParagraphSelection => 'Sair da seleção de parágrafos';

  @override
  String get documentParagraphSelectionExited => 'Modo de seleção desativado.';

  @override
  String get documentBookmarkHintSet =>
      'Deslize para cima ou para baixo para definir um marcador.';

  @override
  String get documentEditParagraphActionHint =>
      'Toque duas vezes para editar este parágrafo. ';

  @override
  String get documentBookmarkHintReplace =>
      'Deslize para cima ou para baixo para eliminar o marcador existente ou substituí-lo por este parágrafo.';

  @override
  String get documentSetBookmarkAction => 'Adicionar novo marcador';

  @override
  String get documentRemoveBookmarkAction => 'Eliminar marcador';

  @override
  String get documentReplaceBookmarkAction =>
      'Eliminar e adicionar um novo marcador';

  @override
  String get searchInDocument => 'Pesquisar no documento';

  @override
  String get documentIndex => 'Índice';

  @override
  String get documentSearchFieldLabel => 'Texto de pesquisa';

  @override
  String get documentSearchFieldHint => 'Palavra ou frase para pesquisar';

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
  String get settingsDefaultVoice => 'Predefinida';

  @override
  String get settingsVoiceSpeed => 'Velocidade: ';

  @override
  String get settingsVoicePitch => 'Tom: ';

  @override
  String get settingsVoiceSpeedLabel => 'Velocidade de leitura';

  @override
  String get settingsVoicePitchLabel => 'Tom';

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
  String get settingsDocumentSliderStep => 'Passo do controlo dos documentos';

  @override
  String get settingsDocumentSliderStepHint =>
      'Define quanto o controlo da posição do documento avança ou recua ao deslizar para cima ou para baixo.';

  @override
  String get settingsReadingSleepTimer =>
      'Temporizador de suspensão da leitura';

  @override
  String get settingsReadingSleepTimerOff => 'Desativado';

  @override
  String settingsReadingSleepTimerMinutes(int minutes) {
    return '$minutes minutos';
  }

  @override
  String get settingsReadingSleepTimerHint =>
      'Para automaticamente a leitura do documento atual após o tempo escolhido e guarda o ponto de paragem. A contagem recomeça sempre que inicia a leitura de um documento.';

  @override
  String get documentReadingSleepTimerStopped =>
      'Temporizador de suspensão: leitura parada e posição guardada.';

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
  String get weatherCurrentSituation => 'Situação atual';

  @override
  String get weatherTomorrow => 'Amanhã';

  @override
  String get weatherChooseDay => 'Escolher dia';

  @override
  String get weatherCurrentTemperature => 'Temperatura atual';

  @override
  String get weatherMaxTemperature => 'Temperatura máxima';

  @override
  String get weatherMinTemperature => 'Temperatura mínima';

  @override
  String get weatherPrecipitation => 'Precipitação';

  @override
  String get weatherPrecipitationProbability => 'Probabilidade de precipitação';

  @override
  String get weatherWind => 'Vento';

  @override
  String get weatherRelativeHumidity => 'Humidade relativa';

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
    String name,
    String surname,
    String email,
    String os,
  ) {
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
  String get yes => 'Sim';

  @override
  String get no => 'Não';

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
  String get docxFormat => 'DOCX (.docx)';

  @override
  String get epubFormat => 'EPUB (.epub)';

  @override
  String get exportError => 'Erro de exportação';

  @override
  String get newFolder => 'Nova pasta';

  @override
  String get folderNameHint => 'Nome da pasta';

  @override
  String get create => 'Criar';

  @override
  String get createNewFolder => 'Criar nova pasta';

  @override
  String get importExternalSources => 'Importar de fontes externas';

  @override
  String get importExternalSourcesTitle => 'Fontes externas';

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
  String get noAudioTracksAvailable => 'Não há faixas de áudio disponíveis.';

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
  String get gutenbergImportAndRead => 'Importar e ler';

  @override
  String get gutenbergImporting => 'A importar...';

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
  String get librivoxNoAudioTracks => 'Não há faixas de áudio disponíveis.';

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
  String get documentMoved => 'Movido com sucesso';

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
  String get newDocumentDefaultName => 'Novo_Documento';

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
    return 'Erro ao importar ZIP: $error';
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
  String get recentArticles => 'Artigos recentes';

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
  String get logCopiedToClipboard =>
      'Registo copiado para a área de transferência';

  @override
  String get logCleared => 'Log limpo';

  @override
  String get parafarmacoDetailReadyAnnouncement =>
      'Ficha do produto carregada. Deslize para a direita para escolher as secções.';

  @override
  String get systemLog => 'Registo do sistema';

  @override
  String get clearSystemLog => 'Limpar registo';

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
  String get shareCalendarDayOptions => 'Opções de partilha';

  @override
  String get shareCalendarDayOnly => 'Partilhar apenas o dia';

  @override
  String get shareCalendarDayWithReminder => 'Partilhar dia e lembrete';

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
      'Procura estações de rádio, escuta transmissões e gere favoritos';

  @override
  String get radioTitle => 'Estações de rádio de todo o mundo';

  @override
  String get radioFavoritesButton => 'Estações favoritas';

  @override
  String get radioNoFavorites => 'Não há estações favoritas.';

  @override
  String get radioSearchText => 'Pesquisar estações';

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
  String get radioActiveFilters => 'Filtros ativos';

  @override
  String get radioResetFilters => 'Repor filtros';

  @override
  String get radioFiltersReset => 'Filtros repostos.';

  @override
  String get radioCity => 'Cidade';

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
  String get tvSearchFieldLabel => 'Pesquisar canais de TV';

  @override
  String get tvSearchFieldHint => 'Nome do canal...';

  @override
  String get tvSearchButton => 'Pesquisar';

  @override
  String get tvSearchResults => 'Resultados de canais de TV';

  @override
  String get tvSearchEmptyQuery =>
      'Introduza o nome de um canal de TV para pesquisar.';

  @override
  String tvSearchNoResults(String query) {
    return 'Nenhum canal de TV encontrado para $query.';
  }

  @override
  String get tvOpenChannelHint => 'Toque para reproduzir o canal de TV';

  @override
  String tvNowOnAir(String title) {
    return 'No ar agora: $title';
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
  String get selectRecordings => 'Selecionar gravações';

  @override
  String deleteRecordingsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminar permanentemente $count gravações?',
      one: 'Eliminar permanentemente uma gravação?',
    );
    return '$_temp0';
  }

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
  String get routeCountryCzechRepublic => 'Chéquia';

  @override
  String get routeVehicle => 'Meio de transporte';

  @override
  String get routeType => 'Tipo';

  @override
  String get routeIncludeMunicipalities => 'Incluir os municípios atravessados';

  @override
  String get routeWalking => 'A pé';

  @override
  String get routeCycling => 'De bicicleta';

  @override
  String get routeDriving => 'De carro';

  @override
  String get routeWheelchair => 'Em cadeira de rodas';

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
  String get routeResultsTitle => 'Percursos disponíveis';

  @override
  String get routeDistance => 'Distância';

  @override
  String get routeDuration => 'Duração';

  @override
  String get routeNavigation => 'Detalhes de navegação';

  @override
  String get routeStartMunicipality => 'Município de partida';

  @override
  String get routeEnterMunicipality => 'Entra no município de';

  @override
  String routeError(Object error) {
    return 'Erro: $error';
  }

  @override
  String get radioLanguageIt => 'Italiano';

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
  String get radioGenreOptionTalk => 'Conversas e análises';

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
  String get radioGenreOptionOldies => 'Anos 70 / 80 / 90';

  @override
  String get radioGenreOptionKids => 'Infantil';

  @override
  String get radioGenreOptionAmbient => 'Ambient';

  @override
  String get radioCommunityLanguageItalian => 'Italiano';

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
    return 'Estreia: $date';
  }

  @override
  String get cinemaOverviewLabel => 'Sinopse:';

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
  String get podcastPlayedEpisodes => 'Episódios reproduzidos';

  @override
  String get podcastSelectDate => 'Selecionar data';

  @override
  String get podcastNoDatesAvailable =>
      'Nenhuma data disponível para estes episódios.';

  @override
  String get podcastChapters => 'Capítulos';

  @override
  String get podcastChaptersUnavailable =>
      'Não há capítulos disponíveis para este episódio.';

  @override
  String get podcastUnplayed => 'Episódios não reproduzidos';

  @override
  String get routeReadAction => 'Ler percurso';

  @override
  String get routeSaveAction => 'Guardar nos documentos';

  @override
  String get routeSaveSuccess => 'Percurso guardado nos documentos';

  @override
  String get deleteItem => 'Eliminar';

  @override
  String get audiobookMp3Format => 'Audiolivro MP3 (.mp3)';

  @override
  String get audiobookM4bFormat => 'Audiolivro M4B (.m4b)';

  @override
  String get exportCompleteTitle => 'Exportação concluída';

  @override
  String get exportCompleteMessage =>
      'O ficheiro foi criado corretamente. Quer guardá-lo no Sonarpad ou partilhá-lo?';

  @override
  String get saveInSonarpad => 'Guardar no Sonarpad';

  @override
  String get exportSavedInSonarpad =>
      'Ficheiro guardado nos Documentos do Sonarpad.';

  @override
  String get audiobookExportProgressTitle => 'Criação do audiolivro';

  @override
  String get audiobookExportPreparing => 'Preparando o audiolivro...';

  @override
  String get audiobookExportGeneratingAudio => 'Gerando áudio';

  @override
  String get audiobookExportConvertingAudio =>
      'Conversão final do arquivo de áudio...';

  @override
  String get audiobookExportFinalizing => 'A finalizar...';

  @override
  String get routeRecentRoutes => 'Rotas recentes';

  @override
  String get routeRecentRoutesEmpty => 'Nenhuma rota recente';

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) {
    return 'Detalhes de navegação de $from para $to - $date';
  }

  @override
  String get sortPodcastsAlphabetically => 'Ordenar podcasts alfabeticamente';

  @override
  String get sortRadioFavoritesAlphabetically =>
      'Ordenar favoritas alfabeticamente';

  @override
  String get podcastsSortedAlphabetically =>
      'Podcasts ordenados alfabeticamente.';

  @override
  String get radioFavoritesSortedAlphabetically =>
      'Rádios favoritas ordenadas alfabeticamente.';

  @override
  String get settingsIncludeFootnotesInText =>
      'Incluir notas de rodapé no texto';

  @override
  String get settingsIncludeFootnotesInTextHint =>
      'Nos EPUB compatíveis, mostra a nota logo após o parágrafo que a referencia.';

  @override
  String get documentFootnoteLabel => 'Nota de rodapé';

  @override
  String get settingsMultipleDocumentBookmarks =>
      'Permitir vários marcadores nos documentos';

  @override
  String get settingsMultipleDocumentBookmarksHint =>
      'Se estiver desativado, fica apenas um marcador por documento. Se estiver ativado, pode guardar vários marcadores no mesmo documento.';

  @override
  String get documentGoToBookmarkAction => 'Ir para o marcador';

  @override
  String get documentChooseBookmarkTitle => 'Escolher marcador';

  @override
  String get documentDeleteBookmarkAction => 'Eliminar marcador';

  @override
  String get documentKeepBookmarkTitle => 'Que marcador pretende manter?';

  @override
  String get documentKeepBookmarkMessage =>
      'Os marcadores múltiplos estão desativados. Escolha um marcador para manter: os outros serão eliminados.';

  @override
  String documentBookmarkChoiceLabel(int order, int paragraph) {
    return 'Marcador $order, parágrafo $paragraph';
  }

  @override
  String documentBookmarkChoiceLabelWithPreview(
    int order,
    int paragraph,
    String preview,
  ) {
    return 'Marcador $order, parágrafo $paragraph. $preview';
  }

  @override
  String get settingsVideoLandscapeFullscreen =>
      'Vídeo horizontal em ecrã inteiro';

  @override
  String get settingsVideoLandscapeFullscreenHint =>
      'Quando ativa o vídeo, este é mostrado em ecrã inteiro na orientação horizontal. As rádios só de áudio não mudam.';

  @override
  String get settingsPodcastCacheTitle => 'Cache de podcasts';

  @override
  String get settingsPodcastCacheHint =>
      'Limpa apenas ficheiros temporários dos podcasts. Subscrições, histórico e áudio importado ficam intactos.';

  @override
  String settingsPodcastCacheSize(String size) {
    return 'Espaço usado: $size';
  }

  @override
  String get clearPodcastCache => 'Limpar cache de podcasts';

  @override
  String get confirmClearPodcastCacheTitle => 'Limpar a cache de podcasts?';

  @override
  String get confirmClearPodcastCacheMessage =>
      'Os ficheiros temporários dos podcasts serão eliminados. As subscrições e o histórico dos episódios não serão removidos.';

  @override
  String podcastCacheCleared(String size) {
    return 'Cache de podcasts limpa: $size libertados.';
  }

  @override
  String get podcastCacheEmpty => 'A cache de podcasts já está vazia.';

  @override
  String get pharmacyFeatureTitle => 'Medicamentos, parafarmácia e suplementos';

  @override
  String get pharmacyProductsSectionTitle => 'Parafarmácia e suplementos';

  @override
  String get pharmacyProductsLoadingTitle =>
      'A procurar parafarmácia e suplementos...';

  @override
  String get pharmacyProductsErrorTitle =>
      'Erro ao procurar parafarmácia e suplementos';

  @override
  String get pharmacyProductsNoResultsTitle =>
      'Nenhum produto de parafarmácia ou suplemento encontrado';

  @override
  String get mediaCutterTitle => 'Cortar ficheiro multimédia';

  @override
  String get mediaCutterInstruction1 =>
      'Abre um ficheiro de áudio ou vídeo, reproduz e vai até ao ponto onde queres cortar.';

  @override
  String get mediaCutterInstruction2 =>
      'Coloque em pausa, prima Dividir, depois elimine as partes que não quer na secção Partes a guardar e prima Guardar.';

  @override
  String get mediaCutterOpenFile => 'Abrir ficheiro multimédia';

  @override
  String mediaCutterSelectedFile(String fileName) {
    return 'Ficheiro selecionado: $fileName';
  }

  @override
  String get mediaCutterPosition => 'Posição de corte';

  @override
  String get mediaCutterPositionHint =>
      'Avança ou recua um segundo de cada vez.';

  @override
  String get mediaCutterHideVideoPreview => 'Ocultar vídeo';

  @override
  String get mediaCutterVideoRotation => 'Rotação do vídeo';

  @override
  String get mediaCutterVideoRotationNone => 'Sem rotação';

  @override
  String get mediaCutterVideoRotationRight => 'Rodar para a direita';

  @override
  String get mediaCutterVideoRotationLeft => 'Rodar para a esquerda';

  @override
  String get mediaCutterVideoRotationUpsideDown => 'Rodar 180 graus';

  @override
  String get mediaCutterVideoPreview => 'Pré-visualização do vídeo';

  @override
  String get mediaCutterSplit => 'Dividir';

  @override
  String get mediaCutterPartsTitle => 'Partes a guardar';

  @override
  String get mediaCutterPartsHint =>
      'Toque numa parte para a ouvir. As partes eliminadas desaparecem da lista, são ignoradas durante a reprodução e não serão guardadas. Os efeitos são aplicados a toda a parte apenas quando o ficheiro multimédia é guardado.';

  @override
  String mediaCutterPartLabel(int index) {
    return 'Parte $index';
  }

  @override
  String mediaCutterPartRange(String start, String end) {
    return 'De $start a $end';
  }

  @override
  String get mediaCutterSave => 'Guardar';

  @override
  String get mediaCutterReady => 'Pronto.';

  @override
  String get mediaCutterUnsavedExitTitle => 'Ficheiro não guardado';

  @override
  String get mediaCutterUnsavedExitMessage =>
      'O ficheiro não foi guardado. Tem a certeza de que quer sair?';

  @override
  String get mediaCutterNoFile => 'Abre primeiro um ficheiro multimédia.';

  @override
  String get mediaCutterInvalidSplitPoint =>
      'Escolhe um ponto dentro do ficheiro, não o início nem o fim.';

  @override
  String get mediaCutterSplitAlreadyExists =>
      'Já existe uma divisão neste ponto.';

  @override
  String mediaCutterSplitAdded(String position) {
    return 'Divisão adicionada em $position.';
  }

  @override
  String get mediaCutterSaving => 'A guardar o ficheiro...';

  @override
  String mediaCutterSaved(String fileName) {
    return 'Ficheiro guardado: $fileName';
  }

  @override
  String mediaCutterLoadFailed(Object error) {
    return 'Não foi possível abrir o ficheiro: $error';
  }

  @override
  String mediaCutterSaveFailed(Object error) {
    return 'Falha ao guardar: $error';
  }

  @override
  String get mediaCutterNoPartsToSave =>
      'Mantenha pelo menos uma parte antes de guardar.';

  @override
  String get mediaCutterRestoreDeletedPart => 'Restaurar parte eliminada';

  @override
  String get mediaCutterNoDeletedParts =>
      'Não há partes eliminadas para restaurar.';

  @override
  String get mediaCutterPartDeleteAction => 'Eliminar';

  @override
  String get mediaCutterPartTapHint =>
      'Toque duas vezes para ouvir esta parte. Use as ações Modificar parte, Eliminar ou Ajustar efeitos.';

  @override
  String mediaCutterPartDeleted(String start, String end) {
    return 'Parte eliminada de $start a $end.';
  }

  @override
  String mediaCutterPartRestored(String start, String end) {
    return 'Parte restaurada de $start a $end.';
  }

  @override
  String get mediaCutterPartEffectsAction => 'Ajustar efeitos';

  @override
  String get mediaCutterPartEditAction => 'Modificar parte';

  @override
  String get mediaCutterPartEditDescription =>
      'Desloque o início ou o fim da parte em 1 segundo e depois ouça a parte modificada.';

  @override
  String mediaCutterPartAdjusted(String start, String end) {
    return 'Parte modificada de $start a $end.';
  }

  @override
  String get mediaCutterPartEffectsTitle => 'Efeitos da parte';

  @override
  String get mediaCutterPartEffectsDescription =>
      'Ajuste o volume e o efeito apenas para esta parte.';

  @override
  String mediaCutterPartVolumeValue(int percent) {
    return 'Volume da parte: $percent%';
  }

  @override
  String get mediaCutterPartEffect => 'Efeito de áudio';

  @override
  String get mediaCutterPartEffectNone => 'Sem efeito';

  @override
  String get mediaCutterPartEffectEcho => 'Eco leve';

  @override
  String get mediaCutterPartEffectEchoRoom => 'Eco sala';

  @override
  String get mediaCutterPartEffectEchoChamber => 'Eco câmara';

  @override
  String get mediaCutterPartEffectEchoCathedral => 'Eco catedral';

  @override
  String get mediaCutterPartEffectLargeRoom => 'Sala grande';

  @override
  String get mediaCutterPartEffectSmallRoom => 'Sala pequena';

  @override
  String get mediaCutterPartEffectBathroom => 'Casa de banho';

  @override
  String get mediaCutterPartEffectTunnel => 'Túnel';

  @override
  String get mediaCutterPartEffectRepeatEcho => 'Eco repetido';

  @override
  String get mediaCutterPartEffectCorridor => 'Corredor';

  @override
  String get mediaCutterPartEffectDelay => 'Delay';

  @override
  String get mediaCutterPartEffectReverb => 'Reverberação leve';

  @override
  String get mediaCutterPartEffectChorus => 'Chorus';

  @override
  String get mediaCutterPartEffectPitchLow => 'Tom baixo';

  @override
  String get mediaCutterPartEffectPitchVeryLow => 'Tom muito baixo';

  @override
  String get mediaCutterPartEffectPitchHigh => 'Tom alto';

  @override
  String get mediaCutterPartEffectPitchVeryHigh => 'Tom muito alto';

  @override
  String get mediaCutterPartEffectRobot => 'Voz robô';

  @override
  String get mediaCutterPartEffectSuperRobot => 'Super robô';

  @override
  String get mediaCutterPartEffectHelicopter => 'Helicóptero';

  @override
  String get mediaCutterPartEffectAlien => 'Vibrato alienígena';

  @override
  String get mediaCutterPartEffectBrightVoice => 'Voz mais clara';

  @override
  String get mediaCutterPartEffectDarkVoice => 'Voz mais escura';

  @override
  String get mediaCutterPartEffectGhost => 'Fantasma';

  @override
  String get mediaCutterPartEffectTelephone => 'Telefone';

  @override
  String get mediaCutterPartEffectOldRadio => 'Rádio antiga';

  @override
  String get mediaCutterPartEffectMegaphone => 'Megafone';

  @override
  String get mediaCutterPartEffectUnderwater => 'Debaixo de água';

  @override
  String get mediaCutterPartEffectMonster => 'Monstro';

  @override
  String get mediaCutterPartEffectChipmunk => 'Voz aguda';

  @override
  String get mediaCutterPartEffectDream => 'Sonho';

  @override
  String get mediaCutterPartEffectDistortion => 'Distorção';

  @override
  String get mediaCutterPartEffectLoFi => 'Lo-fi';

  @override
  String get mediaCutterPartEffectReverseEcho => 'Eco reverso';

  @override
  String get mediaCutterPartEffectFadeIn => 'Fade in';

  @override
  String get mediaCutterPartEffectFadeOut => 'Fade out';

  @override
  String mediaCutterPartEffectAmountValue(int percent) {
    return 'Intensidade do efeito: $percent%';
  }

  @override
  String get mediaCutterPartPreviewAction => 'Ouvir prévia';

  @override
  String get mediaCutterPartEffectsSavedOnly =>
      'A prévia usa o volume escolhido. Os efeitos de áudio são aplicados ao salvar.';

  @override
  String mediaCutterPartEffectsApplied(String start, String end) {
    return 'Efeitos atualizados para a parte de $start a $end.';
  }

  @override
  String mediaCutterPartEffectsSummary(int percent, String effect) {
    return 'Volume $percent%, efeito $effect';
  }

  @override
  String get mediaCutterGuidedModeTitle => 'Corte guiado';

  @override
  String get mediaCutterGuidedModeDescription =>
      'Adequado para quem está a começar. Selecione um ponto inicial e um ponto final, ouça o corte e depois aplique-o.';

  @override
  String get mediaCutterAdvancedModeTitle => 'Corte avançado';

  @override
  String get mediaCutterAdvancedModeDescription =>
      'Inspirado nos programas de edição multimédia mais conhecidos. Permite dividir um ficheiro em várias partes e eliminar as partes que não quer.';

  @override
  String get mediaCutterChangeCutMode => 'Alterar tipo de corte';

  @override
  String get mediaCutterGuidedSetStart => 'Início do corte';

  @override
  String get mediaCutterGuidedSetEnd => 'Fim do corte';

  @override
  String get mediaCutterGuidedApplyCut => 'Aplicar corte';

  @override
  String get mediaCutterGuidedListenCut => 'Ouvir corte';

  @override
  String get mediaCutterGuidedModifyCut => 'Modificar corte';

  @override
  String get mediaCutterGuidedMoveStartBackOneSecond =>
      'Recuar o início do corte 1 segundo';

  @override
  String get mediaCutterGuidedMoveStartForwardOneSecond =>
      'Avançar o início do corte 1 segundo';

  @override
  String get mediaCutterGuidedMoveEndBackOneSecond =>
      'Recuar o fim do corte 1 segundo';

  @override
  String get mediaCutterGuidedMoveEndForwardOneSecond =>
      'Avançar o fim do corte 1 segundo';

  @override
  String get mediaCutterCutEditPrecisionLabel => 'Precisão da edição do corte';

  @override
  String mediaCutterCutEditPrecisionValue(String value) {
    return 'Precisão da edição do corte: $value';
  }

  @override
  String get mediaCutterCutEditStepOneSecond => '1 segundo';

  @override
  String get mediaCutterCutEditStepHalfSecond => '0,5 segundos';

  @override
  String get mediaCutterCutEditStepQuarterSecond => '0,25 segundos';

  @override
  String get mediaCutterCutEditStepTenthSecond => '0,10 segundos';

  @override
  String mediaCutterMoveStartBackBy(String value) {
    return 'Mover início do corte para trás em $value';
  }

  @override
  String mediaCutterMoveStartForwardBy(String value) {
    return 'Mover início do corte para a frente em $value';
  }

  @override
  String mediaCutterMoveEndBackBy(String value) {
    return 'Mover fim do corte para trás em $value';
  }

  @override
  String mediaCutterMoveEndForwardBy(String value) {
    return 'Mover fim do corte para a frente em $value';
  }

  @override
  String mediaCutterGuidedCutAdjusted(String start, String end) {
    return 'Corte modificado de $start a $end.';
  }

  @override
  String get mediaCutterGuidedNoCut => 'Nenhum corte';

  @override
  String get mediaCutterGuidedEffectsAction => 'Regular efeitos do ficheiro';

  @override
  String get mediaCutterGuidedEffectsDescription =>
      'Regule o volume e os efeitos para todo o ficheiro resultante.';

  @override
  String get mediaCutterGuidedFileTapHint =>
      'Toque duas vezes para reproduzir o ficheiro resultante. Use Regular efeitos do ficheiro para aplicar efeitos a todo o ficheiro.';

  @override
  String mediaCutterGuidedStartSet(String start) {
    return 'Início do corte definido em $start.';
  }

  @override
  String mediaCutterGuidedEndSet(String start, String end) {
    return 'Fim do corte definido em $end. Corte de $start a $end.';
  }

  @override
  String mediaCutterGuidedCutApplied(String start, String end) {
    return 'Corte aplicado de $start a $end.';
  }

  @override
  String get mediaCutterGuidedNeedStartEnd =>
      'Defina primeiro o início e o fim do corte.';

  @override
  String mediaCutterGuidedCutSummary(String start, String end) {
    return 'Corte de $start a $end';
  }

  @override
  String mediaCutterGuidedMultipleCutSummary(int count, String cuts) {
    return '$count cortes: $cuts';
  }

  @override
  String get mediaCutterGuidedPendingCutExitMessage =>
      'Tem um corte guiado que ainda não foi aplicado. Quer sair sem o conservar?';

  @override
  String mediaCutterSplitAddedAnnouncement(int partNumber) {
    return 'Divisão adicionada. Parte $partNumber adicionada.';
  }

  @override
  String get newsAddCommunitySource => 'Adicionar fonte à comunidade Sonarpad';

  @override
  String get newsBrowseCommunitySources => 'Fontes da comunidade';

  @override
  String get newsAddCommunityInstructions =>
      'Introduza o título da fonte e o URL do feed RSS ou do site. O Sonarpad usará o idioma de notícias selecionado e, se introduzir um site, tentará encontrar o feed automaticamente.';

  @override
  String get newsCommunitySourceName => 'Título da fonte';

  @override
  String get newsCommunitySourceUrl => 'URL do feed RSS ou do site';

  @override
  String get newsCommunitySubmit => 'Verificar e adicionar';

  @override
  String get newsCommunityChecking => 'A verificar feed ou site...';

  @override
  String get newsCommunityMissingFields =>
      'Introduza o título e o URL do feed ou do site.';

  @override
  String get newsCommunityAdded =>
      'Fonte adicionada corretamente à comunidade Sonarpad.';

  @override
  String newsCommunityAddError(Object error) {
    return 'Erro ao adicionar a fonte: $error';
  }

  @override
  String newsCommunitySelectedLanguage(Object language) {
    return 'Idioma selecionado: $language';
  }

  @override
  String get newsCommunitySourcesTitle => 'Fontes da comunidade';

  @override
  String get newsCommunitySourcesEmpty =>
      'Não há fontes da comunidade disponíveis para este idioma.';

  @override
  String newsCommunitySourcesError(Object error) {
    return 'Erro ao carregar as fontes da comunidade: $error';
  }

  @override
  String newsCommunitySourceAddedToLibrary(Object name) {
    return '$name adicionada à sua biblioteca de notícias.';
  }

  @override
  String newsCommunityAddToLibraryError(Object error) {
    return 'Erro ao adicionar à biblioteca: $error';
  }

  @override
  String get newsCommunitySourceTapHint =>
      'Toque para adicioná-la à sua biblioteca de notícias.';
}
