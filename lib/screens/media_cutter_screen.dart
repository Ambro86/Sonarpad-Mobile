import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_localizations.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';

enum _MediaCutterDoneAction { share, close }

enum _MediaCutterMode { guided, advanced }

enum _VideoRotation {
  none,
  right,
  left,
  upsideDown,
}

enum _MediaPartEffect {
  none,
  echo,
  echoRoom,
  echoChamber,
  echoCathedral,
  largeRoom,
  smallRoom,
  bathroom,
  tunnel,
  repeatEcho,
  corridor,
  delay,
  reverb,
  chorus,
  pitchLow,
  pitchVeryLow,
  pitchHigh,
  pitchVeryHigh,
  robot,
  helicopter,
  alien,
  brightVoice,
  darkVoice,
  ghost,
  telephone,
  oldRadio,
  megaphone,
  underwater,
  monster,
  chipmunk,
  dream,
  distortion,
  loFi,
  reverseEcho,
  fadeIn,
  fadeOut,
}

const _effectPreviewMaxDuration = Duration(seconds: 12);
const _effectPreviewMinDuration = Duration(seconds: 2);

class _MediaCutterExportCancelled implements Exception {
  const _MediaCutterExportCancelled();
}

class _MediaCutterExportProgress {
  const _MediaCutterExportProgress({
    required this.fraction,
    required this.label,
  });

  final double fraction;
  final String label;
}

class _MediaCutterExportController {
  _MediaCutterExportController()
      : progress = ValueNotifier<_MediaCutterExportProgress>(
          const _MediaCutterExportProgress(
            fraction: 0,
            label: '',
          ),
        );

  final ValueNotifier<_MediaCutterExportProgress> progress;
  FFmpegSession? currentSession;
  bool cancelled = false;
  bool disposed = false;

  Future<void> cancel() async {
    cancelled = true;
    final session = currentSession;
    if (session != null) {
      await session.cancel();
    } else {
      await FFmpegKit.cancel();
    }
  }

  void dispose() {
    disposed = true;
    progress.dispose();
  }
}

class _PartEffectSettings {
  const _PartEffectSettings({
    required this.volumePercent,
    required this.effect,
    required this.secondaryEffect,
    required this.thirdEffect,
    required this.fourthEffect,
    required this.effectAmountPercent,
  });

  final int volumePercent;
  final _MediaPartEffect effect;
  final _MediaPartEffect secondaryEffect;
  final _MediaPartEffect thirdEffect;
  final _MediaPartEffect fourthEffect;
  final int effectAmountPercent;
}

class _MediaPart {
  const _MediaPart({
    required this.start,
    required this.end,
    this.keep = true,
    this.volumePercent = 100,
    this.effect = _MediaPartEffect.none,
    this.secondaryEffect = _MediaPartEffect.none,
    this.thirdEffect = _MediaPartEffect.none,
    this.fourthEffect = _MediaPartEffect.none,
    this.effectAmountPercent = 50,
  });

  final Duration start;
  final Duration end;
  final bool keep;
  final int volumePercent;
  final _MediaPartEffect effect;
  final _MediaPartEffect secondaryEffect;
  final _MediaPartEffect thirdEffect;
  final _MediaPartEffect fourthEffect;
  final int effectAmountPercent;

  Duration get duration => end - start;
  double get volumeFactor => volumePercent.clamp(0, 200).toDouble() / 100.0;
  bool get hasEffects =>
      effect != _MediaPartEffect.none ||
      secondaryEffect != _MediaPartEffect.none ||
      thirdEffect != _MediaPartEffect.none ||
      fourthEffect != _MediaPartEffect.none;
  bool get hasAudioChanges => volumePercent != 100 || hasEffects;

  _MediaPart copyWith({
    Duration? start,
    Duration? end,
    bool? keep,
    int? volumePercent,
    _MediaPartEffect? effect,
    _MediaPartEffect? secondaryEffect,
    _MediaPartEffect? thirdEffect,
    _MediaPartEffect? fourthEffect,
    int? effectAmountPercent,
  }) =>
      _MediaPart(
        start: start ?? this.start,
        end: end ?? this.end,
        keep: keep ?? this.keep,
        volumePercent: volumePercent ?? this.volumePercent,
        effect: effect ?? this.effect,
        secondaryEffect: secondaryEffect ?? this.secondaryEffect,
        thirdEffect: thirdEffect ?? this.thirdEffect,
        fourthEffect: fourthEffect ?? this.fourthEffect,
        effectAmountPercent: effectAmountPercent ?? this.effectAmountPercent,
      );
}

class MediaCutterScreen extends StatefulWidget {
  const MediaCutterScreen({super.key});

  @override
  State<MediaCutterScreen> createState() => _MediaCutterScreenState();
}

class _MediaCutterScreenState extends State<MediaCutterScreen> {
  static const _mediaCommands = MethodChannel('sonarpad/tts_commands');
  static const _mediaEvents = EventChannel('sonarpad/tts_events');

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

  static const _mediaSeekStepOptions = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  static const _splitBoundaryTolerance = Duration.zero;

  final _audioPlayer = AudioPlayer();
  final _outputController = TextEditingController();
  VideoPlayerController? _videoController;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  StreamSubscription<bool>? _audioPlayingSubscription;
  StreamSubscription<dynamic>? _mediaEventsSubscription;
  Timer? _videoRefreshTimer;

