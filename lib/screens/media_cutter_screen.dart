import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';

enum _MediaCutterDoneAction { share, close }

enum _MediaPartEffect { none, echo, reverb, fadeIn, fadeOut }

class _PartEffectSettings {
  const _PartEffectSettings({
    required this.volumePercent,
    required this.effect,
    required this.effectAmountPercent,
  });

  final int volumePercent;
  final _MediaPartEffect effect;
  final int effectAmountPercent;
}

class _MediaPart {
  const _MediaPart({
    required this.start,
    required this.end,
    this.keep = true,
    this.volumePercent = 100,
    this.effect = _MediaPartEffect.none,
    this.effectAmountPercent = 50,
  });

  final Duration start;
  final Duration end;
  final bool keep;
  final int volumePercent;
  final _MediaPartEffect effect;
  final int effectAmountPercent;

  Duration get duration => end - start;
  double get volumeFactor => volumePercent.clamp(0, 200).toDouble() / 100.0;
  bool get hasAudioChanges =>
      volumePercent != 100 || effect != _MediaPartEffect.none;

  _MediaPart copyWith({
    bool? keep,
    int? volumePercent,
    _MediaPartEffect? effect,
    int? effectAmountPercent,
  }) =>
      _MediaPart(
        start: start,
        end: end,
        keep: keep ?? this.keep,
        volumePercent: volumePercent ?? this.volumePercent,
        effect: effect ?? this.effect,
        effectAmountPercent: effectAmountPercent ?? this.effectAmountPercent,
      );
}

class MediaCutterScreen extends StatefulWidget {
  const MediaCutterScreen({super.key});

  @override
  State<MediaCutterScreen> createState() => _MediaCutterScreenState();
}

class _MediaCutterScreenState extends State<MediaCutterScreen> {
  static const _mediaExtensions = [
    'mp3',
    'm4a',
    'mp4',
    'aac',
    'mkv',
    'avi',
    'mov',
    'm4v',
    'webm',
    'mpg',
    'mpeg',
    'ts',
    'm2ts',
    'mts',
    'wmv',
    'asf',
    'flv',
    'vob',
    '3gp',
    'flac',
    'ogg',
    'opus',
    'wma',
    'aiff',
    'm4b',
    'wav',
  ];

  final _audioPlayer = AudioPlayer();
  final _outputController = TextEditingController();
  VideoPlayerController? _videoController;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  StreamSubscription<bool>? _audioPlayingSubscription;
  Timer? _videoRefreshTimer;

  String _inputPath = '';
  String _displayName = '';
  String _outputDirectory = '';
  bool _isVideo = false;
  bool _showVideoPreview = false;
  bool _loading = false;
  bool _saving = false;
  bool _playing = false;
  int? _previewPartIndex;
  Duration? _previewPartEnd;
  bool _stoppingPartPreview = false;
  bool _skippingDeletedPart = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  List<Duration> _splitPoints = [];
  List<_MediaPart> _parts = [];
  final List<String> _deletedPartHistory = [];
  String? _status;

