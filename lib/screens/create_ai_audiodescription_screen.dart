import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../services/cloud_file_picker_service.dart';
import '../services/ai_audiodescription_service.dart';
import '../services/app_settings_service.dart';
import '../services/audio_description_mix.dart';
import '../services/audio_description_mix_preview_controller.dart';
import '../services/audio_player_service.dart';
import '../services/document_library_service.dart';
import '../services/ios_photo_library_import_service.dart';
import '../services/media_export_destination_service.dart';
import '../tts/edge_tts_bridge.dart';
import '../tts/edge_tts_retry.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class CreateAiAudiodescriptionScreen extends StatefulWidget {
  const CreateAiAudiodescriptionScreen({
    super.key,
    this.initialSourcePath,
    this.includeSourceVideoWithProjectOutput = false,
    this.mixPreviewControllerFactory,
  });

  final String? initialSourcePath;
  final bool includeSourceVideoWithProjectOutput;
  final AudioDescriptionMixPreviewController Function()? mixPreviewControllerFactory;

  @override
  State<CreateAiAudiodescriptionScreen> createState() =>
      _CreateAiAudiodescriptionScreenState();
}

class _CreateAiAudiodescriptionScreenState
    extends State<CreateAiAudiodescriptionScreen> with WidgetsBindingObserver {
  final _service = AiAudioDescriptionService();
  final _settings = AppSettingsService();
  final _flutterTts = FlutterTts();
  final _audio = AudioPlayerService();
  final _iosPhotoImport = const IosPhotoLibraryImportService();
  late final AudioDescriptionMixPreviewController _mixPreview;
  Future<void> _voiceTestWork = Future<void>.value();
  EdgeTtsBridge? _voiceTestBridge;
  int _voiceTestRevision = 0;
  int _mixPreviewRevision = 0;
  bool _choosingVideo = false;

  bool _loading = true;
  bool _running = false;
  bool _generationActive = false;
  bool _generationDispatched = false;
  bool _confirmingCancel = false;
  bool _cancelling = false;
  bool _testingVoice = false;
  bool _systemVoicePreviewActive = false;
  bool _edgeVoicePreviewActive = false;
  bool _refreshingModels = false;
  bool _activatingSonarpad = false;
  bool _loadingSonarpadBalance = false;
  double _progress = 0;
  String _stage = '';
  String? _sourcePath;
  String? _technicalError;

  String _provider = 'gemini';
  String _apiKey = '';
  String _sonarpadCode = '';
  double? _sonarpadBalanceEur;
  String _model = 'gemini-3.5-flash-lite';
  List<String> _models = const ['gemini-3.5-flash-lite'];
  String _language = 'it';
  String _verbosity = 'detailed';
  bool _extendedPauses = false;
  bool _recognizeCharacters = true;
  bool _recognizeScreenText = true;
  bool _keepCharacterCatalog = false;
  String? _characterCatalogName;
  List<String> _characterCatalogs = const [];
  bool _saveProject = false;
  bool _createVideoOutput = false;
  int _bitrateKbps = audioDescriptionDefaultBitrateKbps;
  double _sourceVolume = audioDescriptionDefaultSourceVolume;

  String _ttsEngine = 'edge';
  List<TtsVoiceOption> _edgeVoices = const [];
  List<TtsVoiceLanguage> _edgeLanguages = const [];
  String _edgeLanguage = 'it-IT';
  String _edgeVoice = 'it-IT-IsabellaNeural';
  List<Map<String, String>> _systemVoices = const [];
  String _systemLanguage = 'it-IT';
  String? _systemVoice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mixPreview = widget.mixPreviewControllerFactory?.call() ??
        AudioDescriptionMixPreviewController();
    _mixPreview.addListener(_mixPreviewChanged);
    final initialSourcePath = widget.initialSourcePath?.trim() ?? '';
    if (initialSourcePath.isNotEmpty) {
      _sourcePath = initialSourcePath;
    }
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_generationActive &&
        (state == AppLifecycleState.inactive || state == AppLifecycleState.paused)) {
      unawaited(_stopPreviews());
    }
    if (_generationActive && state == AppLifecycleState.resumed) {
      unawaited(_ensureGenerationWakelock());
    }
  }

  Future<void> _ensureGenerationWakelock() async {
    try {
      await WakelockPlus.enable();
      await AppLogger.log(
        'Audio description UI: wakelock re-enabled after app resume',
      );
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description UI: wakelock resume enable failed error=$error\n$stackTrace',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_voiceTestRevision;
    _voiceTestBridge?.cancel();
    _mixPreview.removeListener(_mixPreviewChanged);
    _mixPreview.dispose();
    _service.dispose();
    _flutterTts.stop();
    unawaited(_audio.dispose());
    super.dispose();
  }

  void _mixPreviewChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _stopVoicePreview() async {
    final stopSystemVoice = _systemVoicePreviewActive;
    final stopEdgeVoice = _edgeVoicePreviewActive;
    _systemVoicePreviewActive = false;
    _edgeVoicePreviewActive = false;
    ++_voiceTestRevision;
    _voiceTestBridge?.cancel();
    _voiceTestBridge = null;
    if (mounted && _testingVoice) setState(() => _testingVoice = false);
    await Future.wait<void>([
      if (stopSystemVoice) _flutterTts.stop().then<void>((_) {}),
      if (stopEdgeVoice) _audio.stop(),
    ]);
    await _voiceTestWork;
  }

  Future<void> _stopPreviews() async {
    await _mixPreview.stop();
    await _stopVoicePreview();
  }

  void _requestMixPreview({required bool immediately}) {
    final sourcePath = _sourcePath;
    if (_running || _choosingVideo || sourcePath == null || sourcePath.isEmpty) return;
    // Keep a snapshot of every audible choice; later adjustments replace this
    // request instead of changing a render while it is running.
    final settings = _currentSettings();
    final text = AppLocalizations.of(context).audioDescriptionMixPreviewPhrase;
    final revision = ++_mixPreviewRevision;
    Future<AudioDescriptionMixPreview> render(AiAudioDescriptionService service) async {
      await _stopVoicePreview();
      if (!mounted || _running || revision != _mixPreviewRevision ||
          !_mixPreview.isActive) {
        throw StateError('AUDIO_DESCRIPTION_CANCELLED');
      }
      return service.previewMix(
        sourcePath: sourcePath,
        settings: settings,
        text: text,
      );
    }
    if (immediately) {
      _mixPreview.playNow(render);
    } else {
      _mixPreview.schedule(render);
    }
  }

  Future<void> _playMixPreview() async {
    if (_running || _choosingVideo) return;
    final source = _sourcePath;
    if (source == null || source.isEmpty || !await File(source).exists()) {
      await _chooseVideo();
      if (!mounted) return;
    }
    _requestMixPreview(immediately: true);
  }

  Future<void> _load() async {
    try {
      final preferences = await AiAudioDescriptionPreferences.load();
      final edgeVoices = await AppSettingsService.loadEdgeVoices();
      final edgeLanguages = AppSettingsService.languagesForVoices(edgeVoices);
      final settingEngine = await _settings.loadTtsEngine();
      final settingEdgeLanguage = await _settings.loadTtsLanguage();
      final settingEdgeVoice = await _settings.loadTtsVoice();
      final settingSystemLanguage = await _settings.loadSystemTtsLanguage();
      final settingSystemVoice = await _settings.loadSystemTtsVoice();
      final systemVoices = await _loadSystemVoices();
      final characterCatalogs = await _service.listCharacterCatalogs();

      final savedEdgeLanguage =
          preferences['edgeLanguage']?.toString().trim() ?? '';
      final edgeLanguage = savedEdgeLanguage.isNotEmpty
          ? savedEdgeLanguage
          : settingEdgeLanguage;
      final savedEdgeVoice = preferences['edgeVoice']?.toString().trim() ?? '';
      final edgeVoice = savedEdgeVoice.isNotEmpty
          ? savedEdgeVoice
          : settingEdgeVoice;
      final normalizedEdgeLanguage = AppSettingsService.normalizedTtsLanguageCodeFor(
        edgeLanguages,
        edgeVoices,
        edgeLanguage,
        edgeVoice,
      );
      final normalizedEdgeVoice = _validEdgeVoice(
        edgeVoices,
        normalizedEdgeLanguage,
        edgeVoice,
      );

      var systemLanguage =
          preferences['systemLanguage']?.toString().trim() ?? '';
      if (systemLanguage.isEmpty) systemLanguage = settingSystemLanguage;
      if (systemVoices.isNotEmpty &&
          !systemVoices.any((item) => item['locale'] == systemLanguage)) {
        systemLanguage = systemVoices.first['locale'] ?? settingSystemLanguage;
      }
      final savedSystemVoice = preferences['systemVoice']?.toString().trim();
      final systemVoice = savedSystemVoice != null && savedSystemVoice.isNotEmpty
          ? savedSystemVoice
          : settingSystemVoice;

      if (!mounted) return;
      setState(() {
        _provider = preferences['provider']?.toString() ?? 'gemini';
        _apiKey = preferences['apiKey']?.toString() ?? '';
        _sonarpadCode = preferences['sonarpadCode']?.toString() ?? '';
        _model = preferences['model']?.toString() ?? 'gemini-3.5-flash-lite';
        _models = <String>{_model, 'gemini-3.5-flash-lite'}.toList();
        _language = preferences['language']?.toString() ?? 'it';
        final savedVerbosity = preferences['verbosity']?.toString() ?? 'detailed';
        _verbosity = switch (savedVerbosity) {
          'concise' => 'short',
          'normal' => 'standard',
          'intensive' => 'detailed',
          'short' || 'standard' || 'detailed' => savedVerbosity,
          _ => 'detailed',
        };
        _extendedPauses = preferences['extended'] == true;
        _recognizeCharacters = preferences['characters'] != false;
        _recognizeScreenText = preferences['screenText'] != false;
        _keepCharacterCatalog = preferences['keepCatalog'] == true;
        _characterCatalogName = preferences['catalogName']?.toString();
        _characterCatalogs = characterCatalogs;
        _saveProject = preferences['project'] == true;
        _createVideoOutput = preferences['createVideo'] == true;
        _bitrateKbps = normalizeAudioDescriptionBitrate(preferences['bitrateKbps']);
        _sourceVolume =
            (normalizeAudioDescriptionSourceVolume(preferences['sourceVolume']) * 20)
                .round() / 20;
        _ttsEngine = preferences['ttsEngine']?.toString().trim().isNotEmpty == true
            ? preferences['ttsEngine']!.toString()
            : settingEngine;
        _edgeVoices = edgeVoices;
        _edgeLanguages = edgeLanguages;
        _edgeLanguage = normalizedEdgeLanguage;
        _edgeVoice = normalizedEdgeVoice;
        _systemVoices = systemVoices;
        _systemLanguage = systemLanguage;
        _systemVoice = _validSystemVoice(systemVoices, systemLanguage, systemVoice)
            ? systemVoice
            : null;
        _loading = false;
      });
      if (_provider == 'sonarpad') {
        unawaited(_refreshSonarpadBalance());
      }
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description UI: initialization failed error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _technicalError = error.toString();
      });
    }
  }

  Future<List<Map<String, String>>> _loadSystemVoices() async {
    try {
      final raw = await _flutterTts.getVoices;
      if (raw is! List) return const [];
      final voices = <Map<String, String>>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final name = item['name']?.toString().trim() ?? '';
        final locale = item['locale']?.toString().trim() ?? '';
        if (name.isEmpty || locale.isEmpty) continue;
        voices.add(<String, String>{'name': name, 'locale': locale});
      }
      voices.sort((a, b) {
        final locale = (a['locale'] ?? '').compareTo(b['locale'] ?? '');
        if (locale != 0) return locale;
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      });
      return voices;
    } catch (error) {
      await AppLogger.log('Audio description UI: system voices failed $error');
      return const [];
    }
  }

  String _validEdgeVoice(
    List<TtsVoiceOption> voices,
    String language,
    String voice,
  ) {
    final options = AppSettingsService.voicesForLanguageFrom(voices, language);
    if (options.any((item) => item.voice == voice)) return voice;
    return AppSettingsService.defaultVoiceForLanguageFrom(voices, language);
  }

  bool _validSystemVoice(
    List<Map<String, String>> voices,
    String language,
    String? voice,
  ) {
    if (voice == null || voice.isEmpty) return false;
    return voices.any(
      (item) => item['locale'] == language && item['name'] == voice,
    );
  }

  String _chooseFromFilesLabel(AppLocalizations l10n) => switch (l10n.localeName) {
    'en' => 'Choose video from Files',
    'es' => 'Elegir vídeo desde Archivos',
    'fr' => 'Choisir une vidéo dans Fichiers',
    'de' => 'Video aus Dateien wählen',
    'pt' || 'pt_BR' => 'Escolher vídeo dos Arquivos',
    'pl' => 'Wybierz wideo z Plików',
    'cs' => 'Vybrat video ze Souborů',
    'uk' => 'Вибрати відео з Файлів',
    'ro' => 'Alege video din Fișiere',
    'zh_CN' => '从文件选择视频',
    _ => 'Scegli video da File',
  };

  String _importFromPhotosLabel(AppLocalizations l10n) => switch (l10n.localeName) {
    'en' => 'Import video from Photos',
    'es' => 'Importar vídeo desde Fotos',
    'fr' => 'Importer une vidéo depuis Photos',
    'de' => 'Video aus Fotos importieren',
    'pt' || 'pt_BR' => 'Importar vídeo de Fotos',
    'pl' => 'Importuj wideo ze Zdjęć',
    'cs' => 'Importovat video z Fotek',
    'uk' => 'Імпортувати відео з Фото',
    'ro' => 'Importă video din Poze',
    'zh_CN' => '从照片导入视频',
    _ => 'Importa video da Foto',
  };

  Future<void> _chooseVideo() async {
    if (_running || _choosingVideo) return;
    _choosingVideo = true;
    try {
      await _stopPreviews();
      if (!mounted || _running) return;
      if (!_iosPhotoImport.isSupported) {
        await _chooseVideoFromFiles();
        return;
      }

      final l10n = AppLocalizations.of(context);
      final source = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.audioDescriptionChooseVideo),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'files'),
              child: Text(_chooseFromFilesLabel(l10n)),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'photos'),
              child: Text(_importFromPhotosLabel(l10n)),
            ),
          ],
        ),
      );
      if (!mounted || source == null) return;
      if (source == 'photos') {
        await _chooseVideoFromPhotos();
      } else {
        await _chooseVideoFromFiles();
      }
    } finally {
      _choosingVideo = false;
    }
  }

  Future<void> _chooseVideoFromFiles() async {
    final result = await CloudFilePicker.pickFiles(context: context, 
      type: FileType.custom,
      allowMultiple: false,
      withData: false,
      allowedExtensions: const [
        'mp4', 'mkv', 'mov', 'm4v', 'avi', 'webm', 'ts', 'mts', 'm2ts',
      ],
    );
    final path = result?.files.single.path;
    _setSelectedSourcePath(path);
  }

  Future<void> _chooseVideoFromPhotos() async {
    try {
      final paths = await _iosPhotoImport.pickVideos(allowMultiple: false);
      if (paths.isEmpty) return;
      _setSelectedSourcePath(paths.first);
      await AppLogger.log(
        'Audio description UI: source imported from iOS Photos file=${p.basename(paths.first)}',
      );
    } on PlatformException catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description UI: Photos picker failed error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() => _technicalError = error.message ?? error.code);
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description UI: Photos import failed error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() => _technicalError = error.toString());
    }
  }

  void _setSelectedSourcePath(String? path) {
    if (path == null || path.trim().isEmpty || !mounted) return;
    setState(() {
      _sourcePath = path;
      _technicalError = null;
    });
  }

  Future<void> _openGeminiApiKeyPage() async {
    final uri = Uri.parse('https://aistudio.google.com/app/apikey');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pasteAiCredential() async {
    if (_running) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;

    if (_provider == 'sonarpad') {
      await AppLogger.log(
        'SONARPAD_AI_DIAG UI paste code clipboardChars=${text.runes.length} '
        'trimmedChars=${text.trim().runes.length} trimChanged=${text != text.trim()} '
        'codeUnits=${text.codeUnits.length}',
      );
      setState(() {
        _sonarpadCode = text;
        _sonarpadBalanceEur = null;
      });
      return;
    }

    setState(() => _apiKey = text);
    await AiAudioDescriptionPreferences.saveGeminiApiKey(text);
  }

  Future<void> _refreshModels() async {
    if (_refreshingModels || _running) return;
    final l10n = AppLocalizations.of(context);
    if (_apiKey.trim().isEmpty) {
      showStatusMessage(context, l10n.audioDescriptionApiKeyRequired);
      return;
    }
    setState(() => _refreshingModels = true);
    try {
      final models = await _service.fetchGeminiModels(_apiKey);
      if (!mounted) return;
      setState(() {
        _models = models.isEmpty ? <String>[_model] : models;
        if (!_models.contains(_model) && _models.isNotEmpty) {
          _model = _models.first;
        }
      });
      showStatusMessage(context, l10n.audioDescriptionModelsUpdated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _technicalError = error.toString());
      showStatusMessage(context, l10n.audioDescriptionModelsError);
    } finally {
      if (mounted) setState(() => _refreshingModels = false);
    }
  }

  Future<void> _refreshSonarpadBalance({String? token}) async {
    if (_loadingSonarpadBalance) {
      await AppLogger.log('SONARPAD_AI_DIAG UI balance refresh skipped alreadyLoading=true');
      return;
    }
    await AppLogger.log(
      'SONARPAD_AI_DIAG UI balance refresh start explicitToken=${token != null && token.trim().isNotEmpty} '
      'codeChars=${_sonarpadCode.runes.length} trimmedCodeChars=${_sonarpadCode.trim().runes.length} '
      'trimChanged=${_sonarpadCode != _sonarpadCode.trim()}',
    );
    if (mounted) {
      setState(() => _loadingSonarpadBalance = true);
    }
    try {
      final balance = await _service.fetchSonarpadBalance(
        token: token,
        code: _sonarpadCode,
      );
      await AppLogger.log('SONARPAD_AI_DIAG UI balance refresh success parsed=true');
      if (!mounted) return;
      setState(() => _sonarpadBalanceEur = balance);
    } catch (error, stackTrace) {
      await AppLogger.log('Sonarpad AI balance unavailable: $error');
      await AppLogger.log(
        'SONARPAD_AI_DIAG UI balance refresh exception type=${error.runtimeType} error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() => _sonarpadBalanceEur = null);
    } finally {
      if (mounted) setState(() => _loadingSonarpadBalance = false);
    }
  }

  String _sonarpadBalanceLabel(AppLocalizations l10n) {
    if (_loadingSonarpadBalance) return l10n.loading;
    final balance = _sonarpadBalanceEur;
    if (balance == null) return l10n.audioDescriptionSonarpadBalanceUnavailable;
    return NumberFormat.currency(
      locale: l10n.localeName,
      symbol: '€',
      decimalDigits: 2,
    ).format(balance);
  }

  Future<void> _activateSonarpadAi() async {
    if (_activatingSonarpad || _running) {
      await AppLogger.log(
        'SONARPAD_AI_DIAG UI activate skipped activating=$_activatingSonarpad running=$_running',
      );
      return;
    }
    final l10n = AppLocalizations.of(context);
    await AppLogger.log(
      'SONARPAD_AI_DIAG UI activate pressed codeChars=${_sonarpadCode.runes.length} '
      'trimmedCodeChars=${_sonarpadCode.trim().runes.length} trimChanged=${_sonarpadCode != _sonarpadCode.trim()}',
    );
    if (_sonarpadCode.trim().isEmpty) {
      await AppLogger.log('SONARPAD_AI_DIAG UI activate aborted codeEmpty=true');
      if (!mounted) return;
      showStatusMessage(context, l10n.audioDescriptionSonarpadCodeRequired);
      return;
    }
    setState(() => _activatingSonarpad = true);
    try {
      final token = await _service.activateSonarpadAi(_sonarpadCode);
      await AppLogger.log(
        'SONARPAD_AI_DIAG UI activate service success tokenChars=${token.length} startsSst=${token.startsWith('sst_')}',
      );
      await AiAudioDescriptionPreferences.saveProvider('sonarpad');
      if (!mounted) return;
      setState(() => _provider = 'sonarpad');
      showStatusMessage(context, l10n.audioDescriptionSonarpadActivated);
      unawaited(_refreshSonarpadBalance(token: token));
    } on SonarpadAiDeviceLimitReachedException catch (error, stackTrace) {
      await AppLogger.log(
        'SONARPAD_AI_DIAG UI activate device-limit error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() => _technicalError = null);
      showStatusMessage(context, l10n.audioDescriptionSonarpadDeviceLimitReached);
    } catch (error, stackTrace) {
      await AppLogger.log(
        'SONARPAD_AI_DIAG UI activate exception type=${error.runtimeType} error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() => _technicalError = error.toString());
      showStatusMessage(context, l10n.audioDescriptionSonarpadActivationError);
    } finally {
      if (mounted) setState(() => _activatingSonarpad = false);
    }
  }

  Future<void> _testVoice() async {
    if (_testingVoice || _running) return;
    final revision = ++_voiceTestRevision;
    final l10n = AppLocalizations.of(context);
    final settings = _currentSettings();
    setState(() => _testingVoice = true);
    await _mixPreview.stop();
    if (!_voiceTestIsCurrent(revision)) return;
    final work = _runVoiceTest(revision, l10n, settings);
    _voiceTestWork = work;
    await work;
  }

  bool _voiceTestIsCurrent(int revision) =>
      mounted && revision == _voiceTestRevision && _testingVoice && !_running;

  Future<void> _runVoiceTest(
    int revision,
    AppLocalizations l10n,
    AiAudioDescriptionSettings settings,
  ) async {
    try {
      final speed = await _settings.loadTtsSpeed();
      final pitch = await _settings.loadTtsPitch();
      if (!_voiceTestIsCurrent(revision)) return;
      if (settings.ttsEngine == 'system') {
        await _flutterTts.setSpeechRate(speed * 0.5);
        if (!_voiceTestIsCurrent(revision)) return;
        await _flutterTts.setPitch(pitch);
        if (!_voiceTestIsCurrent(revision)) return;
        if (settings.systemVoice != null) {
          await _flutterTts.setVoice(<String, String>{
            'name': settings.systemVoice!,
            'locale': settings.systemLanguage,
          });
        } else {
          await _flutterTts.setLanguage(settings.systemLanguage);
        }
        if (!_voiceTestIsCurrent(revision)) return;
        // The file-synthesis pipeline can leave this plugin-wide flag true.
        // On iOS a cancelled speak does not resolve an awaited completion,
        // so the live voice test must keep its original start-only behavior.
        await _flutterTts.awaitSpeakCompletion(false);
        if (!_voiceTestIsCurrent(revision)) return;
        _systemVoicePreviewActive = true;
        await _flutterTts.speak(l10n.settingsVoiceTestText);
      } else {
        final bridge = EdgeTtsBridge();
        _voiceTestBridge = bridge;
        final file = await EdgeTtsRetry.run(
          generate: () => bridge.speakToFile(
            text: l10n.settingsVoiceTestText,
            voice: settings.edgeVoice,
            speed: speed,
            pitch: pitch,
          ),
          isActive: () => _voiceTestIsCurrent(revision),
        );
        if (file == null || !_voiceTestIsCurrent(revision)) return;
        await _flutterTts.stop();
        if (!_voiceTestIsCurrent(revision)) return;
        _edgeVoicePreviewActive = true;
        await _audio.playVoicePreview(file);
        if (mounted && _voiceTestIsCurrent(revision)) {
          showStatusMessage(context, l10n.audioDescriptionEdgeVoiceReady);
        }
      }
    } catch (error) {
      if (!mounted || !_voiceTestIsCurrent(revision)) return;
      setState(() => _technicalError = error.toString());
      showStatusMessage(context, l10n.settingsVoiceTestError(l10n.technicalErrorGeneric));
    } finally {
      if (revision == _voiceTestRevision) {
        _voiceTestBridge = null;
        if (mounted) setState(() => _testingVoice = false);
      }
    }
  }

  AiAudioDescriptionSettings _currentSettings() => AiAudioDescriptionSettings(
        provider: _provider,
        geminiApiKey: _apiKey,
        sonarpadCode: _sonarpadCode,
        geminiModel: _model,
        languageCode: _language,
        verbosity: _verbosity,
        allowExtendedPauses: _extendedPauses && !_createVideoOutput,
        recognizeCharacters: _recognizeCharacters,
        recognizeScreenText: _recognizeScreenText,
        keepCharacterCatalog: _recognizeCharacters && _keepCharacterCatalog,
        characterCatalogName: _characterCatalogName,
        saveProject: _saveProject,
        createVideoOutput: _createVideoOutput,
        bitrateKbps: _bitrateKbps,
        sourceVolume: _sourceVolume,
        ttsEngine: _ttsEngine,
        edgeLanguage: _edgeLanguage,
        edgeVoice: _edgeVoice,
        systemLanguage: _systemLanguage,
        systemVoice: _systemVoice,
      );

  Future<void> _persistCharacterCatalogPreference() async {
    await AiAudioDescriptionPreferences.saveCharacterCatalogPreference(
      recognizeCharacters: _recognizeCharacters,
      keepCatalog: _keepCharacterCatalog,
      catalogName: _characterCatalogName,
    );
  }

  Future<String?> _askCharacterCatalogName() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.audioDescriptionCharacterCatalogNameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.audioDescriptionCharacterCatalogNamePrompt,
          ),
          onSubmitted: (text) {
            final trimmed = text.trim();
            if (trimmed.isNotEmpty) Navigator.pop(dialogContext, trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) {
                showStatusMessage(
                  dialogContext,
                  l10n.audioDescriptionCharacterCatalogNameError,
                );
                return;
              }
              Navigator.pop(dialogContext, trimmed);
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }


  Future<void> _loadCharacterCatalog() async {
    final l10n = AppLocalizations.of(context);
    try {
      final available = await _service.listCharacterCatalogs();
      if (!mounted) return;
      final selection = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.audioDescriptionLoadCharacterCatalog),
          content: available.isEmpty
              ? Text(l10n.audioDescriptionCharacterCatalogNew)
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final name in available)
                        ListTile(
                          title: Text(name),
                          onTap: () => Navigator.pop(dialogContext, name),
                        ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, '__import_catalog__'),
              child: Text(l10n.audioDescriptionImportCharacterCatalog),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
      if (!mounted || selection == null) return;
      var name = selection;
      if (selection == '__import_catalog__') {
        final result = await CloudFilePicker.pickFiles(context: context, 
          type: FileType.custom,
          allowedExtensions: const ['json'],
        );
        final path = result?.files.single.path;
        if (path == null || path.trim().isEmpty) return;
        name = await _service.importCharacterCatalog(path);
      }
      final refreshed = await _service.listCharacterCatalogs();
      if (!mounted) return;
      setState(() {
        _recognizeCharacters = true;
        _keepCharacterCatalog = true;
        _characterCatalogName = name;
        _characterCatalogs = refreshed;
      });
      await _persistCharacterCatalogPreference();
      if (!mounted) return;
      showStatusMessage(
        context,
        l10n.audioDescriptionCharacterCatalogLoaded,
      );
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description UI: character catalog load failed '
        'error=$error\n$stackTrace',
      );
      if (!mounted) return;
      showStatusMessage(
        context,
        l10n.fileOpenError(l10n.technicalErrorGeneric),
      );
    }
  }

  Future<void> _continueDescription() async {
    if (_running) return;
    try {
      if (_sourcePath == null) await _chooseVideo();
      if (!mounted || _sourcePath == null) return;
      final resumeCatalog = await _service.resumeCharacterCatalogName(_sourcePath!);
      if (resumeCatalog != null && resumeCatalog.isNotEmpty) {
        final available = await _service.listCharacterCatalogs();
        if (!mounted) return;
        setState(() {
          _recognizeCharacters = true;
          _keepCharacterCatalog = true;
          _characterCatalogName = resumeCatalog;
          _characterCatalogs = available;
        });
        await _persistCharacterCatalogPreference();
      }
      await _create(resumeOnly: true);
    } catch (error, stackTrace) {
      await AppLogger.log('Audio description UI: resume failed $error\n$stackTrace');
      if (mounted) showStatusMessage(context, AppLocalizations.of(context).technicalErrorGeneric);
    }
  }

  Future<void> _create({bool resumeOnly = false}) async {
    if (_running) return;
    final l10n = AppLocalizations.of(context);
    final sourcePath = _sourcePath;
    if (sourcePath == null || sourcePath.isEmpty) {
      showStatusMessage(context, l10n.audioDescriptionChooseVideoFirst);
      return;
    }
    if (resumeOnly && !await _service.hasResumeCheckpoint(sourcePath)) {
      if (mounted) showStatusMessage(context, l10n.audioDescriptionNoCheckpoint);
      return;
    }
    if (!mounted) return;
    if (_provider == 'sonarpad') {
      final savedToken = await AiAudioDescriptionPreferences.loadSonarpadToken();
      final savedCode = await AiAudioDescriptionPreferences.loadSonarpadCode();
      await AppLogger.log(
        'SONARPAD_AI_DIAG UI create preflight resumeOnly=$resumeOnly source=${p.basename(sourcePath)} '
        'codeChars=${_sonarpadCode.runes.length} trimmedCodeChars=${_sonarpadCode.trim().runes.length} '
        'trimChanged=${_sonarpadCode != _sonarpadCode.trim()} savedCodePresent=${savedCode != null} '
        'savedCodeChars=${savedCode?.runes.length ?? 0} savedTokenPresent=${savedToken != null} '
        'savedTokenChars=${savedToken?.length ?? 0}',
      );
    }
    if (!mounted) return;
    if (_provider == 'gemini' && _apiKey.trim().isEmpty) {
      showStatusMessage(context, l10n.audioDescriptionApiKeyRequired);
      return;
    }
    if (_provider == 'sonarpad' &&
        _sonarpadCode.trim().isEmpty &&
        await AiAudioDescriptionPreferences.loadSonarpadToken() == null) {
      if (!mounted) return;
      showStatusMessage(context, l10n.audioDescriptionSonarpadCodeRequired);
      return;
    }
    if (_recognizeCharacters &&
        _keepCharacterCatalog &&
        (_characterCatalogName == null || _characterCatalogName!.trim().isEmpty)) {
      final name = await _askCharacterCatalogName();
      if (!mounted || name == null) return;
      setState(() {
        _characterCatalogName = name;
        if (!_characterCatalogs.contains(name)) {
          _characterCatalogs = <String>[..._characterCatalogs, name]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
      });
      await _persistCharacterCatalogPreference();
    }
    setState(() {
      _running = true;
      _generationActive = true;
      _generationDispatched = false;
      _cancelling = false;
      _progress = 0;
      _stage = l10n.audioDescriptionStagePreparing;
      _technicalError = null;
    });
    try {
      await _stopPreviews();
      if (_provider == 'sonarpad') {
        await AppLogger.log(
          'SONARPAD_AI_DIAG UI create dispatch provider=sonarpad language=$_language verbosity=$_verbosity '
          'extended=$_extendedPauses characters=$_recognizeCharacters screenText=$_recognizeScreenText '
          'keepCatalog=$_keepCharacterCatalog saveProject=$_saveProject createVideo=$_createVideoOutput '
          'ttsEngine=$_ttsEngine',
        );
      }
      if (!mounted) return;
      if (_cancelling) throw StateError('AUDIO_DESCRIPTION_CANCELLED');
      _generationDispatched = true;
      final result = await _service.create(
        sourcePath: sourcePath,
        settings: _currentSettings(),
        onProgress: (progress) {
          if (!mounted || _cancelling) return;
          setState(() {
            if (progress.value > _progress) {
              _progress = progress.value;
            }
            _stage = _stageLabel(l10n, progress.stage, progress.detail);
          });
        },
        onHighDemand: _askHighDemandFallback,
        onQuota: _provider == 'gemini' ? _askQuotaFallback : null,
        onBriefRetry: _askBriefRetryFallback,
        onOverlapConsent: _askOverlapFallback,
        onResumeCheckpoint: _askResumeCheckpoint,
        requireCheckpoint: resumeOnly,
      );
      _generationActive = false;
      if (!mounted) return;
      await _showDoneDialog(result);
    } catch (error, stackTrace) {
      _generationActive = false;
      await AppLogger.log('Audio description UI: generation error=$error\n$stackTrace');
      if (!mounted) return;
      final cancelled = error.toString().contains('AUDIO_DESCRIPTION_CANCELLED');
      final noCheckpoint = error is AudioDescriptionResumeUnavailableException;
      final deviceLimit = error is SonarpadAiDeviceLimitReachedException;
      final insufficientCredit = error is SonarpadAiInsufficientCreditException;
      setState(() {
        _technicalError = cancelled || noCheckpoint || deviceLimit || insufficientCredit
            ? null
            : error.toString();
        _stage = cancelled
            ? l10n.audioDescriptionCancelled
            : noCheckpoint
                ? l10n.audioDescriptionNoCheckpoint
                : deviceLimit
                    ? l10n.audioDescriptionSonarpadDeviceLimitReached
                    : insufficientCredit
                        ? l10n.audioDescriptionSonarpadInsufficientCredit
                        : l10n.audioDescriptionGenerationFailed;
      });
      showStatusMessage(
        context,
        cancelled
            ? l10n.audioDescriptionCancelled
            : noCheckpoint
                ? l10n.audioDescriptionNoCheckpoint
                : deviceLimit
                    ? l10n.audioDescriptionSonarpadDeviceLimitReached
                    : insufficientCredit
                        ? l10n.audioDescriptionSonarpadInsufficientCredit
                        : l10n.audioDescriptionGenerationFailed,
      );
    } finally {
      _generationActive = false;
      _generationDispatched = false;
      if (mounted) {
        setState(() {
          _running = false;
          _cancelling = false;
          _progress = 0;
        });
        if (_provider == 'sonarpad') {
          unawaited(_refreshSonarpadBalance());
        }
      }
    }
  }

  Future<AiAudioDescriptionWaitDecision> _askHighDemandFallback() async {
    if (!mounted) return AiAudioDescriptionWaitDecision.stop;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<AiAudioDescriptionWaitDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.audioDescriptionHighDemandTitle),
        content: Text(l10n.audioDescriptionHighDemandMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              AiAudioDescriptionWaitDecision.stop,
            ),
            child: Text(l10n.audioDescriptionStopGeneration),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              AiAudioDescriptionWaitDecision.continueWaiting,
            ),
            child: Text(l10n.audioDescriptionContinueWaiting),
          ),
        ],
      ),
    );
    return result ?? AiAudioDescriptionWaitDecision.stop;
  }

  Future<AiAudioDescriptionQuotaDecision> _askQuotaFallback(
    String currentModel,
    Set<String> exhaustedModels,
  ) async {
    if (!mounted) {
      return const AiAudioDescriptionQuotaDecision(
        AiAudioDescriptionQuotaAction.stop,
      );
    }
    final l10n = AppLocalizations.of(context);
    final action = await showDialog<AiAudioDescriptionQuotaAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.audioDescriptionQuotaTitle),
        content: Text(l10n.audioDescriptionQuotaMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              AiAudioDescriptionQuotaAction.stop,
            ),
            child: Text(l10n.audioDescriptionStopGeneration),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              AiAudioDescriptionQuotaAction.continueWaiting,
            ),
            child: Text(l10n.audioDescriptionContinueWaiting),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              AiAudioDescriptionQuotaAction.switchModel,
            ),
            child: Text(l10n.audioDescriptionSwitchModel),
          ),
        ],
      ),
    );
    if (action == null || action == AiAudioDescriptionQuotaAction.stop) {
      return const AiAudioDescriptionQuotaDecision(
        AiAudioDescriptionQuotaAction.stop,
      );
    }
    if (action == AiAudioDescriptionQuotaAction.continueWaiting) {
      return const AiAudioDescriptionQuotaDecision(
        AiAudioDescriptionQuotaAction.continueWaiting,
      );
    }

    var models = _models;
    try {
      final refreshed = await _service.fetchGeminiModels(_apiKey);
      if (refreshed.isNotEmpty) models = refreshed;
    } catch (error) {
      await AppLogger.log(
        'Audio description UI: model refresh during quota fallback failed $error',
      );
    }
    final alternatives = models
        .where((model) => model != currentModel && !exhaustedModels.contains(model))
        .toList();
    if (!mounted || alternatives.isEmpty) {
      if (mounted) showStatusMessage(context, l10n.audioDescriptionModelsError);
      return const AiAudioDescriptionQuotaDecision(
        AiAudioDescriptionQuotaAction.continueWaiting,
      );
    }
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.audioDescriptionSwitchModel),
        children: alternatives
            .map(
              (model) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, model),
                child: Text(model),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || selected.isEmpty) {
      return const AiAudioDescriptionQuotaDecision(
        AiAudioDescriptionQuotaAction.stop,
      );
    }
    if (mounted) {
      setState(() {
        _model = selected;
        _models = <String>{..._models, selected}.toList()..sort();
      });
    }
    return AiAudioDescriptionQuotaDecision(
      AiAudioDescriptionQuotaAction.switchModel,
      model: selected,
    );
  }

  Future<bool> _askBriefRetryFallback() async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.audioDescriptionBriefRetryTitle),
        content: Text(l10n.audioDescriptionBriefRetryMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.audioDescriptionStopGeneration),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.audioDescriptionRetryBrief),
          ),
        ],
      ),
    );
    await AppLogger.log(
      'Audio description UI: isolated Brief retry accepted=${result == true}',
    );
    return result == true;
  }

  Future<bool> _askOverlapFallback() async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.audioDescriptionOverlapTitle),
        content: Text(l10n.audioDescriptionOverlapMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.audioDescriptionStopGeneration),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.audioDescriptionAllowOverlap),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _askResumeCheckpoint(String checkpointPath) async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.audioDescriptionResumeTitle),
        content: Text(l10n.audioDescriptionResumeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.audioDescriptionRestart),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.audioDescriptionResume),
          ),
        ],
      ),
    );
    await AppLogger.log(
      'Audio description UI: checkpoint choice '
      'path="$checkpointPath" resume=${result == true}',
    );
    return result == true;
  }

  Future<void> _cancel() async {
    if (!_generationActive || _confirmingCancel || _cancelling) return;
    _confirmingCancel = true;
    final l10n = AppLocalizations.of(context);
    try {
      final confirmed = await showAudioDescriptionCancelConfirmation(context);
      if (!mounted || confirmed != true || !_generationActive) return;
      setState(() {
        _cancelling = true;
        _stage = l10n.audioDescriptionCancelling;
      });
      if (_generationDispatched) {
        _service.cancel();
      } else {
        unawaited(_mixPreview.stop());
      }
      unawaited(AppLogger.log('Audio description UI: cancellation confirmed'));
    } finally {
      _confirmingCancel = false;
    }
  }

  String _stageLabel(AppLocalizations l10n, String stage, String? detail) {
    final label = switch (stage) {
      'preparing' => l10n.audioDescriptionStagePreparing,
      'pyannote' => l10n.audioDescriptionStageDialogue,
      'preparing_chunk' => l10n.audioDescriptionStageVideo,
      'gemini' => l10n.audioDescriptionStageGemini,
      'brief_retry' => l10n.audioDescriptionStageBriefRetry,
      'tts' => l10n.audioDescriptionStageTts,
      'mixing' => l10n.audioDescriptionStageMixing,
      'completed' => l10n.audioDescriptionCompleted,
      _ => l10n.loading,
    };
    return detail == null || detail.isEmpty ? label : '$label $detail';
  }

  Future<List<String>> _completedOutputPaths(
    AiAudioDescriptionResult result,
  ) async {
    final paths = <String>[...result.outputPaths];
    final sourcePath = _sourcePath?.trim() ?? '';
    if (widget.includeSourceVideoWithProjectOutput &&
        result.projectPath != null &&
        sourcePath.isNotEmpty &&
        await File(sourcePath).exists() &&
        !paths.contains(sourcePath)) {
      paths.add(sourcePath);
    }
    return paths;
  }

  Future<bool> _alreadyInSonarpadDocuments(String filePath) async {
    final directory = await DocumentLibraryService().documentsFolder();
    final source = p.normalize(p.absolute(filePath));
    final documents = p.normalize(p.absolute(directory.path));
    return source == documents || p.isWithin(documents, source);
  }

  Future<void> _showDoneDialog(AiAudioDescriptionResult result) async {
    final l10n = AppLocalizations.of(context);
    final destinationService = MediaExportDestinationService();
    while (true) {
      if (!mounted) return;
      final action = await showDialog<_DoneAction>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Text(l10n.mediaProcessingCompleted),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, _DoneAction.share),
                child: Text(l10n.share),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _DoneAction.saveDocuments),
                child: Text(l10n.saveInSonarpadDocuments),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (action == null) continue;
      try {
        final outputPaths = await _completedOutputPaths(result);
        final sourcePath = _sourcePath?.trim() ?? '';
        if (action == _DoneAction.share) {
          await SharePlus.instance.share(
            ShareParams(
              files: outputPaths.map((path) => XFile(path)).toList(),
              text: p.basename(result.mp3Path),
            ),
          );
        } else {
          for (final path in outputPaths) {
            if (sourcePath.isNotEmpty &&
                path == sourcePath &&
                await _alreadyInSonarpadDocuments(path)) {
              final moved = await destinationService
                  .moveExistingDocumentToAudiodescriptions(path);
              if (moved) continue;
            }
            await destinationService.saveInSonarpadAudiodescriptions(
              path,
              originalName: p.basename(path),
            );
          }
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              content: Text(l10n.exportSavedInSonarpad),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.ok),
                ),
              ],
            ),
          );
        }
        await AiAudioDescriptionService.cleanupResult(result);
        if (!mounted) return;
        setState(() => _stage = l10n.audioDescriptionCompleted);
        if (result.characterCatalogWarning != null) {
          showStatusMessage(
            context,
            '${l10n.audioDescriptionCharacterCatalogSaveWarning} '
            '${result.characterCatalogWarning}',
          );
        } else if (_recognizeCharacters &&
            _keepCharacterCatalog &&
            _characterCatalogName != null) {
          showStatusMessage(
            context,
            l10n.audioDescriptionCharacterCatalogSaved,
          );
        }
        return;
      } catch (error) {
        await AppLogger.log('Audio description UI: final destination failed $error');
        if (mounted) showStatusMessage(context, l10n.technicalErrorGeneric);
      }
    }
  }

  List<AccessibleOption> _languageOptions(AppLocalizations l10n) => [
        AccessibleOption(value: 'it', label: l10n.italian),
        AccessibleOption(value: 'en', label: l10n.english),
        AccessibleOption(value: 'es', label: l10n.spanish),
        AccessibleOption(value: 'fr', label: l10n.french),
        AccessibleOption(
          value: 'pt',
          label: l10n.audioDescriptionLanguageCountry(
            l10n.radioLanguagePt,
            l10n.radioCountryOptionPt,
          ),
        ),
        AccessibleOption(
          value: 'pt_BR',
          label: l10n.audioDescriptionLanguageCountry(
            l10n.radioLanguagePt,
            l10n.radioCountryOptionBr,
          ),
        ),
        AccessibleOption(value: 'pl', label: l10n.radioLanguagePl),
        AccessibleOption(value: 'cs', label: l10n.radioLanguageCs),
        AccessibleOption(value: 'de', label: l10n.german),
        AccessibleOption(
          value: 'zh_CN',
          label: l10n.simplifiedChineseLanguageName,
        ),
        AccessibleOption(value: 'uk', label: l10n.radioLanguageUk),
        AccessibleOption(value: 'ro', label: l10n.languageLabel('ro')),
      ];

  String _languageLabel(AppLocalizations l10n, String code) {
    for (final option in _languageOptions(l10n)) {
      if (option.value == code) return option.label;
    }
    return code;
  }

  String _edgeLanguageLabel(String code) {
    final language = _edgeLanguages.where((item) => item.code == code);
    return language.isEmpty ? code : language.first.label;
  }

  String _edgeVoiceLabel(String voice) {
    final item = _edgeVoices.where((entry) => entry.voice == voice);
    return item.isEmpty ? voice : item.first.label;
  }

  List<AccessibleOption> _systemLanguageOptions() {
    final values = _systemVoices.map((item) => item['locale'] ?? '').where((e) => e.isNotEmpty).toSet().toList()
      ..sort();
    return values.map((value) => AccessibleOption(value: value, label: value)).toList();
  }

  List<AccessibleOption> _systemVoiceOptions(AppLocalizations l10n) {
    final values = _systemVoices
        .where((item) => item['locale'] == _systemLanguage)
        .map((item) => item['name'] ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    return <AccessibleOption>[
      AccessibleOption(value: '', label: l10n.settingsDefaultVoice),
      ...values.map((value) => AccessibleOption(value: value, label: value)),
    ];
  }

  Widget _buildRunningBody(AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: LinearProgressIndicator(
            value: _progress.clamp(0.0, 1.0).toDouble(),
            semanticsLabel: _stage,
            semanticsValue: '${(_progress * 100).round()}%',
          ),
        ),
        Expanded(
          child: UniversalAccessibleList(
            key: const ValueKey('audio_description_running'),
            initialFocusId: 'progress',
            sections: [
              AccessibleListSection(
                rows: [
                  AccessibleListRow(
                    id: 'progress',
                    title: _stage,
                    value: '${(_progress * 100).round()}%',
                    kind: 'text',
                    accessibilityButtonTrait: false,
                  ),
                  AccessibleListRow(
                    id: 'cancel',
                    title: l10n.cancel,
                    enabled: !_cancelling,
                  ),
                ],
              ),
            ],
            onEvent: (event) async {
              if (event.type == 'activate' && event.id == 'cancel') {
                await _cancel();
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bitrateIndex = audioDescriptionMp3Bitrates.indexOf(_bitrateKbps);
    final bitrateLabels = [
      for (final bitrate in audioDescriptionMp3Bitrates)
        '$bitrate kbps${bitrate == 192 ? ' (${l10n.audioDescriptionAudioNormal})' : ''}',
    ];
    final volumeIndex = (_sourceVolume * 20).round();
    final volumeFormat = NumberFormat('0.0#', l10n.localeName);
    final volumeLabels = [
      for (var index = 0; index <= 40; index++)
        '${volumeFormat.format(index / 20)}${index == 20 ? ' (${l10n.audioDescriptionAudioNormal})' : ''}',
    ];
    return Scaffold(
      appBar: SonarpadAppBar(
        automaticallyImplyLeading: !_running,
        title: Text(l10n.audioDescriptionCreateAiTitle),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading),
            )
          : _running
              ? _buildRunningBody(l10n)
              : Column(
              children: [
                Expanded(
                  child: UniversalAccessibleList(
                    key: const ValueKey('audio_description_settings'),
                    initialFocusId: 'choose_video',
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'choose_video',
                      title: l10n.audioDescriptionChooseVideo,
                      value: _sourcePath == null ? null : p.basename(_sourcePath!),
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'provider',
                      title: l10n.audioDescriptionAiService,
                      kind: 'picker',
                      value: _provider,
                      valueLabel: _provider == 'sonarpad'
                          ? l10n.audioDescriptionUseSonarpadAi
                          : l10n.audioDescriptionUseGeminiKey,
                      enabled: !_running,
                      options: [
                        AccessibleOption(
                          value: 'gemini',
                          label: l10n.audioDescriptionUseGeminiKey,
                        ),
                        AccessibleOption(
                          value: 'sonarpad',
                          label: l10n.audioDescriptionUseSonarpadAi,
                        ),
                      ],
                    ),
                    if (_provider == 'gemini') ...[
                      AccessibleListRow(
                        id: 'api_key',
                        title: l10n.audioDescriptionGeminiApiKey,
                        kind: 'textField',
                        value: _apiKey,
                        secure: true,
                        enabled: !_running,
                      ),
                      AccessibleListRow(
                        id: 'paste_ai_credential',
                        title: l10n.settingsPasteCode,
                        enabled: !_running,
                      ),
                      AccessibleListRow(
                        id: 'get_api_key',
                        title: l10n.audioDescriptionGetGeminiKey,
                        enabled: !_running,
                      ),
                      AccessibleListRow(
                        id: 'model',
                        title: l10n.audioDescriptionGeminiModel,
                        kind: 'picker',
                        value: _model,
                        valueLabel: _model,
                        enabled: !_running,
                        options: _models
                            .map((value) => AccessibleOption(value: value, label: value))
                            .toList(),
                      ),
                      AccessibleListRow(
                        id: 'refresh_models',
                        title: _refreshingModels
                            ? l10n.audioDescriptionRefreshingModels
                            : l10n.audioDescriptionRefreshModels,
                        enabled: !_running && !_refreshingModels,
                      ),
                    ] else ...[
                      AccessibleListRow(
                        id: 'sonarpad_code',
                        title: l10n.audioDescriptionSonarpadCode,
                        kind: 'textField',
                        value: _sonarpadCode,
                        secure: true,
                        enabled: !_running,
                      ),
                      AccessibleListRow(
                        id: 'paste_ai_credential',
                        title: l10n.settingsPasteCode,
                        enabled: !_running,
                      ),
                      AccessibleListRow(
                        id: 'activate_sonarpad',
                        title: _activatingSonarpad
                            ? l10n.audioDescriptionActivatingSonarpad
                            : l10n.audioDescriptionActivateSonarpad,
                        enabled: !_running && !_activatingSonarpad,
                      ),
                      AccessibleListRow(
                        id: 'sonarpad_balance',
                        title: l10n.audioDescriptionSonarpadBalance,
                        value: _sonarpadBalanceLabel(l10n),
                        kind: 'text',
                        accessibilityButtonTrait: false,
                      ),
                      AccessibleListRow(
                        id: 'sonarpad_model_info',
                        title: l10n.audioDescriptionGeminiModel,
                        value: l10n.audioDescriptionServerManagedModel,
                        kind: 'text',
                        accessibilityButtonTrait: false,
                      ),
                    ],
                    AccessibleListRow(
                      id: 'language',
                      title: l10n.audioDescriptionLanguage,
                      kind: 'picker',
                      value: _language,
                      valueLabel: _languageLabel(l10n, _language),
                      enabled: !_running,
                      options: _languageOptions(l10n),
                    ),
                    AccessibleListRow(
                      id: 'verbosity',
                      title: l10n.audioDescriptionDetailLevel,
                      kind: 'picker',
                      value: _verbosity,
                      valueLabel: switch (_verbosity) {
                        'short' => l10n.audioDescriptionDetailConcise,
                        'standard' => l10n.audioDescriptionDetailNormal,
                        _ => l10n.audioDescriptionDetailDetailed,
                      },
                      enabled: !_running,
                      options: [
                        AccessibleOption(
                          value: 'short',
                          label: l10n.audioDescriptionDetailConcise,
                        ),
                        AccessibleOption(
                          value: 'standard',
                          label: l10n.audioDescriptionDetailNormal,
                        ),
                        AccessibleOption(
                          value: 'detailed',
                          label: l10n.audioDescriptionDetailDetailed,
                        ),
                      ],
                    ),
                    AccessibleListRow(
                      id: 'extended',
                      title: l10n.audioDescriptionExtendedPauses,
                      kind: 'toggle',
                      toggleValue: _extendedPauses,
                      enabled: !_running && !_createVideoOutput,
                    ),
                    AccessibleListRow(
                      id: 'create_video_output',
                      title: l10n.audioDescriptionCreateVideoOutput,
                      kind: 'toggle',
                      toggleValue: _createVideoOutput,
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'mp3_bitrate',
                      title: l10n.audioDescriptionMp3Bitrate,
                      kind: 'slider',
                      value: bitrateLabels[bitrateIndex],
                      valueLabel: bitrateLabels[bitrateIndex],
                      sliderMin: 0,
                      sliderMax: (audioDescriptionMp3Bitrates.length - 1).toDouble(),
                      sliderStep: 1,
                      sliderValue: bitrateIndex.toDouble(),
                      sliderIncreasedValueLabel: bitrateLabels[
                        (bitrateIndex + 1).clamp(0, bitrateLabels.length - 1)
                      ],
                      sliderDecreasedValueLabel: bitrateLabels[
                        (bitrateIndex - 1).clamp(0, bitrateLabels.length - 1)
                      ],
                      options: [
                        for (var index = 0; index < bitrateLabels.length; index++)
                          AccessibleOption(value: index, label: bitrateLabels[index]),
                      ],
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'source_volume',
                      title: l10n.audioDescriptionSourceVolume,
                      hint: l10n.audioDescriptionSourceVolumeHint,
                      kind: 'slider',
                      value: volumeLabels[volumeIndex],
                      valueLabel: volumeLabels[volumeIndex],
                      sliderMin: 0,
                      sliderMax: 40,
                      sliderStep: 1,
                      sliderValue: volumeIndex.toDouble(),
                      sliderIncreasedValueLabel: volumeLabels[(volumeIndex + 1).clamp(0, 40)],
                      sliderDecreasedValueLabel: volumeLabels[(volumeIndex - 1).clamp(0, 40)],
                      options: [
                        for (var index = 0; index < volumeLabels.length; index++)
                          AccessibleOption(value: index, label: volumeLabels[index]),
                      ],
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'mix_preview',
                      title: l10n.audioDescriptionMixPreview,
                      value: _mixPreview.isPreparing
                          ? l10n.audioDescriptionMixPreviewPreparing
                          : _mixPreview.error != null
                              ? l10n.technicalErrorGeneric
                              : null,
                      hint: l10n.audioDescriptionMixPreviewHint,
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'mix_preview_stop',
                      title: l10n.audioDescriptionMixPreviewStop,
                      enabled: !_running && _mixPreview.isActive,
                    ),
                    AccessibleListRow(
                      id: 'characters',
                      title: l10n.audioDescriptionRecognizeCharacters,
                      kind: 'toggle',
                      toggleValue: _recognizeCharacters,
                      enabled: !_running,
                    ),
                    if (_recognizeCharacters)
                      AccessibleListRow(
                        id: 'load_character_catalog',
                        title: l10n.audioDescriptionLoadCharacterCatalog,
                        enabled: !_running,
                      ),
                    AccessibleListRow(
                      id: 'screen_text',
                      title: l10n.audioDescriptionRecognizeScreenText,
                      kind: 'toggle',
                      toggleValue: _recognizeScreenText,
                      enabled: !_running,
                    ),
                    if (_recognizeCharacters)
                      AccessibleListRow(
                        id: 'keep_character_catalog',
                        title: l10n.audioDescriptionKeepCharacterCatalog,
                        kind: 'toggle',
                        toggleValue: _keepCharacterCatalog,
                        enabled: !_running,
                      ),
                    if (_recognizeCharacters && _keepCharacterCatalog)
                      AccessibleListRow(
                        id: 'character_catalog',
                        title: l10n.audioDescriptionCharacterCatalogChoose,
                        kind: 'picker',
                        value: _characterCatalogName ?? '',
                        valueLabel: _characterCatalogName ??
                            l10n.audioDescriptionCharacterCatalogNew,
                        enabled: !_running,
                        options: <AccessibleOption>[
                          AccessibleOption(
                            value: '',
                            label: l10n.audioDescriptionCharacterCatalogNew,
                          ),
                          ..._characterCatalogs.map(
                            (name) => AccessibleOption(
                              value: name,
                              label: name,
                            ),
                          ),
                        ],
                      ),
                    AccessibleListRow(
                      id: 'save_project',
                      title: l10n.audioDescriptionSaveProject,
                      kind: 'toggle',
                      toggleValue: _saveProject,
                      enabled: !_running,
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
                      valueLabel: _ttsEngine == 'system'
                          ? l10n.settingsSystemVoices
                          : l10n.settingsEdgeTtsQuality,
                      enabled: !_running,
                      options: [
                        AccessibleOption(
                          value: 'edge',
                          label: l10n.settingsEdgeTtsQuality,
                        ),
                        AccessibleOption(
                          value: 'system',
                          label: l10n.settingsSystemVoices,
                        ),
                      ],
                    ),
                    if (_ttsEngine == 'edge') ...[
                      AccessibleListRow(
                        id: 'edge_language',
                        title: l10n.ttsVoiceLanguage,
                        kind: 'picker',
                        value: _edgeLanguage,
                        valueLabel: _edgeLanguageLabel(_edgeLanguage),
                        enabled: !_running,
                        options: _edgeLanguages
                            .map((item) => AccessibleOption(
                                  value: item.code,
                                  label: item.label,
                                ))
                            .toList(),
                      ),
                      AccessibleListRow(
                        id: 'edge_voice',
                        title: l10n.ttsVoice,
                        kind: 'picker',
                        value: _edgeVoice,
                        valueLabel: _edgeVoiceLabel(_edgeVoice),
                        enabled: !_running,
                        options: AppSettingsService.voicesForLanguageFrom(
                          _edgeVoices,
                          _edgeLanguage,
                        )
                            .map((item) => AccessibleOption(
                                  value: item.voice,
                                  label: item.label,
                                ))
                            .toList(),
                      ),
                    ] else ...[
                      if (_systemLanguageOptions().isNotEmpty)
                        AccessibleListRow(
                          id: 'system_language',
                          title: l10n.settingsSystemLanguage,
                          kind: 'picker',
                          value: _systemLanguage,
                          valueLabel: _systemLanguage,
                          enabled: !_running,
                          options: _systemLanguageOptions(),
                        ),
                      AccessibleListRow(
                        id: 'system_voice',
                        title: l10n.settingsSystemVoice,
                        kind: 'picker',
                        value: _systemVoice ?? '',
                        valueLabel:
                            _systemVoice ?? l10n.settingsDefaultVoice,
                        enabled: !_running,
                        options: _systemVoiceOptions(l10n),
                      ),
                    ],
                    AccessibleListRow(
                      id: 'test_voice',
                      title: _testingVoice
                          ? l10n.audioDescriptionVoiceTesting
                          : l10n.settingsTestVoice,
                      enabled: !_running && !_testingVoice,
                    ),
                  ],
                ),
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'create',
                      title: l10n.audioDescriptionCreate,
                      enabled: !_running,
                    ),
                    if (_running)
                      AccessibleListRow(
                        id: 'progress',
                        title: _stage,
                        value: '${(_progress * 100).round()}%',
                        kind: 'text',
                        accessibilityButtonTrait: false,
                      ),
                    if (_running)
                      AccessibleListRow(
                        id: 'cancel',
                        title: l10n.cancel,
                        enabled: !_cancelling,
                      ),
                    if (!_running && _stage.isNotEmpty)
                      AccessibleListRow(
                        id: 'status',
                        title: l10n.info,
                        value: _stage,
                        kind: 'text',
                        accessibilityButtonTrait: false,
                      ),
                    if (_technicalError != null)
                      AccessibleListRow(
                        id: 'technical_error',
                        title: l10n.technicalErrorGeneric,
                        subtitle: _technicalError,
                        kind: 'text',
                        accessibilityButtonTrait: false,
                      ),
                    AccessibleListRow(
                      id: 'continue_description',
                      title: l10n.audioDescriptionContinueAi,
                      enabled: !_running,
                      onActivate: () { unawaited(_continueDescription()); },
                    ),
                    AccessibleListRow(
                      id: 'edit_project',
                      title: l10n.audioDescriptionEditProject,
                      enabled: !_running,
                      onActivate: () async {
                        if (_running) return;
                        await _stopPreviews();
                        if (!context.mounted || _running) return;
                        await Navigator.of(context).pushNamed('/edit_audio_description_project');
                      },
                    ),
                  ],
                ),
              ],
              onEvent: (event) async {
                final id = event.id;
                if (id == null) return;
                if (_running && id != 'cancel') return;
                if (event.type == 'slider') {
                  if (_running) return;
                  final rawValue = event.value;
                  final value = rawValue is num
                      ? rawValue.toDouble()
                      : double.tryParse(rawValue?.toString() ?? '');
                  if (value == null || !value.isFinite) return;
                  if (id == 'mp3_bitrate') {
                    final index = value.clamp(0, audioDescriptionMp3Bitrates.length - 1).round();
                    final bitrate = audioDescriptionMp3Bitrates[index];
                    if (bitrate != _bitrateKbps) {
                      setState(() => _bitrateKbps = bitrate);
                      unawaited(_mixPreview.stop());
                    }
                  } else if (id == 'source_volume') {
                    final volume = value.clamp(0, 40).round() / 20;
                    if (volume != _sourceVolume) {
                      setState(() => _sourceVolume = volume);
                      _requestMixPreview(immediately: false);
                    }
                  }
                } else if (event.type == 'picker') {
                  final value = event.value?.toString() ?? '';
                  setState(() {
                    switch (id) {
                      case 'provider':
                        _provider = value;
                        break;
                      case 'model':
                        _model = value;
                        break;
                      case 'language':
                        _language = value;
                        break;
                      case 'verbosity':
                        _verbosity = value;
                        break;
                      case 'character_catalog':
                        _characterCatalogName = value.isEmpty ? null : value;
                        break;
                      case 'tts_engine':
                        _ttsEngine = value;
                        break;
                      case 'edge_language':
                        _edgeLanguage = value;
                        _edgeVoice = AppSettingsService.defaultVoiceForLanguageFrom(
                          _edgeVoices,
                          value,
                        );
                        break;
                      case 'edge_voice':
                        _edgeVoice = value;
                        break;
                      case 'system_language':
                        _systemLanguage = value;
                        _systemVoice = null;
                        break;
                      case 'system_voice':
                        _systemVoice = value.isEmpty ? null : value;
                        break;
                    }
                  });
                  if (const {
                    'tts_engine', 'edge_language', 'edge_voice',
                    'system_language', 'system_voice',
                  }.contains(id)) {
                    unawaited(_stopPreviews());
                  }
                  if (id == 'provider') {
                    await AppLogger.log(
                      'SONARPAD_AI_DIAG UI provider changed value=$value codeChars=${_sonarpadCode.runes.length}',
                    );
                    await AiAudioDescriptionPreferences.saveProvider(value);
                    if (value == 'sonarpad') {
                      unawaited(_refreshSonarpadBalance());
                    }
                  } else if (id == 'character_catalog') {
                    await _persistCharacterCatalogPreference();
                  }
                } else if (event.type == 'toggle') {
                  final value = event.value == true;
                  setState(() {
                    switch (id) {
                      case 'extended':
                        _extendedPauses = value;
                        break;
                      case 'create_video_output':
                        _createVideoOutput = value;
                        break;
                      case 'characters':
                        _recognizeCharacters = value;
                        if (!value) _keepCharacterCatalog = false;
                        break;
                      case 'screen_text':
                        _recognizeScreenText = value;
                        break;
                      case 'keep_character_catalog':
                        _keepCharacterCatalog = value;
                        break;
                      case 'save_project':
                        _saveProject = value;
                        break;
                    }
                  });
                  if (id == 'characters' || id == 'keep_character_catalog') {
                    await _persistCharacterCatalogPreference();
                  }
                } else if (event.type == 'textChanged') {
                  final value = event.value?.toString() ?? '';
                  setState(() {
                    switch (id) {
                      case 'api_key':
                        _apiKey = value;
                        break;
                      case 'sonarpad_code':
                        _sonarpadCode = value;
                        _sonarpadBalanceEur = null;
                        break;
                    }
                  });
                  if (id == 'api_key' && value.trim().isNotEmpty) {
                    unawaited(AiAudioDescriptionPreferences.saveGeminiApiKey(value));
                  }
                } else if (event.type == 'activate') {
                  switch (id) {
                    case 'choose_video':
                      await _chooseVideo();
                      break;
                    case 'paste_ai_credential':
                      await _pasteAiCredential();
                      break;
                    case 'get_api_key':
                      await _openGeminiApiKeyPage();
                      break;
                    case 'refresh_models':
                      await _refreshModels();
                      break;
                    case 'activate_sonarpad':
                      await _activateSonarpadAi();
                      break;
                    case 'test_voice':
                      await _testVoice();
                      break;
                    case 'mix_preview':
                      await _playMixPreview();
                      break;
                    case 'mix_preview_stop':
                      await _mixPreview.stop();
                      break;
                    case 'load_character_catalog':
                      await _loadCharacterCatalog();
                      break;
                    case 'create':
                      unawaited(_create());
                      break;
                    case 'cancel':
                      await _cancel();
                      break;
                  }
                }
              },
                  ),
                ),
              ],
            ),
    );
  }
}

enum _DoneAction { share, saveDocuments }

Future<bool> showAudioDescriptionCancelConfirmation(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.cancel),
      content: Text(l10n.audioDescriptionCancelConfirmation),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.no),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.yes),
        ),
      ],
    ),
  );
  return confirmed == true;
}
