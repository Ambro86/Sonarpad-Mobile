import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/ai_audiodescription_service.dart';
import '../services/app_settings_service.dart';
import '../services/audio_description_project_strings.dart';
import '../services/audio_player_service.dart';
import '../services/media_export_destination_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class AudioDescriptionProjectEditorScreen extends StatefulWidget {
  const AudioDescriptionProjectEditorScreen({super.key});

  @override
  State<AudioDescriptionProjectEditorScreen> createState() =>
      _AudioDescriptionProjectEditorScreenState();
}

class _AudioDescriptionProjectEditorScreenState
    extends State<AudioDescriptionProjectEditorScreen> with WidgetsBindingObserver {
  final _service = AiAudioDescriptionService();
  final _flutterTts = FlutterTts();
  final _audio = AudioPlayerService();

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
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadVoiceLists());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_running && state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
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
    final s = AudioDescriptionProjectStrings.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: false,
      allowedExtensions: const ['json'],
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) return;
    try {
      final project = await _service.loadEditableProject(path);
      final sourceExists = project.sourcePath.isNotEmpty &&
          await File(project.sourcePath).exists();
      if (!mounted) return;
      setState(() {
        _project = project;
        _sourceOverride = sourceExists ? project.sourcePath : null;
        _selectedIndex = 0;
        _editText = project.descriptions.first.text;
        _dirty = false;
        _status = s['ready'];
        _technicalError = null;
        _applyProjectVoiceToUi(project);
      });
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description project editor: open failed error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _technicalError = error.toString();
        _status = s['invalidProject'];
      });
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

  Future<T> _withWakelock<T>(Future<T> Function() action) async {
    bool? previous;
    try {
      previous = await WakelockPlus.enabled;
    } catch (_) {}
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    try {
      return await action();
    } finally {
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
      strings['tooLong']
          .replaceAll('{actual}', error.actualSec.toStringAsFixed(2))
          .replaceAll('{available}', error.availableSec.toStringAsFixed(2));

  Future<void> _preview() async {
    final project = _project;
    if (project == null || _running) return;
    final strings = AudioDescriptionProjectStrings.of(context);
    setState(() {
      _running = true;
      _progress = 0.3;
      _status = strings['working'];
      _technicalError = null;
    });
    try {
      final preview = await _withWakelock(() => _service.previewProjectDescription(
            project: project,
            index: _selectedIndex,
            text: _editText,
          ));
      await _audio.playFile(File(preview.path));
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _status = strings['ready'];
      });
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
    final strings = AudioDescriptionProjectStrings.of(context);
    setState(() {
      _running = true;
      _progress = 0.25;
      _status = strings['working'];
      _technicalError = null;
    });
    try {
      final updated = await _withWakelock(() => _service.applyProjectDescriptionEdit(
            project: project,
            index: _selectedIndex,
            text: _editText,
          ));
      if (!mounted) return;
      setState(() {
        _project = updated;
        _editText = updated.descriptions[_selectedIndex].text;
        _dirty = false;
        _progress = 1;
        _status = strings['applied'];
      });
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
      setState(() => _status = strings['deleteLast']);
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(strings['deleteConfirm']),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings['cancel']),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings['delete']),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      final updated = await _service.deleteProjectDescription(
        project: project,
        index: _selectedIndex,
      );
      if (!mounted) return;
      final newIndex = _selectedIndex.clamp(0, updated.descriptions.length - 1).toInt();
      setState(() {
        _project = updated;
        _selectedIndex = newIndex;
        _editText = updated.descriptions[newIndex].text;
        _dirty = false;
        _status = strings['deleted'];
      });
    } catch (error) {
      if (mounted) setState(() => _technicalError = error.toString());
    }
  }

  Future<void> _changeVoice() async {
    final project = _project;
    if (project == null || _running) return;
    final strings = AudioDescriptionProjectStrings.of(context);
    final speed = project.ttsSpeed;
    final pitch = project.ttsPitch;
    setState(() {
      _running = true;
      _progress = 0;
      _status = strings['working'];
      _technicalError = null;
    });
    try {
      final updated = await _withWakelock(() => _service.changeProjectVoice(
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
          ));
      if (!mounted) return;
      setState(() {
        _project = updated;
        _progress = 1;
        _status = strings['voiceChanged'];
      });
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
      setState(() => _status = strings['unsaved']);
      return;
    }
    var source = _sourceOverride;
    if (source == null || source.isEmpty || !await File(source).exists()) {
      setState(() => _status = strings['sourceMissing']);
      await _chooseSource();
      source = _sourceOverride;
      if (source == null || source.isEmpty) return;
    }
    setState(() {
      _running = true;
      _progress = 0;
      _status = strings['working'];
      _technicalError = null;
    });
    try {
      final result = await _withWakelock(() => _service.reexportEditableProject(
            project: project,
            sourcePathOverride: source,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _progress = progress.value.clamp(0.0, 1.0).toDouble();
                _status = progress.detail == null
                    ? progress.stage
                    : '${progress.stage} ${progress.detail}';
              });
            },
          ));
      if (!mounted) return;
      setState(() {
        _project = result.project;
        _selectedIndex = _selectedIndex.clamp(0, result.project.descriptions.length - 1).toInt();
        _editText = result.project.descriptions[_selectedIndex].text;
        _progress = 1;
        _status = strings['completed'];
      });
      await _showOutputDialog(result.outputPaths);
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
      setState(() => _status = strings['unsaved']);
      return;
    }
    try {
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
        content: Text(strings['completed']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _OutputAction.share),
            child: Text(strings['share']),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _OutputAction.saveDocuments),
            child: Text(strings['saveDocuments']),
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
        await destination.saveInSonarpadDocuments(
          path,
          originalName: p.basename(path),
        );
      }
      if (mounted) showStatusMessage(context, strings['saved']);
    }
  }

  void _cancel() {
    _service.cancel();
    setState(() => _status = AudioDescriptionProjectStrings.of(context)['cancel']);
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

  List<AccessibleOption> _edgeLanguageOptions() => _edgeLanguages
      .map((item) => AccessibleOption(value: item.code, label: item.label))
      .toList();

  List<AccessibleOption> _edgeVoiceOptions() =>
      AppSettingsService.voicesForLanguageFrom(_edgeVoices, _edgeLanguage)
          .map((item) => AccessibleOption(value: item.voice, label: item.label))
          .toList();

  List<AccessibleOption> _systemLanguageOptions() {
    final values = _systemVoices
        .map((item) => item['locale'] ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values
        .map((value) => AccessibleOption(value: value, label: value))
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
    return strings['details']
        .replaceAll('{source}', item.sourceStartSec.toStringAsFixed(2))
        .replaceAll('{start}', item.outputStartSec.toStringAsFixed(2))
        .replaceAll('{end}', item.outputEndSec.toStringAsFixed(2))
        .replaceAll('{duration}', item.ttsDurationSec.toStringAsFixed(2))
        .replaceAll('{mode}', item.extendedPause ? strings['extended'] : strings['normal']);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strings = AudioDescriptionProjectStrings.of(context);
    final project = _project;
    final source = _sourceOverride ?? project?.sourcePath;
    return Scaffold(
      appBar: AppBar(title: Text(strings['title'])),
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
              initialFocusId: 'open_project',
              sections: [
                AccessibleListSection(rows: [
                  AccessibleListRow(
                    id: 'open_project',
                    title: strings['open'],
                    enabled: !_running,
                  ),
                  if (project != null)
                    AccessibleListRow(
                      id: 'project_name',
                      title: strings['project'],
                      value: p.basename(project.projectPath),
                      kind: 'text',
                      accessibilityButtonTrait: false,
                    ),
                  if (project != null)
                    AccessibleListRow(
                      id: 'choose_source',
                      title: strings['chooseSource'],
                      value: source == null || source.isEmpty ? null : p.basename(source),
                      enabled: !_running,
                    ),
                ]),
                if (project != null)
                  AccessibleListSection(rows: [
                    AccessibleListRow(
                      id: 'description',
                      title: strings['description'],
                      kind: 'picker',
                      value: '$_selectedIndex',
                      valueLabel: _descriptionOptions()[_selectedIndex].label,
                      enabled: !_running,
                      options: _descriptionOptions(),
                    ),
                    AccessibleListRow(
                      id: 'description_details',
                      title: strings['description'],
                      value: _detailValue(strings),
                      kind: 'text',
                      accessibilityButtonTrait: false,
                    ),
                    AccessibleListRow(
                      id: 'description_text',
                      title: strings['text'],
                      kind: 'textField',
                      value: _editText,
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'preview',
                      title: strings['preview'],
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'apply',
                      title: strings['apply'],
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'delete',
                      title: strings['delete'],
                      enabled: !_running,
                    ),
                  ]),
                if (project != null)
                  AccessibleListSection(rows: [
                    AccessibleListRow(
                      id: 'tts_engine',
                      title: strings['engine'],
                      kind: 'picker',
                      value: _ttsEngine,
                      valueLabel: _ttsEngine == 'system' ? strings['system'] : strings['edge'],
                      enabled: !_running,
                      options: [
                        AccessibleOption(value: 'edge', label: strings['edge']),
                        AccessibleOption(value: 'system', label: strings['system']),
                      ],
                    ),
                    if (_ttsEngine == 'edge') ...[
                      AccessibleListRow(
                        id: 'edge_language',
                        title: strings['language'],
                        kind: 'picker',
                        value: _edgeLanguage,
                        valueLabel: _edgeLanguage,
                        enabled: !_running,
                        options: _edgeLanguageOptions(),
                      ),
                      AccessibleListRow(
                        id: 'edge_voice',
                        title: strings['voice'],
                        kind: 'picker',
                        value: _edgeVoice,
                        valueLabel: _edgeVoice,
                        enabled: !_running,
                        options: _edgeVoiceOptions(),
                      ),
                    ] else ...[
                      if (_systemLanguageOptions().isNotEmpty)
                        AccessibleListRow(
                          id: 'system_language',
                          title: strings['language'],
                          kind: 'picker',
                          value: _systemLanguage,
                          valueLabel: _systemLanguage,
                          enabled: !_running,
                          options: _systemLanguageOptions(),
                        ),
                      AccessibleListRow(
                        id: 'system_voice',
                        title: strings['voice'],
                        kind: 'picker',
                        value: _systemVoice ?? '',
                        valueLabel: _systemVoice ?? l10n.settingsDefaultVoice,
                        enabled: !_running,
                        options: _systemVoiceOptions(),
                      ),
                    ],
                    AccessibleListRow(
                      id: 'change_voice',
                      title: strings['changeVoice'],
                      enabled: !_running,
                    ),
                  ]),
                if (project != null)
                  AccessibleListSection(rows: [
                    AccessibleListRow(
                      id: 'reexport',
                      title: strings['reexport'],
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'export_srt',
                      title: strings['srt'],
                      enabled: !_running,
                    ),
                    AccessibleListRow(
                      id: 'export_vtt',
                      title: strings['vtt'],
                      enabled: !_running,
                    ),
                    if (_running)
                      AccessibleListRow(
                        id: 'cancel',
                        title: strings['cancel'],
                      ),
                    if (_status.isNotEmpty)
                      AccessibleListRow(
                        id: 'status',
                        title: l10n.info,
                        value: _status,
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
                  ]),
              ],
              onEvent: (event) async {
                final id = event.id;
                if (id == null) return;
                if (event.type == 'picker') {
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
                    case 'choose_source':
                      await _chooseSource();
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
                      await _reexport();
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
