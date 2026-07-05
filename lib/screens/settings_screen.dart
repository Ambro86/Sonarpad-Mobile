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
import '../tts/google_tts_bridge.dart';
import '../utils/app_logger.dart';
import 'app_log_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/status_message.dart';

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
  final _screenFocusNode = FocusNode();
  final _viewLogFocusNode = FocusNode();
  String _appLanguage = 'it';
  SonarpadThemeMode _themeMode = SonarpadThemeMode.system;
  WeatherTemperatureUnit _weatherTemperatureUnit =
      WeatherTemperatureUnit.celsius;
  String _languageCode = 'it';
  String _voice = AppSettingsService.defaultVoiceForLanguage('it');
  List<TtsVoiceLanguage> _edgeLanguages = AppSettingsService.ttsLanguages;
  List<TtsVoiceOption> _edgeVoices = AppSettingsService.ttsVoices;
  List<TtsVoiceLanguage> _googleLanguages = const [];
  List<TtsVoiceOption> _googleVoices = const [];

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
  bool _downloadingGoogleVoice = false;
  double? _googleDownloadProgress;
  bool _clearingPodcastCache = false;
  int _podcastCacheBytes = 0;
  bool _autoBookmark = true;
  bool _includeEpubFootnotesInText = false;
  bool _multipleDocumentBookmarks = false;
  bool _displayVideoInPortrait = false;
  bool _homeGroupingEnabled = false;
  int _seekSliderStep = 60;
  int _documentSliderStepPercent =
      AppSettingsService.defaultDocumentSliderStepPercent;
  int _documentReadingSleepTimerMinutes =
      AppSettingsService.defaultDocumentReadingSleepTimerMinutes;
  final _audio = AudioPlayerService();
  String _savedTvSecretCode = '';
  String _savedAppLanguage = 'it';
  SonarpadThemeMode _savedThemeMode = SonarpadThemeMode.system;
  WeatherTemperatureUnit _savedWeatherTemperatureUnit =
      WeatherTemperatureUnit.celsius;
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
    if (totalSeconds < 60) return '$totalSeconds secondi';
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    String minStr = m == 1 ? '1 minuto' : '$m minuti';
    String secStr = s == 1 ? '1 secondo' : '$s secondi';
    if (s == 0) return minStr;
    return '$minStr e $secStr';
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
    var bestDistance =
        (_documentReadingSleepTimerMinutes - options.first).abs();
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
    _screenFocusNode.dispose();
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
    final displayVideoInPortrait = await _settings.displayVideoInPortrait();
    final homeGrouping = await _settings.isHomeGroupingEnabled();
    final seekSliderStep = await _settings.loadSeekSliderStep();
    final documentSliderStepPercent =
        await _settings.loadDocumentSliderStepPercent();
    final documentReadingSleepTimerMinutes =
        await _settings.loadDocumentReadingSleepTimerMinutes();
    await _podcastCache.cleanAutomatically();
    final podcastCacheBytes = await _podcastCache.cacheSizeBytes();
    final edgeVoices = await AppSettingsService.loadEdgeVoices();
    final edgeLanguages = AppSettingsService.languagesForVoices(edgeVoices);
    final googleCatalog = await GoogleTtsBridge.instance.loadCatalog();
    final googleSpeakers = List<GoogleTtsSpeaker>.from(googleCatalog.speakers)
      ..sort((a, b) {
        final languageCompare = a.language.compareTo(b.language);
        if (languageCompare != 0) return languageCompare;
        if (a.highQuality != b.highQuality) return a.highQuality ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    final googleVoices = googleSpeakers
        .map(
          (speaker) => TtsVoiceOption(
            languageCode: speaker.language,
            voice: speaker.id,
            label: speaker.highQuality
                ? '${speaker.name} - Alta qualita'
                : speaker.name,
            languageLabel: speaker.language,
          ),
        )
        .toList();
    final googleLanguages = AppSettingsService.languagesForVoices(googleVoices);
    final activeVoices = ttsEngine == 'google' ? googleVoices : edgeVoices;
    final activeLanguages =
        ttsEngine == 'google' ? googleLanguages : edgeLanguages;
    final normalizedLanguage = AppSettingsService.normalizedTtsLanguageCodeFor(
      activeLanguages,
      activeVoices,
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
      _googleLanguages = googleLanguages;
      _googleVoices = googleVoices;
      _languageCode = normalizedLanguage;
      _savedLanguageCode = normalizedLanguage;
      _voice = _validVoiceForLanguageForEngine(
        normalizedLanguage,
        voice,
        ttsEngine,
      );
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
      _seekSliderStep = seekSliderStep;
      _savedSeekSliderStep = seekSliderStep;
      _documentSliderStepPercent = documentSliderStepPercent;
      _savedDocumentSliderStepPercent = documentSliderStepPercent;
      _documentReadingSleepTimerMinutes = documentReadingSleepTimerMinutes;
      _savedDocumentReadingSleepTimerMinutes = documentReadingSleepTimerMinutes;
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

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context);
    final rawCode = _tvSecretCodeController.text.trim();
    final codeChanged = rawCode != _savedTvSecretCode;
    final appLanguageChanged = _appLanguage != _savedAppLanguage;
    final themeChanged = _themeMode != _savedThemeMode;
    final weatherTemperatureUnitChanged =
        _weatherTemperatureUnit != _savedWeatherTemperatureUnit;
    final autoBookmarkChanged = _autoBookmark != _savedAutoBookmark;
    final includeEpubFootnotesChanged =
        _includeEpubFootnotesInText != _savedIncludeEpubFootnotesInText;
    final multipleDocumentBookmarksChanged =
        _multipleDocumentBookmarks != _savedMultipleDocumentBookmarks;
    final displayVideoInPortraitChanged =
        _displayVideoInPortrait != _savedDisplayVideoInPortrait;
    final homeGroupingChanged =
        _homeGroupingEnabled != _savedHomeGroupingEnabled;
    final seekSliderStepChanged = _seekSliderStep != _savedSeekSliderStep;
    final documentSliderStepChanged =
        _documentSliderStepPercent != _savedDocumentSliderStepPercent;
    final documentReadingSleepTimerChanged =
        _documentReadingSleepTimerMinutes !=
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
    await _settings
        .setMultipleDocumentBookmarksEnabled(_multipleDocumentBookmarks);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (FocusManager.instance.primaryFocus == null &&
          !_screenFocusNode.hasFocus) {
        _screenFocusNode.requestFocus();
      }
      showStatusMessage(context, savedMessage);
    });
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
      await AppLogger.log(
          'Settings: accessibility stabilization failed: $error');
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
    _screenFocusNode.requestFocus();
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

    if (result == _SettingsLeaveAction.discard) return true;
    if (result == _SettingsLeaveAction.save) {
      await _save();
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
      showStatusMessage(context, l10n.error(e));
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
      } else if (_ttsEngine == 'google') {
        final tts = GoogleTtsBridge.instance;
        final file = await tts.speakToFile(
          text: l10n.settingsVoiceTestText,
          voiceId: _voice,
          speed: previewSpeed,
          pitch: previewPitch,
        );
        if (!mounted) return;
        await _audio.playFile(file);
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
      showStatusMessage(context, l10n.settingsVoiceTestError(e));
    } finally {
      if (mounted) {
        setState(() => _testingVoice = false);
      }
    }
  }

  Future<void> _downloadGoogleVoicePackage({bool showSuccess = true}) async {
    if (_downloadingGoogleVoice) return;
    setState(() {
      _downloadingGoogleVoice = true;
      _googleDownloadProgress = 0;
    });
    try {
      final bridge = GoogleTtsBridge.instance;
      final catalog = await bridge.loadCatalog();
      final package = catalog.packageForVoice(_voice);
      await bridge.downloadPackage(
        package,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _googleDownloadProgress = progress);
        },
      );
      if (!mounted) return;
      if (showSuccess) {
        showStatusMessage(context, 'Pacchetto Google TTS scaricato.');
      }
    } catch (e) {
      if (!mounted) return;
      showStatusMessage(context, 'Errore download Google TTS: $e');
    } finally {
      if (mounted) {
        setState(() {
          _downloadingGoogleVoice = false;
          _googleDownloadProgress = null;
        });
      }
    }
  }

  Future<void> _saveTtsSelection() async {
    if (_ttsEngine == 'google') {
      await _downloadGoogleVoicePackage(showSuccess: false);
    }
    await _settings.saveTtsEngine(_ttsEngine);
    await _settings.saveTtsSettings(
      languageCode: _languageCode,
      voice: _voice,
    );
    await _settings.saveSystemTtsLanguage(_systemTtsLanguage);
    await _settings.saveSystemTtsVoice(_systemTtsVoice);
  }

  String _validVoiceForLanguage(String languageCode, String voice) {
    return _validVoiceForLanguageForEngine(languageCode, voice, _ttsEngine);
  }

  String _validVoiceForLanguageForEngine(
    String languageCode,
    String voice,
    String engine,
  ) {
    final voiceOptions = engine == 'google' ? _googleVoices : _edgeVoices;
    final voices = AppSettingsService.voicesForLanguageFrom(
      voiceOptions,
      languageCode,
    );
    if (voices.any((option) => option.voice == voice)) return voice;
    return AppSettingsService.defaultVoiceForLanguageFrom(
      voiceOptions,
      languageCode,
    );
  }

  List<TtsVoiceLanguage> get _activeOnlineLanguages =>
      _ttsEngine == 'google' ? _googleLanguages : _edgeLanguages;

  List<TtsVoiceOption> get _activeOnlineVoices =>
      _ttsEngine == 'google' ? _googleVoices : _edgeVoices;

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
        showStatusMessage(context, l10n.settingsMailOpenError(e));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final voices = AppSettingsService.voicesForLanguageFrom(
      _activeOnlineVoices,
      _languageCode,
    );
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
            : Stack(
                children: [
                  Focus(
                    focusNode: _screenFocusNode,
                    child: ListView(
                      key: const PageStorageKey<String>('settings-list'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _appLanguage,
                          decoration:
                              InputDecoration(labelText: l10n.appLanguage),
                          items: [
                            DropdownMenuItem(
                                value: 'it', child: Text(l10n.italian)),
                            DropdownMenuItem(
                                value: 'en', child: Text(l10n.english)),
                            DropdownMenuItem(
                                value: 'fr', child: Text(l10n.french)),
                            DropdownMenuItem(
                                value: 'es', child: Text(l10n.spanish)),
                            DropdownMenuItem(
                                value: 'pt', child: Text(l10n.radioLanguagePt)),
                            DropdownMenuItem(
                                value: 'pl', child: Text(l10n.radioLanguagePl)),
                            DropdownMenuItem(
                                value: 'cs', child: Text(l10n.radioLanguageCs)),
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
                          decoration:
                              InputDecoration(labelText: l10n.settingsTheme),
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
                            const DropdownMenuItem(
                                value: 'google', child: Text('Google TTS')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _ttsEngine = value;
                              if (value != 'system') {
                                final languages = _activeOnlineLanguages;
                                if (!languages.any((language) =>
                                    language.code == _languageCode)) {
                                  _languageCode = languages.isNotEmpty
                                      ? languages.first.code
                                      : 'it';
                                }
                                _voice = _validVoiceForLanguage(
                                    _languageCode, _voice);
                              }
                            });
                            if (value == 'google') {
                              unawaited(_downloadGoogleVoicePackage());
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_ttsEngine != 'system') ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _languageCode,
                            decoration: InputDecoration(
                                labelText: l10n.ttsVoiceLanguage),
                            items: _activeOnlineLanguages
                                .map((language) => DropdownMenuItem(
                                      value: language.code,
                                      child: Text(
                                        language.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              final next = value ?? 'it';
                              setState(() {
                                _languageCode = next;
                                _voice = AppSettingsService
                                    .defaultVoiceForLanguageFrom(
                                  _activeOnlineVoices,
                                  next,
                                );
                              });
                              if (_ttsEngine == 'google') {
                                unawaited(_downloadGoogleVoicePackage());
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _voice,
                            decoration: InputDecoration(
                              labelText: _ttsEngine == 'google'
                                  ? 'Modello Google TTS'
                                  : l10n.ttsVoice,
                            ),
                            items: voices
                                .map((voice) => DropdownMenuItem(
                                      value: voice.voice,
                                      child: Text(
                                        '${voice.label} (${voice.voice})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(
                                () => _voice = value ??
                                    AppSettingsService
                                        .defaultVoiceForLanguageFrom(
                                      _activeOnlineVoices,
                                      _languageCode,
                                    ),
                              );
                              if (_ttsEngine == 'google') {
                                unawaited(_downloadGoogleVoicePackage());
                              }
                            },
                          ),
                          if (_ttsEngine == 'google') ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _downloadingGoogleVoice
                                  ? null
                                  : _downloadGoogleVoicePackage,
                              icon: const Icon(Icons.download),
                              label: Text(
                                _downloadingGoogleVoice
                                    ? 'Download Google TTS...'
                                    : 'Scarica pacchetto Google TTS',
                              ),
                            ),
                            if (_googleDownloadProgress != null) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: _googleDownloadProgress,
                              ),
                            ],
                          ],
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
                                  .where(
                                      (v) => v['locale'] == _systemTtsLanguage)
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
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
                          onChanged: (val) =>
                              setState(() => _autoBookmark = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: Text(l10n.settingsIncludeFootnotesInText),
                          subtitle:
                              Text(l10n.settingsIncludeFootnotesInTextHint),
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
                                  value:
                                      _documentSliderStepOptionIndex.toDouble(),
                                  min: 0,
                                  max: (AppSettingsService
                                              .documentSliderStepPercentOptions
                                              .length -
                                          1)
                                      .toDouble(),
                                  divisions: AppSettingsService
                                          .documentSliderStepPercentOptions
                                          .length -
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
                          key: const ValueKey(
                              'settings-display-video-in-portrait'),
                          title: Text(l10n.settingsVideoLandscapeFullscreen),
                          subtitle:
                              Text(l10n.settingsVideoLandscapeFullscreenHint),
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
                          onTap:
                              _clearingPodcastCache ? null : _clearPodcastCache,
                          child: ExcludeSemantics(
                            child: Card(
                              child: InkWell(
                                onTap: _clearingPodcastCache
                                    ? null
                                    : _clearPodcastCache,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        l10n.settingsPodcastCacheTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(l10n.settingsPodcastCacheHint),
                                      const SizedBox(height: 8),
                                      Text(l10n.settingsPodcastCacheSize(
                                          _formatBytes(_podcastCacheBytes))),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          _clearingPodcastCache
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
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
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
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
                                settings: const RouteSettings(
                                    name: '/settings/app-log'),
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
                  if (_ttsEngine == 'google')
                    const Positioned(
                      left: 0,
                      top: 0,
                      child: GoogleTtsRuntimeHost(),
                    ),
                ],
              ),
      ),
    );
  }
}
