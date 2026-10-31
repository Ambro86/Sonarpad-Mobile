import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_player_service.dart';
import '../services/cloud_file_picker_service.dart';
import '../services/media_export_destination_service.dart';
import '../services/podcast_recorder_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class PodcastRecorderScreen extends StatefulWidget {
  const PodcastRecorderScreen({super.key, this.service});
  final PodcastRecorderService? service;
  @override
  State<PodcastRecorderScreen> createState() => _PodcastRecorderScreenState();
}

class _PodcastRecorderScreenState extends State<PodcastRecorderScreen>
    with WidgetsBindingObserver {
  late final PodcastRecorderService _recorder;
  AudioPlayerService? _player;
  bool _loading = true, _playing = false, _mixing = false, _leaving = false;
  bool _background = false;
  bool _operationActive = false;
  bool _initialized = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorder = widget.service ?? PodcastRecorderService();
    _recorder.addListener(_changed);
    unawaited(_initialize());
  }

  Future<void> _initialize() => _run(() async {
    await _recorder.initialize();
    _initialized = true;
    if (_recorder.name.isEmpty) {
      _recorder.name =
          'Podcast ${DateFormat('yyyy-MM-dd HH-mm').format(DateTime.now())}';
    }
  });

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (_background && _recorder.state == PodcastCaptureState.recording) {
      unawaited(_run(_recorder.pause));
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (!mounted || _operationActive) return;
    _operationActive = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await operation();
    } catch (e) {
      final code = e is PodcastRecorderException ? e.code : 'technical';
      unawaited(
        AppLogger.log(
          'Podcast recorder action failed code=$code type=${e.runtimeType}',
        ),
      );
      if (mounted && code != 'cancelled') {
        setState(() => _error = code);
        showStatusMessage(context, _errorMessage(code));
      }
    } finally {
      _operationActive = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _mixing = false;
        });
      }
    }
  }

  String _errorMessage(String code) {
    final l10n = AppLocalizations.of(context);
    return code == 'permission'
        ? l10n.podcastRecorderPermission
        : l10n.error(l10n.technicalErrorGeneric);
  }

  Future<void> _stopPreview() async {
    await _player?.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<String> _render() async {
    await _stopPreview();
    if (mounted) setState(() => _mixing = true);
    try {
      return await _recorder.render();
    } finally {
      if (mounted) setState(() => _mixing = false);
    }
  }

  Future<void> _preview() async {
    if (_playing) {
      await _stopPreview();
      return;
    }
    await _run(() async {
      final file = await _render();
      if (!mounted) return;
      _player ??= AudioPlayerService();
      await _player!.setUrl(Uri.file(file).toString(), title: _recorder.name);
      if (!mounted) return;
      setState(() => _playing = true);
      unawaited(
        _player!.play().then(
          (_) {
            if (mounted) setState(() => _playing = false);
          },
          onError: (Object e) {
            if (mounted) {
              setState(() => _playing = false);
              showStatusMessage(context, _errorMessage('playback'));
            }
          },
        ),
      );
    });
  }

  String get _fileName {
    final clean = _recorder.name.trim().replaceAll(
      RegExp(r'[\\/:*?"<>|\x00-\x1f]'),
      '_',
    );
    return '${clean.isEmpty ? 'Podcast' : clean}.m4a';
  }

  Future<void> _save() => _run(() async {
    final file = await _render();
    await MediaExportDestinationService().saveInSonarpadDocuments(
      file,
      originalName: _fileName,
    );
    _recorder.saved = true;
    if (mounted) {
      showStatusMessage(
        context,
        AppLocalizations.of(context).exportSavedInSonarpad,
      );
    }
  });

  Future<void> _share() => _run(() async {
    final file = await _render();
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file)],
        fileNameOverrides: [_fileName],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    // A dismissed share sheet is not proof of a saved recording: retain the draft.
  });

  Future<void> _chooseMusic({bool? intro}) => _run(() async {
    await _stopPreview();
    if (!mounted) return;
    final result = await CloudFilePicker.pickFiles(
      context: context,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'opus'],
    );
    if (!mounted) return;
    final path = result?.files.single.path;
    if (path != null) {
      if (intro == null) {
        await _recorder.chooseMusic(path);
      } else {
        await _recorder.chooseJingle(path, intro: intro);
      }
    }
  });

  Future<bool> _confirm(String message) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.no),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.yes),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _leave() async {
    if (_leaving || _loading || _recorder.busy) return;
    _leaving = true;
    try {
      if (_recorder.hasDraft &&
          !_recorder.saved &&
          !await _confirm(AppLocalizations.of(context).podcastRecorderLeave)) {
        return;
      }
      await _stopPreview();
      await _run(_recorder.stop);
      if (mounted) Navigator.of(context).pop();
    } finally {
      _leaving = false;
    }
  }

  AccessibleListRow _volume(
    String id,
    String label,
    double value,
    double max,
    Future<void> Function(double) change,
  ) {
    String percent(double v) => NumberFormat.percentPattern(
      AppLocalizations.of(context).localeName,
    ).format(v);
    return AccessibleListRow(
      id: id,
      title: label,
      kind: 'slider',
      valueLabel: percent(value),
      sliderMin: 0,
      sliderMax: max,
      sliderStep: .1,
      sliderValue: value,
      sliderIncreasedValueLabel: percent((value + .1).clamp(0, max)),
      sliderDecreasedValueLabel: percent((value - .1).clamp(0, max)),
      onValueChanged: (v) async {
        final number = double.tryParse('$v');
        if (number == null || !number.isFinite) return;
        await _stopPreview();
        await change(number.clamp(0, max));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _recorder.state;
    final active =
        state == PodcastCaptureState.recording ||
        state == PodcastCaptureState.paused;
    final ready = state == PodcastCaptureState.ready;
    final waiting = _loading || _recorder.busy;
    final elapsed = _recorder.elapsed;
    final duration =
        '${elapsed.inHours.toString().padLeft(2, '0')}:'
        '${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final rows = <AccessibleListRow>[
      if (waiting) ...[
        AccessibleListRow(id: 'loading', title: l10n.loading, kind: 'text'),
        if (_mixing)
          AccessibleListRow(
            id: 'cancel',
            title: l10n.cancel,
            kind: 'button',
            onActivate: _recorder.cancelRender,
          ),
      ] else if (!_initialized) ...[
        AccessibleListRow(
          id: 'error',
          title: _errorMessage('technical'),
          kind: 'text',
        ),
        AccessibleListRow(
          id: 'retry',
          title: l10n.retry,
          kind: 'button',
          onActivate: _initialize,
        ),
      ] else if (active) ...[
        AccessibleListRow(
          id: 'status',
          title: state == PodcastCaptureState.recording
              ? l10n.recordingInProgressStatus
              : l10n.pause,
          kind: 'header',
        ),
        AccessibleListRow(
          id: 'elapsed',
          title: l10n.sourceDurationValue(duration),
          kind: 'text',
        ),
        AccessibleListRow(
          id: 'pause',
          title: state == PodcastCaptureState.recording
              ? l10n.pauseRecording
              : l10n.resumeRecording,
          kind: 'button',
          onActivate: () => _run(
            state == PodcastCaptureState.recording
                ? _recorder.pause
                : _recorder.resume,
          ),
        ),
        AccessibleListRow(
          id: 'stop',
          title: l10n.stopRecording,
          kind: 'button',
          onActivate: () => _run(_recorder.stop),
        ),
      ] else ...[
        if (_error != null)
          AccessibleListRow(
            id: 'error',
            title: _errorMessage(_error!),
            kind: 'text',
          ),
        AccessibleListRow(
          id: 'intro',
          title: ready
              ? (_recorder.recovered
                    ? l10n.podcastRecorderRecovered
                    : l10n.podcastRecorderReady)
              : l10n.podcastRecorderHint,
          kind: 'text',
        ),
        AccessibleListRow(
          id: 'name',
          title: l10n.newRecordingName,
          kind: 'textField',
          value: _recorder.name,
          onValueChanged: (v) => _recorder.name = '$v',
        ),
        _volume(
          'microphone',
          l10n.podcastRecorderMicVolume,
          _recorder.microphoneVolume,
          2,
          (v) => _recorder.updateMix(microphone: v),
        ),
        AccessibleListRow(
          id: 'music',
          title: l10n.podcastRecorderChooseMusic,
          subtitle: _recorder.musicPath == null
              ? null
              : p.basename(_recorder.musicPath!),
          kind: 'button',
          onActivate: () => _chooseMusic(),
        ),
        if (_recorder.musicPath != null) ...[
          _volume(
            'music-volume',
            l10n.podcastRecorderMusicVolume,
            _recorder.musicVolume,
            1,
            (v) => _recorder.updateMix(music: v),
          ),
          AccessibleListRow(
            id: 'remove-music',
            title: l10n.podcastRecorderRemoveMusic,
            kind: 'button',
            onActivate: () async {
              await _stopPreview();
              await _recorder.updateMix(removeMusic: true);
            },
          ),
        ],
        for (final intro in [true, false]) ...[
          AccessibleListRow(
            id: intro ? 'intro-jingle' : 'outro-jingle',
            title: intro
                ? l10n.podcastRecorderChooseIntro
                : l10n.podcastRecorderChooseOutro,
            kind: 'button',
            onActivate: () => _chooseMusic(intro: intro),
          ),
          if ((intro ? _recorder.introPath : _recorder.outroPath) != null)
            AccessibleListRow(
              id: intro ? 'remove-intro' : 'remove-outro',
              title: intro
                  ? l10n.podcastRecorderRemoveIntro
                  : l10n.podcastRecorderRemoveOutro,
              kind: 'button',
              onActivate: () => _run(() async {
                await _stopPreview();
                await _recorder.chooseJingle(null, intro: intro);
              }),
            ),
        ],
        if (!ready)
          AccessibleListRow(
            id: 'record',
            title: l10n.startRecording,
            kind: 'button',
            finishEditingOnActivate: true,
            onActivate: () => _run(() async {
              await _stopPreview();
              await _recorder.start();
              if (_background) await _recorder.pause();
            }),
          ),
        if (ready) ...[
          AccessibleListRow(
            id: 'preview',
            title: _playing ? l10n.stop : l10n.play,
            kind: 'button',
            onActivate: _preview,
          ),
          AccessibleListRow(
            id: 'save',
            title: l10n.saveInSonarpadDocuments,
            kind: 'button',
            finishEditingOnActivate: true,
            onActivate: _save,
          ),
          AccessibleListRow(
            id: 'share',
            title: l10n.share,
            kind: 'button',
            onActivate: _share,
          ),
          AccessibleListRow(
            id: 'discard',
            title: l10n.deleteItem,
            kind: 'button',
            onActivate: () async {
              if (await _confirm(l10n.podcastRecorderDiscard)) {
                await _run(() async {
                  await _stopPreview();
                  await _recorder.discard();
                });
              }
            },
          ),
        ],
      ],
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: SonarpadAppBar(
          title: Text(l10n.podcastRecorderTitle),
          leading: SonarpadBackButton(onPressed: _leave),
        ),
        body: UniversalAccessibleList(
          key: ValueKey(
            'recorder-${waiting
                ? 'loading'
                : active
                ? 'capture'
                : ready
                ? 'ready'
                : 'setup'}',
          ),
          initialFocusId: rows.first.id,
          sections: [AccessibleListSection(rows: rows)],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder.removeListener(_changed);
    unawaited(_player?.stopAndDispose());
    unawaited(_recorder.close());
    super.dispose();
  }
}