  String _inputPath = '';
  String _displayName = '';
  String _outputDirectory = '';
  bool _isVideo = false;
  bool _showVideoPreview = false;
  _VideoRotation _videoRotation = _VideoRotation.none;
  bool _loading = false;
  bool _saving = false;
  bool _playing = false;
  int? _previewPartIndex;
  Duration? _previewPartEnd;
  Duration? _renderedPreviewStart;
  File? _renderedPreviewFile;
  bool _usingRenderedPreviewSource = false;
  bool _restoringOriginalAudioSource = false;
  bool _stoppingPartPreview = false;
  bool _skippingDeletedPart = false;
  bool _hasUnsavedEdit = false;
  bool _effectPreviewPreparing = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration _mediaSeekStep = const Duration(seconds: 5);
  _MediaCutterMode? _selectedMode;
  Duration? _guidedCutStart;
  Duration? _guidedCutEnd;
  List<Duration> _splitPoints = [];
  List<_MediaPart> _parts = [];
  final List<String> _deletedPartHistory = [];
  String? _status;
  DateTime? _lastSeekLogAt;
  Duration? _lastSeekLogPosition;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      _mediaEventsSubscription =
          _mediaEvents.receiveBroadcastStream().listen((event) {
        if (event == 'toggle' && mounted) {
          unawaited(_handleMagicTapToggle());
        }
      });
    }
    _audioPositionSubscription = _audioPlayer.positionStream.listen((position) {
      if (!mounted || _isVideo) return;
      final renderedStart = _renderedPreviewStart;
      final clamped = _usingRenderedPreviewSource && renderedStart != null
          ? _clampPosition(renderedStart + position)
          : _clampPosition(position);
      setState(() => _position = clamped);
      _checkPartPreviewEnd(clamped);
      _checkDeletedPartDuringPlayback(clamped);
    });
    _audioDurationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (!mounted ||
          _isVideo ||
          duration == null ||
          _usingRenderedPreviewSource ||
          _restoringOriginalAudioSource) {
        return;
      }
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
    if (Platform.isIOS) {
      unawaited(_clearMagicTap());
    }
    unawaited(_mediaEventsSubscription?.cancel() ?? Future<void>.value());
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioPlayingSubscription?.cancel();
    _videoRefreshTimer?.cancel();
    _videoController?.dispose();
    _audioPlayer.dispose();
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _logMediaCutter(String message) async {
    await AppLogger.log('Media cutter: $message');
  }

  String _logDuration(Duration duration) => _formatTime(duration);

  String _logPreciseDuration(Duration duration) {
    final clamped = duration < Duration.zero ? Duration.zero : duration;
    final milliseconds = clamped.inMilliseconds % 1000;
    if (milliseconds == 0) return _formatTime(clamped);
    return '${_formatTime(clamped)}.${milliseconds.toString().padLeft(3, '0')}';
  }

  String _logMaybeDuration(Duration? duration) =>
      duration == null ? 'none' : _logDuration(duration);

  int get _deletedPartCount => _parts.where((part) => !part.keep).length;

  String _logPlaybackState() {
    return 'file="${_displayName.isEmpty ? p.basename(_inputPath) : _displayName}" '
        'type=${_isVideo ? 'video' : 'audio'} '
        'playing=$_playing '
        'original=${_logDuration(_position)} '
        'timeline=${_logDuration(_currentTimelinePosition)} '
        'duration=${_logDuration(_duration)} '
        'timelineDuration=${_logDuration(_editedTimelineDuration)} '
        'parts=${_parts.length} deleted=$_deletedPartCount '
        'previewIndex=${_previewPartIndex ?? 'none'} '
        'previewEnd=${_logMaybeDuration(_previewPartEnd)} '
        'renderedPreview=$_usingRenderedPreviewSource';
  }

  String _logPart(int index, _MediaPart part) {
    final effects = _activeEffects(part).map((effect) => effect.name).join('|');
    return 'index=$index start=${_logDuration(part.start)} '
        'end=${_logDuration(part.end)} '
        'duration=${_logDuration(part.duration)} '
        'keep=${part.keep} volume=${part.volumePercent}% '
        'effects=${effects.isEmpty ? 'none' : effects} '
        'effectAmount=${part.effectAmountPercent}%';
  }

  void _logSeekRequest({
    required String source,
    required Duration requestedTimeline,
    required Duration requestedOriginal,
    required Duration finalOriginal,
    required bool skippedDeletedPart,
  }) {
    final now = DateTime.now();
    final lastTime = _lastSeekLogAt;
    final lastPosition = _lastSeekLogPosition;
    final samePosition = lastPosition != null &&
        (lastPosition.inMilliseconds - finalOriginal.inMilliseconds).abs() < 1000;
    if (lastTime != null &&
        now.difference(lastTime) < const Duration(milliseconds: 700) &&
        samePosition) {
      return;
    }
    _lastSeekLogAt = now;
    _lastSeekLogPosition = finalOriginal;
    unawaited(_logMediaCutter(
      'seek source=$source requestedTimeline=${_logDuration(requestedTimeline)} '
      'requestedOriginal=${_logDuration(requestedOriginal)} '
      'finalOriginal=${_logDuration(finalOriginal)} '
      'skippedDeletedPart=$skippedDeletedPart ${_logPlaybackState()}',
    ));
  }

  Future<void> _pickInput() async {
    final l10n = AppLocalizations.of(context);
    unawaited(_logMediaCutter('pick file requested'));
    if (!await _confirmDiscardUnsavedEdit()) {
      unawaited(_logMediaCutter('pick file cancelled because unsaved edits were kept'));
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _mediaExtensions,
    );
    final path =
        result == null || result.files.isEmpty ? null : result.files.first.path;
    if (path == null || path.isEmpty) {
      unawaited(_logMediaCutter('pick file cancelled by user'));
      return;
    }
    unawaited(_logMediaCutter('file picked path="$path" name="${p.basename(path)}"'));
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
    final selectedPath = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.convertMediaOutput,
      initialDirectory: initialDirectory,
    );
    if (selectedPath == null || selectedPath.isEmpty) return;

    var path = selectedPath;
    try {
      final selectedType = await FileSystemEntity.type(selectedPath);
      if (selectedType == FileSystemEntityType.file) {
        final parent = p.dirname(selectedPath);
        await AppLogger.log(
          'Media cutter: output picker returned a file path; '
          'using parent directory instead selected="$selectedPath" parent="$parent"',
        );
        path = parent;
      }
    } catch (error) {
      await AppLogger.log(
        'Media cutter: output picker path type check failed '
        'path="$selectedPath" error=$error',
      );
    }

    final writable = await _isWritableOutputDirectory(path);
    if (!mounted) return;
    if (!writable) {
      await AppLogger.log(
        'Media cutter: selected output directory is not writable, '
        'path="$path" originalSelection="$selectedPath"; '
        'using default app folder and native sharing fallback',
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
    unawaited(_logMediaCutter(
      'output directory selected path="$path" originalSelection="$selectedPath"',
    ));
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

  Future<VideoPlayerController> _initializeVideoControllerWithRetry(
    String path,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      final controller = VideoPlayerController.file(
        File(path),
        videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
      );
      try {
        await controller.initialize();
        if (attempt > 1) {
          unawaited(_logMediaCutter(
            'video initialize retry succeeded attempt=$attempt path="$path"',
          ));
        }
        return controller;
      } catch (error) {
        lastError = error;
        await AppLogger.log(
          'Media cutter: video initialize failed attempt=$attempt '
          'path="$path" error=$error',
        );
        await controller.dispose().catchError((_) {});
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    }
    throw lastError ?? StateError('Video initialize failed');
  }

  Future<Duration?> _setAudioSourceWithRetry(String path) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        if (attempt > 1) {
          await _audioPlayer.stop();
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
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
        if (attempt > 1) {
          unawaited(_logMediaCutter(
            'audio source retry succeeded attempt=$attempt path="$path"',
          ));
        }
        return duration;
      } catch (error) {
        lastError = error;
        await AppLogger.log(
          'Media cutter: audio source failed attempt=$attempt '
          'path="$path" error=$error',
        );
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    }
    throw lastError ?? StateError('Audio source failed');
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
      _videoRotation = _VideoRotation.none;
      _duration = Duration.zero;
      _position = Duration.zero;
      _playing = false;
      _guidedCutStart = null;
      _guidedCutEnd = null;
      _splitPoints = [];
      _parts = [];
      _deletedPartHistory.clear();
      _previewPartIndex = null;
      _previewPartEnd = null;
      _renderedPreviewStart = null;
      _renderedPreviewFile = null;
      _usingRenderedPreviewSource = false;
      _restoringOriginalAudioSource = false;
      _stoppingPartPreview = false;
      _hasUnsavedEdit = false;
    });

    unawaited(_logMediaCutter(
      'load start path="$path" name="${p.basename(path)}" '
      'type=${_isVideo ? 'video' : 'audio'}',
    ));

    try {
      await _clearMagicTap();
      await _audioPlayer.stop();
      _videoRefreshTimer?.cancel();
      final oldVideoController = _videoController;
      _videoController = null;
      if (oldVideoController != null) {
        await oldVideoController.dispose();
      }

      if (_isVideo) {
        final controller = await _initializeVideoControllerWithRetry(path);
        _videoController = controller;
        await controller.setVolume(1);
        _videoRefreshTimer =
            Timer.periodic(const Duration(milliseconds: 250), (_) {
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
        unawaited(_logMediaCutter(
          'load video ok duration=${_logDuration(_duration)} '
          'parts=${_parts.length} path="$path"',
        ));
      } else {
        final duration = await _setAudioSourceWithRetry(path);
        setState(() {
          _duration = duration ?? Duration.zero;
          _position = Duration.zero;
          _playing = false;
          _rebuildParts();
        });
        unawaited(_logMediaCutter(
          'load audio ok duration=${_logDuration(_duration)} '
          'parts=${_parts.length} path="$path"',
        ));
      }
      await _setupMagicTap();
      unawaited(_logMediaCutter('load completed ${_logPlaybackState()}'));
    } catch (error) {
      await AppLogger.log(
          'Media cutter: load failed path="$path" error=$error');
      if (!mounted) return;
      setState(() => _status = l10n.mediaCutterLoadFailed(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (_inputPath.isEmpty || _loading || _saving) return;
    unawaited(_logMediaCutter('toggle playback requested ${_logPlaybackState()}'));
    _clearPartPreview();
    try {
      if (_isVideo) {
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) return;
        if (controller.value.isPlaying) {
          await controller.pause();
          await _setMagicTapPlaying(false);
          unawaited(_logMediaCutter('video paused by toggle ${_logPlaybackState()}'));
        } else {
          await _seekTo(_editedToOriginalPosition(_currentTimelinePosition),
              clearPreview: false);
          await _setPlaybackVolume(1);
          await controller.play();
          await _setMagicTapPlaying(true);
          unawaited(_logMediaCutter('video playing by toggle ${_logPlaybackState()}'));
        }
        if (!mounted) return;
        setState(() {
          _position = _clampPosition(controller.value.position);
          _playing = controller.value.isPlaying;
        });
      } else {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
          await _setMagicTapPlaying(false);
          unawaited(_logMediaCutter('audio paused by toggle ${_logPlaybackState()}'));
        } else {
          if (_usingRenderedPreviewSource) {
            await _restoreOriginalAudioSource(seekTo: _position);
          }
          await _seekTo(_editedToOriginalPosition(_currentTimelinePosition),
              clearPreview: false);
          await _setPlaybackVolume(1);
          await _audioPlayer.play();
          await _setMagicTapPlaying(true);
          unawaited(_logMediaCutter('audio playing by toggle ${_logPlaybackState()}'));
        }
      }
    } catch (error) {
      await AppLogger.log('Media cutter: play/pause failed error=$error');
    }
  }

  Future<void> _pause() async {
    unawaited(_logMediaCutter('pause requested ${_logPlaybackState()}'));
    if (_isVideo) {
      await _videoController?.pause();
      await _setMagicTapPlaying(false);
      if (mounted && _videoController != null) {
        setState(() {
          _position = _clampPosition(_videoController!.value.position);
          _playing = _videoController!.value.isPlaying;
        });
      }
    } else {
      await _audioPlayer.pause();
      await _setMagicTapPlaying(false);
    }
    unawaited(_logMediaCutter('pause completed ${_logPlaybackState()}'));
  }

  Future<void> _setupMagicTap() async {
    if (!Platform.isIOS || _inputPath.isEmpty) return;
    try {
      await _mediaCommands.invokeMethod(
        'setupMagicTap',
        _displayName.isEmpty ? p.basename(_inputPath) : _displayName,
      );
      await _setMagicTapPlaying(false);
      unawaited(_logMediaCutter('magic tap setup ok title="${_displayName.isEmpty ? p.basename(_inputPath) : _displayName}"'));
    } catch (error) {
      await AppLogger.log('Media cutter: setupMagicTap failed error=$error');
    }
  }

  Future<void> _setMagicTapPlaying(bool playing) async {
    if (!Platform.isIOS) return;
    try {
      await _mediaCommands.invokeMethod('setMagicTapPlaying', playing);
    } catch (error) {
      await AppLogger.log(
        'Media cutter: setMagicTapPlaying failed playing=$playing error=$error',
      );
    }
  }

  Future<void> _clearMagicTap() async {
    if (!Platform.isIOS) return;
    try {
      await _mediaCommands.invokeMethod('clearMagicTap');
    } catch (error) {
      await AppLogger.log('Media cutter: clearMagicTap failed error=$error');
    }
  }

  Future<void> _handleMagicTapToggle() async {
    if (_inputPath.isEmpty || _loading || _saving) return;
    unawaited(_logMediaCutter('magic tap received ${_logPlaybackState()}'));
    final wasPreviewing = _previewPartEnd != null ||
        _previewPartIndex != null ||
        _usingRenderedPreviewSource;
    final wasPlaying = _isVideo
        ? (_videoController?.value.isPlaying ?? false)
        : _audioPlayer.playing;

    if (wasPreviewing) {
      await _pause();
      if (!_isVideo && _usingRenderedPreviewSource) {
        await _restoreOriginalAudioSource(seekTo: _position);
      }
      _clearPartPreview();
      await _setPlaybackVolume(1);
      await _setMagicTapPlaying(false);
      unawaited(_logMediaCutter(
        'magic tap stopped preview wasPlaying=$wasPlaying ${_logPlaybackState()}',
      ));
      if (wasPlaying) return;
    }

    await _togglePlayback();
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
    if (!_isVideo && _usingRenderedPreviewSource) {
      await _restoreOriginalAudioSource(seekTo: position);
    }
    final clamped = _clampPosition(position);
    final target = clearPreview ? _skipDeletedPartsForward(clamped) : clamped;
    if (target != clamped) {
      unawaited(_logMediaCutter(
        'seek skipped deleted part requestedOriginal=${_logDuration(clamped)} '
        'targetOriginal=${_logDuration(target)} clearPreview=$clearPreview',
      ));
    }
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
    unawaited(_logMediaCutter('part preview requested ${_logPart(index, part)}'));
    if (!part.keep || part.duration <= Duration.zero) {
      if (_previewPartIndex == index) {
        _clearPartPreview();
        await _pause();
      }
      return;
    }
    try {
      await _pause();
      if (!_isVideo && _usingRenderedPreviewSource) {
        await _restoreOriginalAudioSource(seekTo: part.start);
      }
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
        await _setMagicTapPlaying(false);
        if (!mounted) return;
        setState(() => _playing = controller.value.isPlaying);
      } else {
        await _audioPlayer.play();
        await _setMagicTapPlaying(false);
      }
      unawaited(_logMediaCutter('part preview playing ${_logPart(index, part)}'));
    } catch (error) {
      await AppLogger.log('Media cutter: part preview failed error=$error');
    }
  }

  Future<void> _playPartEffectsPreview(
    int index, {
    required int volumePercent,
    required _MediaPartEffect effect,
    required _MediaPartEffect secondaryEffect,
    required _MediaPartEffect thirdEffect,
    required _MediaPartEffect fourthEffect,
    required int effectAmountPercent,
  }) async {
    if (_inputPath.isEmpty || _loading || _saving || _effectPreviewPreparing) {
      return;
    }
    if (index < 0 || index >= _parts.length) return;
    final part = _parts[index];
    unawaited(_logMediaCutter(
      'effects preview requested index=$index volume=$volumePercent% '
      'effect=${effect.name} secondary=${secondaryEffect.name} '
      'third=${thirdEffect.name} fourth=${fourthEffect.name} '
      'amount=$effectAmountPercent% part=${_logPart(index, part)}',
    ));
    if (!part.keep || part.duration <= Duration.zero) return;

    final initialPreviewStart = _effectPreviewStartForPart(
      part,
      effect: effect,
      secondaryEffect: secondaryEffect,
      thirdEffect: thirdEffect,
      fourthEffect: fourthEffect,
    );
    final previewStart = _audibleEffectPreviewStart(part, initialPreviewStart);
    final remainingPreviewDuration = part.end - previewStart;
    if (remainingPreviewDuration <= Duration.zero) return;
    final previewDuration = remainingPreviewDuration < _effectPreviewMaxDuration
        ? remainingPreviewDuration
        : _effectPreviewMaxDuration;
    final previewPart = _MediaPart(
      start: previewStart,
      end: previewStart + previewDuration,
      keep: part.keep,
      volumePercent: volumePercent,
      effect: effect,
      secondaryEffect: secondaryEffect,
      thirdEffect: thirdEffect,
      fourthEffect: fourthEffect,
      effectAmountPercent: effectAmountPercent,
    );
    final filter = _audioFilterForPart(previewPart);
    final activeEffects = _activeEffects(previewPart);
    if (filter == null) {
      if (!_isVideo && _usingRenderedPreviewSource) {
        await _restoreOriginalAudioSource(seekTo: previewStart);
      }
      await _playPart(
        index,
        previewVolumeFactor: volumePercent.clamp(0, 200).toDouble() / 100.0,
      );
      return;
    }

    final tempRoot = await getTemporaryDirectory();
    final previewFile = File(
      p.join(
        tempRoot.path,
        'sonarpad_media_cutter_preview_${DateTime.now().millisecondsSinceEpoch}.m4a',
      ),
    );
    try {
      _effectPreviewPreparing = true;
      await _pause();
      if (!_isVideo && _usingRenderedPreviewSource) {
        await _restoreOriginalAudioSource(seekTo: previewStart);
      }
      final args = [
        '-y',
        '-ss',
        _ffmpegTime(previewStart),
        '-i',
        _inputPath,
        '-t',
        _ffmpegTime(previewDuration),
        '-map',
        '0:a:0?',
        '-vn',
        '-sn',
        '-dn',
        '-filter:a',
        filter,
        '-c:a',
        'aac',
        '-b:a',
        '160k',
        previewFile.path,
      ];
      await AppLogger.log(
        'Media cutter preview effects: start=${_ffmpegTime(previewStart)} '
        'duration=${_ffmpegTime(previewDuration)} '
        'activeEffects=${activeEffects.map((effect) => effect.name).join('|')} '
        'args=${args.map(_quoteLogArg).join(' ')}',
      );
      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();
      final logs = await session.getAllLogsAsString() ?? '';
      if (!ReturnCode.isSuccess(returnCode)) {
        throw logs.trim().isEmpty ? 'FFmpeg ${returnCode?.getValue()}' : logs;
      }
      await _setPlaybackVolume(1);
      _usingRenderedPreviewSource = true;
      _renderedPreviewStart = previewStart;
      _renderedPreviewFile = previewFile;
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.file(previewFile.path),
          tag: MediaItem(
            id: 'media_cutter_preview:${previewFile.path}',
            album: 'Sonarpad',
            title: _displayName.isEmpty ? p.basename(_inputPath) : _displayName,
          ),
        ),
      );
      await _audioPlayer.seek(Duration.zero);
      if (!mounted) return;
      setState(() {
        _previewPartIndex = index;
        _previewPartEnd = previewStart + previewDuration;
        _position = previewStart;
        _playing = true;
      });
      await _audioPlayer.play();
      await _setMagicTapPlaying(false);
      await AppLogger.log(
        'Media cutter: effects preview playing '
        'file=${previewFile.path} duration=${_ffmpegTime(previewDuration)}',
      );
    } catch (error) {
      await AppLogger.log('Media cutter: effects preview failed error=$error');
      if (!mounted) return;
      _showSnack(AppLocalizations.of(context).mediaCutterSaveFailed(error));
    } finally {
      _effectPreviewPreparing = false;
      unawaited(
          Future<void>.delayed(const Duration(seconds: 30)).then((_) async {
        if (await previewFile.exists()) {
          await previewFile.delete();
        }
      }));
    }
  }

  Duration _audibleEffectPreviewStart(_MediaPart part, Duration previewStart) {
    final remaining = part.end - previewStart;
    if (remaining >= _effectPreviewMinDuration ||
        part.duration <= _effectPreviewMinDuration) {
      return previewStart;
    }
    return part.end - _effectPreviewMinDuration;
  }

  Duration _effectPreviewStartForPart(
    _MediaPart part, {
    required _MediaPartEffect effect,
    required _MediaPartEffect secondaryEffect,
    required _MediaPartEffect thirdEffect,
    required _MediaPartEffect fourthEffect,
  }) {
    if ((effect == _MediaPartEffect.fadeOut ||
            secondaryEffect == _MediaPartEffect.fadeOut ||
            thirdEffect == _MediaPartEffect.fadeOut ||
            fourthEffect == _MediaPartEffect.fadeOut) &&
        part.duration > _effectPreviewMaxDuration) {
      return part.end - _effectPreviewMaxDuration;
    }
    final current = _position;
    if (current >= part.start && current < part.end) {
      return current;
    }
    return part.start;
  }

  void _checkPartPreviewEnd(Duration position) {
    final end = _previewPartEnd;
    if (end == null || _stoppingPartPreview || position < end) return;
    unawaited(_logMediaCutter(
      'part preview reached end position=${_logDuration(position)} '
      'end=${_logDuration(end)}',
    ));
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
        if (_usingRenderedPreviewSource) {
          await _restoreOriginalAudioSource(seekTo: end);
        } else {
          await _audioPlayer.seek(_clampPosition(end));
        }
      }
      await _setPlaybackVolume(1);
      await _setMagicTapPlaying(false);
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

  Future<void> _restoreOriginalAudioSource({Duration? seekTo}) async {
    if (_isVideo || !_usingRenderedPreviewSource || _inputPath.isEmpty) return;
    _restoringOriginalAudioSource = true;
    final target = _clampPosition(seekTo ?? _position);
    unawaited(_logMediaCutter('restore original audio source target=${_logDuration(target)}'));
    final previewFile = _renderedPreviewFile;
    try {
      await _audioPlayer.stop();
      final duration = await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.file(_inputPath),
          tag: MediaItem(
            id: 'media_cutter:${File(_inputPath).absolute.path}',
            album: 'Sonarpad',
            title: _displayName.isEmpty ? p.basename(_inputPath) : _displayName,
          ),
        ),
      );
      await _audioPlayer.seek(target);
      if (mounted) {
        setState(() {
          _duration = duration ?? _duration;
          _position = target;
        });
      }
    } finally {
      _usingRenderedPreviewSource = false;
      _renderedPreviewStart = null;
      _renderedPreviewFile = null;
      _restoringOriginalAudioSource = false;
      if (previewFile != null) {
        unawaited(previewFile.delete().then((_) {}).catchError((_) {}));
      }
      unawaited(_logMediaCutter('restore original audio source completed ${_logPlaybackState()}'));
    }
  }

  Future<void> _stopRenderedEffectsPreview() async {
    if (!_usingRenderedPreviewSource) {
      await _pause();
      return;
    }
    await _audioPlayer.pause();
    await _restoreOriginalAudioSource(seekTo: _position);
    if (!mounted) return;
    setState(() {
      _playing = false;
      _previewPartIndex = null;
      _previewPartEnd = null;
    });
  }

  void _clearPartPreview() {
    if (_previewPartIndex == null && _previewPartEnd == null) return;
    unawaited(_logMediaCutter(
      'clear part preview index=${_previewPartIndex ?? 'none'} '
      'end=${_logMaybeDuration(_previewPartEnd)}',
    ));
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


  AppLocalizations get _l10n => AppLocalizations.of(context);

  String get _guidedModeTitle => _l10n.mediaCutterGuidedModeTitle;

  String get _guidedModeDescription => _l10n.mediaCutterGuidedModeDescription;

  String get _advancedModeTitle => _l10n.mediaCutterAdvancedModeTitle;

  String get _advancedModeDescription => _l10n.mediaCutterAdvancedModeDescription;

  String get _changeCutModeLabel => _l10n.mediaCutterChangeCutMode;

  String get _guidedSetStartLabel => _l10n.mediaCutterGuidedSetStart;

  String get _guidedSetEndLabel => _l10n.mediaCutterGuidedSetEnd;

  String get _guidedApplyCutLabel => _l10n.mediaCutterGuidedApplyCut;

  String get _guidedListenCutLabel => _l10n.mediaCutterGuidedListenCut;

  String get _guidedModifyCutLabel => _l10n.mediaCutterGuidedModifyCut;

  String get _guidedMoveStartBackOneSecondLabel =>
      _l10n.mediaCutterGuidedMoveStartBackOneSecond;

  String get _guidedMoveStartForwardOneSecondLabel =>
      _l10n.mediaCutterGuidedMoveStartForwardOneSecond;

  String get _guidedMoveEndBackOneSecondLabel =>
      _l10n.mediaCutterGuidedMoveEndBackOneSecond;

  String get _guidedMoveEndForwardOneSecondLabel =>
      _l10n.mediaCutterGuidedMoveEndForwardOneSecond;

  String _guidedCutAdjustedMessage(Duration start, Duration end) =>
      _l10n.mediaCutterGuidedCutAdjusted(
        _formatTime(start),
        _formatTime(end),
      );

  String get _guidedNoCutLabel => _l10n.mediaCutterGuidedNoCut;

  String get _guidedEffectsLabel => _l10n.mediaCutterGuidedEffectsAction;

  String get _guidedEffectsDescription =>
      _l10n.mediaCutterGuidedEffectsDescription;

  String get _guidedFileTapHint => _l10n.mediaCutterGuidedFileTapHint;

  String _guidedStartSetMessage(Duration start) =>
      _l10n.mediaCutterGuidedStartSet(_formatTime(start));

  String _guidedEndSetMessage(Duration start, Duration end) =>
      _l10n.mediaCutterGuidedEndSet(
        _formatTime(start),
        _formatTime(end),
      );

  String _guidedCutAppliedMessage(Duration start, Duration end) =>
      _l10n.mediaCutterGuidedCutApplied(
        _formatTime(start),
        _formatTime(end),
      );

  String get _guidedNeedStartEndMessage =>
      _l10n.mediaCutterGuidedNeedStartEnd;

  String _guidedCutSummary(Duration start, Duration end) =>
      _l10n.mediaCutterGuidedCutSummary(
        _formatTime(start),
        _formatTime(end),
      );

  String _guidedMultipleCutSummary(int count, List<String> cuts) =>
      _l10n.mediaCutterGuidedMultipleCutSummary(count, cuts.join('; '));

  String get _guidedPendingCutExitMessage =>
      _l10n.mediaCutterGuidedPendingCutExitMessage;

  String get _partEditActionLabel => _l10n.mediaCutterPartEditAction;

  String get _partEditDescription => _l10n.mediaCutterPartEditDescription;

  String _partAdjustedMessage(Duration start, Duration end) =>
      _l10n.mediaCutterPartAdjusted(_formatTime(start), _formatTime(end));

  bool get _isGuidedMode => _selectedMode == _MediaCutterMode.guided;

  bool get _hasPendingGuidedCut =>
      _isGuidedMode &&
      _inputPath.isNotEmpty &&
      !_saving &&
      (_guidedCutStart != null || _guidedCutEnd != null);
  String get _guidedPrimaryCutButtonLabel {
    if (_guidedCutStart == null) return _guidedSetStartLabel;
    if (_guidedCutEnd == null) return _guidedSetEndLabel;
    return _guidedApplyCutLabel;
  }

  List<_MediaPart> get _deletedCuts {
    final merged = <_MediaPart>[];
    for (final part in _parts) {
      if (part.keep) continue;
      if (merged.isNotEmpty && merged.last.end == part.start) {
        final previous = merged.removeLast();
        merged.add(previous.copyWith(end: part.end));
      } else {
        merged.add(part);
      }
    }
    return merged;
  }

  String get _guidedCurrentSummary {
    final pendingStart = _guidedCutStart;
    final pendingEnd = _guidedCutEnd;
    if (pendingStart != null && pendingEnd != null) {
      final start = pendingStart <= pendingEnd ? pendingStart : pendingEnd;
      final end = pendingStart <= pendingEnd ? pendingEnd : pendingStart;
      return _guidedCutSummary(start, end);
    }
    final cuts = _deletedCuts;
    if (cuts.isEmpty) return _guidedNoCutLabel;
    final labels = [
      for (final cut in cuts) _guidedCutSummary(cut.start, cut.end),
    ];
    if (labels.length == 1) return labels.first;
    return _guidedMultipleCutSummary(labels.length, labels);
  }

  void _selectMode(_MediaCutterMode mode) {
    setState(() {
      _selectedMode = mode;
      _guidedCutStart = null;
      _guidedCutEnd = null;
    });
    unawaited(_logMediaCutter('mode selected ${mode.name}'));
  }

  Future<bool> _confirmChangeMode() async {
    if (!_hasUnsavedEdit) return true;
    return _confirmDiscardUnsavedEdit();
  }

  Future<void> _changeMode() async {
    if (!await _confirmChangeMode()) return;
    await _pause();
    await _audioPlayer.stop();
    _videoRefreshTimer?.cancel();
    final oldVideoController = _videoController;
    _videoController = null;
    if (oldVideoController != null) {
      await oldVideoController.dispose();
    }
    setState(() {
      _selectedMode = null;
      _inputPath = '';
      _displayName = '';
      _duration = Duration.zero;
      _position = Duration.zero;
      _playing = false;
      _guidedCutStart = null;
      _guidedCutEnd = null;
      _splitPoints = [];
      _parts = [];
      _deletedPartHistory.clear();
      _hasUnsavedEdit = false;
      _status = null;
      _showVideoPreview = false;
      _isVideo = false;
      _videoRotation = _VideoRotation.none;
    });
  }

  Duration _currentOriginalCutPoint() => _clampPosition(_position);

  Future<void> _guidedCutButtonPressed() async {
    if (_inputPath.isEmpty || _duration == Duration.zero) {
      _showSnack(AppLocalizations.of(context).mediaCutterNoFile);
      return;
    }
    final current = _currentOriginalCutPoint();
    if (_guidedCutStart == null) {
      setState(() {
        _guidedCutStart = current;
        _guidedCutEnd = null;
        _status = _guidedStartSetMessage(current);
      });
      _showSnack(_guidedStartSetMessage(current));
      unawaited(_logMediaCutter(
        'guided cut start set start=${_logPreciseDuration(current)} ${_logPlaybackState()}',
      ));
      return;
    }
    if (_guidedCutEnd == null) {
      final start = _guidedCutStart!;
      if ((current.inMilliseconds - start.inMilliseconds).abs() < 250) {
        _showSnack(AppLocalizations.of(context).mediaCutterInvalidSplitPoint);
        return;
      }
      final orderedStart = start <= current ? start : current;
      final orderedEnd = start <= current ? current : start;
      setState(() {
        _guidedCutStart = orderedStart;
        _guidedCutEnd = orderedEnd;
        _status = _guidedEndSetMessage(orderedStart, orderedEnd);
      });
      _showSnack(_guidedEndSetMessage(orderedStart, orderedEnd));
      unawaited(_logMediaCutter(
        'guided cut end set start=${_logPreciseDuration(orderedStart)} '
        'end=${_logPreciseDuration(orderedEnd)} ${_logPlaybackState()}',
      ));
      return;
    }
    await _applyGuidedCut();
  }

  bool _isInsideKeptPartStrict(Duration position) =>
      _keptPartIndexContainingSplitPoint(position) != null;

  bool _isGuidedCutReadyToEdit() =>
      _inputPath.isNotEmpty && _guidedCutStart != null && _guidedCutEnd != null;

  Future<void> _showGuidedModifyCutDialog() async {
    if (!_isGuidedCutReadyToEdit()) {
      _showSnack(_guidedNeedStartEndMessage);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final start = _guidedCutStart;
            final end = _guidedCutEnd;
            final summary = start != null && end != null
                ? _guidedCutSummary(start <= end ? start : end, start <= end ? end : start)
                : _guidedNeedStartEndMessage;
            Future<void> adjust({required bool moveStart, required int direction}) async {
              await _adjustGuidedCutByOneSecond(
                moveStart: moveStart,
                direction: direction,
              );
              if (mounted) setDialogState(() {});
            }

            return AlertDialog(
              title: Text(_guidedModifyCutLabel),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(summary),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: true, direction: -1)),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      label: Text(_guidedMoveStartBackOneSecondLabel),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: true, direction: 1)),
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      label: Text(_guidedMoveStartForwardOneSecondLabel),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: false, direction: -1)),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      label: Text(_guidedMoveEndBackOneSecondLabel),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: false, direction: 1)),
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      label: Text(_guidedMoveEndForwardOneSecondLabel),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => unawaited(_listenGuidedCut()),
                      icon: const Icon(Icons.hearing),
                      label: Text(_guidedListenCutLabel),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(MaterialLocalizations.of(dialogContext).closeButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _adjustGuidedCutByOneSecond({
    required bool moveStart,
    required int direction,
  }) async {
    final l10n = AppLocalizations.of(context);
    final start = _guidedCutStart;
    final end = _guidedCutEnd;
    if (start == null || end == null) {
      _showSnack(_guidedNeedStartEndMessage);
      return;
    }

    final step = Duration(seconds: direction < 0 ? -1 : 1);
    var newStart = start;
    var newEnd = end;
    if (moveStart) {
      newStart += step;
    } else {
      newEnd += step;
    }

    if (newStart < Duration.zero) newStart = Duration.zero;
    if (newEnd > _duration) newEnd = _duration;
    if (newEnd <= newStart ||
        newEnd.inMilliseconds - newStart.inMilliseconds < 250) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      unawaited(_logMediaCutter(
        'guided cut adjust rejected too close moveStart=$moveStart direction=$direction '
        'start=${_logPreciseDuration(start)} end=${_logPreciseDuration(end)} '
        'newStart=${_logPreciseDuration(newStart)} newEnd=${_logPreciseDuration(newEnd)}',
      ));
      return;
    }

    final orderedStart = newStart;
    final orderedEnd = newEnd;
    final validStart = orderedStart == Duration.zero || _isInsideKeptPartStrict(orderedStart);
    final validEnd = orderedEnd == _duration || _isInsideKeptPartStrict(orderedEnd);
    if (!validStart || !validEnd) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      unawaited(_logMediaCutter(
        'guided cut adjust rejected outside kept part moveStart=$moveStart direction=$direction '
        'newStart=${_logPreciseDuration(orderedStart)} newEnd=${_logPreciseDuration(orderedEnd)}',
      ));
      return;
    }

    setState(() {
      _guidedCutStart = orderedStart;
      _guidedCutEnd = orderedEnd;
      _position = moveStart ? orderedStart : orderedEnd;
      _status = _guidedCutAdjustedMessage(orderedStart, orderedEnd);
    });
    await _seekTo(moveStart ? orderedStart : orderedEnd, clearPreview: true);
    _showSnack(_guidedCutAdjustedMessage(orderedStart, orderedEnd));
    unawaited(_logMediaCutter(
      'guided cut adjusted moveStart=$moveStart direction=$direction '
      'start=${_logPreciseDuration(orderedStart)} end=${_logPreciseDuration(orderedEnd)} '
      '${_logPlaybackState()}',
    ));
  }

  Future<void> _showAdvancedPartEditDialog(int index) async {
    if (_saving || index < 0 || index >= _parts.length || !_parts[index].keep) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (index < 0 || index >= _parts.length || !_parts[index].keep) {
              return AlertDialog(
                title: Text(_partEditActionLabel),
                content: Text(AppLocalizations.of(context).mediaCutterInvalidSplitPoint),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(MaterialLocalizations.of(dialogContext).closeButtonLabel),
                  ),
                ],
              );
            }
            final part = _parts[index];
            final summary = AppLocalizations.of(context).mediaCutterPartRange(
              _formatTime(part.start),
              _formatTime(part.end),
            );
            Future<void> adjust({required bool moveStart, required int direction}) async {
              await _adjustAdvancedPartEdgeByOneSecond(
                index: index,
                moveStart: moveStart,
                direction: direction,
              );
              if (mounted) setDialogState(() {});
            }

            return AlertDialog(
              title: Text(_partEditActionLabel),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_partEditDescription),
                    const SizedBox(height: 8),
                    Text(summary),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: true, direction: -1)),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      label: Text(_guidedMoveStartBackOneSecondLabel),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: true, direction: 1)),
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      label: Text(_guidedMoveStartForwardOneSecondLabel),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: false, direction: -1)),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      label: Text(_guidedMoveEndBackOneSecondLabel),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: false, direction: 1)),
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      label: Text(_guidedMoveEndForwardOneSecondLabel),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => unawaited(_playPart(index)),
                      icon: const Icon(Icons.hearing),
                      label: Text(_guidedListenCutLabel),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(MaterialLocalizations.of(dialogContext).closeButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _adjustAdvancedPartEdgeByOneSecond({
    required int index,
    required bool moveStart,
    required int direction,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (index < 0 || index >= _parts.length || !_parts[index].keep) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }
    final currentPart = _parts[index];
    final step = Duration(seconds: direction < 0 ? -1 : 1);
    var newStart = currentPart.start;
    var newEnd = currentPart.end;
    if (moveStart) {
      newStart += step;
    } else {
      newEnd += step;
    }

    if (moveStart && index == 0) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }
    if (!moveStart && index == _parts.length - 1) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }

    final minDuration = const Duration(milliseconds: 250);
    final previousBoundary = index == 0
        ? Duration.zero
        : _parts[index - 1].start + minDuration;
    final nextBoundary = index == _parts.length - 1
        ? _duration
        : _parts[index + 1].end - minDuration;
    if (newStart < previousBoundary) newStart = previousBoundary;
    if (newEnd > nextBoundary) newEnd = nextBoundary;
    if (newStart < Duration.zero) newStart = Duration.zero;
    if (newEnd > _duration) newEnd = _duration;

    if (newEnd <= newStart ||
        newEnd.inMilliseconds - newStart.inMilliseconds < 250) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      unawaited(_logMediaCutter(
        'advanced part edit rejected too close index=$index moveStart=$moveStart direction=$direction '
        'oldStart=${_logPreciseDuration(currentPart.start)} oldEnd=${_logPreciseDuration(currentPart.end)} '
        'newStart=${_logPreciseDuration(newStart)} newEnd=${_logPreciseDuration(newEnd)}',
      ));
      return;
    }

    final updatedParts = [..._parts];
    if (moveStart) {
      if (index > 0) {
        updatedParts[index - 1] = updatedParts[index - 1].copyWith(end: newStart);
      }
      updatedParts[index] = updatedParts[index].copyWith(start: newStart);
    } else {
      updatedParts[index] = updatedParts[index].copyWith(end: newEnd);
      if (index < updatedParts.length - 1) {
        updatedParts[index + 1] = updatedParts[index + 1].copyWith(start: newEnd);
      }
    }

    final editedPart = updatedParts[index];
    setState(() {
      _parts = updatedParts;
      _splitPoints = [
        for (var i = 0; i < updatedParts.length - 1; i++)
          updatedParts[i].end,
      ].where((point) => point > Duration.zero && point < _duration).toList();
      _position = moveStart ? editedPart.start : editedPart.end;
      _hasUnsavedEdit = true;
      _status = _partAdjustedMessage(editedPart.start, editedPart.end);
    });
    await _seekTo(moveStart ? editedPart.start : editedPart.end, clearPreview: true);
    _showSnack(_partAdjustedMessage(editedPart.start, editedPart.end));
    unawaited(_logMediaCutter(
      'advanced part edited index=$index moveStart=$moveStart direction=$direction '
      'start=${_logPreciseDuration(editedPart.start)} end=${_logPreciseDuration(editedPart.end)} '
      'splitPoints=${_splitPoints.map(_logPreciseDuration).join('|')} parts=${_parts.length} deleted=$_deletedPartCount',
    ));
  }

  Future<void> _listenGuidedCut() async {
    final start = _guidedCutStart;
    final end = _guidedCutEnd;
    if (start == null || end == null) {
      _showSnack(_guidedNeedStartEndMessage);
      return;
    }
    if (end <= start) {
      _showSnack(AppLocalizations.of(context).mediaCutterInvalidSplitPoint);
      return;
    }
    unawaited(_logMediaCutter(
      'guided listen cut start=${_logPreciseDuration(start)} '
      'end=${_logPreciseDuration(end)} ${_logPlaybackState()}',
    ));
    try {
      await _pause();
      if (!_isVideo && _usingRenderedPreviewSource) {
        await _restoreOriginalAudioSource(seekTo: start);
      }
      await _setPlaybackVolume(1);
      await _seekTo(start, clearPreview: false);
      if (!mounted) return;
      setState(() {
        _previewPartIndex = null;
        _previewPartEnd = end;
        _position = start;
      });
      if (_isVideo) {
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) return;
        await controller.play();
        await _setMagicTapPlaying(false);
        if (mounted) setState(() => _playing = controller.value.isPlaying);
      } else {
        await _audioPlayer.play();
        await _setMagicTapPlaying(false);
      }
    } catch (error) {
      await AppLogger.log('Media cutter: guided listen cut failed error=$error');
      if (mounted) _showSnack(AppLocalizations.of(context).mediaCutterSaveFailed(error));
    }
  }

  void _addSplitPointIfNeeded(Duration point) {
    if (point <= Duration.zero || point >= _duration) return;
    if (_matchingExistingSplitPoint(point) != null) return;
    _splitPoints = [..._splitPoints, point]..sort((a, b) => a.compareTo(b));
  }

  Future<void> _applyGuidedCut() async {
    final l10n = AppLocalizations.of(context);
    final start = _guidedCutStart;
    final end = _guidedCutEnd;
    if (start == null || end == null) {
      _showSnack(_guidedNeedStartEndMessage);
      return;
    }
    final cutStart = start <= end ? start : end;
    final cutEnd = start <= end ? end : start;
    if (cutStart < Duration.zero || cutEnd > _duration || cutEnd <= cutStart) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }
    await _pause();
    _clearPartPreview();
    if (!_isVideo && _usingRenderedPreviewSource) {
      await _restoreOriginalAudioSource(seekTo: cutStart);
    }
    setState(() {
      _addSplitPointIfNeeded(cutStart);
      _addSplitPointIfNeeded(cutEnd);
      _rebuildParts();
      final updatedParts = <_MediaPart>[];
      for (final part in _parts) {
        final overlapsCut = part.end > cutStart && part.start < cutEnd;
        updatedParts.add(overlapsCut ? part.copyWith(keep: false) : part);
      }
      _parts = updatedParts;
      _deletedPartHistory.add('$cutStart:$cutEnd');
      _guidedCutStart = null;
      _guidedCutEnd = null;
      _hasUnsavedEdit = true;
      _status = _guidedCutAppliedMessage(cutStart, cutEnd);
    });
    _showSnack(_guidedCutAppliedMessage(cutStart, cutEnd));
    unawaited(_logMediaCutter(
      'guided cut applied start=${_logPreciseDuration(cutStart)} '
      'end=${_logPreciseDuration(cutEnd)} splitPoints=${_splitPoints.map(_logPreciseDuration).join('|')} '
      'parts=${_parts.length} deleted=$_deletedPartCount',
    ));
  }

  Future<void> _showGuidedEffectsDialog() async {
    final index = _parts.indexWhere((part) => part.keep);
    if (index < 0) return;
    await _showPartEffectsDialog(index, applyToWholeFile: true);
    if (!mounted || index >= _parts.length) return;
    final source = _parts[index];
    unawaited(_logMediaCutter(
      'guided effects applied to whole file volume=${source.volumePercent}% '
      'effect=${source.effect.name} secondary=${source.secondaryEffect.name} '
      'third=${source.thirdEffect.name} fourth=${source.fourthEffect.name} '
      'amount=${source.effectAmountPercent}%',
    ));
  }

  Duration _splitPointFromPosition(Duration position) {
    final milliseconds = position.inMilliseconds;
    return Duration(milliseconds: milliseconds < 0 ? 0 : milliseconds);
  }

  Duration? _matchingExistingSplitPoint(Duration point) {
    for (final existing in _splitPoints) {
      final distance =
          (existing.inMilliseconds - point.inMilliseconds).abs();
      if (distance <= _splitBoundaryTolerance.inMilliseconds) {
        return existing;
      }
    }
    return null;
  }

  int? _keptPartIndexContainingSplitPoint(Duration point) {
    for (var i = 0; i < _parts.length; i++) {
      final part = _parts[i];
      if (!part.keep) continue;
      if (point > part.start && point < part.end) {
        return i;
      }
    }
    return null;
  }

  int _visiblePartNumberForStart(Duration start) {
    var visibleNumber = 0;
    for (final part in _parts) {
      if (!part.keep) continue;
      visibleNumber++;
      if ((part.start.inMilliseconds - start.inMilliseconds).abs() < 2) {
        return visibleNumber;
      }
    }
    return visibleNumber == 0 ? 1 : visibleNumber;
  }

  String _splitAddedAnnouncement(int partNumber) =>
      _l10n.mediaCutterSplitAddedAnnouncement(partNumber);

  Future<void> _splitHere() async {
    final l10n = AppLocalizations.of(context);
    unawaited(_logMediaCutter('split requested ${_logPlaybackState()}'));
    if (_inputPath.isEmpty || _duration == Duration.zero) {
      _showSnack(l10n.mediaCutterNoFile);
      return;
    }
    await _pause();
    _clearPartPreview();
    if (!_isVideo && _usingRenderedPreviewSource) {
      await _restoreOriginalAudioSource(seekTo: _position);
    }
    var point = _splitPointFromPosition(_position);
    if (point <= Duration.zero || point >= _duration) {
      unawaited(_logMediaCutter(
        'split rejected invalid point=${_logPreciseDuration(point)} '
        'duration=${_logPreciseDuration(_duration)}',
      ));
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }
    final existing = _matchingExistingSplitPoint(point);
    if (existing != null) {
      unawaited(_logMediaCutter(
        'split rejected exact duplicate point=${_logPreciseDuration(point)} '
        'existing=${_logPreciseDuration(existing)} '
        'splitPoints=${_splitPoints.map(_logPreciseDuration).join('|')}',
      ));
      _showSnack(l10n.mediaCutterSplitAlreadyExists);
      return;
    }
    final targetPartIndex = _keptPartIndexContainingSplitPoint(point);
    if (targetPartIndex == null) {
      unawaited(_logMediaCutter(
        'split rejected not inside kept part point=${_logPreciseDuration(point)} '
        'splitPoints=${_splitPoints.map(_logPreciseDuration).join('|')} '
        'parts=${_parts.asMap().entries.map((entry) => _logPart(entry.key, entry.value)).join(' || ')}',
      ));
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }
    final targetPart = _parts[targetPartIndex];
    unawaited(_logMediaCutter(
      'split target part index=$targetPartIndex '
      'start=${_logPreciseDuration(targetPart.start)} '
      'end=${_logPreciseDuration(targetPart.end)} '
      'duration=${_logPreciseDuration(targetPart.duration)}',
    ));
    var addedVisiblePartNumber = 1;
    setState(() {
      _previewPartIndex = null;
      _previewPartEnd = null;
      _splitPoints = [..._splitPoints, point]..sort((a, b) => a.compareTo(b));
      _rebuildParts();
      _hasUnsavedEdit = true;
      addedVisiblePartNumber = _visiblePartNumberForStart(point);
      _status = l10n.mediaCutterSplitAdded(_formatTime(point));
    });
    final announcement = _splitAddedAnnouncement(addedVisiblePartNumber);
    _showSnack(announcement);
    unawaited(_logMediaCutter(
      'split added point=${_logPreciseDuration(point)} '
      'addedVisiblePart=$addedVisiblePartNumber '
      'splitPoints=${_splitPoints.map(_logPreciseDuration).join('|')} '
      'parts=${_parts.length} deleted=$_deletedPartCount',
    ));
  }

  void _deletePart(int index) {
    if (index < 0 || index >= _parts.length || !_parts[index].keep) return;
    final l10n = AppLocalizations.of(context);
    final part = _parts[index];
    unawaited(_logMediaCutter('delete part requested ${_logPart(index, part)}'));
    final wasPreviewingThisPart = _previewPartIndex == index;
    if (wasPreviewingThisPart) {
      _previewPartIndex = null;
      _previewPartEnd = null;
      unawaited(_pause());
    }
    final message = l10n.mediaCutterPartDeleted(
      _formatTime(part.start),
      _formatTime(part.end),
    );
    setState(() {
      _parts = [
        for (var i = 0; i < _parts.length; i++)
          if (i == index) _parts[i].copyWith(keep: false) else _parts[i],
      ];
      _deletedPartHistory.add(_partKey(part));
      _hasUnsavedEdit = true;
      _status = message;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showSnack(message);
    });
    unawaited(_logMediaCutter(
      'delete part completed ${_logPart(index, part.copyWith(keep: false))} '
      'parts=${_parts.length} deleted=$_deletedPartCount',
    ));
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
        : _parts
            .indexWhere((part) => !part.keep && _partKey(part) == keyToRestore);

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
    unawaited(_logMediaCutter('restore deleted part requested ${_logPart(index, part)}'));
    setState(() {
      _parts = [
        for (var i = 0; i < _parts.length; i++)
          if (i == index) _parts[i].copyWith(keep: true) else _parts[i],
      ];
      _hasUnsavedEdit = true;
      _status = l10n.mediaCutterPartRestored(
        _formatTime(part.start),
        _formatTime(part.end),
      );
    });
    unawaited(_logMediaCutter(
      'restore deleted part completed index=$index parts=${_parts.length} '
      'deleted=$_deletedPartCount',
    ));
  }

  Widget _buildEffectPicker(
    AppLocalizations l10n, {
    required _MediaPartEffect value,
    required String label,
    required ValueChanged<_MediaPartEffect> onChanged,
  }) {
    final selectedLabel = _effectLabel(l10n, value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: '$label, $selectedLabel',
          child: ExcludeSemantics(
            child: OutlinedButton(
              onPressed: () async {
                final selected = await _showEffectPickerDialog(
                  l10n,
                  title: label,
                  current: value,
                );
                if (selected == null) return;
                onChanged(selected);
              },
              child: Row(
                children: [
                  Expanded(child: Text(selectedLabel)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<_MediaPartEffect?> _showEffectPickerDialog(
    AppLocalizations l10n, {
    required String title,
    required _MediaPartEffect current,
  }) {
    return showDialog<_MediaPartEffect>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _MediaPartEffect.values.length,
            itemBuilder: (context, index) {
              final effect = _MediaPartEffect.values[index];
              final selected = effect == current;
              final effectLabel = _effectLabel(l10n, effect);
              return Semantics(
                selected: selected,
                button: true,
                child: ListTile(
                  selected: selected,
                  title: Text(effectLabel),
                  trailing: selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(dialogContext, effect),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  List<_MediaPartEffect> _normalizedEffectSlots(
    List<_MediaPartEffect> effects,
  ) {
    final active = [
      for (final effect in effects)
        if (effect != _MediaPartEffect.none) effect,
    ];
    while (active.length < 4) {
      active.add(_MediaPartEffect.none);
    }
    return active.take(4).toList();
  }



  Future<void> _showPartEffectsDialog(int index, {bool applyToWholeFile = false}) async {
    if (_saving || index < 0 || index >= _parts.length || !_parts[index].keep) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final part = _parts[index];
    var volumePercent = part.volumePercent;
    var effect = part.effect;
    var secondaryEffect = part.secondaryEffect;
    var thirdEffect = part.thirdEffect;
    var fourthEffect = part.fourthEffect;
    var effectAmountPercent = part.effectAmountPercent;

    void normalizeDialogEffects(List<_MediaPartEffect> slots) {
      final normalized = _normalizedEffectSlots(slots);
      effect = normalized[0];
      secondaryEffect = normalized[1];
      thirdEffect = normalized[2];
      fourthEffect = normalized[3];
    }

    normalizeDialogEffects([effect, secondaryEffect, thirdEffect, fourthEffect]);

    final result = await showDialog<_PartEffectSettings>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(applyToWholeFile ? _guidedEffectsLabel : l10n.mediaCutterPartEffectsTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(applyToWholeFile ? _guidedEffectsDescription : l10n.mediaCutterPartEffectsDescription),
                const SizedBox(height: 16),
                ExcludeSemantics(
                  child: Text(l10n.mediaCutterPartVolumeValue(volumePercent)),
                ),
                Semantics(
                  slider: true,
                  label: l10n.mediaCutterPartVolumeValue(volumePercent),
                  value: '$volumePercent%',
                  increasedValue: '${(volumePercent + 10).clamp(0, 200)}%',
                  decreasedValue: '${(volumePercent - 10).clamp(0, 200)}%',
                  onIncrease: () => setDialogState(
                    () => volumePercent = (volumePercent + 10).clamp(0, 200),
                  ),
                  onDecrease: () => setDialogState(
                    () => volumePercent = (volumePercent - 10).clamp(0, 200),
                  ),
                  child: ExcludeSemantics(
                    child: Slider(
                      value: volumePercent.toDouble(),
                      min: 0,
                      max: 200,
                      divisions: 20,
                      label: '$volumePercent%',
                      onChanged: (value) => setDialogState(
                        () => volumePercent = value.round(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final currentEffects = [
                      effect,
                      secondaryEffect,
                      thirdEffect,
                      fourthEffect,
                    ];
                    final activeCount = currentEffects
                        .where((item) => item != _MediaPartEffect.none)
                        .length;
                    final visibleSlots = activeCount == 0 ? 1 : activeCount;
                    final children = <Widget>[];

                    void setEffectSlot(int slot, _MediaPartEffect value) {
                      final slots = [
                        effect,
                        secondaryEffect,
                        thirdEffect,
                        fourthEffect,
                      ];
                      slots[slot] = value;
                      normalizeDialogEffects(slots);
                    }

                    for (var slot = 0; slot < visibleSlots; slot++) {
                      if (children.isNotEmpty) {
                        children.add(const SizedBox(height: 12));
                      }
                      children.add(_buildEffectPicker(
                        l10n,
                        value: currentEffects[slot],
                        label: _effectSlotLabel(l10n, slot + 1),
                        onChanged: (value) => setDialogState(
                          () => setEffectSlot(slot, value),
                        ),
                      ));
                    }

                    if (activeCount > 0 && activeCount < 4) {
                      children.add(const SizedBox(height: 12));
                      children.add(OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await _showEffectPickerDialog(
                            l10n,
                            title: '${l10n.add} ${_effectSlotLabel(l10n, activeCount + 1)}',
                            current: _MediaPartEffect.none,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          if (selected == null || selected == _MediaPartEffect.none) {
                            return;
                          }
                          setDialogState(() => setEffectSlot(activeCount, selected));
                        },
                        icon: const Icon(Icons.add),
                        label: Text('${l10n.add} ${_effectSlotLabel(l10n, activeCount + 1)}'),
                      ));
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    );
                  },
                ),
                if (effect != _MediaPartEffect.none ||
                    secondaryEffect != _MediaPartEffect.none ||
                    thirdEffect != _MediaPartEffect.none ||
                    fourthEffect != _MediaPartEffect.none) ...[
                  const SizedBox(height: 16),
                  ExcludeSemantics(
                    child: Text(
                      l10n.mediaCutterPartEffectAmountValue(
                        effectAmountPercent,
                      ),
                    ),
                  ),
                  Semantics(
                    slider: true,
                    label: l10n.mediaCutterPartEffectAmountValue(
                      effectAmountPercent,
                    ),
                    value: '$effectAmountPercent%',
                    increasedValue:
                        '${(effectAmountPercent + 10).clamp(0, 100)}%',
                    decreasedValue:
                        '${(effectAmountPercent - 10).clamp(0, 100)}%',
                    onIncrease: () => setDialogState(
                      () => effectAmountPercent =
                          (effectAmountPercent + 10).clamp(0, 100),
                    ),
                    onDecrease: () => setDialogState(
                      () => effectAmountPercent =
                          (effectAmountPercent - 10).clamp(0, 100),
                    ),
                    child: ExcludeSemantics(
                      child: Slider(
                        value: effectAmountPercent.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '$effectAmountPercent%',
                        onChanged: (value) => setDialogState(
                          () => effectAmountPercent = value.round(),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => unawaited(
                    _playPartEffectsPreview(
                      index,
                      volumePercent: volumePercent,
                      effect: effect,
                      secondaryEffect: secondaryEffect,
                      thirdEffect: thirdEffect,
                      fourthEffect: fourthEffect,
                      effectAmountPercent: effectAmountPercent,
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
              onPressed: () {
                unawaited(_stopRenderedEffectsPreview());
                Navigator.pop(dialogContext);
              },
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                unawaited(_stopRenderedEffectsPreview());
                normalizeDialogEffects([
                  effect,
                  secondaryEffect,
                  thirdEffect,
                  fourthEffect,
                ]);
                Navigator.pop(
                  dialogContext,
                  _PartEffectSettings(
                    volumePercent: volumePercent,
                    effect: effect,
                    secondaryEffect: secondaryEffect,
                    thirdEffect: thirdEffect,
                    fourthEffect: fourthEffect,
                    effectAmountPercent: effectAmountPercent,
                  ),
                );
              },
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
          if (applyToWholeFile ? _parts[i].keep : i == index)
            _parts[i].copyWith(
              volumePercent: result.volumePercent,
              effect: result.effect,
              secondaryEffect: result.secondaryEffect,
              thirdEffect: result.thirdEffect,
              fourthEffect: result.fourthEffect,
              effectAmountPercent: result.effectAmountPercent,
            )
          else
            _parts[i],
      ];
      _status = applyToWholeFile
          ? _guidedEffectsLabel
          : l10n.mediaCutterPartEffectsApplied(
              _formatTime(part.start),
              _formatTime(part.end),
            );
      _hasUnsavedEdit = true;
    });
    unawaited(_logMediaCutter(
      'part effects applied index=$index volume=$volumePercent% '
      'effect=${effect.name} secondary=${secondaryEffect.name} '
      'third=${thirdEffect.name} fourth=${fourthEffect.name} '
      'amount=$effectAmountPercent%',
    ));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_inputPath.isEmpty) {
      _showSnack(l10n.mediaCutterNoFile);
      return;
    }
    final keptParts = _parts.where((part) => part.keep).toList();
    unawaited(_logMediaCutter(
      'save requested keptParts=${keptParts.length} totalParts=${_parts.length} '
      'deleted=$_deletedPartCount outputDir="$_outputDirectory" ${_logPlaybackState()}',
    ));
    if (keptParts.isEmpty) {
      _showSnack(l10n.mediaCutterNoPartsToSave);
      return;
    }

    setState(() {
      _saving = true;
      _status = l10n.mediaCutterSaving;
    });

    final exportController = _MediaCutterExportController();
    var wakelockEnabled = false;
    try {
      await _pause();
      await _enableExportWakelock();
      wakelockEnabled = true;
      var outputDir = _outputDirectory;
      if (outputDir.isEmpty) {
        outputDir = await _defaultOutputDirectory();
        if (!mounted) return;
        setState(() {
          _outputDirectory = outputDir;
          _outputController.text =
              _defaultOutputDirectoryDisplayPath(outputDir);
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
          _outputController.text =
              _defaultOutputDirectoryDisplayPath(outputDir);
        });
        _showSnack(l10n.convertMediaOutputNotWritable);
      }

      var output = await _uniqueOutputPath(outputDir, _inputPath);
      try {
        await _runWithProgressDialog(l10n, exportController, () async {
          await _exportKeptParts(keptParts, output, exportController);
        });
      } catch (error) {
        if (error is _MediaCutterExportCancelled) rethrow;
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
          _outputController.text =
              _defaultOutputDirectoryDisplayPath(outputDir);
        });
        _showSnack(l10n.convertMediaOutputNotWritable);
        await _runWithProgressDialog(l10n, exportController, () async {
          await _exportKeptParts(keptParts, output, exportController);
        });
      }
      if (!mounted) return;
      unawaited(_logMediaCutter(
        'save completed output="$output" fallbackToShare=$fallbackToShare '
        'keptParts=${keptParts.length}',
      ));
      final message = l10n.mediaCutterSaved(p.basename(output));
      setState(() {
        _hasUnsavedEdit = false;
        _status = message;
      });
      await _showDoneDialog(message, output, forceShare: fallbackToShare);
    } catch (error) {
      if (error is _MediaCutterExportCancelled) {
        await AppLogger.log('Media cutter: save cancelled by user');
        return;
      }
      await AppLogger.log('Media cutter: save failed error=$error');
      if (!mounted) return;
      setState(() => _status = l10n.mediaCutterReady);
      _showSnack(l10n.mediaCutterSaveFailed(error));
    } finally {
      if (wakelockEnabled) {
        await _disableExportWakelock();
      }
      exportController.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscardUnsavedEdit() async {
    if (_saving) return true;
    final hasPendingGuidedCut = _hasPendingGuidedCut;
    if (!_hasUnsavedEdit && !hasPendingGuidedCut) return true;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mediaCutterUnsavedExitTitle),
        content: Text(
          hasPendingGuidedCut && !_hasUnsavedEdit
              ? _guidedPendingCutExitMessage
              : l10n.mediaCutterUnsavedExitMessage,
        ),
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
    if (result == true && hasPendingGuidedCut) {
      unawaited(_logMediaCutter(
        'discarding pending guided cut start=${_logMaybeDuration(_guidedCutStart)} '
        'end=${_logMaybeDuration(_guidedCutEnd)} ${_logPlaybackState()}',
      ));
    }
    return result ?? false;
  }

  Future<void> _enableExportWakelock() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    try {
      await WakelockPlus.enable();
      await AppLogger.log('Media cutter: wakelock enabled during save');
    } catch (error) {
      await AppLogger.log('Media cutter: wakelock enable failed $error');
    }
  }

  Future<void> _disableExportWakelock() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    try {
      await WakelockPlus.disable();
      await AppLogger.log('Media cutter: wakelock disabled after save');
    } catch (error) {
      await AppLogger.log('Media cutter: wakelock disable failed $error');
    }
  }

  Future<void> _exportKeptParts(
    List<_MediaPart> keptParts,
    String output,
    _MediaCutterExportController exportController,
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
    final totalDurationMs = keptParts.fold<int>(
      0,
      (sum, part) => sum + part.duration.inMilliseconds,
    );
    var completedDurationMs = 0;

    unawaited(_logMediaCutter(
      'export start output="$output" keptParts=${keptParts.length} '
      'totalDuration=${_logDuration(Duration(milliseconds: totalDurationMs))} '
      'isVideo=${_isVideoInput(input)}',
    ));
    for (var i = 0; i < keptParts.length; i++) {
      unawaited(_logMediaCutter('export part ${i + 1}/${keptParts.length} ${_logPart(i, keptParts[i])}'));
    }

    try {
      for (var i = 0; i < keptParts.length; i++) {
        if (exportController.cancelled) {
          throw const _MediaCutterExportCancelled();
        }
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
          if (_videoFilter() != null) ...[
            '-filter:v',
            _videoFilter()!,
          ],
          ..._codecArguments(input),
          '-avoid_negative_ts',
          'make_zero',
          segment,
        ];
        await _runFfmpeg(
          args,
          'segment ${i + 1}/${keptParts.length}',
          exportController,
          onStatistics: (statistics) {
            final segmentMs = statistics.getTime().clamp(
                  0,
                  part.duration.inMilliseconds,
                );
            final fraction = totalDurationMs <= 0
                ? 0.0
                : (completedDurationMs + segmentMs) / totalDurationMs;
            _updateExportProgress(
              exportController,
              fraction,
              'Parte ${i + 1} di ${keptParts.length}',
            );
          },
        );
        completedDurationMs += part.duration.inMilliseconds;
        _updateExportProgress(
          exportController,
          totalDurationMs <= 0 ? 1 : completedDurationMs / totalDurationMs,
          'Parte ${i + 1} di ${keptParts.length}',
        );
        segmentPaths.add(segment);
      }

      if (exportController.cancelled) {
        throw const _MediaCutterExportCancelled();
      }
      if (segmentPaths.length == 1) {
        await File(segmentPaths.single).copy(output);
        _updateExportProgress(exportController, 1, 'Completamento');
        unawaited(_logMediaCutter('export single segment copied output="$output"'));
        return;
      }

      final listFile = File(p.join(workDir.path, 'concat.txt'));
      await listFile.writeAsString(
        segmentPaths
            .map((path) => "file '${path.replaceAll("'", r"'\\''")}'")
            .join('\n'),
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
      _updateExportProgress(exportController, 0.98, 'Completamento');
      await _runFfmpeg(concatArgs, 'concat', exportController);
      _updateExportProgress(exportController, 1, 'Completamento');
      unawaited(_logMediaCutter('export concat completed output="$output" segments=${segmentPaths.length}'));
    } finally {
      if (exportController.cancelled) {
        final outputFile = File(output);
        if (await outputFile.exists()) {
          await outputFile.delete();
        }
      }
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  void _updateExportProgress(
    _MediaCutterExportController exportController,
    double fraction,
    String label,
  ) {
    if (exportController.disposed) return;
    exportController.progress.value = _MediaCutterExportProgress(
      fraction: fraction.clamp(0.0, 1.0).toDouble(),
      label: label,
    );
  }

  Future<void> _runFfmpeg(
    List<String> args,
    String step,
    _MediaCutterExportController exportController, {
    void Function(Statistics statistics)? onStatistics,
  }) async {
    if (exportController.cancelled) {
      throw const _MediaCutterExportCancelled();
    }
    await AppLogger.log(
      'Media cutter ffmpeg $step: args=${args.map(_quoteLogArg).join(' ')}',
    );
    final completer = Completer<FFmpegSession>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (completedSession) {
        if (!completer.isCompleted) completer.complete(completedSession);
      },
      null,
      onStatistics,
    );
    exportController.currentSession = session;
    final completedSession = await completer.future;
    if (identical(exportController.currentSession, session)) {
      exportController.currentSession = null;
    }
    if (exportController.cancelled) {
      throw const _MediaCutterExportCancelled();
    }
    final returnCode = await completedSession.getReturnCode();
    final logs = await completedSession.getAllLogsAsString() ?? '';
    if (ReturnCode.isCancel(returnCode)) {
      throw const _MediaCutterExportCancelled();
    }
    if (!ReturnCode.isSuccess(returnCode)) {
      await AppLogger.log(
        'Media cutter ffmpeg $step failed returnCode=${returnCode?.getValue()} '
        'logs="${_compactLog(logs)}"',
      );
      throw logs.trim().isEmpty ? 'FFmpeg ${returnCode?.getValue()}' : logs;
    }
    await AppLogger.log('Media cutter ffmpeg $step completed returnCode=${returnCode?.getValue()}');
  }

  Future<void> _runWithProgressDialog(
    AppLocalizations l10n,
    _MediaCutterExportController exportController,
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
                ValueListenableBuilder<_MediaCutterExportProgress>(
                  valueListenable: exportController.progress,
                  builder: (context, progress, _) {
                    final percent = (progress.fraction * 100).round();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(value: progress.fraction),
                        const SizedBox(height: 8),
                        Text(
                          progress.label.isEmpty
                              ? '$percent%'
                              : '${progress.label}: $percent%',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  unawaited(taskFuture.catchError((error, stackTrace) async {
                    await AppLogger.log(
                      'Media cutter: background export stopped after cancel '
                      'error=$error',
                    );
                  }));
                  unawaited(exportController.cancel());
                  closeDialog();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(l10n.cancel),
              ),
            ],
          ),
        );
      },
    );

    if (exportController.cancelled) {
      throw const _MediaCutterExportCancelled();
    }
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

  List<_MediaPart> get _keptParts => [
        for (final part in _parts)
          if (part.keep) part,
      ];

  Duration get _editedTimelineDuration {
    if (!_hasDeletedParts) return _duration;
    var total = Duration.zero;
    for (final part in _keptParts) {
      if (part.duration > Duration.zero) total += part.duration;
    }
    return total;
  }

  Duration get _currentTimelinePosition => _originalToEditedPosition(_position);

  Duration _originalToEditedPosition(Duration originalPosition) {
    final original = _clampPosition(originalPosition);
    if (!_hasDeletedParts) return original;
    var elapsed = Duration.zero;
    for (final part in _parts) {
      if (!part.keep) continue;
      if (original <= part.start) return elapsed;
      if (original < part.end) return elapsed + (original - part.start);
      elapsed += part.duration;
    }
    return elapsed;
  }

  Duration _editedToOriginalPosition(Duration editedPosition) {
    if (!_hasDeletedParts) return _clampPosition(editedPosition);
    final keptParts = _keptParts;
    if (keptParts.isEmpty) return Duration.zero;
    final total = _editedTimelineDuration;
    var edited = editedPosition;
    if (edited < Duration.zero) edited = Duration.zero;
    if (total > Duration.zero && edited > total) edited = total;

    var elapsed = Duration.zero;
    for (var i = 0; i < keptParts.length; i++) {
      final part = keptParts[i];
      final nextElapsed = elapsed + part.duration;
      final isLast = i == keptParts.length - 1;
      if (edited < nextElapsed || (edited == nextElapsed && isLast)) {
        return _clampPosition(part.start + (edited - elapsed));
      }
      elapsed = nextElapsed;
    }
    return _clampPosition(keptParts.last.end);
  }

  Future<void> _seekTimelineTo(Duration timelinePosition) async {
    final requestedOriginal = _editedToOriginalPosition(timelinePosition);
    final finalOriginal = _skipDeletedPartsForward(requestedOriginal);
    _logSeekRequest(
      source: 'slider',
      requestedTimeline: timelinePosition,
      requestedOriginal: requestedOriginal,
      finalOriginal: finalOriginal,
      skippedDeletedPart: finalOriginal != requestedOriginal,
    );
    await _seekTo(requestedOriginal);
  }

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
      unawaited(_logMediaCutter(
        'playback skipped deleted part target=${_logDuration(target)} '
        '${_logPlaybackState()}',
      ));
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
    for (final effect in _activeEffects(part)) {
      final filter = _audioFilterForEffect(effect, part, amount);
      if (filter != null) filters.add(filter);
    }

    if (filters.isEmpty) return null;
    return filters.join(',');
  }

  List<_MediaPartEffect> _activeEffects(_MediaPart part) {
    return [
      part.effect,
      part.secondaryEffect,
      part.thirdEffect,
      part.fourthEffect,
    ].where((effect) => effect != _MediaPartEffect.none).toList();
  }

  String? _audioFilterForEffect(
    _MediaPartEffect effect,
    _MediaPart part,
    double amount,
  ) {
    switch (effect) {
      case _MediaPartEffect.none:
        return null;
      case _MediaPartEffect.echo:
        final delay = (120 + 320 * amount).round();
        final decay = (0.35 + 0.55 * amount).toStringAsFixed(2);
        return 'aecho=0.85:0.95:$delay:$decay';
      case _MediaPartEffect.echoRoom:
        final delay1 = (55 + 90 * amount).round();
        final delay2 = (95 + 140 * amount).round();
        final decay1 = (0.22 + 0.24 * amount).toStringAsFixed(2);
        final decay2 = (0.12 + 0.22 * amount).toStringAsFixed(2);
        return 'aecho=0.82:0.88:$delay1|$delay2:$decay1|$decay2';
      case _MediaPartEffect.echoChamber:
        final delay1 = (95 + 150 * amount).round();
        final delay2 = (180 + 260 * amount).round();
        final delay3 = (280 + 360 * amount).round();
        final decay1 = (0.28 + 0.30 * amount).toStringAsFixed(2);
        final decay2 = (0.20 + 0.28 * amount).toStringAsFixed(2);
        final decay3 = (0.13 + 0.22 * amount).toStringAsFixed(2);
        return 'aecho=0.82:0.92:$delay1|$delay2|$delay3:'
            '$decay1|$decay2|$decay3';
      case _MediaPartEffect.echoCathedral:
        final delay1 = (240 + 220 * amount).round();
        final delay2 = (520 + 360 * amount).round();
        final delay3 = (850 + 520 * amount).round();
        final delay4 = (1200 + 700 * amount).round();
        final decay1 = (0.30 + 0.30 * amount).toStringAsFixed(2);
        final decay2 = (0.24 + 0.30 * amount).toStringAsFixed(2);
        final decay3 = (0.18 + 0.28 * amount).toStringAsFixed(2);
        final decay4 = (0.12 + 0.22 * amount).toStringAsFixed(2);
        return 'aecho=0.78:0.96:$delay1|$delay2|$delay3|$delay4:'
            '$decay1|$decay2|$decay3|$decay4';
      case _MediaPartEffect.largeRoom:
        final delay1 = (65 + 40 * amount).round();
        final delay2 = (125 + 70 * amount).round();
        final delay3 = (210 + 100 * amount).round();
        final decay1 = (0.20 + 0.18 * amount).toStringAsFixed(2);
        final decay2 = (0.16 + 0.16 * amount).toStringAsFixed(2);
        final decay3 = (0.11 + 0.14 * amount).toStringAsFixed(2);
        return 'aecho=0.82:0.90:$delay1|$delay2|$delay3:'
            '$decay1|$decay2|$decay3';
      case _MediaPartEffect.smallRoom:
        final delay1 = (25 + 30 * amount).round();
        final delay2 = (55 + 45 * amount).round();
        final decay1 = (0.12 + 0.16 * amount).toStringAsFixed(2);
        final decay2 = (0.08 + 0.14 * amount).toStringAsFixed(2);
        return 'aecho=0.84:0.82:$delay1|$delay2:$decay1|$decay2';
      case _MediaPartEffect.bathroom:
        final delay1 = (35 + 30 * amount).round();
        final delay2 = (70 + 55 * amount).round();
        final delay3 = (110 + 75 * amount).round();
        final decay1 = (0.22 + 0.20 * amount).toStringAsFixed(2);
        final decay2 = (0.17 + 0.17 * amount).toStringAsFixed(2);
        final decay3 = (0.12 + 0.14 * amount).toStringAsFixed(2);
        return 'highpass=f=180,'
            'aecho=0.86:0.90:$delay1|$delay2|$delay3:'
            '$decay1|$decay2|$decay3';
      case _MediaPartEffect.tunnel:
        final delay1 = (140 + 80 * amount).round();
        final delay2 = (290 + 140 * amount).round();
        final delay3 = (440 + 200 * amount).round();
        final delay4 = (590 + 260 * amount).round();
        final decay1 = (0.32 + 0.20 * amount).toStringAsFixed(2);
        final decay2 = (0.25 + 0.18 * amount).toStringAsFixed(2);
        final decay3 = (0.19 + 0.16 * amount).toStringAsFixed(2);
        final decay4 = (0.14 + 0.13 * amount).toStringAsFixed(2);
        return 'aecho=0.78:0.94:$delay1|$delay2|$delay3|$delay4:'
            '$decay1|$decay2|$decay3|$decay4';
      case _MediaPartEffect.repeatEcho:
        final delay1 = (300 + 240 * amount).round();
        final delay2 = delay1 * 2;
        final delay3 = delay1 * 3;
        final decay1 = (0.45 + 0.25 * amount).toStringAsFixed(2);
        final decay2 = (0.30 + 0.20 * amount).toStringAsFixed(2);
        final decay3 = (0.18 + 0.16 * amount).toStringAsFixed(2);
        return 'aecho=0.80:0.95:$delay1|$delay2|$delay3:'
            '$decay1|$decay2|$decay3';
      case _MediaPartEffect.corridor:
        final delay1 = (85 + 55 * amount).round();
        final delay2 = (180 + 100 * amount).round();
        final delay3 = (310 + 145 * amount).round();
        final decay1 = (0.18 + 0.16 * amount).toStringAsFixed(2);
        final decay2 = (0.14 + 0.14 * amount).toStringAsFixed(2);
        final decay3 = (0.10 + 0.12 * amount).toStringAsFixed(2);
        return 'aecho=0.82:0.90:$delay1|$delay2|$delay3:'
            '$decay1|$decay2|$decay3';
      case _MediaPartEffect.delay:
        final delay = (180 + 300 * amount).round();
        final decay = (0.35 + 0.30 * amount).toStringAsFixed(2);
        return 'aecho=0.90:0.88:$delay:$decay';
      case _MediaPartEffect.reverb:
        final delay1 = (45 + 100 * amount).round();
        final delay2 = (110 + 260 * amount).round();
        final delay3 = (190 + 420 * amount).round();
        final decay1 = (0.24 + 0.34 * amount).toStringAsFixed(2);
        final decay2 = (0.18 + 0.30 * amount).toStringAsFixed(2);
        final decay3 = (0.12 + 0.26 * amount).toStringAsFixed(2);
        return 'aecho=0.85:0.95:$delay1|$delay2|$delay3:'
            '$decay1|$decay2|$decay3';
      case _MediaPartEffect.chorus:
        final delay1 = (35 + 20 * amount).round();
        final delay2 = (55 + 30 * amount).round();
        final decay1 = (0.22 + 0.18 * amount).toStringAsFixed(2);
        final decay2 = (0.18 + 0.16 * amount).toStringAsFixed(2);
        final speed1 = (0.22 + 0.18 * amount).toStringAsFixed(2);
        final speed2 = (0.35 + 0.22 * amount).toStringAsFixed(2);
        final depth1 = (1.5 + 1.4 * amount).toStringAsFixed(2);
        final depth2 = (1.9 + 1.7 * amount).toStringAsFixed(2);
        return 'chorus=0.75:0.88:$delay1|$delay2:$decay1|$decay2:'
            '$speed1|$speed2:$depth1|$depth2';
      case _MediaPartEffect.pitchLow:
        return _pitchFilter(0.85);
      case _MediaPartEffect.pitchVeryLow:
        return _pitchFilter(0.75);
      case _MediaPartEffect.pitchHigh:
        return _pitchFilter(1.15);
      case _MediaPartEffect.pitchVeryHigh:
        return _pitchFilter(1.30);
      case _MediaPartEffect.robot:
        final bits = (10 - 5 * amount).round().clamp(5, 10);
        return 'highpass=f=300,lowpass=f=3000,'
            'acrusher=level_in=1:level_out=1:bits=$bits:mode=log:aa=1';
      case _MediaPartEffect.helicopter:
        final frequency = (6 + 12 * amount).toStringAsFixed(2);
        final depth = (0.45 + 0.50 * amount).toStringAsFixed(2);
        return 'tremolo=f=$frequency:d=$depth';
      case _MediaPartEffect.alien:
        final frequency = (4 + 7 * amount).toStringAsFixed(2);
        final depth = (0.35 + 0.55 * amount).toStringAsFixed(2);
        return '${_pitchFilter(1.08 + 0.12 * amount)},'
            'tremolo=f=$frequency:d=$depth,'
            'chorus=0.62:0.78:35|58:0.18|0.14:0.28|0.42:1.8|2.4';
      case _MediaPartEffect.brightVoice:
        final gain = (3 + 6 * amount).toStringAsFixed(2);
        return 'equalizer=f=3500:t=q:w=1.0:g=$gain,highpass=f=120';
      case _MediaPartEffect.darkVoice:
        final gain = (3 + 6 * amount).toStringAsFixed(2);
        return 'equalizer=f=180:t=q:w=1.0:g=$gain,lowpass=f=4200';
      case _MediaPartEffect.ghost:
        final delay1 = (500 + 360 * amount).round();
        final delay2 = (900 + 520 * amount).round();
        final decay1 = (0.34 + 0.20 * amount).toStringAsFixed(2);
        final decay2 = (0.20 + 0.16 * amount).toStringAsFixed(2);
        final tremoloFrequency = (3.8 + 2.6 * amount).toStringAsFixed(2);
        final tremoloDepth = (0.22 + 0.28 * amount).toStringAsFixed(2);
        return 'aecho=0.70:0.95:$delay1|$delay2:$decay1|$decay2,'
            'tremolo=f=$tremoloFrequency:d=$tremoloDepth,volume=0.92';
      case _MediaPartEffect.telephone:
        final ratio = (2.2 + 2.4 * amount).toStringAsFixed(2);
        return 'highpass=f=300,lowpass=f=3400,'
            'acompressor=threshold=-18dB:ratio=$ratio:attack=5:release=80';
      case _MediaPartEffect.oldRadio:
        final bits = (10 - 4 * amount).round().clamp(6, 10);
        final ratio = (2.5 + 2.5 * amount).toStringAsFixed(2);
        return 'highpass=f=250,lowpass=f=3200,'
            'acrusher=level_in=1:level_out=1:bits=$bits:mode=log:aa=1,'
            'acompressor=threshold=-20dB:ratio=$ratio:attack=5:release=120';
      case _MediaPartEffect.megaphone:
        final gain = (3 + 5 * amount).toStringAsFixed(2);
        final ratio = (4 + 4 * amount).toStringAsFixed(2);
        return 'highpass=f=500,lowpass=f=5000,'
            'acompressor=threshold=-16dB:ratio=$ratio:attack=3:release=80,'
            'equalizer=f=1800:t=q:w=1.0:g=$gain';
      case _MediaPartEffect.underwater:
        final lowpass = (1300 - 650 * amount).round().clamp(550, 1300);
        final delay1 = (50 + 50 * amount).round();
        final delay2 = (110 + 70 * amount).round();
        final decay1 = (0.12 + 0.12 * amount).toStringAsFixed(2);
        final decay2 = (0.08 + 0.10 * amount).toStringAsFixed(2);
        return 'lowpass=f=$lowpass,'
            'aecho=0.75:0.55:$delay1|$delay2:$decay1|$decay2';
      case _MediaPartEffect.monster:
        final factor = 0.82 - 0.18 * amount;
        final bits = (10 - 4 * amount).round().clamp(6, 10);
        return '${_pitchFilter(factor)},'
            'acrusher=level_in=1:level_out=1:bits=$bits:mode=log:aa=1';
      case _MediaPartEffect.chipmunk:
        final factor = 1.35 + 0.35 * amount;
        return _pitchFilter(factor);
      case _MediaPartEffect.dream:
        final delay1 = (180 + 160 * amount).round();
        final delay2 = (380 + 280 * amount).round();
        final decay1 = (0.20 + 0.14 * amount).toStringAsFixed(2);
        final decay2 = (0.12 + 0.12 * amount).toStringAsFixed(2);
        return 'aecho=0.72:0.82:$delay1|$delay2:$decay1|$decay2,'
            'chorus=0.65:0.75:45|65:0.18|0.14:0.25|0.38:1.6|2.1';
      case _MediaPartEffect.distortion:
        final bits = (9 - 5 * amount).round().clamp(4, 9);
        final levelIn = (1.0 + 0.45 * amount).toStringAsFixed(2);
        return 'acrusher=level_in=$levelIn:level_out=0.85:'
            'bits=$bits:mode=log:aa=1';
      case _MediaPartEffect.loFi:
        final lowpass = (4800 - 1800 * amount).round().clamp(2400, 4800);
        final bits = (10 - 4 * amount).round().clamp(6, 10);
        return 'lowpass=f=$lowpass,highpass=f=120,'
            'acrusher=level_in=1:level_out=0.9:bits=$bits:mode=log:aa=1';
      case _MediaPartEffect.reverseEcho:
        final delay1 = (320 + 220 * amount).round();
        final delay2 = (680 + 360 * amount).round();
        final decay1 = (0.30 + 0.20 * amount).toStringAsFixed(2);
        final decay2 = (0.16 + 0.16 * amount).toStringAsFixed(2);
        return 'areverse,aecho=0.75:0.88:$delay1|$delay2:'
            '$decay1|$decay2,areverse';
      case _MediaPartEffect.fadeIn:
        final fade = _fadeDurationSeconds(part.duration);
        return 'afade=t=in:st=0:d=$fade';
      case _MediaPartEffect.fadeOut:
        final fade = _fadeDurationSeconds(part.duration);
        final start = (_seconds(part.duration) - double.parse(fade))
            .clamp(0.0, double.infinity)
            .toStringAsFixed(3);
        return 'afade=t=out:st=$start:d=$fade';
    }
  }

  String _pitchFilter(double factor) {
    final compensation = 1 / factor;
    return 'asetrate=44100*${factor.toStringAsFixed(3)},'
        'aresample=44100,'
        'atempo=${compensation.toStringAsFixed(6)}';
  }

  String _fadeDurationSeconds(Duration duration) {
    final seconds = _seconds(duration);
    final fade = seconds <= 0 ? 0.2 : (seconds / 3).clamp(0.2, 3.0);
    return fade.toStringAsFixed(3);
  }

  double _seconds(Duration duration) => duration.inMilliseconds / 1000.0;

  String? _videoFilter() {
    if (!_isVideo) return null;
    return switch (_videoRotation) {
      _VideoRotation.none => null,
      _VideoRotation.right => 'transpose=1',
      _VideoRotation.left => 'transpose=2',
      _VideoRotation.upsideDown => 'transpose=1,transpose=1',
    };
  }

  String _videoRotationLabel(
    AppLocalizations l10n,
    _VideoRotation rotation,
  ) {
    return switch (rotation) {
      _VideoRotation.none => l10n.mediaCutterVideoRotationNone,
      _VideoRotation.right => l10n.mediaCutterVideoRotationRight,
      _VideoRotation.left => l10n.mediaCutterVideoRotationLeft,
      _VideoRotation.upsideDown => l10n.mediaCutterVideoRotationUpsideDown,
    };
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
        (part) => part.start <= start && part.end >= end,
      );
      final inherited = previous.isEmpty ? null : previous.first;
      rebuilt.add(_MediaPart(
        start: start,
        end: end,
        keep: inherited?.keep ?? true,
        volumePercent: inherited?.volumePercent ?? 100,
        effect: inherited?.effect ?? _MediaPartEffect.none,
        secondaryEffect:
            inherited?.secondaryEffect ?? _MediaPartEffect.none,
        thirdEffect: inherited?.thirdEffect ?? _MediaPartEffect.none,
        fourthEffect: inherited?.fourthEffect ?? _MediaPartEffect.none,
        effectAmountPercent: inherited?.effectAmountPercent ?? 50,
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
      case _MediaPartEffect.echoRoom:
        return l10n.mediaCutterPartEffectEchoRoom;
      case _MediaPartEffect.echoChamber:
        return l10n.mediaCutterPartEffectEchoChamber;
      case _MediaPartEffect.echoCathedral:
        return l10n.mediaCutterPartEffectEchoCathedral;
      case _MediaPartEffect.largeRoom:
        return l10n.mediaCutterPartEffectLargeRoom;
      case _MediaPartEffect.smallRoom:
        return l10n.mediaCutterPartEffectSmallRoom;
      case _MediaPartEffect.bathroom:
        return l10n.mediaCutterPartEffectBathroom;
      case _MediaPartEffect.tunnel:
        return l10n.mediaCutterPartEffectTunnel;
      case _MediaPartEffect.repeatEcho:
        return l10n.mediaCutterPartEffectRepeatEcho;
      case _MediaPartEffect.corridor:
        return l10n.mediaCutterPartEffectCorridor;
      case _MediaPartEffect.delay:
        return l10n.mediaCutterPartEffectDelay;
      case _MediaPartEffect.reverb:
        return l10n.mediaCutterPartEffectReverb;
      case _MediaPartEffect.chorus:
        return l10n.mediaCutterPartEffectChorus;
      case _MediaPartEffect.pitchLow:
        return l10n.mediaCutterPartEffectPitchLow;
      case _MediaPartEffect.pitchVeryLow:
        return l10n.mediaCutterPartEffectPitchVeryLow;
      case _MediaPartEffect.pitchHigh:
        return l10n.mediaCutterPartEffectPitchHigh;
      case _MediaPartEffect.pitchVeryHigh:
        return l10n.mediaCutterPartEffectPitchVeryHigh;
      case _MediaPartEffect.robot:
        return l10n.mediaCutterPartEffectRobot;
      case _MediaPartEffect.helicopter:
        return l10n.mediaCutterPartEffectHelicopter;
      case _MediaPartEffect.alien:
        return l10n.mediaCutterPartEffectAlien;
      case _MediaPartEffect.brightVoice:
        return l10n.mediaCutterPartEffectBrightVoice;
      case _MediaPartEffect.darkVoice:
        return l10n.mediaCutterPartEffectDarkVoice;
      case _MediaPartEffect.ghost:
        return l10n.mediaCutterPartEffectGhost;
      case _MediaPartEffect.telephone:
        return l10n.mediaCutterPartEffectTelephone;
      case _MediaPartEffect.oldRadio:
        return l10n.mediaCutterPartEffectOldRadio;
      case _MediaPartEffect.megaphone:
        return l10n.mediaCutterPartEffectMegaphone;
      case _MediaPartEffect.underwater:
        return l10n.mediaCutterPartEffectUnderwater;
      case _MediaPartEffect.monster:
        return l10n.mediaCutterPartEffectMonster;
      case _MediaPartEffect.chipmunk:
        return l10n.mediaCutterPartEffectChipmunk;
      case _MediaPartEffect.dream:
        return l10n.mediaCutterPartEffectDream;
      case _MediaPartEffect.distortion:
        return l10n.mediaCutterPartEffectDistortion;
      case _MediaPartEffect.loFi:
        return l10n.mediaCutterPartEffectLoFi;
      case _MediaPartEffect.reverseEcho:
        return l10n.mediaCutterPartEffectReverseEcho;
      case _MediaPartEffect.fadeIn:
        return l10n.mediaCutterPartEffectFadeIn;
      case _MediaPartEffect.fadeOut:
        return l10n.mediaCutterPartEffectFadeOut;
    }
  }

  String _effectSlotLabel(AppLocalizations l10n, int slot) {
    return '${l10n.mediaCutterPartEffect} $slot';
  }

  void _addEffectSlotSummary(
    AppLocalizations l10n,
    List<String> pieces,
    int slot,
    _MediaPartEffect effect,
  ) {
    if (effect == _MediaPartEffect.none) return;
    pieces.add('${_effectSlotLabel(l10n, slot)} ${_effectLabel(l10n, effect)}');
  }

  String _partDetailsSummary(AppLocalizations l10n, _MediaPart part) {
    final duration = _formatHumanDuration(part.duration);
    final pieces = <String>[];

    if (part.volumePercent != 100) {
      pieces.add(_localizedVolumeSummary(part.volumePercent));
    }
    _addEffectSlotSummary(l10n, pieces, 1, part.effect);
    _addEffectSlotSummary(l10n, pieces, 2, part.secondaryEffect);
    _addEffectSlotSummary(l10n, pieces, 3, part.thirdEffect);
    _addEffectSlotSummary(l10n, pieces, 4, part.fourthEffect);
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

  String _mediaSeekStepButtonLabel() {
    final step = _formatHumanDuration(_mediaSeekStep);
    final lang = Localizations.localeOf(context).languageCode;
    return switch (lang) {
      'en' => 'Adjust media file movement: $step',
      'fr' => 'Régler le déplacement du fichier média : $step',
      'es' => 'Ajustar el desplazamiento del archivo multimedia: $step',
      'pt' => 'Regular o deslocamento do arquivo de mídia: $step',
      'pl' => 'Dostosuj przesuwanie pliku multimedialnego: $step',
      'cs' => 'Nastavit posun mediálního souboru: $step',
      _ => 'Regola lo spostamento del file media: $step',
    };
  }

  String _mediaSeekStepDialogTitle() {
    final lang = Localizations.localeOf(context).languageCode;
    return switch (lang) {
      'en' => 'Media file movement',
      'fr' => 'Déplacement du fichier média',
      'es' => 'Desplazamiento del archivo multimedia',
      'pt' => 'Deslocamento do arquivo de mídia',
      'pl' => 'Przesuwanie pliku multimedialnego',
      'cs' => 'Posun mediálního souboru',
      _ => 'Spostamento del file media',
    };
  }

  String _mediaSeekStepSelectedMessage(Duration step) {
    final formatted = _formatHumanDuration(step);
    final lang = Localizations.localeOf(context).languageCode;
    return switch (lang) {
      'en' => 'Media file movement set to $formatted.',
      'fr' => 'Déplacement du fichier média réglé sur $formatted.',
      'es' => 'Desplazamiento del archivo multimedia ajustado a $formatted.',
      'pt' => 'Deslocamento do arquivo de mídia definido para $formatted.',
      'pl' => 'Przesuwanie pliku multimedialnego ustawione na $formatted.',
      'cs' => 'Posun mediálního souboru nastaven na $formatted.',
      _ => 'Spostamento del file media impostato a $formatted.',
    };
  }

  Future<void> _showMediaSeekStepDialog() async {
    final selected = await showDialog<Duration>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(_mediaSeekStepDialogTitle()),
          children: [
            for (final step in _mediaSeekStepOptions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(step),
                child: Row(
                  children: [
                    if (step == _mediaSeekStep)
                      const Icon(Icons.check)
                    else
                      const SizedBox(width: 24),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_formatHumanDuration(step))),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (selected == null || selected == _mediaSeekStep || !mounted) return;
    setState(() => _mediaSeekStep = selected);
    unawaited(_logMediaCutter('media movement step changed to ${_logDuration(selected)}'));
    _showSnack(_mediaSeekStepSelectedMessage(selected));
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
    final position = _currentTimelinePosition;
    final sliderDuration = _editedTimelineDuration;
    if (sliderDuration == Duration.zero) return const SizedBox();
    final posSecs = position.inSeconds.toDouble();
    final durSecs = sliderDuration.inSeconds
        .toDouble()
        .clamp(1.0, double.infinity)
        .toDouble();
    final seekStep = _mediaSeekStep;
    final stepForward = position + seekStep > sliderDuration
        ? sliderDuration
        : position + seekStep;
    final stepBack = position - seekStep < Duration.zero
        ? Duration.zero
        : position - seekStep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            '${_formatTime(position)} / ${_formatTime(sliderDuration)}',
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('media_cutter_position_slider_semantics'),
          slider: true,
          label: l10n.mediaCutterPosition,
          value: l10n.playbackPositionValue(
            _formatHumanDuration(position),
            _formatHumanDuration(sliderDuration),
          ),
          increasedValue: _formatHumanDuration(stepForward),
          decreasedValue: _formatHumanDuration(stepBack),
          onIncrease: position < sliderDuration
              ? () => unawaited(_seekTimelineTo(stepForward))
              : null,
          onDecrease: position > Duration.zero
              ? () => unawaited(_seekTimelineTo(stepBack))
              : null,
          hint: l10n.mediaCutterPositionHint,
          child: ExcludeSemantics(
            child: Slider(
              value: posSecs.clamp(0.0, durSecs).toDouble(),
              min: 0,
              max: durSecs,
              divisions: sliderDuration.inSeconds > 0 ? sliderDuration.inSeconds : null,
              onChanged: _saving
                  ? null
                  : (value) => unawaited(
                        _seekTimelineTo(Duration(seconds: value.round())),
                      ),
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
        for (var visibleIndex = 0;
            visibleIndex < visibleParts.length;
            visibleIndex++)
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
    final editAction = CustomSemanticsAction(
      label: _partEditActionLabel,
    );

    return Semantics(
      key: ValueKey('media_cutter_part_semantics_${_partKey(part)}'),
      container: true,
      button: true,
      enabled: !_saving,
      label: '$label, $partSummary',
      hint: l10n.mediaCutterPartTapHint,
      onTap: _saving ? null : () => _playPart(originalIndex),
      customSemanticsActions: _saving
          ? const <CustomSemanticsAction, VoidCallback>{}
          : <CustomSemanticsAction, VoidCallback>{
              editAction: () =>
                  unawaited(_showAdvancedPartEditDialog(originalIndex)),
              deleteAction: () => _deletePart(originalIndex),
              effectsAction: () =>
                  unawaited(_showPartEffectsDialog(originalIndex)),
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
                  tooltip: _partEditActionLabel,
                  icon: const Icon(Icons.edit),
                  onPressed: _saving
                      ? null
                      : () => _showAdvancedPartEditDialog(originalIndex),
                ),
                IconButton(
                  tooltip: l10n.mediaCutterPartEffectsAction,
                  icon: const Icon(Icons.tune),
                  onPressed: _saving
                      ? null
                      : () => _showPartEffectsDialog(originalIndex),
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


  Widget _buildModeSelection() {
    Widget modeCard({
      required _MediaCutterMode mode,
      required IconData icon,
      required String title,
      required String description,
    }) {
      return Card(
        child: InkWell(
          onTap: () => _selectMode(mode),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(description),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).mediaCutterTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            modeCard(
              mode: _MediaCutterMode.guided,
              icon: Icons.content_cut,
              title: _guidedModeTitle,
              description: _guidedModeDescription,
            ),
            const SizedBox(height: 12),
            modeCard(
              mode: _MediaCutterMode.advanced,
              icon: Icons.graphic_eq,
              title: _advancedModeTitle,
              description: _advancedModeDescription,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidedSummarySection(AppLocalizations l10n) {
    if (_inputPath.isEmpty || _duration == Duration.zero) return const SizedBox();
    final title = _displayName.isEmpty ? p.basename(_inputPath) : _displayName;
    final summary = _guidedCurrentSummary;
    final effectsAction = CustomSemanticsAction(label: _guidedEffectsLabel);
    return Semantics(
      key: const ValueKey('media_cutter_guided_summary_semantics'),
      container: true,
      button: true,
      enabled: !_saving,
      label: '$title, $summary',
      hint: _guidedFileTapHint,
      onTap: _saving ? null : () => _togglePlayback(),
      customSemanticsActions: _saving
          ? const <CustomSemanticsAction, VoidCallback>{}
          : <CustomSemanticsAction, VoidCallback>{
              effectsAction: () => unawaited(_showGuidedEffectsDialog()),
            },
      child: ExcludeSemantics(
        child: Card(
          child: ListTile(
            enabled: !_saving,
            onTap: !_saving ? () => _togglePlayback() : null,
            leading: Icon(_playing ? Icons.pause : Icons.play_arrow),
            title: Text(title),
            subtitle: Text(summary),
            trailing: IconButton(
              tooltip: _guidedEffectsLabel,
              icon: const Icon(Icons.tune),
              onPressed: _saving ? null : _showGuidedEffectsDialog,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_selectedMode == null) return _buildModeSelection();
    final canUseMedia = _inputPath.isNotEmpty && !_loading && !_saving;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmDiscardUnsavedEdit();
        if (!context.mounted || !shouldLeave) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.mediaCutterTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_isGuidedMode ? _guidedModeTitle : _advancedModeTitle),
              const SizedBox(height: 4),
              Text(_isGuidedMode ? _guidedModeDescription : _advancedModeDescription),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading || _saving ? null : () => unawaited(_changeMode()),
                icon: const Icon(Icons.swap_horiz),
                label: Text(_changeCutModeLabel),
              ),
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
              if (_inputPath.isNotEmpty && _duration != Duration.zero) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: canUseMedia
                      ? () => unawaited(_showMediaSeekStepDialog())
                      : null,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(_mediaSeekStepButtonLabel()),
                ),
              ],
              if (_isVideo) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<_VideoRotation>(
                  initialValue: _videoRotation,
                  decoration: InputDecoration(
                    labelText: l10n.mediaCutterVideoRotation,
                  ),
                  items: [
                    for (final rotation in _VideoRotation.values)
                      DropdownMenuItem<_VideoRotation>(
                        value: rotation,
                        child: Text(_videoRotationLabel(l10n, rotation)),
                      ),
                  ],
                  onChanged: _loading || _saving
                      ? null
                      : (value) {
                          if (value == null || value == _videoRotation) return;
                          setState(() {
                            _videoRotation = value;
                            _hasUnsavedEdit = true;
                          });
                          unawaited(_logMediaCutter(
                            'video rotation changed rotation=${value.name} mode=${_selectedMode?.name ?? 'none'} ${_logPlaybackState()}',
                          ));
                        },
                ),
                const SizedBox(height: 12),
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
                  if (_isGuidedMode) ...[
                    FilledButton.icon(
                      onPressed: canUseMedia ? _guidedCutButtonPressed : null,
                      icon: const Icon(Icons.content_cut),
                      label: Text(_guidedPrimaryCutButtonLabel),
                    ),
                    OutlinedButton.icon(
                      onPressed: canUseMedia &&
                              _guidedCutStart != null &&
                              _guidedCutEnd != null
                          ? _listenGuidedCut
                          : null,
                      icon: const Icon(Icons.hearing),
                      label: Text(_guidedListenCutLabel),
                    ),
                    OutlinedButton.icon(
                      onPressed: canUseMedia &&
                              _guidedCutStart != null &&
                              _guidedCutEnd != null
                          ? _showGuidedModifyCutDialog
                          : null,
                      icon: const Icon(Icons.tune),
                      label: Text(_guidedModifyCutLabel),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: canUseMedia ? _splitHere : null,
                      icon: const Icon(Icons.content_cut),
                      label: Text(l10n.mediaCutterSplit),
                    ),
                    OutlinedButton.icon(
                      onPressed: canUseMedia && _hasDeletedParts
                          ? _restoreDeletedPart
                          : null,
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.mediaCutterRestoreDeletedPart),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              _isGuidedMode
                  ? _buildGuidedSummarySection(l10n)
                  : _buildPartsSection(l10n),
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
      ),
    );
  }
}