  @override
  void initState() {
    super.initState();
    _audioPositionSubscription = _audioPlayer.positionStream.listen((position) {
      if (!mounted || _isVideo) return;
      final clamped = _clampPosition(position);
      setState(() => _position = clamped);
      _checkPartPreviewEnd(clamped);
      _checkDeletedPartDuringPlayback(clamped);
    });
    _audioDurationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (!mounted || _isVideo || duration == null) return;
      setState(() {
        _duration = duration;
        _position = _clampPosition(_position);
        _rebuildParts();
      });
    });
    _audioPlayingSubscription = _audioPlayer.playingStream.listen((playing) {
      if (!mounted || _isVideo) return;
      setState(() => _playing = playing);
    });
  }

  @override
  void dispose() {
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioPlayingSubscription?.cancel();
    _videoRefreshTimer?.cancel();
    _videoController?.dispose();
    _audioPlayer.dispose();
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _pickInput() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _mediaExtensions,
    );
    final path =
        result == null || result.files.isEmpty ? null : result.files.first.path;
    if (path == null || path.isEmpty) return;
    if (!await File(path).exists()) {
      if (!mounted) return;
      _showSnack(l10n.fileInaccessible(p.basename(path)));
      return;
    }

    await _loadMedia(path);
    if (_outputDirectory.isEmpty) {
      final outputDirectory = await _defaultOutputDirectory();
      if (!mounted) return;
      setState(() {
        _outputDirectory = outputDirectory;
        _outputController.text = _defaultOutputDirectoryDisplayPath(
          outputDirectory,
        );
      });
    }
  }



  Future<void> _pickOutput() async {
    final l10n = AppLocalizations.of(context);
    final initialDirectory = _outputDirectory.isEmpty
        ? await _defaultOutputDirectory()
        : _outputDirectory;
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.convertMediaOutput,
      initialDirectory: initialDirectory,
    );
    if (path == null || path.isEmpty) return;

    final writable = await _isWritableOutputDirectory(path);
    if (!mounted) return;
    if (!writable) {
      await AppLogger.log(
        'Media cutter: selected output directory is not writable, '
        'path="$path"; using default app folder and native sharing fallback',
      );
      final fallback = await _defaultOutputDirectory();
      if (!mounted) return;
      setState(() {
        _outputDirectory = fallback;
        _outputController.text = _defaultOutputDirectoryDisplayPath(fallback);
      });
      _showSnack(l10n.convertMediaOutputNotWritable);
      return;
    }

    setState(() {
      _outputDirectory = path;
      _outputController.text = _shortPath(path, parentCount: 2);
    });
  }

  Future<bool> _isWritableOutputDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) return false;
      final testFile = File(
        p.join(
          path,
          '.sonarpad_write_test_${DateTime.now().microsecondsSinceEpoch}.tmp',
        ),
      );
      await testFile.writeAsString('test', flush: true);
      if (await testFile.exists()) {
        await testFile.delete();
      }
      return true;
    } catch (error) {
      await AppLogger.log(
        'Media cutter: output directory write test failed path="$path" '
        'error=$error',
      );
      return false;
    }
  }

  Future<void> _loadMedia(String path) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _status = null;
      _inputPath = path;
      _displayName = p.basename(path);
      _isVideo = _isVideoInput(path);
      _showVideoPreview = false;
      _duration = Duration.zero;
      _position = Duration.zero;
      _playing = false;
      _splitPoints = [];
      _parts = [];
      _deletedPartHistory.clear();
      _previewPartIndex = null;
      _previewPartEnd = null;
      _stoppingPartPreview = false;
    });

    try {
      await _audioPlayer.stop();
      _videoRefreshTimer?.cancel();
      final oldVideoController = _videoController;
      _videoController = null;
      if (oldVideoController != null) {
        await oldVideoController.dispose();
      }

      if (_isVideo) {
        final controller = VideoPlayerController.file(
          File(path),
          videoPlayerOptions:
              VideoPlayerOptions(allowBackgroundPlayback: true),
        );
        _videoController = controller;
        await controller.initialize();
        await controller.setVolume(1);
        _videoRefreshTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
          if (!mounted || _videoController == null) return;
          final value = _videoController!.value;
          final clamped = _clampPosition(value.position);
          setState(() {
            _position = clamped;
            _playing = value.isPlaying;
          });
          _checkPartPreviewEnd(clamped);
          _checkDeletedPartDuringPlayback(clamped);
        });
        setState(() {
          _duration = controller.value.duration;
          _position = _clampPosition(controller.value.position);
          _playing = controller.value.isPlaying;
          _rebuildParts();
        });
      } else {
        final duration = await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.file(path),
            tag: MediaItem(
              id: 'media_cutter:${File(path).absolute.path}',
              album: 'Sonarpad',
              title: _displayName.isEmpty ? p.basename(path) : _displayName,
            ),
          ),
        );
        setState(() {
          _duration = duration ?? Duration.zero;
          _position = Duration.zero;
          _playing = false;
          _rebuildParts();
        });
      }
    } catch (error) {
      await AppLogger.log('Media cutter: load failed path="$path" error=$error');
      if (!mounted) return;
      setState(() => _status = l10n.mediaCutterLoadFailed(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (_inputPath.isEmpty || _loading || _saving) return;
    _clearPartPreview();
    try {
      if (_isVideo) {
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) return;
        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          await _setPlaybackVolume(1);
          await controller.play();
        }
        if (!mounted) return;
        setState(() {
          _position = _clampPosition(controller.value.position);
          _playing = controller.value.isPlaying;
        });
      } else {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        } else {
          await _setPlaybackVolume(1);
          await _audioPlayer.play();
        }
      }
    } catch (error) {
      await AppLogger.log('Media cutter: play/pause failed error=$error');
    }
  }

  Future<void> _pause() async {
    if (_isVideo) {
      await _videoController?.pause();
      if (mounted && _videoController != null) {
        setState(() {
          _position = _clampPosition(_videoController!.value.position);
          _playing = _videoController!.value.isPlaying;
        });
      }
    } else {
      await _audioPlayer.pause();
    }
  }

  Future<void> _setPlaybackVolume(double volume) async {
    final clamped = volume.clamp(0.0, 2.0).toDouble();
    if (_isVideo) {
      await _videoController?.setVolume(clamped.clamp(0.0, 1.0).toDouble());
    } else {
      await _audioPlayer.setVolume(clamped);
    }
  }

  Future<void> _seekTo(Duration position, {bool clearPreview = true}) async {
    if (clearPreview) _clearPartPreview();
    final clamped = _clampPosition(position);
    final target = clearPreview ? _skipDeletedPartsForward(clamped) : clamped;
    setState(() => _position = target);
    if (_isVideo) {
      await _videoController?.seekTo(target);
      if (target >= _duration) {
        await _videoController?.pause();
        if (mounted && _videoController != null) {
          setState(() => _playing = _videoController!.value.isPlaying);
        }
      }
    } else {
      await _audioPlayer.seek(target);
      if (target >= _duration) await _audioPlayer.pause();
    }
  }

  Future<void> _playPart(
    int index, {
    double? previewVolumeFactor,
  }) async {
    if (_inputPath.isEmpty || _loading || _saving) return;
    if (index < 0 || index >= _parts.length) return;
    final part = _parts[index];
    if (!part.keep || part.duration <= Duration.zero) {
      if (_previewPartIndex == index) {
        _clearPartPreview();
        await _pause();
      }
      return;
    }

    try {
      await _pause();
      await _setPlaybackVolume(previewVolumeFactor ?? part.volumeFactor);
      await _seekTo(part.start, clearPreview: false);
      if (!mounted) return;
      setState(() {
        _previewPartIndex = index;
        _previewPartEnd = part.end;
        _position = part.start;
      });
      if (_isVideo) {
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) return;
        await controller.play();
        if (!mounted) return;
        setState(() => _playing = controller.value.isPlaying);
      } else {
        await _audioPlayer.play();
      }
    } catch (error) {
      await AppLogger.log('Media cutter: part preview failed error=$error');
    }
  }

  void _checkPartPreviewEnd(Duration position) {
    final end = _previewPartEnd;
    if (end == null || _stoppingPartPreview || position < end) return;
    unawaited(_stopPartPreviewAtEnd(end));
  }

  Future<void> _stopPartPreviewAtEnd(Duration end) async {
    if (_stoppingPartPreview) return;
    _stoppingPartPreview = true;
    try {
      if (_isVideo) {
        final controller = _videoController;
        if (controller != null && controller.value.isInitialized) {
          await controller.pause();
          await controller.seekTo(_clampPosition(end));
        }
      } else {
        await _audioPlayer.pause();
        await _audioPlayer.seek(_clampPosition(end));
      }
      await _setPlaybackVolume(1);
      if (!mounted) return;
      setState(() {
        _position = _clampPosition(end);
        _playing = false;
        _previewPartIndex = null;
        _previewPartEnd = null;
      });
    } finally {
      _stoppingPartPreview = false;
    }
  }

  void _clearPartPreview() {
    if (_previewPartIndex == null && _previewPartEnd == null) return;
    if (!mounted) {
      _previewPartIndex = null;
      _previewPartEnd = null;
      return;
    }
    setState(() {
      _previewPartIndex = null;
      _previewPartEnd = null;
    });
  }

  Future<void> _splitHere() async {
    final l10n = AppLocalizations.of(context);
    if (_inputPath.isEmpty || _duration == Duration.zero) {
      _showSnack(l10n.mediaCutterNoFile);
      return;
    }
    await _pause();
    final point = Duration(seconds: _position.inSeconds);
    if (point <= Duration.zero || point >= _duration) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }
    if (_splitPoints.any((existing) => existing.inSeconds == point.inSeconds)) {
      _showSnack(l10n.mediaCutterSplitAlreadyExists);
      return;
    }
    setState(() {
      _previewPartIndex = null;
      _previewPartEnd = null;
      _splitPoints = [..._splitPoints, point]
        ..sort((a, b) => a.compareTo(b));
      _rebuildParts();
      _status = l10n.mediaCutterSplitAdded(_formatTime(point));
    });
  }

  void _deletePart(int index) {
    if (index < 0 || index >= _parts.length || !_parts[index].keep) return;
    final l10n = AppLocalizations.of(context);
    final part = _parts[index];
    final wasPreviewingThisPart = _previewPartIndex == index;
    if (wasPreviewingThisPart) {
      _previewPartIndex = null;
      _previewPartEnd = null;
      unawaited(_pause());
    }
    setState(() {
      _parts = [
        for (var i = 0; i < _parts.length; i++)
          if (i == index) _parts[i].copyWith(keep: false) else _parts[i],
      ];
      _deletedPartHistory.add(_partKey(part));
      _status = l10n.mediaCutterPartDeleted(
        _formatTime(part.start),
        _formatTime(part.end),
      );
    });
    if (_isInsidePart(_position, part)) {
      unawaited(_seekTo(part.end, clearPreview: true));
    }
  }

  void _restoreDeletedPart() {
    final l10n = AppLocalizations.of(context);
    if (!_hasDeletedParts) {
      _showSnack(l10n.mediaCutterNoDeletedParts);
      return;
    }

    var keyToRestore = _deletedPartHistory.isNotEmpty
        ? _deletedPartHistory.removeLast()
        : null;
    var index = keyToRestore == null
        ? -1
        : _parts.indexWhere((part) => !part.keep && _partKey(part) == keyToRestore);

    while (index == -1 && _deletedPartHistory.isNotEmpty) {
      keyToRestore = _deletedPartHistory.removeLast();
      index = _parts.indexWhere(
        (part) => !part.keep && _partKey(part) == keyToRestore,
      );
    }

    if (index == -1) {
      index = _parts.lastIndexWhere((part) => !part.keep);
    }
    if (index == -1) {
      _showSnack(l10n.mediaCutterNoDeletedParts);
      return;
    }

    final part = _parts[index];
    setState(() {
      _parts = [
        for (var i = 0; i < _parts.length; i++)
          if (i == index) _parts[i].copyWith(keep: true) else _parts[i],
      ];
      _status = l10n.mediaCutterPartRestored(
        _formatTime(part.start),
        _formatTime(part.end),
      );
    });
  }

  Future<void> _showPartEffectsDialog(int index) async {
    if (_saving || index < 0 || index >= _parts.length || !_parts[index].keep) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final part = _parts[index];
    var volumePercent = part.volumePercent;
    var effect = part.effect;
    var effectAmountPercent = part.effectAmountPercent;

    final result = await showDialog<_PartEffectSettings>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.mediaCutterPartEffectsTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.mediaCutterPartEffectsDescription),
                const SizedBox(height: 16),
                Text(l10n.mediaCutterPartVolumeValue(volumePercent)),
                Slider(
                  value: volumePercent.toDouble(),
                  min: 0,
                  max: 200,
                  divisions: 20,
                  label: '$volumePercent%',
                  onChanged: (value) => setDialogState(
                    () => volumePercent = value.round(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_MediaPartEffect>(
                  initialValue: effect,
                  decoration: InputDecoration(
                    labelText: l10n.mediaCutterPartEffect,
                  ),
                  items: [
                    for (final value in _MediaPartEffect.values)
                      DropdownMenuItem<_MediaPartEffect>(
                        value: value,
                        child: Text(_effectLabel(l10n, value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => effect = value);
                  },
                ),
                if (effect != _MediaPartEffect.none) ...[
                  const SizedBox(height: 16),
                  Text(l10n.mediaCutterPartEffectAmountValue(effectAmountPercent)),
                  Slider(
                    value: effectAmountPercent.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: '$effectAmountPercent%',
                    onChanged: (value) => setDialogState(
                      () => effectAmountPercent = value.round(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.mediaCutterPartEffectsSavedOnly),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => unawaited(
                    _playPart(
                      index,
                      previewVolumeFactor:
                          volumePercent.clamp(0, 200).toDouble() / 100.0,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n.mediaCutterPartPreviewAction),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _PartEffectSettings(
                  volumePercent: volumePercent,
                  effect: effect,
                  effectAmountPercent: effectAmountPercent,
                ),
              ),
              child: Text(l10n.ok),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _parts = [
        for (var i = 0; i < _parts.length; i++)
          if (i == index)
            _parts[i].copyWith(
              volumePercent: result.volumePercent,
              effect: result.effect,
              effectAmountPercent: result.effectAmountPercent,
            )
          else
            _parts[i],
      ];
      _status = l10n.mediaCutterPartEffectsApplied(
        _formatTime(part.start),
        _formatTime(part.end),
      );
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_inputPath.isEmpty) {
      _showSnack(l10n.mediaCutterNoFile);
      return;
    }
    final keptParts = _parts.where((part) => part.keep).toList();
    if (keptParts.isEmpty) {
      _showSnack(l10n.mediaCutterNoPartsToSave);
      return;
    }

    setState(() {
      _saving = true;
      _status = l10n.mediaCutterSaving;
    });

    try {
      await _pause();
      var outputDir = _outputDirectory;
      if (outputDir.isEmpty) {
        outputDir = await _defaultOutputDirectory();
        if (!mounted) return;
        setState(() {
          _outputDirectory = outputDir;
          _outputController.text = _defaultOutputDirectoryDisplayPath(outputDir);
        });
      }

      var fallbackToShare = false;
      if (!await _isWritableOutputDirectory(outputDir)) {
        await AppLogger.log(
          'Media cutter: output directory not writable at save time, '
          'path="$outputDir"; using default app folder and native share fallback',
        );
        outputDir = await _defaultOutputDirectory();
        fallbackToShare = true;
        if (!mounted) return;
        setState(() {
          _outputDirectory = outputDir;
          _outputController.text = _defaultOutputDirectoryDisplayPath(outputDir);
        });
        _showSnack(l10n.convertMediaOutputNotWritable);
      }

      var output = await _uniqueOutputPath(outputDir, _inputPath);
      try {
        await _runWithProgressDialog(l10n, () async {
          await _exportKeptParts(keptParts, output);
        });
      } catch (error) {
        final defaultOutputDir = await _defaultOutputDirectory();
        final alreadyUsingDefault = p.equals(
          p.normalize(outputDir),
          p.normalize(defaultOutputDir),
        );
        if (alreadyUsingDefault) rethrow;

        await AppLogger.log(
          'Media cutter: save to selected directory failed, retrying in app '
          'folder and using native share fallback. output="$output" error=$error',
        );
        outputDir = defaultOutputDir;
        output = await _uniqueOutputPath(outputDir, _inputPath);
        fallbackToShare = true;
        if (!mounted) return;
        setState(() {
          _outputDirectory = outputDir;
          _outputController.text = _defaultOutputDirectoryDisplayPath(outputDir);
        });
        _showSnack(l10n.convertMediaOutputNotWritable);
        await _runWithProgressDialog(l10n, () async {
          await _exportKeptParts(keptParts, output);
        });
      }
      if (!mounted) return;
      final message = l10n.mediaCutterSaved(p.basename(output));
      setState(() => _status = message);
      await _showDoneDialog(message, output, forceShare: fallbackToShare);
    } catch (error) {
      await AppLogger.log('Media cutter: save failed error=$error');
      if (!mounted) return;
      setState(() => _status = l10n.mediaCutterReady);
      _showSnack(l10n.mediaCutterSaveFailed(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportKeptParts(
    List<_MediaPart> keptParts,
    String output,
  ) async {
    final input = _inputPath;
    final tempRoot = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
        tempRoot.path,
        'sonarpad_media_cutter_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await workDir.create(recursive: true);
    final ext = _outputExtension(input);
    final segmentPaths = <String>[];

    try {
      for (var i = 0; i < keptParts.length; i++) {
        final part = keptParts[i];
        final segment = p.join(
          workDir.path,
          'segment_${i.toString().padLeft(3, '0')}$ext',
        );
        final args = [
          '-y',
          '-ss',
          _ffmpegTime(part.start),
          '-i',
          input,
          '-t',
          _ffmpegTime(part.duration),
          if (_isVideoInput(input)) ...[
            '-map',
            '0:v:0?',
            '-map',
            '0:a:0?',
          ] else ...[
            '-map',
            '0:a:0?',
            '-vn',
          ],
          '-sn',
          '-dn',
          if (_audioFilterForPart(part) != null) ...[
            '-filter:a',
            _audioFilterForPart(part)!,
          ],
          ..._codecArguments(input),
          '-avoid_negative_ts',
          'make_zero',
          segment,
        ];
        await _runFfmpeg(args, 'segment ${i + 1}/${keptParts.length}');
        segmentPaths.add(segment);
      }

      if (segmentPaths.length == 1) {
        await File(segmentPaths.single).copy(output);
        return;
      }

      final listFile = File(p.join(workDir.path, 'concat.txt'));
      await listFile.writeAsString(
        segmentPaths.map((path) => "file '${path.replaceAll("'", r"'\\''")}'").join('\n'),
      );
      final concatArgs = [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        '-c',
        'copy',
        output,
      ];
      await _runFfmpeg(concatArgs, 'concat');
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  Future<void> _runFfmpeg(List<String> args, String step) async {
    await AppLogger.log(
      'Media cutter ffmpeg $step: args=${args.map(_quoteLogArg).join(' ')}',
    );
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    final logs = await session.getAllLogsAsString() ?? '';
    if (!ReturnCode.isSuccess(returnCode)) {
      await AppLogger.log(
        'Media cutter ffmpeg $step failed returnCode=${returnCode?.getValue()} '
        'logs="${_compactLog(logs)}"',
      );
      throw logs.trim().isEmpty ? 'FFmpeg ${returnCode?.getValue()}' : logs;
    }
  }

  Future<void> _runWithProgressDialog(
    AppLocalizations l10n,
    Future<void> Function() task,
  ) async {
    final taskFuture = task();
    var closeAttached = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        void closeDialog() {
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
        }

        if (!closeAttached) {
          closeAttached = true;
          taskFuture.then(
            (_) => closeDialog(),
            onError: (error, stackTrace) => closeDialog(),
          );
        }

        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.mediaCutterSaving),
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );

    await taskFuture;
  }

  Future<void> _showDoneDialog(
    String message,
    String filePath, {
    bool forceShare = false,
  }) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    if (forceShare) {
      await _shareOutputFile(filePath);
      return;
    }

    final action = await showDialog<_MediaCutterDoneAction>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _MediaCutterDoneAction.share),
            child: Text(l10n.share),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _MediaCutterDoneAction.close),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (!mounted || action != _MediaCutterDoneAction.share) return;
    await _shareOutputFile(filePath);
  }

  Future<void> _shareOutputFile(String filePath) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath)], text: p.basename(filePath)),
    );
  }

  Future<String> _defaultOutputDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(documentsDir.path, 'media'));
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    return mediaDir.path;
  }

  String _defaultOutputDirectoryDisplayPath(String path) {
    if (p.basename(path) == 'media') return ['Sonarpad', 'media'].join('/');
    return _shortPath(path, parentCount: 2);
  }

  String _shortPath(String path, {required int parentCount}) {
    final normalized = p.normalize(path);
    final parts = p.split(normalized);
    final fileName = parts.isEmpty ? path : parts.last;
    final parents = parts.length <= 1
        ? const <String>[]
        : parts
            .sublist(0, parts.length - 1)
            .reversed
            .take(parentCount)
            .toList()
            .reversed;
    return [...parents, fileName].join('/');
  }

  Future<String> _uniqueOutputPath(String outputDir, String inputPath) async {
    final stem = p.basenameWithoutExtension(inputPath);
    final ext = _outputExtension(inputPath);
    var candidate = p.join(outputDir, '${stem}_tagliato$ext');
    var index = 2;
    while (await File(candidate).exists()) {
      candidate = p.join(outputDir, '${stem}_tagliato_$index$ext');
      index += 1;
    }
    return candidate;
  }



  String _outputExtension(String inputPath) {
    if (_isVideoInput(inputPath)) return '.mp4';
    final ext = p.extension(inputPath).toLowerCase();
    return ext.isEmpty ? '.mp3' : ext;
  }


  bool get _hasDeletedParts => _parts.any((part) => !part.keep);

  String _partKey(_MediaPart part) =>
      '${part.start.inMilliseconds}:${part.end.inMilliseconds}';

  bool _isInsidePart(Duration position, _MediaPart part) =>
      position >= part.start && position < part.end;

  _MediaPart? _deletedPartAt(Duration position) {
    for (final part in _parts) {
      if (!part.keep && _isInsidePart(position, part)) return part;
    }
    return null;
  }

  Duration _skipDeletedPartsForward(Duration position) {
    var target = _clampPosition(position);
    for (var i = 0; i < _parts.length; i++) {
      final deletedPart = _deletedPartAt(target);
      if (deletedPart == null) return target;
      target = _clampPosition(deletedPart.end);
    }
    return target;
  }

  void _checkDeletedPartDuringPlayback(Duration position) {
    if (_skippingDeletedPart || _previewPartEnd != null || !_playing) return;
    final target = _skipDeletedPartsForward(position);
    if (target == position) return;
    unawaited(_skipDeletedPartDuringPlayback(target));
  }

  Future<void> _skipDeletedPartDuringPlayback(Duration target) async {
    if (_skippingDeletedPart) return;
    _skippingDeletedPart = true;
    try {
      await _seekTo(target, clearPreview: false);
      if (target >= _duration) await _pause();
    } finally {
      _skippingDeletedPart = false;
    }
  }

  String? _audioFilterForPart(_MediaPart part) {
    final filters = <String>[];
    if (part.volumePercent != 100) {
      filters.add('volume=${part.volumeFactor.toStringAsFixed(3)}');
    }

    final amount = part.effectAmountPercent.clamp(0, 100) / 100.0;
    switch (part.effect) {
      case _MediaPartEffect.none:
        break;
      case _MediaPartEffect.echo:
        final delay = (80 + 220 * amount).round();
        final decay = (0.18 + 0.45 * amount).toStringAsFixed(2);
        filters.add('aecho=0.8:0.88:$delay:$decay');
        break;
      case _MediaPartEffect.reverb:
        final delay1 = (55 + 120 * amount).round();
        final delay2 = (120 + 280 * amount).round();
        final decay1 = (0.16 + 0.28 * amount).toStringAsFixed(2);
        final decay2 = (0.10 + 0.24 * amount).toStringAsFixed(2);
        filters.add('aecho=0.8:0.9:$delay1|$delay2:$decay1|$decay2');
        break;
      case _MediaPartEffect.fadeIn:
        final fade = _fadeDurationSeconds(part.duration);
        filters.add('afade=t=in:st=0:d=$fade');
        break;
      case _MediaPartEffect.fadeOut:
        final fade = _fadeDurationSeconds(part.duration);
        final start = (_seconds(part.duration) - double.parse(fade))
            .clamp(0.0, double.infinity)
            .toStringAsFixed(3);
        filters.add('afade=t=out:st=$start:d=$fade');
        break;
    }

    if (filters.isEmpty) return null;
    return filters.join(',');
  }

  String _fadeDurationSeconds(Duration duration) {
    final seconds = _seconds(duration);
    final fade = seconds <= 0 ? 0.2 : (seconds / 3).clamp(0.2, 3.0);
    return fade.toStringAsFixed(3);
  }

  double _seconds(Duration duration) => duration.inMilliseconds / 1000.0;

  List<String> _codecArguments(String inputPath) {
    if (_isVideoInput(inputPath)) {
      return [
        '-c:v',
        'mpeg4',
        '-q:v',
        '4',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
      ];
    }

    final ext = p.extension(inputPath).toLowerCase().replaceFirst('.', '');
    return switch (ext) {
      'mp3' => ['-c:a', 'libmp3lame', '-b:a', '192k'],
      'm4a' || 'm4b' || 'aac' => ['-c:a', 'aac', '-b:a', '192k'],
      'ogg' => ['-c:a', 'libvorbis', '-q:a', '5'],
      'opus' => ['-c:a', 'libopus', '-b:a', '160k'],
      'flac' => ['-c:a', 'flac'],
      'wav' => ['-c:a', 'pcm_s16le'],
      'aiff' || 'aif' => ['-c:a', 'pcm_s16be'],
      'wma' => ['-c:a', 'wmav2'],
      _ => ['-c:a', 'aac', '-b:a', '192k'],
    };
  }

  void _rebuildParts() {
    if (_duration == Duration.zero) {
      _parts = [];
      return;
    }
    final oldParts = _parts;
    final points = [
      Duration.zero,
      ..._splitPoints.where(
        (point) => point > Duration.zero && point < _duration,
      ),
      _duration,
    ]..sort((a, b) => a.compareTo(b));
    final rebuilt = <_MediaPart>[];
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final previous = oldParts.where(
        (part) => part.start == start && part.end == end,
      );
      rebuilt.add(_MediaPart(
        start: start,
        end: end,
        keep: previous.isEmpty ? true : previous.first.keep,
        volumePercent: previous.isEmpty ? 100 : previous.first.volumePercent,
        effect: previous.isEmpty
            ? _MediaPartEffect.none
            : previous.first.effect,
        effectAmountPercent:
            previous.isEmpty ? 50 : previous.first.effectAmountPercent,
      ));
    }
    _parts = rebuilt;
  }

  Duration _clampPosition(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    if (_duration > Duration.zero && position > _duration) return _duration;
    return position;
  }

  bool _isVideoInput(String path) {
    final extension = p.extension(path).toLowerCase().replaceFirst('.', '');
    return const {
      'mp4',
      'avi',
      'mov',
      'mkv',
      'm4v',
      'webm',
      'mpg',
      'mpeg',
      'ts',
      'm2ts',
      'mts',
      'wmv',
      'asf',
      'flv',
      'vob',
      '3gp',
    }.contains(extension);
  }

  String _effectLabel(AppLocalizations l10n, _MediaPartEffect effect) {
    switch (effect) {
      case _MediaPartEffect.none:
        return l10n.mediaCutterPartEffectNone;
      case _MediaPartEffect.echo:
        return l10n.mediaCutterPartEffectEcho;
      case _MediaPartEffect.reverb:
        return l10n.mediaCutterPartEffectReverb;
      case _MediaPartEffect.fadeIn:
        return l10n.mediaCutterPartEffectFadeIn;
      case _MediaPartEffect.fadeOut:
        return l10n.mediaCutterPartEffectFadeOut;
    }
  }

  String _partDetailsSummary(AppLocalizations l10n, _MediaPart part) {
    final duration = _formatHumanDuration(part.duration);
    final pieces = <String>[];

    if (part.volumePercent != 100) {
      pieces.add(_localizedVolumeSummary(part.volumePercent));
    }
    if (part.effect != _MediaPartEffect.none) {
      pieces.add(_effectLabel(l10n, part.effect));
    }
    pieces.add(_localizedDurationSummary(duration));

    return pieces.join(', ');
  }

  String _localizedVolumeSummary(int percent) {
    final lang = Localizations.localeOf(context).languageCode;
    switch (lang) {
      case 'en':
        return 'volume $percent%';
      case 'fr':
        return 'volume $percent %';
      case 'es':
        return 'volumen $percent%';
      case 'pt':
        return 'volume $percent%';
      case 'pl':
        return 'głośność $percent%';
      case 'cs':
        return 'hlasitost $percent %';
      default:
        return 'volume $percent%';
    }
  }

  String _localizedDurationSummary(String duration) {
    final lang = Localizations.localeOf(context).languageCode;
    switch (lang) {
      case 'en':
        return 'duration $duration';
      case 'fr':
        return 'durée $duration';
      case 'es':
        return 'duración $duration';
      case 'pt':
        return 'duração $duration';
      case 'pl':
        return 'czas trwania $duration';
      case 'cs':
        return 'délka $duration';
      default:
        return 'durata $duration';
    }
  }

  String _formatHumanDuration(Duration duration) {
    var totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0 && duration.inMilliseconds > 0) totalSeconds = 1;
    if (totalSeconds < 0) totalSeconds = 0;

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final units = <String>[];

    if (hours > 0) units.add(_humanDurationUnit('hour', hours));
    if (minutes > 0) units.add(_humanDurationUnit('minute', minutes));
    if (seconds > 0 || units.isEmpty) {
      units.add(_humanDurationUnit('second', seconds));
    }

    return _joinHumanDurationUnits(units);
  }

  String _humanDurationUnit(String unit, int value) {
    final lang = Localizations.localeOf(context).languageCode;
    final word = switch (lang) {
      'en' => switch (unit) {
          'hour' => value == 1 ? 'hour' : 'hours',
          'minute' => value == 1 ? 'minute' : 'minutes',
          _ => value == 1 ? 'second' : 'seconds',
        },
      'fr' => switch (unit) {
          'hour' => value == 1 ? 'heure' : 'heures',
          'minute' => value == 1 ? 'minute' : 'minutes',
          _ => value == 1 ? 'seconde' : 'secondes',
        },
      'es' => switch (unit) {
          'hour' => value == 1 ? 'hora' : 'horas',
          'minute' => value == 1 ? 'minuto' : 'minutos',
          _ => value == 1 ? 'segundo' : 'segundos',
        },
      'pt' => switch (unit) {
          'hour' => value == 1 ? 'hora' : 'horas',
          'minute' => value == 1 ? 'minuto' : 'minutos',
          _ => value == 1 ? 'segundo' : 'segundos',
        },
      'pl' => _polishDurationUnit(unit, value),
      'cs' => _czechDurationUnit(unit, value),
      _ => switch (unit) {
          'hour' => value == 1 ? 'ora' : 'ore',
          'minute' => value == 1 ? 'minuto' : 'minuti',
          _ => value == 1 ? 'secondo' : 'secondi',
        },
    };
    return '$value $word';
  }

  String _polishDurationUnit(String unit, int value) {
    final mod10 = value % 10;
    final mod100 = value % 100;
    final few = mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14);
    switch (unit) {
      case 'hour':
        if (value == 1) return 'godzina';
        return few ? 'godziny' : 'godzin';
      case 'minute':
        if (value == 1) return 'minuta';
        return few ? 'minuty' : 'minut';
      default:
        if (value == 1) return 'sekunda';
        return few ? 'sekundy' : 'sekund';
    }
  }

  String _czechDurationUnit(String unit, int value) {
    final few = value >= 2 && value <= 4;
    switch (unit) {
      case 'hour':
        if (value == 1) return 'hodina';
        return few ? 'hodiny' : 'hodin';
      case 'minute':
        if (value == 1) return 'minuta';
        return few ? 'minuty' : 'minut';
      default:
        if (value == 1) return 'sekunda';
        return few ? 'sekundy' : 'sekund';
    }
  }

  String _joinHumanDurationUnits(List<String> units) {
    if (units.length <= 1) return units.first;
    final lang = Localizations.localeOf(context).languageCode;
    final connector = switch (lang) {
      'en' => ' and ',
      'fr' => ' et ',
      'es' => ' y ',
      'pt' => ' e ',
      'pl' => ' i ',
      'cs' => ' a ',
      _ => ' e ',
    };
    if (units.length == 2) return '${units[0]}$connector${units[1]}';
    return '${units.sublist(0, units.length - 1).join(', ')}$connector${units.last}';
  }

  String _formatTime(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _ffmpegTime(Duration duration) {
    final milliseconds = duration.inMilliseconds;
    final seconds = milliseconds / 1000.0;
    return seconds.toStringAsFixed(3);
  }

  String _quoteLogArg(String value) {
    if (!value.contains(' ')) return value;
    return '"${value.replaceAll('"', r'\"')}"';
  }

  String _compactLog(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 1200) return compact;
    return '${compact.substring(0, 1200)}...';
  }

  void _showSnack(String message) => showStatusMessage(context, message);


  Widget _buildVideoPreview(AppLocalizations l10n) {
    if (!_isVideo || !_showVideoPreview) return const SizedBox();
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox();
    }
    final aspectRatio = controller.value.aspectRatio <= 0
        ? 16 / 9
        : controller.value.aspectRatio;

    return Semantics(
      container: true,
      label: l10n.mediaCutterVideoPreview,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionSlider(AppLocalizations l10n) {
    if (_duration == Duration.zero) return const SizedBox();
    final position = _clampPosition(_position);
    final posSecs = position.inSeconds.toDouble();
    final durSecs =
        _duration.inSeconds.toDouble().clamp(1.0, double.infinity).toDouble();
    final oneSecondForward = _clampPosition(position + const Duration(seconds: 1));
    final oneSecondBack = _clampPosition(position - const Duration(seconds: 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            '${_formatTime(position)} / ${_formatTime(_duration)}',
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('media_cutter_position_slider_semantics'),
          slider: true,
          label: l10n.mediaCutterPosition,
          value: l10n.playbackPositionValue(
            _formatTime(position),
            _formatTime(_duration),
          ),
          increasedValue: _formatTime(oneSecondForward),
          decreasedValue: _formatTime(oneSecondBack),
          onIncrease: () => _seekTo(oneSecondForward),
          onDecrease: () => _seekTo(oneSecondBack),
          hint: l10n.mediaCutterPositionHint,
          child: ExcludeSemantics(
            child: Slider(
              value: posSecs.clamp(0.0, durSecs).toDouble(),
              min: 0,
              max: durSecs,
              divisions: _duration.inSeconds > 0 ? _duration.inSeconds : null,
              onChanged: _saving
                  ? null
                  : (value) => _seekTo(Duration(seconds: value.round())),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartsSection(AppLocalizations l10n) {
    final visibleParts = <MapEntry<int, _MediaPart>>[
      for (var i = 0; i < _parts.length; i++)
        if (_parts[i].keep) MapEntry(i, _parts[i]),
    ];
    if (visibleParts.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.mediaCutterPartsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(l10n.mediaCutterPartsHint),
        const SizedBox(height: 8),
        for (var visibleIndex = 0; visibleIndex < visibleParts.length; visibleIndex++)
          _buildPartTile(
            l10n,
            originalIndex: visibleParts[visibleIndex].key,
            visibleIndex: visibleIndex,
            part: visibleParts[visibleIndex].value,
          ),
      ],
    );
  }

  Widget _buildPartTile(
    AppLocalizations l10n, {
    required int originalIndex,
    required int visibleIndex,
    required _MediaPart part,
  }) {
    final label = l10n.mediaCutterPartLabel(visibleIndex + 1);
    final range = l10n.mediaCutterPartRange(
      _formatTime(part.start),
      _formatTime(part.end),
    );
    final partSummary = _partDetailsSummary(l10n, part);
    final deleteAction = CustomSemanticsAction(
      label: l10n.mediaCutterPartDeleteAction,
    );
    final effectsAction = CustomSemanticsAction(
      label: l10n.mediaCutterPartEffectsAction,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: !_saving,
      label: '$label, $partSummary',
      hint: l10n.mediaCutterPartTapHint,
      onTap: _saving ? null : () => _playPart(originalIndex),
      customSemanticsActions: _saving
          ? const <CustomSemanticsAction, VoidCallback>{}
          : <CustomSemanticsAction, VoidCallback>{
              deleteAction: () => _deletePart(originalIndex),
              effectsAction: () => unawaited(_showPartEffectsDialog(originalIndex)),
            },
      child: ExcludeSemantics(
        child: Card(
          child: ListTile(
            enabled: !_saving,
            onTap: !_saving ? () => _playPart(originalIndex) : null,
            leading: Icon(
              _previewPartIndex == originalIndex
                  ? Icons.volume_up
                  : Icons.play_arrow,
            ),
            title: Text('$label, $partSummary'),
            subtitle: Text(range),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: l10n.mediaCutterPartEffectsAction,
                  icon: const Icon(Icons.tune),
                  onPressed:
                      _saving ? null : () => _showPartEffectsDialog(originalIndex),
                ),
                IconButton(
                  tooltip: l10n.mediaCutterPartDeleteAction,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _saving ? null : () => _deletePart(originalIndex),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canUseMedia = _inputPath.isNotEmpty && !_loading && !_saving;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mediaCutterTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.mediaCutterInstruction1),
            const SizedBox(height: 4),
            Text(l10n.mediaCutterInstruction2),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading || _saving ? null : _pickInput,
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.mediaCutterOpenFile),
            ),
            if (_displayName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.mediaCutterSelectedFile(_displayName)),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _outputController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.convertMediaOutput,
                suffixIcon: IconButton(
                  tooltip: l10n.convertMediaBrowse,
                  onPressed: _loading || _saving ? null : _pickOutput,
                  icon: const Icon(Icons.drive_folder_upload),
                ),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_isVideo && _showVideoPreview) ...[
              const SizedBox(height: 16),
              _buildVideoPreview(l10n),
            ],
            const SizedBox(height: 20),
            _buildPositionSlider(l10n),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: canUseMedia ? _togglePlayback : null,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                  label: Text(_playing ? l10n.pause : l10n.play),
                ),
                if (_isVideo)
                  OutlinedButton.icon(
                    onPressed: canUseMedia
                        ? () => setState(
                              () => _showVideoPreview = !_showVideoPreview,
                            )
                        : null,
                    icon: Icon(
                      _showVideoPreview ? Icons.videocam_off : Icons.videocam,
                    ),
                    label: Text(
                      _showVideoPreview
                          ? l10n.mediaCutterHideVideoPreview
                          : l10n.enableVideo,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: canUseMedia ? _splitHere : null,
                  icon: const Icon(Icons.content_cut),
                  label: Text(l10n.mediaCutterSplit),
                ),
                OutlinedButton.icon(
                  onPressed:
                      canUseMedia && _hasDeletedParts ? _restoreDeletedPart : null,
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.mediaCutterRestoreDeletedPart),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildPartsSection(l10n),
            const SizedBox(height: 20),
            Text(_status ?? l10n.mediaCutterReady),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canUseMedia ? _save : null,
              icon: const Icon(Icons.save_alt),
              label: Text(l10n.mediaCutterSave),
            ),
          ],
        ),
      ),
    );
  }
}
