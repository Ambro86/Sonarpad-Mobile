// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sonarpad';

  @override
  String get appLanguage => 'App language';

  @override
  String get settingsTheme => 'App theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsWeatherTemperatureUnit => 'Weather temperature unit';

  @override
  String get weatherTemperatureCelsius => 'Celsius (°C)';

  @override
  String get weatherTemperatureFahrenheit => 'Fahrenheit (°F)';

  @override
  String get homeSemanticsLabel => 'Sonarpad, main screen';

  @override
  String get settings => 'Settings';

  @override
  String get settingsHint => 'Open settings';

  @override
  String get info => 'About';

  @override
  String get infoHint => 'Open app info';

  @override
  String get categoryReading => 'Reading and documents';

  @override
  String get categoryMedia => 'Media and entertainment';

  @override
  String get categoryUtilities => 'Searches and utilities';

  @override
  String get voiceDictionaryTitle => 'Voice dictionary';

  @override
  String get voiceDictionaryAdd => 'Add entries to dictionary';

  @override
  String get voiceDictionaryOriginalWord => 'Original word';

  @override
  String get voiceDictionaryReplacementWord => 'Replacement word';

  @override
  String get voiceDictionaryMatchCase => 'Match case';

  @override
  String get voiceDictionaryIgnoreCase => 'Ignore case';

  @override
  String get voiceDictionaryEntries => 'Dictionary entries';

  @override
  String get voiceDictionaryEmpty => 'No dictionary entries.';

  @override
  String get voiceDictionaryRemove => 'Remove selected entry';

  @override
  String get voiceDictionaryOriginalRequired => 'Enter the original word.';

  @override
  String get convertMediaTitle => 'Convert media';

  @override
  String get convertMediaInput => 'File to convert';

  @override
  String get convertMediaOutput => 'Save folder';

  @override
  String get convertMediaImage => 'Image';

  @override
  String get convertMediaBrowse => 'Browse...';

  @override
  String get convertMediaFormat => 'Format';

  @override
  String get convertMediaBitrate => 'Bitrate (kbps)';

  @override
  String get convertMediaOggQuality => 'Quality (q)';

  @override
  String get convertMediaFlacCompression => 'Compression level';

  @override
  String get convertMediaWavBitDepth => 'WAV bit depth';

  @override
  String get convertMediaReady => 'Ready.';

  @override
  String get convertMediaRunning => 'Converting...';

  @override
  String get convertMediaDone => 'Conversion completed.';

  @override
  String get convertMediaButton => 'Convert media';

  @override
  String get convertMediaNoInput => 'Select a file to convert.';

  @override
  String get convertMediaNoOutput => 'Select a save folder.';

  @override
  String get convertMediaOutputNotWritable =>
      'The selected folder is not directly accessible. The file will be saved in Sonarpad’s internal folder; when conversion is complete, you can share it or save it in the Files app.';

  @override
  String get convertMediaNoImage => 'Select an image for the video.';

  @override
  String get convertMediaSamePath =>
      'The converted file must be different from the source file.';

  @override
  String get convertMediaInvalidBitrate =>
      'Invalid bitrate. Please enter a value between 64 and 320 kbps.';

  @override
  String convertMediaFailed(Object error) {
    return 'Conversion failed: $error';
  }

  @override
  String get donations => 'Donations';

  @override
  String get donationsHint => 'Support the development of Sonarpad';

  @override
  String get loading => 'Loading';

  @override
  String get ttsVoiceLanguage => 'TTS voice language';

  @override
  String get ttsVoice => 'TTS voice';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get settingsSaved => 'Settings saved.';

  @override
  String get settingsSavedTitle => 'Settings saved';

  @override
  String get sonarpadCodeValidTitle => 'Valid code';

  @override
  String get sonarpadCodeValidMessage =>
      'The Sonarpad code is correct. Settings saved.';

  @override
  String get sonarpadCodeInvalidTitle => 'Invalid code';

  @override
  String get sonarpadCodeInvalidMessage =>
      'The Sonarpad code is not valid. Check that you copied it without extra spaces.';

  @override
  String get infoDescription =>
      'Sonarpad is a simple app with many features. Designed to be accessible with VoiceOver for blind and visually impaired people, it lets you listen to news, search for and subscribe to podcasts, import Wikipedia articles, add documents to your library, save them and edit them. Sonarpad is constantly updated, and every feature is designed to make everyday life easier.';

  @override
  String get infoAuthor => 'Author: Ambrogio Riili';

  @override
  String get donationsIntro =>
      'Sonarpad was initially created to meet personal needs, but over time it has grown into a broader app. Its development requires constant work: improving features, fixing bugs, exploring new ideas, and carefully testing every function.\n\nIf you find Sonarpad useful and want to support its development, you can make a donation.';

  @override
  String get donationsPaypalDesc =>
      'You can donate via PayPal using this link:\nhttps://www.paypal.me/ambrogio86\nPlease, if possible, add “Sonarpad” as the payment note.';

  @override
  String get donationsBankDesc =>
      'You can also donate via bank transfer to the bank account in the name of Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nPlease, if possible, use a clear payment reason, for example “Sonarpad”.';

  @override
  String get donationsThanks =>
      'Anyone who supports the project will be mentioned in the app and on the GitHub repository, unless they prefer to stay anonymous or use a nickname.\n\nThanks to Jiri Holzinger and Paola Vagata for their contribution.\nFor the Czech translation, thanks to Radek Žalud and Jiri Holzinger.\nFor the Spanish translation, thanks to Arturo Fernandez Rivas.';

  @override
  String get news => 'News';

  @override
  String get newsHint => 'Open news from Google News RSS';

  @override
  String get podcasts => 'Podcasts';

  @override
  String get podcastsHint => 'Subscribe to podcasts, play or download episodes';

  @override
  String get importFromWikipedia => 'Wikipedia';

  @override
  String get wikipediaHint =>
      'Search for a Wikipedia article and import the text';

  @override
  String get newsCategoryTop => 'Top stories';

  @override
  String get settingsHomeGrouping =>
      'Enable grouping of home icons into categories';

  @override
  String get settingsHomeGroupingHint =>
      'If disabled, the main icons will be shown as a single list without subfolders';

  @override
  String get newsCategoryMyCity => 'My City';

  @override
  String get newsLocalCityLabel => 'Enter your city';

  @override
  String get newsLocalCityHint => 'Correct the city used for local news';

  @override
  String get update => 'Update';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get hide => 'Delete';

  @override
  String get moveToPosition => 'Move to position';

  @override
  String positionLabel(int position, String targetName) {
    return 'Position $position: before $targetName';
  }

  @override
  String get positionLabelLast => 'Last position';

  @override
  String get restoreHiddenSources => 'Restore deleted sources';

  @override
  String get addCustomNewsSource => 'Add custom RSS source';

  @override
  String get newsSourceName => 'Source or site name';

  @override
  String get newsSourceUrlOrSearch => 'Website URL, RSS feed or search word';

  @override
  String get deleteNewsSource => 'Delete source';

  @override
  String get importRssSourcesFromOpml => 'Import RSS sources from OPML';

  @override
  String get exportRssSourcesToOpml => 'Export RSS sources to OPML';

  @override
  String rssImportComplete(int count) {
    return 'Imported RSS sources: $count';
  }

  @override
  String rssImportError(Object error) {
    return 'RSS import error: $error';
  }

  @override
  String get rssExportComplete => 'RSS sources exported';

  @override
  String rssExportError(Object error) {
    return 'RSS export error: $error';
  }

  @override
  String get articleTextSemantics => 'Article text';

  @override
  String get newsLanguage => 'News language';

  @override
  String get loadingNews => 'Loading news';

  @override
  String error(Object error) {
    return 'Error: $error';
  }

  @override
  String get noNewsFound => 'No news found';

  @override
  String get loadingArticle => 'Loading article';

  @override
  String get noFullArticleFound =>
      'Full article not available. Showing feed summary.';

  @override
  String get italian => 'Italian';

  @override
  String get english => 'English';

  @override
  String get french => 'French';

  @override
  String get spanish => 'Spanish';

  @override
  String get newsSource => 'News source';

  @override
  String get article => 'Article';

  @override
  String get articlePreview => 'Article preview';

  @override
  String get readFullArticle => 'Read full article';

  @override
  String get extractingReaderArticleText => 'Extracting text in reader mode...';

  @override
  String get extractingVisibleArticleText =>
      'Extracting visible text from page...';

  @override
  String source(String source) {
    return 'Source: $source';
  }

  @override
  String get readyStatus => 'Ready.';

  @override
  String get preparingEdgeTts => 'Preparing Edge TTS reading in blocks...';

  @override
  String get noTextToRead => 'No text to read.';

  @override
  String chunkCreated(int index, int total) {
    return 'Block $index of $total created. Reading in progress...';
  }

  @override
  String playingChunk(int index, int total, int size) {
    return 'Playing block $index of $total ($size bytes)...';
  }

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) {
    return 'Reading finished. Blocks created: $readyChunks/$totalChunks. Library: $libraryPath';
  }

  @override
  String get libraryNotSpecified => 'not specified';

  @override
  String get readingStopped => 'Reading stopped.';

  @override
  String edgeTtsError(Object error) {
    return 'Edge TTS error: $error';
  }

  @override
  String audioChunksReady(int readyChunks, int totalChunks) {
    return 'Audio blocks ready: $readyChunks / $totalChunks';
  }

  @override
  String get readingInProgress => 'Reading in progress...';

  @override
  String get readWithEdgeTts => 'Start reading';

  @override
  String get stopReading => 'Stop reading';

  @override
  String get startReading => 'Start reading';

  @override
  String get resumeReading => 'Resume reading';

  @override
  String get pauseReading => 'Pause reading';

  @override
  String get openOriginalArticle => 'Open original article';

  @override
  String get searchPodcasts => 'Search podcasts';

  @override
  String get podcastName => 'Podcast name';

  @override
  String get podcastSearchHint =>
      'Example: technology, history, podcast name...';

  @override
  String get searchCountry => 'Search country';

  @override
  String get browsePodcastCountries => 'Browse by country';

  @override
  String get podcastCountries => 'Podcast countries';

  @override
  String get podcastCategory => 'Podcast category';

  @override
  String get browsePodcastCategories => 'Browse categories';

  @override
  String get selectedPodcastCategory => 'Selected category';

  @override
  String get selectedRecently => 'recent choice';

  @override
  String get podcastCategories => 'Podcast categories';

  @override
  String get countryItaly => 'Italy';

  @override
  String get countryUnitedStatesEnglish => 'United States / English';

  @override
  String get countryUnitedKingdom => 'United Kingdom';

  @override
  String get countrySpain => 'Spain';

  @override
  String get countryFrance => 'France';

  @override
  String get searchInProgress => 'Search in progress...';

  @override
  String get newsReadArticles => 'Read articles';

  @override
  String get weatherRecentCities => 'Recent cities';

  @override
  String podcastResultsFound(int count) {
    return 'Found $count podcasts';
  }

  @override
  String podcastSearchError(Object error) {
    return 'Podcast search error: $error';
  }

  @override
  String subscribedTo(String title) {
    return 'Subscribed to $title';
  }

  @override
  String subscriptionError(Object error) {
    return 'Subscription error: $error';
  }

  @override
  String podcastSubscriptionError(Object error) {
    return 'Podcast subscription error: $error';
  }

  @override
  String get searchResults => 'Search results';

  @override
  String get podcastInfo => 'Podcast information';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get openPodcast => 'Open podcast';

  @override
  String get viewEpisodes => 'View episodes';

  @override
  String get podcastAuthor => 'Author';

  @override
  String get noPodcastDescription => 'No description available.';

  @override
  String get noPodcastResults => 'No podcasts found.';

  @override
  String get loadingPodcastInfo => 'Loading podcast info';

  @override
  String get podcastArtwork => 'Podcast artwork';

  @override
  String get addFeedUrlManually => 'Add RSS feed URL manually';

  @override
  String get podcastFeedUrl => 'Podcast RSS feed URL';

  @override
  String get subscribeFromUrl => 'Subscribe from URL';

  @override
  String get subscribedPodcasts => 'Subscribed podcasts';

  @override
  String get noSubscribedPodcasts =>
      'No subscribed podcasts. Search for a podcast and tap a result to subscribe.';

  @override
  String get localAudioFiles => 'Local audio files';

  @override
  String get noLocalAudioFiles => 'No local audio files found.';

  @override
  String get importAudioFromITunes => 'Import local audio files';

  @override
  String localAudioFilesFound(int count) {
    return 'Local audio files found: $count';
  }

  @override
  String get importPodcastsFromFile => 'Import podcasts from file';

  @override
  String get exportPodcastsToFile => 'Export podcasts to OPML file';

  @override
  String podcastImportComplete(int count) {
    return 'Imported podcasts: $count';
  }

  @override
  String podcastImportError(Object error) {
    return 'Podcast import error: $error';
  }

  @override
  String get podcastInvalidOpmlFile =>
      'Invalid file. Select an OPML or XML file.';

  @override
  String get podcastExportComplete => 'Podcasts exported';

  @override
  String podcastExportError(Object error) {
    return 'Podcast export error: $error';
  }

  @override
  String get loadingEpisodes => 'Loading episodes';

  @override
  String get noAudioEpisodesFound => 'No audio episodes found in the feed.';

  @override
  String get episodes => 'Episodes';

  @override
  String get episodeActions => 'Episode actions';

  @override
  String downloaded(String path) {
    return 'Downloaded: $path';
  }

  @override
  String episodeError(Object error) {
    return 'Episode error: $error';
  }

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get rewind15s => 'Rewind 15s';

  @override
  String get forward15s => 'Forward 15s';

  @override
  String get stop => 'Stop';

  @override
  String get back => 'Back';

  @override
  String get episodePlayer => 'Episode player';

  @override
  String nowPlayingTitle(String title) {
    return 'Now playing: $title';
  }

  @override
  String get loadingEpisodeAudio => 'Loading episode audio';

  @override
  String get playbackPosition => 'Position';

  @override
  String playbackPositionValue(String position, String duration) {
    return '$position of $duration';
  }

  @override
  String get adjustVolume => 'Adjust volume';

  @override
  String volumeValue(int percentage) {
    return 'Volume: $percentage%';
  }

  @override
  String get download => 'Download';

  @override
  String get searchWikipedia => 'Search on Wikipedia';

  @override
  String get wikipediaLanguage => 'Wikipedia language';

  @override
  String get search => 'Search';

  @override
  String get wikipediaSearch => 'Wikipedia search';

  @override
  String get wikipediaImporting => 'Wikipedia import';

  @override
  String get noWikipediaResults => 'No Wikipedia results found';

  @override
  String get wikipediaImportMode => 'Import mode';

  @override
  String get wikipediaImportWholeArticle => 'Whole article';

  @override
  String get documents => 'Documents';

  @override
  String get documentsHint => 'Open document library';

  @override
  String get documentLibrary => 'Document library';

  @override
  String get addToLibrary => 'Add to library';

  @override
  String get documentImportSelectionMode =>
      'Do you want to select one document or multiple documents?';

  @override
  String get documentImportSingle => 'One document';

  @override
  String get documentImportMultiple => 'Multiple documents';

  @override
  String get noDocuments => 'No documents. Add a file.';

  @override
  String get noDocumentsInLibrary => 'No documents in the library.';

  @override
  String get documentAdded => 'Document added';

  @override
  String get documentsAdded => 'Documents added';

  @override
  String get importDocumentsFromITunes =>
      'Import documents from iTunes / Apple Devices';

  @override
  String sharedDocumentsImportComplete(int count) {
    return 'Documents imported from iTunes / Apple Devices: $count';
  }

  @override
  String libraryLoadError(Object error) {
    return 'Library loading error: $error';
  }

  @override
  String fileOpenError(Object error) {
    return 'File opening error: $error';
  }

  @override
  String get filePathUnavailable => 'File path unavailable.';

  @override
  String fileInaccessible(String name) {
    return 'File inaccessible: $name';
  }

  @override
  String documentAddError(Object error) {
    return 'Document add error: $error';
  }

  @override
  String documentRemoveError(Object error) {
    return 'Remove error: $error';
  }

  @override
  String get noExportableTextFound => 'No exportable text found.';

  @override
  String get modifiedDocumentNoExportableText =>
      'The modified document contains no exportable text.';

  @override
  String get documentRemoved => 'Document removed';

  @override
  String get folderRemoved => 'Folder removed';

  @override
  String get removeFolder => 'Remove folder';

  @override
  String get removeDocument => 'Remove document';

  @override
  String get writeNewDocument => 'Write new document';

  @override
  String get addDocumentToLibraryHint =>
      'Add document to library. Browse device files and add them.';

  @override
  String get documentTypeLabel => 'Document';

  @override
  String get documentPosition => 'Document position';

  @override
  String get documentRemainingLessThanOneMinute =>
      'less than 1 minute remaining';

  @override
  String documentRemainingMinutes(int minutes) {
    return 'about $minutes minutes remaining';
  }

  @override
  String documentRemainingHours(int hours) {
    return 'about $hours hours remaining';
  }

  @override
  String documentRemainingHoursMinutes(int hours, int minutes) {
    return 'about $hours hours and $minutes minutes remaining';
  }

  @override
  String get folderTypeLabel => 'Folder';

  @override
  String documentAddedOn(String date) {
    return 'added on $date';
  }

  @override
  String documentTypeDescription(String extension) {
    return 'type $extension';
  }

  @override
  String get openFolderHint => 'Double tap to open the folder';

  @override
  String get openDocumentHint => 'Double tap to open and read the document';

  @override
  String removeItem(String name) {
    return 'Remove $name';
  }

  @override
  String get removePodcast => 'Remove podcast';

  @override
  String get podcastRemoved => 'Podcast removed';

  @override
  String get documentPickerError => 'Error opening file';

  @override
  String get readDocument => 'Read document';

  @override
  String get documentReaderTitle => 'Document reader';

  @override
  String get documentReaderEditHint =>
      'Tap a paragraph to edit it. Swipe up or down to add a bookmark.';

  @override
  String get documentBookmarkHintSet => 'Swipe up or down to set a bookmark.';

  @override
  String get documentEditParagraphActionHint =>
      'Double tap to edit this paragraph. ';

  @override
  String get documentBookmarkHintReplace =>
      'Swipe up or down to remove the existing bookmark or replace it with this paragraph.';

  @override
  String get documentSetBookmarkAction => 'Add new bookmark';

  @override
  String get documentRemoveBookmarkAction => 'Remove bookmark';

  @override
  String get documentReplaceBookmarkAction => 'Remove and add a new bookmark';

  @override
  String get searchInDocument => 'Search in document';

  @override
  String get documentIndex => 'Table of contents';

  @override
  String get documentSearchFieldLabel => 'Search text';

  @override
  String get documentSearchFieldHint => 'Word or phrase to find';

  @override
  String get documentSearchEmptyQuery => 'Enter text to search for.';

  @override
  String get documentSearchResultsTitle => 'Document search results';

  @override
  String noDocumentSearchResults(String query) {
    return 'No results found for $query.';
  }

  @override
  String documentSearchResultParagraph(int number) {
    return 'Paragraph $number';
  }

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get settingsReadingEngine => 'Reading engine';

  @override
  String get settingsEdgeTtsQuality => 'Edge TTS (high-quality online)';

  @override
  String get settingsSystemVoices => 'System Voices (VoiceOver / Google)';

  @override
  String get settingsNoSystemVoices => 'No system voices available.';

  @override
  String get settingsDefaultVoiceHint => 'Default voice';

  @override
  String get settingsDefaultVoice => 'Default';

  @override
  String get settingsVoiceSpeed => 'Speed: ';

  @override
  String get settingsVoicePitch => 'Pitch: ';

  @override
  String get settingsVoiceSpeedLabel => 'Reading speed';

  @override
  String get settingsVoicePitchLabel => 'Pitch';

  @override
  String get settingsTestVoice => 'Test voice';

  @override
  String get settingsTestingVoice => 'Playing...';

  @override
  String get settingsVoiceTestText => 'This is a test of the selected voice.';

  @override
  String settingsVoiceTestError(Object error) {
    return 'Voice test error: $error';
  }

  @override
  String settingsVoiceSaveError(Object error) {
    return 'TTS voice save error: $error';
  }

  @override
  String get settingsUnsavedTitle => 'Unsaved changes';

  @override
  String get settingsUnsavedMessage =>
      'Do you want to save your changes before leaving settings?';

  @override
  String get settingsExitWithoutSaving => 'Exit without saving';

  @override
  String get settingsSystemLanguage => 'System language';

  @override
  String get settingsSystemVoice => 'System voice';

  @override
  String get settingsAutoBookmark => 'Automatic resume';

  @override
  String get settingsAutoBookmarkHint =>
      'Resume documents, podcasts, and media from where you left off.';

  @override
  String get settingsDocumentSliderStep => 'Document slider step';

  @override
  String get settingsDocumentSliderStepHint =>
      'Controls how far the document position slider moves when swiping up or down.';

  @override
  String get settingsReadingSleepTimer => 'Reading sleep timer';

  @override
  String get settingsReadingSleepTimerOff => 'Off';

  @override
  String settingsReadingSleepTimerMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get settingsReadingSleepTimerHint =>
      'Automatically stops reading the current document after the selected time and saves the stopping point. The countdown restarts whenever you start reading a document.';

  @override
  String get documentReadingSleepTimerStopped =>
      'Sleep timer: reading stopped and position saved.';

  @override
  String get settingsSeekStep => 'Rewind / fast-forward step for media';

  @override
  String get aiChatIntro => 'I’m Sonarpad AI. How can I help you?';

  @override
  String get meteoTitle => 'Weather';

  @override
  String get weatherCity => 'City';

  @override
  String get weatherCityHint => 'Example: Rome';

  @override
  String get weatherCityNotFound => 'City not found';

  @override
  String get weatherSearchError => 'Error during search';

  @override
  String get weatherToday => 'Today';

  @override
  String get weatherCurrentSituation => 'Current situation';

  @override
  String get weatherTomorrow => 'Tomorrow';

  @override
  String get weatherChooseDay => 'Choose day';

  @override
  String get weatherCurrentTemperature => 'Current temperature';

  @override
  String get weatherMaxTemperature => 'Maximum temperature';

  @override
  String get weatherMinTemperature => 'Minimum temperature';

  @override
  String get weatherPrecipitation => 'Precipitation';

  @override
  String get weatherPrecipitationProbability => 'Precipitation probability';

  @override
  String get weatherWind => 'Wind';

  @override
  String get weatherRelativeHumidity => 'Relative humidity';

  @override
  String get settingsSecretCode => 'Sonarpad code for extra features';

  @override
  String get settingsRequestCode => 'Request code from author';

  @override
  String get settingsPasteCode => 'Paste code';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsSend => 'Send';

  @override
  String get settingsFillFieldsCode => 'Fill all fields to request the code.';

  @override
  String get settingsName => 'Name';

  @override
  String get settingsSurname => 'Surname';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsOperatingSystem => 'Operating system';

  @override
  String settingsCodeRequestBody(
      String name, String surname, String email, String os) {
    return 'Name: $name; Surname: $surname; Email: $email; Operating system: $os';
  }

  @override
  String get settingsNameOptional => 'Name (optional)';

  @override
  String get settingsMessageOptional => 'Message (optional)';

  @override
  String get settingsVerifyCodeAndSave => 'Verifying code and saving...';

  @override
  String get settingsViewSysLog => 'View system log';

  @override
  String settingsMailOpenError(Object error) {
    return 'Error opening email: $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get invia => 'Send';

  @override
  String get saveArticle => 'Save article';

  @override
  String get shareArticle => 'Share article';

  @override
  String get articleSavedSuccess => 'Article saved to Documents';

  @override
  String get annulla => 'Cancel';

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice =>
      'Fill all fields to request the code.';

  @override
  String get selectFolder => 'Select folder';

  @override
  String get exportDocument => 'Export document';

  @override
  String get exportFormatPrompt =>
      'In which format do you want to export the document?';

  @override
  String get textFormat => 'Text (.txt)';

  @override
  String get pdfFormat => 'PDF (.pdf)';

  @override
  String get docxFormat => 'DOCX (.docx)';

  @override
  String get epubFormat => 'EPUB (.epub)';

  @override
  String get exportError => 'Export error';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderNameHint => 'Folder name';

  @override
  String get create => 'Create';

  @override
  String get createNewFolder => 'Create new folder';

  @override
  String get importExternalSources => 'Import from external sources';

  @override
  String get importExternalSourcesTitle => 'External sources';

  @override
  String get importFromDropbox => 'Import documents from Dropbox';

  @override
  String get importFromProjectGutenberg => 'Import from Project Gutenberg';

  @override
  String get projectGutenbergImportUnavailable =>
      'Project Gutenberg import is not available yet.';

  @override
  String get importFromInternetArchive => 'Import from Internet Archive';

  @override
  String get internetArchiveTitle => 'Internet Archive';

  @override
  String get internetArchiveSearchLabel => 'Search audio';

  @override
  String get internetArchiveSourceLabel => 'Source';

  @override
  String get internetArchiveOldTimeRadio => 'Old Time Radio';

  @override
  String get internetArchiveSpeeches => 'Historical speeches';

  @override
  String get internetArchiveLiveMusic => 'Live Music Archive';

  @override
  String get internetArchiveNoItemsFound => 'No audio items found.';

  @override
  String get saveAudioInDocuments => 'Save audio in Documents';

  @override
  String get audioSavedInDocuments => 'Audio saved in Documents.';

  @override
  String get noAudioTracksAvailable => 'No audio tracks available.';

  @override
  String get importFromLibriVox => 'Import from LibriVox';

  @override
  String get gutenbergSearchLabel => 'Search book or author';

  @override
  String get sourceLanguageLabel => 'Language';

  @override
  String get noGutenbergBooksFound => 'No books found.';

  @override
  String get loadMore => 'Load more';

  @override
  String sourceLanguageValue(String language) {
    return 'Language: $language';
  }

  @override
  String get gutenbergImportAndRead => 'Import and read';

  @override
  String get gutenbergImporting => 'Importing...';

  @override
  String get librivoxSearchLabel => 'Search audiobook';

  @override
  String get noLibrivoxAudiobooksFound => 'No audiobooks found.';

  @override
  String get librivoxAudiobookSaved => 'Audiobook saved in Documents.';

  @override
  String get librivoxSaveAudiobook => 'Save audiobook in Documents';

  @override
  String get librivoxSaving => 'Saving...';

  @override
  String get librivoxNoAudioTracks => 'No audio tracks available.';

  @override
  String get librivoxNotTextExportable =>
      'LibriVox audiobooks cannot be exported as text.';

  @override
  String sourceDurationValue(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get importFromPoetryDb => 'Import from PoetryDB';

  @override
  String get poetryDbSearchLabel => 'Search poem';

  @override
  String get poetryDbSearchBy => 'Search by';

  @override
  String get poetryDbSearchByTitle => 'Title';

  @override
  String get poetryDbSearchByAuthor => 'Author';

  @override
  String get poetryDbNoPoemsFound => 'No poems found.';

  @override
  String poetryDbLineCount(int count) {
    return '$count lines';
  }

  @override
  String get moveDocument => 'Move document';

  @override
  String get documentMoved => 'Moved successfully';

  @override
  String get outOfFolder => 'Out of folder';

  @override
  String get moveToAnotherFolder => 'Move to another folder...';

  @override
  String get ttsError => 'TTS error';

  @override
  String get editParagraph => 'Edit paragraph';

  @override
  String get editParagraphTextField => 'Text field for editing the paragraph';

  @override
  String get editParagraphHint => 'Edit the paragraph text';

  @override
  String get applyAndSave => 'Apply and save';

  @override
  String get textEditedAndSaved => 'Text edited and saved in current document.';

  @override
  String get saveError => 'Error while saving';

  @override
  String get docSavedInLibrary => 'Document saved in library';

  @override
  String get saveInLibrary => 'Save in library';

  @override
  String get documentTextLabel => 'Document text';

  @override
  String get modifiedInSonarpad => 'Modified in Sonarpad';

  @override
  String get noTextAvailableForDocument =>
      'No text available for this document.';

  @override
  String bookmarkSet(int index) {
    return 'Bookmark set at paragraph $index.';
  }

  @override
  String get bookmarkRemoved => 'Bookmark removed.';

  @override
  String get docEmpty => 'Document is empty';

  @override
  String get docSavedSuccessfully => 'Document saved successfully!';

  @override
  String get writeDocument => 'Write document';

  @override
  String get documentTitleOptional => 'Title (optional)';

  @override
  String get documentTitleHint => 'Example: Shopping notes';

  @override
  String get documentTextField => 'Document text';

  @override
  String get documentTextHint => 'Start writing here...';

  @override
  String get newDocumentDefaultName => 'New_Document';

  @override
  String get saving => 'Saving...';

  @override
  String get saveDocument => 'Save document';

  @override
  String get addRssSource => 'Add RSS source';

  @override
  String get add => 'Add';

  @override
  String get errorPrefix => 'Error';

  @override
  String versionBuild(String version, String buildNumber) {
    return 'Version $version (Build $buildNumber)';
  }

  @override
  String get whatIsNew => 'What’s new';

  @override
  String whatIsNewInVersion(String version) {
    return 'What’s new in version $version';
  }

  @override
  String changelogLoadError(Object error) {
    return 'Error loading what is new: $error';
  }

  @override
  String get visitSonarpadSite => 'Visit the Sonarpad website';

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return 'Visit the Sonarpad website: $url';
  }

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get fileImported => 'File imported';

  @override
  String importZipError(Object error) {
    return 'ZIP import error: $error';
  }

  @override
  String get dropboxLoginPrompt =>
      'Log in to Dropbox to import your documents.';

  @override
  String get loginToDropbox => 'Log in to Dropbox';

  @override
  String get logoutFromDropbox => 'Log out';

  @override
  String get dropboxLoginFailed => 'Login failed or cancelled';

  @override
  String dropboxLoadFolderError(Object error) {
    return 'Folder loading error: $error';
  }

  @override
  String dropboxImportError(Object error) {
    return 'Import error: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get goBack => 'Go back';

  @override
  String get noSupportedFilesInFolder => 'No supported files in this folder.';

  @override
  String get articleNotFound => 'Article not found.';

  @override
  String get errorOpening => 'Error opening';

  @override
  String get recentArticles => 'Recent articles';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get confirmClearHistory =>
      'Do you really want to clear all recent searches?';

  @override
  String get clear => 'Clear';

  @override
  String get noRecentSearches => 'No recent searches.';

  @override
  String get logCopiedToClipboard => 'Log copied to clipboard';

  @override
  String get logCleared => 'Log cleared';

  @override
  String get parafarmacoDetailReadyAnnouncement =>
      'Product sheet loaded. Swipe right to choose the sections.';

  @override
  String get systemLog => 'System log';

  @override
  String get clearSystemLog => 'Clear log';

  @override
  String get copySystemLog => 'Copy log';

  @override
  String get donateWithPaypal => 'Donate with PayPal';

  @override
  String get bankTransferTitle => 'Bank transfer';

  @override
  String get enableVideo => 'Enable video';

  @override
  String get calendar => 'Calendar';

  @override
  String get calendarHint =>
      'View calendar, holidays, saint of the day, and your reminders';

  @override
  String get saintOfTheDay => 'Saint of the day';

  @override
  String get quoteOfTheDay => 'Quote of the day';

  @override
  String get reminders => 'Reminders';

  @override
  String get addReminder => 'Add reminder';

  @override
  String get removeReminder => 'Remove reminder';

  @override
  String get noReminders => 'No reminders';

  @override
  String get writeReminder => 'Write your reminder here...';

  @override
  String get saveReminder => 'Save';

  @override
  String get cancelReminder => 'Cancel';

  @override
  String get backToToday => 'Back to today';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarTomorrow => 'Tomorrow';

  @override
  String get calendarYesterday => 'Yesterday';

  @override
  String get share => 'Share';

  @override
  String get shareCalendarDayOptions => 'Share options';

  @override
  String get shareCalendarDayOnly => 'Share day only';

  @override
  String get shareCalendarDayWithReminder => 'Share day and reminder';

  @override
  String get listenToAll => 'Listen to all';

  @override
  String reminderSaved(int count) {
    return '$count reminders';
  }

  @override
  String get audiodescriptionTitle => 'Audio descriptions';

  @override
  String get audiodescriptionRecent => 'Recent';

  @override
  String get audiodescriptionAll => 'All audio descriptions';

  @override
  String get audiodescriptionFilm => 'Movies';

  @override
  String get audiodescriptionSearch => 'Search...';

  @override
  String get audiodescriptionLoading => 'Loading...';

  @override
  String get audiodescriptionError => 'Error loading catalog';

  @override
  String get audiodescriptionEmpty => 'No items found';

  @override
  String get radio => 'Radio';

  @override
  String get radioHint =>
      'Search radio stations, listen to streams and manage favorites';

  @override
  String get radioTitle => 'Radio stations from around the world';

  @override
  String get radioFavoritesButton => 'Favorite radio stations';

  @override
  String get radioNoFavorites => 'No favorite radio stations.';

  @override
  String get radioSearchText => 'Search radio stations';

  @override
  String get radioSearchHint => 'Radio station name or city...';

  @override
  String get radioLanguage => 'Language';

  @override
  String get radioBrowseBy => 'Browse by';

  @override
  String get radioBrowseByLanguage => 'Browse by language';

  @override
  String get radioBrowseByCountry => 'Browse by country';

  @override
  String get radioCountry => 'Country';

  @override
  String get radioGenre => 'Genre';

  @override
  String get radioActiveFilters => 'Active filters';

  @override
  String get radioResetFilters => 'Reset filters';

  @override
  String get radioFiltersReset => 'Filters reset.';

  @override
  String get radioCity => 'City';

  @override
  String get radioSearch => 'Search';

  @override
  String get radioSearching => 'Loading radios...';

  @override
  String get radioSearchResults => 'Radio results';

  @override
  String get radioNoResults => 'No radios found.';

  @override
  String radioResultsFound(int count) {
    return 'Found $count radio stations';
  }

  @override
  String radioSearchError(Object error) {
    return 'Radio search error: $error';
  }

  @override
  String radioNowPlaying(String name) {
    return 'Playing $name';
  }

  @override
  String radioPlayError(Object error) {
    return 'Radio stream error: $error';
  }

  @override
  String get radioAddFavorite => 'Add to favorites';

  @override
  String get radioRemoveFavorite => 'Remove from favorites';

  @override
  String radioFavoriteAdded(String name) {
    return '$name added to favorites.';
  }

  @override
  String radioFavoriteRemoved(String name) {
    return '$name removed from favorites.';
  }

  @override
  String get tvSearchFieldLabel => 'Search TV channels';

  @override
  String get tvSearchFieldHint => 'Channel name...';

  @override
  String get tvSearchButton => 'Search';

  @override
  String get tvSearchResults => 'TV channel results';

  @override
  String get tvSearchEmptyQuery =>
      'Enter the name of a TV channel to search for.';

  @override
  String tvSearchNoResults(String query) {
    return 'No TV channels found for $query.';
  }

  @override
  String get tvOpenChannelHint => 'Tap to play the TV channel';

  @override
  String tvNowOnAir(String title) {
    return 'Now on air: $title';
  }

  @override
  String get radioAddCommunity => 'Add radio to Sonarpad community';

  @override
  String get radioAddName => 'Radio name';

  @override
  String get radioAddUrl => 'Stream address';

  @override
  String get radioAddSubmit => 'Verify and add';

  @override
  String get radioAddMissingFields =>
      'Please enter radio name and stream address.';

  @override
  String get radioCommunityAdded =>
      'Radio successfully added to Sonarpad community.';

  @override
  String radioCommunityAddError(Object error) {
    return 'Error adding radio: $error';
  }

  @override
  String get radioPlay => 'Play';

  @override
  String get startRecording => 'Start recording';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get recordings => 'Recordings';

  @override
  String get noRecordings => 'No recordings.';

  @override
  String get recordingStarted => 'Recording started.';

  @override
  String recordingSaved(Object path) {
    return 'Recording saved: $path';
  }

  @override
  String recordingError(Object error) {
    return 'Recording error: $error';
  }

  @override
  String get routeTitle => 'Routes';

  @override
  String get routeFrom => 'From';

  @override
  String get routeTo => 'To';

  @override
  String get routeCountry => 'Country';

  @override
  String get routeCountryItaly => 'Italy';

  @override
  String get routeCountryFrance => 'France';

  @override
  String get routeCountrySpain => 'Spain';

  @override
  String get routeCountryCzechRepublic => 'Czech Republic';

  @override
  String get routeVehicle => 'Transport mode';

  @override
  String get routeType => 'Type';

  @override
  String get routeIncludeMunicipalities => 'Include towns crossed';

  @override
  String get routeWalking => 'Walking';

  @override
  String get routeCycling => 'Cycling';

  @override
  String get routeDriving => 'Driving';

  @override
  String get routeWheelchair => 'Wheelchair';

  @override
  String get routeFastest => 'Fastest';

  @override
  String get routeShortest => 'Shortest';

  @override
  String get routeCalculate => 'Calculate route';

  @override
  String get routeCalculating => 'Calculating...';

  @override
  String get routeChooseFrom => 'Choose starting point';

  @override
  String get routeChooseTo => 'Choose destination';

  @override
  String get routeCancel => 'Cancel';

  @override
  String get routeErrorMissingFields =>
      'Please enter starting point and destination';

  @override
  String get routeErrorFromNotFound =>
      'No result found for the starting address';

  @override
  String get routeErrorToNotFound =>
      'No result found for the destination address';

  @override
  String get routeResultsTitle => 'Available routes';

  @override
  String get routeDistance => 'Distance';

  @override
  String get routeDuration => 'Duration';

  @override
  String get routeNavigation => 'Navigation details';

  @override
  String get routeStartMunicipality => 'Starting municipality';

  @override
  String get routeEnterMunicipality => 'You enter the municipality of';

  @override
  String routeError(Object error) {
    return 'Error: $error';
  }

  @override
  String get radioLanguageIt => 'Italian';

  @override
  String get radioLanguageEn => 'English';

  @override
  String get radioLanguageDe => 'German';

  @override
  String get radioLanguageCountryCh => 'Switzerland';

  @override
  String get radioLanguageEs => 'Spanish';

  @override
  String get radioLanguagePt => 'Portuguese';

  @override
  String get radioLanguageSv => 'Swedish';

  @override
  String get radioLanguageVi => 'Vietnamese';

  @override
  String get radioLanguageCs => 'Czech';

  @override
  String get radioLanguagePl => 'Polish';

  @override
  String get radioLanguageFr => 'French';

  @override
  String get radioLanguageSr => 'Serbian';

  @override
  String get radioLanguageUk => 'Ukrainian';

  @override
  String get radioLanguageHi => 'Hindi';

  @override
  String get radioLanguageLt => 'Lithuanian';

  @override
  String get radioLanguageRu => 'Russian';

  @override
  String get radioLanguageZh => 'Chinese';

  @override
  String get radioCountryOptionIt => 'Italy';

  @override
  String get radioCountryOptionUs => 'United States';

  @override
  String get radioCountryOptionGb => 'United Kingdom';

  @override
  String get radioCountryOptionFr => 'France';

  @override
  String get radioCountryOptionEs => 'Spain';

  @override
  String get radioCountryOptionDe => 'Germany';

  @override
  String get radioCountryOptionCh => 'Switzerland';

  @override
  String get radioCountryOptionAt => 'Austria';

  @override
  String get radioCountryOptionBe => 'Belgium';

  @override
  String get radioCountryOptionNl => 'Netherlands';

  @override
  String get radioCountryOptionPt => 'Portugal';

  @override
  String get radioCountryOptionBr => 'Brazil';

  @override
  String get radioCountryOptionAr => 'Argentina';

  @override
  String get radioCountryOptionMx => 'Mexico';

  @override
  String get radioCountryOptionCa => 'Canada';

  @override
  String get radioCountryOptionAu => 'Australia';

  @override
  String get radioCountryOptionIe => 'Ireland';

  @override
  String get radioCountryOptionSe => 'Sweden';

  @override
  String get radioCountryOptionPl => 'Poland';

  @override
  String get radioCountryOptionJp => 'Japan';

  @override
  String get radioGenreOptionAll => 'All genres';

  @override
  String get radioGenreOptionNews => 'News';

  @override
  String get radioGenreOptionMusic => 'Music';

  @override
  String get radioGenreOptionSport => 'Sport';

  @override
  String get radioGenreOptionTalk => 'Talk and analysis';

  @override
  String get radioGenreOptionPop => 'Pop';

  @override
  String get radioGenreOptionRock => 'Rock';

  @override
  String get radioGenreOptionClassical => 'Classical';

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
  String get radioGenreOptionElectronic => 'Electronic';

  @override
  String get radioGenreOptionLatin => 'Latin';

  @override
  String get radioGenreOptionReggae => 'Reggae';

  @override
  String get radioGenreOptionMetal => 'Metal';

  @override
  String get radioGenreOptionFolk => 'Folk';

  @override
  String get radioGenreOptionReligion => 'Religion';

  @override
  String get radioGenreOptionLocal => 'Local';

  @override
  String get radioGenreOptionCulture => 'Culture';

  @override
  String get radioGenreOptionOldies => '70s / 80s / 90s';

  @override
  String get radioGenreOptionKids => 'Kids';

  @override
  String get radioGenreOptionAmbient => 'Ambient';

  @override
  String get radioCommunityLanguageItalian => 'Italian';

  @override
  String get radioCommunityLanguageEnglish => 'English';

  @override
  String get radioCommunityLanguageSpanish => 'Spanish';

  @override
  String get radioCommunityLanguageFrench => 'French';

  @override
  String get radioCommunityLanguageGerman => 'German';

  @override
  String get radioCommunityLanguagePortuguese => 'Portuguese';

  @override
  String get radioCommunityLanguageSwedish => 'Swedish';

  @override
  String get radioCommunityLanguageVietnamese => 'Vietnamese';

  @override
  String get radioCommunityLanguageCzech => 'Czech';

  @override
  String get radioCommunityLanguagePolish => 'Polish';

  @override
  String get radioCommunityLanguageSerbian => 'Serbian';

  @override
  String get radioCommunityLanguageUkrainian => 'Ukrainian';

  @override
  String get radioCommunityLanguageLithuanian => 'Lithuanian';

  @override
  String get radioCommunityLanguageRussian => 'Russian';

  @override
  String get radioCommunityLanguageChinese => 'Chinese';

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
  String get cinemaTitle => 'Movies in theaters';

  @override
  String get cinemaNoMovies => 'No movies found at the moment.';

  @override
  String get cinemaError => 'Error loading movies.';

  @override
  String cinemaReleased(String date) {
    return 'Released on: $date';
  }

  @override
  String get cinemaOverviewLabel => 'Overview:';

  @override
  String get cinemaUpcomingReleases => 'Upcoming releases';

  @override
  String cinemaWillRelease(String date) {
    return 'Will be released on: $date';
  }

  @override
  String get cinemaOpenTrailer => 'Open trailer';

  @override
  String get concertsTitle => 'Concerts & Events';

  @override
  String get concertsSearchHint => 'Enter a city (e.g. London, New York)';

  @override
  String get concertsSearchLabel => 'Search concerts by city';

  @override
  String get concertsSearchTooltip => 'Search';

  @override
  String get concertsInitialText =>
      'Enter the name of your city above to see upcoming music concerts.';

  @override
  String get concertsEmpty => 'No concerts found in this city.';

  @override
  String get concertsVenue => 'Concert venue:';

  @override
  String get concertsBuyTickets => 'Buy or see details on Ticketmaster';

  @override
  String get podcastPlayedEpisodes => 'Played episodes';

  @override
  String get podcastSelectDate => 'Select date';

  @override
  String get podcastNoDatesAvailable =>
      'No dates available for these episodes.';

  @override
  String get podcastChapters => 'Chapters';

  @override
  String get podcastChaptersUnavailable =>
      'No chapters available for this episode.';

  @override
  String get podcastUnplayed => 'Unplayed episodes';

  @override
  String get routeReadAction => 'Read route';

  @override
  String get routeSaveAction => 'Save to documents';

  @override
  String get routeSaveSuccess => 'Route saved to documents';

  @override
  String get deleteItem => 'Delete';

  @override
  String get audiobookMp3Format => 'Audiobook MP3 (.mp3)';

  @override
  String get audiobookM4bFormat => 'Audiobook M4B (.m4b)';

  @override
  String get exportCompleteTitle => 'Export complete';

  @override
  String get exportCompleteMessage =>
      'The file was created successfully. Do you want to save it in Sonarpad or share it?';

  @override
  String get saveInSonarpad => 'Save in Sonarpad';

  @override
  String get exportSavedInSonarpad => 'File saved in Sonarpad Documents.';

  @override
  String get audiobookExportProgressTitle => 'Creating audiobook';

  @override
  String get audiobookExportPreparing => 'Preparing the audiobook...';

  @override
  String get audiobookExportGeneratingAudio => 'Generating audio';

  @override
  String get audiobookExportConvertingAudio => 'Final audio conversion...';

  @override
  String get audiobookExportFinalizing => 'Finalizing...';

  @override
  String get routeRecentRoutes => 'Recent routes';

  @override
  String get routeRecentRoutesEmpty => 'No recent routes';

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) {
    return 'Navigation details from $from to $to - $date';
  }

  @override
  String get sortPodcastsAlphabetically => 'Sort podcasts alphabetically';

  @override
  String get sortRadioFavoritesAlphabetically =>
      'Sort favorites alphabetically';

  @override
  String get podcastsSortedAlphabetically => 'Podcasts sorted alphabetically.';

  @override
  String get radioFavoritesSortedAlphabetically =>
      'Radio favorites sorted alphabetically.';

  @override
  String get settingsIncludeFootnotesInText => 'Include footnotes in text';

  @override
  String get settingsIncludeFootnotesInTextHint =>
      'For supported EPUB books, show each note immediately after the paragraph that references it.';

  @override
  String get documentFootnoteLabel => 'Footnote';

  @override
  String get settingsMultipleDocumentBookmarks =>
      'Allow multiple bookmarks in documents';

  @override
  String get settingsMultipleDocumentBookmarksHint =>
      'When disabled, each document keeps one bookmark. When enabled, you can save multiple bookmarks in the same document.';

  @override
  String get documentGoToBookmarkAction => 'Go to bookmark';

  @override
  String get documentChooseBookmarkTitle => 'Choose bookmark';

  @override
  String get documentDeleteBookmarkAction => 'Delete bookmark';

  @override
  String get documentKeepBookmarkTitle => 'Which bookmark do you want to keep?';

  @override
  String get documentKeepBookmarkMessage =>
      'Multiple bookmarks are disabled. Choose one bookmark to keep: the others will be deleted.';

  @override
  String documentBookmarkChoiceLabel(int order, int paragraph) {
    return 'Bookmark $order, paragraph $paragraph';
  }

  @override
  String documentBookmarkChoiceLabelWithPreview(
      int order, int paragraph, String preview) {
    return 'Bookmark $order, paragraph $paragraph. $preview';
  }

  @override
  String get settingsVideoLandscapeFullscreen => 'Landscape full-screen video';

  @override
  String get settingsVideoLandscapeFullscreenHint =>
      'When you enable video, it is shown full-screen in landscape orientation. Audio-only radios are unchanged.';

  @override
  String get settingsPodcastCacheTitle => 'Podcast cache';

  @override
  String get settingsPodcastCacheHint =>
      'Clears only temporary podcast files. Subscriptions, history, and imported audio stay intact.';

  @override
  String settingsPodcastCacheSize(String size) {
    return 'Space used: $size';
  }

  @override
  String get clearPodcastCache => 'Clear podcast cache';

  @override
  String get confirmClearPodcastCacheTitle => 'Clear podcast cache?';

  @override
  String get confirmClearPodcastCacheMessage =>
      'Temporary podcast files will be deleted. Subscriptions and episode history will not be removed.';

  @override
  String podcastCacheCleared(String size) {
    return 'Podcast cache cleared: freed $size.';
  }

  @override
  String get podcastCacheEmpty => 'The podcast cache is already empty.';

  @override
  String get pharmacyFeatureTitle =>
      'Medicines, parapharmaceuticals and supplements';

  @override
  String get pharmacyProductsSectionTitle =>
      'Parapharmaceuticals and supplements';

  @override
  String get pharmacyProductsLoadingTitle =>
      'Searching parapharmaceuticals and supplements...';

  @override
  String get pharmacyProductsErrorTitle =>
      'Error searching parapharmaceuticals and supplements';

  @override
  String get pharmacyProductsNoResultsTitle =>
      'No parapharmaceutical or supplement found';

  @override
  String get mediaCutterTitle => 'Cut media file';

  @override
  String get mediaCutterInstruction1 =>
      'Open an audio or video file, play it, and move to the point where you want to cut.';

  @override
  String get mediaCutterInstruction2 =>
      'Pause, press Split, then delete the parts you do not want in the Parts to save section and press Save.';

  @override
  String get mediaCutterOpenFile => 'Open media file';

  @override
  String mediaCutterSelectedFile(String fileName) {
    return 'Selected file: $fileName';
  }

  @override
  String get mediaCutterPosition => 'Cut position';

  @override
  String get mediaCutterPositionHint =>
      'Move forward or backward one second at a time.';

  @override
  String get mediaCutterHideVideoPreview => 'Hide video';

  @override
  String get mediaCutterVideoRotation => 'Video rotation';

  @override
  String get mediaCutterVideoRotationNone => 'No rotation';

  @override
  String get mediaCutterVideoRotationRight => 'Rotate right';

  @override
  String get mediaCutterVideoRotationLeft => 'Rotate left';

  @override
  String get mediaCutterVideoRotationUpsideDown => 'Rotate 180 degrees';

  @override
  String get mediaCutterVideoPreview => 'Video preview';

  @override
  String get mediaCutterSplit => 'Split';

  @override
  String get mediaCutterPartsTitle => 'Parts to save';

  @override
  String get mediaCutterPartsHint =>
      'Tap a part to listen to it. Deleted parts disappear from the list, are skipped during playback, and will not be saved. Effects are applied to the whole part only when the media is saved.';

  @override
  String mediaCutterPartLabel(int index) {
    return 'Part $index';
  }

  @override
  String mediaCutterPartRange(String start, String end) {
    return 'From $start to $end';
  }

  @override
  String get mediaCutterSave => 'Save';

  @override
  String get mediaCutterReady => 'Ready.';

  @override
  String get mediaCutterUnsavedExitTitle => 'Unsaved file';

  @override
  String get mediaCutterUnsavedExitMessage =>
      'The file has not been saved. Are you sure you want to leave?';

  @override
  String get mediaCutterNoFile => 'Open a media file first.';

  @override
  String get mediaCutterInvalidSplitPoint =>
      'Choose a point inside the file, not the beginning or the end.';

  @override
  String get mediaCutterSplitAlreadyExists =>
      'There is already a split at this point.';

  @override
  String mediaCutterSplitAdded(String position) {
    return 'Split added at $position.';
  }

  @override
  String get mediaCutterSaving => 'Saving file...';

  @override
  String mediaCutterSaved(String fileName) {
    return 'File saved: $fileName';
  }

  @override
  String mediaCutterLoadFailed(Object error) {
    return 'Could not open the file: $error';
  }

  @override
  String mediaCutterSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get mediaCutterNoPartsToSave =>
      'Keep at least one part before saving.';

  @override
  String get mediaCutterRestoreDeletedPart => 'Restore deleted part';

  @override
  String get mediaCutterNoDeletedParts =>
      'There are no deleted parts to restore.';

  @override
  String get mediaCutterPartDeleteAction => 'Delete';

  @override
  String get mediaCutterPartTapHint =>
      'Double-tap to preview this part. Use the Edit part, Delete, or Adjust effects actions.';

  @override
  String mediaCutterPartDeleted(String start, String end) {
    return 'Part deleted from $start to $end.';
  }

  @override
  String mediaCutterPartRestored(String start, String end) {
    return 'Part restored from $start to $end.';
  }

  @override
  String get mediaCutterPartEffectsAction => 'Adjust effects';

  @override
  String get mediaCutterPartEditAction => 'Edit part';

  @override
  String get mediaCutterPartEditDescription =>
      'Move the start or end of the part by 1 second, then listen to the edited part.';

  @override
  String mediaCutterPartAdjusted(String start, String end) {
    return 'Part edited from $start to $end.';
  }

  @override
  String get mediaCutterPartEffectsTitle => 'Part effects';

  @override
  String get mediaCutterPartEffectsDescription =>
      'Adjust volume and effect only for this part.';

  @override
  String mediaCutterPartVolumeValue(int percent) {
    return 'Part volume: $percent%';
  }

  @override
  String get mediaCutterPartEffect => 'Audio effect';

  @override
  String get mediaCutterPartEffectNone => 'No effect';

  @override
  String get mediaCutterPartEffectEcho => 'Light echo';

  @override
  String get mediaCutterPartEffectEchoRoom => 'Room echo';

  @override
  String get mediaCutterPartEffectEchoChamber => 'Chamber echo';

  @override
  String get mediaCutterPartEffectEchoCathedral => 'Cathedral echo';

  @override
  String get mediaCutterPartEffectLargeRoom => 'Large room';

  @override
  String get mediaCutterPartEffectSmallRoom => 'Small room';

  @override
  String get mediaCutterPartEffectBathroom => 'Bathroom';

  @override
  String get mediaCutterPartEffectTunnel => 'Tunnel';

  @override
  String get mediaCutterPartEffectRepeatEcho => 'Repeating echo';

  @override
  String get mediaCutterPartEffectCorridor => 'Corridor';

  @override
  String get mediaCutterPartEffectDelay => 'Delay';

  @override
  String get mediaCutterPartEffectReverb => 'Light reverb';

  @override
  String get mediaCutterPartEffectChorus => 'Chorus';

  @override
  String get mediaCutterPartEffectPitchLow => 'Low pitch';

  @override
  String get mediaCutterPartEffectPitchVeryLow => 'Very low pitch';

  @override
  String get mediaCutterPartEffectPitchHigh => 'High pitch';

  @override
  String get mediaCutterPartEffectPitchVeryHigh => 'Very high pitch';

  @override
  String get mediaCutterPartEffectRobot => 'Robot voice';

  @override
  String get mediaCutterPartEffectSuperRobot => 'Super robot';

  @override
  String get mediaCutterPartEffectHelicopter => 'Helicopter';

  @override
  String get mediaCutterPartEffectAlien => 'Alien vibrato';

  @override
  String get mediaCutterPartEffectBrightVoice => 'Clear voice';

  @override
  String get mediaCutterPartEffectDarkVoice => 'Dark voice';

  @override
  String get mediaCutterPartEffectGhost => 'Ghost';

  @override
  String get mediaCutterPartEffectTelephone => 'Telephone';

  @override
  String get mediaCutterPartEffectOldRadio => 'Old radio';

  @override
  String get mediaCutterPartEffectMegaphone => 'Megaphone';

  @override
  String get mediaCutterPartEffectUnderwater => 'Underwater';

  @override
  String get mediaCutterPartEffectMonster => 'Monster';

  @override
  String get mediaCutterPartEffectChipmunk => 'Chipmunk';

  @override
  String get mediaCutterPartEffectDream => 'Dream';

  @override
  String get mediaCutterPartEffectDistortion => 'Distortion';

  @override
  String get mediaCutterPartEffectLoFi => 'Lo-fi';

  @override
  String get mediaCutterPartEffectReverseEcho => 'Reverse echo';

  @override
  String get mediaCutterPartEffectFadeIn => 'Fade in';

  @override
  String get mediaCutterPartEffectFadeOut => 'Fade out';

  @override
  String mediaCutterPartEffectAmountValue(int percent) {
    return 'Effect intensity: $percent%';
  }

  @override
  String get mediaCutterPartPreviewAction => 'Preview';

  @override
  String get mediaCutterPartEffectsSavedOnly =>
      'The preview uses the selected volume. Audio effects are applied when saving.';

  @override
  String mediaCutterPartEffectsApplied(String start, String end) {
    return 'Effects updated for the part from $start to $end.';
  }

  @override
  String mediaCutterPartEffectsSummary(int percent, String effect) {
    return 'Volume $percent%, effect $effect';
  }

  @override
  String get mediaCutterGuidedModeTitle => 'Guided cut';

  @override
  String get mediaCutterGuidedModeDescription =>
      'Suitable for beginners. Select a start point and an end point, listen to the cut, then apply it.';

  @override
  String get mediaCutterAdvancedModeTitle => 'Advanced cut';

  @override
  String get mediaCutterAdvancedModeDescription =>
      'Inspired by popular media editing programs. It lets you split a media file into several parts and remove the parts you do not want.';

  @override
  String get mediaCutterChangeCutMode => 'Change cut type';

  @override
  String get mediaCutterGuidedSetStart => 'Cut start';

  @override
  String get mediaCutterGuidedSetEnd => 'Cut end';

  @override
  String get mediaCutterGuidedApplyCut => 'Apply cut';

  @override
  String get mediaCutterGuidedListenCut => 'Listen to cut';

  @override
  String get mediaCutterGuidedModifyCut => 'Edit cut';

  @override
  String get mediaCutterGuidedMoveStartBackOneSecond =>
      'Move cut start back by 1 second';

  @override
  String get mediaCutterGuidedMoveStartForwardOneSecond =>
      'Move cut start forward by 1 second';

  @override
  String get mediaCutterGuidedMoveEndBackOneSecond =>
      'Move cut end back by 1 second';

  @override
  String get mediaCutterGuidedMoveEndForwardOneSecond =>
      'Move cut end forward by 1 second';

  @override
  String get mediaCutterCutEditPrecisionLabel => 'Cut edit precision';

  @override
  String mediaCutterCutEditPrecisionValue(String value) {
    return 'Cut edit precision: $value';
  }

  @override
  String get mediaCutterCutEditStepOneSecond => '1 second';

  @override
  String get mediaCutterCutEditStepHalfSecond => '0.5 seconds';

  @override
  String get mediaCutterCutEditStepQuarterSecond => '0.25 seconds';

  @override
  String get mediaCutterCutEditStepTenthSecond => '0.10 seconds';

  @override
  String mediaCutterMoveStartBackBy(String value) {
    return 'Move cut start back by $value';
  }

  @override
  String mediaCutterMoveStartForwardBy(String value) {
    return 'Move cut start forward by $value';
  }

  @override
  String mediaCutterMoveEndBackBy(String value) {
    return 'Move cut end back by $value';
  }

  @override
  String mediaCutterMoveEndForwardBy(String value) {
    return 'Move cut end forward by $value';
  }

  @override
  String mediaCutterGuidedCutAdjusted(String start, String end) {
    return 'Cut changed from $start to $end.';
  }

  @override
  String get mediaCutterGuidedNoCut => 'No cut';

  @override
  String get mediaCutterGuidedEffectsAction => 'Adjust file effects';

  @override
  String get mediaCutterGuidedEffectsDescription =>
      'Adjust volume and effects for the whole resulting file.';

  @override
  String get mediaCutterGuidedFileTapHint =>
      'Double tap to play the resulting file. Use Adjust file effects to apply effects to the whole file.';

  @override
  String mediaCutterGuidedStartSet(String start) {
    return 'Cut start set to $start.';
  }

  @override
  String mediaCutterGuidedEndSet(String start, String end) {
    return 'Cut end set to $end. Cut from $start to $end.';
  }

  @override
  String mediaCutterGuidedCutApplied(String start, String end) {
    return 'Cut applied from $start to $end.';
  }

  @override
  String get mediaCutterGuidedNeedStartEnd =>
      'Set the cut start and end first.';

  @override
  String mediaCutterGuidedCutSummary(String start, String end) {
    return 'Cut from $start to $end';
  }

  @override
  String mediaCutterGuidedMultipleCutSummary(int count, String cuts) {
    return '$count cuts: $cuts';
  }

  @override
  String get mediaCutterGuidedPendingCutExitMessage =>
      'You have a guided cut that has not been applied. Do you want to leave without keeping it?';

  @override
  String mediaCutterSplitAddedAnnouncement(int partNumber) {
    return 'Split added. Part $partNumber added.';
  }

  @override
  String get newsAddCommunitySource => 'Add news source to Sonarpad community';

  @override
  String get newsBrowseCommunitySources => 'Community news sources';

  @override
  String get newsAddCommunityInstructions =>
      'Enter the source title and an RSS feed URL or website URL. Sonarpad will use the selected news language and, if you enter a website, will try to find the feed automatically.';

  @override
  String get newsCommunitySourceName => 'Source title';

  @override
  String get newsCommunitySourceUrl => 'RSS feed or website URL';

  @override
  String get newsCommunitySubmit => 'Check and add';

  @override
  String get newsCommunityChecking => 'Checking feed or website...';

  @override
  String get newsCommunityMissingFields =>
      'Enter the title and feed or website URL.';

  @override
  String get newsCommunityAdded =>
      'News source added successfully to the Sonarpad community.';

  @override
  String newsCommunityAddError(Object error) {
    return 'Error while adding the news source: $error';
  }

  @override
  String newsCommunitySelectedLanguage(Object language) {
    return 'Selected language: $language';
  }

  @override
  String get newsCommunitySourcesTitle => 'Community news sources';

  @override
  String get newsCommunitySourcesEmpty =>
      'No community news sources are available for this language.';

  @override
  String newsCommunitySourcesError(Object error) {
    return 'Error loading community news sources: $error';
  }

  @override
  String newsCommunitySourceAddedToLibrary(Object name) {
    return '$name added to your news library.';
  }

  @override
  String newsCommunityAddToLibraryError(Object error) {
    return 'Error while adding to the library: $error';
  }

  @override
  String get newsCommunitySourceTapHint =>
      'Tap to add it to your news library.';
}
