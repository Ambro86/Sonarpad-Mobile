import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('it'),
    Locale('cs'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pl'),
    Locale('pt')
  ];

  /// Localized text for appTitle.
  ///
  /// In it, this message translates to:
  /// **'Sonarpad'**
  String get appTitle;

  /// Localized text for appLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua dell\'app'**
  String get appLanguage;

  /// Localized text for settingsTheme.
  ///
  /// In it, this message translates to:
  /// **'Tema app'**
  String get settingsTheme;

  /// Localized text for settingsThemeSystem.
  ///
  /// In it, this message translates to:
  /// **'Sistema'**
  String get settingsThemeSystem;

  /// Localized text for settingsThemeLight.
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get settingsThemeLight;

  /// Localized text for settingsThemeDark.
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get settingsThemeDark;

  /// Localized text for settingsWeatherTemperatureUnit.
  ///
  /// In it, this message translates to:
  /// **'Unità temperatura meteo'**
  String get settingsWeatherTemperatureUnit;

  /// Localized text for weatherTemperatureCelsius.
  ///
  /// In it, this message translates to:
  /// **'Celsius (°C)'**
  String get weatherTemperatureCelsius;

  /// Localized text for weatherTemperatureFahrenheit.
  ///
  /// In it, this message translates to:
  /// **'Fahrenheit (°F)'**
  String get weatherTemperatureFahrenheit;

  /// Localized text for homeSemanticsLabel.
  ///
  /// In it, this message translates to:
  /// **'Sonarpad, schermata principale'**
  String get homeSemanticsLabel;

  /// Localized text for settings.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settings;

  /// Localized text for settingsHint.
  ///
  /// In it, this message translates to:
  /// **'Apre le impostazioni'**
  String get settingsHint;

  /// Localized text for info.
  ///
  /// In it, this message translates to:
  /// **'Informazioni'**
  String get info;

  /// Localized text for infoHint.
  ///
  /// In it, this message translates to:
  /// **'Apre le informazioni sull\'app'**
  String get infoHint;

  /// Localized text for categoryReading.
  ///
  /// In it, this message translates to:
  /// **'Lettura e documenti'**
  String get categoryReading;

  /// Localized text for categoryMedia.
  ///
  /// In it, this message translates to:
  /// **'Media e intrattenimento'**
  String get categoryMedia;

  /// Localized text for categoryUtilities.
  ///
  /// In it, this message translates to:
  /// **'Ricerche e utilità'**
  String get categoryUtilities;

  /// Localized text for voiceDictionaryTitle.
  ///
  /// In it, this message translates to:
  /// **'Dizionario vocale'**
  String get voiceDictionaryTitle;

  /// Localized text for voiceDictionaryAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi voci al dizionario'**
  String get voiceDictionaryAdd;

  /// Localized text for voiceDictionaryOriginalWord.
  ///
  /// In it, this message translates to:
  /// **'Parola originale'**
  String get voiceDictionaryOriginalWord;

  /// Localized text for voiceDictionaryReplacementWord.
  ///
  /// In it, this message translates to:
  /// **'Parola sostitutiva'**
  String get voiceDictionaryReplacementWord;

  /// Localized text for voiceDictionaryMatchCase.
  ///
  /// In it, this message translates to:
  /// **'Distingui maiuscole e minuscole'**
  String get voiceDictionaryMatchCase;

  /// Localized text for voiceDictionaryIgnoreCase.
  ///
  /// In it, this message translates to:
  /// **'Ignora maiuscole e minuscole'**
  String get voiceDictionaryIgnoreCase;

  /// Localized text for voiceDictionaryEntries.
  ///
  /// In it, this message translates to:
  /// **'Voci del dizionario'**
  String get voiceDictionaryEntries;

  /// Localized text for voiceDictionaryEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna voce nel dizionario.'**
  String get voiceDictionaryEmpty;

  /// Localized text for voiceDictionaryRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi voce selezionata'**
  String get voiceDictionaryRemove;

  /// Localized text for voiceDictionaryOriginalRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la parola originale.'**
  String get voiceDictionaryOriginalRequired;

  /// Localized text for convertMediaTitle.
  ///
  /// In it, this message translates to:
  /// **'Converti media'**
  String get convertMediaTitle;

  /// Localized text for convertMediaInput.
  ///
  /// In it, this message translates to:
  /// **'File da convertire'**
  String get convertMediaInput;

  /// Localized text for convertMediaOutput.
  ///
  /// In it, this message translates to:
  /// **'Cartella di salvataggio'**
  String get convertMediaOutput;

  /// Localized text for convertMediaImage.
  ///
  /// In it, this message translates to:
  /// **'Immagine'**
  String get convertMediaImage;

  /// Localized text for convertMediaBrowse.
  ///
  /// In it, this message translates to:
  /// **'Sfoglia...'**
  String get convertMediaBrowse;

  /// Localized text for convertMediaFormat.
  ///
  /// In it, this message translates to:
  /// **'Formato'**
  String get convertMediaFormat;

  /// Localized text for convertMediaBitrate.
  ///
  /// In it, this message translates to:
  /// **'Bitrate (kbps)'**
  String get convertMediaBitrate;

  /// Localized text for convertMediaOggQuality.
  ///
  /// In it, this message translates to:
  /// **'Qualità (q)'**
  String get convertMediaOggQuality;

  /// Localized text for convertMediaFlacCompression.
  ///
  /// In it, this message translates to:
  /// **'Livello di compressione'**
  String get convertMediaFlacCompression;

  /// Localized text for convertMediaWavBitDepth.
  ///
  /// In it, this message translates to:
  /// **'Profondità bit WAV'**
  String get convertMediaWavBitDepth;

  /// Localized text for convertMediaReady.
  ///
  /// In it, this message translates to:
  /// **'Pronto.'**
  String get convertMediaReady;

  /// Localized text for convertMediaRunning.
  ///
  /// In it, this message translates to:
  /// **'Conversione in corso...'**
  String get convertMediaRunning;

  /// Localized text for convertMediaDone.
  ///
  /// In it, this message translates to:
  /// **'Conversione completata.'**
  String get convertMediaDone;

  /// Localized text for convertMediaButton.
  ///
  /// In it, this message translates to:
  /// **'Converti'**
  String get convertMediaButton;

  /// Localized text for convertMediaNoInput.
  ///
  /// In it, this message translates to:
  /// **'Seleziona un file da convertire.'**
  String get convertMediaNoInput;

  /// Localized text for convertMediaNoOutput.
  ///
  /// In it, this message translates to:
  /// **'Scegli una cartella di salvataggio.'**
  String get convertMediaNoOutput;

  /// Localized text for convertMediaOutputNotWritable.
  ///
  /// In it, this message translates to:
  /// **'La cartella scelta non è accessibile direttamente. Il file verrà salvato nella cartella interna di Sonarpad; al termine potrai condividerlo o salvarlo nell’app File.'**
  String get convertMediaOutputNotWritable;

  /// Localized text for convertMediaNoImage.
  ///
  /// In it, this message translates to:
  /// **'Seleziona un\'immagine per il video.'**
  String get convertMediaNoImage;

  /// Localized text for convertMediaSamePath.
  ///
  /// In it, this message translates to:
  /// **'Il file convertito deve essere diverso dal file sorgente.'**
  String get convertMediaSamePath;

  /// Localized text for convertMediaInvalidBitrate.
  ///
  /// In it, this message translates to:
  /// **'Bitrate non valido. Inserisci un valore tra 64 e 320 kbps.'**
  String get convertMediaInvalidBitrate;

  /// Localized text for convertMediaFailed.
  ///
  /// In it, this message translates to:
  /// **'Conversione non riuscita: {error}'**
  String convertMediaFailed(Object error);

  /// Localized text for donations.
  ///
  /// In it, this message translates to:
  /// **'Donazioni'**
  String get donations;

  /// Localized text for donationsHint.
  ///
  /// In it, this message translates to:
  /// **'Sostieni lo sviluppo di Sonarpad'**
  String get donationsHint;

  /// Localized text for loading.
  ///
  /// In it, this message translates to:
  /// **'Caricamento'**
  String get loading;

  /// Localized text for ttsVoiceLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua della voce TTS'**
  String get ttsVoiceLanguage;

  /// Localized text for ttsVoice.
  ///
  /// In it, this message translates to:
  /// **'Voce TTS'**
  String get ttsVoice;

  /// Localized text for saveSettings.
  ///
  /// In it, this message translates to:
  /// **'Salva impostazioni'**
  String get saveSettings;

  /// Localized text for settingsSaved.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni salvate.'**
  String get settingsSaved;

  /// Localized text for settingsSavedTitle.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni salvate'**
  String get settingsSavedTitle;

  /// Localized text for sonarpadCodeValidTitle.
  ///
  /// In it, this message translates to:
  /// **'Codice valido'**
  String get sonarpadCodeValidTitle;

  /// Localized text for sonarpadCodeValidMessage.
  ///
  /// In it, this message translates to:
  /// **'Il codice Sonarpad è corretto. Impostazioni salvate.'**
  String get sonarpadCodeValidMessage;

  /// Localized text for sonarpadCodeInvalidTitle.
  ///
  /// In it, this message translates to:
  /// **'Codice non valido'**
  String get sonarpadCodeInvalidTitle;

  /// Localized text for sonarpadCodeInvalidMessage.
  ///
  /// In it, this message translates to:
  /// **'Il codice Sonarpad inserito non è valido. Verifica di averlo copiato senza spazi aggiuntivi.'**
  String get sonarpadCodeInvalidMessage;

  /// Localized text for infoDescription.
  ///
  /// In it, this message translates to:
  /// **'Sonarpad è un’app semplice, ma ricca di funzioni. È pensata per essere accessibile con VoiceOver alle persone non vedenti e ipovedenti: permette di ascoltare le notizie, cercare podcast e iscriversi, importare articoli da Wikipedia, aggiungere documenti alla libreria, salvarli e modificarli. Sonarpad è in continuo aggiornamento e ogni funzione è progettata per rendere più semplice la vita quotidiana.'**
  String get infoDescription;

  /// Localized text for infoAuthor.
  ///
  /// In it, this message translates to:
  /// **'Autore: Ambrogio Riili'**
  String get infoAuthor;

  /// Localized text for donationsIntro.
  ///
  /// In it, this message translates to:
  /// **'Sonarpad è nato inizialmente per rispondere a esigenze personali, ma nel tempo è diventato un’app più completa. Il suo sviluppo richiede un lavoro costante: migliorare le funzionalità, correggere bug, cercare nuove idee e testare con attenzione ogni funzione.\n\nSe Sonarpad ti è utile e vuoi sostenerne lo sviluppo, puoi effettuare una donazione.'**
  String get donationsIntro;

  /// Localized text for donationsPaypalDesc.
  ///
  /// In it, this message translates to:
  /// **'Puoi donare tramite PayPal al seguente link:\nhttps://www.paypal.me/ambrogio86\nSe possibile, indica come causale “Sonarpad”.'**
  String get donationsPaypalDesc;

  /// Localized text for donationsBankDesc.
  ///
  /// In it, this message translates to:
  /// **'È possibile contribuire anche tramite bonifico bancario sul conto intestato a Ambrogio Riili.\nIBAN: IT77W0306901020100000064149\nSe possibile, indica una causale chiara, ad esempio “Sonarpad”.'**
  String get donationsBankDesc;

  /// Localized text for donationsThanks.
  ///
  /// In it, this message translates to:
  /// **'Chiunque decida di sostenere il progetto verrà ringraziato nell’app e nel repository GitHub, nella sezione sostenitori, salvo richiesta di anonimato o utilizzo di un nickname.\n\nRingrazio Jiri Holzinger e Paola Vagata per il loro contributo.\nPer la traduzione in ceco ringrazio Radek Žalud e Jiri Holzinger.\nPer la traduzione in spagnolo ringrazio Arturo Fernandez Rivas.'**
  String get donationsThanks;

  /// Localized text for news.
  ///
  /// In it, this message translates to:
  /// **'Notizie'**
  String get news;

  /// Localized text for newsHint.
  ///
  /// In it, this message translates to:
  /// **'Apre le notizie da Google News RSS'**
  String get newsHint;

  /// Localized text for podcasts.
  ///
  /// In it, this message translates to:
  /// **'Podcast'**
  String get podcasts;

  /// Localized text for podcastsHint.
  ///
  /// In it, this message translates to:
  /// **'Iscriviti ai podcast, riproduci o scarica episodi'**
  String get podcastsHint;

  /// Localized text for importFromWikipedia.
  ///
  /// In it, this message translates to:
  /// **'Wikipedia'**
  String get importFromWikipedia;

  /// Localized text for wikipediaHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca un articolo Wikipedia e importa il testo'**
  String get wikipediaHint;

  /// Localized text for newsCategoryTop.
  ///
  /// In it, this message translates to:
  /// **'Principali'**
  String get newsCategoryTop;

  /// Localized text for settingsHomeGrouping.
  ///
  /// In it, this message translates to:
  /// **'Attiva il raggruppamento delle icone in categorie'**
  String get settingsHomeGrouping;

  /// Localized text for settingsHomeGroupingHint.
  ///
  /// In it, this message translates to:
  /// **'Se disattivato, le icone principali saranno mostrate come elenco singolo senza sottocartelle'**
  String get settingsHomeGroupingHint;

  /// Localized text for newsCategoryMyCity.
  ///
  /// In it, this message translates to:
  /// **'La mia città'**
  String get newsCategoryMyCity;

  /// Localized text for newsLocalCityLabel.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la tua città'**
  String get newsLocalCityLabel;

  /// Localized text for newsLocalCityHint.
  ///
  /// In it, this message translates to:
  /// **'Correggi la città usata per le notizie locali'**
  String get newsLocalCityHint;

  /// Localized text for update.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get update;

  /// Localized text for moveUp.
  ///
  /// In it, this message translates to:
  /// **'Sposta in alto'**
  String get moveUp;

  /// Localized text for moveDown.
  ///
  /// In it, this message translates to:
  /// **'Sposta in basso'**
  String get moveDown;

  /// Localized text for hide.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get hide;

  /// Localized text for moveToPosition.
  ///
  /// In it, this message translates to:
  /// **'Sposta alla posizione'**
  String get moveToPosition;

  /// Localized text for positionLabel.
  ///
  /// In it, this message translates to:
  /// **'Posizione {position}: prima di {targetName}'**
  String positionLabel(int position, String targetName);

  /// Localized text for positionLabelLast.
  ///
  /// In it, this message translates to:
  /// **'Ultima posizione'**
  String get positionLabelLast;

  /// Localized text for restoreHiddenSources.
  ///
  /// In it, this message translates to:
  /// **'Ripristina testate eliminate'**
  String get restoreHiddenSources;

  /// Localized text for addCustomNewsSource.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi sorgente RSS personalizzata'**
  String get addCustomNewsSource;

  /// Localized text for newsSourceName.
  ///
  /// In it, this message translates to:
  /// **'Nome testata/sito'**
  String get newsSourceName;

  /// Localized text for newsSourceUrlOrSearch.
  ///
  /// In it, this message translates to:
  /// **'URL sito, feed RSS o parola di ricerca'**
  String get newsSourceUrlOrSearch;

  /// Localized text for deleteNewsSource.
  ///
  /// In it, this message translates to:
  /// **'Elimina sorgente'**
  String get deleteNewsSource;

  /// Localized text for importRssSourcesFromOpml.
  ///
  /// In it, this message translates to:
  /// **'Importa sorgenti RSS da OPML'**
  String get importRssSourcesFromOpml;

  /// Localized text for exportRssSourcesToOpml.
  ///
  /// In it, this message translates to:
  /// **'Esporta sorgenti RSS in OPML'**
  String get exportRssSourcesToOpml;

  /// Localized text for rssImportComplete.
  ///
  /// In it, this message translates to:
  /// **'Sorgenti RSS importate: {count}'**
  String rssImportComplete(int count);

  /// Localized text for rssImportError.
  ///
  /// In it, this message translates to:
  /// **'Errore importazione RSS: {error}'**
  String rssImportError(Object error);

  /// Localized text for rssExportComplete.
  ///
  /// In it, this message translates to:
  /// **'Sorgenti RSS esportate'**
  String get rssExportComplete;

  /// Localized text for rssExportError.
  ///
  /// In it, this message translates to:
  /// **'Errore esportazione RSS: {error}'**
  String rssExportError(Object error);

  /// Localized text for articleTextSemantics.
  ///
  /// In it, this message translates to:
  /// **'Testo articolo'**
  String get articleTextSemantics;

  /// Localized text for newsLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua notizie'**
  String get newsLanguage;

  /// Localized text for loadingNews.
  ///
  /// In it, this message translates to:
  /// **'Caricamento notizie'**
  String get loadingNews;

  /// Localized text for error.
  ///
  /// In it, this message translates to:
  /// **'Errore: {error}'**
  String error(Object error);

  /// Localized text for noNewsFound.
  ///
  /// In it, this message translates to:
  /// **'Nessuna notizia trovata'**
  String get noNewsFound;

  /// Localized text for loadingArticle.
  ///
  /// In it, this message translates to:
  /// **'Caricamento articolo'**
  String get loadingArticle;

  /// Localized text for noFullArticleFound.
  ///
  /// In it, this message translates to:
  /// **'Articolo integrale non disponibile. Mostro il riassunto del feed.'**
  String get noFullArticleFound;

  /// Localized text for italian.
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get italian;

  /// Localized text for english.
  ///
  /// In it, this message translates to:
  /// **'Inglese'**
  String get english;

  /// Localized text for french.
  ///
  /// In it, this message translates to:
  /// **'Francese'**
  String get french;

  /// Localized text for spanish.
  ///
  /// In it, this message translates to:
  /// **'Spagnolo'**
  String get spanish;

  /// Localized text for newsSource.
  ///
  /// In it, this message translates to:
  /// **'Fonte notizie'**
  String get newsSource;

  /// Localized text for article.
  ///
  /// In it, this message translates to:
  /// **'Articolo'**
  String get article;

  /// Localized text for articlePreview.
  ///
  /// In it, this message translates to:
  /// **'Anteprima articolo'**
  String get articlePreview;

  /// Localized text for readFullArticle.
  ///
  /// In it, this message translates to:
  /// **'Leggi articolo completo'**
  String get readFullArticle;

  /// Localized text for extractingReaderArticleText.
  ///
  /// In it, this message translates to:
  /// **'Estraggo il testo in modalità lettura...'**
  String get extractingReaderArticleText;

  /// Localized text for extractingVisibleArticleText.
  ///
  /// In it, this message translates to:
  /// **'Estraggo il testo visibile dalla pagina...'**
  String get extractingVisibleArticleText;

  /// Localized text for source.
  ///
  /// In it, this message translates to:
  /// **'Fonte: {source}'**
  String source(String source);

  /// Localized text for readyStatus.
  ///
  /// In it, this message translates to:
  /// **'Pronto.'**
  String get readyStatus;

  /// Localized text for preparingEdgeTts.
  ///
  /// In it, this message translates to:
  /// **'Preparo lettura Edge TTS a blocchi...'**
  String get preparingEdgeTts;

  /// Localized text for noTextToRead.
  ///
  /// In it, this message translates to:
  /// **'Nessun testo da leggere.'**
  String get noTextToRead;

  /// Localized text for chunkCreated.
  ///
  /// In it, this message translates to:
  /// **'Blocco {index} di {total} creato. Lettura in corso...'**
  String chunkCreated(int index, int total);

  /// Localized text for playingChunk.
  ///
  /// In it, this message translates to:
  /// **'Riproduco blocco {index} di {total} ({size} byte)...'**
  String playingChunk(int index, int total, int size);

  /// Localized text for readingFinished.
  ///
  /// In it, this message translates to:
  /// **'Lettura terminata. Blocchi creati: {readyChunks}/{totalChunks}. Libreria: {libraryPath}'**
  String readingFinished(int readyChunks, int totalChunks, String libraryPath);

  /// Localized text for libraryNotSpecified.
  ///
  /// In it, this message translates to:
  /// **'non indicata'**
  String get libraryNotSpecified;

  /// Localized text for readingStopped.
  ///
  /// In it, this message translates to:
  /// **'Lettura interrotta.'**
  String get readingStopped;

  /// Localized text for edgeTtsError.
  ///
  /// In it, this message translates to:
  /// **'Errore Edge TTS: {error}'**
  String edgeTtsError(Object error);

  /// Localized text for audioChunksReady.
  ///
  /// In it, this message translates to:
  /// **'Blocchi audio pronti: {readyChunks} / {totalChunks}'**
  String audioChunksReady(int readyChunks, int totalChunks);

  /// Localized text for readingInProgress.
  ///
  /// In it, this message translates to:
  /// **'Lettura in corso...'**
  String get readingInProgress;

  /// Localized text for readWithEdgeTts.
  ///
  /// In it, this message translates to:
  /// **'Avvia lettura'**
  String get readWithEdgeTts;

  /// Localized text for stopReading.
  ///
  /// In it, this message translates to:
  /// **'Interrompi lettura'**
  String get stopReading;

  /// Localized text for startReading.
  ///
  /// In it, this message translates to:
  /// **'Avvia lettura'**
  String get startReading;

  /// Localized text for resumeReading.
  ///
  /// In it, this message translates to:
  /// **'Riprendi lettura'**
  String get resumeReading;

  /// Localized text for pauseReading.
  ///
  /// In it, this message translates to:
  /// **'Pausa lettura'**
  String get pauseReading;

  /// Localized text for openOriginalArticle.
  ///
  /// In it, this message translates to:
  /// **'Apri articolo originale'**
  String get openOriginalArticle;

  /// Localized text for searchPodcasts.
  ///
  /// In it, this message translates to:
  /// **'Cerca podcast'**
  String get searchPodcasts;

  /// Localized text for podcastName.
  ///
  /// In it, this message translates to:
  /// **'Nome podcast'**
  String get podcastName;

  /// Localized text for podcastSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Esempio: tecnologia, storia, il nome del podcast...'**
  String get podcastSearchHint;

  /// Localized text for searchCountry.
  ///
  /// In it, this message translates to:
  /// **'Paese di ricerca'**
  String get searchCountry;

  /// Localized text for browsePodcastCountries.
  ///
  /// In it, this message translates to:
  /// **'Sfoglia per nazione'**
  String get browsePodcastCountries;

  /// Localized text for podcastCountries.
  ///
  /// In it, this message translates to:
  /// **'Nazioni podcast'**
  String get podcastCountries;

  /// Localized text for podcastCategory.
  ///
  /// In it, this message translates to:
  /// **'Categoria podcast'**
  String get podcastCategory;

  /// Localized text for browsePodcastCategories.
  ///
  /// In it, this message translates to:
  /// **'Sfoglia categorie'**
  String get browsePodcastCategories;

  /// Localized text for selectedPodcastCategory.
  ///
  /// In it, this message translates to:
  /// **'Categoria selezionata'**
  String get selectedPodcastCategory;

  /// Label appended to the most recently selected podcast country or category.
  ///
  /// In it, this message translates to:
  /// **'scelta recente'**
  String get selectedRecently;

  /// Localized text for podcastCategories.
  ///
  /// In it, this message translates to:
  /// **'Categorie podcast'**
  String get podcastCategories;

  /// Localized text for countryItaly.
  ///
  /// In it, this message translates to:
  /// **'Italia'**
  String get countryItaly;

  /// Localized text for countryUnitedStatesEnglish.
  ///
  /// In it, this message translates to:
  /// **'Stati Uniti / inglese'**
  String get countryUnitedStatesEnglish;

  /// Localized text for countryUnitedKingdom.
  ///
  /// In it, this message translates to:
  /// **'Regno Unito'**
  String get countryUnitedKingdom;

  /// Localized text for countrySpain.
  ///
  /// In it, this message translates to:
  /// **'Spagna'**
  String get countrySpain;

  /// Localized text for countryFrance.
  ///
  /// In it, this message translates to:
  /// **'Francia'**
  String get countryFrance;

  /// Localized text for searchInProgress.
  ///
  /// In it, this message translates to:
  /// **'Ricerca in corso...'**
  String get searchInProgress;

  /// No description provided for @newsReadArticles.
  ///
  /// In it, this message translates to:
  /// **'Articoli letti'**
  String get newsReadArticles;

  /// No description provided for @weatherRecentCities.
  ///
  /// In it, this message translates to:
  /// **'Città recenti'**
  String get weatherRecentCities;

  /// Localized text for podcastResultsFound.
  ///
  /// In it, this message translates to:
  /// **'Trovati {count} podcast'**
  String podcastResultsFound(int count);

  /// Localized text for podcastSearchError.
  ///
  /// In it, this message translates to:
  /// **'Errore ricerca podcast: {error}'**
  String podcastSearchError(Object error);

  /// Localized text for subscribedTo.
  ///
  /// In it, this message translates to:
  /// **'Iscritto a {title}'**
  String subscribedTo(String title);

  /// Localized text for subscriptionError.
  ///
  /// In it, this message translates to:
  /// **'Errore iscrizione: {error}'**
  String subscriptionError(Object error);

  /// Localized text for podcastSubscriptionError.
  ///
  /// In it, this message translates to:
  /// **'Errore iscrizione podcast: {error}'**
  String podcastSubscriptionError(Object error);

  /// Localized text for searchResults.
  ///
  /// In it, this message translates to:
  /// **'Risultati ricerca'**
  String get searchResults;

  /// Localized text for podcastInfo.
  ///
  /// In it, this message translates to:
  /// **'Informazioni sul podcast'**
  String get podcastInfo;

  /// Localized text for subscribe.
  ///
  /// In it, this message translates to:
  /// **'Iscriviti'**
  String get subscribe;

  /// Localized text for openPodcast.
  ///
  /// In it, this message translates to:
  /// **'Apri podcast'**
  String get openPodcast;

  /// Localized text for viewEpisodes.
  ///
  /// In it, this message translates to:
  /// **'Vedi episodi'**
  String get viewEpisodes;

  /// Localized text for podcastAuthor.
  ///
  /// In it, this message translates to:
  /// **'Autore'**
  String get podcastAuthor;

  /// Localized text for noPodcastDescription.
  ///
  /// In it, this message translates to:
  /// **'Nessuna descrizione disponibile.'**
  String get noPodcastDescription;

  /// Localized text for noPodcastResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun podcast trovato.'**
  String get noPodcastResults;

  /// Localized text for loadingPodcastInfo.
  ///
  /// In it, this message translates to:
  /// **'Caricamento info podcast'**
  String get loadingPodcastInfo;

  /// Localized text for podcastArtwork.
  ///
  /// In it, this message translates to:
  /// **'Copertina podcast'**
  String get podcastArtwork;

  /// Localized text for addFeedUrlManually.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi manualmente URL feed RSS'**
  String get addFeedUrlManually;

  /// Localized text for podcastFeedUrl.
  ///
  /// In it, this message translates to:
  /// **'URL feed podcast RSS'**
  String get podcastFeedUrl;

  /// Localized text for subscribeFromUrl.
  ///
  /// In it, this message translates to:
  /// **'Iscriviti da URL'**
  String get subscribeFromUrl;

  /// Localized text for subscribedPodcasts.
  ///
  /// In it, this message translates to:
  /// **'Podcast sottoscritti'**
  String get subscribedPodcasts;

  /// Localized text for noSubscribedPodcasts.
  ///
  /// In it, this message translates to:
  /// **'Nessun podcast sottoscritto. Cerca un podcast e tocca un risultato per iscriverti.'**
  String get noSubscribedPodcasts;

  /// Localized text for localAudioFiles.
  ///
  /// In it, this message translates to:
  /// **'File audio locali'**
  String get localAudioFiles;

  /// Localized text for noLocalAudioFiles.
  ///
  /// In it, this message translates to:
  /// **'Nessun file audio locale trovato.'**
  String get noLocalAudioFiles;

  /// Localized text for importAudioFromITunes.
  ///
  /// In it, this message translates to:
  /// **'Importa file audio locali'**
  String get importAudioFromITunes;

  /// Localized text for localAudioFilesFound.
  ///
  /// In it, this message translates to:
  /// **'File audio locali trovati: {count}'**
  String localAudioFilesFound(int count);

  /// Localized text for importPodcastsFromFile.
  ///
  /// In it, this message translates to:
  /// **'Importa podcast da file'**
  String get importPodcastsFromFile;

  /// Localized text for exportPodcastsToFile.
  ///
  /// In it, this message translates to:
  /// **'Esporta podcast in file OPML'**
  String get exportPodcastsToFile;

  /// Localized text for podcastImportComplete.
  ///
  /// In it, this message translates to:
  /// **'Podcast importati: {count}'**
  String podcastImportComplete(int count);

  /// Localized text for podcastImportError.
  ///
  /// In it, this message translates to:
  /// **'Errore importazione podcast: {error}'**
  String podcastImportError(Object error);

  /// Shown when the selected podcast import file is not an OPML or XML file.
  ///
  /// In it, this message translates to:
  /// **'File non valido. Seleziona un file OPML o XML.'**
  String get podcastInvalidOpmlFile;

  /// Localized text for podcastExportComplete.
  ///
  /// In it, this message translates to:
  /// **'Podcast esportati'**
  String get podcastExportComplete;

  /// Localized text for podcastExportError.
  ///
  /// In it, this message translates to:
  /// **'Errore esportazione podcast: {error}'**
  String podcastExportError(Object error);

  /// Localized text for loadingEpisodes.
  ///
  /// In it, this message translates to:
  /// **'Caricamento episodi'**
  String get loadingEpisodes;

  /// Localized text for noAudioEpisodesFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun episodio audio trovato nel feed.'**
  String get noAudioEpisodesFound;

  /// Localized text for episodes.
  ///
  /// In it, this message translates to:
  /// **'Episodi'**
  String get episodes;

  /// Localized text for episodeActions.
  ///
  /// In it, this message translates to:
  /// **'Azioni episodio'**
  String get episodeActions;

  /// Localized text for downloaded.
  ///
  /// In it, this message translates to:
  /// **'Scaricato: {path}'**
  String downloaded(String path);

  /// Localized text for episodeError.
  ///
  /// In it, this message translates to:
  /// **'Errore episodio: {error}'**
  String episodeError(Object error);

  /// Localized text for play.
  ///
  /// In it, this message translates to:
  /// **'Riproduci'**
  String get play;

  /// Localized text for pause.
  ///
  /// In it, this message translates to:
  /// **'Pausa'**
  String get pause;

  /// Localized text for rewind15s.
  ///
  /// In it, this message translates to:
  /// **'Indietro 15s'**
  String get rewind15s;

  /// Localized text for forward15s.
  ///
  /// In it, this message translates to:
  /// **'Avanti 15s'**
  String get forward15s;

  /// Localized text for stop.
  ///
  /// In it, this message translates to:
  /// **'Stop'**
  String get stop;

  /// Localized text for back.
  ///
  /// In it, this message translates to:
  /// **'Indietro'**
  String get back;

  /// Localized text for episodePlayer.
  ///
  /// In it, this message translates to:
  /// **'Lettore episodio'**
  String get episodePlayer;

  /// Localized text for nowPlayingTitle.
  ///
  /// In it, this message translates to:
  /// **'In riproduzione: {title}'**
  String nowPlayingTitle(String title);

  /// Localized text for loadingEpisodeAudio.
  ///
  /// In it, this message translates to:
  /// **'Caricamento audio episodio'**
  String get loadingEpisodeAudio;

  /// Localized text for playbackPosition.
  ///
  /// In it, this message translates to:
  /// **'Posizione'**
  String get playbackPosition;

  /// Localized text for playbackPositionValue.
  ///
  /// In it, this message translates to:
  /// **'{position} di {duration}'**
  String playbackPositionValue(String position, String duration);

  /// Accessibility label for the media volume slider.
  ///
  /// In it, this message translates to:
  /// **'Regola il volume'**
  String get adjustVolume;

  /// Visible media volume percentage.
  ///
  /// In it, this message translates to:
  /// **'Volume: {percentage}%'**
  String volumeValue(int percentage);

  /// Localized text for download.
  ///
  /// In it, this message translates to:
  /// **'Scarica'**
  String get download;

  /// Localized text for searchWikipedia.
  ///
  /// In it, this message translates to:
  /// **'Cerca su Wikipedia'**
  String get searchWikipedia;

  /// Localized text for wikipediaLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua Wikipedia'**
  String get wikipediaLanguage;

  /// Localized text for search.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get search;

  /// Localized text for wikipediaSearch.
  ///
  /// In it, this message translates to:
  /// **'Ricerca Wikipedia'**
  String get wikipediaSearch;

  /// Localized text for wikipediaImporting.
  ///
  /// In it, this message translates to:
  /// **'Importazione Wikipedia'**
  String get wikipediaImporting;

  /// Localized text for noWikipediaResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato Wikipedia trovato'**
  String get noWikipediaResults;

  /// Localized text for wikipediaImportMode.
  ///
  /// In it, this message translates to:
  /// **'Modalità di importazione'**
  String get wikipediaImportMode;

  /// Localized text for wikipediaImportWholeArticle.
  ///
  /// In it, this message translates to:
  /// **'Tutto l\'articolo'**
  String get wikipediaImportWholeArticle;

  /// Localized text for documents.
  ///
  /// In it, this message translates to:
  /// **'Documenti'**
  String get documents;

  /// Localized text for documentsHint.
  ///
  /// In it, this message translates to:
  /// **'Apre la libreria documenti'**
  String get documentsHint;

  /// Localized text for documentLibrary.
  ///
  /// In it, this message translates to:
  /// **'Libreria documenti'**
  String get documentLibrary;

  /// Localized text for addToLibrary.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi alla libreria'**
  String get addToLibrary;

  /// Localized text for documentImportSelectionMode.
  ///
  /// In it, this message translates to:
  /// **'Vuoi selezionare un solo documento o più documenti?'**
  String get documentImportSelectionMode;

  /// Localized text for documentImportSingle.
  ///
  /// In it, this message translates to:
  /// **'Un documento'**
  String get documentImportSingle;

  /// Localized text for documentImportMultiple.
  ///
  /// In it, this message translates to:
  /// **'Più documenti'**
  String get documentImportMultiple;

  /// Localized text for noDocuments.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento. Aggiungi un file.'**
  String get noDocuments;

  /// Localized text for noDocumentsInLibrary.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento presente nella libreria.'**
  String get noDocumentsInLibrary;

  /// Localized text for documentAdded.
  ///
  /// In it, this message translates to:
  /// **'Documento aggiunto'**
  String get documentAdded;

  /// Localized text for documentsAdded.
  ///
  /// In it, this message translates to:
  /// **'Documenti aggiunti'**
  String get documentsAdded;

  /// Localized text for importDocumentsFromITunes.
  ///
  /// In it, this message translates to:
  /// **'Importa documenti da iTunes / Apple Devices'**
  String get importDocumentsFromITunes;

  /// Localized text for sharedDocumentsImportComplete.
  ///
  /// In it, this message translates to:
  /// **'Documenti importati da iTunes / Apple Devices: {count}'**
  String sharedDocumentsImportComplete(int count);

  /// Localized text for libraryLoadError.
  ///
  /// In it, this message translates to:
  /// **'Errore caricamento libreria: {error}'**
  String libraryLoadError(Object error);

  /// Localized text for fileOpenError.
  ///
  /// In it, this message translates to:
  /// **'Errore apertura file: {error}'**
  String fileOpenError(Object error);

  /// Localized text for filePathUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Percorso file non disponibile.'**
  String get filePathUnavailable;

  /// Localized text for fileInaccessible.
  ///
  /// In it, this message translates to:
  /// **'File inaccessibile: {name}'**
  String fileInaccessible(String name);

  /// Localized text for documentAddError.
  ///
  /// In it, this message translates to:
  /// **'Errore aggiunta documento: {error}'**
  String documentAddError(Object error);

  /// Localized text for documentRemoveError.
  ///
  /// In it, this message translates to:
  /// **'Errore rimozione: {error}'**
  String documentRemoveError(Object error);

  /// Localized text for noExportableTextFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun testo esportabile trovato.'**
  String get noExportableTextFound;

  /// Localized text for modifiedDocumentNoExportableText.
  ///
  /// In it, this message translates to:
  /// **'Il documento modificato non contiene testo esportabile.'**
  String get modifiedDocumentNoExportableText;

  /// Localized text for documentRemoved.
  ///
  /// In it, this message translates to:
  /// **'Documento rimosso'**
  String get documentRemoved;

  /// Localized text for folderRemoved.
  ///
  /// In it, this message translates to:
  /// **'Cartella rimossa'**
  String get folderRemoved;

  /// Localized text for removeFolder.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi cartella'**
  String get removeFolder;

  /// Localized text for removeDocument.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi documento'**
  String get removeDocument;

  /// Localized text for writeNewDocument.
  ///
  /// In it, this message translates to:
  /// **'Scrivi nuovo documento'**
  String get writeNewDocument;

  /// Localized text for addDocumentToLibraryHint.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi documento alla libreria. Sfoglia i file del dispositivo e aggiungili.'**
  String get addDocumentToLibraryHint;

  /// Localized text for documentTypeLabel.
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get documentTypeLabel;

  /// Localized text for documentPosition.
  ///
  /// In it, this message translates to:
  /// **'Posizione documento'**
  String get documentPosition;

  /// Localized text for folderTypeLabel.
  ///
  /// In it, this message translates to:
  /// **'Cartella'**
  String get folderTypeLabel;

  /// Localized text for documentAddedOn.
  ///
  /// In it, this message translates to:
  /// **'aggiunto il {date}'**
  String documentAddedOn(String date);

  /// Localized text for documentTypeDescription.
  ///
  /// In it, this message translates to:
  /// **'tipo {extension}'**
  String documentTypeDescription(String extension);

  /// Localized text for openFolderHint.
  ///
  /// In it, this message translates to:
  /// **'Tocca due volte per aprire la cartella'**
  String get openFolderHint;

  /// Localized text for openDocumentHint.
  ///
  /// In it, this message translates to:
  /// **'Tocca due volte per aprire e leggere il documento'**
  String get openDocumentHint;

  /// Localized text for removeItem.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi {name}'**
  String removeItem(String name);

  /// Localized text for removePodcast.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi podcast'**
  String get removePodcast;

  /// Localized text for podcastRemoved.
  ///
  /// In it, this message translates to:
  /// **'Podcast rimosso'**
  String get podcastRemoved;

  /// Localized text for documentPickerError.
  ///
  /// In it, this message translates to:
  /// **'Errore apertura file'**
  String get documentPickerError;

  /// Localized text for readDocument.
  ///
  /// In it, this message translates to:
  /// **'Leggi documento'**
  String get readDocument;

  /// Localized text for documentReaderTitle.
  ///
  /// In it, this message translates to:
  /// **'Lettore documento'**
  String get documentReaderTitle;

  /// Localized text for documentReaderEditHint.
  ///
  /// In it, this message translates to:
  /// **'Tocca un paragrafo per modificarlo. Scorri verso l’alto o verso il basso per aggiungere un segnalibro.'**
  String get documentReaderEditHint;

  /// Localized text for documentBookmarkHintSet.
  ///
  /// In it, this message translates to:
  /// **'Scorri verso l’alto o verso il basso per impostare un segnalibro.'**
  String get documentBookmarkHintSet;

  /// Localized text for documentEditParagraphActionHint.
  ///
  /// In it, this message translates to:
  /// **'Tocca due volte per modificare questo paragrafo. '**
  String get documentEditParagraphActionHint;

  /// Localized text for documentBookmarkHintReplace.
  ///
  /// In it, this message translates to:
  /// **'Scorri verso l’alto o verso il basso per rimuovere il segnalibro esistente o sostituirlo con questo paragrafo.'**
  String get documentBookmarkHintReplace;

  /// Localized text for documentSetBookmarkAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi nuovo segnalibro'**
  String get documentSetBookmarkAction;

  /// Localized text for documentRemoveBookmarkAction.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi segnalibro'**
  String get documentRemoveBookmarkAction;

  /// Localized text for documentReplaceBookmarkAction.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi e aggiungi un nuovo segnalibro'**
  String get documentReplaceBookmarkAction;

  /// Localized text for searchInDocument.
  ///
  /// In it, this message translates to:
  /// **'Cerca nel documento'**
  String get searchInDocument;

  /// Localized text for documentIndex.
  ///
  /// In it, this message translates to:
  /// **'Indice'**
  String get documentIndex;

  /// Localized text for documentSearchFieldLabel.
  ///
  /// In it, this message translates to:
  /// **'Testo da cercare'**
  String get documentSearchFieldLabel;

  /// Localized text for documentSearchFieldHint.
  ///
  /// In it, this message translates to:
  /// **'Parola o frase da trovare'**
  String get documentSearchFieldHint;

  /// Localized text for documentSearchEmptyQuery.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il testo da cercare.'**
  String get documentSearchEmptyQuery;

  /// Localized text for documentSearchResultsTitle.
  ///
  /// In it, this message translates to:
  /// **'Risultati ricerca nel documento'**
  String get documentSearchResultsTitle;

  /// Localized text for noDocumentSearchResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato trovato per {query}.'**
  String noDocumentSearchResults(String query);

  /// Localized text for documentSearchResultParagraph.
  ///
  /// In it, this message translates to:
  /// **'Paragrafo {number}'**
  String documentSearchResultParagraph(int number);

  /// Localized text for edit.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get edit;

  /// Localized text for save.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get save;

  /// Localized text for cancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancel;

  /// Localized text for settingsReadingEngine.
  ///
  /// In it, this message translates to:
  /// **'Motore di lettura'**
  String get settingsReadingEngine;

  /// Localized text for settingsEdgeTtsQuality.
  ///
  /// In it, this message translates to:
  /// **'Edge TTS (Alta qualità online)'**
  String get settingsEdgeTtsQuality;

  /// Localized text for settingsSystemVoices.
  ///
  /// In it, this message translates to:
  /// **'Voci di sistema (VoiceOver / Google)'**
  String get settingsSystemVoices;

  /// Localized text for settingsNoSystemVoices.
  ///
  /// In it, this message translates to:
  /// **'Nessuna voce di sistema disponibile.'**
  String get settingsNoSystemVoices;

  /// Localized text for settingsDefaultVoiceHint.
  ///
  /// In it, this message translates to:
  /// **'Voce predefinita'**
  String get settingsDefaultVoiceHint;

  /// Localized text for settingsDefaultVoice.
  ///
  /// In it, this message translates to:
  /// **'Predefinita'**
  String get settingsDefaultVoice;

  /// Localized text for settingsVoiceSpeed.
  ///
  /// In it, this message translates to:
  /// **'Velocità lettura: '**
  String get settingsVoiceSpeed;

  /// Localized text for settingsVoicePitch.
  ///
  /// In it, this message translates to:
  /// **'Tono: '**
  String get settingsVoicePitch;

  /// Localized text for settingsVoiceSpeedLabel.
  ///
  /// In it, this message translates to:
  /// **'Velocità lettura'**
  String get settingsVoiceSpeedLabel;

  /// Localized text for settingsVoicePitchLabel.
  ///
  /// In it, this message translates to:
  /// **'Tono'**
  String get settingsVoicePitchLabel;

  /// Localized text for settingsTestVoice.
  ///
  /// In it, this message translates to:
  /// **'Testa voce'**
  String get settingsTestVoice;

  /// Localized text for settingsTestingVoice.
  ///
  /// In it, this message translates to:
  /// **'Riproduzione in corso...'**
  String get settingsTestingVoice;

  /// Localized text for settingsVoiceTestText.
  ///
  /// In it, this message translates to:
  /// **'Questo è un test della voce selezionata.'**
  String get settingsVoiceTestText;

  /// Localized text for settingsVoiceTestError.
  ///
  /// In it, this message translates to:
  /// **'Errore test voce: {error}'**
  String settingsVoiceTestError(Object error);

  /// Localized text for settingsVoiceSaveError.
  ///
  /// In it, this message translates to:
  /// **'Errore salvataggio voce TTS: {error}'**
  String settingsVoiceSaveError(Object error);

  /// Localized text for settingsUnsavedTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifiche non salvate'**
  String get settingsUnsavedTitle;

  /// Localized text for settingsUnsavedMessage.
  ///
  /// In it, this message translates to:
  /// **'Vuoi salvare le modifiche prima di uscire dalle impostazioni?'**
  String get settingsUnsavedMessage;

  /// Localized text for settingsExitWithoutSaving.
  ///
  /// In it, this message translates to:
  /// **'Esci senza salvare'**
  String get settingsExitWithoutSaving;

  /// Localized text for settingsSystemLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua di sistema'**
  String get settingsSystemLanguage;

  /// Localized text for settingsSystemVoice.
  ///
  /// In it, this message translates to:
  /// **'Voce di sistema'**
  String get settingsSystemVoice;

  /// Localized text for settingsAutoBookmark.
  ///
  /// In it, this message translates to:
  /// **'Segnalibro automatico'**
  String get settingsAutoBookmark;

  /// Localized text for settingsAutoBookmarkHint.
  ///
  /// In it, this message translates to:
  /// **'Riprendi documenti, podcast, RaiPlay e audiodescrizioni dal punto interrotto.'**
  String get settingsAutoBookmarkHint;

  /// Localized text for settingsDocumentSliderStep.
  ///
  /// In it, this message translates to:
  /// **'Intervallo slider documenti'**
  String get settingsDocumentSliderStep;

  /// Localized text for settingsDocumentSliderStepHint.
  ///
  /// In it, this message translates to:
  /// **'Regola di quanto avanza o arretra il cursore della posizione documento con il flick verso l’alto o verso il basso.'**
  String get settingsDocumentSliderStepHint;

  /// Localized text for settingsSeekStep.
  ///
  /// In it, this message translates to:
  /// **'Intervallo indietro / avanti nei media'**
  String get settingsSeekStep;

  /// Localized text for aiChatIntro.
  ///
  /// In it, this message translates to:
  /// **'Sono l’intelligenza artificiale di Sonarpad. Come posso aiutarti?'**
  String get aiChatIntro;

  /// Localized text for meteoTitle.
  ///
  /// In it, this message translates to:
  /// **'Meteo'**
  String get meteoTitle;

  /// Localized text for weatherCity.
  ///
  /// In it, this message translates to:
  /// **'Città'**
  String get weatherCity;

  /// Localized text for weatherCityHint.
  ///
  /// In it, this message translates to:
  /// **'Esempio: Roma'**
  String get weatherCityHint;

  /// Localized text for weatherCityNotFound.
  ///
  /// In it, this message translates to:
  /// **'Città non trovata'**
  String get weatherCityNotFound;

  /// Localized text for weatherSearchError.
  ///
  /// In it, this message translates to:
  /// **'Errore durante la ricerca'**
  String get weatherSearchError;

  /// Localized text for weatherToday.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get weatherToday;

  /// Localized text for weatherCurrentSituation.
  ///
  /// In it, this message translates to:
  /// **'Situazione attuale'**
  String get weatherCurrentSituation;

  /// Localized text for weatherTomorrow.
  ///
  /// In it, this message translates to:
  /// **'Domani'**
  String get weatherTomorrow;

  /// Localized text for weatherChooseDay.
  ///
  /// In it, this message translates to:
  /// **'Scegli il giorno'**
  String get weatherChooseDay;

  /// Localized text for weatherCurrentTemperature.
  ///
  /// In it, this message translates to:
  /// **'Temperatura attuale'**
  String get weatherCurrentTemperature;

  /// Localized text for weatherMaxTemperature.
  ///
  /// In it, this message translates to:
  /// **'Temperatura massima'**
  String get weatherMaxTemperature;

  /// Localized text for weatherMinTemperature.
  ///
  /// In it, this message translates to:
  /// **'Temperatura minima'**
  String get weatherMinTemperature;

  /// Localized text for weatherPrecipitation.
  ///
  /// In it, this message translates to:
  /// **'Precipitazioni'**
  String get weatherPrecipitation;

  /// Localized text for weatherPrecipitationProbability.
  ///
  /// In it, this message translates to:
  /// **'Probabilità di precipitazioni'**
  String get weatherPrecipitationProbability;

  /// Localized text for weatherWind.
  ///
  /// In it, this message translates to:
  /// **'Vento'**
  String get weatherWind;

  /// Localized text for weatherRelativeHumidity.
  ///
  /// In it, this message translates to:
  /// **'Umidità relativa'**
  String get weatherRelativeHumidity;

  /// Localized text for settingsSecretCode.
  ///
  /// In it, this message translates to:
  /// **'Codice Sonarpad per funzioni aggiuntive'**
  String get settingsSecretCode;

  /// Localized text for settingsRequestCode.
  ///
  /// In it, this message translates to:
  /// **'Richiedi codice all\'autore'**
  String get settingsRequestCode;

  /// Localized text for settingsPasteCode.
  ///
  /// In it, this message translates to:
  /// **'Incolla codice'**
  String get settingsPasteCode;

  /// Localized text for settingsCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get settingsCancel;

  /// Localized text for settingsSend.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get settingsSend;

  /// Localized text for settingsFillFieldsCode.
  ///
  /// In it, this message translates to:
  /// **'Compila tutti i campi per richiedere il codice.'**
  String get settingsFillFieldsCode;

  /// Localized text for settingsName.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get settingsName;

  /// Localized text for settingsSurname.
  ///
  /// In it, this message translates to:
  /// **'Cognome'**
  String get settingsSurname;

  /// Localized text for settingsEmail.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// Localized text for settingsOperatingSystem.
  ///
  /// In it, this message translates to:
  /// **'Sistema operativo'**
  String get settingsOperatingSystem;

  /// Localized text for settingsCodeRequestBody.
  ///
  /// In it, this message translates to:
  /// **'Nome: {name}; Cognome: {surname}; Email: {email}; Sistema operativo: {os}'**
  String settingsCodeRequestBody(
      String name, String surname, String email, String os);

  /// Localized text for settingsNameOptional.
  ///
  /// In it, this message translates to:
  /// **'Nome (opzionale)'**
  String get settingsNameOptional;

  /// Localized text for settingsMessageOptional.
  ///
  /// In it, this message translates to:
  /// **'Messaggio (opzionale)'**
  String get settingsMessageOptional;

  /// Localized text for settingsVerifyCodeAndSave.
  ///
  /// In it, this message translates to:
  /// **'Verifica codice e salvataggio...'**
  String get settingsVerifyCodeAndSave;

  /// Localized text for settingsViewSysLog.
  ///
  /// In it, this message translates to:
  /// **'Visualizza log di sistema'**
  String get settingsViewSysLog;

  /// Localized text for settingsMailOpenError.
  ///
  /// In it, this message translates to:
  /// **'Errore apertura mail: {error}'**
  String settingsMailOpenError(Object error);

  /// Localized text for ok.
  ///
  /// In it, this message translates to:
  /// **'OK'**
  String get ok;

  /// Localized text for invia.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get invia;

  /// Localized text for saveArticle.
  ///
  /// In it, this message translates to:
  /// **'Salva l\'articolo'**
  String get saveArticle;

  /// Localized text for shareArticle.
  ///
  /// In it, this message translates to:
  /// **'Condividi l\'articolo'**
  String get shareArticle;

  /// Localized text for articleSavedSuccess.
  ///
  /// In it, this message translates to:
  /// **'Articolo salvato nei Documenti'**
  String get articleSavedSuccess;

  /// Localized text for annulla.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get annulla;

  /// Localized text for compilaTuttiICampiPerRichiedereIlCodice.
  ///
  /// In it, this message translates to:
  /// **'Compila tutti i campi per richiedere il codice.'**
  String get compilaTuttiICampiPerRichiedereIlCodice;

  /// Localized text for selectFolder.
  ///
  /// In it, this message translates to:
  /// **'Seleziona cartella'**
  String get selectFolder;

  /// Localized text for exportDocument.
  ///
  /// In it, this message translates to:
  /// **'Esporta documento'**
  String get exportDocument;

  /// Localized text for exportFormatPrompt.
  ///
  /// In it, this message translates to:
  /// **'In quale formato desideri esportare il documento?'**
  String get exportFormatPrompt;

  /// Localized text for textFormat.
  ///
  /// In it, this message translates to:
  /// **'Testo (.txt)'**
  String get textFormat;

  /// Localized text for pdfFormat.
  ///
  /// In it, this message translates to:
  /// **'PDF (.pdf)'**
  String get pdfFormat;

  /// No description provided for @docxFormat.
  ///
  /// In it, this message translates to:
  /// **'DOCX (.docx)'**
  String get docxFormat;

  /// No description provided for @epubFormat.
  ///
  /// In it, this message translates to:
  /// **'EPUB (.epub)'**
  String get epubFormat;

  /// Localized text for exportError.
  ///
  /// In it, this message translates to:
  /// **'Errore esportazione'**
  String get exportError;

  /// Localized text for newFolder.
  ///
  /// In it, this message translates to:
  /// **'Nuova cartella'**
  String get newFolder;

  /// Localized text for folderNameHint.
  ///
  /// In it, this message translates to:
  /// **'Nome cartella'**
  String get folderNameHint;

  /// Localized text for create.
  ///
  /// In it, this message translates to:
  /// **'Crea'**
  String get create;

  /// Localized text for createNewFolder.
  ///
  /// In it, this message translates to:
  /// **'Crea nuova cartella'**
  String get createNewFolder;

  /// Localized text for importExternalSources.
  ///
  /// In it, this message translates to:
  /// **'Importa da fonti esterne'**
  String get importExternalSources;

  /// Localized text for importExternalSourcesTitle.
  ///
  /// In it, this message translates to:
  /// **'Fonti esterne'**
  String get importExternalSourcesTitle;

  /// Localized text for importFromDropbox.
  ///
  /// In it, this message translates to:
  /// **'Importa documenti da Dropbox'**
  String get importFromDropbox;

  /// Localized text for importFromProjectGutenberg.
  ///
  /// In it, this message translates to:
  /// **'Importa da Project Gutenberg'**
  String get importFromProjectGutenberg;

  /// Localized text for projectGutenbergImportUnavailable.
  ///
  /// In it, this message translates to:
  /// **'L\'importazione da Project Gutenberg non è ancora disponibile.'**
  String get projectGutenbergImportUnavailable;

  /// Localized text for importFromInternetArchive.
  ///
  /// In it, this message translates to:
  /// **'Importa da Internet Archive'**
  String get importFromInternetArchive;

  /// Localized text for internetArchiveTitle.
  ///
  /// In it, this message translates to:
  /// **'Internet Archive'**
  String get internetArchiveTitle;

  /// Localized text for internetArchiveSearchLabel.
  ///
  /// In it, this message translates to:
  /// **'Cerca audio'**
  String get internetArchiveSearchLabel;

  /// Localized text for internetArchiveSourceLabel.
  ///
  /// In it, this message translates to:
  /// **'Fonte'**
  String get internetArchiveSourceLabel;

  /// Localized text for internetArchiveOldTimeRadio.
  ///
  /// In it, this message translates to:
  /// **'Old Time Radio'**
  String get internetArchiveOldTimeRadio;

  /// Localized text for internetArchiveSpeeches.
  ///
  /// In it, this message translates to:
  /// **'Discorsi storici'**
  String get internetArchiveSpeeches;

  /// Localized text for internetArchiveLiveMusic.
  ///
  /// In it, this message translates to:
  /// **'Live Music Archive'**
  String get internetArchiveLiveMusic;

  /// Localized text for internetArchiveNoItemsFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun elemento audio trovato.'**
  String get internetArchiveNoItemsFound;

  /// Localized text for saveAudioInDocuments.
  ///
  /// In it, this message translates to:
  /// **'Salva audio nei Documenti'**
  String get saveAudioInDocuments;

  /// Localized text for audioSavedInDocuments.
  ///
  /// In it, this message translates to:
  /// **'Audio salvato nei Documenti.'**
  String get audioSavedInDocuments;

  /// Localized text for noAudioTracksAvailable.
  ///
  /// In it, this message translates to:
  /// **'Nessuna traccia audio disponibile.'**
  String get noAudioTracksAvailable;

  /// Localized text for importFromLibriVox.
  ///
  /// In it, this message translates to:
  /// **'Importa da LibriVox'**
  String get importFromLibriVox;

  /// Localized text for gutenbergSearchLabel.
  ///
  /// In it, this message translates to:
  /// **'Cerca libro o autore'**
  String get gutenbergSearchLabel;

  /// Localized text for sourceLanguageLabel.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get sourceLanguageLabel;

  /// Localized text for noGutenbergBooksFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun libro trovato.'**
  String get noGutenbergBooksFound;

  /// Localized text for loadMore.
  ///
  /// In it, this message translates to:
  /// **'Carica altri'**
  String get loadMore;

  /// Localized text for sourceLanguageValue.
  ///
  /// In it, this message translates to:
  /// **'Lingua: {language}'**
  String sourceLanguageValue(String language);

  /// Localized text for gutenbergImportAndRead.
  ///
  /// In it, this message translates to:
  /// **'Importa e leggi'**
  String get gutenbergImportAndRead;

  /// Localized text for gutenbergImporting.
  ///
  /// In it, this message translates to:
  /// **'Importazione...'**
  String get gutenbergImporting;

  /// Localized text for librivoxSearchLabel.
  ///
  /// In it, this message translates to:
  /// **'Cerca audiolibro'**
  String get librivoxSearchLabel;

  /// Localized text for noLibrivoxAudiobooksFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun audiolibro trovato.'**
  String get noLibrivoxAudiobooksFound;

  /// Localized text for librivoxAudiobookSaved.
  ///
  /// In it, this message translates to:
  /// **'Audiolibro salvato nei Documenti.'**
  String get librivoxAudiobookSaved;

  /// Localized text for librivoxSaveAudiobook.
  ///
  /// In it, this message translates to:
  /// **'Salva audiolibro nei Documenti'**
  String get librivoxSaveAudiobook;

  /// Localized text for librivoxSaving.
  ///
  /// In it, this message translates to:
  /// **'Salvataggio...'**
  String get librivoxSaving;

  /// Localized text for librivoxNoAudioTracks.
  ///
  /// In it, this message translates to:
  /// **'Nessuna traccia audio disponibile.'**
  String get librivoxNoAudioTracks;

  /// Localized text for librivoxNotTextExportable.
  ///
  /// In it, this message translates to:
  /// **'Gli audiolibri LibriVox non sono esportabili come testo.'**
  String get librivoxNotTextExportable;

  /// Localized text for sourceDurationValue.
  ///
  /// In it, this message translates to:
  /// **'Durata: {duration}'**
  String sourceDurationValue(String duration);

  /// Localized text for importFromPoetryDb.
  ///
  /// In it, this message translates to:
  /// **'Importa da PoetryDB'**
  String get importFromPoetryDb;

  /// Localized text for poetryDbSearchLabel.
  ///
  /// In it, this message translates to:
  /// **'Cerca poesia'**
  String get poetryDbSearchLabel;

  /// Localized text for poetryDbSearchBy.
  ///
  /// In it, this message translates to:
  /// **'Cerca per'**
  String get poetryDbSearchBy;

  /// Localized text for poetryDbSearchByTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get poetryDbSearchByTitle;

  /// Localized text for poetryDbSearchByAuthor.
  ///
  /// In it, this message translates to:
  /// **'Autore'**
  String get poetryDbSearchByAuthor;

  /// Localized text for poetryDbNoPoemsFound.
  ///
  /// In it, this message translates to:
  /// **'Nessuna poesia trovata.'**
  String get poetryDbNoPoemsFound;

  /// Localized text for poetryDbLineCount.
  ///
  /// In it, this message translates to:
  /// **'{count} versi'**
  String poetryDbLineCount(int count);

  /// Localized text for moveDocument.
  ///
  /// In it, this message translates to:
  /// **'Sposta documento'**
  String get moveDocument;

  /// Localized text for documentMoved.
  ///
  /// In it, this message translates to:
  /// **'Spostato correttamente'**
  String get documentMoved;

  /// Localized text for outOfFolder.
  ///
  /// In it, this message translates to:
  /// **'Fuori dalla cartella'**
  String get outOfFolder;

  /// Localized text for moveToAnotherFolder.
  ///
  /// In it, this message translates to:
  /// **'Sposta in un\'altra cartella...'**
  String get moveToAnotherFolder;

  /// Localized text for ttsError.
  ///
  /// In it, this message translates to:
  /// **'Errore sintesi vocale'**
  String get ttsError;

  /// Localized text for editParagraph.
  ///
  /// In it, this message translates to:
  /// **'Modifica paragrafo'**
  String get editParagraph;

  /// Localized text for editParagraphTextField.
  ///
  /// In it, this message translates to:
  /// **'Campo di testo per la modifica del paragrafo'**
  String get editParagraphTextField;

  /// Localized text for editParagraphHint.
  ///
  /// In it, this message translates to:
  /// **'Modifica il testo del paragrafo'**
  String get editParagraphHint;

  /// Localized text for applyAndSave.
  ///
  /// In it, this message translates to:
  /// **'Applica e salva'**
  String get applyAndSave;

  /// Localized text for textEditedAndSaved.
  ///
  /// In it, this message translates to:
  /// **'Testo modificato e salvato nel documento corrente.'**
  String get textEditedAndSaved;

  /// Localized text for saveError.
  ///
  /// In it, this message translates to:
  /// **'Errore durante il salvataggio'**
  String get saveError;

  /// Localized text for docSavedInLibrary.
  ///
  /// In it, this message translates to:
  /// **'Documento salvato nella libreria'**
  String get docSavedInLibrary;

  /// Localized text for saveInLibrary.
  ///
  /// In it, this message translates to:
  /// **'Salva nella libreria'**
  String get saveInLibrary;

  /// Localized text for documentTextLabel.
  ///
  /// In it, this message translates to:
  /// **'Testo documento'**
  String get documentTextLabel;

  /// Localized text for modifiedInSonarpad.
  ///
  /// In it, this message translates to:
  /// **'Modificato in Sonarpad'**
  String get modifiedInSonarpad;

  /// Localized text for noTextAvailableForDocument.
  ///
  /// In it, this message translates to:
  /// **'Nessun testo disponibile per questo documento.'**
  String get noTextAvailableForDocument;

  /// Localized text for bookmarkSet.
  ///
  /// In it, this message translates to:
  /// **'Segnalibro impostato al paragrafo {index}.'**
  String bookmarkSet(int index);

  /// Localized text for bookmarkRemoved.
  ///
  /// In it, this message translates to:
  /// **'Segnalibro rimosso.'**
  String get bookmarkRemoved;

  /// Localized text for docEmpty.
  ///
  /// In it, this message translates to:
  /// **'Il documento è vuoto'**
  String get docEmpty;

  /// Localized text for docSavedSuccessfully.
  ///
  /// In it, this message translates to:
  /// **'Documento salvato correttamente.'**
  String get docSavedSuccessfully;

  /// Localized text for writeDocument.
  ///
  /// In it, this message translates to:
  /// **'Scrivi documento'**
  String get writeDocument;

  /// Localized text for documentTitleOptional.
  ///
  /// In it, this message translates to:
  /// **'Titolo (opzionale)'**
  String get documentTitleOptional;

  /// Localized text for documentTitleHint.
  ///
  /// In it, this message translates to:
  /// **'Esempio: lista della spesa'**
  String get documentTitleHint;

  /// Localized text for documentTextField.
  ///
  /// In it, this message translates to:
  /// **'Testo del documento'**
  String get documentTextField;

  /// Localized text for documentTextHint.
  ///
  /// In it, this message translates to:
  /// **'Inizia a scrivere qui...'**
  String get documentTextHint;

  /// Localized text for newDocumentDefaultName.
  ///
  /// In it, this message translates to:
  /// **'Nuovo_Documento'**
  String get newDocumentDefaultName;

  /// Localized text for saving.
  ///
  /// In it, this message translates to:
  /// **'Salvataggio...'**
  String get saving;

  /// Localized text for saveDocument.
  ///
  /// In it, this message translates to:
  /// **'Salva documento'**
  String get saveDocument;

  /// Localized text for addRssSource.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi sorgente RSS'**
  String get addRssSource;

  /// Localized text for add.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get add;

  /// Localized text for errorPrefix.
  ///
  /// In it, this message translates to:
  /// **'Errore'**
  String get errorPrefix;

  /// Localized text for versionBuild.
  ///
  /// In it, this message translates to:
  /// **'Versione {version} (Build {buildNumber})'**
  String versionBuild(String version, String buildNumber);

  /// Localized text for whatIsNew.
  ///
  /// In it, this message translates to:
  /// **'Novità'**
  String get whatIsNew;

  /// Localized text for whatIsNewInVersion.
  ///
  /// In it, this message translates to:
  /// **'Novità della versione {version}'**
  String whatIsNewInVersion(String version);

  /// Localized text for changelogLoadError.
  ///
  /// In it, this message translates to:
  /// **'Errore caricamento novità: {error}'**
  String changelogLoadError(Object error);

  /// Localized text for visitSonarpadSite.
  ///
  /// In it, this message translates to:
  /// **'Visita il sito di Sonarpad'**
  String get visitSonarpadSite;

  /// Localized text for visitSonarpadSiteWithUrl.
  ///
  /// In it, this message translates to:
  /// **'Visita il sito di Sonarpad: {url}'**
  String visitSonarpadSiteWithUrl(String url);

  /// Localized text for nowPlaying.
  ///
  /// In it, this message translates to:
  /// **'In riproduzione'**
  String get nowPlaying;

  /// Localized text for fileImported.
  ///
  /// In it, this message translates to:
  /// **'File importato'**
  String get fileImported;

  /// Localized text for importZipError.
  ///
  /// In it, this message translates to:
  /// **'Errore importazione zip: {error}'**
  String importZipError(Object error);

  /// Localized text for dropboxLoginPrompt.
  ///
  /// In it, this message translates to:
  /// **'Accedi a Dropbox per importare i tuoi documenti.'**
  String get dropboxLoginPrompt;

  /// Localized text for loginToDropbox.
  ///
  /// In it, this message translates to:
  /// **'Accedi a Dropbox'**
  String get loginToDropbox;

  /// Localized text for logoutFromDropbox.
  ///
  /// In it, this message translates to:
  /// **'Disconnetti'**
  String get logoutFromDropbox;

  /// Localized text for dropboxLoginFailed.
  ///
  /// In it, this message translates to:
  /// **'Accesso fallito o annullato'**
  String get dropboxLoginFailed;

  /// Localized text for dropboxLoadFolderError.
  ///
  /// In it, this message translates to:
  /// **'Errore caricamento cartella: {error}'**
  String dropboxLoadFolderError(Object error);

  /// Localized text for dropboxImportError.
  ///
  /// In it, this message translates to:
  /// **'Errore importazione: {error}'**
  String dropboxImportError(Object error);

  /// Localized text for retry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get retry;

  /// Localized text for goBack.
  ///
  /// In it, this message translates to:
  /// **'.. Torna indietro'**
  String get goBack;

  /// Localized text for noSupportedFilesInFolder.
  ///
  /// In it, this message translates to:
  /// **'Nessun file supportato in questa cartella.'**
  String get noSupportedFilesInFolder;

  /// Localized text for articleNotFound.
  ///
  /// In it, this message translates to:
  /// **'Articolo non trovato.'**
  String get articleNotFound;

  /// Localized text for errorOpening.
  ///
  /// In it, this message translates to:
  /// **'Errore durante l\'apertura'**
  String get errorOpening;

  /// Localized text for recentArticles.
  ///
  /// In it, this message translates to:
  /// **'Articoli recenti'**
  String get recentArticles;

  /// Localized text for clearHistory.
  ///
  /// In it, this message translates to:
  /// **'Cancella cronologia'**
  String get clearHistory;

  /// Localized text for confirmClearHistory.
  ///
  /// In it, this message translates to:
  /// **'Vuoi davvero cancellare tutte le ricerche recenti?'**
  String get confirmClearHistory;

  /// Localized text for clear.
  ///
  /// In it, this message translates to:
  /// **'Cancella'**
  String get clear;

  /// Localized text for noRecentSearches.
  ///
  /// In it, this message translates to:
  /// **'Nessuna ricerca recente.'**
  String get noRecentSearches;

  /// Localized text for logCopiedToClipboard.
  ///
  /// In it, this message translates to:
  /// **'Log copiato negli appunti'**
  String get logCopiedToClipboard;

  /// Localized text for systemLog.
  ///
  /// In it, this message translates to:
  /// **'Log di sistema'**
  String get systemLog;

  /// Localized text for clearSystemLog.
  ///
  /// In it, this message translates to:
  /// **'Svuota log'**
  String get clearSystemLog;

  /// Localized text for copySystemLog.
  ///
  /// In it, this message translates to:
  /// **'Copia log'**
  String get copySystemLog;

  /// Localized text for donateWithPaypal.
  ///
  /// In it, this message translates to:
  /// **'Dona con PayPal'**
  String get donateWithPaypal;

  /// Localized text for bankTransferTitle.
  ///
  /// In it, this message translates to:
  /// **'Bonifico bancario'**
  String get bankTransferTitle;

  /// Localized text for enableVideo.
  ///
  /// In it, this message translates to:
  /// **'Attiva video'**
  String get enableVideo;

  /// Localized text for calendar.
  ///
  /// In it, this message translates to:
  /// **'Calendario'**
  String get calendar;

  /// Localized text for calendarHint.
  ///
  /// In it, this message translates to:
  /// **'Apri il calendario con santi, festività e promemoria'**
  String get calendarHint;

  /// Localized text for saintOfTheDay.
  ///
  /// In it, this message translates to:
  /// **'Santo del giorno'**
  String get saintOfTheDay;

  /// Localized text for quoteOfTheDay.
  ///
  /// In it, this message translates to:
  /// **'Citazione del giorno'**
  String get quoteOfTheDay;

  /// Localized text for reminders.
  ///
  /// In it, this message translates to:
  /// **'Promemoria'**
  String get reminders;

  /// Localized text for addReminder.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi promemoria'**
  String get addReminder;

  /// Localized text for removeReminder.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi promemoria'**
  String get removeReminder;

  /// Localized text for noReminders.
  ///
  /// In it, this message translates to:
  /// **'Nessun promemoria'**
  String get noReminders;

  /// Localized text for writeReminder.
  ///
  /// In it, this message translates to:
  /// **'Scrivi qui il tuo promemoria...'**
  String get writeReminder;

  /// Localized text for saveReminder.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get saveReminder;

  /// Localized text for cancelReminder.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancelReminder;

  /// Localized text for backToToday.
  ///
  /// In it, this message translates to:
  /// **'Torna a oggi'**
  String get backToToday;

  /// Localized text for calendarToday.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get calendarToday;

  /// Localized text for calendarTomorrow.
  ///
  /// In it, this message translates to:
  /// **'Domani'**
  String get calendarTomorrow;

  /// Localized text for calendarYesterday.
  ///
  /// In it, this message translates to:
  /// **'Ieri'**
  String get calendarYesterday;

  /// Localized text for share.
  ///
  /// In it, this message translates to:
  /// **'Condividi'**
  String get share;

  /// Localized text for shareCalendarDayOptions.
  ///
  /// In it, this message translates to:
  /// **'Opzioni di condivisione'**
  String get shareCalendarDayOptions;

  /// Localized text for shareCalendarDayOnly.
  ///
  /// In it, this message translates to:
  /// **'Condividi solo il giorno'**
  String get shareCalendarDayOnly;

  /// Localized text for shareCalendarDayWithReminder.
  ///
  /// In it, this message translates to:
  /// **'Condividi giorno e promemoria'**
  String get shareCalendarDayWithReminder;

  /// Localized text for listenToAll.
  ///
  /// In it, this message translates to:
  /// **'Ascolta tutto'**
  String get listenToAll;

  /// Localized text for reminderSaved.
  ///
  /// In it, this message translates to:
  /// **'{count} promemoria'**
  String reminderSaved(int count);

  /// Localized text for audiodescriptionTitle.
  ///
  /// In it, this message translates to:
  /// **'Audiodescrizioni Rai'**
  String get audiodescriptionTitle;

  /// Localized text for audiodescriptionRecent.
  ///
  /// In it, this message translates to:
  /// **'Recenti'**
  String get audiodescriptionRecent;

  /// Localized text for audiodescriptionAll.
  ///
  /// In it, this message translates to:
  /// **'Tutte le audiodescrizioni'**
  String get audiodescriptionAll;

  /// Localized text for audiodescriptionFilm.
  ///
  /// In it, this message translates to:
  /// **'Film'**
  String get audiodescriptionFilm;

  /// Localized text for audiodescriptionSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca...'**
  String get audiodescriptionSearch;

  /// Localized text for audiodescriptionLoading.
  ///
  /// In it, this message translates to:
  /// **'Caricamento in corso...'**
  String get audiodescriptionLoading;

  /// Localized text for audiodescriptionError.
  ///
  /// In it, this message translates to:
  /// **'Errore nel caricamento del catalogo'**
  String get audiodescriptionError;

  /// Localized text for audiodescriptionEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun elemento trovato'**
  String get audiodescriptionEmpty;

  /// Localized text for radio.
  ///
  /// In it, this message translates to:
  /// **'Radio'**
  String get radio;

  /// Localized text for radioHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca stazioni radio, ascolta streaming e gestisci le preferite'**
  String get radioHint;

  /// Localized text for radioTitle.
  ///
  /// In it, this message translates to:
  /// **'Radio da tutto il mondo'**
  String get radioTitle;

  /// Localized text for radioFavoritesButton.
  ///
  /// In it, this message translates to:
  /// **'Radio preferite'**
  String get radioFavoritesButton;

  /// Localized text for radioNoFavorites.
  ///
  /// In it, this message translates to:
  /// **'Nessuna radio preferita.'**
  String get radioNoFavorites;

  /// Localized text for radioSearchText.
  ///
  /// In it, this message translates to:
  /// **'Cerca radio'**
  String get radioSearchText;

  /// Localized text for radioSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Nome della stazione o città...'**
  String get radioSearchHint;

  /// Localized text for radioLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get radioLanguage;

  /// No description provided for @radioBrowseBy.
  ///
  /// In it, this message translates to:
  /// **'Sfoglia per'**
  String get radioBrowseBy;

  /// No description provided for @radioBrowseByLanguage.
  ///
  /// In it, this message translates to:
  /// **'Sfoglia per lingua'**
  String get radioBrowseByLanguage;

  /// No description provided for @radioBrowseByCountry.
  ///
  /// In it, this message translates to:
  /// **'Sfoglia per nazione'**
  String get radioBrowseByCountry;

  /// No description provided for @radioCountry.
  ///
  /// In it, this message translates to:
  /// **'Nazione'**
  String get radioCountry;

  /// Localized text for radioGenre.
  ///
  /// In it, this message translates to:
  /// **'Genere'**
  String get radioGenre;

  /// No description provided for @radioActiveFilters.
  ///
  /// In it, this message translates to:
  /// **'Filtri attivi'**
  String get radioActiveFilters;

  /// No description provided for @radioResetFilters.
  ///
  /// In it, this message translates to:
  /// **'Reimposta filtri'**
  String get radioResetFilters;

  /// No description provided for @radioFiltersReset.
  ///
  /// In it, this message translates to:
  /// **'Filtri reimpostati.'**
  String get radioFiltersReset;

  /// No description provided for @radioCity.
  ///
  /// In it, this message translates to:
  /// **'Città'**
  String get radioCity;

  /// Localized text for radioSearch.
  ///
  /// In it, this message translates to:
  /// **'Ricerca'**
  String get radioSearch;

  /// Localized text for radioSearching.
  ///
  /// In it, this message translates to:
  /// **'Caricamento radio...'**
  String get radioSearching;

  /// Localized text for radioSearchResults.
  ///
  /// In it, this message translates to:
  /// **'Risultati radio'**
  String get radioSearchResults;

  /// Localized text for radioNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessuna radio trovata.'**
  String get radioNoResults;

  /// Localized text for radioResultsFound.
  ///
  /// In it, this message translates to:
  /// **'Trovate {count} radio'**
  String radioResultsFound(int count);

  /// Localized text for radioSearchError.
  ///
  /// In it, this message translates to:
  /// **'Errore ricerca radio: {error}'**
  String radioSearchError(Object error);

  /// Localized text for radioNowPlaying.
  ///
  /// In it, this message translates to:
  /// **'Riproduco {name}'**
  String radioNowPlaying(String name);

  /// Localized text for radioPlayError.
  ///
  /// In it, this message translates to:
  /// **'Errore streaming radio: {error}'**
  String radioPlayError(Object error);

  /// Localized text for radioAddFavorite.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi ai preferiti'**
  String get radioAddFavorite;

  /// Localized text for radioRemoveFavorite.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dai preferiti'**
  String get radioRemoveFavorite;

  /// Localized text for radioFavoriteAdded.
  ///
  /// In it, this message translates to:
  /// **'{name} aggiunta ai preferiti.'**
  String radioFavoriteAdded(String name);

  /// Localized text for radioFavoriteRemoved.
  ///
  /// In it, this message translates to:
  /// **'{name} rimossa dai preferiti.'**
  String radioFavoriteRemoved(String name);

  /// Localized text for tvSearchFieldLabel.
  ///
  /// In it, this message translates to:
  /// **'Cerca canali TV'**
  String get tvSearchFieldLabel;

  /// Localized text for tvSearchFieldHint.
  ///
  /// In it, this message translates to:
  /// **'Nome del canale...'**
  String get tvSearchFieldHint;

  /// Localized text for tvSearchButton.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get tvSearchButton;

  /// Localized text for tvSearchResults.
  ///
  /// In it, this message translates to:
  /// **'Risultati canali TV'**
  String get tvSearchResults;

  /// Localized text for tvSearchEmptyQuery.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il nome di un canale TV da cercare.'**
  String get tvSearchEmptyQuery;

  /// Localized text for tvSearchNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun canale TV trovato per {query}.'**
  String tvSearchNoResults(String query);

  /// Localized text for tvOpenChannelHint.
  ///
  /// In it, this message translates to:
  /// **'Tocca per riprodurre il canale TV'**
  String get tvOpenChannelHint;

  /// Localized text for tvNowOnAir.
  ///
  /// In it, this message translates to:
  /// **'Ora in onda: {title}'**
  String tvNowOnAir(String title);

  /// Localized text for radioAddCommunity.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi radio alla comunità Sonarpad'**
  String get radioAddCommunity;

  /// Localized text for radioAddName.
  ///
  /// In it, this message translates to:
  /// **'Nome radio'**
  String get radioAddName;

  /// Localized text for radioAddUrl.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo streaming'**
  String get radioAddUrl;

  /// Localized text for radioAddSubmit.
  ///
  /// In it, this message translates to:
  /// **'Verifica e aggiungi'**
  String get radioAddSubmit;

  /// Localized text for radioAddMissingFields.
  ///
  /// In it, this message translates to:
  /// **'Inserisci nome radio e indirizzo streaming.'**
  String get radioAddMissingFields;

  /// Localized text for radioCommunityAdded.
  ///
  /// In it, this message translates to:
  /// **'Radio aggiunta correttamente alla comunità Sonarpad.'**
  String get radioCommunityAdded;

  /// Localized text for radioCommunityAddError.
  ///
  /// In it, this message translates to:
  /// **'Errore durante l\'aggiunta della radio: {error}'**
  String radioCommunityAddError(Object error);

  /// Localized text for radioPlay.
  ///
  /// In it, this message translates to:
  /// **'Riproduci'**
  String get radioPlay;

  /// No description provided for @startRecording.
  ///
  /// In it, this message translates to:
  /// **'Avvia registrazione'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In it, this message translates to:
  /// **'Ferma registrazione'**
  String get stopRecording;

  /// No description provided for @recordings.
  ///
  /// In it, this message translates to:
  /// **'Registrazioni'**
  String get recordings;

  /// No description provided for @noRecordings.
  ///
  /// In it, this message translates to:
  /// **'Nessuna registrazione.'**
  String get noRecordings;

  /// No description provided for @recordingStarted.
  ///
  /// In it, this message translates to:
  /// **'Registrazione avviata.'**
  String get recordingStarted;

  /// No description provided for @recordingSaved.
  ///
  /// In it, this message translates to:
  /// **'Registrazione salvata: {path}'**
  String recordingSaved(Object path);

  /// No description provided for @recordingError.
  ///
  /// In it, this message translates to:
  /// **'Errore registrazione: {error}'**
  String recordingError(Object error);

  /// Localized text for routeTitle.
  ///
  /// In it, this message translates to:
  /// **'Percorsi'**
  String get routeTitle;

  /// Localized text for routeFrom.
  ///
  /// In it, this message translates to:
  /// **'Partenza'**
  String get routeFrom;

  /// Localized text for routeTo.
  ///
  /// In it, this message translates to:
  /// **'Destinazione'**
  String get routeTo;

  /// Localized text for routeCountry.
  ///
  /// In it, this message translates to:
  /// **'Paese'**
  String get routeCountry;

  /// Localized text for routeCountryItaly.
  ///
  /// In it, this message translates to:
  /// **'Italia'**
  String get routeCountryItaly;

  /// Localized text for routeCountryFrance.
  ///
  /// In it, this message translates to:
  /// **'Francia'**
  String get routeCountryFrance;

  /// Localized text for routeCountrySpain.
  ///
  /// In it, this message translates to:
  /// **'Spagna'**
  String get routeCountrySpain;

  /// Localized text for routeCountryCzechRepublic.
  ///
  /// In it, this message translates to:
  /// **'Repubblica Ceca'**
  String get routeCountryCzechRepublic;

  /// Localized text for routeVehicle.
  ///
  /// In it, this message translates to:
  /// **'Mezzo di trasporto'**
  String get routeVehicle;

  /// Localized text for routeType.
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get routeType;

  /// Localized text for routeIncludeMunicipalities.
  ///
  /// In it, this message translates to:
  /// **'Includi comuni attraversati'**
  String get routeIncludeMunicipalities;

  /// Localized text for routeWalking.
  ///
  /// In it, this message translates to:
  /// **'A piedi'**
  String get routeWalking;

  /// Localized text for routeCycling.
  ///
  /// In it, this message translates to:
  /// **'In bicicletta'**
  String get routeCycling;

  /// Localized text for routeDriving.
  ///
  /// In it, this message translates to:
  /// **'In auto'**
  String get routeDriving;

  /// Localized text for routeWheelchair.
  ///
  /// In it, this message translates to:
  /// **'In sedia a rotelle'**
  String get routeWheelchair;

  /// Localized text for routeFastest.
  ///
  /// In it, this message translates to:
  /// **'Più veloce'**
  String get routeFastest;

  /// Localized text for routeShortest.
  ///
  /// In it, this message translates to:
  /// **'Più corto'**
  String get routeShortest;

  /// Localized text for routeCalculate.
  ///
  /// In it, this message translates to:
  /// **'Calcola percorso'**
  String get routeCalculate;

  /// Localized text for routeCalculating.
  ///
  /// In it, this message translates to:
  /// **'Calcolo in corso...'**
  String get routeCalculating;

  /// Localized text for routeChooseFrom.
  ///
  /// In it, this message translates to:
  /// **'Scegli il punto di partenza'**
  String get routeChooseFrom;

  /// Localized text for routeChooseTo.
  ///
  /// In it, this message translates to:
  /// **'Scegli la destinazione'**
  String get routeChooseTo;

  /// Localized text for routeCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get routeCancel;

  /// Localized text for routeErrorMissingFields.
  ///
  /// In it, this message translates to:
  /// **'Inserisci punto di partenza e destinazione'**
  String get routeErrorMissingFields;

  /// Localized text for routeErrorFromNotFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato trovato per l\'indirizzo di partenza'**
  String get routeErrorFromNotFound;

  /// Localized text for routeErrorToNotFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato trovato per l\'indirizzo di arrivo'**
  String get routeErrorToNotFound;

  /// Localized text for routeResultsTitle.
  ///
  /// In it, this message translates to:
  /// **'Percorsi disponibili'**
  String get routeResultsTitle;

  /// Localized text for routeDistance.
  ///
  /// In it, this message translates to:
  /// **'Distanza'**
  String get routeDistance;

  /// Localized text for routeDuration.
  ///
  /// In it, this message translates to:
  /// **'Durata'**
  String get routeDuration;

  /// Localized text for routeNavigation.
  ///
  /// In it, this message translates to:
  /// **'Dettagli navigazione'**
  String get routeNavigation;

  /// Localized text for routeStartMunicipality.
  ///
  /// In it, this message translates to:
  /// **'Comune di partenza'**
  String get routeStartMunicipality;

  /// Localized text for routeEnterMunicipality.
  ///
  /// In it, this message translates to:
  /// **'Entri nel comune di'**
  String get routeEnterMunicipality;

  /// Localized text for routeError.
  ///
  /// In it, this message translates to:
  /// **'Errore: {error}'**
  String routeError(Object error);

  /// Localized text for radioLanguageIt.
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get radioLanguageIt;

  /// Localized text for radioLanguageEn.
  ///
  /// In it, this message translates to:
  /// **'Inglese'**
  String get radioLanguageEn;

  /// Localized text for radioLanguageDe.
  ///
  /// In it, this message translates to:
  /// **'Tedesco'**
  String get radioLanguageDe;

  /// Localized text for radioLanguageCountryCh.
  ///
  /// In it, this message translates to:
  /// **'Svizzera'**
  String get radioLanguageCountryCh;

  /// Localized text for radioLanguageEs.
  ///
  /// In it, this message translates to:
  /// **'Spagnolo'**
  String get radioLanguageEs;

  /// Localized text for radioLanguagePt.
  ///
  /// In it, this message translates to:
  /// **'Portoghese'**
  String get radioLanguagePt;

  /// Localized text for radioLanguageSv.
  ///
  /// In it, this message translates to:
  /// **'Svedese'**
  String get radioLanguageSv;

  /// Localized text for radioLanguageVi.
  ///
  /// In it, this message translates to:
  /// **'Vietnamita'**
  String get radioLanguageVi;

  /// Localized text for radioLanguageCs.
  ///
  /// In it, this message translates to:
  /// **'Ceco'**
  String get radioLanguageCs;

  /// Localized text for radioLanguagePl.
  ///
  /// In it, this message translates to:
  /// **'Polacco'**
  String get radioLanguagePl;

  /// Localized text for radioLanguageFr.
  ///
  /// In it, this message translates to:
  /// **'Francese'**
  String get radioLanguageFr;

  /// Localized text for radioLanguageSr.
  ///
  /// In it, this message translates to:
  /// **'Serbo'**
  String get radioLanguageSr;

  /// Localized text for radioLanguageUk.
  ///
  /// In it, this message translates to:
  /// **'Ucraino'**
  String get radioLanguageUk;

  /// Localized text for radioLanguageHi.
  ///
  /// In it, this message translates to:
  /// **'Hindi'**
  String get radioLanguageHi;

  /// Localized text for radioLanguageLt.
  ///
  /// In it, this message translates to:
  /// **'Lituano'**
  String get radioLanguageLt;

  /// Localized text for radioLanguageRu.
  ///
  /// In it, this message translates to:
  /// **'Russo'**
  String get radioLanguageRu;

  /// Localized text for radioLanguageZh.
  ///
  /// In it, this message translates to:
  /// **'Cinese'**
  String get radioLanguageZh;

  /// No description provided for @radioCountryOptionIt.
  ///
  /// In it, this message translates to:
  /// **'Italia'**
  String get radioCountryOptionIt;

  /// No description provided for @radioCountryOptionUs.
  ///
  /// In it, this message translates to:
  /// **'Stati Uniti'**
  String get radioCountryOptionUs;

  /// No description provided for @radioCountryOptionGb.
  ///
  /// In it, this message translates to:
  /// **'Regno Unito'**
  String get radioCountryOptionGb;

  /// No description provided for @radioCountryOptionFr.
  ///
  /// In it, this message translates to:
  /// **'Francia'**
  String get radioCountryOptionFr;

  /// No description provided for @radioCountryOptionEs.
  ///
  /// In it, this message translates to:
  /// **'Spagna'**
  String get radioCountryOptionEs;

  /// No description provided for @radioCountryOptionDe.
  ///
  /// In it, this message translates to:
  /// **'Germania'**
  String get radioCountryOptionDe;

  /// No description provided for @radioCountryOptionCh.
  ///
  /// In it, this message translates to:
  /// **'Svizzera'**
  String get radioCountryOptionCh;

  /// No description provided for @radioCountryOptionAt.
  ///
  /// In it, this message translates to:
  /// **'Austria'**
  String get radioCountryOptionAt;

  /// No description provided for @radioCountryOptionBe.
  ///
  /// In it, this message translates to:
  /// **'Belgio'**
  String get radioCountryOptionBe;

  /// No description provided for @radioCountryOptionNl.
  ///
  /// In it, this message translates to:
  /// **'Paesi Bassi'**
  String get radioCountryOptionNl;

  /// No description provided for @radioCountryOptionPt.
  ///
  /// In it, this message translates to:
  /// **'Portogallo'**
  String get radioCountryOptionPt;

  /// No description provided for @radioCountryOptionBr.
  ///
  /// In it, this message translates to:
  /// **'Brasile'**
  String get radioCountryOptionBr;

  /// No description provided for @radioCountryOptionAr.
  ///
  /// In it, this message translates to:
  /// **'Argentina'**
  String get radioCountryOptionAr;

  /// No description provided for @radioCountryOptionMx.
  ///
  /// In it, this message translates to:
  /// **'Messico'**
  String get radioCountryOptionMx;

  /// No description provided for @radioCountryOptionCa.
  ///
  /// In it, this message translates to:
  /// **'Canada'**
  String get radioCountryOptionCa;

  /// No description provided for @radioCountryOptionAu.
  ///
  /// In it, this message translates to:
  /// **'Australia'**
  String get radioCountryOptionAu;

  /// No description provided for @radioCountryOptionIe.
  ///
  /// In it, this message translates to:
  /// **'Irlanda'**
  String get radioCountryOptionIe;

  /// No description provided for @radioCountryOptionSe.
  ///
  /// In it, this message translates to:
  /// **'Svezia'**
  String get radioCountryOptionSe;

  /// No description provided for @radioCountryOptionPl.
  ///
  /// In it, this message translates to:
  /// **'Polonia'**
  String get radioCountryOptionPl;

  /// No description provided for @radioCountryOptionJp.
  ///
  /// In it, this message translates to:
  /// **'Giappone'**
  String get radioCountryOptionJp;

  /// Localized text for radioGenreOptionAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti i generi'**
  String get radioGenreOptionAll;

  /// Localized text for radioGenreOptionNews.
  ///
  /// In it, this message translates to:
  /// **'Notizie'**
  String get radioGenreOptionNews;

  /// Localized text for radioGenreOptionMusic.
  ///
  /// In it, this message translates to:
  /// **'Musica'**
  String get radioGenreOptionMusic;

  /// Localized text for radioGenreOptionSport.
  ///
  /// In it, this message translates to:
  /// **'Sport'**
  String get radioGenreOptionSport;

  /// Localized text for radioGenreOptionTalk.
  ///
  /// In it, this message translates to:
  /// **'Talk e approfondimenti'**
  String get radioGenreOptionTalk;

  /// Localized text for radioGenreOptionPop.
  ///
  /// In it, this message translates to:
  /// **'Pop'**
  String get radioGenreOptionPop;

  /// Localized text for radioGenreOptionRock.
  ///
  /// In it, this message translates to:
  /// **'Rock'**
  String get radioGenreOptionRock;

  /// Localized text for radioGenreOptionClassical.
  ///
  /// In it, this message translates to:
  /// **'Classica'**
  String get radioGenreOptionClassical;

  /// Localized text for radioGenreOptionJazz.
  ///
  /// In it, this message translates to:
  /// **'Jazz'**
  String get radioGenreOptionJazz;

  /// Localized text for radioGenreOptionDance.
  ///
  /// In it, this message translates to:
  /// **'Dance'**
  String get radioGenreOptionDance;

  /// Localized text for radioGenreOptionBlues.
  ///
  /// In it, this message translates to:
  /// **'Blues'**
  String get radioGenreOptionBlues;

  /// Localized text for radioGenreOptionCountry.
  ///
  /// In it, this message translates to:
  /// **'Country'**
  String get radioGenreOptionCountry;

  /// Localized text for radioGenreOptionHiphop.
  ///
  /// In it, this message translates to:
  /// **'Hip hop'**
  String get radioGenreOptionHiphop;

  /// Localized text for radioGenreOptionElectronic.
  ///
  /// In it, this message translates to:
  /// **'Elettronica'**
  String get radioGenreOptionElectronic;

  /// Localized text for radioGenreOptionLatin.
  ///
  /// In it, this message translates to:
  /// **'Latina'**
  String get radioGenreOptionLatin;

  /// Localized text for radioGenreOptionReggae.
  ///
  /// In it, this message translates to:
  /// **'Reggae'**
  String get radioGenreOptionReggae;

  /// Localized text for radioGenreOptionMetal.
  ///
  /// In it, this message translates to:
  /// **'Metal'**
  String get radioGenreOptionMetal;

  /// Localized text for radioGenreOptionFolk.
  ///
  /// In it, this message translates to:
  /// **'Folk'**
  String get radioGenreOptionFolk;

  /// Localized text for radioGenreOptionReligion.
  ///
  /// In it, this message translates to:
  /// **'Religione'**
  String get radioGenreOptionReligion;

  /// Localized text for radioGenreOptionLocal.
  ///
  /// In it, this message translates to:
  /// **'Locale'**
  String get radioGenreOptionLocal;

  /// Localized text for radioGenreOptionCulture.
  ///
  /// In it, this message translates to:
  /// **'Cultura'**
  String get radioGenreOptionCulture;

  /// Localized text for radioGenreOptionOldies.
  ///
  /// In it, this message translates to:
  /// **'Anni 70 / 80 / 90'**
  String get radioGenreOptionOldies;

  /// Localized text for radioGenreOptionKids.
  ///
  /// In it, this message translates to:
  /// **'Bambini'**
  String get radioGenreOptionKids;

  /// Localized text for radioGenreOptionAmbient.
  ///
  /// In it, this message translates to:
  /// **'Ambient'**
  String get radioGenreOptionAmbient;

  /// Localized text for radioCommunityLanguageItalian.
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get radioCommunityLanguageItalian;

  /// Localized text for radioCommunityLanguageEnglish.
  ///
  /// In it, this message translates to:
  /// **'Inglese'**
  String get radioCommunityLanguageEnglish;

  /// Localized text for radioCommunityLanguageSpanish.
  ///
  /// In it, this message translates to:
  /// **'Spagnolo'**
  String get radioCommunityLanguageSpanish;

  /// Localized text for radioCommunityLanguageFrench.
  ///
  /// In it, this message translates to:
  /// **'Francese'**
  String get radioCommunityLanguageFrench;

  /// Localized text for radioCommunityLanguageGerman.
  ///
  /// In it, this message translates to:
  /// **'Tedesco'**
  String get radioCommunityLanguageGerman;

  /// Localized text for radioCommunityLanguagePortuguese.
  ///
  /// In it, this message translates to:
  /// **'Portoghese'**
  String get radioCommunityLanguagePortuguese;

  /// Localized text for radioCommunityLanguageSwedish.
  ///
  /// In it, this message translates to:
  /// **'Svedese'**
  String get radioCommunityLanguageSwedish;

  /// Localized text for radioCommunityLanguageVietnamese.
  ///
  /// In it, this message translates to:
  /// **'Vietnamita'**
  String get radioCommunityLanguageVietnamese;

  /// Localized text for radioCommunityLanguageCzech.
  ///
  /// In it, this message translates to:
  /// **'Ceco'**
  String get radioCommunityLanguageCzech;

  /// Localized text for radioCommunityLanguagePolish.
  ///
  /// In it, this message translates to:
  /// **'Polacco'**
  String get radioCommunityLanguagePolish;

  /// Localized text for radioCommunityLanguageSerbian.
  ///
  /// In it, this message translates to:
  /// **'Serbo'**
  String get radioCommunityLanguageSerbian;

  /// Localized text for radioCommunityLanguageUkrainian.
  ///
  /// In it, this message translates to:
  /// **'Ucraino'**
  String get radioCommunityLanguageUkrainian;

  /// Localized text for radioCommunityLanguageLithuanian.
  ///
  /// In it, this message translates to:
  /// **'Lituano'**
  String get radioCommunityLanguageLithuanian;

  /// Localized text for radioCommunityLanguageRussian.
  ///
  /// In it, this message translates to:
  /// **'Russo'**
  String get radioCommunityLanguageRussian;

  /// Localized text for radioCommunityLanguageChinese.
  ///
  /// In it, this message translates to:
  /// **'Cinese'**
  String get radioCommunityLanguageChinese;

  /// Localized text for radioCommunityLanguageHindi.
  ///
  /// In it, this message translates to:
  /// **'Hindi'**
  String get radioCommunityLanguageHindi;

  /// Formatted route distance in meters.
  ///
  /// In it, this message translates to:
  /// **'{meters} m'**
  String routeDistanceMeters(int meters);

  /// Formatted route distance in kilometers.
  ///
  /// In it, this message translates to:
  /// **'{kilometers} km'**
  String routeDistanceKilometers(String kilometers);

  /// Formatted route duration in minutes.
  ///
  /// In it, this message translates to:
  /// **'{minutes} min'**
  String routeDurationMinutes(int minutes);

  /// Formatted route duration in hours and minutes.
  ///
  /// In it, this message translates to:
  /// **'{hours}h {minutes}m'**
  String routeDurationHoursMinutes(int hours, int minutes);

  /// Titolo della schermata dei film al cinema
  ///
  /// In it, this message translates to:
  /// **'Film al cinema'**
  String get cinemaTitle;

  /// Testo quando non ci sono film
  ///
  /// In it, this message translates to:
  /// **'Nessun film trovato al momento.'**
  String get cinemaNoMovies;

  /// Errore caricamento film
  ///
  /// In it, this message translates to:
  /// **'Errore durante il caricamento dei film.'**
  String get cinemaError;

  /// Data di uscita
  ///
  /// In it, this message translates to:
  /// **'Uscito il: {date}'**
  String cinemaReleased(String date);

  /// Label trama
  ///
  /// In it, this message translates to:
  /// **'Trama:'**
  String get cinemaOverviewLabel;

  /// No description provided for @cinemaUpcomingReleases.
  ///
  /// In it, this message translates to:
  /// **'Prossime uscite'**
  String get cinemaUpcomingReleases;

  /// Data di uscita futura
  ///
  /// In it, this message translates to:
  /// **'Uscirà il: {date}'**
  String cinemaWillRelease(String date);

  /// Label per aprire il trailer
  ///
  /// In it, this message translates to:
  /// **'Apri trailer'**
  String get cinemaOpenTrailer;

  /// No description provided for @concertsTitle.
  ///
  /// In it, this message translates to:
  /// **'Concerti ed eventi'**
  String get concertsTitle;

  /// No description provided for @concertsSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Inserisci una città (es. Milano, Roma)'**
  String get concertsSearchHint;

  /// No description provided for @concertsSearchLabel.
  ///
  /// In it, this message translates to:
  /// **'Cerca concerti per città'**
  String get concertsSearchLabel;

  /// No description provided for @concertsSearchTooltip.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get concertsSearchTooltip;

  /// No description provided for @concertsInitialText.
  ///
  /// In it, this message translates to:
  /// **'Scrivi il nome della tua città in alto per vedere i concerti musicali in programma.'**
  String get concertsInitialText;

  /// No description provided for @concertsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun concerto trovato in questa città.'**
  String get concertsEmpty;

  /// No description provided for @concertsVenue.
  ///
  /// In it, this message translates to:
  /// **'Luogo del concerto:'**
  String get concertsVenue;

  /// No description provided for @concertsBuyTickets.
  ///
  /// In it, this message translates to:
  /// **'Acquista o vedi dettagli su Ticketmaster'**
  String get concertsBuyTickets;

  /// No description provided for @podcastPlayedEpisodes.
  ///
  /// In it, this message translates to:
  /// **'Episodi ascoltati'**
  String get podcastPlayedEpisodes;

  /// Button that opens the podcast date selector.
  ///
  /// In it, this message translates to:
  /// **'Seleziona data'**
  String get podcastSelectDate;

  /// Shown when a podcast feed has no publication dates to choose from.
  ///
  /// In it, this message translates to:
  /// **'Nessuna data disponibile per questi episodi.'**
  String get podcastNoDatesAvailable;

  /// Button and screen title for the podcast chapter list.
  ///
  /// In it, this message translates to:
  /// **'Capitoli'**
  String get podcastChapters;

  /// Shown when no podcast chapters are available for an episode.
  ///
  /// In it, this message translates to:
  /// **'Capitoli non disponibili per questo episodio.'**
  String get podcastChaptersUnavailable;

  /// No description provided for @podcastUnplayed.
  ///
  /// In it, this message translates to:
  /// **'Episodi non ascoltati'**
  String get podcastUnplayed;

  /// Localized text for routeReadAction.
  ///
  /// In it, this message translates to:
  /// **'Leggi percorso'**
  String get routeReadAction;

  /// Localized text for routeSaveAction.
  ///
  /// In it, this message translates to:
  /// **'Salva nei documenti'**
  String get routeSaveAction;

  /// Localized text for routeSaveSuccess.
  ///
  /// In it, this message translates to:
  /// **'Percorso salvato nei documenti'**
  String get routeSaveSuccess;

  /// Localized text for deleteItem.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get deleteItem;

  /// Export format label for audiobook MP3.
  ///
  /// In it, this message translates to:
  /// **'Audiolibro MP3 (.mp3)'**
  String get audiobookMp3Format;

  /// Export format label for audiobook M4B.
  ///
  /// In it, this message translates to:
  /// **'Audiolibro M4B (.m4b)'**
  String get audiobookM4bFormat;

  /// Localized text for exportCompleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Esportazione completata'**
  String get exportCompleteTitle;

  /// Localized text for exportCompleteMessage.
  ///
  /// In it, this message translates to:
  /// **'Il file è stato creato correttamente. Vuoi salvarlo in Sonarpad o condividerlo?'**
  String get exportCompleteMessage;

  /// Localized text for saveInSonarpad.
  ///
  /// In it, this message translates to:
  /// **'Salva in Sonarpad'**
  String get saveInSonarpad;

  /// Localized text for exportSavedInSonarpad.
  ///
  /// In it, this message translates to:
  /// **'File salvato nei Documenti di Sonarpad.'**
  String get exportSavedInSonarpad;

  /// Title shown while exporting an audiobook.
  ///
  /// In it, this message translates to:
  /// **'Creazione audiolibro'**
  String get audiobookExportProgressTitle;

  /// Progress text shown while preparing audiobook export.
  ///
  /// In it, this message translates to:
  /// **'Preparazione dell’audiolibro...'**
  String get audiobookExportPreparing;

  /// Progress text shown while generating audiobook chunks.
  ///
  /// In it, this message translates to:
  /// **'Generazione audio'**
  String get audiobookExportGeneratingAudio;

  /// Progress text shown while converting/merging audiobook audio.
  ///
  /// In it, this message translates to:
  /// **'Conversione finale del file audio...'**
  String get audiobookExportConvertingAudio;

  /// Progress text shown while finalizing audiobook export.
  ///
  /// In it, this message translates to:
  /// **'Finalizzazione...'**
  String get audiobookExportFinalizing;

  /// No description provided for @routeRecentRoutes.
  ///
  /// In it, this message translates to:
  /// **'Percorsi recenti'**
  String get routeRecentRoutes;

  /// No description provided for @routeRecentRoutesEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun percorso recente'**
  String get routeRecentRoutesEmpty;

  /// No description provided for @routeNavigationFromTo.
  ///
  /// In it, this message translates to:
  /// **'Dettagli navigazione da {from} a {to} - {date}'**
  String routeNavigationFromTo(Object from, Object to, Object date);

  /// Button that sorts the subscribed podcasts alphabetically.
  ///
  /// In it, this message translates to:
  /// **'Ordina podcast alfabeticamente'**
  String get sortPodcastsAlphabetically;

  /// Button that sorts radio favorites alphabetically.
  ///
  /// In it, this message translates to:
  /// **'Ordina preferite alfabeticamente'**
  String get sortRadioFavoritesAlphabetically;

  /// Status message shown after podcasts have been sorted alphabetically.
  ///
  /// In it, this message translates to:
  /// **'Podcast ordinati alfabeticamente.'**
  String get podcastsSortedAlphabetically;

  /// Status message shown after radio favorites have been sorted alphabetically.
  ///
  /// In it, this message translates to:
  /// **'Radio preferite ordinate alfabeticamente.'**
  String get radioFavoritesSortedAlphabetically;

  /// Localized text for settingsIncludeFootnotesInText.
  ///
  /// In it, this message translates to:
  /// **'Includi le note a piè di pagina nel testo'**
  String get settingsIncludeFootnotesInText;

  /// Localized text for settingsIncludeFootnotesInTextHint.
  ///
  /// In it, this message translates to:
  /// **'Per gli EPUB supportati, mostra il testo della nota subito dopo il paragrafo che la richiama.'**
  String get settingsIncludeFootnotesInTextHint;

  /// Localized text for documentFootnoteLabel.
  ///
  /// In it, this message translates to:
  /// **'Nota a piè di pagina'**
  String get documentFootnoteLabel;

  /// Title for the setting that enables multiple bookmarks in documents.
  ///
  /// In it, this message translates to:
  /// **'Permetti segnalibri multipli nei documenti'**
  String get settingsMultipleDocumentBookmarks;

  /// Description for the setting that enables multiple bookmarks in documents.
  ///
  /// In it, this message translates to:
  /// **'Se disattivato, resta un solo segnalibro per documento. Se attivato, puoi salvare più segnalibri nello stesso documento.'**
  String get settingsMultipleDocumentBookmarksHint;

  /// Accessibility action and menu entry to open document bookmarks.
  ///
  /// In it, this message translates to:
  /// **'Vai al segnalibro'**
  String get documentGoToBookmarkAction;

  /// Dialog title for choosing a document bookmark.
  ///
  /// In it, this message translates to:
  /// **'Scegli segnalibro'**
  String get documentChooseBookmarkTitle;

  /// Action label to delete a document bookmark.
  ///
  /// In it, this message translates to:
  /// **'Elimina segnalibro'**
  String get documentDeleteBookmarkAction;

  /// Dialog title asking which bookmark to keep when multiple bookmarks are disabled.
  ///
  /// In it, this message translates to:
  /// **'Quale segnalibro vuoi mantenere?'**
  String get documentKeepBookmarkTitle;

  /// Dialog message asking which bookmark to keep when multiple bookmarks are disabled.
  ///
  /// In it, this message translates to:
  /// **'I segnalibri multipli sono disattivati. Scegli un segnalibro da mantenere: gli altri verranno eliminati.'**
  String get documentKeepBookmarkMessage;

  /// Label for a bookmark in the bookmark chooser.
  ///
  /// In it, this message translates to:
  /// **'Segnalibro {order}, paragrafo {paragraph}'**
  String documentBookmarkChoiceLabel(int order, int paragraph);

  /// Label for a bookmark in the bookmark chooser, including a short text preview.
  ///
  /// In it, this message translates to:
  /// **'Segnalibro {order}, paragrafo {paragraph}. {preview}'**
  String documentBookmarkChoiceLabelWithPreview(
      int order, int paragraph, String preview);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'cs',
        'en',
        'es',
        'fr',
        'it',
        'pl',
        'pt'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
