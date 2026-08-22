import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/audiodescription_service.dart';
import '../services/audio_player_service.dart';
import '../services/podcast_cache_service.dart';
import '../tts/edge_tts_bridge.dart';
import '../utils/app_logger.dart';
import 'app_log_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/status_message.dart';
import '../widgets/letter_jump_option_picker_screen.dart';
import '../widgets/universal_accessible_view.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<SonarpadThemeMode>? onThemeModeChanged;

  const SettingsScreen({super.key, this.onThemeModeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _SettingsLeaveAction { save, discard, cancel }

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService();
  final _podcastCache = PodcastCacheService();
  final _flutterTts = FlutterTts();
  final _edgeLanguageFocusNode = FocusNode(debugLabel: 'edge-language');
  final _edgeVoiceFocusNode = FocusNode(debugLabel: 'edge-voice');
  final _viewLogFocusNode = FocusNode();
  String _appLanguage = 'it';
  SonarpadThemeMode _themeMode = SonarpadThemeMode.system;
  WeatherTemperatureUnit _weatherTemperatureUnit = WeatherTemperatureUnit.celsius;
  String _languageCode = 'it';
  String _voice = AppSettingsService.defaultVoiceForLanguage('it');
  List<TtsVoiceLanguage> _edgeLanguages = AppSettingsService.ttsLanguages;
  List<TtsVoiceOption> _edgeVoices = AppSettingsService.ttsVoices;

  String _ttsEngine = 'edge';
  String _systemTtsLanguage = 'it-IT';
  String? _systemTtsVoice;
  List<Map<String, String>> _systemVoices = [];

  double _ttsSpeed = 1.0;
  double _ttsPitch = 1.0;
  bool _loading = true;
  bool _isSaving = false;
  late TextEditingController _tvSecretCodeController;
  bool _testingVoice = false;
  bool _clearingPodcastCache = false;
  int _podcastCacheBytes = 0;
  bool _autoBookmark = true;
  bool _includeEpubFootnotesInText = false;
  bool _multipleDocumentBookmarks = false;
  bool _displayVideoInPortrait = false;
  bool _homeGroupingEnabled = false;
  bool _developerModeEnabled = false;
  bool _useFlutterAccessibleRendererOnIos = false;
  int _seekSliderStep = 60;
  int _documentSliderStepPercent =
      AppSettingsService.defaultDocumentSliderStepPercent;
  int _documentReadingSleepTimerMinutes =
      AppSettingsService.defaultDocumentReadingSleepTimerMinutes;
  final _audio = AudioPlayerService();
  String _savedTvSecretCode = '';
  String _savedAppLanguage = 'it';
  SonarpadThemeMode _savedThemeMode = SonarpadThemeMode.system;
  WeatherTemperatureUnit _savedWeatherTemperatureUnit = WeatherTemperatureUnit.celsius;
  String _savedLanguageCode = 'it';
  String _savedVoice = AppSettingsService.defaultVoiceForLanguage('it');
  String _savedTtsEngine = 'edge';
  String _savedSystemTtsLanguage = 'it-IT';
  String? _savedSystemTtsVoice;
  double _savedTtsSpeed = 1.0;
  double _savedTtsPitch = 1.0;
  bool _savedAutoBookmark = true;
  bool _savedIncludeEpubFootnotesInText = false;
  bool _savedMultipleDocumentBookmarks = false;
  bool _savedDisplayVideoInPortrait = false;
  bool _savedHomeGroupingEnabled = false;
  int _savedSeekSliderStep = 60;
  int _savedDocumentSliderStepPercent =
      AppSettingsService.defaultDocumentSliderStepPercent;
  int _savedDocumentReadingSleepTimerMinutes =
      AppSettingsService.defaultDocumentReadingSleepTimerMinutes;

  String get _multipleDocumentBookmarksTitle =>
      AppLocalizations.of(context).settingsMultipleDocumentBookmarks;

  String get _multipleDocumentBookmarksHint =>
      AppLocalizations.of(context).settingsMultipleDocumentBookmarksHint;

  String _formatTime(int totalSeconds) {
    final l10n = AppLocalizations.of(context);
    if (totalSeconds < 60) {
      final unit = totalSeconds == 1
          ? l10n.mediaCutterDurationSecondOne
          : l10n.mediaCutterDurationSecondFew;
      return '$totalSeconds $unit';
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final minuteUnit = minutes == 1
        ? l10n.mediaCutterDurationMinuteOne
        : l10n.mediaCutterDurationMinuteFew;
    final secondUnit = seconds == 1
        ? l10n.mediaCutterDurationSecondOne
        : l10n.mediaCutterDurationSecondFew;
    final minuteText = '$minutes $minuteUnit';
    if (seconds == 0) return minuteText;
    return '$minuteText ${l10n.mediaCutterDurationAnd} $seconds $secondUnit';
  }

  String _formatPercent(int value) => '$value%';

  String _formatSleepTimerMinutes(int value) {
    final l10n = AppLocalizations.of(context);
    if (value <= 0) return l10n.settingsReadingSleepTimerOff;
    return l10n.settingsReadingSleepTimerMinutes(value);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb < 10 ? 1 : 0)} GB';
  }

  int get _documentSliderStepOptionIndex {
    final options = AppSettingsService.documentSliderStepPercentOptions;
    final exact = options.indexOf(_documentSliderStepPercent);
    if (exact >= 0) return exact;
    var bestIndex = 0;
    var bestDistance = (_documentSliderStepPercent - options.first).abs();
    for (var i = 1; i < options.length; i++) {
      final distance = (_documentSliderStepPercent - options[i]).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  int _documentSliderStepAt(int index) {
    final options = AppSettingsService.documentSliderStepPercentOptions;
    final clampedIndex = index.clamp(0, options.length - 1).toInt();
    return options[clampedIndex];
  }

  int get _documentReadingSleepTimerOptionIndex {
    final options = AppSettingsService.documentReadingSleepTimerMinutesOptions;
    final exact = options.indexOf(_documentReadingSleepTimerMinutes);
    if (exact >= 0) return exact;
    var bestIndex = 0;
    var bestDistance = (_documentReadingSleepTimerMinutes - options.first).abs();
    for (var i = 1; i < options.length; i++) {
      final distance = (_documentReadingSleepTimerMinutes - options[i]).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  int _documentReadingSleepTimerAt(int index) {
    final options = AppSettingsService.documentReadingSleepTimerMinutesOptions;
    final clampedIndex = index.clamp(0, options.length - 1).toInt();
    return options[clampedIndex];
  }

  void _setDocumentReadingSleepTimerByIndex(double value) {
    setState(() {
      _documentReadingSleepTimerMinutes =
          _documentReadingSleepTimerAt(value.round());
    });
  }

  void _increaseDocumentReadingSleepTimer() {
    setState(() {
      _documentReadingSleepTimerMinutes = _documentReadingSleepTimerAt(
        _documentReadingSleepTimerOptionIndex + 1,
      );
    });
  }

  void _decreaseDocumentReadingSleepTimer() {
    setState(() {
      _documentReadingSleepTimerMinutes = _documentReadingSleepTimerAt(
        _documentReadingSleepTimerOptionIndex - 1,
      );
    });
  }

  void _setDocumentSliderStepByIndex(double value) {
    setState(() {
      _documentSliderStepPercent = _documentSliderStepAt(value.round());
    });
  }

  void _increaseDocumentSliderStep() {
    setState(() {
      _documentSliderStepPercent =
          _documentSliderStepAt(_documentSliderStepOptionIndex + 1);
    });
  }

  void _decreaseDocumentSliderStep() {
    setState(() {
      _documentSliderStepPercent =
          _documentSliderStepAt(_documentSliderStepOptionIndex - 1);
    });
  }

  @override
  void initState() {
    super.initState();
    _tvSecretCodeController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _edgeLanguageFocusNode.dispose();
    _edgeVoiceFocusNode.dispose();
    _viewLogFocusNode.dispose();
    _tvSecretCodeController.dispose();
    unawaited(_audio.stop().whenComplete(_audio.dispose));
    super.dispose();
  }

  Future<void> _load() async {
    final appLang = await _settings.loadAppLanguage();
    final themeMode = await _settings.loadThemeMode();
    final weatherTemperatureUnit = await _settings.loadWeatherTemperatureUnit();
    final language = await _settings.loadTtsLanguage();
    final voice = await _settings.loadTtsVoice();
    final speed = await _settings.loadTtsSpeed();
    final pitch = await _settings.loadTtsPitch();
    final tvSecretCode = await _settings.getTvSecretCode();

    final ttsEngine = await _settings.loadTtsEngine();
    final sysLang = await _settings.loadSystemTtsLanguage();
    final sysVoice = await _settings.loadSystemTtsVoice();
    final autoBookmark = await _settings.isAutoBookmarkEnabled();
    final includeEpubFootnotesInText =
        await _settings.includeEpubFootnotesInText();
    final multipleDocumentBookmarks =
        await _settings.multipleDocumentBookmarksEnabled();
    final displayVideoInPortrait =
        await _settings.displayVideoInPortrait();
    final homeGrouping = await _settings.isHomeGroupingEnabled();
    final developerModeEnabled = await _settings.isDeveloperModeEnabled();
    final useFlutterAccessibleRendererOnIos = developerModeEnabled &&
            canChooseAccessibleRendererAtRuntime
        ? await _settings.useFlutterAccessibleRendererOnIos()
        : false;
    final seekSliderStep = await _settings.loadSeekSliderStep();
    final documentSliderStepPercent =
        await _settings.loadDocumentSliderStepPercent();
    final documentReadingSleepTimerMinutes =
        await _settings.loadDocumentReadingSleepTimerMinutes();
    await _podcastCache.cleanAutomatically();
    final podcastCacheBytes = await _podcastCache.cacheSizeBytes();
    final edgeVoices = await AppSettingsService.loadEdgeVoices();
    final edgeLanguages = AppSettingsService.languagesForVoices(edgeVoices);
    final normalizedLanguage = AppSettingsService.normalizedTtsLanguageCodeFor(
      edgeLanguages,
      edgeVoices,
      language,
      voice,
    );

    await _loadSystemVoices();

    if (!mounted) return;
    setState(() {
      _appLanguage = appLang;
      _savedAppLanguage = appLang;
      _themeMode = themeMode;
      _savedThemeMode = themeMode;
      _weatherTemperatureUnit = weatherTemperatureUnit;
      _savedWeatherTemperatureUnit = weatherTemperatureUnit;
      _edgeLanguages = edgeLanguages;
      _edgeVoices = edgeVoices;
      _languageCode = normalizedLanguage;
      _savedLanguageCode = normalizedLanguage;
      _voice = _validVoiceForLanguage(normalizedLanguage, voice);
      _savedVoice = _voice;
      _ttsSpeed = speed;
      _savedTtsSpeed = speed;
      _ttsPitch = pitch;
      _savedTtsPitch = pitch;
      _tvSecretCodeController.text = tvSecretCode;
      _savedTvSecretCode = tvSecretCode;
      _ttsEngine = ttsEngine;
      _savedTtsEngine = ttsEngine;
      _systemTtsLanguage = sysLang;
      _savedSystemTtsLanguage = sysLang;
      _systemTtsVoice = sysVoice;
      _savedSystemTtsVoice = sysVoice;
      _autoBookmark = autoBookmark;
      _savedAutoBookmark = autoBookmark;
      _includeEpubFootnotesInText = includeEpubFootnotesInText;
      _savedIncludeEpubFootnotesInText = includeEpubFootnotesInText;
      _multipleDocumentBookmarks = multipleDocumentBookmarks;
      _savedMultipleDocumentBookmarks = multipleDocumentBookmarks;
      _displayVideoInPortrait = displayVideoInPortrait;
      _savedDisplayVideoInPortrait = displayVideoInPortrait;
      _homeGroupingEnabled = homeGrouping;
      _savedHomeGroupingEnabled = homeGrouping;
      _developerModeEnabled = developerModeEnabled;
      _useFlutterAccessibleRendererOnIos =
          useFlutterAccessibleRendererOnIos;
      _seekSliderStep = seekSliderStep;
      _savedSeekSliderStep = seekSliderStep;
      _documentSliderStepPercent = documentSliderStepPercent;
      _savedDocumentSliderStepPercent = documentSliderStepPercent;
      _documentReadingSleepTimerMinutes = documentReadingSleepTimerMinutes;
      _savedDocumentReadingSleepTimerMinutes =
          documentReadingSleepTimerMinutes;
      _podcastCacheBytes = podcastCacheBytes;
      _loading = false;
    });
  }

  Future<void> _loadSystemVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices != null && voices is List) {
        final List<Map<String, String>> parsedVoices = [];
        for (var v in voices) {
          if (v is Map) {
            final name = v['name']?.toString() ?? '';
            final locale = v['locale']?.toString() ?? '';
            if (name.isNotEmpty && locale.isNotEmpty) {
              parsedVoices.add({'name': name, 'locale': locale});
            }
          }
        }
        _systemVoices = parsedVoices;
      }
    } catch (e) {
      debugPrint('Errore caricamento voci di sistema: $e');
    }
  }

  Future<void> _save({bool showConfirmation = true}) async {
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context);
    final rawCode = _tvSecretCodeController.text.trim();
    final codeChanged = rawCode != _savedTvSecretCode;
    final appLanguageChanged = _appLanguage != _savedAppLanguage;
    final themeChanged = _themeMode != _savedThemeMode;
    final weatherTemperatureUnitChanged =
        _weatherTemperatureUnit != _savedWeatherTemperatureUnit;
    final autoBookmarkChanged = _autoBookmark != _savedAutoBookmark;
    final includeEpubFootnotesChanged = _includeEpubFootnotesInText !=
        _savedIncludeEpubFootnotesInText;
    final multipleDocumentBookmarksChanged =
        _multipleDocumentBookmarks != _savedMultipleDocumentBookmarks;
    final displayVideoInPortraitChanged =
        _displayVideoInPortrait != _savedDisplayVideoInPortrait;
    final homeGroupingChanged = _homeGroupingEnabled != _savedHomeGroupingEnabled;
    final seekSliderStepChanged = _seekSliderStep != _savedSeekSliderStep;
    final documentSliderStepChanged =
        _documentSliderStepPercent != _savedDocumentSliderStepPercent;
    final documentReadingSleepTimerChanged = _documentReadingSleepTimerMinutes !=
        _savedDocumentReadingSleepTimerMinutes;
    final ttsEngineChanged = _ttsEngine != _savedTtsEngine;
    final ttsSettingsChanged = ttsEngineChanged ||
        _languageCode != _savedLanguageCode ||
        _voice != _savedVoice ||
        _systemTtsLanguage != _savedSystemTtsLanguage ||
        _systemTtsVoice != _savedSystemTtsVoice ||
        _ttsSpeed != _savedTtsSpeed ||
        _ttsPitch != _savedTtsPitch;
    final anySettingsChanged = codeChanged ||
        appLanguageChanged ||
        themeChanged ||
        weatherTemperatureUnitChanged ||
        autoBookmarkChanged ||
        includeEpubFootnotesChanged ||
        multipleDocumentBookmarksChanged ||
        displayVideoInPortraitChanged ||
        homeGroupingChanged ||
        seekSliderStepChanged ||
        documentSliderStepChanged ||
        documentReadingSleepTimerChanged ||
        ttsSettingsChanged;
    final savedMessage = codeChanged && rawCode.isNotEmpty
        ? l10n.sonarpadCodeValidMessage
        : l10n.settingsSaved;

    await AppLogger.log(
      'Settings: save start anySettingsChanged=$anySettingsChanged '
      'appLanguageChanged=$appLanguageChanged themeChanged=$themeChanged '
      'weatherTemperatureUnitChanged=$weatherTemperatureUnitChanged '
      'codeChanged=$codeChanged autoBookmarkChanged=$autoBookmarkChanged '
      'includeEpubFootnotesChanged=$includeEpubFootnotesChanged '
      'multipleDocumentBookmarksChanged=$multipleDocumentBookmarksChanged '
      'displayVideoInPortraitChanged=$displayVideoInPortraitChanged '
      'homeGroupingChanged=$homeGroupingChanged '
      'seekSliderStepChanged=$seekSliderStepChanged '
      'documentSliderStepChanged=$documentSliderStepChanged '
      'documentReadingSleepTimerChanged=$documentReadingSleepTimerChanged '
      'ttsEngine=$_ttsEngine previous=$_savedTtsEngine '
      'ttsSettingsChanged=$ttsSettingsChanged voice=$_voice savedVoice=$_savedVoice '
      'systemVoice=$_systemTtsVoice savedSystemVoice=$_savedSystemTtsVoice',
    );

    if (codeChanged && rawCode.isNotEmpty) {
      try {
        await AudiodescriptionService().fetchRecentCatalog(rawCode);
      } catch (e) {
        setState(() => _isSaving = false);
        await AppLogger.log('Settings: save failed invalid Sonarpad code: $e');
        if (!mounted) return;
        await _showSaveResultDialog(
          title: l10n.sonarpadCodeInvalidTitle,
          message: l10n.sonarpadCodeInvalidMessage,
        );
        return;
      }
    }

    await _saveTtsSelection();
    if (anySettingsChanged) {
      await _stabilizeAccessibilityAfterSettingsChange(
        ttsSettingsChanged: ttsSettingsChanged,
        engineChanged: ttsEngineChanged,
      );
    }
    await _settings.saveAppLanguage(_appLanguage);
    await _settings.saveThemeMode(_themeMode);
    await _settings.saveWeatherTemperatureUnit(_weatherTemperatureUnit);
    await _settings.saveTtsSpeed(_ttsSpeed);
    await _settings.saveTtsPitch(_ttsPitch);
    await _settings.setTvSecretCode(rawCode);
    await _settings.setAutoBookmarkEnabled(_autoBookmark);
    await _settings.setIncludeEpubFootnotesInText(_includeEpubFootnotesInText);
    await _settings.setMultipleDocumentBookmarksEnabled(_multipleDocumentBookmarks);
    await _settings.setDisplayVideoInPortrait(_displayVideoInPortrait);
    await _settings.setHomeGroupingEnabled(_homeGroupingEnabled);
    await _settings.saveSeekSliderStep(_seekSliderStep);
    await _settings.saveDocumentSliderStepPercent(_documentSliderStepPercent);
    await _settings.saveDocumentReadingSleepTimerMinutes(
      _documentReadingSleepTimerMinutes,
    );
    _markSaved(rawCode);

    if (!mounted) return;
    setState(() => _isSaving = false);

    // Evita di ricostruire inutilmente tutto il MaterialApp quando l'utente
    // salva solo il motore/voce TTS. Su iOS questa ricostruzione può far
    // perdere temporaneamente il focus e l'albero semantico a VoiceOver.
    if (themeChanged) {
      widget.onThemeModeChanged?.call(_themeMode);
    }

    unawaited(AppLogger.log('Settings: save completed'));

    if (showConfirmation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showStatusMessage(context, savedMessage);
      });
    }
  }

  Future<void> _stabilizeAccessibilityAfterSettingsChange({
    required bool ttsSettingsChanged,
    required bool engineChanged,
  }) async {
    try {
      await AppLogger.log(
        'Settings: settings changed, stabilizing accessibility '
        'ttsSettingsChanged=$ttsSettingsChanged engineChanged=$engineChanged '
        'savedEngine=$_savedTtsEngine newEngine=$_ttsEngine '
        'savedEdgeVoice=$_savedVoice newEdgeVoice=$_voice '
        'savedSystemVoice=$_savedSystemTtsVoice newSystemVoice=$_systemTtsVoice',
      );

      // Qualunque impostazione venga salvata può lasciare attive sessioni
      // audio di prova o una sessione TTS inizializzata mentre l'utente era
      // nella schermata impostazioni. Prima di restituire il focus a
      // VoiceOver/TalkBack le fermiamo sempre.
      await _audio.stop();
      await _flutterTts.stop();

      // La parte più delicata è iOS: se il motore finale è Edge, il TTS di
      // sistema non deve restare con una shared session attiva. La protezione
      // viene applicata anche se è cambiata una qualsiasi altra impostazione,
      // non solo quando cambia voce o motore TTS.
      if (Platform.isIOS && _ttsEngine == 'edge') {
        await _flutterTts.autoStopSharedSession(true);
        await _flutterTts.setSharedInstance(false);
      }

      // Piccolo respiro per lasciare al framework il tempo di chiudere le
      // sessioni native prima dello SnackBar/annuncio semantico.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      await AppLogger.log('Settings: accessibility stabilization completed');
    } catch (error) {
      await AppLogger.log('Settings: accessibility stabilization failed: $error');
    }
  }

  Future<void> _showSaveResultDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
    if (!mounted) return;
  }

  void _markSaved(String rawCode) {
    _savedAppLanguage = _appLanguage;
    _savedThemeMode = _themeMode;
    _savedWeatherTemperatureUnit = _weatherTemperatureUnit;
    _savedLanguageCode = _languageCode;
    _savedVoice = _voice;
    _savedTtsEngine = _ttsEngine;
    _savedSystemTtsLanguage = _systemTtsLanguage;
    _savedSystemTtsVoice = _systemTtsVoice;
    _savedTtsSpeed = _ttsSpeed;
    _savedTtsPitch = _ttsPitch;
    _savedTvSecretCode = rawCode;
    _savedAutoBookmark = _autoBookmark;
    _savedIncludeEpubFootnotesInText = _includeEpubFootnotesInText;
    _savedMultipleDocumentBookmarks = _multipleDocumentBookmarks;
    _savedDisplayVideoInPortrait = _displayVideoInPortrait;
    _savedHomeGroupingEnabled = _homeGroupingEnabled;
    _savedSeekSliderStep = _seekSliderStep;
    _savedDocumentSliderStepPercent = _documentSliderStepPercent;
    _savedDocumentReadingSleepTimerMinutes = _documentReadingSleepTimerMinutes;
  }

  bool get _hasUnsavedChanges {
    if (_loading) return false;
    return _appLanguage != _savedAppLanguage ||
        _themeMode != _savedThemeMode ||
        _weatherTemperatureUnit != _savedWeatherTemperatureUnit ||
        _languageCode != _savedLanguageCode ||
        _voice != _savedVoice ||
        _ttsEngine != _savedTtsEngine ||
        _systemTtsLanguage != _savedSystemTtsLanguage ||
        _systemTtsVoice != _savedSystemTtsVoice ||
        _ttsSpeed != _savedTtsSpeed ||
        _ttsPitch != _savedTtsPitch ||
        _tvSecretCodeController.text.trim() != _savedTvSecretCode ||
        _autoBookmark != _savedAutoBookmark ||
        _includeEpubFootnotesInText != _savedIncludeEpubFootnotesInText ||
        _multipleDocumentBookmarks != _savedMultipleDocumentBookmarks ||
        _displayVideoInPortrait != _savedDisplayVideoInPortrait ||
        _homeGroupingEnabled != _savedHomeGroupingEnabled ||
        _seekSliderStep != _savedSeekSliderStep ||
        _documentSliderStepPercent != _savedDocumentSliderStepPercent ||
        _documentReadingSleepTimerMinutes !=
            _savedDocumentReadingSleepTimerMinutes;
  }

  Future<bool> _confirmLeaveSettings() async {
    if (!_hasUnsavedChanges || _isSaving) return true;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_SettingsLeaveAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsUnsavedTitle),
        content: Text(l10n.settingsUnsavedMessage),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _SettingsLeaveAction.cancel),
            child: Text(l10n.annulla),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _SettingsLeaveAction.discard),
            child: Text(l10n.settingsExitWithoutSaving),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _SettingsLeaveAction.save),
            child: Text(l10n.saveSettings),
          ),
        ],
      ),
    );

    if (result == _SettingsLeaveAction.discard) {
      // The app language is applied by Home from the value returned by
      // this route. Returning the unsaved picker value would make a
      // discarded language appear active until Settings is opened again,
      // while SharedPreferences still contains the previously saved one.
      // Restore the saved value before popping so discard is immediate and
      // consistent both on screen and on the next Settings visit.
      if (_appLanguage != _savedAppLanguage && mounted) {
        setState(() => _appLanguage = _savedAppLanguage);
      }
      return true;
    }
    if (result == _SettingsLeaveAction.save) {
      await _save(showConfirmation: false);
      return !_hasUnsavedChanges;
    }
    return false;
  }

  Future<void> _reloadPodcastCacheSize() async {
    final bytes = await _podcastCache.cacheSizeBytes();
    if (!mounted) return;
    setState(() => _podcastCacheBytes = bytes);
  }

  Future<void> _clearPodcastCache() async {
    if (_clearingPodcastCache) return;
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmClearPodcastCacheTitle),
        content: Text(l10n.confirmClearPodcastCacheMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearPodcastCache),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _clearingPodcastCache = true);
    try {
      final freedBytes = await _podcastCache.clearCache();
      await _reloadPodcastCacheSize();
      if (!mounted) return;
      final message = freedBytes > 0
          ? l10n.podcastCacheCleared(_formatBytes(freedBytes))
          : l10n.podcastCacheEmpty;
      showStatusMessage(context, message);
    } catch (e) {
      if (!mounted) return;
      showStatusMessage(context, l10n.error(l10n.technicalErrorGeneric));
    } finally {
      if (mounted) {
        setState(() => _clearingPodcastCache = false);
      }
    }
  }

  Future<void> _testVoice() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _testingVoice = true);
    try {
      await _audio.stop();
      await _flutterTts.stop();

      final previewSpeed = _ttsSpeed.clamp(0.5, 2.0).toDouble();
      final previewPitch = _ttsPitch.clamp(0.5, 2.0).toDouble();

      if (_ttsEngine == 'system') {
        await _flutterTts
            .setSpeechRate(previewSpeed * 0.5); // flutter_tts usa range 0-1
        await _flutterTts.setPitch(previewPitch);
        if (_systemTtsVoice != null) {
          await _flutterTts.setVoice(
              {"name": _systemTtsVoice!, "locale": _systemTtsLanguage});
        } else {
          await _flutterTts.setLanguage(_systemTtsLanguage);
        }
        await _flutterTts.speak(l10n.settingsVoiceTestText);
        // _flutterTts is asynchronous but we can just wait, or not wait.
        // For simplicity, we just trigger speak.
      } else {
        final tts = EdgeTtsBridge();
        final file = await tts.speakToFile(
          text: l10n.settingsVoiceTestText,
          voice: _voice,
          speed: previewSpeed,
          pitch: previewPitch,
        );
        if (!mounted) return;
        await _audio.playFile(file);
      }
    } catch (e) {
      if (!mounted) return;
      showStatusMessage(context, l10n.settingsVoiceTestError(l10n.technicalErrorGeneric));
    } finally {
      if (mounted) {
        setState(() => _testingVoice = false);
      }
    }
  }

  Future<void> _saveTtsSelection() async {
    await _settings.saveTtsEngine(_ttsEngine);
    await _settings.saveTtsSettings(
      languageCode: _languageCode,
      voice: _voice,
    );
    await _settings.saveSystemTtsLanguage(_systemTtsLanguage);
    await _settings.saveSystemTtsVoice(_systemTtsVoice);
  }

  String _validVoiceForLanguage(String languageCode, String voice) {
    final voices = AppSettingsService.voicesForLanguageFrom(
      _edgeVoices,
      languageCode,
    );
    if (voices.any((option) => option.voice == voice)) return voice;
    return AppSettingsService.defaultVoiceForLanguageFrom(
      _edgeVoices,
      languageCode,
    );
  }

  TtsVoiceLanguage? get _selectedEdgeLanguage {
    for (final language in _edgeLanguages) {
      if (language.code == _languageCode) return language;
    }
    return _edgeLanguages.isEmpty ? null : _edgeLanguages.first;
  }

  TtsVoiceOption? get _selectedEdgeVoice {
    final voices = AppSettingsService.voicesForLanguageFrom(
      _edgeVoices,
      _languageCode,
    );
    for (final voice in voices) {
      if (voice.voice == _voice) return voice;
    }
    return voices.isEmpty ? null : voices.first;
  }

  Future<void> _restoreControlFocus(FocusNode focusNode) async {
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    focusNode.requestFocus();

    // VoiceOver può ricevere il nuovo albero semantico con qualche istante di
    // ritardo dopo la rimozione di una route. Un secondo aggancio al controllo
    // reale evita che il focus resti sul nodo ormai eliminato del selettore.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    focusNode.requestFocus();
  }

  Future<void> _openEdgeLanguagePicker() async {
    final l10n = AppLocalizations.of(context);
    final languages = List<TtsVoiceLanguage>.of(_edgeLanguages)
      ..sort((a, b) => a.label.compareTo(b.label));

    final result = await Navigator.of(context).push<TtsVoiceLanguage>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/settings/edge-languages'),
        builder: (_) => LetterJumpOptionPickerScreen<TtsVoiceLanguage>(
          title: l10n.ttsVoiceLanguage,
          options: languages,
          labelBuilder: (language) => language.label,
          selectedBuilder: (language) => language.code == _languageCode,
          selectedLabel: l10n.letterJumpSelected,
          leadingBuilder: (selected) =>
              Icon(selected ? Icons.check : Icons.language),
          selectLetterLabel: l10n.letterJumpSelectLetter,
          selectLetterTitle: l10n.letterJumpSelectLetter,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null && result.code != _languageCode) {
      setState(() {
        _languageCode = result.code;
        _voice = AppSettingsService.defaultVoiceForLanguageFrom(
          _edgeVoices,
          result.code,
        );
      });
    }
    await _restoreControlFocus(_edgeLanguageFocusNode);
  }

  Future<void> _openEdgeVoicePicker() async {
    final l10n = AppLocalizations.of(context);
    final voices = List<TtsVoiceOption>.of(
      AppSettingsService.voicesForLanguageFrom(
        _edgeVoices,
        _languageCode,
      ),
    )..sort((a, b) => a.label.compareTo(b.label));

    final result = await Navigator.of(context).push<TtsVoiceOption>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/settings/edge-voices'),
        builder: (_) => LetterJumpOptionPickerScreen<TtsVoiceOption>(
          title: l10n.ttsVoice,
          options: voices,
          labelBuilder: (voice) => '${voice.label} (${voice.voice})',
          selectedBuilder: (voice) => voice.voice == _voice,
          selectedLabel: l10n.letterJumpSelected,
          leadingBuilder: (selected) =>
              Icon(selected ? Icons.check : Icons.record_voice_over),
          selectLetterLabel: l10n.letterJumpSelectLetter,
          selectLetterTitle: l10n.letterJumpSelectLetter,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null && result.voice != _voice) {
      setState(() => _voice = result.voice);
    }
    await _restoreControlFocus(_edgeVoiceFocusNode);
  }

  double _sliderStep(double value, double delta) {
    final next = (value + delta).clamp(0.5, 2.0);
    return (next * 10).round() / 10;
  }

  void _setTtsSpeed(double value) {
    setState(() => _ttsSpeed = value);
  }

  void _setTtsPitch(double value) {
    setState(() => _ttsPitch = value);
  }

  Future<void> _requestSecretCode() async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.settingsRequestCode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.settingsName),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: surnameCtrl,
                decoration: InputDecoration(labelText: l10n.settingsSurname),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: l10n.settingsEmail),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.settingsCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.settingsSend),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final name = nameCtrl.text.trim();
      final surname = surnameCtrl.text.trim();
      final email = emailCtrl.text.trim();

      if (name.isEmpty || surname.isEmpty || email.isEmpty) {
        if (!mounted) return;
                showStatusMessage(context, l10n.settingsFillFieldsCode);
        return;
      }

      const subject = 'Richiesta Codice Sonarpad';
      final os = Platform.isIOS
          ? 'iOS'
          : Platform.isAndroid
              ? 'Android'
              : Platform.isWindows
                  ? 'Windows'
                  : Platform.isMacOS
                      ? 'macOS'
                      : Platform.isLinux
                          ? 'Linux'
                          : 'Sconosciuto';

      final body = l10n.settingsCodeRequestBody(name, surname, email, os);

      // I client mail richiedono %20 per gli spazi nei link mailto, mentre Uri(queryParameters)
      // usa il '+' tipico dell'HTTP, che i client mail non decodificano.
      // Quindi, codifichiamo manualmente con Uri.encodeComponent.
      String encodeQueryParameters(Map<String, String> params) {
        return params.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
      }

      final url = Uri.parse(
        'mailto:ambro86@gmail.com?${encodeQueryParameters({
              'subject': subject,
              'body': body,
            })}',
      );

      try {
        await launchUrl(url);
      } catch (e) {
        if (!mounted) return;
                showStatusMessage(context, l10n.settingsMailOpenError(l10n.technicalErrorGeneric));
      }
    }
  }

  Future<void> _pasteSecretCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _tvSecretCodeController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }


  Widget _buildSharedAccessibleSettings(
    AppLocalizations l10n,
    bool showItalianOnlySettings,
  ) {
    String toggleLabel(bool value) =>
        value ? l10n.settingsToggleOn : l10n.settingsToggleOff;

    final edgeLanguages = List<TtsVoiceLanguage>.of(_edgeLanguages)
      ..sort((a, b) => a.label.compareTo(b.label));
    final edgeVoices = List<TtsVoiceOption>.of(
      AppSettingsService.voicesForLanguageFrom(_edgeVoices, _languageCode),
    )..sort((a, b) => a.label.compareTo(b.label));
    final systemLocales = _systemVoices.map((v) => v['locale']!).toSet().toList()
      ..sort();
    final systemVoices = _systemVoices
        .where((v) => v['locale'] == _systemTtsLanguage)
        .toList();

    final sections = <AccessibleListSection>[
      AccessibleListSection(
        rows: [
          AccessibleListRow(
            id: 'app_language',
            title: l10n.appLanguage,
            kind: 'picker',
            value: _appLanguage,
            valueLabel: switch (_appLanguage) {
              'en' => l10n.english,
              'fr' => l10n.french,
              'es' => l10n.spanish,
              'pt' => '${l10n.radioLanguagePt} (${l10n.radioCountryOptionPt})',
              'pt_BR' => '${l10n.radioLanguagePt} (${l10n.radioCountryOptionBr})',
              'pl' => l10n.radioLanguagePl,
              'cs' => l10n.radioLanguageCs,
              'de' => l10n.german,
              'zh_CN' => l10n.simplifiedChineseLanguageName,
              _ => l10n.italian,
            },
            options: [
              AccessibleOption(value: 'it', label: l10n.italian),
              AccessibleOption(value: 'en', label: l10n.english),
              AccessibleOption(value: 'fr', label: l10n.french),
              AccessibleOption(value: 'es', label: l10n.spanish),
              AccessibleOption(value: 'pt', label: '${l10n.radioLanguagePt} (${l10n.radioCountryOptionPt})'),
              AccessibleOption(value: 'pt_BR', label: '${l10n.radioLanguagePt} (${l10n.radioCountryOptionBr})'),
              AccessibleOption(value: 'pl', label: l10n.radioLanguagePl),
              AccessibleOption(value: 'cs', label: l10n.radioLanguageCs),
              AccessibleOption(value: 'de', label: l10n.german),
              AccessibleOption(value: 'zh_CN', label: l10n.simplifiedChineseLanguageName),
            ],
          ),
          AccessibleListRow(
            id: 'theme',
            title: l10n.settingsTheme,
            kind: 'picker',
            value: _themeMode.value,
            valueLabel: switch (_themeMode) {
              SonarpadThemeMode.light => l10n.settingsThemeLight,
              SonarpadThemeMode.dark => l10n.settingsThemeDark,
              _ => l10n.settingsThemeSystem,
            },
            options: [
              AccessibleOption(value: 'system', label: l10n.settingsThemeSystem),
              AccessibleOption(value: 'light', label: l10n.settingsThemeLight),
              AccessibleOption(value: 'dark', label: l10n.settingsThemeDark),
            ],
          ),
          AccessibleListRow(
            id: 'temperature_unit',
            title: l10n.settingsWeatherTemperatureUnit,
            kind: 'picker',
            value: _weatherTemperatureUnit.value,
            valueLabel: _weatherTemperatureUnit == WeatherTemperatureUnit.celsius
                ? l10n.weatherTemperatureCelsius
                : l10n.weatherTemperatureFahrenheit,
            options: [
              AccessibleOption(value: 'celsius', label: l10n.weatherTemperatureCelsius),
              AccessibleOption(value: 'fahrenheit', label: l10n.weatherTemperatureFahrenheit),
            ],
          ),
        ],
      ),
      AccessibleListSection(
        rows: [
          AccessibleListRow(
            id: 'tts_engine',
            title: l10n.settingsReadingEngine,
            kind: 'picker',
            value: _ttsEngine,
            valueLabel: _ttsEngine == 'edge'
                ? l10n.settingsEdgeTtsQuality
                : l10n.settingsSystemVoices,
            options: [
              AccessibleOption(value: 'edge', label: l10n.settingsEdgeTtsQuality),
              AccessibleOption(value: 'system', label: l10n.settingsSystemVoices),
            ],
          ),
          if (_ttsEngine == 'edge') ...[
            AccessibleListRow(
              id: 'edge_language',
              title: l10n.ttsVoiceLanguage,
              kind: 'picker',
              value: _languageCode,
              valueLabel: _selectedEdgeLanguage?.label ?? _languageCode,
              options: edgeLanguages
                  .map((e) => AccessibleOption(value: e.code, label: e.label))
                  .toList(),
            ),
            AccessibleListRow(
              id: 'edge_voice',
              title: l10n.ttsVoice,
              kind: 'picker',
              value: _voice,
              valueLabel: _selectedEdgeVoice == null
                  ? _voice
                  : '${_selectedEdgeVoice!.label} (${_selectedEdgeVoice!.voice})',
              options: edgeVoices
                  .map((e) => AccessibleOption(
                        value: e.voice,
                        label: '${e.label} (${e.voice})',
                      ))
                  .toList(),
            ),
          ] else ...[
            if (systemLocales.isNotEmpty)
              AccessibleListRow(
                id: 'system_language',
                title: l10n.settingsSystemLanguage,
                kind: 'picker',
                value: _systemTtsLanguage,
                valueLabel: _systemTtsLanguage,
                options: systemLocales
                    .map((e) => AccessibleOption(value: e, label: e))
                    .toList(),
              ),
            AccessibleListRow(
              id: 'system_voice',
              title: l10n.settingsSystemVoice,
              kind: 'picker',
              value: _systemTtsVoice ?? '',
              valueLabel: _systemTtsVoice ?? l10n.settingsDefaultVoice,
              options: [
                AccessibleOption(value: '', label: l10n.settingsDefaultVoice),
                ...systemVoices.map((e) => AccessibleOption(
                      value: e['name'] ?? '',
                      label: e['name'] ?? '',
                    )),
              ],
            ),
          ],
          AccessibleListRow(
            id: 'tts_speed',
            title: l10n.settingsVoiceSpeedLabel,
            kind: 'slider',
            value: '${_ttsSpeed.toStringAsFixed(1)}x',
            valueLabel: '${_ttsSpeed.toStringAsFixed(1)}x',
            sliderValue: _ttsSpeed,
            sliderMin: 0.5,
            sliderMax: 2.0,
            sliderStep: 0.1,
            sliderIncreasedValueLabel:
                '${_sliderStep(_ttsSpeed, 0.1).toStringAsFixed(1)}x',
            sliderDecreasedValueLabel:
                '${_sliderStep(_ttsSpeed, -0.1).toStringAsFixed(1)}x',
          ),
          AccessibleListRow(
            id: 'tts_pitch',
            title: l10n.settingsVoicePitchLabel,
            kind: 'slider',
            value: '${_ttsPitch.toStringAsFixed(1)}x',
            valueLabel: '${_ttsPitch.toStringAsFixed(1)}x',
            sliderValue: _ttsPitch,
            sliderMin: 0.5,
            sliderMax: 2.0,
            sliderStep: 0.1,
            sliderIncreasedValueLabel:
                '${_sliderStep(_ttsPitch, 0.1).toStringAsFixed(1)}x',
            sliderDecreasedValueLabel:
                '${_sliderStep(_ttsPitch, -0.1).toStringAsFixed(1)}x',
          ),
          AccessibleListRow(
            id: 'test_voice',
            title: _testingVoice ? l10n.settingsTestingVoice : l10n.settingsTestVoice,
            kind: 'button',
            enabled: !_testingVoice,
          ),
        ],
      ),
      AccessibleListSection(
        rows: [
          AccessibleListRow(
            id: 'auto_bookmark',
            title: l10n.settingsAutoBookmark,
            subtitle: l10n.settingsAutoBookmarkHint,
            kind: 'toggle',
            toggleValue: _autoBookmark,
            valueLabel: toggleLabel(_autoBookmark),
          ),
          AccessibleListRow(
            id: 'epub_footnotes',
            title: l10n.settingsIncludeFootnotesInText,
            subtitle: l10n.settingsIncludeFootnotesInTextHint,
            kind: 'toggle',
            toggleValue: _includeEpubFootnotesInText,
            valueLabel: toggleLabel(_includeEpubFootnotesInText),
          ),
          AccessibleListRow(
            id: 'multiple_bookmarks',
            title: _multipleDocumentBookmarksTitle,
            subtitle: _multipleDocumentBookmarksHint,
            kind: 'toggle',
            toggleValue: _multipleDocumentBookmarks,
            valueLabel: toggleLabel(_multipleDocumentBookmarks),
          ),
          AccessibleListRow(
            id: 'reading_sleep_timer',
            title: l10n.settingsReadingSleepTimer,
            subtitle: l10n.settingsReadingSleepTimerHint,
            kind: 'slider',
            value: _formatSleepTimerMinutes(_documentReadingSleepTimerMinutes),
            valueLabel: _formatSleepTimerMinutes(_documentReadingSleepTimerMinutes),
            sliderValue: _documentReadingSleepTimerOptionIndex.toDouble(),
            sliderMin: 0,
            sliderMax: (AppSettingsService.documentReadingSleepTimerMinutesOptions.length - 1).toDouble(),
            sliderStep: 1,
            sliderIncreasedValueLabel: _formatSleepTimerMinutes(
              _documentReadingSleepTimerAt(
                _documentReadingSleepTimerOptionIndex + 1,
              ),
            ),
            sliderDecreasedValueLabel: _formatSleepTimerMinutes(
              _documentReadingSleepTimerAt(
                _documentReadingSleepTimerOptionIndex - 1,
              ),
            ),
          ),
          AccessibleListRow(
            id: 'document_slider_step',
            title: l10n.settingsDocumentSliderStep,
            subtitle: l10n.settingsDocumentSliderStepHint,
            kind: 'slider',
            value: _formatPercent(_documentSliderStepPercent),
            valueLabel: _formatPercent(_documentSliderStepPercent),
            sliderValue: _documentSliderStepOptionIndex.toDouble(),
            sliderMin: 0,
            sliderMax: (AppSettingsService.documentSliderStepPercentOptions.length - 1).toDouble(),
            sliderStep: 1,
            sliderIncreasedValueLabel: _formatPercent(
              _documentSliderStepAt(_documentSliderStepOptionIndex + 1),
            ),
            sliderDecreasedValueLabel: _formatPercent(
              _documentSliderStepAt(_documentSliderStepOptionIndex - 1),
            ),
          ),
          AccessibleListRow(
            id: 'video_portrait',
            title: l10n.settingsVideoLandscapeFullscreen,
            subtitle: l10n.settingsVideoLandscapeFullscreenHint,
            kind: 'toggle',
            toggleValue: _displayVideoInPortrait,
            valueLabel: toggleLabel(_displayVideoInPortrait),
          ),
        ],
      ),
      AccessibleListSection(
        footer: '${l10n.settingsPodcastCacheHint} ${l10n.settingsPodcastCacheSize(_formatBytes(_podcastCacheBytes))}',
        rows: [
          AccessibleListRow(
            id: 'clear_podcast_cache',
            title: _clearingPodcastCache ? l10n.loading : l10n.clearPodcastCache,
            kind: 'button',
            enabled: !_clearingPodcastCache,
          ),
        ],
      ),
      if (showItalianOnlySettings)
        AccessibleListSection(
          rows: [
            AccessibleListRow(
              id: 'home_grouping',
              title: l10n.settingsHomeGrouping,
              subtitle: l10n.settingsHomeGroupingHint,
              kind: 'toggle',
              toggleValue: _homeGroupingEnabled,
              valueLabel: toggleLabel(_homeGroupingEnabled),
            ),
            AccessibleListRow(
              id: 'seek_step',
              title: l10n.settingsSeekStep,
              kind: 'slider',
              value: _formatTime(_seekSliderStep),
              valueLabel: _formatTime(_seekSliderStep),
              sliderValue: _seekSliderStep.toDouble(),
              sliderMin: 10,
              sliderMax: 300,
              sliderStep: 10,
              sliderIncreasedValueLabel:
                  _formatTime((_seekSliderStep + 10).clamp(10, 300)),
              sliderDecreasedValueLabel:
                  _formatTime((_seekSliderStep - 10).clamp(10, 300)),
            ),
            AccessibleListRow(
              id: 'tv_secret_code',
              title: l10n.settingsSecretCode,
              kind: 'textField',
              value: _tvSecretCodeController.text,
              placeholder: l10n.settingsSecretCode,
              secure: true,
            ),
            AccessibleListRow(id: 'paste_secret_code', title: l10n.settingsPasteCode, kind: 'button'),
            AccessibleListRow(id: 'request_secret_code', title: l10n.settingsRequestCode, kind: 'button'),
          ],
        ),
      if (_developerModeEnabled && canChooseAccessibleRendererAtRuntime)
        AccessibleListSection(
          header: l10n.developerSectionTitle,
          rows: [
            AccessibleListRow(
              id: 'developer_flutter_renderer',
              title: l10n.developerUseExperimentalFlutterRenderer,
              subtitle: l10n.developerUseExperimentalFlutterRendererHint,
              kind: 'toggle',
              toggleValue: _useFlutterAccessibleRendererOnIos,
            ),
          ],
        ),
      AccessibleListSection(
        rows: [
          AccessibleListRow(
            id: 'save',
            title: _isSaving ? l10n.settingsVerifyCodeAndSave : l10n.saveSettings,
            kind: 'button',
            enabled: !_isSaving,
          ),
          AccessibleListRow(id: 'view_log', title: l10n.settingsViewSysLog, kind: 'button'),
        ],
      ),
    ];

    return UniversalAccessibleList(
      key: const ValueKey('settings-shared-accessible-list'),
      debugTag: 'settings',
      sections: sections,
      onEvent: (event) async {
        final id = event.id;
        if (event.type == 'picker') {
          final value = event.value?.toString() ?? '';
          switch (id) {
            case 'app_language':
              if (value.isNotEmpty && value != _appLanguage) setState(() => _appLanguage = value);
              break;
            case 'theme':
              setState(() => _themeMode = SonarpadThemeMode.values.firstWhere((e) => e.value == value, orElse: () => SonarpadThemeMode.system));
              break;
            case 'temperature_unit':
              setState(() => _weatherTemperatureUnit = WeatherTemperatureUnit.values.firstWhere((e) => e.value == value, orElse: () => WeatherTemperatureUnit.celsius));
              break;
            case 'tts_engine':
              setState(() => _ttsEngine = value);
              break;
            case 'edge_language':
              if (value != _languageCode) {
                setState(() {
                  _languageCode = value;
                  _voice = AppSettingsService.defaultVoiceForLanguageFrom(_edgeVoices, value);
                });
              }
              break;
            case 'edge_voice':
              setState(() => _voice = value);
              break;
            case 'system_language':
              setState(() { _systemTtsLanguage = value; _systemTtsVoice = null; });
              break;
            case 'system_voice':
              setState(() => _systemTtsVoice = value.isEmpty ? null : value);
              break;
          }
        } else if (event.type == 'toggle') {
          final value = event.value == true;
          if (id == 'developer_flutter_renderer') {
            await _settings.setFlutterAccessibleRendererOnIos(value);
            if (!mounted) return;
            setState(() => _useFlutterAccessibleRendererOnIos = value);
            configureAccessibleRendererRuntime(useFlutterOnIos: value);
            return;
          }
          setState(() {
            switch (id) {
              case 'auto_bookmark': _autoBookmark = value; break;
              case 'epub_footnotes': _includeEpubFootnotesInText = value; break;
              case 'multiple_bookmarks': _multipleDocumentBookmarks = value; break;
              case 'video_portrait': _displayVideoInPortrait = value; break;
              case 'home_grouping': _homeGroupingEnabled = value; break;
            }
          });
        } else if (event.type == 'slider') {
          final value = (event.value as num?)?.toDouble();
          if (value == null) return;
          unawaited(AppLogger.log(
            'Settings slider dart begin id=$id value=$value '
            'ttsSpeed=$_ttsSpeed ttsPitch=$_ttsPitch mounted=$mounted',
          ));
          switch (id) {
            case 'tts_speed': _setTtsSpeed(value); break;
            case 'tts_pitch': _setTtsPitch(value); break;
            case 'reading_sleep_timer': _setDocumentReadingSleepTimerByIndex(value); break;
            case 'document_slider_step': _setDocumentSliderStepByIndex(value); break;
            case 'seek_step': setState(() => _seekSliderStep = value.round().clamp(10, 300).toInt()); break;
          }
          unawaited(AppLogger.log(
            'Settings slider dart end id=$id value=$value '
            'ttsSpeed=$_ttsSpeed ttsPitch=$_ttsPitch mounted=$mounted',
          ));
        } else if (event.type == 'textChanged' && id == 'tv_secret_code') {
          final text = event.value?.toString() ?? '';
          _tvSecretCodeController.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
        } else if (event.type == 'activate') {
          switch (id) {
            case 'test_voice': await _testVoice(); break;
            case 'clear_podcast_cache': await _clearPodcastCache(); break;
            case 'paste_secret_code': await _pasteSecretCode(); setState(() {}); break;
            case 'request_secret_code': await _requestSecretCode(); break;
            case 'save': await _save(); break;
            case 'view_log':
              if (!mounted) return;
              await Navigator.of(context).push(MaterialPageRoute<void>(settings: const RouteSettings(name: '/settings/app-log'), builder: (_) => const AppLogScreen()));
              break;
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showItalianOnlySettings = _appLanguage == 'it' &&
        Localizations.localeOf(context).languageCode == 'it';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmLeaveSettings();
        if (!context.mounted || !shouldLeave) return;
        // Non forziamo unfocus prima di uscire: su iOS/VoiceOver può
        // contribuire a lasciare momentaneamente l'app senza un nodo
        // semantico agganciato nella schermata precedente.
        await Future<void>.delayed(Duration.zero);
        if (!context.mounted) return;
        Navigator.of(context).pop(_appLanguage);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.settings)),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(semanticsLabel: l10n.loading))
            : useSharedAccessibleViewModel
                ? _buildSharedAccessibleSettings(l10n, showItalianOnlySettings)
                : ListView(
                  key: const PageStorageKey<String>('settings-list'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _appLanguage,
                      decoration: InputDecoration(labelText: l10n.appLanguage),
                      items: [
                        DropdownMenuItem(
                            value: 'it', child: Text(l10n.italian)),
                        DropdownMenuItem(
                            value: 'en', child: Text(l10n.english)),
                        DropdownMenuItem(value: 'fr', child: Text(l10n.french)),
                        DropdownMenuItem(
                            value: 'es', child: Text(l10n.spanish)),
                        DropdownMenuItem(
                            value: 'pt', child: Text('${l10n.radioLanguagePt} (${l10n.radioCountryOptionPt})')),
                        DropdownMenuItem(
                            value: 'pt_BR', child: Text('${l10n.radioLanguagePt} (${l10n.radioCountryOptionBr})')),
                        DropdownMenuItem(
                            value: 'pl', child: Text(l10n.radioLanguagePl)),
                        DropdownMenuItem(
                            value: 'cs', child: Text(l10n.radioLanguageCs)),
                        DropdownMenuItem(
                            value: 'de', child: Text(l10n.german)),
                        DropdownMenuItem(
                            value: 'zh_CN', child: Text(l10n.simplifiedChineseLanguageName)),
                      ],
                      onChanged: (value) {
                        if (value == null || value == _appLanguage) return;
                        setState(() => _appLanguage = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SonarpadThemeMode>(
                      isExpanded: true,
                      initialValue: _themeMode,
                      decoration: InputDecoration(labelText: l10n.settingsTheme),
                      items: [
                        DropdownMenuItem(
                          value: SonarpadThemeMode.system,
                          child: Text(l10n.settingsThemeSystem),
                        ),
                        DropdownMenuItem(
                          value: SonarpadThemeMode.light,
                          child: Text(l10n.settingsThemeLight),
                        ),
                        DropdownMenuItem(
                          value: SonarpadThemeMode.dark,
                          child: Text(l10n.settingsThemeDark),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _themeMode = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WeatherTemperatureUnit>(
                      isExpanded: true,
                      initialValue: _weatherTemperatureUnit,
                      decoration: InputDecoration(
                        labelText: l10n.settingsWeatherTemperatureUnit,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: WeatherTemperatureUnit.celsius,
                          child: Text(l10n.weatherTemperatureCelsius),
                        ),
                        DropdownMenuItem(
                          value: WeatherTemperatureUnit.fahrenheit,
                          child: Text(l10n.weatherTemperatureFahrenheit),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _weatherTemperatureUnit = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _ttsEngine,
                      decoration: InputDecoration(
                          labelText: l10n.settingsReadingEngine),
                      items: [
                        DropdownMenuItem(
                            value: 'edge',
                            child: Text(l10n.settingsEdgeTtsQuality)),
                        DropdownMenuItem(
                            value: 'system',
                            child: Text(l10n.settingsSystemVoices)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _ttsEngine = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_ttsEngine == 'edge') ...[
                      ListTile(
                        focusNode: _edgeLanguageFocusNode,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.language),
                        title: Text(l10n.ttsVoiceLanguage),
                        subtitle: Text(
                          _selectedEdgeLanguage?.label ?? _languageCode,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openEdgeLanguagePicker,
                      ),
                      const SizedBox(height: 4),
                      ListTile(
                        focusNode: _edgeVoiceFocusNode,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.record_voice_over),
                        title: Text(l10n.ttsVoice),
                        subtitle: Text(
                          _selectedEdgeVoice == null
                              ? _voice
                              : '${_selectedEdgeVoice!.label} '
                                  '(${_selectedEdgeVoice!.voice})',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openEdgeVoicePicker,
                      ),
                    ] else ...[
                      Builder(
                        builder: (context) {
                          final locales = _systemVoices
                              .map((v) => v['locale']!)
                              .toSet()
                              .toList()
                            ..sort();
                          if (locales.isEmpty) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(l10n.settingsNoSystemVoices),
                            );
                          }
                          final availableVoices = _systemVoices
                              .where((v) => v['locale'] == _systemTtsLanguage)
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue:
                                    locales.contains(_systemTtsLanguage)
                                        ? _systemTtsLanguage
                                        : locales.first,
                                decoration: InputDecoration(
                                    labelText: l10n.settingsSystemLanguage),
                                items: locales
                                    .map((l) => DropdownMenuItem(
                                          value: l,
                                          child: Text(
                                            l,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _systemTtsLanguage = value;
                                    _systemTtsVoice = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String?>(
                                isExpanded: true,
                                initialValue: availableVoices.any(
                                        (v) => v['name'] == _systemTtsVoice)
                                    ? _systemTtsVoice
                                    : null,
                                decoration: InputDecoration(
                                    labelText: l10n.settingsSystemVoice),
                                hint: Text(
                                  l10n.settingsDefaultVoiceHint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      l10n.settingsDefaultVoice,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  ...availableVoices
                                      .map((v) => DropdownMenuItem<String?>(
                                            value: v['name'],
                                            child: Text(
                                              v['name'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _systemTtsVoice = value;
                                  });
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                              '${l10n.settingsVoiceSpeed}${_ttsSpeed.toStringAsFixed(1)}x'),
                        ),
                        Semantics(
                          slider: true,
                          label: l10n.settingsVoiceSpeedLabel,
                          value: '${_ttsSpeed.toStringAsFixed(1)}x',
                          increasedValue:
                              '${_sliderStep(_ttsSpeed, 0.1).toStringAsFixed(1)}x',
                          decreasedValue:
                              '${_sliderStep(_ttsSpeed, -0.1).toStringAsFixed(1)}x',
                          onIncrease: () => _setTtsSpeed(
                            _sliderStep(_ttsSpeed, 0.1),
                          ),
                          onDecrease: () => _setTtsSpeed(
                            _sliderStep(_ttsSpeed, -0.1),
                          ),
                          child: ExcludeSemantics(
                            child: Slider(
                              value: _ttsSpeed,
                              min: 0.5,
                              max: 2.0,
                              divisions: 15,
                              onChanged: _setTtsSpeed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                              '${l10n.settingsVoicePitch}${_ttsPitch.toStringAsFixed(1)}x'),
                        ),
                        Semantics(
                          slider: true,
                          label: l10n.settingsVoicePitchLabel,
                          value: '${_ttsPitch.toStringAsFixed(1)}x',
                          increasedValue:
                              '${_sliderStep(_ttsPitch, 0.1).toStringAsFixed(1)}x',
                          decreasedValue:
                              '${_sliderStep(_ttsPitch, -0.1).toStringAsFixed(1)}x',
                          onIncrease: () => _setTtsPitch(
                            _sliderStep(_ttsPitch, 0.1),
                          ),
                          onDecrease: () => _setTtsPitch(
                            _sliderStep(_ttsPitch, -0.1),
                          ),
                          child: ExcludeSemantics(
                            child: Slider(
                              value: _ttsPitch,
                              min: 0.5,
                              max: 2.0,
                              divisions: 15,
                              onChanged: _setTtsPitch,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _testingVoice ? null : _testVoice,
                      icon: _testingVoice
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.volume_up),
                      label: Text(_testingVoice
                          ? l10n.settingsTestingVoice
                          : l10n.settingsTestVoice),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(l10n.settingsAutoBookmark),
                      subtitle: Text(l10n.settingsAutoBookmarkHint),
                      value: _autoBookmark,
                      onChanged: (val) => setState(() => _autoBookmark = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: Text(l10n.settingsIncludeFootnotesInText),
                      subtitle: Text(l10n.settingsIncludeFootnotesInTextHint),
                      value: _includeEpubFootnotesInText,
                      onChanged: (val) => setState(
                        () => _includeEpubFootnotesInText = val,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: Text(_multipleDocumentBookmarksTitle),
                      subtitle: Text(_multipleDocumentBookmarksHint),
                      value: _multipleDocumentBookmarks,
                      onChanged: (val) => setState(
                        () => _multipleDocumentBookmarks = val,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            '${l10n.settingsReadingSleepTimer}: '
                            '${_formatSleepTimerMinutes(_documentReadingSleepTimerMinutes)}',
                          ),
                        ),
                        Semantics(
                          slider: true,
                          label: l10n.settingsReadingSleepTimer,
                          value: _formatSleepTimerMinutes(
                            _documentReadingSleepTimerMinutes,
                          ),
                          increasedValue: _formatSleepTimerMinutes(
                            _documentReadingSleepTimerAt(
                              _documentReadingSleepTimerOptionIndex + 1,
                            ),
                          ),
                          decreasedValue: _formatSleepTimerMinutes(
                            _documentReadingSleepTimerAt(
                              _documentReadingSleepTimerOptionIndex - 1,
                            ),
                          ),
                          onIncrease: _increaseDocumentReadingSleepTimer,
                          onDecrease: _decreaseDocumentReadingSleepTimer,
                          hint: l10n.settingsReadingSleepTimerHint,
                          child: ExcludeSemantics(
                            child: Slider(
                              value: _documentReadingSleepTimerOptionIndex
                                  .toDouble(),
                              min: 0,
                              max: (AppSettingsService
                                          .documentReadingSleepTimerMinutesOptions
                                          .length -
                                      1)
                                  .toDouble(),
                              divisions: AppSettingsService
                                      .documentReadingSleepTimerMinutesOptions
                                      .length -
                                  1,
                              onChanged:
                                  _setDocumentReadingSleepTimerByIndex,
                            ),
                          ),
                        ),
                        ExcludeSemantics(
                          child: Text(l10n.settingsReadingSleepTimerHint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            '${l10n.settingsDocumentSliderStep}: '
                            '${_formatPercent(_documentSliderStepPercent)}',
                          ),
                        ),
                        Semantics(
                          slider: true,
                          label: l10n.settingsDocumentSliderStep,
                          value: _formatPercent(_documentSliderStepPercent),
                          increasedValue: _formatPercent(
                            _documentSliderStepAt(
                              _documentSliderStepOptionIndex + 1,
                            ),
                          ),
                          decreasedValue: _formatPercent(
                            _documentSliderStepAt(
                              _documentSliderStepOptionIndex - 1,
                            ),
                          ),
                          onIncrease: _increaseDocumentSliderStep,
                          onDecrease: _decreaseDocumentSliderStep,
                          hint: l10n.settingsDocumentSliderStepHint,
                          child: ExcludeSemantics(
                            child: Slider(
                              value: _documentSliderStepOptionIndex.toDouble(),
                              min: 0,
                              max: (AppSettingsService
                                          .documentSliderStepPercentOptions
                                          .length -
                                      1)
                                  .toDouble(),
                              divisions: AppSettingsService
                                      .documentSliderStepPercentOptions.length -
                                  1,
                              onChanged: _setDocumentSliderStepByIndex,
                            ),
                          ),
                        ),
                        ExcludeSemantics(
                          child: Text(l10n.settingsDocumentSliderStepHint),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      key: const ValueKey('settings-display-video-in-portrait'),
                      title: Text(l10n.settingsVideoLandscapeFullscreen),
                      subtitle: Text(l10n.settingsVideoLandscapeFullscreenHint),
                      value: _displayVideoInPortrait,
                      onChanged: (val) => setState(
                        () => _displayVideoInPortrait = val,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      container: true,
                      button: true,
                      enabled: !_clearingPodcastCache,
                      label: _clearingPodcastCache
                          ? l10n.loading
                          : l10n.clearPodcastCache,
                      hint: '${l10n.settingsPodcastCacheHint} '
                          '${l10n.settingsPodcastCacheSize(_formatBytes(_podcastCacheBytes))}',
                      onTap: _clearingPodcastCache ? null : _clearPodcastCache,
                      child: ExcludeSemantics(
                        child: Card(
                          child: InkWell(
                            onTap: _clearingPodcastCache
                                ? null
                                : _clearPodcastCache,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l10n.settingsPodcastCacheTitle,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(l10n.settingsPodcastCacheHint),
                                  const SizedBox(height: 8),
                                  Text(l10n.settingsPodcastCacheSize(
                                      _formatBytes(_podcastCacheBytes))),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _clearingPodcastCache
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.delete_sweep),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _clearingPodcastCache
                                              ? l10n.loading
                                              : l10n.clearPodcastCache,
                                          textAlign: TextAlign.end,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showItalianOnlySettings) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: Text(l10n.settingsHomeGrouping),
                        subtitle: Text(l10n.settingsHomeGroupingHint),
                        value: _homeGroupingEnabled,
                        onChanged: (val) =>
                            setState(() => _homeGroupingEnabled = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(
                            child: Text(
                                '${l10n.settingsSeekStep}: ${_formatTime(_seekSliderStep)}'),
                          ),
                          Semantics(
                            slider: true,
                            label: l10n.settingsSeekStep,
                            value: _formatTime(_seekSliderStep),
                            increasedValue: _formatTime(
                                (_seekSliderStep + 10).clamp(10, 300)),
                            decreasedValue: _formatTime(
                                (_seekSliderStep - 10).clamp(10, 300)),
                            onIncrease: () {
                              setState(() {
                                _seekSliderStep =
                                    (_seekSliderStep + 10).clamp(10, 300);
                              });
                            },
                            onDecrease: () {
                              setState(() {
                                _seekSliderStep =
                                    (_seekSliderStep - 10).clamp(10, 300);
                              });
                            },
                            child: ExcludeSemantics(
                              child: Slider(
                                value: _seekSliderStep.toDouble(),
                                min: 10,
                                max: 300,
                                divisions: 29,
                                onChanged: (val) => setState(
                                    () => _seekSliderStep = val.toInt()),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tvSecretCodeController,
                        decoration: InputDecoration(
                          labelText: l10n.settingsSecretCode,
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pasteSecretCode,
                            icon: const Icon(Icons.content_paste),
                            label: Text(l10n.settingsPasteCode),
                          ),
                          OutlinedButton.icon(
                            onPressed: _requestSecretCode,
                            icon: const Icon(Icons.mail_outline),
                            label: Text(l10n.settingsRequestCode),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : () => _save(),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_isSaving
                          ? l10n.settingsVerifyCodeAndSave
                          : l10n.saveSettings),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      focusNode: _viewLogFocusNode,
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            settings:
                                const RouteSettings(name: '/settings/app-log'),
                            builder: (_) => const AppLogScreen(),
                          ),
                        );
                        if (!context.mounted) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          _viewLogFocusNode.requestFocus();
                        });
                      },
                      icon: const Icon(Icons.description),
                      label: Text(l10n.settingsViewSysLog),
                    ),
                  ],
                ),
      ),
    );
  }
}
