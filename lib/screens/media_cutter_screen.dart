import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';

enum _MediaCutterDoneAction { share, close }

class _MediaPart {
  const _MediaPart({
    required this.start,
    required this.end,
    this.keep = true,
  });

  final Duration start;
  final Duration end;
  final bool keep;

  Duration get duration => end - start;

  _MediaPart copyWith({bool? keep}) => _MediaPart(
        start: start,
        end: end,
        keep: keep ?? this.keep,
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
        final duration = await _audioPlayer.setFilePath(path);
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

  Future<void> _playPart(int index) async {
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
    final deleteAction = CustomSemanticsAction(
      label: l10n.mediaCutterPartDeleteAction,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: !_saving,
      label: '$label, $range',
      hint: l10n.mediaCutterPartTapHint,
      onTap: _saving ? null : () => _playPart(originalIndex),
      customSemanticsActions: _saving
          ? const <CustomSemanticsAction, VoidCallback>{}
          : <CustomSemanticsAction, VoidCallback>{
              deleteAction: () => _deletePart(originalIndex),
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
            title: Text(label),
            subtitle: Text(range),
            trailing: IconButton(
              tooltip: l10n.mediaCutterPartDeleteAction,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : () => _deletePart(originalIndex),
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
