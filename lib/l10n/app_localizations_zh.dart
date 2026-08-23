import 'app_localizations.dart';
// ignore_for_file: type=lint

/// The translations for Simplified Chinese (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizations {
  AppLocalizationsZhCn([String locale = 'zh_CN']) : super(locale);

  @override
  String get appTitle => 'Sonarpad';

  @override
  String get appLanguage => '应用语言';

  @override
  String get settingsTheme => '应用主题';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsWeatherTemperatureUnit => '天气温度单位';

  @override
  String get weatherTemperatureCelsius => '摄氏度（°C）';

  @override
  String get weatherTemperatureFahrenheit => '华氏度（°F）';

  @override
  String get homeSemanticsLabel => 'Sonarpad，主屏幕';

  @override
  String get settings => '设置';

  @override
  String get settingsHint => '打开设置';

  @override
  String get info => '关于';

  @override
  String get infoHint => '打开应用信息';

  @override
  String get categoryReading => '阅读与文档';

  @override
  String get categoryMedia => '媒体与娱乐';

  @override
  String get sonarTubeTitle => 'SonarTube';

  @override
  String get sonarTubeSearchLabel => '搜索视频、频道或播放列表';

  @override
  String get sonarTubeSearchPrompt => '输入搜索内容以查找视频、频道和播放列表。';

  @override
  String get sonarTubeNoResults => '未找到视频。';

  @override
  String get sonarTubeLoadMore => '加载更多结果';

  @override
  String get sonarTubeChannel => '频道';

  @override
  String get sonarTubePlaylist => '播放列表';

  @override
  String get sonarTubeLive => '直播';

  @override
  String get sonarTubeResolving => '正在准备视频…';

  @override
  String get sonarTubeFavorites => '收藏';

  @override
  String get sonarTubeNoFavorites => '没有收藏的频道或播放列表。';

  @override
  String get sonarTubeAddFavorite => '添加到收藏';

  @override
  String get sonarTubeRemoveFavorite => '从收藏中移除';

  @override
  String sonarTubeFavoriteAdded(String name) => '已将 ${name} 添加到收藏。';

  @override
  String sonarTubeFavoriteRemoved(String name) => '已将 ${name} 从收藏中移除。';

  @override
  String get categoryUtilities => '搜索与工具';

  @override
  String get voiceDictionaryTitle => '语音词典';

  @override
  String get voiceDictionaryAdd => '向词典添加条目';

  @override
  String get voiceDictionaryOriginalWord => '原词';

  @override
  String get voiceDictionaryReplacementWord => '替换词';

  @override
  String get voiceDictionaryMatchCase => '区分大小写';

  @override
  String get voiceDictionaryIgnoreCase => '忽略大小写';

  @override
  String get voiceDictionaryEntries => '词典条目';

  @override
  String get voiceDictionaryEmpty => '词典中没有条目。';

  @override
  String get voiceDictionaryRemove => '移除所选条目';

  @override
  String get voiceDictionaryOriginalRequired => '请输入原词。';

  @override
  String get convertMediaTitle => '转换媒体';

  @override
  String get convertMediaInput => '要转换的文件';

  @override
  String get convertMediaOutput => '保存文件夹';

  @override
  String get convertMediaImage => '图像';

  @override
  String get convertMediaBrowse => '浏览...';

  @override
  String get convertMediaFormat => '格式';

  @override
  String get convertMediaBitrate => '比特率（kbps）';

  @override
  String get convertMediaOggQuality => '质量（q）';

  @override
  String get convertMediaFlacCompression => '压缩级别';

  @override
  String get convertMediaWavBitDepth => 'WAV 位深度';

  @override
  String get convertMediaReady => '就绪。';

  @override
  String get convertMediaRunning => '正在转换...';

  @override
  String get convertMediaDone => '转换完成。';

  @override
  String get convertMediaButton => '转换媒体';

  @override
  String get convertMediaNoInput => '请选择要转换的文件。';

  @override
  String get convertMediaNoOutput => '请选择保存文件夹。';

  @override
  String get convertMediaOutputNotWritable => '无法直接访问所选文件夹。文件将保存在 Sonarpad 的内部文件夹中；转换完成后，你可以分享文件，或将其保存到“文件”应用中。';

  @override
  String get convertMediaNoImage => '请选择用于视频的图像。';

  @override
  String get convertMediaSamePath => '转换后的文件必须与源文件不同。';

  @override
  String get convertMediaInvalidBitrate => '比特率无效。请输入 64 到 320 kbps 之间的值。';

  @override
  String convertMediaFailed(Object error) => '转换失败：${error}';

  @override
  String get donations => '捐赠';

  @override
  String get donationsHint => '支持 Sonarpad 的开发';

  @override
  String get loading => '正在加载';

  @override
  String get ttsVoiceLanguage => 'TTS 语音语言';

  @override
  String get ttsVoice => 'TTS 语音';

  @override
  String get saveSettings => '保存设置';

  @override
  String get settingsSaved => '设置已保存。';

  @override
  String get settingsSavedTitle => '设置已保存';

  @override
  String get sonarpadCodeValidTitle => '代码有效';

  @override
  String get sonarpadCodeValidMessage => 'Sonarpad 代码正确。设置已保存。';

  @override
  String get sonarpadCodeInvalidTitle => '代码无效';

  @override
  String get sonarpadCodeInvalidMessage => 'Sonarpad 代码无效。请确认复制时没有多余的空格。';

  @override
  String get infoDescription => 'Sonarpad 是一款简单但功能丰富的应用。它专为盲人和视障人士使用 VoiceOver 进行无障碍操作而设计，可用于收听新闻、搜索并订阅播客、导入维基百科文章、将文档添加到资料库并进行保存和编辑。Sonarpad 会持续更新，每项功能都旨在让日常生活更轻松。';

  @override
  String get infoAuthor => '作者：Ambrogio Riili';

  @override
  String get donationsIntro => 'Sonarpad 最初是为满足个人需求而创建的，但随着时间推移，它逐渐发展成一款功能更广泛的应用。开发需要持续投入：改进功能、修复错误、探索新想法，并认真测试每一项功能。\n\n如果你觉得 Sonarpad 对你有帮助，并希望支持它的开发，可以进行捐赠。';

  @override
  String get donationsPaypalDesc => '你可以通过 PayPal 使用以下链接捐赠：\nhttps://www.paypal.me/ambrogio86\n如有可能，请在付款备注中填写“Sonarpad”。';

  @override
  String get donationsBankDesc => '你也可以通过银行转账捐赠至 Ambrogio Riili 名下的银行账户。\nIBAN：IT77W0306901020100000064149\n如有可能，请填写清晰的付款用途，例如“Sonarpad”。';

  @override
  String get donationsThanks => '所有支持本项目的人都会在应用和 GitHub 仓库中被提及，除非他们希望保持匿名或使用昵称。\n\n感谢 Jiri Holzinger 和 Paola Vagata 的贡献。\n捷克语翻译感谢 Radek Žalud 和 Jiri Holzinger。\n西班牙语翻译感谢 Arturo Fernandez Rivas。';

  @override
  String get news => '新闻';

  @override
  String get newsHint => '打开 Google 新闻 RSS';

  @override
  String get podcasts => '播客';

  @override
  String get podcastsHint => '订阅播客，播放或下载单集';

  @override
  String get importFromWikipedia => '维基百科';

  @override
  String get wikipediaHint => '搜索维基百科文章并导入文本';

  @override
  String get newsCategoryTop => '头条新闻';

  @override
  String get settingsHomeGrouping => '将主页图标按类别分组';

  @override
  String get settingsHomeGroupingHint => '关闭后，主页图标将以单一列表显示，不再使用子文件夹';

  @override
  String get newsCategoryMyCity => '我的城市';

  @override
  String get newsLocalCityLabel => '输入你的城市';

  @override
  String get newsLocalCityHint => '更正用于本地新闻的城市';

  @override
  String get update => '更新';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get hide => '删除';

  @override
  String get moveToPosition => '移动到位置';

  @override
  String positionLabel(int position, String targetName) => '位置 ${position}：位于 ${targetName} 之前';

  @override
  String get positionLabelLast => '最后一个位置';

  @override
  String get restoreHiddenSources => '恢复已删除的来源';

  @override
  String get addCustomNewsSource => '添加自定义 RSS 来源';

  @override
  String get newsSourceName => '来源或网站名称';

  @override
  String get newsSourceUrlOrSearch => '网站网址、RSS 源或搜索词';

  @override
  String get deleteNewsSource => '删除来源';

  @override
  String get importRssSourcesFromOpml => '从 OPML 导入 RSS 来源';

  @override
  String get exportRssSourcesToOpml => '将 RSS 来源导出为 OPML';

  @override
  String rssImportComplete(int count) => '已导入 RSS 来源：${count}';

  @override
  String rssImportError(Object error) => 'RSS 导入错误：${error}';

  @override
  String get rssExportComplete => 'RSS 来源已导出';

  @override
  String rssExportError(Object error) => 'RSS 导出错误：${error}';

  @override
  String get articleTextSemantics => '文章正文';

  @override
  String get newsLanguage => '新闻语言';

  @override
  String get loadingNews => '正在加载新闻';

  @override
  String error(Object error) => '错误：${error}';

  @override
  String get noNewsFound => '未找到新闻';

  @override
  String get loadingArticle => '正在加载文章';

  @override
  String get noFullArticleFound => '无法获取完整文章。正在显示订阅源摘要。';

  @override
  String get italian => '意大利语';

  @override
  String get english => '英语';

  @override
  String get french => '法语';

  @override
  String get spanish => '西班牙语';

  @override
  String get german => '德语';

  @override
  String get newsSource => '新闻来源';

  @override
  String get article => '文章';

  @override
  String get articlePreview => '文章预览';

  @override
  String get readFullArticle => '阅读完整文章';

  @override
  String get extractingReaderArticleText => '正在以阅读器模式提取文本...';

  @override
  String get extractingVisibleArticleText => '正在提取页面可见文本...';

  @override
  String source(String source) => '来源：${source}';

  @override
  String get readyStatus => '就绪。';

  @override
  String get preparingEdgeTts => '正在准备 Edge TTS 分段朗读...';

  @override
  String get noTextToRead => '没有可朗读的文本。';

  @override
  String chunkCreated(int index, int total) => '已创建第 ${index}/${total} 个分段。正在朗读...';

  @override
  String playingChunk(int index, int total, int size) => '正在播放第 ${index}/${total} 个分段（${size} 字节）...';

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) => '朗读结束。已创建分段：${readyChunks}/${totalChunks}。资料库：${libraryPath}';

  @override
  String get libraryNotSpecified => '未指定';

  @override
  String get readingStopped => '朗读已停止。';

  @override
  String edgeTtsError(Object error) => 'Edge TTS 错误：${error}';

  @override
  String audioChunksReady(int readyChunks, int totalChunks) => '音频分段已就绪：${readyChunks} / ${totalChunks}';

  @override
  String get readingInProgress => '正在朗读...';

  @override
  String get readWithEdgeTts => '开始朗读';

  @override
  String get stopReading => '停止朗读';

  @override
  String get startReading => '开始朗读';

  @override
  String get resumeReading => '继续朗读';

  @override
  String get pauseReading => '暂停朗读';

  @override
  String get openOriginalArticle => '打开原始文章';

  @override
  String get searchPodcasts => '搜索播客';

  @override
  String get podcastName => '播客名称';

  @override
  String get podcastSearchHint => '例如：科技、历史、播客名称...';

  @override
  String get searchCountry => '搜索国家/地区';

  @override
  String get browsePodcastCountries => '按国家/地区浏览';

  @override
  String get podcastCountries => '播客国家/地区';

  @override
  String get podcastCategory => '播客类别';

  @override
  String get browsePodcastCategories => '浏览类别';

  @override
  String get selectedPodcastCategory => '已选类别';

  @override
  String get selectedRecently => '最近选择';

  @override
  String get podcastCategories => '播客类别';

  @override
  String get countryItaly => '意大利';

  @override
  String get countryUnitedStatesEnglish => '美国 / 英语';

  @override
  String get countryUnitedKingdom => '英国';

  @override
  String get countrySpain => '西班牙';

  @override
  String get countryFrance => '法国';

  @override
  String get searchInProgress => '正在搜索...';

  @override
  String get newsReadArticles => '阅读文章';

  @override
  String get weatherRecentCities => '最近的城市';

  @override
  String podcastResultsFound(int count) => '找到 ${count} 个播客';

  @override
  String podcastSearchError(Object error) => '播客搜索错误：${error}';

  @override
  String subscribedTo(String title) => '已订阅 ${title}';

  @override
  String subscriptionError(Object error) => '订阅错误：${error}';

  @override
  String podcastSubscriptionError(Object error) => '播客订阅错误：${error}';

  @override
  String get searchResults => '搜索结果';

  @override
  String get podcastInfo => '播客信息';

  @override
  String get subscribe => '订阅';

  @override
  String get openPodcast => '打开播客';

  @override
  String get viewEpisodes => '查看单集';

  @override
  String get podcastAuthor => '作者';

  @override
  String get noPodcastDescription => '暂无简介。';

  @override
  String get noPodcastResults => '未找到播客。';

  @override
  String get loadingPodcastInfo => '正在加载播客信息';

  @override
  String get podcastArtwork => '播客封面';

  @override
  String get addFeedUrlManually => '手动添加 RSS 源网址';

  @override
  String get podcastFeedUrl => '播客 RSS 源网址';

  @override
  String get subscribeFromUrl => '通过网址订阅';

  @override
  String get subscribedPodcasts => '已订阅的播客';

  @override
  String get noSubscribedPodcasts => '没有已订阅的播客。搜索播客并轻点结果即可订阅。';

  @override
  String get localAudioFiles => '本地音频文件';

  @override
  String get noLocalAudioFiles => '未找到本地音频文件。';

  @override
  String get importAudioFromITunes => '导入本地音频文件';

  @override
  String localAudioFilesFound(int count) => '找到本地音频文件：${count}';

  @override
  String get importPodcastsFromFile => '从文件导入播客';

  @override
  String get exportPodcastsToFile => '将播客导出为 OPML 文件';

  @override
  String podcastImportComplete(int count) => '已导入播客：${count}';

  @override
  String podcastImportError(Object error) => '播客导入错误：${error}';

  @override
  String get podcastInvalidOpmlFile => '文件无效。请选择 OPML 或 XML 文件。';

  @override
  String get podcastExportComplete => '播客已导出';

  @override
  String podcastExportError(Object error) => '播客导出错误：${error}';

  @override
  String get loadingEpisodes => '正在加载单集';

  @override
  String get noAudioEpisodesFound => '订阅源中未找到音频单集。';

  @override
  String get episodes => '单集';

  @override
  String get episodeActions => '单集操作';

  @override
  String downloaded(String path) => '已下载：${path}';

  @override
  String episodeError(Object error) => '单集错误：${error}';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get rewind15s => '后退 15 秒';

  @override
  String get forward15s => '前进 15 秒';

  @override
  String get stop => '停止';

  @override
  String get back => '返回';

  @override
  String get episodePlayer => '单集播放器';

  @override
  String nowPlayingTitle(String title) => '正在播放：${title}';

  @override
  String get loadingEpisodeAudio => '正在加载单集音频';

  @override
  String get playbackPosition => '播放位置';

  @override
  String playbackPositionValue(String position, String duration) => '${position} / ${duration}';

  @override
  String get adjustVolume => '调节音量';

  @override
  String volumeValue(int percentage) => '音量：${percentage}%';

  @override
  String get download => '下载';

  @override
  String get searchWikipedia => '在维基百科中搜索';

  @override
  String get wikipediaLanguage => '维基百科语言';

  @override
  String get search => '搜索';

  @override
  String get wikipediaSearch => '维基百科搜索';

  @override
  String get wikipediaImporting => '正在导入维基百科内容';

  @override
  String get noWikipediaResults => '未找到维基百科结果';

  @override
  String get wikipediaImportMode => '导入方式';

  @override
  String get wikipediaImportWholeArticle => '整篇文章';

  @override
  String get documents => '文档';

  @override
  String get documentsHint => '打开文档资料库';

  @override
  String get documentLibrary => '文档资料库';

  @override
  String get addToLibrary => '添加到资料库';

  @override
  String get documentImportSelectionMode => '你要选择一个文档还是多个文档？';

  @override
  String get documentImportSingle => '一个文档';

  @override
  String get documentImportMultiple => '多个文档';

  @override
  String get noDocuments => '没有文档。请添加文件。';

  @override
  String get noDocumentsInLibrary => '资料库中没有文档。';

  @override
  String get documentAdded => '文档已添加';

  @override
  String get documentsAdded => '文档已添加';

  @override
  String get importDocumentsFromITunes => '从 iTunes / Apple 设备导入文档';

  @override
  String sharedDocumentsImportComplete(int count) => '从 iTunes / Apple 设备导入的文档：${count}';

  @override
  String libraryLoadError(Object error) => '资料库加载错误：${error}';

  @override
  String fileOpenError(Object error) => '文件打开错误：${error}';

  @override
  String get filePathUnavailable => '文件路径不可用。';

  @override
  String fileInaccessible(String name) => '无法访问文件：${name}';

  @override
  String documentAddError(Object error) => '添加文档错误：${error}';

  @override
  String documentRemoveError(Object error) => '移除错误：${error}';

  @override
  String get noExportableTextFound => '未找到可导出的文本。';

  @override
  String get modifiedDocumentNoExportableText => '修改后的文档中没有可导出的文本。';

  @override
  String get documentRemoved => '文档已移除';

  @override
  String get folderRemoved => '文件夹已移除';

  @override
  String get removeFolder => '移除文件夹';

  @override
  String get removeDocument => '移除文档';

  @override
  String get writeNewDocument => '新建文档';

  @override
  String get addDocumentToLibraryHint => '将文档添加到资料库。浏览设备上的文件并添加。';

  @override
  String get documentTypeLabel => '文档';

  @override
  String get documentPosition => '文档位置';

  @override
  String get documentRemainingLessThanOneMinute => '剩余不到 1 分钟';

  @override
  String documentRemainingMinutes(int minutes) => '大约还剩 ${minutes} 分钟';

  @override
  String documentRemainingHours(int hours) => '大约还剩 ${hours} 小时';

  @override
  String documentRemainingHoursMinutes(int hours, int minutes) => '大约还剩 ${hours} 小时 ${minutes} 分钟';

  @override
  String get folderTypeLabel => '文件夹';

  @override
  String documentAddedOn(String date) => '添加于 ${date}';

  @override
  String documentTypeDescription(String extension) => '类型 ${extension}';

  @override
  String get openFolderHint => '双击打开文件夹';

  @override
  String get openDocumentHint => '双击打开并阅读文档';

  @override
  String removeItem(String name) => '移除 ${name}';

  @override
  String get removePodcast => '移除播客';

  @override
  String get podcastRemoved => '播客已移除';

  @override
  String get documentPickerError => '打开文件时出错';

  @override
  String get readDocument => '阅读文档';

  @override
  String get documentReaderTitle => '文档阅读器';

  @override
  String get documentReaderEditHint => '轻点段落可进行编辑。向上或向下轻扫可添加书签。';

  @override
  String get documentParagraphSelectionStartAction => '开始选择段落';

  @override
  String get documentParagraphSelectionTapHint => '选择模式已启用。双击可选择或取消选择此段落。';

  @override
  String get documentParagraphSelectionStarted => '选择模式已启用。已选择段落。双击其他段落可继续选择。';

  @override
  String documentParagraphSelectedAnnouncement(int count) => '已选择段落。当前共选择：${count}。';

  @override
  String documentParagraphDeselectedAnnouncement(int count) => '已取消选择段落。当前共选择：${count}。';

  @override
  String documentParagraphSelectionCount(int count) => '已选择：${count}';

  @override
  String get documentDeleteSelectedParagraphs => '删除所选段落';

  @override
  String documentDeleteSelectedParagraphsConfirmation(int count) => '删除所选段落吗？共 ${count} 个。';

  @override
  String documentSelectedParagraphsDeleted(int count) => '已删除段落：${count}。';

  @override
  String get documentExitParagraphSelection => '退出段落选择';

  @override
  String get documentParagraphSelectionExited => '选择模式已关闭。';

  @override
  String get documentBookmarkHintSet => '向上或向下轻扫可设置书签。';

  @override
  String get documentEditParagraphActionHint => '双击可编辑此段落。';

  @override
  String get documentBookmarkHintReplace => '向上或向下轻扫可移除现有书签，或用此段落替换书签。';

  @override
  String get documentSetBookmarkAction => '添加新书签';

  @override
  String get documentRemoveBookmarkAction => '移除书签';

  @override
  String get documentReplaceBookmarkAction => '移除并添加新书签';

  @override
  String get searchInDocument => '在文档中搜索';

  @override
  String get documentIndex => '目录';

  @override
  String get documentSearchFieldLabel => '搜索文本';

  @override
  String get documentSearchFieldHint => '要查找的词语或短语';

  @override
  String get documentSearchEmptyQuery => '请输入要搜索的文本。';

  @override
  String get documentSearchResultsTitle => '文档搜索结果';

  @override
  String noDocumentSearchResults(String query) => '未找到“${query}”的结果。';

  @override
  String documentSearchResultParagraph(int number) => '第 ${number} 段';

  @override
  String get edit => '编辑';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get settingsReadingEngine => '朗读引擎';

  @override
  String get settingsEdgeTtsQuality => 'Edge TTS（高质量在线语音）';

  @override
  String get settingsSystemVoices => '系统语音（VoiceOver / Google）';

  @override
  String get settingsNoSystemVoices => '没有可用的系统语音。';

  @override
  String get settingsDefaultVoiceHint => '默认语音';

  @override
  String get settingsDefaultVoice => '默认';

  @override
  String get settingsVoiceSpeed => '速度：';

  @override
  String get settingsVoicePitch => '音调：';

  @override
  String get settingsVoiceSpeedLabel => '朗读速度';

  @override
  String get settingsVoicePitchLabel => '音调';

  @override
  String get settingsTestVoice => '测试语音';

  @override
  String get settingsTestingVoice => '正在播放...';

  @override
  String get settingsVoiceTestText => '这是所选语音的测试。';

  @override
  String settingsVoiceTestError(Object error) => '语音测试错误：${error}';

  @override
  String settingsVoiceSaveError(Object error) => '保存 TTS 语音时出错：${error}';

  @override
  String get settingsUnsavedTitle => '未保存的更改';

  @override
  String get settingsUnsavedMessage => '离开设置前要保存更改吗？';

  @override
  String get settingsExitWithoutSaving => '不保存并退出';

  @override
  String get settingsSystemLanguage => '系统语言';

  @override
  String get settingsSystemVoice => '系统语音';

  @override
  String get settingsAutoBookmark => '自动继续';

  @override
  String get settingsAutoBookmarkHint => '从上次停止的位置继续文档、播客和媒体。';

  @override
  String get settingsDocumentSliderStep => '文档滑块步长';

  @override
  String get settingsDocumentSliderStepHint => '控制向上或向下轻扫时，文档位置滑块移动的距离。';

  @override
  String get settingsReadingSleepTimer => '朗读睡眠定时器';

  @override
  String get settingsReadingSleepTimerOff => '关闭';

  @override
  String settingsReadingSleepTimerMinutes(int minutes) => '${minutes} 分钟';

  @override
  String get settingsReadingSleepTimerHint => '在所选时间后自动停止朗读当前文档并保存停止位置。每次开始朗读文档时都会重新开始倒计时。';

  @override
  String get documentReadingSleepTimerStopped => '睡眠定时器：朗读已停止，位置已保存。';

  @override
  String get settingsSeekStep => '媒体后退 / 快进步长';

  @override
  String get aiChatIntro => '我是 Sonarpad AI。有什么可以帮你？';

  @override
  String get meteoTitle => '天气';

  @override
  String get weatherCity => '城市';

  @override
  String get weatherCityHint => '例如：北京';

  @override
  String get weatherCityNotFound => '未找到城市';

  @override
  String get weatherSearchError => '搜索时出错';

  @override
  String get weatherToday => '今天';

  @override
  String get weatherCurrentSituation => '当前天气';

  @override
  String get weatherTomorrow => '明天';

  @override
  String get weatherChooseDay => '选择日期';

  @override
  String get weatherCurrentTemperature => '当前温度';

  @override
  String get weatherMaxTemperature => '最高温度';

  @override
  String get weatherMinTemperature => '最低温度';

  @override
  String get weatherPrecipitation => '降水量';

  @override
  String get weatherPrecipitationProbability => '降水概率';

  @override
  String get weatherWind => '风';

  @override
  String get weatherRelativeHumidity => '相对湿度';

  @override
  String get settingsSecretCode => '用于额外功能的 Sonarpad 代码';

  @override
  String get settingsRequestCode => '向作者申请代码';

  @override
  String get settingsPasteCode => '粘贴代码';

  @override
  String get settingsCancel => '取消';

  @override
  String get settingsSend => '发送';

  @override
  String get settingsFillFieldsCode => '请填写所有字段以申请代码。';

  @override
  String get settingsName => '名字';

  @override
  String get settingsSurname => '姓氏';

  @override
  String get settingsEmail => '电子邮件';

  @override
  String get settingsOperatingSystem => '操作系统';

  @override
  String settingsCodeRequestBody(
    String name,
    String surname,
    String email,
    String os,
  ) => '名字：${name}；姓氏：${surname}；电子邮件：${email}；操作系统：${os}';

  @override
  String get settingsNameOptional => '名字（可选）';

  @override
  String get settingsMessageOptional => '消息（可选）';

  @override
  String get settingsVerifyCodeAndSave => '正在验证代码并保存...';

  @override
  String get settingsViewSysLog => '查看系统日志';

  @override
  String settingsMailOpenError(Object error) => '打开电子邮件时出错：${error}';

  @override
  String get ok => '确定';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get invia => '发送';

  @override
  String get saveArticle => '保存文章';

  @override
  String get shareArticle => '分享文章';

  @override
  String get articleSavedSuccess => '文章已保存到“文档”';

  @override
  String get annulla => '取消';

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice => '请填写所有字段以申请代码。';

  @override
  String get selectFolder => '选择文件夹';

  @override
  String get exportDocument => '导出文档';

  @override
  String get exportFormatPrompt => '要以哪种格式导出文档？';

  @override
  String get textFormat => '文本（.txt）';

  @override
  String get pdfFormat => 'PDF（.pdf）';

  @override
  String get docxFormat => 'DOCX（.docx）';

  @override
  String get epubFormat => 'EPUB（.epub）';

  @override
  String get exportError => '导出错误';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get folderNameHint => '文件夹名称';

  @override
  String get create => '创建';

  @override
  String get createNewFolder => '创建新文件夹';

  @override
  String get importExternalSources => '从外部来源导入';

  @override
  String get importExternalSourcesTitle => '外部来源';

  @override
  String get importFromDropbox => '从 Dropbox 导入文档';

  @override
  String get importFromProjectGutenberg => '从古登堡计划导入';

  @override
  String get projectGutenbergImportUnavailable => '古登堡计划导入功能暂不可用。';

  @override
  String get importFromInternetArchive => '从互联网档案馆导入';

  @override
  String get internetArchiveTitle => '互联网档案馆';

  @override
  String get internetArchiveSearchLabel => '搜索音频';

  @override
  String get internetArchiveSourceLabel => '来源';

  @override
  String get internetArchiveOldTimeRadio => '经典广播';

  @override
  String get internetArchiveSpeeches => '历史演讲';

  @override
  String get internetArchiveLiveMusic => '现场音乐档案';

  @override
  String get internetArchiveNoItemsFound => '未找到音频项目。';

  @override
  String get saveAudioInDocuments => '将音频保存到“文档”';

  @override
  String get audioSavedInDocuments => '音频已保存到“文档”。';

  @override
  String get noAudioTracksAvailable => '没有可用的音轨。';

  @override
  String get importFromLibriVox => '从 LibriVox 导入';

  @override
  String get gutenbergSearchLabel => '搜索书名或作者';

  @override
  String get sourceLanguageLabel => '语言';

  @override
  String get noGutenbergBooksFound => '未找到图书。';

  @override
  String get loadMore => '加载更多';

  @override
  String sourceLanguageValue(String language) => '语言：${language}';

  @override
  String get gutenbergImportAndRead => '导入并阅读';

  @override
  String get gutenbergImporting => '正在导入...';

  @override
  String get librivoxSearchLabel => '搜索有声书';

  @override
  String get noLibrivoxAudiobooksFound => '未找到有声书。';

  @override
  String get librivoxAudiobookSaved => '有声书已保存到“文档”。';

  @override
  String get librivoxSaveAudiobook => '将有声书保存到“文档”';

  @override
  String get librivoxSaving => '正在保存...';

  @override
  String get librivoxNoAudioTracks => '没有可用的音轨。';

  @override
  String get librivoxNotTextExportable => 'LibriVox 有声书不能导出为文本。';

  @override
  String sourceDurationValue(String duration) => '时长：${duration}';

  @override
  String get importFromPoetryDb => '从 PoetryDB 导入';

  @override
  String get poetryDbSearchLabel => '搜索诗歌';

  @override
  String get poetryDbSearchBy => '搜索方式';

  @override
  String get poetryDbSearchByTitle => '标题';

  @override
  String get poetryDbSearchByAuthor => '作者';

  @override
  String get poetryDbNoPoemsFound => '未找到诗歌。';

  @override
  String poetryDbLineCount(int count) => '${count} 行';

  @override
  String get moveDocument => '移动文档';

  @override
  String get documentMoved => '移动成功';

  @override
  String get outOfFolder => '移出文件夹';

  @override
  String get moveToAnotherFolder => '移动到其他文件夹...';

  @override
  String get ttsError => 'TTS 错误';

  @override
  String get editParagraph => '编辑段落';

  @override
  String get editParagraphTextField => '用于编辑段落的文本框';

  @override
  String get editParagraphHint => '编辑段落文本';

  @override
  String get applyAndSave => '应用并保存';

  @override
  String get textEditedAndSaved => '文本已编辑并保存到当前文档。';

  @override
  String get saveError => '保存时出错';

  @override
  String get docSavedInLibrary => '文档已保存到资料库';

  @override
  String get saveInLibrary => '保存到资料库';

  @override
  String get documentTextLabel => '文档文本';

  @override
  String get modifiedInSonarpad => '已在 Sonarpad 中修改';

  @override
  String get noTextAvailableForDocument => '此文档没有可用文本。';

  @override
  String bookmarkSet(int index) => '已在第 ${index} 段设置书签。';

  @override
  String get bookmarkRemoved => '书签已移除。';

  @override
  String get docEmpty => '文档为空';

  @override
  String get docSavedSuccessfully => '文档保存成功！';

  @override
  String get writeDocument => '编写文档';

  @override
  String get documentTitleOptional => '标题（可选）';

  @override
  String get documentTitleHint => '例如：购物笔记';

  @override
  String get documentTextField => '文档文本';

  @override
  String get documentTextHint => '从这里开始输入...';

  @override
  String get newDocumentDefaultName => '新建文档';

  @override
  String get saving => '正在保存...';

  @override
  String get saveDocument => '保存文档';

  @override
  String get addRssSource => '添加 RSS 来源';

  @override
  String get add => '添加';

  @override
  String get errorPrefix => '错误';

  @override
  String versionBuild(String version, String buildNumber) => '版本 ${version}（构建 ${buildNumber}）';

  @override
  String get whatIsNew => '更新内容';

  @override
  String whatIsNewInVersion(String version) => '版本 ${version} 的更新内容';

  @override
  String changelogLoadError(Object error) => '加载更新内容时出错：${error}';

  @override
  String get visitSonarpadSite => '访问 Sonarpad 网站';

  @override
  String visitSonarpadSiteWithUrl(String url) => '访问 Sonarpad 网站：${url}';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get fileImported => '文件已导入';

  @override
  String importZipError(Object error) => 'ZIP 导入错误：${error}';

  @override
  String get dropboxLoginPrompt => '登录 Dropbox 以导入你的文档。';

  @override
  String get loginToDropbox => '登录 Dropbox';

  @override
  String get logoutFromDropbox => '退出 Dropbox';

  @override
  String get dropboxLoginFailed => '登录失败或已取消';

  @override
  String dropboxLoadFolderError(Object error) => '文件夹加载错误：${error}';

  @override
  String dropboxImportError(Object error) => '导入错误：${error}';

  @override
  String get retry => '重试';

  @override
  String get goBack => '返回';

  @override
  String get noSupportedFilesInFolder => '此文件夹中没有支持的文件。';

  @override
  String get articleNotFound => '未找到文章。';

  @override
  String get errorOpening => '打开时出错';

  @override
  String get recentArticles => '最近文章';

  @override
  String get clearHistory => '清除历史记录';

  @override
  String get confirmClearHistory => '确定要清除所有最近搜索吗？';

  @override
  String get clear => '清除';

  @override
  String get noRecentSearches => '没有最近搜索。';

  @override
  String get logCopiedToClipboard => '日志已复制到剪贴板';

  @override
  String get logCleared => '日志已清除';

  @override
  String get parafarmacoDetailReadyAnnouncement => '产品信息已加载。向右轻扫以选择各个部分。';

  @override
  String get systemLog => '系统日志';

  @override
  String get clearSystemLog => '清除日志';

  @override
  String get copySystemLog => '复制日志';

  @override
  String get donateWithPaypal => '通过 PayPal 捐赠';

  @override
  String get bankTransferTitle => '银行转账';

  @override
  String get enableVideo => '启用视频';

  @override
  String get calendar => '日历';

  @override
  String get calendarHint => '查看日历、节假日、今日圣人和你的提醒';

  @override
  String get saintOfTheDay => '今日圣人';

  @override
  String get quoteOfTheDay => '每日名言';

  @override
  String get reminders => '提醒';

  @override
  String get addReminder => '添加提醒';

  @override
  String get removeReminder => '移除提醒';

  @override
  String get noReminders => '没有提醒';

  @override
  String get writeReminder => '在这里输入提醒内容...';

  @override
  String get saveReminder => '保存';

  @override
  String get cancelReminder => '取消';

  @override
  String get backToToday => '返回今天';

  @override
  String get calendarToday => '今天';

  @override
  String get calendarTomorrow => '明天';

  @override
  String get calendarYesterday => '昨天';

  @override
  String get share => '分享';

  @override
  String get shareCalendarDayOptions => '分享选项';

  @override
  String get shareCalendarDayOnly => '仅分享日期';

  @override
  String get shareCalendarDayWithReminder => '分享日期和提醒';

  @override
  String get listenToAll => '全部朗读';

  @override
  String reminderSaved(int count) => '${count} 个提醒';

  @override
  String get audiodescriptionTitle => '音频描述';

  @override
  String get audiodescriptionRecent => '最近';

  @override
  String get audiodescriptionAll => '全部音频描述';

  @override
  String get audiodescriptionFilm => '电影';

  @override
  String get audiodescriptionSearch => '搜索...';

  @override
  String get audiodescriptionLoading => '正在加载...';

  @override
  String get audiodescriptionError => '加载目录时出错';

  @override
  String get audiodescriptionEmpty => '未找到项目';

  @override
  String get radio => '广播';

  @override
  String get radioHint => '搜索广播电台、收听流媒体并管理收藏';

  @override
  String get radioTitle => '世界各地的广播电台';

  @override
  String get radioFavoritesButton => '收藏的广播电台';

  @override
  String get radioNoFavorites => '没有收藏的广播电台。';

  @override
  String get radioSearchText => '搜索广播电台';

  @override
  String get radioSearchHint => '电台名称或城市...';

  @override
  String get radioLanguage => '语言';

  @override
  String get radioBrowseBy => '浏览方式';

  @override
  String get radioBrowseByLanguage => '按语言浏览';

  @override
  String get radioBrowseByCountry => '按国家/地区浏览';

  @override
  String get radioCountry => '国家/地区';

  @override
  String get radioGenre => '类型';

  @override
  String get radioActiveFilters => '当前筛选条件';

  @override
  String get radioResetFilters => '重置筛选条件';

  @override
  String get radioFiltersReset => '筛选条件已重置。';

  @override
  String get radioCity => '城市';

  @override
  String get radioSearch => '搜索';

  @override
  String get radioSearching => '正在加载电台...';

  @override
  String get radioSearchResults => '电台搜索结果';

  @override
  String get radioNoResults => '未找到电台。';

  @override
  String radioResultsFound(int count) => '找到 ${count} 个广播电台';

  @override
  String radioSearchError(Object error) => '电台搜索错误：${error}';

  @override
  String radioNowPlaying(String name) => '正在播放 ${name}';

  @override
  String radioPlayError(Object error) => '广播流错误：${error}';

  @override
  String get radioAddFavorite => '添加到收藏';

  @override
  String get radioRemoveFavorite => '从收藏中移除';

  @override
  String radioFavoriteAdded(String name) => '已将 ${name} 添加到收藏。';

  @override
  String radioFavoriteRemoved(String name) => '已将 ${name} 从收藏中移除。';

  @override
  String get tvSearchFieldLabel => '搜索电视频道';

  @override
  String get tvSearchFieldHint => '频道名称...';

  @override
  String get tvSearchButton => '搜索';

  @override
  String get tvSearchResults => '电视频道搜索结果';

  @override
  String get tvSearchEmptyQuery => '请输入要搜索的电视频道名称。';

  @override
  String tvSearchNoResults(String query) => '未找到与 ${query} 匹配的电视频道。';

  @override
  String get tvOpenChannelHint => '轻点以播放电视频道';

  @override
  String tvNowOnAir(String title) => '正在播出：${title}';

  @override
  String get radioAddCommunity => '将电台添加到 Sonarpad 社区';

  @override
  String get radioAddName => '电台名称';

  @override
  String get radioAddUrl => '流媒体地址';

  @override
  String get radioAddSubmit => '验证并添加';

  @override
  String get radioAddMissingFields => '请输入电台名称和流媒体地址。';

  @override
  String get radioCommunityAdded => '电台已成功添加到 Sonarpad 社区。';

  @override
  String radioCommunityAddError(Object error) => '添加电台时出错：${error}';

  @override
  String get radioPlay => '播放';

  @override
  String get startRecording => '开始录制';

  @override
  String get stopRecording => '停止录制';

  @override
  String get recordings => '录音';

  @override
  String get recordingInProgressStatus => '录制进行中';

  @override
  String get scheduledRecordingInProgressStatus => '定时录制进行中';

  @override
  String get recordingCannotOpenWhileInProgress => '无法打开此录制，因为录制仍在进行中。';

  @override
  String get blindLibrarySearchCatalog => '搜索目录';

  @override
  String get selectRecordings => '选择录音';

  @override
  String deleteRecordingsConfirmation(int count) => '永久删除 ${count} 条录音吗？';

  @override
  String get noRecordings => '没有录音。';

  @override
  String get recordingStarted => '录制已开始。';

  @override
  String recordingSaved(Object path) => '录音已保存：${path}';

  @override
  String recordingError(Object error) => '录制错误：${error}';

  @override
  String get routeTitle => '路线';

  @override
  String get routeFrom => '起点';

  @override
  String get routeTo => '终点';

  @override
  String get routeCountry => '国家/地区';

  @override
  String get routeCountryItaly => '意大利';

  @override
  String get routeCountryFrance => '法国';

  @override
  String get routeCountrySpain => '西班牙';

  @override
  String get routeCountryCzechRepublic => '捷克共和国';

  @override
  String get routeVehicle => '出行方式';

  @override
  String get routeType => '路线类型';

  @override
  String get routeIncludeMunicipalities => '包含途经城镇';

  @override
  String get routeWalking => '步行';

  @override
  String get routeCycling => '骑行';

  @override
  String get routeDriving => '驾车';

  @override
  String get routeWheelchair => '轮椅';

  @override
  String get routeFastest => '最快';

  @override
  String get routeShortest => '最短';

  @override
  String get routeCalculate => '计算路线';

  @override
  String get routeCalculating => '正在计算...';

  @override
  String get routeChooseFrom => '选择起点';

  @override
  String get routeChooseTo => '选择目的地';

  @override
  String get routeCancel => '取消';

  @override
  String get routeErrorMissingFields => '请输入起点和目的地';

  @override
  String get routeErrorFromNotFound => '未找到起始地址';

  @override
  String get routeErrorToNotFound => '未找到目的地地址';

  @override
  String get routeResultsTitle => '可用路线';

  @override
  String get routeDistance => '距离';

  @override
  String get routeDuration => '时长';

  @override
  String get routeNavigation => '导航详情';

  @override
  String get routeStartMunicipality => '起始城市';

  @override
  String get routeEnterMunicipality => '进入城市';

  @override
  String routeError(Object error) => '错误：${error}';

  @override
  String get radioLanguageIt => '意大利语';

  @override
  String get radioLanguageEn => '英语';

  @override
  String get radioLanguageDe => '德语';

  @override
  String get radioLanguageCountryCh => '瑞士';

  @override
  String get radioLanguageEs => '西班牙语';

  @override
  String get radioLanguagePt => '葡萄牙语';

  @override
  String get radioLanguageSv => '瑞典语';

  @override
  String get radioLanguageVi => '越南语';

  @override
  String get radioLanguageCs => '捷克语';

  @override
  String get radioLanguagePl => '波兰语';

  @override
  String get radioLanguageFr => '法语';

  @override
  String get radioLanguageSr => '塞尔维亚语';

  @override
  String get radioLanguageUk => '乌克兰语';

  @override
  String get radioLanguageHi => '印地语';

  @override
  String get radioLanguageLt => '立陶宛语';

  @override
  String get radioLanguageRu => '俄语';

  @override
  String get radioLanguageZh => '中文';

  @override
  String get radioCountryOptionIt => '意大利';

  @override
  String get radioCountryOptionUs => '美国';

  @override
  String get radioCountryOptionGb => '英国';

  @override
  String get radioCountryOptionFr => '法国';

  @override
  String get radioCountryOptionEs => '西班牙';

  @override
  String get radioCountryOptionDe => '德国';

  @override
  String get radioCountryOptionCh => '瑞士';

  @override
  String get radioCountryOptionAt => '奥地利';

  @override
  String get radioCountryOptionBe => '比利时';

  @override
  String get radioCountryOptionNl => '荷兰';

  @override
  String get radioCountryOptionPt => '葡萄牙';

  @override
  String get radioCountryOptionBr => '巴西';

  @override
  String get radioCountryOptionAr => '阿根廷';

  @override
  String get radioCountryOptionMx => '墨西哥';

  @override
  String get radioCountryOptionCa => '加拿大';

  @override
  String get radioCountryOptionAu => '澳大利亚';

  @override
  String get radioCountryOptionIe => '爱尔兰';

  @override
  String get radioCountryOptionSe => '瑞典';

  @override
  String get radioCountryOptionPl => '波兰';

  @override
  String get radioCountryOptionJp => '日本';

  @override
  String get radioGenreOptionAll => '所有类型';

  @override
  String get radioGenreOptionNews => '新闻';

  @override
  String get radioGenreOptionMusic => '音乐';

  @override
  String get radioGenreOptionSport => '体育';

  @override
  String get radioGenreOptionTalk => '谈话与分析';

  @override
  String get radioGenreOptionPop => '流行音乐';

  @override
  String get radioGenreOptionRock => '摇滚';

  @override
  String get radioGenreOptionClassical => '古典音乐';

  @override
  String get radioGenreOptionJazz => '爵士乐';

  @override
  String get radioGenreOptionDance => '舞曲';

  @override
  String get radioGenreOptionBlues => '蓝调';

  @override
  String get radioGenreOptionCountry => '乡村音乐';

  @override
  String get radioGenreOptionHiphop => '嘻哈';

  @override
  String get radioGenreOptionElectronic => '电子音乐';

  @override
  String get radioGenreOptionLatin => '拉丁音乐';

  @override
  String get radioGenreOptionReggae => '雷鬼';

  @override
  String get radioGenreOptionMetal => '金属';

  @override
  String get radioGenreOptionFolk => '民谣';

  @override
  String get radioGenreOptionReligion => '宗教';

  @override
  String get radioGenreOptionLocal => '本地';

  @override
  String get radioGenreOptionCulture => '文化';

  @override
  String get radioGenreOptionOldies => '70 / 80 / 90 年代';

  @override
  String get radioGenreOptionKids => '儿童';

  @override
  String get radioGenreOptionAmbient => '氛围音乐';

  @override
  String get radioCommunityLanguageItalian => '意大利语';

  @override
  String get radioCommunityLanguageEnglish => '英语';

  @override
  String get radioCommunityLanguageSpanish => '西班牙语';

  @override
  String get radioCommunityLanguageFrench => '法语';

  @override
  String get radioCommunityLanguageGerman => '德语';

  @override
  String get radioCommunityLanguagePortuguese => '葡萄牙语';

  @override
  String get radioCommunityLanguageSwedish => '瑞典语';

  @override
  String get radioCommunityLanguageVietnamese => '越南语';

  @override
  String get radioCommunityLanguageCzech => '捷克语';

  @override
  String get radioCommunityLanguagePolish => '波兰语';

  @override
  String get radioCommunityLanguageSerbian => '塞尔维亚语';

  @override
  String get radioCommunityLanguageUkrainian => '乌克兰语';

  @override
  String get radioCommunityLanguageLithuanian => '立陶宛语';

  @override
  String get radioCommunityLanguageRussian => '俄语';

  @override
  String get radioCommunityLanguageChinese => '中文';

  @override
  String get radioCommunityLanguageHindi => '印地语';

  @override
  String routeDistanceMeters(int meters) => '${meters} 米';

  @override
  String routeDistanceKilometers(String kilometers) => '${kilometers} 公里';

  @override
  String routeDurationMinutes(int minutes) => '${minutes} 分钟';

  @override
  String routeDurationHoursMinutes(int hours, int minutes) => '${hours} 小时 ${minutes} 分钟';

  @override
  String get cinemaTitle => '院线电影';

  @override
  String get cinemaNoMovies => '目前未找到电影。';

  @override
  String get cinemaError => '加载电影时出错。';

  @override
  String cinemaReleased(String date) => '上映日期：${date}';

  @override
  String get cinemaOverviewLabel => '简介：';

  @override
  String get cinemaUpcomingReleases => '即将上映';

  @override
  String cinemaWillRelease(String date) => '上映日期：${date}';

  @override
  String get cinemaOpenTrailer => '打开预告片';

  @override
  String get concertsTitle => '音乐会与活动';

  @override
  String get concertsSearchHint => '输入城市（例如北京、上海）';

  @override
  String get concertsSearchLabel => '按城市搜索音乐会';

  @override
  String get concertsSearchTooltip => '搜索';

  @override
  String get concertsInitialText => '在上方输入你的城市名称，以查看即将举行的音乐会。';

  @override
  String get concertsEmpty => '此城市未找到音乐会。';

  @override
  String get concertsVenue => '演出地点：';

  @override
  String get concertsBuyTickets => '在 Ticketmaster 购票或查看详情';

  @override
  String get podcastPlayedEpisodes => '已播放单集';

  @override
  String get podcastSelectDate => '选择日期';

  @override
  String get podcastNoDatesAvailable => '这些单集没有可用日期。';

  @override
  String get podcastChapters => '章节';

  @override
  String get podcastChaptersUnavailable => '此单集没有可用章节。';

  @override
  String get podcastUnplayed => '未播放单集';

  @override
  String get routeReadAction => '朗读路线';

  @override
  String get routeSaveAction => '保存到文档';

  @override
  String get routeSaveSuccess => '路线已保存到文档';

  @override
  String get deleteItem => '删除';

  @override
  String get audiobookMp3Format => 'MP3 有声书（.mp3）';

  @override
  String get audiobookM4bFormat => 'M4B 有声书（.m4b）';

  @override
  String get exportCompleteTitle => '导出完成';

  @override
  String get exportCompleteMessage => '文件已成功创建。要保存到 Sonarpad 还是分享？';

  @override
  String get saveInSonarpad => '保存到 Sonarpad';

  @override
  String get exportSavedInSonarpad => '文件已保存到 Sonarpad 文档。';

  @override
  String get audiobookExportProgressTitle => '正在创建有声书';

  @override
  String get audiobookExportPreparing => '正在准备有声书...';

  @override
  String get audiobookExportGeneratingAudio => '正在生成音频';

  @override
  String get audiobookExportConvertingAudio => '正在进行最终音频转换...';

  @override
  String get audiobookExportFinalizing => '正在完成...';

  @override
  String get routeRecentRoutes => '最近路线';

  @override
  String get routeRecentRoutesEmpty => '没有最近路线';

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) => '从 ${from} 到 ${to} 的导航详情 - ${date}';

  @override
  String get sortPodcastsAlphabetically => '按字母顺序排列播客';

  @override
  String get sortRadioFavoritesAlphabetically => '按字母顺序排列收藏';

  @override
  String get podcastsSortedAlphabetically => '播客已按字母顺序排列。';

  @override
  String get radioFavoritesSortedAlphabetically => '收藏的电台已按字母顺序排列。';

  @override
  String get settingsIncludeFootnotesInText => '在文本中包含脚注';

  @override
  String get settingsIncludeFootnotesInTextHint => '对于支持的 EPUB 图书，在引用脚注的段落后立即显示相应注释。';

  @override
  String get documentFootnoteLabel => '脚注';

  @override
  String get settingsMultipleDocumentBookmarks => '允许文档使用多个书签';

  @override
  String get settingsMultipleDocumentBookmarksHint => '关闭后，每个文档只保留一个书签。启用后，可以在同一文档中保存多个书签。';

  @override
  String get documentGoToBookmarkAction => '转到书签';

  @override
  String get documentChooseBookmarkTitle => '选择书签';

  @override
  String get documentDeleteBookmarkAction => '删除书签';

  @override
  String get documentKeepBookmarkTitle => '要保留哪个书签？';

  @override
  String get documentKeepBookmarkMessage => '已关闭多个书签。请选择一个要保留的书签，其他书签将被删除。';

  @override
  String documentBookmarkChoiceLabel(int order, int paragraph) => '书签 ${order}，第 ${paragraph} 段';

  @override
  String documentBookmarkChoiceLabelWithPreview(
    int order,
    int paragraph,
    String preview,
  ) => '书签 ${order}，第 ${paragraph} 段。${preview}';

  @override
  String get settingsVideoLandscapeFullscreen => '横屏全屏视频';

  @override
  String get settingsVideoLandscapeFullscreenHint => '启用视频后，将以横屏全屏方式显示。仅音频广播不受影响。';

  @override
  String get settingsPodcastCacheTitle => '播客缓存';

  @override
  String get settingsPodcastCacheHint => '仅清除播客临时文件。订阅、历史记录和已导入音频不会被删除。';

  @override
  String settingsPodcastCacheSize(String size) => '已用空间：${size}';

  @override
  String get clearPodcastCache => '清除播客缓存';

  @override
  String get confirmClearPodcastCacheTitle => '清除播客缓存？';

  @override
  String get confirmClearPodcastCacheMessage => '将删除播客临时文件。订阅和单集历史记录不会被删除。';

  @override
  String podcastCacheCleared(String size) => '播客缓存已清除，释放 ${size}。';

  @override
  String get podcastCacheEmpty => '播客缓存已经为空。';

  @override
  String get pharmacyFeatureTitle => '药品、保健用品和补充剂';

  @override
  String get pharmacyProductsSectionTitle => '保健用品和补充剂';

  @override
  String get pharmacyProductsLoadingTitle => '正在搜索保健用品和补充剂...';

  @override
  String get pharmacyProductsErrorTitle => '搜索保健用品和补充剂时出错';

  @override
  String get pharmacyProductsNoResultsTitle => '未找到保健用品或补充剂';

  @override
  String get mediaCutterTitle => '剪切媒体文件';

  @override
  String get mediaCutterInstruction1 => '打开音频或视频文件，播放并移动到希望剪切的位置。';

  @override
  String get mediaCutterInstruction2 => '暂停后按“分割”，然后在“要保存的片段”中删除不需要的片段，再按“保存”。';

  @override
  String get mediaCutterOpenFile => '打开媒体文件';

  @override
  String mediaCutterSelectedFile(String fileName) => '已选文件：${fileName}';

  @override
  String get mediaCutterPosition => '剪切位置';

  @override
  String get mediaCutterPositionHint => '每次前进或后退 1 秒。';

  @override
  String get mediaCutterHideVideoPreview => '隐藏视频';

  @override
  String get mediaCutterVideoRotation => '视频旋转';

  @override
  String get mediaCutterVideoRotationNone => '不旋转';

  @override
  String get mediaCutterVideoRotationRight => '向右旋转';

  @override
  String get mediaCutterVideoRotationLeft => '向左旋转';

  @override
  String get mediaCutterVideoRotationUpsideDown => '旋转 180 度';

  @override
  String get mediaCutterVideoPreview => '视频预览';

  @override
  String get mediaCutterSplit => '分割';

  @override
  String get mediaCutterPartsTitle => '要保存的片段';

  @override
  String get mediaCutterPartsHint => '轻点片段可试听。已删除的片段会从列表中消失，播放时会跳过，也不会被保存。音频效果只会在保存媒体时应用到整个片段。';

  @override
  String mediaCutterPartLabel(int index) => '片段 ${index}';

  @override
  String mediaCutterPartRange(String start, String end) => '从 ${start} 到 ${end}';

  @override
  String get mediaCutterSave => '保存';

  @override
  String get mediaCutterReady => '就绪。';

  @override
  String get mediaCutterUnsavedExitTitle => '文件未保存';

  @override
  String get mediaCutterUnsavedExitMessage => '文件尚未保存。确定要离开吗？';

  @override
  String get mediaCutterNoFile => '请先打开一个媒体文件。';

  @override
  String get mediaCutterInvalidSplitPoint => '请选择文件内部的位置，不能是开头或结尾。';

  @override
  String get mediaCutterSplitAlreadyExists => '此位置已经有分割点。';

  @override
  String mediaCutterSplitAdded(String position) => '已在 ${position} 添加分割点。';

  @override
  String get mediaCutterSaving => '正在保存文件...';

  @override
  String mediaCutterSaved(String fileName) => '文件已保存：${fileName}';

  @override
  String mediaCutterLoadFailed(Object error) => '无法打开文件：${error}';

  @override
  String mediaCutterSaveFailed(Object error) => '保存失败：${error}';

  @override
  String get mediaCutterNoPartsToSave => '保存前至少保留一个片段。';

  @override
  String get mediaCutterRestoreDeletedPart => '恢复已删除片段';

  @override
  String get mediaCutterNoDeletedParts => '没有可恢复的已删除片段。';

  @override
  String get mediaCutterPartDeleteAction => '删除';

  @override
  String get mediaCutterPartTapHint => '双击可预览此片段。可使用“编辑片段”、“删除”或“调整效果”操作。';

  @override
  String mediaCutterPartDeleted(String start, String end) => '已删除从 ${start} 到 ${end} 的片段。';

  @override
  String mediaCutterPartRestored(String start, String end) => '已恢复从 ${start} 到 ${end} 的片段。';

  @override
  String get mediaCutterPartEffectsAction => '调整效果';

  @override
  String get mediaCutterPartEditAction => '编辑片段';

  @override
  String get mediaCutterPartEditDescription => '将片段开头或结尾移动 1 秒，然后试听编辑后的片段。';

  @override
  String mediaCutterPartAdjusted(String start, String end) => '片段已编辑：从 ${start} 到 ${end}。';

  @override
  String get mediaCutterPartEffectsTitle => '片段效果';

  @override
  String get mediaCutterPartEffectsDescription => '仅调整此片段的音量和效果。';

  @override
  String get mediaCutterPartVolumeLabel => '片段音量';

  @override
  String mediaCutterPartVolumeValue(int percent) => '片段音量：${percent}%';

  @override
  String get mediaCutterPartEffect => '音频效果';

  @override
  String get mediaCutterPartEffectNone => '无效果';

  @override
  String get mediaCutterPartEffectEcho => '轻微回声';

  @override
  String get mediaCutterPartEffectEchoRoom => '房间回声';

  @override
  String get mediaCutterPartEffectEchoChamber => '回声室';

  @override
  String get mediaCutterPartEffectEchoCathedral => '大教堂回声';

  @override
  String get mediaCutterPartEffectLargeRoom => '大房间';

  @override
  String get mediaCutterPartEffectSmallRoom => '小房间';

  @override
  String get mediaCutterPartEffectBathroom => '浴室';

  @override
  String get mediaCutterPartEffectTunnel => '隧道';

  @override
  String get mediaCutterPartEffectRepeatEcho => '重复回声';

  @override
  String get mediaCutterPartEffectCorridor => '走廊';

  @override
  String get mediaCutterPartEffectDelay => '延迟';

  @override
  String get mediaCutterPartEffectReverb => '轻微混响';

  @override
  String get mediaCutterPartEffectChorus => '合唱';

  @override
  String get mediaCutterPartEffectPitchLow => '低音调';

  @override
  String get mediaCutterPartEffectPitchVeryLow => '极低音调';

  @override
  String get mediaCutterPartEffectPitchHigh => '高音调';

  @override
  String get mediaCutterPartEffectPitchVeryHigh => '极高音调';

  @override
  String get mediaCutterPartEffectRobot => '机器人声音';

  @override
  String get mediaCutterPartEffectSuperRobot => '超级机器人';

  @override
  String get mediaCutterPartEffectHelicopter => '直升机';

  @override
  String get mediaCutterPartEffectAlien => '外星人颤音';

  @override
  String get mediaCutterPartEffectBrightVoice => '清亮声音';

  @override
  String get mediaCutterPartEffectDarkVoice => '低沉声音';

  @override
  String get mediaCutterPartEffectGhost => '幽灵';

  @override
  String get mediaCutterPartEffectTelephone => '电话';

  @override
  String get mediaCutterPartEffectOldRadio => '老式收音机';

  @override
  String get mediaCutterPartEffectMegaphone => '扩音器';

  @override
  String get mediaCutterPartEffectUnderwater => '水下';

  @override
  String get mediaCutterPartEffectMonster => '怪物';

  @override
  String get mediaCutterPartEffectChipmunk => '花栗鼠';

  @override
  String get mediaCutterPartEffectDream => '梦境';

  @override
  String get mediaCutterPartEffectDistortion => '失真';

  @override
  String get mediaCutterPartEffectLoFi => '低保真';

  @override
  String get mediaCutterPartEffectReverseEcho => '反向回声';

  @override
  String get mediaCutterPartEffectFadeIn => '淡入';

  @override
  String get mediaCutterPartEffectFadeOut => '淡出';

  @override
  String get mediaCutterPartEffectAmountLabel => '效果强度';

  @override
  String mediaCutterPartEffectAmountValue(int percent) => '效果强度：${percent}%';

  @override
  String get mediaCutterPartPreviewAction => '预览';

  @override
  String get mediaCutterPartEffectsSavedOnly => '预览使用所选音量。音频效果会在保存时应用。';

  @override
  String mediaCutterPartEffectsApplied(String start, String end) => '已更新从 ${start} 到 ${end} 的片段效果。';

  @override
  String mediaCutterPartEffectsSummary(int percent, String effect) => '音量 ${percent}%，效果 ${effect}';

  @override
  String get mediaCutterGuidedModeTitle => '引导式剪切';

  @override
  String get mediaCutterGuidedModeDescription => '适合初学者。选择起点和终点，试听剪切结果，然后应用。';

  @override
  String get mediaCutterAdvancedModeTitle => '高级剪切';

  @override
  String get mediaCutterAdvancedModeDescription => '参考常见媒体编辑程序设计。可以将媒体文件分成多个片段，并删除不需要的部分。';

  @override
  String get mediaCutterChangeCutMode => '更改剪切类型';

  @override
  String get mediaCutterGuidedSetStart => '设置剪切起点';

  @override
  String get mediaCutterGuidedSetEnd => '设置剪切终点';

  @override
  String get mediaCutterGuidedApplyCut => '应用剪切';

  @override
  String get mediaCutterGuidedListenCut => '试听剪切';

  @override
  String get mediaCutterGuidedModifyCut => '编辑剪切';

  @override
  String get mediaCutterGuidedMoveStartBackOneSecond => '将剪切起点后退 1 秒';

  @override
  String get mediaCutterGuidedMoveStartForwardOneSecond => '将剪切起点前进 1 秒';

  @override
  String get mediaCutterGuidedMoveEndBackOneSecond => '将剪切终点后退 1 秒';

  @override
  String get mediaCutterGuidedMoveEndForwardOneSecond => '将剪切终点前进 1 秒';

  @override
  String get mediaCutterCutEditPrecisionLabel => '剪切编辑精度';

  @override
  String mediaCutterCutEditPrecisionValue(String value) => '剪切编辑精度：${value}';

  @override
  String get mediaCutterCutEditStepOneSecond => '1 秒';

  @override
  String get mediaCutterCutEditStepHalfSecond => '0.5 秒';

  @override
  String get mediaCutterCutEditStepQuarterSecond => '0.25 秒';

  @override
  String get mediaCutterCutEditStepTenthSecond => '0.10 秒';

  @override
  String mediaCutterMoveStartBackBy(String value) => '将剪切起点后退 ${value}';

  @override
  String mediaCutterMoveStartForwardBy(String value) => '将剪切起点前进 ${value}';

  @override
  String mediaCutterMoveEndBackBy(String value) => '将剪切终点后退 ${value}';

  @override
  String mediaCutterMoveEndForwardBy(String value) => '将剪切终点前进 ${value}';

  @override
  String mediaCutterGuidedCutAdjusted(String start, String end) => '剪切已更改：从 ${start} 到 ${end}。';

  @override
  String get mediaCutterGuidedNoCut => '没有剪切';

  @override
  String get mediaCutterGuidedEffectsAction => '调整文件效果';

  @override
  String get mediaCutterGuidedEffectsDescription => '调整整个结果文件的音量和效果。';

  @override
  String get mediaCutterGuidedFileTapHint => '双击可播放结果文件。使用“调整文件效果”可将效果应用到整个文件。';

  @override
  String mediaCutterGuidedStartSet(String start) => '剪切起点已设为 ${start}。';

  @override
  String mediaCutterGuidedEndSet(String start, String end) => '剪切终点已设为 ${end}。剪切范围从 ${start} 到 ${end}。';

  @override
  String mediaCutterGuidedCutApplied(String start, String end) => '已应用从 ${start} 到 ${end} 的剪切。';

  @override
  String get mediaCutterGuidedNeedStartEnd => '请先设置剪切起点和终点。';

  @override
  String mediaCutterGuidedCutSummary(String start, String end) => '剪切范围：${start} 到 ${end}';

  @override
  String mediaCutterGuidedMultipleCutSummary(int count, String cuts) => '${count} 个剪切：${cuts}';

  @override
  String get mediaCutterGuidedPendingCutExitMessage => '你有一个尚未应用的引导式剪切。要在不保留它的情况下离开吗？';

  @override
  String mediaCutterSplitAddedAnnouncement(int partNumber) => '已添加分割点。已添加片段 ${partNumber}。';

  @override
  String get newsAddCommunitySource => '将新闻来源添加到 Sonarpad 社区';

  @override
  String get newsBrowseCommunitySources => '社区新闻来源';

  @override
  String get newsAddCommunityInstructions => '输入来源标题以及 RSS 源网址或网站网址。Sonarpad 会使用所选新闻语言；如果输入的是网站网址，还会尝试自动查找订阅源。';

  @override
  String get newsCommunitySourceName => '来源标题';

  @override
  String get newsCommunitySourceUrl => 'RSS 源或网站网址';

  @override
  String get newsCommunitySubmit => '检查并添加';

  @override
  String get newsCommunityChecking => '正在检查订阅源或网站...';

  @override
  String get newsCommunityMissingFields => '请输入标题以及订阅源或网站网址。';

  @override
  String get newsCommunityAdded => '新闻来源已成功添加到 Sonarpad 社区。';

  @override
  String newsCommunityAddError(Object error) => '添加新闻来源时出错：${error}';

  @override
  String newsCommunitySelectedLanguage(Object language) => '所选语言：${language}';

  @override
  String get newsCommunitySourcesTitle => '社区新闻来源';

  @override
  String get newsCommunitySourcesEmpty => '此语言暂无社区新闻来源。';

  @override
  String newsCommunitySourcesError(Object error) => '加载社区新闻来源时出错：${error}';

  @override
  String newsCommunitySourceAddedToLibrary(Object name) => '已将 ${name} 添加到你的新闻资料库。';

  @override
  String newsCommunityAddToLibraryError(Object error) => '添加到资料库时出错：${error}';

  @override
  String get newsCommunitySourceTapHint => '轻点可将其添加到你的新闻资料库。';

  @override
  String get developerModeEnabled => '开发者模式已启用。';

  @override
  String get developerModeDisabled => '开发者模式已关闭。';

  @override
  String get developerSectionTitle => '开发者';

  @override
  String get developerUseExperimentalFlutterRenderer => '使用实验性 Flutter 渲染器';

  @override
  String get developerUseExperimentalFlutterRendererHint => '暂时停用 UIKit，以比较 VoiceOver 在纯 Flutter 下的表现。';

  @override
  String get letterJumpSelectLetter => '选择字母';

  @override
  String get letterJumpSelected => '已选择';

  @override
  String get settingsToggleOn => '开启';

  @override
  String get settingsToggleOff => '关闭';

  @override
  String get radioDirectoryLoading => '正在更新广播国家/地区和语言...';

  @override
  String get recentRadios => '最近电台';

  @override
  String get radioNextPage => '下一页';

  @override
  String radioPageOf(int current, int total) => '第 ${current} 页，共 ${total} 页';

  @override
  String get radioNoResultsWithQuery => '未找到电台。请尝试只输入电台名称，不要输入类型，或更改语言/国家地区。';

  @override
  String get radioNoResultsGeneric => '未找到电台。请尝试其他语言、国家/地区或类型。';

  @override
  String radioSearchRawError(Object error) => '电台搜索错误：${error}';

  @override
  String get radioBrowserConnectionError => '连接 Radio Browser 时出错。请稍后重试。';

  @override
  String get documentIndexLoadingMessage => '正在加载目录...请稍候。';

  @override
  String get documentIndexUnavailableMessage => '此 EPUB 没有可用目录。';

  @override
  String mediaCutterVolumeSummary(int percent) => '音量 ${percent}%';

  @override
  String mediaCutterDurationSummary(String duration) => '时长 ${duration}';

  @override
  String get mediaCutterDurationHourOne => '小时';

  @override
  String get mediaCutterDurationHourFew => '小时';

  @override
  String get mediaCutterDurationHourMany => '小时';

  @override
  String get mediaCutterDurationMinuteOne => '分钟';

  @override
  String get mediaCutterDurationMinuteFew => '分钟';

  @override
  String get mediaCutterDurationMinuteMany => '分钟';

  @override
  String get mediaCutterDurationSecondOne => '秒';

  @override
  String get mediaCutterDurationSecondFew => '秒';

  @override
  String get mediaCutterDurationSecondMany => '秒';

  @override
  String get mediaCutterDurationAnd => '和';

  @override
  String mediaCutterSeekStepButton(String step) => '调整媒体文件移动步长：${step}';

  @override
  String get mediaCutterSeekStepTitle => '媒体文件移动步长';

  @override
  String mediaCutterSeekStepSelected(String step) => '媒体文件移动步长已设为 ${step}。';

  @override
  String get mediaCutterPartEffectBackwards => '倒放';

  @override
  String get mediaCutterPartEffectTalkingGuitar => '会说话的吉他';

  @override
  String get mediaCutterPartEffectMosquito => '蚊子';

  @override
  String get mediaCutterPartEffectOneOfMany => '一个声音，多位歌手';

  @override
  String get mediaCutterPartEffectOrganVocoder => '会说话的风琴';

  @override
  String get mediaCutterPartEffectWarped => '扭曲';

  @override
  String get mediaCutterPartEffectSwirling => '立体声旋涡';

  @override
  String get mediaCutterPartEffectVader => '电影感低沉声音';

  @override
  String get mediaCutterPartEffectMetallic => '金属音';

  @override
  String get mediaCutterPartEffectSongbird => '鸣禽';

  @override
  String get mediaCutterPartEffectExterminator => '灭绝者';

  @override
  String get mediaCutterPartEffectRainAndThunder => '雨声与雷声';

  @override
  String get mediaCutterPartEffectJungle => '丛林';

  @override
  String get mediaCutterPartEffectCrowd => '人群';

  @override
  String get mediaCutterPartEffectSlotMachines => '老虎机';

  @override
  String get mediaCutterPartEffectTraffic => '交通噪声';

  @override
  String get mediaCutterPartEffectSpaceship => '宇宙飞船';

  @override
  String get mediaCutterPartEffectCricket => '蟋蟀';

  @override
  String get mediaCutterPartEffectSiren => '警报器';

  @override
  String get mediaCutterPartEffectSleighBells => '雪橇铃';

  @override
  String get mediaCutterPartEffectDj => 'DJ 刮碟';

  @override
  String get mediaCutterPartEffectApplause => '掌声';

  @override
  String get mediaCutterPartEffectBadMelody => '跑调旋律';

  @override
  String get mediaCutterPartEffectBadHarmony => '不协和和声';

  @override
  String get mediaCutterPartEffectWarmVoice => '温暖声音';

  @override
  String get mediaCutterPartEffectTurtle => '乌龟';

  @override
  String get mediaCutterPartEffectHaunting => '阴森';

  @override
  String get radioPreviousPage => '上一页';

  @override
  String get noRecentRadios => '没有最近电台。';

  @override
  String get radioBrowseByCity => '按城市浏览';

  @override
  String get radioCityInputHint => '输入城市名称...';

  @override
  String get openItem => '打开';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get fileTypeLabel => '文件';

  @override
  String get cinemaTrailerLoading => '正在加载预告片';

  @override
  String get cinemaNoTrailer => '此电影没有可用预告片';

  @override
  String get radioScheduleHours => '小时';

  @override
  String get radioScheduleSelectHours => '选择小时';

  @override
  String get radioScheduleMinutes => '分钟';

  @override
  String get radioScheduleSelectMinutes => '选择分钟';

  @override
  String get radioScheduleStopCurrentFirst => '安排新录制前，请先停止当前录制。';

  @override
  String get radioScheduleStartTime => '开始时间';

  @override
  String get radioScheduleEndTime => '结束时间';

  @override
  String get radioScheduleDialogTitle => '安排录制';

  @override
  String get radioScheduleOpenRequirement => '在你浏览 Sonarpad 的其他屏幕时，计划录制仍会继续工作。Sonarpad 必须保持打开；如果应用被关闭或被系统挂起，则无法保证录制会按时开始。';

  @override
  String radioScheduleStartTimeValue(String time) => '开始时间：${time}';

  @override
  String radioScheduleEndTimeValue(String time) => '结束时间：${time}';

  @override
  String get radioScheduleOptionalTitle => '可选标题';

  @override
  String get radioScheduleTitleHint => '留空则使用广播或电视名称';

  @override
  String get radioScheduleAction => '安排';

  @override
  String radioScheduledRecordingRange(String start, String end) => '计划录制：${start} - ${end}。';

  @override
  String get radioScheduledRecordingAlreadyActive => '计划录制未开始：当前已有其他录制正在进行。';

  @override
  String get radioScheduledRecordingStarted => '计划录制已开始。';

  @override
  String radioScheduledRecordingError(Object error) => '计划录制错误：${error}';

  @override
  String get radioScheduledRecordingSaved => '计划录制已保存。';

  @override
  String radioScheduledRecordingSaveError(Object error) => '保存计划录制时出错：${error}';

  @override
  String get radioScheduledRecordingCancelled => '计划录制已取消。';

  @override
  String radioScheduledRecordingRangeWithTitle(String start, String end, String title) => '计划录制：${start} - ${end}。标题：${title}。';

  @override
  String get radioScheduleCancelAction => '取消计划录制';

  @override
  String get radioLanguageTr => '土耳其语';

  @override
  String get radioCountryOptionTr => '土耳其';

  @override
  String get radioCommunityLanguageTurkish => '土耳其语';

  @override
  String get simplifiedChineseLanguageName => '简体中文';

  @override
  String get chinaCountryName => '中国';

  @override
  String get technicalErrorGeneric => '技术错误。请重试。';

  @override
  String cinemaTrailerTitle(String title) {
    return '预告片：$title';
  }

  @override
  String mediaCutterExportPartProgress(int index, int total) {
    return '第 $index/$total 部分';
  }

  @override
  String get mediaCutterExportFinalVerification => '最终验证';

  @override
  String get mediaCutterExportMergeParts => '合并片段';

  @override
  String get mediaCutterExportFileCheck => '检查文件';

  @override
  String get mediaCutterExportPublishing => '发布';

  @override
  String get mediaCutterExportCompletion => '完成';


  @override
  String get mediaCutterAddTrack => '添加新音轨';

  @override
  String get mediaCutterChooseAudioTrack => '选择音频文件';

  @override
  String mediaCutterAddedTrackSelected(String name) => '已选择音频文件：$name';

  @override
  String get mediaCutterOriginalTrackVolume => '原始音轨音量';

  @override
  String get mediaCutterNewTrackVolume => '新音轨音量';

  @override
  String get mediaCutterLoopNewTrack => '循环播放新音轨';

  @override
  String get mediaCutterPreviewNewTrack => '试听';

  @override
  String get mediaCutterFinalizeTrack => '完成';

  @override
  String mediaCutterAddedTrackApplied(String name) => '已添加新音轨：$name';

  @override
  String get mediaCutterAddedTrackInvalidAudio => '所选文件不包含有效的音频轨道。';

  @override
  String get mediaCutterAddedTrackPreviewPreparing => '正在准备试听…';

  @override
  String get mediaCutterAddedTrackPreviewFailed => '无法创建试听。';

  @override
  String get mediaCutterMixingAddedTrack => '正在混合新音轨';


  @override
  String get preserveMedia => '保存媒体';

  @override
  String get preserveMediaSaving => '正在保存媒体…';

  @override
  String get preserveMediaSaved => '媒体已保存到 Sonarpad 文档。';

  @override
  String get preserveMediaError => '无法保存媒体。';

}
