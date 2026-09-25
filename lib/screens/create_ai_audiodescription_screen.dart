import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/ai_audiodescription_service.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/media_export_destination_service.dart';
import '../tts/edge_tts_bridge.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class CreateAiAudiodescriptionScreen extends StatefulWidget {
  const CreateAiAudiodescriptionScreen({super.key});

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

  bool _loading = true;
  bool _running = false;
  bool _generationActive = false;
  bool _testingVoice = false;
  bool _refreshingModels = false;
  bool _activatingSonarpad = false;
  double _progress = 0;
  String _stage = '';
  String? _sourcePath;
  String? _technicalError;

  String _provider = 'gemini';
  String _apiKey = '';
  String _sonarpadCode = '';
  String _model = 'gemini-3.5-flash-lite';
  List<String> _models = const ['gemini-3.5-flash-lite'];
  String _language = 'it';
  String _verbosity = 'detailed';
  bool _extendedPauses = true;
  bool _recognizeCharacters = true;
  bool _recognizeScreenText = false;
  bool _keepCharacterCatalog = false;
  String? _characterCatalogName;
  List<String> _characterCatalogs = const [];
  bool _saveProject = false;

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
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    _service.dispose();
    _flutterTts.stop();
    unawaited(_audio.dispose());
    super.dispose();
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
        _extendedPauses = preferences['extended'] != false;
        _recognizeCharacters = preferences['characters'] != false;
        _recognizeScreenText = preferences['screenText'] == true;
        _keepCharacterCatalog = preferences['keepCatalog'] == true;
        _characterCatalogName = preferences['catalogName']?.toString();
        _characterCatalogs = characterCatalogs;
        _saveProject = preferences['project'] == true;
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

  Future<void> _chooseVideo() async {
    if (_running) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: false,
      allowedExtensions: const [
        'mp4', 'mkv', 'mov', 'm4v', 'avi', 'webm', 'ts', 'mts', 'm2ts',
      ],
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) return;
    if (!mounted) return;
    setState(() {
      _sourcePath = path;
      _technicalError = null;
    });
  }

  Future<void> _openGeminiApiKeyPage() async {
    final uri = Uri.parse('https://aistudio.google.com/app/apikey');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Future<void> _activateSonarpadAi() async {
    if (_activatingSonarpad || _running) return;
    final l10n = AppLocalizations.of(context);
    if (_sonarpadCode.trim().isEmpty) {
      showStatusMessage(context, l10n.audioDescriptionSonarpadCodeRequired);
      return;
    }
    setState(() => _activatingSonarpad = true);
    try {
      await _service.activateSonarpadAi(_sonarpadCode);
      if (!mounted) return;
      showStatusMessage(context, l10n.audioDescriptionSonarpadActivated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _technicalError = error.toString());
      showStatusMessage(context, l10n.audioDescriptionSonarpadActivationError);
    } finally {
      if (mounted) setState(() => _activatingSonarpad = false);
    }
  }

  Future<void> _testVoice() async {
    if (_testingVoice || _running) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _testingVoice = true);
    try {
      final speed = await _settings.loadTtsSpeed();
      final pitch = await _settings.loadTtsPitch();
      if (_ttsEngine == 'system') {
        await _flutterTts.setSpeechRate(speed * 0.5);
        await _flutterTts.setPitch(pitch);
        if (_systemVoice != null) {
          await _flutterTts.setVoice(<String, String>{
            'name': _systemVoice!,
            'locale': _systemLanguage,
          });
        } else {
          await _flutterTts.setLanguage(_systemLanguage);
        }
        await _flutterTts.speak(l10n.settingsVoiceTestText);
      } else {
        final file = await EdgeTtsBridge().speakToFile(
          text: l10n.settingsVoiceTestText,
          voice: _edgeVoice,
          speed: speed,
          pitch: pitch,
        );
        await _flutterTts.stop();
        await _audio.playFile(file);
        if (mounted) {
          showStatusMessage(context, l10n.audioDescriptionEdgeVoiceReady);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _technicalError = error.toString());
      showStatusMessage(context, l10n.settingsVoiceTestError(l10n.technicalErrorGeneric));
    } finally {
      if (mounted) setState(() => _testingVoice = false);
    }
  }

  AiAudioDescriptionSettings _currentSettings() => AiAudioDescriptionSettings(
        provider: _provider,
        geminiApiKey: _apiKey,
        sonarpadCode: _sonarpadCode,
        geminiModel: _model,
        languageCode: _language,
        verbosity: _verbosity,
        allowExtendedPauses: _extendedPauses,
        recognizeCharacters: _recognizeCharacters,
        recognizeScreenText: _recognizeScreenText,
        keepCharacterCatalog: _recognizeCharacters && _keepCharacterCatalog,
        characterCatalogName: _characterCatalogName,
        saveProject: _saveProject,
        ttsEngine: _ttsEngine,
        edgeLanguage: _edgeLanguage,
        edgeVoice: _edgeVoice,
        systemLanguage: _systemLanguage,
        systemVoice: _systemVoice,
      );

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

  Future<void> _create() async {
    if (_running) return;
    final l10n = AppLocalizations.of(context);
    final sourcePath = _sourcePath;
    if (sourcePath == null || sourcePath.isEmpty) {
      showStatusMessage(context, l10n.audioDescriptionChooseVideoFirst);
      return;
    }
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
    }
    setState(() {
      _running = true;
      _generationActive = true;
      _progress = 0;
      _stage = l10n.audioDescriptionStagePreparing;
      _technicalError = null;
    });
    try {
      final result = await _service.create(
        sourcePath: sourcePath,
        settings: _currentSettings(),
        onProgress: (progress) {
          if (!mounted) return;
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
      );
      _generationActive = false;
      if (!mounted) return;
      await _showDoneDialog(result);
    } catch (error, stackTrace) {
      _generationActive = false;
      await AppLogger.log('Audio description UI: generation error=$error\n$stackTrace');
      if (!mounted) return;
      final cancelled = error.toString().contains('AUDIO_DESCRIPTION_CANCELLED');
      setState(() {
        _technicalError = cancelled ? null : error.toString();
        _stage = cancelled
            ? l10n.audioDescriptionCancelled
            : l10n.audioDescriptionGenerationFailed;
      });
      showStatusMessage(
        context,
        cancelled
            ? l10n.audioDescriptionCancelled
            : l10n.audioDescriptionGenerationFailed,
      );
    } finally {
      _generationActive = false;
      if (mounted) {
        setState(() {
          _running = false;
          _progress = 0;
        });
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

  void _cancel() {
    _service.cancel();
    if (mounted) {
      setState(() => _stage = AppLocalizations.of(context).audioDescriptionCancelling);
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
        if (action == _DoneAction.share) {
          await SharePlus.instance.share(
            ShareParams(
              files: result.outputPaths.map((path) => XFile(path)).toList(),
              text: p.basename(result.mp3Path),
            ),
          );
        } else {
          for (final path in result.outputPaths) {
            await destinationService.saveInSonarpadDocuments(
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
          label: '${l10n.radioLanguagePt} (${l10n.radioCountryOptionPt})',
        ),
        AccessibleOption(
          value: 'pt_BR',
          label: '${l10n.radioLanguagePt} (${l10n.radioCountryOptionBr})',
        ),
        AccessibleOption(value: 'pl', label: l10n.radioLanguagePl),
        AccessibleOption(value: 'cs', label: l10n.radioLanguageCs),
        AccessibleOption(value: 'de', label: l10n.german),
        AccessibleOption(
          value: 'zh_CN',
          label: l10n.simplifiedChineseLanguageName,
        ),
        AccessibleOption(value: 'uk', label: l10n.radioLanguageUk),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.audioDescriptionCreateAiTitle)),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading),
            )
          : Column(
              children: [
                if (_running)
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
                        id: 'activate_sonarpad',
                        title: _activatingSonarpad
                            ? l10n.audioDescriptionActivatingSonarpad
                            : l10n.audioDescriptionActivateSonarpad,
                        enabled: !_running && !_activatingSonarpad,
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
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'characters',
                      title: l10n.audioDescriptionRecognizeCharacters,
                      kind: 'toggle',
                      toggleValue: _recognizeCharacters,
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
                        value: _technicalError,
                        kind: 'text',
                        accessibilityButtonTrait: false,
                      ),
                  ],
                ),
              ],
              onEvent: (event) async {
                final id = event.id;
                if (id == null) return;
                if (event.type == 'picker') {
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
                } else if (event.type == 'toggle') {
                  final value = event.value == true;
                  setState(() {
                    switch (id) {
                      case 'extended':
                        _extendedPauses = value;
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
                } else if (event.type == 'textChanged') {
                  final value = event.value?.toString() ?? '';
                  setState(() {
                    switch (id) {
                      case 'api_key':
                        _apiKey = value;
                        break;
                      case 'sonarpad_code':
                        _sonarpadCode = value;
                        break;
                    }
                  });
                } else if (event.type == 'activate') {
                  switch (id) {
                    case 'choose_video':
                      await _chooseVideo();
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
                    case 'create':
                      await _create();
                      break;
                    case 'cancel':
                      _cancel();
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
