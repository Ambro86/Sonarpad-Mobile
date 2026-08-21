import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../utils/app_logger.dart';
import '../widgets/universal_accessible_view.dart';

class MediaCutterAddedTrackSettings {
  const MediaCutterAddedTrackSettings({
    required this.path,
    required this.originalVolumePercent,
    required this.newTrackVolumePercent,
    required this.loop,
  });

  final String path;
  final int originalVolumePercent;
  final int newTrackVolumePercent;
  final bool loop;
}

class MediaCutterAddTrackScreen extends StatefulWidget {
  const MediaCutterAddTrackScreen({
    super.key,
    required this.sourcePath,
    required this.sourceHasAudio,
    this.initialSettings,
    required this.playPreviewFile,
    required this.stopPreviewPlayback,
  });

  final String sourcePath;
  final bool sourceHasAudio;
  final MediaCutterAddedTrackSettings? initialSettings;
  final Future<void> Function(String path) playPreviewFile;
  final Future<void> Function() stopPreviewPlayback;

  @override
  State<MediaCutterAddTrackScreen> createState() =>
      _MediaCutterAddTrackScreenState();
}

class _MediaCutterAddTrackScreenState
    extends State<MediaCutterAddTrackScreen> {
  static const _audioExtensions = <String>[
    'mp3',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'opus',
    'wma',
    'aiff',
    'aif',
    'm4b',
    'wav',
  ];

  String? _trackPath;
  double _originalVolume = 100;
  double _newTrackVolume = 30;
  bool _loop = false;
  bool _busy = false;
  File? _previewFile;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSettings;
    if (initial != null) {
      _trackPath = initial.path;
      _originalVolume = initial.originalVolumePercent.toDouble();
      _newTrackVolume = initial.newTrackVolumePercent.toDouble();
      _loop = initial.loop;
    }
  }

  @override
  void dispose() {
    final preview = _previewFile;
    if (preview != null) {
      // The parent Media Cutter owns the single just_audio player and stops it
      // as soon as this route closes. Delay cleanup slightly so iOS never
      // loses a file that may still be attached to that shared player.
      unawaited(Future<void>.delayed(const Duration(seconds: 2), () async {
        try {
          if (await preview.exists()) await preview.delete();
        } catch (_) {
          // Temporary preview cleanup is best effort.
        }
      }));
    }
    super.dispose();
  }

  Future<bool> _containsAudioStream(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final returnCode = await session.getReturnCode();
      final information = session.getMediaInformation();
      if (!ReturnCode.isSuccess(returnCode) || information == null) return false;
      return information.getStreams().any((stream) => stream.getType() == 'audio');
    } catch (error) {
      await AppLogger.log(
        'Media cutter add track: probe failed path="$path" error=$error',
      );
      return false;
    }
  }

  Future<void> _pickTrack() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioExtensions,
    );
    final path = result == null || result.files.isEmpty
        ? null
        : result.files.first.path;
    if (path == null || path.isEmpty) return;
    if (!await File(path).exists() || !await _containsAudioStream(path)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mediaCutterAddedTrackInvalidAudio)),
      );
      return;
    }
    await _stopPreview();
    if (!mounted) return;
    setState(() => _trackPath = path);
  }

  String _percentValue(double value) => '${value.round()}%';

  String _ffmpegVolume(double percent) =>
      (percent / 100).clamp(0.0, 1.0).toStringAsFixed(3);

  Future<void> _stopPreview() async {
    try {
      await widget.stopPreviewPlayback();
    } catch (_) {
      // Best effort: a stale preview must not block selecting another track.
    }
    final previous = _previewFile;
    _previewFile = null;
    if (previous != null) {
      try {
        if (await previous.exists()) await previous.delete();
      } catch (_) {
        // Temporary preview cleanup is best effort.
      }
    }
  }

  Future<void> _preview() async {
    final l10n = AppLocalizations.of(context);
    final trackPath = _trackPath;
    if (trackPath == null || _busy) return;
    setState(() => _busy = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.mediaCutterAddedTrackPreviewPreparing)),
    );
    try {
      await _stopPreview();
      final tempDir = await getTemporaryDirectory();
      final preview = File(
        p.join(
          tempDir.path,
          'sonarpad_added_track_preview_${DateTime.now().microsecondsSinceEpoch}.m4a',
        ),
      );
      final args = <String>['-y'];
      if (widget.sourceHasAudio) {
        args.addAll(['-i', widget.sourcePath]);
      }
      if (_loop) args.addAll(['-stream_loop', '-1']);
      args.addAll(['-i', trackPath]);

      final addedInputIndex = widget.sourceHasAudio ? 1 : 0;
      if (widget.sourceHasAudio) {
        args.addAll([
          '-filter_complex',
          '[0:a:0]volume=${_ffmpegVolume(_originalVolume)},'
              'aresample=44100,aformat=sample_fmts=fltp:sample_rates=44100:'
              'channel_layouts=stereo[orig];'
              '[$addedInputIndex:a:0]volume=${_ffmpegVolume(_newTrackVolume)},'
              'aresample=44100,aformat=sample_fmts=fltp:sample_rates=44100:'
              'channel_layouts=stereo[added];'
              '[orig][added]amix=inputs=2:duration=first:'
              'dropout_transition=0:normalize=0,alimiter=limit=0.98[outa]',
          '-map',
          '[outa]',
        ]);
      } else {
        args.addAll([
          '-filter:a',
          'volume=${_ffmpegVolume(_newTrackVolume)},aresample=44100,'
              'aformat=sample_fmts=fltp:sample_rates=44100:'
              'channel_layouts=stereo',
          '-map',
          '$addedInputIndex:a:0',
        ]);
      }
      args.addAll([
        '-t',
        '15',
        '-vn',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-ar',
        '44100',
        '-ac',
        '2',
        preview.path,
      ]);

      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode) ||
          !await preview.exists() ||
          await preview.length() == 0) {
        final output = await session.getOutput() ?? '';
        await AppLogger.log(
          'Media cutter add track: preview render failed '
          'returnCode=${returnCode?.getValue()} output=$output',
        );
        throw StateError('preview render failed');
      }
      _previewFile = preview;
      await widget.playPreviewFile(preview.path);
    } catch (error) {
      await AppLogger.log('Media cutter add track: preview failed error=$error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mediaCutterAddedTrackPreviewFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    final path = _trackPath;
    if (path == null || _busy) return;
    setState(() => _busy = true);
    await _stopPreview();
    if (!mounted) return;
    Navigator.of(context).pop(
      MediaCutterAddedTrackSettings(
        path: path,
        originalVolumePercent: _originalVolume.round(),
        newTrackVolumePercent: _newTrackVolume.round(),
        loop: _loop,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trackPath = _trackPath;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mediaCutterAddTrack)),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                padding: const EdgeInsets.all(16),
                sections: [
                  AccessibleListSection(
                    rows: [
                      AccessibleListRow(
                        id: 'choose_track',
                        title: l10n.mediaCutterChooseAudioTrack,
                        kind: 'button',
                        enabled: !_busy,
                      ),
                      if (trackPath != null) ...[
                        AccessibleListRow(
                          id: 'selected_track',
                          kind: 'text',
                          title: l10n.mediaCutterAddedTrackSelected(
                            p.basename(trackPath),
                          ),
                        ),
                        AccessibleListRow(
                          id: 'original_volume',
                          title: l10n.mediaCutterOriginalTrackVolume,
                          kind: 'slider',
                          enabled: !_busy,
                          sliderValue: _originalVolume,
                          sliderMin: 0,
                          sliderMax: 100,
                          sliderStep: 1,
                          valueLabel: _percentValue(_originalVolume),
                          sliderIncreasedValueLabel:
                              _percentValue((_originalVolume + 1).clamp(0.0, 100.0).toDouble()),
                          sliderDecreasedValueLabel:
                              _percentValue((_originalVolume - 1).clamp(0.0, 100.0).toDouble()),
                        ),
                        AccessibleListRow(
                          id: 'new_track_volume',
                          title: l10n.mediaCutterNewTrackVolume,
                          kind: 'slider',
                          enabled: !_busy,
                          sliderValue: _newTrackVolume,
                          sliderMin: 0,
                          sliderMax: 100,
                          sliderStep: 1,
                          valueLabel: _percentValue(_newTrackVolume),
                          sliderIncreasedValueLabel:
                              _percentValue((_newTrackVolume + 1).clamp(0.0, 100.0).toDouble()),
                          sliderDecreasedValueLabel:
                              _percentValue((_newTrackVolume - 1).clamp(0.0, 100.0).toDouble()),
                        ),
                        AccessibleListRow(
                          id: 'loop',
                          title: l10n.mediaCutterLoopNewTrack,
                          kind: 'toggle',
                          enabled: !_busy,
                          toggleValue: _loop,
                        ),
                        AccessibleListRow(
                          id: 'preview',
                          title: l10n.mediaCutterPreviewNewTrack,
                          kind: 'button',
                          enabled: !_busy,
                        ),
                        AccessibleListRow(
                          id: 'finalize',
                          title: l10n.mediaCutterFinalizeTrack,
                          kind: 'button',
                          enabled: !_busy,
                        ),
                      ],
                      if (_busy)
                        AccessibleListRow(
                          id: 'busy',
                          kind: 'text',
                          title: l10n.mediaCutterAddedTrackPreviewPreparing,
                        ),
                    ],
                  ),
                ],
                onEvent: (event) async {
                  final id = event.id;
                  if (id == 'choose_track' && event.type == 'activate') {
                    await _pickTrack();
                  } else if (id == 'original_volume' &&
                      event.type == 'slider') {
                    final value = event.value;
                    if (value is num) {
                      setState(() {
                        _originalVolume =
                            value.toDouble().clamp(0.0, 100.0).toDouble();
                      });
                    }
                  } else if (id == 'new_track_volume' &&
                      event.type == 'slider') {
                    final value = event.value;
                    if (value is num) {
                      setState(() {
                        _newTrackVolume =
                            value.toDouble().clamp(0.0, 100.0).toDouble();
                      });
                    }
                  } else if (id == 'loop' && event.type == 'toggle') {
                    setState(() => _loop = event.value == true);
                  } else if (id == 'preview' && event.type == 'activate') {
                    await _preview();
                  } else if (id == 'finalize' && event.type == 'activate') {
                    await _finalize();
                  }
                },
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickTrack,
                    icon: const Icon(Icons.audio_file),
                    label: Text(l10n.mediaCutterChooseAudioTrack),
                  ),
                  if (trackPath != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.mediaCutterAddedTrackSelected(p.basename(trackPath)),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      label: l10n.mediaCutterOriginalTrackVolume,
                      value: _percentValue(_originalVolume),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.mediaCutterOriginalTrackVolume),
                          Slider(
                            value: _originalVolume,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: _percentValue(_originalVolume),
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _originalVolume = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: l10n.mediaCutterNewTrackVolume,
                      value: _percentValue(_newTrackVolume),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.mediaCutterNewTrackVolume),
                          Slider(
                            value: _newTrackVolume,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: _percentValue(_newTrackVolume),
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _newTrackVolume = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.mediaCutterLoopNewTrack),
                      value: _loop,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _loop = value ?? false),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _preview,
                      icon: const Icon(Icons.hearing),
                      label: Text(l10n.mediaCutterPreviewNewTrack),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _finalize,
                      icon: const Icon(Icons.check),
                      label: Text(l10n.mediaCutterFinalizeTrack),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 20),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
      ),
    );
  }
}
