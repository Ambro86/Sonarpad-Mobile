// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => "Sonarpad";

  @override
  String get appLanguage => "App-Sprache";

  @override
  String get settingsTheme => "App-Design";

  @override
  String get settingsThemeSystem => "System";

  @override
  String get settingsThemeLight => "Hell";

  @override
  String get settingsThemeDark => "Dunkel";

  @override
  String get settingsWeatherTemperatureUnit => "Temperatureinheit für Wetter";

  @override
  String get weatherTemperatureCelsius => "Celsius (°C)";

  @override
  String get weatherTemperatureFahrenheit => "Fahrenheit (°F)";

  @override
  String get homeSemanticsLabel => "Sonarpad, Startbildschirm";

  @override
  String get settings => "Einstellungen";

  @override
  String get settingsHint => "Einstellungen öffnen";

  @override
  String get info => "Über Sonarpad";

  @override
  String get infoHint => "App-Informationen öffnen";

  @override
  String get categoryReading => "Lesen und Dokumente";

  @override
  String get categoryMedia => "Medien und Unterhaltung";

  @override
  String get sonarTubeTitle => "SonarTube";

  @override
  String get sonarTubeSearchLabel => "Videos, Kanäle oder Playlists suchen";

  @override
  String get sonarTubeSearchPrompt => "Gib einen Suchbegriff ein, um Videos, Kanäle und Playlists zu finden.";

  @override
  String get sonarTubeNoResults => "Keine Videos gefunden.";

  @override
  String get sonarTubeLoadMore => "Weitere Ergebnisse laden";

  @override
  String get sonarTubeVideo => "Video";

  @override
  String get sonarTubeChannel => "Kanal";

  @override
  String get sonarTubePlaylist => "Playlist";

  @override
  String get sonarTubeLive => "Live";

  @override
  String get sonarTubeResolving => "Video wird vorbereitet…";

  @override
  String get sonarTubeFavorites => "Favoriten";

  @override
  String get sonarTubeVideoFavorites => 'Favorisierte Videos';

  @override
  String get sonarTubeChannelFavorites => 'Favorisierte Kanäle';

  @override
  String get sonarTubeNoVideoFavorites => 'Keine favorisierten Videos oder Playlists.';

  @override
  String get sonarTubeNoChannelFavorites => 'Keine favorisierten Kanäle.';

  @override
  String get sonarTubeAddChannelFavorite => 'Kanal zu Favoriten hinzufügen';

  @override
  String get sonarTubeRemoveChannelFavorite => 'Kanal aus Favoriten entfernen';

  @override
  String get sonarTubeRecentVideos => 'Zuletzt angesehene Videos';

  @override
  String get sonarTubeNoRecentVideos => 'Keine kürzlich angesehenen Videos.';

  @override
  String get sonarTubeConfirmClearHistory => 'Möchtest du den Verlauf der zuletzt angesehenen Videos wirklich löschen?';

  @override
  String get sonarTubeNoFavorites => "Keine favorisierten Videos, Kanäle oder Playlists.";

  @override
  String get sonarTubeAddFavorite => "Zu Favoriten hinzufügen";

  @override
  String get sonarTubeShareVideo => 'Video teilen';

  @override
  String get sonarTubePreviousTrack => 'Zum vorherigen Video';

  @override
  String get sonarTubeNextTrack => 'Zum nächsten Video';

  @override
  String get sonarTubeGoToChannel => 'Zum Kanal';

  @override
  String get sonarTubeViewComments => 'Kommentare anzeigen';

  @override
  String get sonarTubeComments => 'Kommentare';

  @override
  String get sonarTubeNoComments => 'Keine Kommentare verfügbar.';

  @override
  String get sonarTubeLoadMoreComments => 'Weitere Kommentare laden';

  @override
  String get sonarTubeTranscribeVideo => 'Video transkribieren';

  @override
  String get sonarTubeTranscript => 'Transkript';

  @override
  String get sonarTubeNoTranscript => 'Für dieses Video ist kein Transkript verfügbar.';

  @override
  String get sonarTubeCopyTranscript => 'Transkript kopieren';

  @override
  String get sonarTubeTranscriptCopied => 'Transkript wurde in die Zwischenablage kopiert';

  @override
  String get sonarTubeTranscriptSavedInDocuments => 'Das Transkript wurde in Dokumente gespeichert.';

  @override
  String get sonarTubeShareChannel => 'Kanal teilen';

  @override
  String get sonarTubeSharePlaylist => 'Playlist teilen';

  @override
  String get sonarTubeRemoveFavorite => "Aus Favoriten entfernen";

  @override
  String sonarTubeFavoriteAdded(String name) {
    return "${name} wurde zu den Favoriten hinzugefügt.";
  }

  @override
  String sonarTubeFavoriteRemoved(String name) {
    return "${name} wurde aus den Favoriten entfernt.";
  }

  @override
  String get categoryUtilities => "Suche und Werkzeuge";

  @override
  String get voiceDictionaryTitle => "Aussprachewörterbuch";

  @override
  String get voiceDictionaryAdd => "Einträge zum Wörterbuch hinzufügen";

  @override
  String get voiceDictionaryOriginalWord => "Originalwort";

  @override
  String get voiceDictionaryReplacementWord => "Ersatzwort";

  @override
  String get voiceDictionaryMatchCase => "Groß-/Kleinschreibung beachten";

  @override
  String get voiceDictionaryIgnoreCase => "Groß-/Kleinschreibung ignorieren";

  @override
  String get voiceDictionaryEntries => "Wörterbucheinträge";

  @override
  String get voiceDictionaryEmpty => "Keine Wörterbucheinträge.";

  @override
  String get voiceDictionaryRemove => "Ausgewählten Eintrag entfernen";

  @override
  String get voiceDictionaryOriginalRequired => "Gib das Originalwort ein.";

  @override
  String get convertMediaTitle => "Medien konvertieren";

  @override
  String get convertMediaInput => "Zu konvertierende Datei";

  @override
  String get convertMediaOutput => "Speicherordner";

  @override
  String get convertMediaImage => "Bild";

  @override
  String get convertMediaBrowse => "Durchsuchen…";

  @override
  String get convertMediaFormat => "Format";

  @override
  String get convertMediaBitrate => "Bitrate (kbps)";

  @override
  String get convertMediaOggQuality => "Qualität (q)";

  @override
  String get convertMediaFlacCompression => "Kompressionsstufe";

  @override
  String get convertMediaWavBitDepth => "WAV-Bittiefe";

  @override
  String get convertMediaReady => "Bereit.";

  @override
  String get convertMediaRunning => "Konvertierung läuft…";

  @override
  String get convertMediaDone => "Konvertierung abgeschlossen.";

  @override
  String get convertMediaButton => "Medien konvertieren";

  @override
  String get convertMediaNoInput => "Wähle eine Datei zum Konvertieren aus.";

  @override
  String get convertMediaNoOutput => "Wähle einen Speicherordner aus.";

  @override
  String get convertMediaOutputNotWritable => "Auf den ausgewählten Ordner kann nicht direkt zugegriffen werden. Die Datei wird im internen Sonarpad-Ordner gespeichert; nach Abschluss der Konvertierung kannst du sie teilen oder in der Dateien-App speichern.";

  @override
  String get convertMediaNoImage => "Wähle ein Bild für das Video aus.";

  @override
  String get convertMediaSamePath => "Die konvertierte Datei muss sich von der Quelldatei unterscheiden.";

  @override
  String get convertMediaInvalidBitrate => "Ungültige Bitrate. Gib einen Wert zwischen 64 und 320 kbps ein.";

  @override
  String convertMediaFailed(Object error) {
    return "Konvertierung fehlgeschlagen: ${error}";
  }

  @override
  String get donations => "Spenden";

  @override
  String get donationsHint => "Die Entwicklung von Sonarpad unterstützen";

  @override
  String get loading => "Wird geladen";

  @override
  String get ttsVoiceLanguage => "Sprache der TTS-Stimme";

  @override
  String get ttsVoice => "TTS-Stimme";

  @override
  String get saveSettings => "Einstellungen speichern";

  @override
  String get settingsSaved => "Einstellungen gespeichert.";

  @override
  String get settingsSavedTitle => "Einstellungen gespeichert";

  @override
  String get sonarpadCodeValidTitle => "Gültiger Code";

  @override
  String get sonarpadCodeValidMessage => "Der Sonarpad-Code ist korrekt. Die Einstellungen wurden gespeichert.";

  @override
  String get sonarpadCodeInvalidTitle => "Ungültiger Code";

  @override
  String get sonarpadCodeInvalidMessage => "Der Sonarpad-Code ist ungültig. Prüfe, ob du ihn ohne zusätzliche Leerzeichen kopiert hast.";

  @override
  String get infoDescription => "Sonarpad ist eine einfache App mit vielen Funktionen. Sie wurde so entwickelt, dass sie mit VoiceOver für blinde und sehbehinderte Menschen gut zugänglich ist. Du kannst Nachrichten anhören, Podcasts suchen und abonnieren, Wikipedia-Artikel importieren sowie Dokumente zu deiner Bibliothek hinzufügen, speichern und bearbeiten. Sonarpad wird ständig weiterentwickelt, und jede Funktion soll den Alltag erleichtern.";

  @override
  String get infoAuthor => "Autor: Ambrogio Riili";

  @override
  String get donationsIntro => "Sonarpad wurde ursprünglich für persönliche Bedürfnisse entwickelt, ist mit der Zeit jedoch zu einer umfangreicheren App gewachsen. Die Entwicklung erfordert kontinuierliche Arbeit: Funktionen verbessern, Fehler beheben, neue Ideen erproben und jede Funktion sorgfältig testen.\n\nWenn du Sonarpad nützlich findest und die Entwicklung unterstützen möchtest, kannst du spenden.";

  @override
  String get donationsPaypalDesc => "Du kannst über PayPal über folgenden Link spenden:\nhttps://www.paypal.me/ambrogio86\nBitte füge, wenn möglich, „Sonarpad“ als Zahlungsnotiz hinzu.";

  @override
  String get donationsBankDesc => "Du kannst auch per Banküberweisung auf das Konto von Ambrogio Riili spenden.\nIBAN: IT77W0306901020100000064149\nBitte verwende, wenn möglich, einen eindeutigen Verwendungszweck, zum Beispiel „Sonarpad“.";

  @override
  String get donationsThanks => "Wer das Projekt unterstützt, wird in der App und im GitHub-Repository erwähnt, sofern die Person nicht anonym bleiben oder einen Spitznamen verwenden möchte.\n\nVielen Dank an Jiri Holzinger und Paola Vagata für ihren Beitrag.\nFür die tschechische Übersetzung danken wir Radek Žalud und Jiri Holzinger.\nFür die spanische Übersetzung danken wir Arturo Fernandez Rivas.";

  @override
  String get news => "Nachrichten";

  @override
  String get newsHint => "Nachrichten aus Google News RSS öffnen";

  @override
  String get podcasts => "Podcasts";

  @override
  String get podcastsHint => "Podcasts abonnieren sowie Episoden abspielen oder herunterladen";

  @override
  String get importFromWikipedia => "Wikipedia";

  @override
  String get wikipediaHint => "Einen Wikipedia-Artikel suchen und den Text importieren";

  @override
  String get newsCategoryTop => "Top-Meldungen";

  @override
  String get settingsHomeGrouping => "Startsymbole in Kategorien gruppieren";

  @override
  String get settingsHomeGroupingHint => "Wenn deaktiviert, werden die Hauptsymbole als eine einzige Liste ohne Unterordner angezeigt.";

  @override
  String get newsCategoryMyCity => "Meine Stadt";

  @override
  String get newsLocalCityLabel => "Stadt eingeben";

  @override
  String get newsLocalCityHint => "Die für lokale Nachrichten verwendete Stadt ändern";

  @override
  String get update => "Aktualisieren";

  @override
  String get moveUp => "Nach oben verschieben";

  @override
  String get moveDown => "Nach unten verschieben";

  @override
  String get hide => "Löschen";

  @override
  String get moveToPosition => "An Position verschieben";

  @override
  String positionLabel(int position, String targetName) {
    return "Position ${position}: vor ${targetName}";
  }

  @override
  String get positionLabelLast => "Letzte Position";

  @override
  String get restoreHiddenSources => "Gelöschte Quellen wiederherstellen";

  @override
  String get addCustomNewsSource => "Eigene RSS-Quelle hinzufügen";

  @override
  String get newsSourceName => "Name der Quelle oder Website";

  @override
  String get newsSourceUrlOrSearch => "Website-URL, RSS-Feed oder Suchbegriff";

  @override
  String get deleteNewsSource => "Quelle löschen";

  @override
  String get importRssSourcesFromOpml => "RSS-Quellen aus OPML importieren";

  @override
  String get exportRssSourcesToOpml => "RSS-Quellen als OPML exportieren";

  @override
  String rssImportComplete(int count) {
    return "Importierte RSS-Quellen: ${count}";
  }

  @override
  String rssImportError(Object error) {
    return "Fehler beim RSS-Import: ${error}";
  }

  @override
  String get rssExportComplete => "RSS-Quellen exportiert";

  @override
  String rssExportError(Object error) {
    return "Fehler beim RSS-Export: ${error}";
  }

  @override
  String get articleTextSemantics => "Artikeltext";

  @override
  String get newsLanguage => "Nachrichtensprache";

  @override
  String get loadingNews => "Nachrichten werden geladen";

  @override
  String error(Object error) {
    return "Fehler: ${error}";
  }

  @override
  String get noNewsFound => "Keine Nachrichten gefunden";

  @override
  String get loadingArticle => "Artikel wird geladen";

  @override
  String get noFullArticleFound => "Der vollständige Artikel ist nicht verfügbar. Die Zusammenfassung aus dem Feed wird angezeigt.";

  @override
  String get italian => "Italienisch";

  @override
  String get english => "Englisch";

  @override
  String get french => "Französisch";

  @override
  String get spanish => "Spanisch";

  @override
  String get german => 'Deutsch';

  @override
  String get newsSource => "Nachrichtenquelle";

  @override
  String get article => "Artikel";

  @override
  String get articlePreview => "Artikelvorschau";

  @override
  String get readFullArticle => "Vollständigen Artikel lesen";

  @override
  String get extractingReaderArticleText => "Text wird im Lesemodus extrahiert…";

  @override
  String get extractingVisibleArticleText => "Sichtbarer Text der Seite wird extrahiert…";

  @override
  String source(String source) {
    return "Quelle: ${source}";
  }

  @override
  String get readyStatus => "Bereit.";

  @override
  String get preparingEdgeTts => "Edge-TTS-Lesen in Blöcken wird vorbereitet…";

  @override
  String get noTextToRead => "Kein Text zum Lesen vorhanden.";

  @override
  String chunkCreated(int index, int total) {
    return "Block ${index} von ${total} erstellt. Lesen läuft…";
  }

  @override
  String playingChunk(int index, int total, int size) {
    return "Block ${index} von ${total} wird abgespielt (${size} Byte)…";
  }

  @override
  String readingFinished(int readyChunks, int totalChunks, String libraryPath) {
    return "Lesen beendet. Erstellte Blöcke: ${readyChunks}/${totalChunks}. Bibliothek: ${libraryPath}";
  }

  @override
  String get libraryNotSpecified => "nicht angegeben";

  @override
  String get readingStopped => "Lesen beendet.";

  @override
  String edgeTtsError(Object error) {
    return "Edge-TTS-Fehler: ${error}";
  }

  @override
  String audioChunksReady(int readyChunks, int totalChunks) {
    return "Audioblöcke bereit: ${readyChunks} / ${totalChunks}";
  }

  @override
  String get readingInProgress => "Lesen läuft…";

  @override
  String get readWithEdgeTts => "Lesen starten";

  @override
  String get stopReading => "Lesen beenden";

  @override
  String get startReading => "Lesen starten";

  @override
  String get resumeReading => "Lesen fortsetzen";

  @override
  String get pauseReading => "Lesen pausieren";

  @override
  String get openOriginalArticle => "Originalartikel öffnen";

  @override
  String get searchPodcasts => "Podcasts suchen";

  @override
  String get podcastName => "Podcastname";

  @override
  String get podcastSearchHint => "Beispiel: Technologie, Geschichte, Podcastname…";

  @override
  String get searchCountry => "Land suchen";

  @override
  String get browsePodcastCountries => "Nach Land durchsuchen";

  @override
  String get podcastCountries => "Podcast-Länder";

  @override
  String get podcastCategory => "Podcast-Kategorie";

  @override
  String get browsePodcastCategories => "Kategorien durchsuchen";

  @override
  String get selectedPodcastCategory => "Ausgewählte Kategorie";

  @override
  String get selectedRecently => "zuletzt ausgewählt";

  @override
  String get podcastCategories => "Podcast-Kategorien";

  @override
  String get countryItaly => "Italien";

  @override
  String get countryUnitedStatesEnglish => "Vereinigte Staaten / Englisch";

  @override
  String get countryUnitedKingdom => "Vereinigtes Königreich";

  @override
  String get countrySpain => "Spanien";

  @override
  String get countryFrance => "Frankreich";

  @override
  String get searchInProgress => "Suche läuft…";

  @override
  String get newsReadArticles => "Gelesene Artikel";

  @override
  String get weatherRecentCities => "Zuletzt verwendete Städte";

  @override
  String podcastResultsFound(int count) {
    return "${count} Podcasts gefunden";
  }

  @override
  String podcastSearchError(Object error) {
    return "Fehler bei der Podcast-Suche: ${error}";
  }

  @override
  String subscribedTo(String title) {
    return "${title} abonniert";
  }

  @override
  String subscriptionError(Object error) {
    return "Fehler beim Abonnieren: ${error}";
  }

  @override
  String podcastSubscriptionError(Object error) {
    return "Podcast-Abonnementfehler: ${error}";
  }

  @override
  String get searchResults => "Suchergebnisse";

  @override
  String get podcastInfo => "Podcast-Informationen";

  @override
  String get subscribe => "Abonnieren";

  @override
  String get openPodcast => "Podcast öffnen";

  @override
  String get viewEpisodes => "Episoden anzeigen";

  @override
  String get podcastAuthor => "Autor";

  @override
  String get noPodcastDescription => "Keine Beschreibung verfügbar.";

  @override
  String get noPodcastResults => "Keine Podcasts gefunden.";

  @override
  String get loadingPodcastInfo => "Podcast-Informationen werden geladen";

  @override
  String get podcastArtwork => "Podcast-Cover";

  @override
  String get addFeedUrlManually => "RSS-Feed-URL manuell hinzufügen";

  @override
  String get podcastFeedUrl => "Podcast-RSS-Feed-URL";

  @override
  String get subscribeFromUrl => "Über URL abonnieren";

  @override
  String get subscribedPodcasts => "Abonnierte Podcasts";

  @override
  String get noSubscribedPodcasts => "Keine Podcasts abonniert. Suche nach einem Podcast und tippe auf ein Ergebnis, um ihn zu abonnieren.";

  @override
  String get localAudioFiles => "Lokale Audiodateien";

  @override
  String get noLocalAudioFiles => "Keine lokalen Audiodateien gefunden.";

  @override
  String get importAudioFromITunes => "Lokale Audiodateien importieren";

  @override
  String localAudioFilesFound(int count) {
    return "Lokale Audiodateien gefunden: ${count}";
  }

  @override
  String get importPodcastsFromFile => "Podcasts aus Datei importieren";

  @override
  String get exportPodcastsToFile => "Podcasts als OPML-Datei exportieren";

  @override
  String podcastImportComplete(int count) {
    return "Importierte Podcasts: ${count}";
  }

  @override
  String podcastImportError(Object error) {
    return "Fehler beim Podcast-Import: ${error}";
  }

  @override
  String get podcastInvalidOpmlFile => "Ungültige Datei. Wähle eine OPML- oder XML-Datei aus.";

  @override
  String get podcastExportComplete => "Podcasts exportiert";

  @override
  String podcastExportError(Object error) {
    return "Fehler beim Podcast-Export: ${error}";
  }

  @override
  String get loadingEpisodes => "Episoden werden geladen";

  @override
  String get noAudioEpisodesFound => "Keine Audioepisoden im Feed gefunden.";

  @override
  String get episodes => "Episoden";

  @override
  String get episodeActions => "Episodenaktionen";

  @override
  String downloaded(String path) {
    return "Heruntergeladen: ${path}";
  }

  @override
  String episodeError(Object error) {
    return "Episodenfehler: ${error}";
  }

  @override
  String get play => "Abspielen";

  @override
  String get pause => "Pause";

  @override
  String get rewind15s => "15 Sekunden zurück";

  @override
  String get forward15s => "15 Sekunden vor";

  @override
  String get stop => "Stopp";

  @override
  String get back => "Zurück";

  @override
  String get episodePlayer => "Episodenplayer";

  @override
  String nowPlayingTitle(String title) {
    return "Wiedergabe: ${title}";
  }

  @override
  String get loadingEpisodeAudio => "Episodenaudio wird geladen";

  @override
  String get playbackPosition => "Position";

  @override
  String playbackPositionValue(String position, String duration) {
    return "${position} von ${duration}";
  }

  @override
  String get adjustVolume => "Lautstärke anpassen";

  @override
  String volumeValue(int percentage) {
    return "Lautstärke: ${percentage}%";
  }

  @override
  String get download => "Herunterladen";

  @override
  String get searchWikipedia => "In Wikipedia suchen";

  @override
  String get wikipediaLanguage => "Wikipedia-Sprache";

  @override
  String get search => "Suchen";

  @override
  String get wikipediaSearch => "Wikipedia-Suche";

  @override
  String get wikipediaImporting => "Wikipedia-Import";

  @override
  String get noWikipediaResults => "Keine Wikipedia-Ergebnisse gefunden";

  @override
  String get wikipediaImportMode => "Importmodus";

  @override
  String get wikipediaImportWholeArticle => "Gesamter Artikel";

  @override
  String get documents => "Dokumente";

  @override
  String get documentsHint => "Dokumentbibliothek öffnen";

  @override
  String get documentLibrary => "Dokumentbibliothek";

  @override
  String get addToLibrary => "Zur Bibliothek hinzufügen";

  @override
  String get documentImportSelectionMode => "Möchtest du ein einzelnes Dokument oder mehrere Dokumente auswählen?";

  @override
  String get documentImportSingle => "Ein Dokument";

  @override
  String get documentImportMultiple => "Mehrere Dokumente";

  @override
  String get noDocuments => "Keine Dokumente. Füge eine Datei hinzu.";

  @override
  String get noDocumentsInLibrary => "Keine Dokumente in der Bibliothek.";

  @override
  String get documentAdded => "Dokument hinzugefügt";

  @override
  String get documentsAdded => "Dokumente hinzugefügt";

  @override
  String get importDocumentsFromITunes => "Dokumente aus iTunes / Apple Devices importieren";

  @override
  String sharedDocumentsImportComplete(int count) {
    return "Aus iTunes / Apple Devices importierte Dokumente: ${count}";
  }

  @override
  String libraryLoadError(Object error) {
    return "Fehler beim Laden der Bibliothek: ${error}";
  }

  @override
  String fileOpenError(Object error) {
    return "Fehler beim Öffnen der Datei: ${error}";
  }

  @override
  String get filePathUnavailable => "Dateipfad nicht verfügbar.";

  @override
  String fileInaccessible(String name) {
    return "Datei nicht zugänglich: ${name}";
  }

  @override
  String documentAddError(Object error) {
    return "Fehler beim Hinzufügen des Dokuments: ${error}";
  }

  @override
  String documentRemoveError(Object error) {
    return "Fehler beim Entfernen: ${error}";
  }

  @override
  String get noExportableTextFound => "Kein exportierbarer Text gefunden.";

  @override
  String get modifiedDocumentNoExportableText => "Das geänderte Dokument enthält keinen exportierbaren Text.";

  @override
  String get documentRemoved => "Dokument entfernt";

  @override
  String get folderRemoved => "Ordner entfernt";

  @override
  String get removeFolder => "Ordner entfernen";

  @override
  String get removeDocument => "Dokument entfernen";

  @override
  String get writeNewDocument => "Neues Dokument schreiben";

  @override
  String get addDocumentToLibraryHint => "Dokument zur Bibliothek hinzufügen. Dateien auf dem Gerät durchsuchen und hinzufügen.";

  @override
  String get documentTypeLabel => "Dokument";

  @override
  String get documentPosition => "Dokumentposition";

  @override
  String get documentRemainingLessThanOneMinute => "weniger als 1 Minute verbleibend";

  @override
  String documentRemainingMinutes(int minutes) {
    return "noch etwa ${minutes} Minuten";
  }

  @override
  String documentRemainingHours(int hours) {
    return "noch etwa ${hours} Stunden";
  }

  @override
  String documentRemainingHoursMinutes(int hours, int minutes) {
    return "noch etwa ${hours} Stunden und ${minutes} Minuten";
  }

  @override
  String get folderTypeLabel => "Ordner";

  @override
  String documentAddedOn(String date) {
    return "hinzugefügt am ${date}";
  }

  @override
  String documentTypeDescription(String extension) {
    return "Typ ${extension}";
  }

  @override
  String get openFolderHint => "Doppeltippen, um den Ordner zu öffnen";

  @override
  String get openDocumentHint => "Doppeltippen, um das Dokument zu öffnen und zu lesen";

  @override
  String removeItem(String name) {
    return "${name} entfernen";
  }

  @override
  String get removePodcast => "Podcast entfernen";

  @override
  String get podcastRemoved => "Podcast entfernt";

  @override
  String get documentPickerError => "Fehler beim Öffnen der Datei";

  @override
  String get readDocument => "Dokument lesen";

  @override
  String get documentReaderTitle => "Dokumentleser";

  @override
  String get documentReaderEditHint => "Tippe auf einen Absatz, um ihn zu bearbeiten. Streiche nach oben oder unten, um ein Lesezeichen hinzuzufügen.";

  @override
  String get documentParagraphSelectionStartAction => "Absatzauswahl starten";

  @override
  String get documentParagraphSelectionTapHint => "Auswahlmodus ist aktiv. Doppeltippen, um diesen Absatz aus- oder abzuwählen.";

  @override
  String get documentParagraphSelectionStarted => "Auswahlmodus ist aktiv. Absatz ausgewählt. Doppeltippe auf weitere Absätze, um sie auszuwählen.";

  @override
  String documentParagraphSelectedAnnouncement(int count) {
    return "Absatz ausgewählt. Insgesamt ausgewählt: ${count}.";
  }

  @override
  String documentParagraphDeselectedAnnouncement(int count) {
    return "Absatz abgewählt. Insgesamt ausgewählt: ${count}.";
  }

  @override
  String documentParagraphSelectionCount(int count) {
    return "Ausgewählt: ${count}";
  }

  @override
  String get documentDeleteSelectedParagraphs => "Ausgewählte Absätze löschen";

  @override
  String documentDeleteSelectedParagraphsConfirmation(int count) {
    return "Ausgewählte Absätze löschen? Insgesamt: ${count}.";
  }

  @override
  String documentSelectedParagraphsDeleted(int count) {
    return "Gelöschte Absätze: ${count}.";
  }

  @override
  String get documentExitParagraphSelection => "Absatzauswahl beenden";

  @override
  String get documentParagraphSelectionExited => "Auswahlmodus deaktiviert.";

  @override
  String get documentBookmarkHintSet => "Nach oben oder unten streichen, um ein Lesezeichen zu setzen.";

  @override
  String get documentEditParagraphActionHint => "Doppeltippen, um diesen Absatz zu bearbeiten. ";

  @override
  String get documentBookmarkHintReplace => "Nach oben oder unten streichen, um das vorhandene Lesezeichen zu entfernen oder durch diesen Absatz zu ersetzen.";

  @override
  String get documentSetBookmarkAction => "Neues Lesezeichen hinzufügen";

  @override
  String get documentRemoveBookmarkAction => "Lesezeichen entfernen";

  @override
  String get documentReplaceBookmarkAction => "Lesezeichen entfernen und neues hinzufügen";

  @override
  String get searchInDocument => "Im Dokument suchen";

  @override
  String get documentIndex => "Inhaltsverzeichnis";

  @override
  String get documentSearchFieldLabel => "Text suchen";

  @override
  String get documentSearchFieldHint => "Zu suchendes Wort oder Phrase";

  @override
  String get documentSearchEmptyQuery => "Gib einen Suchtext ein.";

  @override
  String get documentSearchResultsTitle => "Suchergebnisse im Dokument";

  @override
  String noDocumentSearchResults(String query) {
    return "Keine Ergebnisse für ${query} gefunden.";
  }

  @override
  String documentSearchResultParagraph(int number) {
    return "Absatz ${number}";
  }

  @override
  String get edit => "Bearbeiten";

  @override
  String get save => "Speichern";

  @override
  String get cancel => "Abbrechen";

  @override
  String get settingsReadingEngine => "Lese-Engine";

  @override
  String get settingsEdgeTtsQuality => "Edge TTS (hochwertig, online)";

  @override
  String get settingsSystemVoices => "Systemstimmen (VoiceOver / Google)";

  @override
  String get settingsNoSystemVoices => "Keine Systemstimmen verfügbar.";

  @override
  String get settingsDefaultVoiceHint => "Standardstimme";

  @override
  String get settingsDefaultVoice => "Standard";

  @override
  String get settingsVoiceSpeed => "Geschwindigkeit: ";

  @override
  String get settingsVoicePitch => "Tonhöhe: ";

  @override
  String get settingsVoiceSpeedLabel => "Lesegeschwindigkeit";

  @override
  String get settingsVoicePitchLabel => "Tonhöhe";

  @override
  String get settingsTestVoice => "Stimme testen";

  @override
  String get settingsTestingVoice => "Wiedergabe…";

  @override
  String get settingsVoiceTestText => "Dies ist ein Test der ausgewählten Stimme.";

  @override
  String settingsVoiceTestError(Object error) {
    return "Fehler beim Stimmtest: ${error}";
  }

  @override
  String settingsVoiceSaveError(Object error) {
    return "Fehler beim Speichern der TTS-Stimme: ${error}";
  }

  @override
  String get settingsUnsavedTitle => "Nicht gespeicherte Änderungen";

  @override
  String get settingsUnsavedMessage => "Möchtest du deine Änderungen speichern, bevor du die Einstellungen verlässt?";

  @override
  String get settingsExitWithoutSaving => "Ohne Speichern verlassen";

  @override
  String get settingsSystemLanguage => "Systemsprache";

  @override
  String get settingsSystemVoice => "Systemstimme";

  @override
  String get settingsAutoBookmark => "Automatisch fortsetzen";

  @override
  String get settingsAutoBookmarkHint => "Dokumente, Podcasts und Medien an der zuletzt verlassenen Stelle fortsetzen.";

  @override
  String get settingsDocumentSliderStep => "Schrittweite des Dokumentreglers";

  @override
  String get settingsDocumentSliderStepHint => "Legt fest, wie weit sich der Regler für die Dokumentposition beim Streichen nach oben oder unten bewegt.";

  @override
  String get settingsReadingSleepTimer => "Schlaftimer beim Lesen";

  @override
  String get settingsReadingSleepTimerOff => "Aus";

  @override
  String settingsReadingSleepTimerMinutes(int minutes) {
    return "${minutes} Minuten";
  }

  @override
  String get settingsReadingSleepTimerHint => "Beendet das Lesen des aktuellen Dokuments nach der gewählten Zeit automatisch und speichert die Position. Der Countdown beginnt bei jedem Start des Lesens eines Dokuments neu.";

  @override
  String get documentReadingSleepTimerStopped => "Schlaftimer: Lesen beendet und Position gespeichert.";

  @override
  String get settingsSeekStep => "Schrittweite für Zurück-/Vorspulen bei Medien";

  @override
  String get aiChatIntro => "Ich bin Sonarpad AI. Wie kann ich dir helfen?";

  @override
  String get meteoTitle => "Wetter";

  @override
  String get weatherCity => "Stadt";

  @override
  String get weatherCityHint => "Beispiel: Berlin";

  @override
  String get weatherCityNotFound => "Stadt nicht gefunden";

  @override
  String get weatherSearchError => "Fehler bei der Suche";

  @override
  String get weatherToday => "Heute";

  @override
  String get weatherCurrentSituation => "Aktuelle Lage";

  @override
  String get weatherTomorrow => "Morgen";

  @override
  String get weatherChooseDay => "Tag auswählen";


  @override
  String get tvRecordingChooseDay => weatherChooseDay;
  @override
  String get weatherCurrentTemperature => "Aktuelle Temperatur";

  @override
  String get weatherMaxTemperature => "Höchsttemperatur";

  @override
  String get weatherMinTemperature => "Tiefsttemperatur";

  @override
  String get weatherPrecipitation => "Niederschlag";

  @override
  String get weatherPrecipitationProbability => "Niederschlagswahrscheinlichkeit";

  @override
  String get weatherWind => "Wind";

  @override
  String get weatherRelativeHumidity => "Relative Luftfeuchtigkeit";

  @override
  String get settingsSecretCode => "Sonarpad-Code für zusätzliche Funktionen";

  @override
  String get settingsRequestCode => "Code beim Autor anfordern";

  @override
  String get settingsPasteCode => "Code einfügen";

  @override
  String get settingsCancel => "Abbrechen";

  @override
  String get settingsSend => "Senden";

  @override
  String get settingsFillFieldsCode => "Fülle alle Felder aus, um den Code anzufordern.";

  @override
  String get settingsName => "Vorname";

  @override
  String get settingsSurname => "Nachname";

  @override
  String get settingsEmail => "E-Mail";

  @override
  String get settingsOperatingSystem => "Betriebssystem";

  @override
  String settingsCodeRequestBody(
    String name,
    String surname,
    String email,
    String os,
  ) {
    return "Vorname: ${name}; Nachname: ${surname}; E-Mail: ${email}; Betriebssystem: ${os}";
  }

  @override
  String get settingsNameOptional => "Name (optional)";

  @override
  String get settingsMessageOptional => "Nachricht (optional)";

  @override
  String get settingsVerifyCodeAndSave => "Code wird überprüft und gespeichert…";

  @override
  String get settingsViewSysLog => "Systemprotokoll anzeigen";

  @override
  String settingsMailOpenError(Object error) {
    return "Fehler beim Öffnen der E-Mail: ${error}";
  }

  @override
  String get ok => "OK";

  @override
  String get yes => "Ja";

  @override
  String get no => "Nein";

  @override
  String get invia => "Senden";

  @override
  String get saveArticle => "Artikel speichern";

  @override
  String get shareArticle => "Artikel teilen";

  @override
  String get articleSavedSuccess => "Artikel in Dokumente gespeichert";

  @override
  String get annulla => "Abbrechen";

  @override
  String get compilaTuttiICampiPerRichiedereIlCodice => "Fülle alle Felder aus, um den Code anzufordern.";

  @override
  String get selectFolder => "Ordner auswählen";

  @override
  String get exportDocument => "Dokument exportieren";

  @override
  String get exportFormatPrompt => "In welchem Format möchtest du das Dokument exportieren?";

  @override
  String get textFormat => "Text (.txt)";

  @override
  String get pdfFormat => "PDF (.pdf)";

  @override
  String get docxFormat => "DOCX (.docx)";

  @override
  String get epubFormat => "EPUB (.epub)";

  @override
  String get exportError => "Exportfehler";

  @override
  String get newFolder => "Neuer Ordner";

  @override
  String get folderNameHint => "Ordnername";

  @override
  String get create => "Erstellen";

  @override
  String get createNewFolder => "Neuen Ordner erstellen";

  @override
  String get importExternalSources => "Aus externen Quellen importieren";

  @override
  String get importExternalSourcesTitle => "Externe Quellen";

  @override
  String get importFromDropbox => "Dokumente aus Dropbox importieren";

  @override
  String get importFromProjectGutenberg => "Aus Project Gutenberg importieren";

  @override
  String get projectGutenbergImportUnavailable => "Der Import aus Project Gutenberg ist noch nicht verfügbar.";

  @override
  String get importFromInternetArchive => "Aus Internet Archive importieren";

  @override
  String get internetArchiveTitle => "Internet Archive";

  @override
  String get internetArchiveSearchLabel => "Audio suchen";

  @override
  String get internetArchiveSourceLabel => "Quelle";

  @override
  String get internetArchiveOldTimeRadio => "Historische Radiosendungen";

  @override
  String get internetArchiveSpeeches => "Historische Reden";

  @override
  String get internetArchiveLiveMusic => "Live Music Archive";

  @override
  String get internetArchiveNoItemsFound => "Keine Audioinhalte gefunden.";

  @override
  String get saveAudioInDocuments => "Audio in Dokumente speichern";

  @override
  String get audioSavedInDocuments => "Audio in Dokumente gespeichert.";

  @override
  String get noAudioTracksAvailable => "Keine Audiospuren verfügbar.";

  @override
  String get importFromLibriVox => "Aus LibriVox importieren";

  @override
  String get gutenbergSearchLabel => "Buch oder Autor suchen";

  @override
  String get sourceLanguageLabel => "Sprache";

  @override
  String get noGutenbergBooksFound => "Keine Bücher gefunden.";

  @override
  String get loadMore => "Mehr laden";

  @override
  String sourceLanguageValue(String language) {
    return "Sprache: ${language}";
  }

  @override
  String get gutenbergImportAndRead => "Importieren und lesen";

  @override
  String get gutenbergImporting => "Wird importiert…";

  @override
  String get librivoxSearchLabel => "Hörbuch suchen";

  @override
  String get noLibrivoxAudiobooksFound => "Keine Hörbücher gefunden.";

  @override
  String get librivoxAudiobookSaved => "Hörbuch in Dokumente gespeichert.";

  @override
  String get librivoxSaveAudiobook => "Hörbuch in Dokumente speichern";

  @override
  String get librivoxSaving => "Wird gespeichert…";

  @override
  String get librivoxNoAudioTracks => "Keine Audiospuren verfügbar.";

  @override
  String get librivoxNotTextExportable => "LibriVox-Hörbücher können nicht als Text exportiert werden.";

  @override
  String sourceDurationValue(String duration) {
    return "Dauer: ${duration}";
  }

  @override
  String get importFromPoetryDb => "Aus PoetryDB importieren";

  @override
  String get poetryDbSearchLabel => "Gedicht suchen";

  @override
  String get poetryDbSearchBy => "Suchen nach";

  @override
  String get poetryDbSearchByTitle => "Titel";

  @override
  String get poetryDbSearchByAuthor => "Autor";

  @override
  String get poetryDbNoPoemsFound => "Keine Gedichte gefunden.";

  @override
  String poetryDbLineCount(int count) {
    return "${count} Zeilen";
  }

  @override
  String get moveDocument => "Dokument verschieben";

  @override
  String get documentMoved => "Erfolgreich verschoben";

  @override
  String get outOfFolder => "Aus dem Ordner heraus";

  @override
  String get moveToAnotherFolder => "In einen anderen Ordner verschieben…";

  @override
  String get ttsError => "TTS-Fehler";

  @override
  String get editParagraph => "Absatz bearbeiten";

  @override
  String get editParagraphTextField => "Textfeld zum Bearbeiten des Absatzes";

  @override
  String get editParagraphHint => "Absatztext bearbeiten";

  @override
  String get applyAndSave => "Übernehmen und speichern";

  @override
  String get textEditedAndSaved => "Text im aktuellen Dokument bearbeitet und gespeichert.";

  @override
  String get saveError => "Fehler beim Speichern";

  @override
  String get docSavedInLibrary => "Dokument in der Bibliothek gespeichert";

  @override
  String get saveInLibrary => "In Bibliothek speichern";

  @override
  String get copyToClipboard => "In die Zwischenablage kopieren";

  @override
  String get textCopiedToClipboard => "Text in die Zwischenablage kopiert";

  @override
  String get documentTextLabel => "Dokumenttext";

  @override
  String get modifiedInSonarpad => "In Sonarpad geändert";

  @override
  String get noTextAvailableForDocument => "Für dieses Dokument ist kein Text verfügbar.";

  @override
  String bookmarkSet(int index) {
    return "Lesezeichen bei Absatz ${index} gesetzt.";
  }

  @override
  String get bookmarkRemoved => "Lesezeichen entfernt.";

  @override
  String get docEmpty => "Dokument ist leer";

  @override
  String get docSavedSuccessfully => "Dokument erfolgreich gespeichert!";

  @override
  String get writeDocument => "Dokument schreiben";

  @override
  String get documentTitleOptional => "Titel (optional)";

  @override
  String get documentTitleHint => "Beispiel: Einkaufsnotizen";

  @override
  String get documentTextField => "Dokumenttext";

  @override
  String get documentTextHint => "Hier mit dem Schreiben beginnen…";

  @override
  String get newDocumentDefaultName => "Neues_Dokument";

  @override
  String get saving => "Wird gespeichert…";

  @override
  String get saveDocument => "Dokument speichern";

  @override
  String get addRssSource => "RSS-Quelle hinzufügen";

  @override
  String get add => "Hinzufügen";

  @override
  String get errorPrefix => "Fehler";

  @override
  String versionBuild(String version, String buildNumber) {
    return "Version ${version} (Build ${buildNumber})";
  }

  @override
  String get whatIsNew => "Neuigkeiten";

  @override
  String whatIsNewInVersion(String version) {
    return "Neu in Version ${version}";
  }

  @override
  String changelogLoadError(Object error) {
    return "Fehler beim Laden der Neuigkeiten: ${error}";
  }

  @override
  String get visitSonarpadSite => "Sonarpad-Website besuchen";

  @override
  String visitSonarpadSiteWithUrl(String url) {
    return "Sonarpad-Website besuchen: ${url}";
  }

  @override
  String get nowPlaying => "Wiedergabe";

  @override
  String get fileImported => "Datei importiert";

  @override
  String importZipError(Object error) {
    return "Fehler beim ZIP-Import: ${error}";
  }

  @override
  String get dropboxLoginPrompt => "Melde dich bei Dropbox an, um deine Dokumente zu importieren.";

  @override
  String get loginToDropbox => "Bei Dropbox anmelden";

  @override
  String get logoutFromDropbox => "Abmelden";

  @override
  String get dropboxLoginFailed => "Anmeldung fehlgeschlagen oder abgebrochen";

  @override
  String dropboxLoadFolderError(Object error) {
    return "Fehler beim Laden des Ordners: ${error}";
  }

  @override
  String dropboxImportError(Object error) {
    return "Importfehler: ${error}";
  }

  @override
  String get retry => "Erneut versuchen";

  @override
  String get goBack => "Zurück";

  @override
  String get noSupportedFilesInFolder => "Keine unterstützten Dateien in diesem Ordner.";

  @override
  String get articleNotFound => "Artikel nicht gefunden.";

  @override
  String get errorOpening => "Fehler beim Öffnen";

  @override
  String get recentArticles => "Letzte Artikel";

  @override
  String get clearHistory => "Verlauf löschen";

  @override
  String get confirmClearHistory => "Möchtest du wirklich alle letzten Suchanfragen löschen?";

  @override
  String get clear => "Löschen";

  @override
  String get noRecentSearches => "Keine letzten Suchanfragen.";

  @override
  String get logCopiedToClipboard => "Protokoll in die Zwischenablage kopiert";

  @override
  String get logCleared => "Protokoll gelöscht";

  @override
  String get parafarmacoDetailReadyAnnouncement => "Produktdatenblatt geladen. Streiche nach rechts, um die Bereiche auszuwählen.";

  @override
  String get systemLog => "Systemprotokoll";

  @override
  String get clearSystemLog => "Protokoll löschen";

  @override
  String get copySystemLog => "Protokoll kopieren";

  @override
  String get donateWithPaypal => "Mit PayPal spenden";

  @override
  String get bankTransferTitle => "Banküberweisung";

  @override
  String get enableVideo => "Video aktivieren";

  @override
  String get calendar => "Kalender";

  @override
  String get calendarHint => "Kalender, Feiertage, Heilige des Tages und Erinnerungen anzeigen";

  @override
  String get saintOfTheDay => "Heilige/r des Tages";

  @override
  String get quoteOfTheDay => "Zitat des Tages";

  @override
  String get reminders => "Erinnerungen";

  @override
  String get addReminder => "Erinnerung hinzufügen";

  @override
  String get removeReminder => "Erinnerung entfernen";

  @override
  String get noReminders => "Keine Erinnerungen";

  @override
  String get writeReminder => "Schreibe deine Erinnerung hier…";

  @override
  String get saveReminder => "Speichern";

  @override
  String get cancelReminder => "Abbrechen";

  @override
  String get backToToday => "Zurück zu heute";

  @override
  String get calendarToday => "Heute";

  @override
  String get calendarTomorrow => "Morgen";

  @override
  String get calendarYesterday => "Gestern";

  @override
  String get share => "Teilen";

  @override
  String get shareCalendarDayOptions => "Optionen zum Teilen";

  @override
  String get shareCalendarDayOnly => "Nur den Tag teilen";

  @override
  String get shareCalendarDayWithReminder => "Tag und Erinnerung teilen";

  @override
  String get listenToAll => "Alles anhören";

  @override
  String reminderSaved(int count) {
    return "${count} Erinnerungen";
  }

  @override
  String get audiodescriptionTitle => "Audiodeskriptionen";

  @override
  String get audiodescriptionRecent => "Zuletzt";

  @override
  String get audiodescriptionAll => "Alle Audiodeskriptionen";

  @override
  String get audiodescriptionFilm => "Filme";

  @override
  String get audiodescriptionSearch => "Suchen…";

  @override
  String get audiodescriptionLoading => "Wird geladen…";

  @override
  String get audiodescriptionError => "Fehler beim Laden des Katalogs";

  @override
  String get audiodescriptionEmpty => "Keine Einträge gefunden";

  @override
  String get radio => "Radio";

  @override
  String get radioHint => "Radiosender suchen, Streams hören und Favoriten verwalten";

  @override
  String get radioTitle => "Radiosender aus aller Welt";

  @override
  String get radioFavoritesButton => "Favorisierte Radiosender";

  @override
  String get radioNoFavorites => "Keine favorisierten Radiosender.";

  @override
  String get radioSearchText => "Radiosender suchen";

  @override
  String get radioSearchHint => "Sendername oder Stadt…";

  @override
  String get radioLanguage => "Sprache";

  @override
  String get radioBrowseBy => "Durchsuchen nach";

  @override
  String get radioBrowseByLanguage => "Nach Sprache durchsuchen";

  @override
  String get radioBrowseByCountry => "Nach Land durchsuchen";

  @override
  String get radioCountry => "Land";

  @override
  String get radioGenre => "Genre";

  @override
  String get radioActiveFilters => "Aktive Filter";

  @override
  String get radioResetFilters => "Filter zurücksetzen";

  @override
  String get radioFiltersReset => "Filter zurückgesetzt.";

  @override
  String get radioCity => "Stadt";

  @override
  String get radioSearch => "Suchen";

  @override
  String get radioSearching => "Radios werden geladen…";

  @override
  String get radioSearchResults => "Radioergebnisse";

  @override
  String get radioNoResults => "Keine Radiosender gefunden.";

  @override
  String radioResultsFound(int count) {
    return "${count} Radiosender gefunden";
  }

  @override
  String radioSearchError(Object error) {
    return "Fehler bei der Radiosuche: ${error}";
  }

  @override
  String radioNowPlaying(String name) {
    return "${name} wird wiedergegeben";
  }

  @override
  String radioPlayError(Object error) {
    return "Fehler beim Radiostream: ${error}";
  }

  @override
  String get radioAddFavorite => "Zu Favoriten hinzufügen";

  @override
  String get radioRemoveFavorite => "Aus Favoriten entfernen";

  @override
  String radioFavoriteAdded(String name) {
    return "${name} wurde zu den Favoriten hinzugefügt.";
  }

  @override
  String radioFavoriteRemoved(String name) {
    return "${name} wurde aus den Favoriten entfernt.";
  }

  @override
  String get tvSearchFieldLabel => "TV-Sender suchen";

  @override
  String get tvSearchFieldHint => "Sendername…";

  @override
  String get tvSearchButton => "Suchen";

  @override
  String get tvSearchResults => "TV-Senderergebnisse";

  @override
  String get tvSearchEmptyQuery => "Gib den Namen eines TV-Senders ein, nach dem gesucht werden soll.";

  @override
  String tvSearchNoResults(String query) {
    return "Keine TV-Sender für ${query} gefunden.";
  }

  @override
  String get tvOpenChannelHint => "Tippen, um den TV-Sender abzuspielen";

  @override
  String tvNowOnAir(String title) {
    return "Jetzt auf Sendung: ${title}";
  }

  @override
  String get radioAddCommunity => "Radio zur Sonarpad-Community hinzufügen";

  @override
  String get radioAddName => "Radioname";

  @override
  String get radioAddUrl => "Stream-Adresse";

  @override
  String get radioAddSubmit => "Prüfen und hinzufügen";

  @override
  String get radioAddMissingFields => "Bitte Radioname und Stream-Adresse eingeben.";

  @override
  String get radioCommunityAdded => "Radio erfolgreich zur Sonarpad-Community hinzugefügt.";

  @override
  String radioCommunityAddError(Object error) {
    return "Fehler beim Hinzufügen des Radios: ${error}";
  }

  @override
  String get radioPlay => "Abspielen";

  @override
  String get startRecording => "Aufnahme starten";

  @override
  String get stopRecording => "Aufnahme stoppen";

  @override
  String get recordings => "Aufnahmen";

  @override
  String get recordingInProgressStatus => 'Aufnahme läuft';

  @override
  String get scheduledRecordingInProgressStatus => 'Geplante Aufnahme läuft';

  @override
  String get recordingCannotOpenWhileInProgress => 'Diese Aufnahme kann nicht geöffnet werden, da sie noch läuft.';

  @override
  String get blindLibrarySearchCatalog => 'Katalog durchsuchen';

  @override
  String get selectRecordings => "Aufnahmen auswählen";

  @override
  String deleteRecordingsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen dauerhaft löschen?',
      one: 'Eine Aufnahme dauerhaft löschen?',
    );
    return '$_temp0';
  }

  @override
  String get noRecordings => "Keine Aufnahmen.";

  @override
  String get recordingStarted => "Aufnahme gestartet.";

  @override
  String recordingSaved(Object path) {
    return "Aufnahme gespeichert: ${path}";
  }

  @override
  String recordingError(Object error) {
    return "Aufnahmefehler: ${error}";
  }

  @override
  String get routeTitle => "Routen";

  @override
  String get routeFrom => "Von";

  @override
  String get routeTo => "Nach";

  @override
  String get routeCountry => "Land";

  @override
  String get routeCountryItaly => "Italien";

  @override
  String get routeCountryFrance => "Frankreich";

  @override
  String get routeCountrySpain => "Spanien";

  @override
  String get routeCountryCzechRepublic => "Tschechien";

  @override
  String get routeVehicle => "Verkehrsmittel";

  @override
  String get routeType => "Typ";

  @override
  String get routeIncludeMunicipalities => "Durchquerte Orte einbeziehen";

  @override
  String get routeWalking => "Zu Fuß";

  @override
  String get routeCycling => "Fahrrad";

  @override
  String get routeDriving => "Auto";

  @override
  String get routeWheelchair => "Rollstuhl";

  @override
  String get routeFastest => "Schnellste";

  @override
  String get routeShortest => "Kürzeste";

  @override
  String get routeCalculate => "Route berechnen";

  @override
  String get routeCalculating => "Wird berechnet…";

  @override
  String get routeChooseFrom => "Startpunkt auswählen";

  @override
  String get routeChooseTo => "Ziel auswählen";

  @override
  String get routeCancel => "Abbrechen";

  @override
  String get routeErrorMissingFields => "Bitte Startpunkt und Ziel eingeben";

  @override
  String get routeErrorFromNotFound => "Kein Ergebnis für die Startadresse gefunden";

  @override
  String get routeErrorToNotFound => "Kein Ergebnis für die Zieladresse gefunden";

  @override
  String get routeResultsTitle => "Verfügbare Routen";

  @override
  String get routeDistance => "Entfernung";

  @override
  String get routeDuration => "Dauer";

  @override
  String get routeNavigation => "Navigationsdetails";

  @override
  String get routeStartMunicipality => "Startgemeinde";

  @override
  String get routeEnterMunicipality => "Du fährst in die Gemeinde";

  @override
  String routeError(Object error) {
    return "Fehler: ${error}";
  }

  @override
  String get radioLanguageIt => "Italienisch";

  @override
  String get radioLanguageEn => "Englisch";

  @override
  String get radioLanguageDe => "Deutsch";

  @override
  String get radioLanguageCountryCh => "Schweiz";

  @override
  String get radioLanguageEs => "Spanisch";

  @override
  String get radioLanguagePt => "Portugiesisch";

  @override
  String get radioLanguageSv => "Schwedisch";

  @override
  String get radioLanguageVi => "Vietnamesisch";

  @override
  String get radioLanguageCs => "Tschechisch";

  @override
  String get radioLanguagePl => "Polnisch";

  @override
  String get radioLanguageFr => "Französisch";

  @override
  String get radioLanguageSr => "Serbisch";

  @override
  String get radioLanguageUk => "Ukrainisch";

  @override
  String get radioLanguageHi => "Hindi";

  @override
  String get radioLanguageLt => "Litauisch";

  @override
  String get radioLanguageRu => "Russisch";

  @override
  String get radioLanguageZh => "Chinesisch";

  @override
  String get radioCountryOptionIt => "Italien";

  @override
  String get radioCountryOptionUs => "Vereinigte Staaten";

  @override
  String get radioCountryOptionGb => "Vereinigtes Königreich";

  @override
  String get radioCountryOptionFr => "Frankreich";

  @override
  String get radioCountryOptionEs => "Spanien";

  @override
  String get radioCountryOptionDe => "Deutschland";

  @override
  String get radioCountryOptionCh => "Schweiz";

  @override
  String get radioCountryOptionAt => "Österreich";

  @override
  String get radioCountryOptionBe => "Belgien";

  @override
  String get radioCountryOptionNl => "Niederlande";

  @override
  String get radioCountryOptionPt => "Portugal";

  @override
  String get radioCountryOptionBr => "Brasilien";

  @override
  String get radioCountryOptionAr => "Argentinien";

  @override
  String get radioCountryOptionMx => "Mexiko";

  @override
  String get radioCountryOptionCa => "Kanada";

  @override
  String get radioCountryOptionAu => "Australien";

  @override
  String get radioCountryOptionIe => "Irland";

  @override
  String get radioCountryOptionSe => "Schweden";

  @override
  String get radioCountryOptionPl => "Polen";

  @override
  String get radioCountryOptionJp => "Japan";

  @override
  String get radioGenreOptionAll => "Alle Genres";

  @override
  String get radioGenreOptionNews => "Nachrichten";

  @override
  String get radioGenreOptionMusic => "Musik";

  @override
  String get radioGenreOptionSport => "Sport";

  @override
  String get radioGenreOptionTalk => "Gespräch und Analyse";

  @override
  String get radioGenreOptionPop => "Pop";

  @override
  String get radioGenreOptionRock => "Rock";

  @override
  String get radioGenreOptionClassical => "Klassik";

  @override
  String get radioGenreOptionJazz => "Jazz";

  @override
  String get radioGenreOptionDance => "Dance";

  @override
  String get radioGenreOptionBlues => "Blues";

  @override
  String get radioGenreOptionCountry => "Country";

  @override
  String get radioGenreOptionHiphop => "Hip-Hop";

  @override
  String get radioGenreOptionElectronic => "Elektronisch";

  @override
  String get radioGenreOptionLatin => "Latin";

  @override
  String get radioGenreOptionReggae => "Reggae";

  @override
  String get radioGenreOptionMetal => "Metal";

  @override
  String get radioGenreOptionFolk => "Folk";

  @override
  String get radioGenreOptionReligion => "Religion";

  @override
  String get radioGenreOptionLocal => "Lokal";

  @override
  String get radioGenreOptionCulture => "Kultur";

  @override
  String get radioGenreOptionOldies => "70er / 80er / 90er";

  @override
  String get radioGenreOptionKids => "Kinder";

  @override
  String get radioGenreOptionAmbient => "Ambient";

  @override
  String get radioCommunityLanguageItalian => "Italienisch";

  @override
  String get radioCommunityLanguageEnglish => "Englisch";

  @override
  String get radioCommunityLanguageSpanish => "Spanisch";

  @override
  String get radioCommunityLanguageFrench => "Französisch";

  @override
  String get radioCommunityLanguageGerman => "Deutsch";

  @override
  String get radioCommunityLanguagePortuguese => "Portugiesisch";

  @override
  String get radioCommunityLanguageSwedish => "Schwedisch";

  @override
  String get radioCommunityLanguageVietnamese => "Vietnamesisch";

  @override
  String get radioCommunityLanguageCzech => "Tschechisch";

  @override
  String get radioCommunityLanguagePolish => "Polnisch";

  @override
  String get radioCommunityLanguageSerbian => "Serbisch";

  @override
  String get radioCommunityLanguageUkrainian => "Ukrainisch";

  @override
  String get radioCommunityLanguageLithuanian => "Litauisch";

  @override
  String get radioCommunityLanguageRussian => "Russisch";

  @override
  String get radioCommunityLanguageChinese => "Chinesisch";

  @override
  String get radioCommunityLanguageHindi => "Hindi";

  @override
  String routeDistanceMeters(int meters) {
    return "${meters} m";
  }

  @override
  String routeDistanceKilometers(String kilometers) {
    return "${kilometers} km";
  }

  @override
  String routeDurationMinutes(int minutes) {
    return "${minutes} Min.";
  }

  @override
  String routeDurationHoursMinutes(int hours, int minutes) {
    return "${hours} Std. ${minutes} Min.";
  }

  @override
  String get cinemaTitle => "Filme im Kino";

  @override
  String get cinemaNoMovies => "Zurzeit keine Filme gefunden.";

  @override
  String get cinemaError => "Fehler beim Laden der Filme.";

  @override
  String cinemaReleased(String date) {
    return "Veröffentlicht am: ${date}";
  }

  @override
  String get cinemaOverviewLabel => "Übersicht:";

  @override
  String get cinemaUpcomingReleases => "Kommende Veröffentlichungen";

  @override
  String cinemaWillRelease(String date) {
    return "Erscheint am: ${date}";
  }

  @override
  String get cinemaOpenTrailer => "Trailer öffnen";

  @override
  String get concertsTitle => "Konzerte & Veranstaltungen";

  @override
  String get concertsSearchHint => "Stadt eingeben (z. B. Berlin, München)";

  @override
  String get concertsSearchLabel => "Konzerte nach Stadt suchen";

  @override
  String get concertsSearchTooltip => "Suchen";

  @override
  String get concertsInitialText => "Gib oben den Namen deiner Stadt ein, um kommende Musikkonzerte anzuzeigen.";

  @override
  String get concertsEmpty => "Keine Konzerte in dieser Stadt gefunden.";

  @override
  String get concertsVenue => "Veranstaltungsort:";

  @override
  String get concertsBuyTickets => "Tickets kaufen oder Details bei Ticketmaster ansehen";

  @override
  String get podcastPlayedEpisodes => "Abgespielte Episoden";

  @override
  String get podcastSelectDate => "Datum auswählen";

  @override
  String get podcastNoDatesAvailable => "Für diese Episoden sind keine Daten verfügbar.";

  @override
  String get podcastChapters => "Kapitel";

  @override
  String get podcastChaptersUnavailable => "Für diese Episode sind keine Kapitel verfügbar.";

  @override
  String get podcastUnplayed => "Nicht abgespielte Episoden";

  @override
  String get routeReadAction => "Route vorlesen";

  @override
  String get routeSaveAction => "In Dokumente speichern";

  @override
  String get routeSaveSuccess => "Route in Dokumente gespeichert";

  @override
  String get deleteItem => "Löschen";

  @override
  String get audiobookMp3Format => "Hörbuch MP3 (.mp3)";

  @override
  String get audiobookM4bFormat => "Hörbuch M4B (.m4b)";

  @override
  String get exportCompleteTitle => "Export abgeschlossen";

  @override
  String get exportCompleteMessage => "Die Datei wurde erfolgreich erstellt. Möchtest du sie in Sonarpad speichern oder teilen?";

  @override
  String get saveInSonarpad => "In Sonarpad speichern";

  @override
  String get exportSavedInSonarpad => "Datei in Sonarpad-Dokumenten gespeichert.";

  @override
  String get audiobookExportProgressTitle => "Hörbuch wird erstellt";

  @override
  String get audiobookExportPreparing => "Hörbuch wird vorbereitet…";

  @override
  String get audiobookExportGeneratingAudio => "Audio wird erzeugt";

  @override
  String get audiobookExportConvertingAudio => "Abschließende Audiokonvertierung…";

  @override
  String get audiobookExportFinalizing => "Wird abgeschlossen…";

  @override
  String get routeRecentRoutes => "Letzte Routen";

  @override
  String get routeRecentRoutesEmpty => "Keine letzten Routen";

  @override
  String routeNavigationFromTo(Object from, Object to, Object date) {
    return "Navigationsdetails von ${from} nach ${to} – ${date}";
  }

  @override
  String get sortPodcastsAlphabetically => "Podcasts alphabetisch sortieren";

  @override
  String get sortRadioFavoritesAlphabetically => "Favoriten alphabetisch sortieren";

  @override
  String get podcastsSortedAlphabetically => "Podcasts alphabetisch sortiert.";

  @override
  String get radioFavoritesSortedAlphabetically => "Radiofavoriten alphabetisch sortiert.";

  @override
  String get settingsIncludeFootnotesInText => "Fußnoten im Text anzeigen";

  @override
  String get settingsIncludeFootnotesInTextHint => "Bei unterstützten EPUB-Büchern wird jede Fußnote direkt nach dem Absatz angezeigt, der auf sie verweist.";

  @override
  String get documentFootnoteLabel => "Fußnote";

  @override
  String get settingsMultipleDocumentBookmarks => "Mehrere Lesezeichen in Dokumenten erlauben";

  @override
  String get settingsMultipleDocumentBookmarksHint => "Wenn deaktiviert, behält jedes Dokument ein Lesezeichen. Wenn aktiviert, kannst du mehrere Lesezeichen im selben Dokument speichern.";

  @override
  String get documentGoToBookmarkAction => "Zum Lesezeichen gehen";

  @override
  String get documentChooseBookmarkTitle => "Lesezeichen auswählen";

  @override
  String get documentDeleteBookmarkAction => "Lesezeichen löschen";

  @override
  String get documentKeepBookmarkTitle => "Welches Lesezeichen möchtest du behalten?";

  @override
  String get documentKeepBookmarkMessage => "Mehrere Lesezeichen sind deaktiviert. Wähle ein Lesezeichen aus, das behalten werden soll; die anderen werden gelöscht.";

  @override
  String documentBookmarkChoiceLabel(int order, int paragraph) {
    return "Lesezeichen ${order}, Absatz ${paragraph}";
  }

  @override
  String documentBookmarkChoiceLabelWithPreview(
    int order,
    int paragraph,
    String preview,
  ) {
    return "Lesezeichen ${order}, Absatz ${paragraph}. ${preview}";
  }

  @override
  String get settingsVideoLandscapeFullscreen => "Video im Querformat als Vollbild";

  @override
  String get settingsVideoLandscapeFullscreenHint => "Wenn du Video aktivierst, wird es im Querformat als Vollbild angezeigt. Radios mit reinem Audio bleiben unverändert.";

  @override
  String get settingsPodcastCacheTitle => "Podcast-Cache";

  @override
  String get settingsPodcastCacheHint => "Löscht nur temporäre Podcast-Dateien. Abonnements, Verlauf und importierte Audiodateien bleiben erhalten.";

  @override
  String settingsPodcastCacheSize(String size) {
    return "Belegter Speicher: ${size}";
  }

  @override
  String get clearPodcastCache => "Podcast-Cache leeren";

  @override
  String get confirmClearPodcastCacheTitle => "Podcast-Cache leeren?";

  @override
  String get confirmClearPodcastCacheMessage => "Temporäre Podcast-Dateien werden gelöscht. Abonnements und Episodenverlauf werden nicht entfernt.";

  @override
  String podcastCacheCleared(String size) {
    return "Podcast-Cache geleert: ${size} freigegeben.";
  }

  @override
  String get podcastCacheEmpty => "Der Podcast-Cache ist bereits leer.";

  @override
  String get pharmacyFeatureTitle => "Medikamente, Parapharmazeutika und Nahrungsergänzungsmittel";

  @override
  String get pharmacyProductsSectionTitle => "Parapharmazeutika und Nahrungsergänzungsmittel";

  @override
  String get pharmacyProductsLoadingTitle => "Parapharmazeutika und Nahrungsergänzungsmittel werden gesucht…";

  @override
  String get pharmacyProductsErrorTitle => "Fehler bei der Suche nach Parapharmazeutika und Nahrungsergänzungsmitteln";

  @override
  String get pharmacyProductsNoResultsTitle => "Kein Parapharmazeutikum oder Nahrungsergänzungsmittel gefunden";

  @override
  String get mediaCutterTitle => "Mediendatei schneiden";

  @override
  String get mediaCutterInstruction1 => "Öffne eine Audio- oder Videodatei, spiele sie ab und gehe zu der Stelle, an der du schneiden möchtest.";

  @override
  String get mediaCutterInstruction2 => "Pausiere, drücke Teilen, lösche anschließend im Bereich Zu speichernde Teile die unerwünschten Teile und drücke Speichern.";

  @override
  String get mediaCutterOpenFile => "Mediendatei öffnen";

  @override
  String mediaCutterSelectedFile(String fileName) {
    return "Ausgewählte Datei: ${fileName}";
  }

  @override
  String get mediaCutterPosition => "Schnittposition";

  @override
  String get mediaCutterPositionHint => "Jeweils eine Sekunde vor- oder zurückgehen.";

  @override
  String get mediaCutterHideVideoPreview => "Video ausblenden";

  @override
  String get mediaCutterVideoRotation => "Videodrehung";

  @override
  String get mediaCutterVideoRotationNone => "Keine Drehung";

  @override
  String get mediaCutterVideoRotationRight => "Nach rechts drehen";

  @override
  String get mediaCutterVideoRotationLeft => "Nach links drehen";

  @override
  String get mediaCutterVideoRotationUpsideDown => "Um 180 Grad drehen";

  @override
  String get mediaCutterVideoPreview => "Videovorschau";

  @override
  String get mediaCutterSplit => "Teilen";

  @override
  String get mediaCutterPartsTitle => "Zu speichernde Teile";

  @override
  String get mediaCutterPartsHint => "Tippe auf einen Teil, um ihn anzuhören. Gelöschte Teile verschwinden aus der Liste, werden bei der Wiedergabe übersprungen und nicht gespeichert. Effekte werden erst beim Speichern auf den gesamten Teil angewendet.";

  @override
  String mediaCutterPartLabel(int index) {
    return "Teil ${index}";
  }

  @override
  String mediaCutterPartRange(String start, String end) {
    return "Von ${start} bis ${end}";
  }

  @override
  String get mediaCutterSave => "Speichern";

  @override
  String get mediaCutterReady => "Bereit.";

  @override
  String get mediaCutterUnsavedExitTitle => "Nicht gespeicherte Datei";

  @override
  String get mediaCutterUnsavedExitMessage => "Die Datei wurde nicht gespeichert. Möchtest du wirklich verlassen?";

  @override
  String get mediaCutterNoFile => "Öffne zuerst eine Mediendatei.";

  @override
  String get mediaCutterInvalidSplitPoint => "Wähle einen Punkt innerhalb der Datei, nicht den Anfang oder das Ende.";

  @override
  String get mediaCutterSplitAlreadyExists => "An dieser Stelle gibt es bereits eine Teilung.";

  @override
  String mediaCutterSplitAdded(String position) {
    return "Teilung bei ${position} hinzugefügt.";
  }

  @override
  String get mediaCutterSaving => 'Verarbeitung läuft…';

  @override
  String mediaCutterSaved(String fileName) {
    return "Datei gespeichert: ${fileName}";
  }

  @override
  String mediaCutterLoadFailed(Object error) {
    return "Datei konnte nicht geöffnet werden: ${error}";
  }

  @override
  String mediaCutterSaveFailed(Object error) {
    return "Speichern fehlgeschlagen: ${error}";
  }

  @override
  String get mediaCutterNoPartsToSave => "Behalte vor dem Speichern mindestens einen Teil.";

  @override
  String get mediaCutterRestoreDeletedPart => "Gelöschten Teil wiederherstellen";

  @override
  String get mediaCutterNoDeletedParts => "Es gibt keine gelöschten Teile zum Wiederherstellen.";

  @override
  String get mediaCutterPartDeleteAction => "Löschen";

  @override
  String get mediaCutterPartTapHint => "Doppeltippen, um diesen Teil vorzuhören. Verwende die Aktionen Teil bearbeiten, Löschen oder Effekte anpassen.";

  @override
  String mediaCutterPartDeleted(String start, String end) {
    return "Teil von ${start} bis ${end} gelöscht.";
  }

  @override
  String mediaCutterPartRestored(String start, String end) {
    return "Teil von ${start} bis ${end} wiederhergestellt.";
  }

  @override
  String get mediaCutterPartEffectsAction => "Effekte anpassen";

  @override
  String get mediaCutterPartEditAction => "Teil bearbeiten";

  @override
  String get mediaCutterPartEditDescription => "Verschiebe Anfang oder Ende des Teils um 1 Sekunde und höre anschließend den bearbeiteten Teil an.";

  @override
  String mediaCutterPartAdjusted(String start, String end) {
    return "Teil von ${start} bis ${end} bearbeitet.";
  }

  @override
  String get mediaCutterPartEffectsTitle => "Effekte für Teil";

  @override
  String get mediaCutterPartEffectsDescription => "Lautstärke und Effekt nur für diesen Teil anpassen.";

  @override
  String get mediaCutterPartVolumeLabel => 'Lautstärke des Teils';

  @override
  String mediaCutterPartVolumeValue(int percent) {
    return "Lautstärke des Teils: ${percent}%";
  }

  @override
  String get mediaCutterPartEffect => "Audioeffekt";

  @override
  String get mediaCutterPartEffectNone => "Kein Effekt";

  @override
  String get mediaCutterPartEffectEcho => "Leichtes Echo";

  @override
  String get mediaCutterPartEffectEchoRoom => "Raumecho";

  @override
  String get mediaCutterPartEffectEchoChamber => "Kammerecho";

  @override
  String get mediaCutterPartEffectEchoCathedral => "Kathedralenecho";

  @override
  String get mediaCutterPartEffectLargeRoom => "Großer Raum";

  @override
  String get mediaCutterPartEffectSmallRoom => "Kleiner Raum";

  @override
  String get mediaCutterPartEffectBathroom => "Badezimmer";

  @override
  String get mediaCutterPartEffectTunnel => "Tunnel";

  @override
  String get mediaCutterPartEffectRepeatEcho => "Wiederholendes Echo";

  @override
  String get mediaCutterPartEffectCorridor => "Korridor";

  @override
  String get mediaCutterPartEffectDelay => "Verzögerung";

  @override
  String get mediaCutterPartEffectReverb => "Leichter Hall";

  @override
  String get mediaCutterPartEffectChorus => "Chorus";

  @override
  String get mediaCutterPartEffectPitchLow => "Tiefe Tonhöhe";

  @override
  String get mediaCutterPartEffectPitchVeryLow => "Sehr tiefe Tonhöhe";

  @override
  String get mediaCutterPartEffectPitchHigh => "Hohe Tonhöhe";

  @override
  String get mediaCutterPartEffectPitchVeryHigh => "Sehr hohe Tonhöhe";

  @override
  String get mediaCutterPartEffectRobot => "Roboterstimme";

  @override
  String get mediaCutterPartEffectSuperRobot => "Superroboter";

  @override
  String get mediaCutterPartEffectHelicopter => "Hubschrauber";

  @override
  String get mediaCutterPartEffectAlien => "Alien-Vibrato";

  @override
  String get mediaCutterPartEffectBrightVoice => "Klare Stimme";

  @override
  String get mediaCutterPartEffectDarkVoice => "Dunkle Stimme";

  @override
  String get mediaCutterPartEffectGhost => "Geist";

  @override
  String get mediaCutterPartEffectTelephone => "Telefon";

  @override
  String get mediaCutterPartEffectOldRadio => "Altes Radio";

  @override
  String get mediaCutterPartEffectMegaphone => "Megafon";

  @override
  String get mediaCutterPartEffectUnderwater => "Unter Wasser";

  @override
  String get mediaCutterPartEffectMonster => "Monster";

  @override
  String get mediaCutterPartEffectChipmunk => "Streifenhörnchen";

  @override
  String get mediaCutterPartEffectDream => "Traum";

  @override
  String get mediaCutterPartEffectDistortion => "Verzerrung";

  @override
  String get mediaCutterPartEffectLoFi => "Lo-Fi";

  @override
  String get mediaCutterPartEffectReverseEcho => "Rückwärtsecho";

  @override
  String get mediaCutterPartEffectFadeIn => "Einblenden";

  @override
  String get mediaCutterPartEffectFadeOut => "Ausblenden";

  @override
  String get mediaCutterPartEffectAmountLabel => 'Effektstärke';

  @override
  String mediaCutterPartEffectAmountValue(int percent) {
    return "Effektstärke: ${percent}%";
  }

  @override
  String get mediaCutterPartPreviewAction => "Vorschau";

  @override
  String get mediaCutterPartEffectsSavedOnly => "Die Vorschau verwendet die gewählte Lautstärke. Audioeffekte werden beim Speichern angewendet.";

  @override
  String mediaCutterPartEffectsApplied(String start, String end) {
    return "Effekte für den Teil von ${start} bis ${end} aktualisiert.";
  }

  @override
  String mediaCutterPartEffectsSummary(int percent, String effect) {
    return "Lautstärke ${percent}%, Effekt ${effect}";
  }

  @override
  String get mediaCutterGuidedModeTitle => "Geführter Schnitt";

  @override
  String get mediaCutterGuidedModeDescription => "Für Einsteiger geeignet. Wähle einen Start- und einen Endpunkt, höre den Schnitt an und wende ihn anschließend an.";

  @override
  String get mediaCutterAdvancedModeTitle => "Erweiterter Schnitt";

  @override
  String get mediaCutterAdvancedModeDescription => "An gängigen Medienbearbeitungsprogrammen orientiert. Du kannst eine Mediendatei in mehrere Teile aufteilen und unerwünschte Teile entfernen.";

  @override
  String get mediaCutterChangeCutMode => "Schnittart ändern";

  @override
  String get mediaCutterGuidedSetStart => "Schnittanfang";

  @override
  String get mediaCutterGuidedSetEnd => "Schnittende";

  @override
  String get mediaCutterGuidedApplyCut => "Schnitt anwenden";

  @override
  String get mediaCutterGuidedListenCut => "Schnitt anhören";

  @override
  String get mediaCutterGuidedModifyCut => "Schnitt bearbeiten";

  @override
  String get mediaCutterGuidedMoveStartBackOneSecond => "Schnittanfang um 1 Sekunde zurück verschieben";

  @override
  String get mediaCutterGuidedMoveStartForwardOneSecond => "Schnittanfang um 1 Sekunde vor verschieben";

  @override
  String get mediaCutterGuidedMoveEndBackOneSecond => "Schnittende um 1 Sekunde zurück verschieben";

  @override
  String get mediaCutterGuidedMoveEndForwardOneSecond => "Schnittende um 1 Sekunde vor verschieben";

  @override
  String get mediaCutterCutEditPrecisionLabel => "Genauigkeit der Schnittbearbeitung";

  @override
  String mediaCutterCutEditPrecisionValue(String value) {
    return "Genauigkeit der Schnittbearbeitung: ${value}";
  }

  @override
  String get mediaCutterCutEditStepOneSecond => "1 Sekunde";

  @override
  String get mediaCutterCutEditStepHalfSecond => "0,5 Sekunden";

  @override
  String get mediaCutterCutEditStepQuarterSecond => "0,25 Sekunden";

  @override
  String get mediaCutterCutEditStepTenthSecond => "0,10 Sekunden";

  @override
  String mediaCutterMoveStartBackBy(String value) {
    return "Schnittanfang um ${value} zurück verschieben";
  }

  @override
  String mediaCutterMoveStartForwardBy(String value) {
    return "Schnittanfang um ${value} vor verschieben";
  }

  @override
  String mediaCutterMoveEndBackBy(String value) {
    return "Schnittende um ${value} zurück verschieben";
  }

  @override
  String mediaCutterMoveEndForwardBy(String value) {
    return "Schnittende um ${value} vor verschieben";
  }

  @override
  String mediaCutterGuidedCutAdjusted(String start, String end) {
    return "Schnitt von ${start} bis ${end} geändert.";
  }

  @override
  String get mediaCutterGuidedNoCut => "Kein Schnitt";

  @override
  String get mediaCutterGuidedEffectsAction => "Dateieffekte anpassen";

  @override
  String get mediaCutterGuidedEffectsDescription => "Lautstärke und Effekte für die gesamte Ergebnisdatei anpassen.";

  @override
  String get mediaCutterGuidedFileTapHint => "Doppeltippen, um die Ergebnisdatei abzuspielen. Verwende Dateieffekte anpassen, um Effekte auf die gesamte Datei anzuwenden.";

  @override
  String mediaCutterGuidedStartSet(String start) {
    return "Schnittanfang auf ${start} gesetzt.";
  }

  @override
  String mediaCutterGuidedEndSet(String start, String end) {
    return "Schnittende auf ${end} gesetzt. Schnitt von ${start} bis ${end}.";
  }

  @override
  String mediaCutterGuidedCutApplied(String start, String end) {
    return "Schnitt von ${start} bis ${end} angewendet.";
  }

  @override
  String get mediaCutterGuidedNeedStartEnd => "Lege zuerst Schnittanfang und Schnittende fest.";

  @override
  String mediaCutterGuidedCutSummary(String start, String end) {
    return "Schnitt von ${start} bis ${end}";
  }

  @override
  String mediaCutterGuidedMultipleCutSummary(int count, String cuts) {
    return "${count} Schnitte: ${cuts}";
  }

  @override
  String get mediaCutterGuidedPendingCutExitMessage => "Du hast einen geführten Schnitt, der noch nicht angewendet wurde. Möchtest du verlassen, ohne ihn zu übernehmen?";

  @override
  String mediaCutterSplitAddedAnnouncement(int partNumber) {
    return "Teilung hinzugefügt. Teil ${partNumber} hinzugefügt.";
  }

  @override
  String get newsAddCommunitySource => "Nachrichtenquelle zur Sonarpad-Community hinzufügen";

  @override
  String get newsBrowseCommunitySources => "Nachrichtenquellen der Community";

  @override
  String get newsAddCommunityInstructions => "Gib den Titel der Quelle und eine RSS-Feed-URL oder Website-URL ein. Sonarpad verwendet die ausgewählte Nachrichtensprache und versucht bei einer Website, den Feed automatisch zu finden.";

  @override
  String get newsCommunitySourceName => "Titel der Quelle";

  @override
  String get newsCommunitySourceUrl => "RSS-Feed- oder Website-URL";

  @override
  String get newsCommunitySubmit => "Prüfen und hinzufügen";

  @override
  String get newsCommunityChecking => "Feed oder Website wird geprüft…";

  @override
  String get newsCommunityMissingFields => "Gib Titel und Feed- oder Website-URL ein.";

  @override
  String get newsCommunityAdded => "Nachrichtenquelle erfolgreich zur Sonarpad-Community hinzugefügt.";

  @override
  String newsCommunityAddError(Object error) {
    return "Fehler beim Hinzufügen der Nachrichtenquelle: ${error}";
  }

  @override
  String newsCommunitySelectedLanguage(Object language) {
    return "Ausgewählte Sprache: ${language}";
  }

  @override
  String get newsCommunitySourcesTitle => "Nachrichtenquellen der Community";

  @override
  String get newsCommunitySourcesEmpty => "Für diese Sprache sind keine Community-Nachrichtenquellen verfügbar.";

  @override
  String newsCommunitySourcesError(Object error) {
    return "Fehler beim Laden der Community-Nachrichtenquellen: ${error}";
  }

  @override
  String newsCommunitySourceAddedToLibrary(Object name) {
    return "${name} wurde zu deiner Nachrichtenbibliothek hinzugefügt.";
  }

  @override
  String newsCommunityAddToLibraryError(Object error) {
    return "Fehler beim Hinzufügen zur Bibliothek: ${error}";
  }

  @override
  String get newsCommunitySourceTapHint => "Tippen, um die Quelle zu deiner Nachrichtenbibliothek hinzuzufügen.";

  @override
  String get developerModeEnabled => "Entwicklermodus aktiviert.";

  @override
  String get developerModeDisabled => "Entwicklermodus deaktiviert.";

  @override
  String get developerSectionTitle => "Entwickler";

  @override
  String get developerUseExperimentalFlutterRenderer => "Experimentellen Flutter-Renderer verwenden";

  @override
  String get developerUseExperimentalFlutterRendererHint => "Deaktiviert UIKit vorübergehend, um VoiceOver mit reinem Flutter zu vergleichen.";


  // Shared labels generated from ARB entries.
  @override
  String get letterJumpSelectLetter => 'Buchstaben auswählen';

  @override
  String get letterJumpSelected => 'ausgewählt';

  @override
  String get settingsToggleOn => 'Ein';

  @override
  String get settingsToggleOff => 'Aus';

  @override
  String get radioDirectoryLoading => 'Radioländer und -sprachen werden aktualisiert...';

  @override
  String get recentRadios => 'Zuletzt gehörte Radiosender';

  @override
  String get radioNextPage => 'Weiter';

  @override
  String radioPageOf(int current, int total) {
    return 'Seite $current von $total';
  }

  @override
  String get radioNoResultsWithQuery => 'Keine Radiosender gefunden. Versuche nur den Sendernamen ohne Genre oder ändere Sprache bzw. Land.';

  @override
  String get radioNoResultsGeneric => 'Keine Radiosender gefunden. Versuche eine andere Sprache, ein anderes Land oder Genre.';

  @override
  String radioSearchRawError(Object error) {
    return 'Fehler bei der Radiosuche: $error';
  }

  @override
  String get radioBrowserConnectionError => 'Verbindungsfehler mit Radio Browser. Bitte versuche es später erneut.';

  @override
  String get documentIndexLoadingMessage => 'Inhaltsverzeichnis wird geladen... Bitte warten.';

  @override
  String get documentIndexUnavailableMessage => 'Für dieses EPUB ist kein Inhaltsverzeichnis verfügbar.';

  @override
  String mediaCutterVolumeSummary(int percent) {
    return 'Lautstärke $percent%';
  }

  @override
  String mediaCutterDurationSummary(String duration) {
    return 'Dauer $duration';
  }

  @override
  String get mediaCutterDurationHourOne => 'Stunde';

  @override
  String get mediaCutterDurationHourFew => 'Stunden';

  @override
  String get mediaCutterDurationHourMany => 'Stunden';

  @override
  String get mediaCutterDurationMinuteOne => 'Minute';

  @override
  String get mediaCutterDurationMinuteFew => 'Minuten';

  @override
  String get mediaCutterDurationMinuteMany => 'Minuten';

  @override
  String get mediaCutterDurationSecondOne => 'Sekunde';

  @override
  String get mediaCutterDurationSecondFew => 'Sekunden';

  @override
  String get mediaCutterDurationSecondMany => 'Sekunden';

  @override
  String get mediaCutterDurationAnd => 'und';

  @override
  String mediaCutterSeekStepButton(String step) {
    return 'Schrittweite der Mediendatei anpassen: $step';
  }

  @override
  String get mediaCutterSeekStepTitle => 'Schrittweite der Mediendatei';

  @override
  String mediaCutterSeekStepSelected(String step) {
    return 'Schrittweite der Mediendatei auf $step eingestellt.';
  }

  @override
  String get mediaCutterPartEffectBackwards => 'Rückwärts';

  @override
  String get mediaCutterPartEffectTalkingGuitar => 'Sprechende Gitarre';

  @override
  String get mediaCutterPartEffectMosquito => 'Mücke';

  @override
  String get mediaCutterPartEffectOneOfMany => 'Eine Stimme, viele Sänger';

  @override
  String get mediaCutterPartEffectOrganVocoder => 'Sprechende Orgel';

  @override
  String get mediaCutterPartEffectWarped => 'Verformt';

  @override
  String get mediaCutterPartEffectSwirling => 'Stereo-Wirbel';

  @override
  String get mediaCutterPartEffectVader => 'Filmische dunkle Stimme';

  @override
  String get mediaCutterPartEffectMetallic => 'Metallisch';

  @override
  String get mediaCutterPartEffectSongbird => 'Singvogel';

  @override
  String get mediaCutterPartEffectExterminator => 'Exterminator';

  @override
  String get mediaCutterPartEffectRainAndThunder => 'Regen und Donner';

  @override
  String get mediaCutterPartEffectJungle => 'Dschungel';

  @override
  String get mediaCutterPartEffectCrowd => 'Menschenmenge';

  @override
  String get mediaCutterPartEffectSlotMachines => 'Spielautomaten';

  @override
  String get mediaCutterPartEffectTraffic => 'Verkehr';

  @override
  String get mediaCutterPartEffectSpaceship => 'Raumschiff';

  @override
  String get mediaCutterPartEffectCricket => 'Grille';

  @override
  String get mediaCutterPartEffectSiren => 'Sirene';

  @override
  String get mediaCutterPartEffectSleighBells => 'Schlittenglocken';

  @override
  String get mediaCutterPartEffectDj => 'DJ-Scratch';

  @override
  String get mediaCutterPartEffectApplause => 'Applaus';

  @override
  String get mediaCutterPartEffectBadMelody => 'Schräge Melodie';

  @override
  String get mediaCutterPartEffectBadHarmony => 'Dissonante Harmonie';

  @override
  String get mediaCutterPartEffectWarmVoice => 'Warme Stimme';

  @override
  String get mediaCutterPartEffectTurtle => 'Schildkröte';

  @override
  String get mediaCutterPartEffectHaunting => 'Gespenstisch';

  @override
  String get radioPreviousPage => 'Zurück';

  @override
  String get noRecentRadios => 'Keine zuletzt gehörten Radiosender.';

  @override
  String get radioBrowseByCity => 'Nach Stadt durchsuchen';

  @override
  String get radioCityInputHint => 'Stadt eingeben...';

  @override
  String get openItem => 'Öffnen';

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get fileTypeLabel => 'Datei';

  @override
  String get cinemaTrailerLoading => 'Trailer wird geladen';

  @override
  String get cinemaNoTrailer => 'Für diesen Film ist kein Trailer verfügbar';

  @override
  String get radioScheduleHours => 'Stunden';

  @override
  String get radioScheduleSelectHours => 'Stunden auswählen';

  @override
  String get radioScheduleMinutes => 'Minuten';

  @override
  String get radioScheduleSelectMinutes => 'Minuten auswählen';

  @override
  String radioScheduleLabeledValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get radioScheduleStopCurrentFirst => 'Beende die laufende Aufnahme, bevor du eine neue planst.';

  @override
  String get radioScheduleStartTime => 'Startzeit';

  @override
  String get radioScheduleEndTime => 'Endzeit';

  @override
  String get radioScheduleDialogTitle => 'Aufnahme planen';

  @override
  String get radioScheduleOpenRequirement => 'Die geplante Aufnahme funktioniert weiter, während du zu anderen Sonarpad-Bildschirmen wechselst. Sonarpad muss geöffnet bleiben; wenn die App geschlossen oder vom System angehalten wird, ist der Start der Aufnahme nicht garantiert.';

  @override
  String radioScheduleStartTimeValue(String time) {
    return 'Startzeit: $time';
  }

  @override
  String radioScheduleEndTimeValue(String time) {
    return 'Endzeit: $time';
  }

  @override
  String get radioScheduleOptionalTitle => 'Optionaler Titel';

  @override
  String get radioScheduleTitleHint => 'Leer lassen, um den Namen des Radiosenders oder TV-Senders zu verwenden';

  @override
  String get radioScheduleAction => 'Planen';

  @override
  String radioScheduledRecordingRange(String start, String end) {
    return 'Geplante Aufnahme: $start - $end.';
  }

  @override
  String get radioScheduledRecordingAlreadyActive => 'Geplante Aufnahme nicht gestartet: Es läuft bereits eine andere Aufnahme.';

  @override
  String get radioScheduledRecordingStarted => 'Geplante Aufnahme gestartet.';

  @override
  String radioScheduledRecordingError(Object error) {
    return 'Fehler bei der geplanten Aufnahme: $error';
  }

  @override
  String get radioScheduledRecordingSaved => 'Geplante Aufnahme gespeichert.';

  @override
  String radioScheduledRecordingSaveError(Object error) {
    return 'Fehler beim Speichern der geplanten Aufnahme: $error';
  }

  @override
  String get radioScheduledRecordingCancelled => 'Geplante Aufnahme abgebrochen.';

  @override
  String radioScheduledRecordingRangeWithTitle(String start, String end, String title) {
    return 'Geplante Aufnahme: $start - $end. Titel: $title.';
  }

  @override
  String get radioScheduleCancelAction => 'Geplante Aufnahme abbrechen';
  @override
  String get radioLanguageTr => 'Türkisch';

  @override
  String get radioCountryOptionTr => 'Türkei';

  @override
  String get radioCommunityLanguageTurkish => 'Türkisch';
  @override
  String get simplifiedChineseLanguageName => 'Vereinfachtes Chinesisch';

  @override
  String get chinaCountryName => 'China';

  @override
  String get technicalErrorGeneric => 'Technischer Fehler. Bitte versuche es erneut.';

  @override
  String cinemaTrailerTitle(String title) {
    return 'Trailer: $title';
  }

  @override
  String mediaCutterExportPartProgress(int index, int total) {
    return 'Teil $index von $total';
  }

  @override
  String get mediaCutterExportFinalVerification => 'Abschließende Überprüfung';

  @override
  String get mediaCutterExportMergeParts => 'Teile zusammenführen';

  @override
  String get mediaCutterExportFileCheck => 'Dateiprüfung';

  @override
  String get mediaCutterExportPublishing => 'Veröffentlichung';

  @override
  String get mediaCutterExportCompletion => 'Abschluss';


  @override
  String get mediaCutterAddTrack => 'Neue Spur hinzufügen';

  @override
  String get mediaCutterChooseAudioTrack => 'Audiodatei auswählen';

  @override
  String mediaCutterAddedTrackSelected(String name) => 'Ausgewählte Audiodatei: $name';

  @override
  String get mediaCutterOriginalTrackVolume => 'Lautstärke der Originalspur';

  @override
  String get mediaCutterNewTrackVolume => 'Lautstärke der neuen Spur';

  @override
  String get mediaCutterLoopNewTrack => 'Neue Spur in Schleife wiedergeben';

  @override
  String get mediaCutterPreviewNewTrack => 'Vorschau anhören';

  @override
  String get mediaCutterFinalizeTrack => 'Fertigstellen';

  @override
  String mediaCutterAddedTrackApplied(String name) => 'Neue Spur hinzugefügt: $name';

  @override
  String get mediaCutterAddedTrackInvalidAudio => 'Die ausgewählte Datei enthält keine gültige Audiospur.';

  @override
  String get mediaCutterAddedTrackPreviewPreparing => 'Vorschau wird vorbereitet…';

  @override
  String get mediaCutterAddedTrackPreviewFailed => 'Vorschau konnte nicht erstellt werden.';

  @override
  String get mediaCutterMixingAddedTrack => 'Neue Spur wird gemischt';


  @override
  String get mediaProcessingCompleted => 'Verarbeitung abgeschlossen.';

  @override
  String get saveInSonarpadDocuments => 'In Sonarpad-Dokumenten speichern';

  @override
  String get mediaCutterProcess => 'Verarbeiten';

  @override
  String get preserveMedia => 'Inhalt speichern';

  @override
  String get preserveMediaSaving => 'Inhalt wird gespeichert…';

  @override
  String get preserveMediaSaved => 'Inhalt in Sonarpad-Dokumenten gespeichert.';

  @override
  String get preserveMediaError => 'Der Inhalt konnte nicht gespeichert werden.';

}
