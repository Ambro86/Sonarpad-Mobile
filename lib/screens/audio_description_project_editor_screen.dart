import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import 'audio_description_project_picker_screen.dart';
import '../services/cloud_file_picker_service.dart';
import '../services/ai_audiodescription_service.dart';
import '../services/app_settings_service.dart';
import '../services/audio_description_mix.dart';
import '../services/audio_description_mix_preview_controller.dart';
import '../services/audio_description_project_strings.dart';
import '../services/audio_player_service.dart';
import '../services/media_export_destination_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class AudioDescriptionProjectEditorScreen extends StatefulWidget {
  const AudioDescriptionProjectEditorScreen({
    super.key,
    this.initialProjectPath,
    this.projectServiceFactory,
    this.mixPreviewControllerFactory,
  });

  final String? initialProjectPath;

  /// Optional factory for observing real project I/O in editor tests.
  /// The editor owns and disposes the service; normal callers use the default.
  final AiAudioDescriptionService Function()? projectServiceFactory;
  final AudioDescriptionMixPreviewController Function()? mixPreviewControllerFactory;

  @override
  State<AudioDescriptionProjectEditorScreen> createState() =>
      _AudioDescriptionProjectEditorScreenState();
}

class _AudioDescriptionProjectEditorScreenState
    extends State<AudioDescriptionProjectEditorScreen> with WidgetsBindingObserver {
  late final AiAudioDescriptionService _service;
  final _flutterTts = FlutterTts();
  final _audio = AudioPlayerService();
  late final AudioDescriptionMixPreviewController _mixPreview;
  Future<void> _projectWrites = Future<void>.value();
  int _audioSaveRevision = 0;
  int _mixPreviewRevision = 0;
  int _operationRevision = 0;
  bool _serviceOperationStarted = false;

  AudioDescriptionEditableProject? _project;
  String? _sourceOverride;
  int _selectedIndex = 0;
  String _editText = '';
  bool _dirty = false;
  bool _running = false;
  double _progress = 0;
  String _status = '';
  String? _technicalError;

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
    _service = widget.projectServiceFactory?.call() ?? AiAudioDescriptionService();
    WidgetsBinding.instance.addObserver(this);
    _mixPreview = widget.mixPreviewControllerFactory?.call() ??
        AudioDescriptionMixPreviewController();
    _mixPreview.addListener(_mixPreviewChanged);
    unawaited(_loadVoiceLists());
    final path = widget.initialProjectPath;
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadProject(path));
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(_mixPreview.stop());
    }
    if (_running && state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
    }
  }

  @override
  void dispose() {
    ++_operationRevision;
    WidgetsBinding.instance.removeObserver(this);
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

  void _checkOperation(int revision) {
    if (!mounted || revision != _operationRevision) {
      throw const _EditorOperationCancelled();
    }
  }

  Future<void> _stopPlayback() async {
    await _mixPreview.stop();
    await _audio.stop();
  }

  Future<T> _queueProjectOperation<T>(Future<T> Function() operation) {
    final pending = _projectWrites.then((_) => operation());
    // Keep the queue usable after a failed write. Every caller handles its
    // own error; the immutable snapshots can finish saving after navigation.
    _projectWrites = pending.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return pending;
  }

  AudioDescriptionEditableProject? _mixPreviewProject() {
    final project = _project;
    if (project == null) return null;
    return project.copyWith(
      ttsEngine: _ttsEngine,
      ttsVoice: _ttsEngine == 'edge' ? _edgeVoice : (_systemVoice ?? ''),
      edgeLanguage: _edgeLanguage,
      systemLanguage: _systemLanguage,
      systemVoice: _systemVoice,
      clearSystemVoice: _ttsEngine != 'system' || _systemVoice == null,
    );
  }

  void _requestMixPreview({required bool immediately}) {
    final project = _mixPreviewProject();
    final source = _sourceOverride;
    if (_running || project == null || source == null || source.isEmpty) return;
    final revision = ++_mixPreviewRevision;
    final text = AppLocalizations.of(context).audioDescriptionMixPreviewPhrase;
    Future<AudioDescriptionMixPreview> render(AiAudioDescriptionService service) async {
      await _audio.stop();
      if (!mounted || revision != _mixPreviewRevision || !_mixPreview.isActive) {
        throw const _EditorOperationCancelled();
      }
      return service.previewProjectMix(
        project: project,
        text: text,
        sourcePathOverride: source,
      );
    }
    if (immediately) {
      _mixPreview.playNow(render);
    } else {
      _mixPreview.schedule(render);
    }
  }

  Future<void> _toggleMixPreview() async {
    if (_running || _project == null || !_mixPreview.canPauseOrResume) return;
    if (_mixPreview.isPlaying) {
      await _mixPreview.pause();
    } else if (_mixPreview.isPaused) {
      await _mixPreview.resume();
    }
  }

  Future<void> _setAudioSetting(AccessibleListEvent event) async {
    final project = _project;
    if (_running || project == null) return;
    final rawValue = event.value;
    final value = rawValue is num
        ? rawValue.toDouble()
        : double.tryParse(rawValue?.toString() ?? '');
    if (value == null || !value.isFinite) return;
    AudioDescriptionEditableProject updated;
    if (event.id == 'mp3_bitrate') {
      final index = value.clamp(0, audioDescriptionMp3Bitrates.length - 1).round();
      final bitrate = audioDescriptionMp3Bitrates[index];
      if (bitrate == project.bitrateKbps) return;
      updated = project.copyWith(bitrateKbps: bitrate);
    } else if (event.id == 'source_volume') {
      final volume = value.clamp(0, 40).round() / 20;
      if (volume == project.sourceVolume) return;
      updated = project.copyWith(sourceVolume: volume);
    } else {
      return;
    }
    final snapshot = updated.copyWith(updatedAtUtc: DateTime.now().toUtc().toIso8601String());
    final revision = ++_audioSaveRevision;
    setState(() {
      _project = snapshot;
      _technicalError = null;
    });
    if (event.id == 'source_volume') {
      _requestMixPreview(immediately: false);
    } else {
      unawaited(_mixPreview.stop());
    }
    try {
      await _queueProjectOperation(() => _service.saveEditableProject(snapshot));
    } catch (error, stackTrace) {
      await AppLogger.log('Audio description project audio settings save failed $error\n$stackTrace');
      if (!mounted || revision != _audioSaveRevision ||
          _project?.projectPath != snapshot.projectPath) {
        return;
      }
      setState(() => _technicalError = error.toString());
    }
  }

  Future<void> _loadVoiceLists() async {
    try {
      final edge = await AppSettingsService.loadEdgeVoices();
      final langs = AppSettingsService.languagesForVoices(edge);
      final system = await _loadSystemVoices();
      if (!mounted) return;
      setState(() {
        _edgeVoices = edge;
        _edgeLanguages = langs;
        _systemVoices = system;
      });
    } catch (error) {
      await AppLogger.log('Audio description project editor: voice lists failed $error');
    }
  }

  Future<List<Map<String, String>>> _loadSystemVoices() async {
    try {
      final raw = await _flutterTts.getVoices;
      if (raw is! List) return const [];
      final result = <Map<String, String>>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final name = item['name']?.toString().trim() ?? '';
        final locale = item['locale']?.toString().trim() ?? '';
        if (name.isNotEmpty && locale.isNotEmpty) {
          result.add(<String, String>{'name': name, 'locale': locale});
        }
      }
      result.sort((a, b) {
        final locale = (a['locale'] ?? '').compareTo(b['locale'] ?? '');
        return locale != 0 ? locale : (a['name'] ?? '').compareTo(b['name'] ?? '');
      });
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openProject() async {
    if (_running) return;
    await _stopPlayback();
    if (!mounted) return;
    final path = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const AudioDescriptionProjectPickerScreen(),
    ));
    if (!mounted || path == null) return;
    await _loadProject(path);
  }

  Future<void> _browseProject() async {
    if (_running) return;
    try {
      await _stopPlayback();
      if (!mounted) return;
      final result = await CloudFilePicker.pickFiles(context: context, 
        type: FileType.custom,
        allowMultiple: false,
        withData: false,
        allowedExtensions: const ['json'],
      );
      final path = result?.files.single.path;
      if (!mounted || path == null || path.trim().isEmpty) return;
      await _loadProject(path);
    } catch (error, stackTrace) {
      await AppLogger.log('Audio description project editor: browse failed $error\n$stackTrace');
      if (mounted) showStatusMessage(context, AppLocalizations.of(context).technicalErrorGeneric);
    }
  }

  Future<void> _loadProject(String path) async {
    if (_running) return;
    final s = AudioDescriptionProjectStrings.of(context);
    final operation = ++_operationRevision;
    setState(() => _running = true);
    try {
      await _stopPlayback();
      await _projectWrites;
      _checkOperation(operation);
      final project = await _service.loadEditableProject(path);
      final sourceExists = project.sourcePath.isNotEmpty &&
          await File(project.sourcePath).exists();
      _checkOperation(operation);
      setState(() {
        _project = project;
        _sourceOverride = sourceExists ? project.sourcePath : null;
        _selectedIndex = 0;
        _editText = project.descriptions.first.text;
        _dirty = false;
        _status = s.ready;
        _technicalError = null;
        _applyProjectVoiceToUi(project);
      });
    } on _EditorOperationCancelled {
      // Navigation or Cancel superseded this pending load.
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description project editor: open failed error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _technicalError = error.toString();
        _status = s.invalidProject;
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _applyProjectVoiceToUi(AudioDescriptionEditableProject project) {
    _ttsEngine = (project.ttsEngine == 'edge' || project.ttsEngine == 'system')
        ? project.ttsEngine
        : 'edge';
    _edgeLanguage = project.edgeLanguage;
    _edgeVoice = project.ttsVoice.isNotEmpty
        ? project.ttsVoice
        : AppSettingsService.defaultVoiceForLanguageFrom(
            _edgeVoices,
            project.edgeLanguage,
          );
    _systemLanguage = project.systemLanguage;
    _systemVoice = project.systemVoice;
  }

  Future<void> _chooseSource() async {
    if (_running) return;
    await _stopPlayback();
    if (!mounted) return;
    final result = await CloudFilePicker.pickFiles(context: context, 
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
      _sourceOverride = path;
      _technicalError = null;
    });
  }

  AudioDescriptionProjectItem? get _selected {
    final project = _project;
    if (project == null || project.descriptions.isEmpty) return null;
    final index = _selectedIndex.clamp(0, project.descriptions.length - 1).toInt();
    return project.descriptions[index];
  }

  Future<T> _withWakelock<T>(
    int operation,
    Future<T> Function() action,
  ) async {
    _checkOperation(operation);
    bool? previous;
    try {
      previous = await WakelockPlus.enabled;
    } catch (_) {}
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    try {
      _checkOperation(operation);
      _serviceOperationStarted = true;
      return await action();
    } finally {
      _serviceOperationStarted = false;
      try {
        if (previous == true) {
          await WakelockPlus.enable();
        } else {
          await WakelockPlus.disable();
        }
      } catch (_) {}
    }
  }

  String _tooLongMessage(
    AudioDescriptionProjectStrings strings,
    AudioDescriptionProjectTooLongException error,
  ) =>
      strings.tooLong(
        actual: error.actualSec.toStringAsFixed(2),
        available: error.availableSec.toStringAsFixed(2),
      );

  Future<void> _preview() async {
    final project = _project;
    if (project == null || _running) return;
    final operation = ++_operationRevision;
    final strings = AudioDescriptionProjectStrings.of(context);
    setState(() {
      _running = true;
      _progress = 0.3;
      _status = strings.working;
      _technicalError = null;
    });
    try {
      await _stopPlayback();
      _checkOperation(operation);
      final preview = await _withWakelock(operation, () => _service.previewProjectDescription(
            project: project,
            index: _selectedIndex,
            text: _editText,
          ));
      _checkOperation(operation);
      await _audio.playFile(File(preview.path));
      _checkOperation(operation);
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _status = strings.ready;
      });
    } on _EditorOperationCancelled {
      // Cancellation also covers time spent draining the previous preview.
    } on AudioDescriptionProjectTooLongException catch (error) {
      if (!mounted) return;
      setState(() => _status = _tooLongMessage(strings, error));
    } catch (error, stackTrace) {
      await AppLogger.log('Audio description project preview failed $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _technicalError = error.toString();
        _status = error.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _applyEdit() async {
    final project = _project;
    if (project == null || _running) return;
    final operation = ++_operationRevision;
    final strings = AudioDescriptionProjectStrings.of(context);
    setState(() {
      _running = true;
      _progress = 0.25;
      _status = strings.working;
      _technicalError = null;
    });
    try {
      await _stopPlayback();
      _checkOperation(operation);
      final updated = await _queueProjectOperation(
        () => _withWakelock(operation, () => _service.applyProjectDescriptionEdit(
            project: project,
            index: _selectedIndex,
            text: _editText,
          )),
      );
      if (!mounted) return;
      setState(() {
        _project = updated;
        _editText = updated.descriptions[_selectedIndex].text;
        _dirty = false;
        _progress = 1;
        _status = strings.applied;
      });
    } on _EditorOperationCancelled {
      // Cancellation also covers time spent draining the previous preview.
    } on AudioDescriptionProjectTooLongException catch (error) {
      if (!mounted) return;
      setState(() => _status = _tooLongMessage(strings, error));
    } catch (error, stackTrace) {
      await AppLogger.log('Audio description project apply failed $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _technicalError = error.toString();
        _status = error.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _deleteDescription() async {
    final project = _project;
    if (project == null || _running) return;
    final strings = AudioDescriptionProjectStrings.of(context);
    if (project.descriptions.length <= 1) {
      setState(() => _status = strings.deleteLast);
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(strings.deleteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted || _running) return;
    final latest = _project;
    if (latest == null || latest.projectPath != project.projectPath) return;
    final operation = ++_operationRevision;
    setState(() => _running = true);
    try {
      await _stopPlayback();
      _checkOperation(operation);
      final updated = await _queueProjectOperation(
        () {
          _checkOperation(operation);
          return _service.deleteProjectDescription(
            project: latest,
            index: _selectedIndex,
          );
        },
      );
      if (!mounted) return;
      final newIndex = _selectedIndex.clamp(0, updated.descriptions.length - 1).toInt();
      setState(() {
        _project = updated;
        _selectedIndex = newIndex;
        _editText = updated.descriptions[newIndex].text;
        _dirty = false;
        _status = strings.deleted;
      });
    } on _EditorOperationCancelled {
      // The queued write has not started if cancellation happened in the drain.
    } catch (error) {
      if (mounted) setState(() => _technicalError = error.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _changeVoice() async {
    final project = _project;
    if (project == null || _running) return;
    final operation = ++_operationRevision;
    final strings = AudioDescriptionProjectStrings.of(context);
    final speed = project.ttsSpeed;
    final pitch = project.ttsPitch;
    setState(() {
      _running = true;
      _progress = 0;
      _status = strings.working;
      _technicalError = null;
    });
    try {
      await _stopPlayback();
      _checkOperation(operation);
      final updated = await _queueProjectOperation(
        () => _withWakelock(operation, () => _service.changeProjectVoice(
            project: project,
            ttsEngine: _ttsEngine,
            edgeLanguage: _edgeLanguage,
            edgeVoice: _edgeVoice,
            systemLanguage: _systemLanguage,
            systemVoice: _systemVoice,
            speed: speed,
            pitch: pitch,
            onProgress: (value) {
              if (!mounted) return;
              setState(() => _progress = value.clamp(0.0, 1.0).toDouble());
            },
          )),
      );
      if (!mounted) return;
      setState(() {
        _project = updated;
        _progress = 1;
        _status = strings.voiceChanged;
      });
    } on _EditorOperationCancelled {
      // Cancellation also covers time spent draining the previous preview.
    } on AudioDescriptionProjectTooLongException catch (error) {
      if (!mounted) return;
      setState(() => _status = _tooLongMessage(strings, error));
    } catch (error, stackTrace) {
      await AppLogger.log('Audio description project voice change failed $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _technicalError = error.toString();
        _status = error.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _reexport() async {
    final project = _project;
    if (project == null || _running) return;
    final strings = AudioDescriptionProjectStrings.of(context);
    if (_dirty) {
      setState(() => _status = strings.unsaved);
      return;
    }
    var source = _sourceOverride;
    final sourceExists = source != null && source.isNotEmpty &&
        await File(source).exists();
    if (!mounted) return;
    if (!sourceExists) {
      setState(() => _status = strings.sourceMissing);
      await _chooseSource();
      source = _sourceOverride;
      if (source == null || source.isEmpty) return;
    }
    if (!mounted || _running) return;
    final latest = _project;
    if (latest == null || latest.projectPath != project.projectPath) return;
    if (_dirty) {
      setState(() => _status = strings.unsaved);
      return;
    }
    final operation = ++_operationRevision;
    setState(() {
      _running = true;
      _progress = 0;
      _status = strings.working;
      _technicalError = null;
    });
    try {
      await _stopPlayback();
      _checkOperation(operation);
      final result = await _queueProjectOperation(
        () => _withWakelock(operation, () => _service.reexportEditableProject(
            project: latest,
            sourcePathOverride: source,
            onProgress: (progress) {
              if (!mounted) return;
              final l10n = AppLocalizations.of(context);
              final label = switch (progress.stage) {
                'project_tts' => l10n.audioDescriptionStageTts,
                'project_export' => l10n.audioDescriptionStageMixing,
                'completed' => l10n.audioDescriptionCompleted,
                _ => l10n.audioDescriptionStagePreparing,
              };
              setState(() {
                if (progress.value > _progress) {
                  _progress = progress.value.clamp(0.0, 1.0).toDouble();
                }
                _status = progress.detail == null
                    ? label
                    : '$label ${progress.detail}';
              });
            },
          )),
      );
      if (!mounted) return;
      setState(() {
        _project = result.project;
        _selectedIndex = _selectedIndex.clamp(0, result.project.descriptions.length - 1).toInt();
        _editText = result.project.descriptions[_selectedIndex].text;
        _progress = 1;
        _status = strings.completed;
      });
      await _showOutputDialog(result.outputPaths);
    } on _EditorOperationCancelled {
      // Cancellation also covers time spent draining the previous preview.
    } on AudioDescriptionProjectTooLongException catch (error) {
      if (!mounted) return;
      setState(() => _status = _tooLongMessage(strings, error));
    } catch (error, stackTrace) {
      await AppLogger.log('Audio description project export failed $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _technicalError = error.toString();
        _status = error.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _exportSubtitle(String format) async {
    final project = _project;
    if (project == null || _running) return;
    final strings = AudioDescriptionProjectStrings.of(context);
    if (_dirty) {
      setState(() => _status = strings.unsaved);
      return;
    }
    try {
      await _stopPlayback();
      await _projectWrites;
      if (!mounted) return;
      final path = await _service.exportEditableProjectSubtitle(
        project: project,
        format: format,
      );
      await _showOutputDialog(<String>[path]);
    } catch (error) {
      if (mounted) setState(() => _technicalError = error.toString());
    }
  }

  Future<void> _showOutputDialog(List<String> paths) async {
    final strings = AudioDescriptionProjectStrings.of(context);
    final destination = MediaExportDestinationService();
    final action = await showDialog<_OutputAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Text(strings.completed),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _OutputAction.share),
            child: Text(strings.share),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _OutputAction.saveDocuments),
            child: Text(strings.saveDocuments),
          ),
        ],
      ),
    );
    if (action == null) return;
    if (action == _OutputAction.share) {
      await SharePlus.instance.share(
        ShareParams(files: paths.map((path) => XFile(path)).toList()),
      );
    } else {
      for (final path in paths) {
        await destination.saveInSonarpadAudiodescriptions(
          path,
          originalName: p.basename(path),
        );
      }
      if (mounted) showStatusMessage(context, strings.saved);
    }
  }

  void _cancel() {
    ++_operationRevision;
    if (_serviceOperationStarted) _service.cancel();
    unawaited(_mixPreview.stop());
    unawaited(_audio.stop());
    setState(() => _status = AudioDescriptionProjectStrings.of(context).cancel);
  }

  List<AccessibleOption> _descriptionOptions() {
    final project = _project;
    if (project == null) return const [];
    return List<AccessibleOption>.generate(project.descriptions.length, (index) {
      final item = project.descriptions[index];
      final short = item.text.length > 70 ? '${item.text.substring(0, 70)}…' : item.text;
      return AccessibleOption(
        value: '$index',
        label: AppLocalizations.of(context).audioDescriptionProjectEditorDescriptionOption(
          '${index + 1}',
          item.sourceStartSec.toStringAsFixed(1),
          short,
        ),
      );
    });
  }

  String _localizedTurkishTtsLanguageLabel(
    AppLocalizations l10n,
    String code,
    String fallbackLabel,
  ) {
    final normalized = code.trim().replaceAll('_', '-').toLowerCase();
    if (normalized == 'tr') return l10n.languageLabel('tr');
    if (normalized == 'tr-tr') {
      return l10n.audioDescriptionLanguageCountry(
        l10n.languageLabel('tr'),
        l10n.radioCountryOptionTr,
      );
    }
    return fallbackLabel;
  }

  List<AccessibleOption> _edgeLanguageOptions(AppLocalizations l10n) => _edgeLanguages
      .map((item) => AccessibleOption(
            value: item.code,
            label: _localizedTurkishTtsLanguageLabel(
              l10n,
              item.code,
              item.label,
            ),
          ))
      .toList();

  List<AccessibleOption> _edgeVoiceOptions() =>
      AppSettingsService.voicesForLanguageFrom(_edgeVoices, _edgeLanguage)
          .map((item) => AccessibleOption(value: item.voice, label: item.label))
          .toList();

  List<AccessibleOption> _systemLanguageOptions(AppLocalizations l10n) {
    final values = _systemVoices
        .map((item) => item['locale'] ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values
        .map((value) => AccessibleOption(
              value: value,
              label: _localizedTurkishTtsLanguageLabel(l10n, value, value),
            ))
        .toList();
  }

  List<AccessibleOption> _systemVoiceOptions() {
    final values = _systemVoices
        .where((item) => item['locale'] == _systemLanguage)
        .map((item) => item['name'] ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    return <AccessibleOption>[
      AccessibleOption(value: '', label: AppLocalizations.of(context).settingsDefaultVoice),
      ...values.map((value) => AccessibleOption(value: value, label: value)),
    ];
  }

  String _detailValue(AudioDescriptionProjectStrings strings) {
    final item = _selected;
    if (item == null) return '';
    return strings.details(
      source: item.sourceStartSec.toStringAsFixed(2),
      start: item.outputStartSec.toStringAsFixed(2),
      end: item.outputEndSec.toStringAsFixed(2),
      duration: item.ttsDurationSec.toStringAsFixed(2),
      mode: item.extendedPause ? strings.extended : strings.normal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strings = AudioDescriptionProjectStrings.of(context);
    final project = _project;
    final source = _sourceOverride ?? project?.sourcePath;
    final bitrateIndex = audioDescriptionMp3Bitrates.indexOf(
      project?.bitrateKbps ?? audioDescriptionDefaultBitrateKbps,
    );
    final bitrateLabels = [
      for (final bitrate in audioDescriptionMp3Bitrates)
        '$bitrate kbps${bitrate == 192 ? ' (${l10n.audioDescriptionAudioNormal})' : ''}',
    ];
    final volumeIndex = ((project?.sourceVolume ?? audioDescriptionDefaultSourceVolume) * 20).round();
    final volumeFormat = NumberFormat('0.0#', l10n.localeName);
    final volumeLabels = [
      for (var index = 0; index <= 40; index++)
        '${volumeFormat.format(index / 20)}${index == 20 ? ' (${l10n.audioDescriptionAudioNormal})' : ''}',
    ];
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(strings.title)),
      body: Column(
        children: [
          if (_running)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: LinearProgressIndicator(
                value: _progress.clamp(0.0, 1.0).toDouble(),
                semanticsLabel: _status,
                semanticsValue: '${(_progress * 100).round()}%',
              ),
            ),
          Expanded(
            child: UniversalAccessibleList(
              key: const ValueKey('audio_description_project_editor'),
              initialFocusId: 'open_project',
              sections: [
                AccessibleListSection(rows: [
                  AccessibleListRow(
                    id: 'open_project',
                    title: l10n.audioDescriptionFindProject,
                    enabled: !_running,
                  ),
                  AccessibleListRow(
                    id: 'browse_project',
                    title: l10n.audioDescriptionBrowseProject,
                    enabled: !_running,
                  ),
                  if (project != null)
                    AccessibleListRow(
                      id: 'project_name',
                      title: strings.project,
                      value: p.basename(project.projectPath),
                      kind: 'text',
                      accessibilityButtonTrait: false,
                    ),
                  if (project != null)
                    AccessibleListRow(
                      id: 'choose_source',
                      title: strings.chooseSource,
                      value: source == null || source.isEmpty ? null : p.basename(source),
                      enabled: !_running,
                    ),
                ]),
                if (project != null)
                  AccessibleListSection(rows: [
                    AccessibleListRow(
                      id: 'description',
                      title: strings.description,
                      kind: 'picker',
                      value: '$_selectedIndex',
                      valueLabel: _descriptionOptions()[_selectedIndex].label,
                      enabled: !_running,
                      options: _descriptionOptions(),
                    ),
                    AccessibleListRow(
                      id: 'description_details',
                      title: strings.description,
                      subtitle: _detailValue(strings),
                      kind: 'text',
                      accessibilityButtonTrait: false,
                    ),
                    AccessibleListRow(
                      id: 'description_text',
                      title: strings.text,
                      kind: 'textField',
                      value: _editText,
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'preview',
                      title: strings.preview,
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'apply',
                      title: strings.apply,
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'delete',
                      title: strings.delete,
                      enabled: !_running,
                    ),
                  ]),
                if (project != null)
                  AccessibleListSection(rows: [
                    AccessibleListRow(
                      id: 'tts_engine',
                      title: strings.engine,
                      kind: 'picker',
                      value: _ttsEngine,
                      valueLabel: _ttsEngine == 'system' ? strings.system : strings.edge,
                      enabled: !_running,
                      options: [
                        AccessibleOption(value: 'edge', label: strings.edge),
                        AccessibleOption(value: 'system', label: strings.system),
                      ],
                    ),
                    if (_ttsEngine == 'edge') ...[
                      AccessibleListRow(
                        id: 'edge_language',
                        title: strings.language,
                        kind: 'picker',
                        value: _edgeLanguage,
                        valueLabel: _localizedTurkishTtsLanguageLabel(
                          l10n,
                          _edgeLanguage,
                          _edgeLanguage,
                        ),
                        enabled: !_running,
                        options: _edgeLanguageOptions(l10n),
                      ),
                      AccessibleListRow(
                        id: 'edge_voice',
                        title: strings.voice,
                        kind: 'picker',
                        value: _edgeVoice,
                        valueLabel: _edgeVoice,
                        enabled: !_running,
                        options: _edgeVoiceOptions(),
                      ),
                    ] else ...[
                      if (_systemLanguageOptions(l10n).isNotEmpty)
                        AccessibleListRow(
                          id: 'system_language',
                          title: strings.language,
                          kind: 'picker',
                          value: _systemLanguage,
                          valueLabel: _localizedTurkishTtsLanguageLabel(
                            l10n,
                            _systemLanguage,
                            _systemLanguage,
                          ),
                          enabled: !_running,
                          options: _systemLanguageOptions(l10n),
                        ),
                      AccessibleListRow(
                        id: 'system_voice',
                        title: strings.voice,
                        kind: 'picker',
                        value: _systemVoice ?? '',
                        valueLabel: _systemVoice ?? l10n.settingsDefaultVoice,
                        enabled: !_running,
                        options: _systemVoiceOptions(),
                      ),
                    ],
                    AccessibleListRow(
                      id: 'change_voice',
                      title: strings.changeVoice,
                      enabled: !_running,
                    ),
                  ]),
                if (project != null)
                  AccessibleListSection(rows: [
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
                      hint: '${l10n.audioDescriptionSourceVolumeHint} ${l10n.audioDescriptionMixPreviewHint}',
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
                    // A fresh or completed sample cannot be resumed. Keep
                    // this row out of both the visual and accessibility trees.
                    if (_mixPreview.canPauseOrResume)
                      AccessibleListRow(
                        id: 'mix_preview',
                        title: _mixPreview.isPlaying
                            ? l10n.pause
                            : l10n.audioDescriptionResume,
                        hint: l10n.audioDescriptionMixPreviewHint,
                        enabled: !_running,
                      ),
                    if ((_mixPreview.isActive && !_mixPreview.canPauseOrResume) ||
                        _mixPreview.error != null)
                      AccessibleListRow(
                        id: 'mix_preview_status',
                        title: _mixPreview.error != null
                            ? l10n.technicalErrorGeneric
                            : l10n.audioDescriptionMixPreviewPreparing,
                        kind: 'text',
                        accessibilityButtonTrait: false,
                      ),
                  ]),
                if (project != null)
                  AccessibleListSection(rows: [
                    AccessibleListRow(
                      id: 'reexport',
                      title: strings.reexport,
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'export_srt',
                      title: strings.srt,
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'export_vtt',
                      title: strings.vtt,
                      enabled: !_running,
                    ),
                    if (_running)
                      AccessibleListRow(
                        id: 'progress',
                        title: _status,
                        value: '${(_progress * 100).round()}%',
                        kind: 'text',
                        accessibilityButtonTrait: false,
                      ),
                    if (_running)
                      AccessibleListRow(
                        id: 'cancel',
                        title: strings.cancel,
                      ),
                    if (!_running && _status.isNotEmpty)
                      AccessibleListRow(
                        id: 'status',
                        title: l10n.info,
                        subtitle: _status,
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
                  ]),
              ],
              onEvent: (event) async {
                final id = event.id;
                if (id == null || !mounted) return;
                if (_running && id != 'cancel') return;
                if (event.type == 'slider') {
                  await _setAudioSetting(event);
                } else if (event.type == 'picker') {
                  final value = event.value?.toString() ?? '';
                  setState(() {
                    switch (id) {
                      case 'description':
                        _selectedIndex = int.tryParse(value) ?? 0;
                        _editText = _project!.descriptions[_selectedIndex].text;
                        _dirty = false;
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
                  if (id != 'description') unawaited(_mixPreview.stop());
                } else if (event.type == 'textChanged' && id == 'description_text') {
                  final value = event.value?.toString() ?? '';
                  setState(() {
                    _editText = value;
                    _dirty = _selected?.text != value;
                  });
                } else if (event.type == 'activate') {
                  switch (id) {
                    case 'open_project':
                      await _openProject();
                      break;
                    case 'browse_project':
                      await _browseProject();
                      break;
                    case 'choose_source':
                      await _chooseSource();
                      break;
                    case 'mix_preview':
                      await _toggleMixPreview();
                      break;
                    case 'preview':
                      await _preview();
                      break;
                    case 'apply':
                      await _applyEdit();
                      break;
                    case 'delete':
                      await _deleteDescription();
                      break;
                    case 'change_voice':
                      await _changeVoice();
                      break;
                    case 'reexport':
                      unawaited(_reexport());
                      break;
                    case 'export_srt':
                      await _exportSubtitle('srt');
                      break;
                    case 'export_vtt':
                      await _exportSubtitle('vtt');
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

enum _OutputAction { share, saveDocuments }

class _EditorOperationCancelled implements Exception {
  const _EditorOperationCancelled();
}
