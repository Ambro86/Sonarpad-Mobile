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
  superRobot,
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
const _cutEditStepOptions = <Duration>[
  Duration(seconds: 1),
  Duration(milliseconds: 500),
  Duration(milliseconds: 250),
  Duration(milliseconds: 100),
];

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

class _MediaEffectSlot {
  const _MediaEffectSlot({
    required this.effect,
    required this.amountPercent,
  });

  final _MediaPartEffect effect;
  final int amountPercent;

  _MediaEffectSlot copyWith({
    _MediaPartEffect? effect,
    int? amountPercent,
  }) =>
      _MediaEffectSlot(
        effect: effect ?? this.effect,
        amountPercent: amountPercent ?? this.amountPercent,
      );
}

class _PartEffectSettings {
  const _PartEffectSettings({
    required this.volumePercent,
    required this.effect,
    required this.secondaryEffect,
    required this.thirdEffect,
    required this.fourthEffect,
    required this.effectAmountPercent,
    required this.secondaryEffectAmountPercent,
    required this.thirdEffectAmountPercent,
    required this.fourthEffectAmountPercent,
  });

  final int volumePercent;
  final _MediaPartEffect effect;
  final _MediaPartEffect secondaryEffect;
  final _MediaPartEffect thirdEffect;
  final _MediaPartEffect fourthEffect;
  final int effectAmountPercent;
  final int secondaryEffectAmountPercent;
  final int thirdEffectAmountPercent;
  final int fourthEffectAmountPercent;
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
    this.secondaryEffectAmountPercent = 50,
    this.thirdEffectAmountPercent = 50,
    this.fourthEffectAmountPercent = 50,
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
  final int secondaryEffectAmountPercent;
  final int thirdEffectAmountPercent;
  final int fourthEffectAmountPercent;

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
    int? secondaryEffectAmountPercent,
    int? thirdEffectAmountPercent,
    int? fourthEffectAmountPercent,
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
        secondaryEffectAmountPercent: secondaryEffectAmountPercent ??
            this.secondaryEffectAmountPercent,
        thirdEffectAmountPercent:
            thirdEffectAmountPercent ?? this.thirdEffectAmountPercent,
        fourthEffectAmountPercent:
            fourthEffectAmountPercent ?? this.fourthEffectAmountPercent,
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
  Timer? _deletedSkipTimer;
  Duration? _scheduledDeletedSkipBoundary;
  Duration? _scheduledDeletedSkipTarget;

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
  Future<String>? _underwaterBubblesSourcePath;
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
      _scheduleDeletedPartSkipTimer(fromPosition: clamped);
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
    unawaited(_deleteUnderwaterBubblesCache());
    unawaited(_mediaEventsSubscription?.cancel() ?? Future<void>.value());
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioPlayingSubscription?.cancel();
    _videoRefreshTimer?.cancel();
    _cancelDeletedSkipTimer();
    _videoController?.dispose();
    _audioPlayer.dispose();
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _logMediaCutter(String message) async {
    await AppLogger.log('Media cutter: $message');
  }

  Future<void> _deleteUnderwaterBubblesCache() async {
    final sourcePath = _underwaterBubblesSourcePath;
    if (sourcePath == null) return;
    try {
      final file = File(await sourcePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Cache cleanup is best-effort.
    }
  }

  Future<String> _ensureUnderwaterBubblesSourcePath() {
    final cached = _underwaterBubblesSourcePath;
    if (cached != null) return cached;
    _underwaterBubblesSourcePath = _buildUnderwaterBubblesSourcePath();
    return _underwaterBubblesSourcePath!;
  }

  Future<String> _buildUnderwaterBubblesSourcePath() async {
    final tempRoot = await getTemporaryDirectory();
    final file = File(p.join(tempRoot.path, 'sonarpad_underwater_bubbles.mp3'));
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/audio/underwater_bubbles.mp3');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return file.path;
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

  List<_MediaEffectSlot> _effectSlotsForPart(_MediaPart part) => [
        _MediaEffectSlot(
          effect: part.effect,
          amountPercent: part.effectAmountPercent,
        ),
        _MediaEffectSlot(
          effect: part.secondaryEffect,
          amountPercent: part.secondaryEffectAmountPercent,
        ),
        _MediaEffectSlot(
          effect: part.thirdEffect,
          amountPercent: part.thirdEffectAmountPercent,
        ),
        _MediaEffectSlot(
          effect: part.fourthEffect,
          amountPercent: part.fourthEffectAmountPercent,
        ),
      ];

  List<_MediaEffectSlot> _activeEffectSlots(_MediaPart part) =>
      _effectSlotsForPart(part)
          .where((slot) => slot.effect != _MediaPartEffect.none)
          .toList();

  List<_MediaEffectSlot> _normalizedEffectSlots(
    List<_MediaEffectSlot> slots,
  ) {
    final active = [
      for (final slot in slots)
        if (slot.effect != _MediaPartEffect.none)
          _MediaEffectSlot(
            effect: slot.effect,
            amountPercent: slot.amountPercent.clamp(0, 100).toInt(),
          ),
    ];
    while (active.length < 4) {
      active.add(const _MediaEffectSlot(
        effect: _MediaPartEffect.none,
        amountPercent: 50,
      ));
    }
    return active.take(4).toList();
  }

  String _logPart(int index, _MediaPart part) {
    final effects = _activeEffectSlots(part)
        .map((slot) => '${slot.effect.name}:${slot.amountPercent}%')
        .join('|');
    return 'index=$index start=${_logDuration(part.start)} '
        'end=${_logDuration(part.end)} '
        'duration=${_logDuration(part.duration)} '
        'keep=${part.keep} volume=${part.volumePercent}% '
        'effects=${effects.isEmpty ? 'none' : effects}';
  }

  String _logEffectSlots(List<_MediaEffectSlot> slots) {
    return slots
        .asMap()
        .entries
        .map((entry) =>
            'slot${entry.key + 1}=${entry.value.effect.name}:'
            '${entry.value.amountPercent}%')
        .join(',');
  }

  int _visibleEffectSlots(List<_MediaEffectSlot> slots) {
    final firstEmptySlot = slots.indexWhere(
      (item) => item.effect == _MediaPartEffect.none,
    );
    return firstEmptySlot == -1 ? slots.length : firstEmptySlot + 1;
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
      _cancelDeletedSkipTimer();
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
          _scheduleDeletedPartSkipTimer(fromPosition: clamped);
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
          _scheduleDeletedPartSkipTimer(fromPosition: controller.value.position);
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
          _scheduleDeletedPartSkipTimer(fromPosition: _audioPlayer.position);
          unawaited(_logMediaCutter('audio playing by toggle ${_logPlaybackState()}'));
        }
      }
    } catch (error) {
      await AppLogger.log('Media cutter: play/pause failed error=$error');
    }
  }

  Future<void> _pause() async {
    _cancelDeletedSkipTimer();
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
    _cancelDeletedSkipTimer();
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
    if (_isPlayerActuallyPlaying && _previewPartEnd == null) {
      _scheduleDeletedPartSkipTimer(fromPosition: target);
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
    required int secondaryEffectAmountPercent,
    required int thirdEffectAmountPercent,
    required int fourthEffectAmountPercent,
  }) async {
    if (_inputPath.isEmpty || _loading || _saving || _effectPreviewPreparing) {
      return;
    }
    if (index < 0 || index >= _parts.length) return;
    final part = _parts[index];
    unawaited(_logMediaCutter(
      'effects preview requested index=$index volume=$volumePercent% '
      'effect=${effect.name}:$effectAmountPercent% '
      'secondary=${secondaryEffect.name}:$secondaryEffectAmountPercent% '
      'third=${thirdEffect.name}:$thirdEffectAmountPercent% '
      'fourth=${fourthEffect.name}:$fourthEffectAmountPercent% '
      'part=${_logPart(index, part)}',
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
      secondaryEffectAmountPercent: secondaryEffectAmountPercent,
      thirdEffectAmountPercent: thirdEffectAmountPercent,
      fourthEffectAmountPercent: fourthEffectAmountPercent,
    );
    final activeEffects = _activeEffects(previewPart);
    final usesUnderwaterBubbles = _usesUnderwaterBubbles(previewPart);
    final String? filter = usesUnderwaterBubbles
        ? _underwaterAudioFilterForPart(previewPart)
        : _audioFilterForPart(previewPart);
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
      final String audioFilter = filter;
      final args = <String>[
        '-y',
        '-ss',
        _ffmpegTime(previewStart),
        '-i',
        _inputPath,
      ];
      if (usesUnderwaterBubbles) {
        args.addAll([
          '-stream_loop',
          '-1',
          '-i',
          await _ensureUnderwaterBubblesSourcePath(),
        ]);
      }
      args.addAll([
        '-t',
        _ffmpegTime(previewDuration),
      ]);
      if (usesUnderwaterBubbles) {
        args.addAll([
          '-filter_complex',
          audioFilter,
          '-map',
          '[outa]',
        ]);
      } else {
        args.addAll([
          '-map',
          '0:a:0?',
          '-vn',
          '-sn',
          '-dn',
          '-filter:a',
          audioFilter,
        ]);
      }
      args.addAll([
        '-c:a',
        'aac',
        '-b:a',
        '160k',
        previewFile.path,
      ]);
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

  String _cutEditStepLabel(Duration step) {
    switch (step.inMilliseconds) {
      case 1000:
        return _l10n.mediaCutterCutEditStepOneSecond;
      case 500:
        return _l10n.mediaCutterCutEditStepHalfSecond;
      case 250:
        return _l10n.mediaCutterCutEditStepQuarterSecond;
      case 100:
        return _l10n.mediaCutterCutEditStepTenthSecond;
      default:
        final seconds = step.inMilliseconds / 1000;
        return '${seconds.toStringAsFixed(2)} s';
    }
  }

  String _moveStartBackLabel(Duration step) =>
      _l10n.mediaCutterMoveStartBackBy(_cutEditStepLabel(step));

  String _moveStartForwardLabel(Duration step) =>
      _l10n.mediaCutterMoveStartForwardBy(_cutEditStepLabel(step));

  String _moveEndBackLabel(Duration step) =>
      _l10n.mediaCutterMoveEndBackBy(_cutEditStepLabel(step));

  String _moveEndForwardLabel(Duration step) =>
      _l10n.mediaCutterMoveEndForwardBy(_cutEditStepLabel(step));

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
    _cancelDeletedSkipTimer();
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

  bool _isGuidedCutReadyToEdit() =>
      _inputPath.isNotEmpty && _guidedCutStart != null && _guidedCutEnd != null;

  int _cutEditStepIndex(Duration step) {
    final index = _cutEditStepOptions.indexWhere(
      (option) => option.inMilliseconds == step.inMilliseconds,
    );
    return index == -1 ? 0 : index;
  }

  Widget _buildCutEditPrecisionSlider({
    required Duration value,
    required ValueChanged<Duration> onChanged,
  }) {
    final index = _cutEditStepIndex(value);
    final label = _cutEditStepLabel(value);
    void setIndex(int newIndex) {
      final maxIndex = _cutEditStepOptions.length - 1;
      final clamped = newIndex < 0
          ? 0
          : newIndex > maxIndex
              ? maxIndex
              : newIndex;
      onChanged(_cutEditStepOptions[clamped]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(_l10n.mediaCutterCutEditPrecisionValue(label)),
        ),
        Semantics(
          slider: true,
          label: _l10n.mediaCutterCutEditPrecisionLabel,
          value: label,
          increasedValue: _cutEditStepLabel(
            _cutEditStepOptions[
              index + 1 >= _cutEditStepOptions.length
                  ? _cutEditStepOptions.length - 1
                  : index + 1
            ],
          ),
          decreasedValue: _cutEditStepLabel(
            _cutEditStepOptions[index - 1 < 0 ? 0 : index - 1],
          ),
          onIncrease: () => setIndex(index + 1),
          onDecrease: () => setIndex(index - 1),
          child: ExcludeSemantics(
            child: Slider(
              value: index.toDouble(),
              min: 0,
              max: (_cutEditStepOptions.length - 1).toDouble(),
              divisions: _cutEditStepOptions.length - 1,
              label: label,
              onChanged: (rawValue) => setIndex(rawValue.round()),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showGuidedModifyCutDialog() async {
    if (!_isGuidedCutReadyToEdit()) {
      _showSnack(_guidedNeedStartEndMessage);
      return;
    }
    var editStep = _cutEditStepOptions.first;
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
              await _adjustGuidedCutByStep(
                moveStart: moveStart,
                direction: direction,
                step: editStep,
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
                    _buildCutEditPrecisionSlider(
                      value: editStep,
                      onChanged: (value) => setDialogState(() => editStep = value),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: true, direction: -1)),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      label: Text(_moveStartBackLabel(editStep)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: true, direction: 1)),
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      label: Text(_moveStartForwardLabel(editStep)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: false, direction: -1)),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      label: Text(_moveEndBackLabel(editStep)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: false, direction: 1)),
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      label: Text(_moveEndForwardLabel(editStep)),
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

  Future<void> _adjustGuidedCutByStep({
    required bool moveStart,
    required int direction,
    required Duration step,
  }) async {
    final l10n = AppLocalizations.of(context);
    final start = _guidedCutStart;
    final end = _guidedCutEnd;
    if (start == null || end == null) {
      _showSnack(_guidedNeedStartEndMessage);
      return;
    }

    final signedStep = Duration(milliseconds: step.inMilliseconds * (direction < 0 ? -1 : 1));
    var newStart = start;
    var newEnd = end;
    if (moveStart) {
      newStart += signedStep;
    } else {
      newEnd += signedStep;
    }

    if (newStart < Duration.zero) newStart = Duration.zero;
    if (newEnd > _duration) newEnd = _duration;
    if (newEnd <= newStart ||
        newEnd.inMilliseconds - newStart.inMilliseconds < 100) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      unawaited(_logMediaCutter(
        'guided cut adjust rejected too close moveStart=$moveStart direction=$direction ' 
        'step=${_logPreciseDuration(step)} ' 
        'start=${_logPreciseDuration(start)} end=${_logPreciseDuration(end)} ' 
        'newStart=${_logPreciseDuration(newStart)} newEnd=${_logPreciseDuration(newEnd)}',
      ));
      return;
    }

    final orderedStart = newStart;
    final orderedEnd = newEnd;
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
      'step=${_logPreciseDuration(step)} ' 
      'start=${_logPreciseDuration(orderedStart)} end=${_logPreciseDuration(orderedEnd)} ' 
      '${_logPlaybackState()}',
    ));
  }

  Future<void> _showAdvancedPartEditDialog(int index) async {
    if (_saving || index < 0 || index >= _parts.length || !_parts[index].keep) {
      return;
    }
    var editStep = _cutEditStepOptions.first;
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
              await _adjustAdvancedPartEdgeByStep(
                index: index,
                moveStart: moveStart,
                direction: direction,
                step: editStep,
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
                    _buildCutEditPrecisionSlider(
                      value: editStep,
                      onChanged: (value) => setDialogState(() => editStep = value),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: true, direction: -1)),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      label: Text(_moveStartBackLabel(editStep)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: true, direction: 1)),
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      label: Text(_moveStartForwardLabel(editStep)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: false, direction: -1)),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      label: Text(_moveEndBackLabel(editStep)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(adjust(moveStart: false, direction: 1)),
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      label: Text(_moveEndForwardLabel(editStep)),
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

  Future<void> _adjustAdvancedPartEdgeByStep({
    required int index,
    required bool moveStart,
    required int direction,
    required Duration step,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (index < 0 || index >= _parts.length || !_parts[index].keep) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }
    final currentPart = _parts[index];
    final signedStep = Duration(milliseconds: step.inMilliseconds * (direction < 0 ? -1 : 1));
    var newStart = currentPart.start;
    var newEnd = currentPart.end;
    if (moveStart) {
      newStart += signedStep;
    } else {
      newEnd += signedStep;
    }

    if (moveStart && index == 0) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }
    if (!moveStart && index == _parts.length - 1) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      return;
    }

    final minDuration = const Duration(milliseconds: 100);
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
        newEnd.inMilliseconds - newStart.inMilliseconds < minDuration.inMilliseconds) {
      _showSnack(l10n.mediaCutterInvalidSplitPoint);
      unawaited(_logMediaCutter(
        'advanced part edit rejected too close index=$index moveStart=$moveStart direction=$direction ' 
        'step=${_logPreciseDuration(step)} ' 
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
      'step=${_logPreciseDuration(step)} ' 
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
    await _seekTo(cutStart, clearPreview: true);
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
    final before = _parts[index];
    await _showPartEffectsDialog(index, applyToWholeFile: true);
    if (!mounted || index >= _parts.length) return;
    final source = _parts[index];
    final changed = before.volumePercent != source.volumePercent ||
        before.effect != source.effect ||
        before.secondaryEffect != source.secondaryEffect ||
        before.thirdEffect != source.thirdEffect ||
        before.fourthEffect != source.fourthEffect ||
        before.effectAmountPercent != source.effectAmountPercent ||
        before.secondaryEffectAmountPercent !=
            source.secondaryEffectAmountPercent ||
        before.thirdEffectAmountPercent != source.thirdEffectAmountPercent ||
        before.fourthEffectAmountPercent != source.fourthEffectAmountPercent;
    unawaited(_logMediaCutter(
      'guided effects ${changed ? 'applied' : 'closed without changes'} '
      'to whole file volume=${source.volumePercent}% '
      'effect=${source.effect.name}:${source.effectAmountPercent}% '
      'secondary=${source.secondaryEffect.name}:'
      '${source.secondaryEffectAmountPercent}% '
      'third=${source.thirdEffect.name}:${source.thirdEffectAmountPercent}% '
      'fourth=${source.fourthEffect.name}:'
      '${source.fourthEffectAmountPercent}%',
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
    required int slotNumber,
    required _MediaPartEffect value,
    required String label,
    required ValueChanged<_MediaPartEffect> onChanged,
    required String Function() debugSlotsSnapshot,
    required int Function() debugVisibleSlotsSnapshot,
    VoidCallback? onOpen,
    ValueChanged<_MediaPartEffect?>? onDialogClosed,
  }) {
    final selectedLabel = _effectLabel(l10n, value);
    final buttonLabel = value == _MediaPartEffect.none
        ? label
        : '$label $selectedLabel';

    Future<void> activateSlot(String source) async {
      unawaited(_logMediaCutter(
        'effect slot activated source=$source slot=$slotNumber '
        'title="$label" label="$buttonLabel" current=${value.name} '
        'visibleSlots=${debugVisibleSlotsSnapshot()} '
        'slots=${debugSlotsSnapshot()}',
      ));
      onOpen?.call();
      final selected = await _showEffectPickerDialog(
        l10n,
        title: label,
        current: value,
      );
      unawaited(_logMediaCutter(
        selected == null
            ? 'effect slot dialog returned slot=$slotNumber selected=null '
                'title="$label" current=${value.name} '
                'slots=${debugSlotsSnapshot()}'
            : 'effect slot dialog returned slot=$slotNumber selected=${selected.name} '
                'title="$label" current=${value.name} '
                'slots=${debugSlotsSnapshot()}',
      ));
      onDialogClosed?.call(selected);
      if (selected == null) return;
      onChanged(selected);
    }

    // Important for VoiceOver: the semantics node itself owns the tap action.
    // If only the visual OutlinedButton receives the tap, iOS can keep focus on
    // the newly inserted empty slot after slot 1 is filled and then open slot 2
    // even when the user is trying to re-open slot 1. Binding the semantics tap
    // directly to this slot keeps title, selected value and saved slot aligned.
    return Semantics(
      key: ValueKey('media-cutter-effect-slot-semantics-$slotNumber'),
      container: true,
      button: true,
      label: buttonLabel,
      onTap: () => unawaited(activateSlot('semantics')),
      child: ExcludeSemantics(
        child: OutlinedButton(
          key: ValueKey('media-cutter-effect-slot-button-$slotNumber'),
          onPressed: () => unawaited(activateSlot('button')),
          child: Row(
            children: [
              Expanded(child: Text(buttonLabel)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
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

  Future<void> _showPartEffectsDialog(int index, {bool applyToWholeFile = false}) async {
    if (_saving || index < 0 || index >= _parts.length || !_parts[index].keep) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final part = _parts[index];
    var volumePercent = part.volumePercent;
    var effectSlots = _normalizedEffectSlots(_effectSlotsForPart(part));
    unawaited(_logMediaCutter(
      'effects dialog opened index=$index applyToWholeFile=$applyToWholeFile '
      'volume=$volumePercent% slots=${_logEffectSlots(effectSlots)} '
      'visibleSlots=${_visibleEffectSlots(effectSlots)}',
    ));

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
                    final visibleSlots = _visibleEffectSlots(effectSlots);
                    final children = <Widget>[];

                    void setEffectSlot(int slot, _MediaPartEffect value) {
                      final beforeSlots = [...effectSlots];
                      final beforeValue = beforeSlots[slot].effect;
                      final updated = [...effectSlots];
                      updated[slot] = updated[slot].copyWith(effect: value);
                      // Slot fixed: tapping "Audio effect 1" always edits slot 1.
                      // Clearing a slot compacts both the effect and its own amount.
                      effectSlots = value == _MediaPartEffect.none
                          ? _normalizedEffectSlots(updated)
                          : updated;
                      final action = beforeValue == _MediaPartEffect.none
                          ? (value == _MediaPartEffect.none
                              ? 'empty_kept_empty'
                              : 'created')
                          : (value == _MediaPartEffect.none
                              ? 'cleared'
                              : 'modified');
                      unawaited(_logMediaCutter(
                        'effect slot changed action=$action slot=${slot + 1} '
                        'from=${beforeValue.name} to=${value.name} '
                        'beforeSlots=${_logEffectSlots(beforeSlots)} '
                        'afterSlots=${_logEffectSlots(effectSlots)} '
                        'beforeVisible=${_visibleEffectSlots(beforeSlots)} '
                        'afterVisible=${_visibleEffectSlots(effectSlots)}',
                      ));
                    }

                    for (var slot = 0; slot < visibleSlots; slot++) {
                      if (children.isNotEmpty) {
                        children.add(const SizedBox(height: 12));
                      }
                      final fixedSlot = slot;
                      final slotNumber = fixedSlot + 1;
                      children.add(KeyedSubtree(
                        key: ValueKey(
                          'media-cutter-effect-slot-wrapper-$slotNumber',
                        ),
                        child: _buildEffectPicker(
                          l10n,
                          slotNumber: slotNumber,
                          value: effectSlots[fixedSlot].effect,
                          label: _effectSlotLabel(l10n, slotNumber),
                          debugSlotsSnapshot: () =>
                              _logEffectSlots(effectSlots),
                          debugVisibleSlotsSnapshot: () =>
                              _visibleEffectSlots(effectSlots),
                          onOpen: () => unawaited(_logMediaCutter(
                            'effect slot picker opened slot=$slotNumber '
                            'current=${effectSlots[fixedSlot].effect.name} '
                            'visibleSlots=${_visibleEffectSlots(effectSlots)} '
                            'slots=${_logEffectSlots(effectSlots)}',
                          )),
                          onDialogClosed: (selected) =>
                              unawaited(_logMediaCutter(
                            selected == null
                                ? 'effect slot picker cancelled '
                                    'slot=$slotNumber '
                                    'current=${effectSlots[fixedSlot].effect.name} '
                                    'slots=${_logEffectSlots(effectSlots)}'
                                : 'effect slot picker selected '
                                    'slot=$slotNumber '
                                    'from=${effectSlots[fixedSlot].effect.name} '
                                    'to=${selected.name} '
                                    'slotsBeforeApply=${_logEffectSlots(effectSlots)}',
                          )),
                          onChanged: (value) => setDialogState(
                            () => setEffectSlot(fixedSlot, value),
                          ),
                        ),
                      ));

                      final selectedEffect = effectSlots[fixedSlot].effect;
                      if (selectedEffect != _MediaPartEffect.none) {
                        final amount = effectSlots[fixedSlot].amountPercent;
                        final amountLabel =
                            '${_effectSlotLabel(l10n, slotNumber)}, '
                            '${_effectLabel(l10n, selectedEffect)}, '
                            '${l10n.mediaCutterPartEffectAmountValue(amount)}';
                        children.add(const SizedBox(height: 6));
                        children.add(ExcludeSemantics(
                          child: Text(amountLabel),
                        ));
                        children.add(Semantics(
                          slider: true,
                          label: amountLabel,
                          value: '$amount%',
                          increasedValue:
                              '${(amount + 10).clamp(0, 100)}%',
                          decreasedValue:
                              '${(amount - 10).clamp(0, 100)}%',
                          onIncrease: () => setDialogState(() {
                            final current =
                                effectSlots[fixedSlot].amountPercent;
                            effectSlots[fixedSlot] = effectSlots[fixedSlot]
                                .copyWith(
                              amountPercent:
                                  (current + 10).clamp(0, 100).toInt(),
                            );
                          }),
                          onDecrease: () => setDialogState(() {
                            final current =
                                effectSlots[fixedSlot].amountPercent;
                            effectSlots[fixedSlot] = effectSlots[fixedSlot]
                                .copyWith(
                              amountPercent:
                                  (current - 10).clamp(0, 100).toInt(),
                            );
                          }),
                          child: ExcludeSemantics(
                            child: Slider(
                              value: amount.toDouble(),
                              min: 0,
                              max: 100,
                              divisions: 10,
                              label: '$amount%',
                              onChanged: (value) => setDialogState(() {
                                effectSlots[fixedSlot] =
                                    effectSlots[fixedSlot].copyWith(
                                  amountPercent: value.round(),
                                );
                              }),
                            ),
                          ),
                        ));
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => unawaited(
                    _playPartEffectsPreview(
                      index,
                      volumePercent: volumePercent,
                      effect: effectSlots[0].effect,
                      secondaryEffect: effectSlots[1].effect,
                      thirdEffect: effectSlots[2].effect,
                      fourthEffect: effectSlots[3].effect,
                      effectAmountPercent: effectSlots[0].amountPercent,
                      secondaryEffectAmountPercent:
                          effectSlots[1].amountPercent,
                      thirdEffectAmountPercent:
                          effectSlots[2].amountPercent,
                      fourthEffectAmountPercent:
                          effectSlots[3].amountPercent,
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
                unawaited(_logMediaCutter(
                  'effects dialog cancelled index=$index applyToWholeFile=$applyToWholeFile '
                  'slots=${_logEffectSlots(effectSlots)} '
                  'visibleSlots=${_visibleEffectSlots(effectSlots)}',
                ));
                unawaited(_stopRenderedEffectsPreview());
                Navigator.pop(dialogContext);
              },
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                unawaited(_stopRenderedEffectsPreview());
                final normalizedSlots = _normalizedEffectSlots(effectSlots);
                unawaited(_logMediaCutter(
                  'effects dialog confirmed index=$index applyToWholeFile=$applyToWholeFile '
                  'rawSlots=${_logEffectSlots(effectSlots)} '
                  'normalizedSlots=${_logEffectSlots(normalizedSlots)} '
                  'visibleSlots=${_visibleEffectSlots(effectSlots)} '
                  'volume=$volumePercent%',
                ));
                Navigator.pop(
                  dialogContext,
                  _PartEffectSettings(
                    volumePercent: volumePercent,
                    effect: normalizedSlots[0].effect,
                    secondaryEffect: normalizedSlots[1].effect,
                    thirdEffect: normalizedSlots[2].effect,
                    fourthEffect: normalizedSlots[3].effect,
                    effectAmountPercent: normalizedSlots[0].amountPercent,
                    secondaryEffectAmountPercent:
                        normalizedSlots[1].amountPercent,
                    thirdEffectAmountPercent:
                        normalizedSlots[2].amountPercent,
                    fourthEffectAmountPercent:
                        normalizedSlots[3].amountPercent,
                  ),
                );
              },
              child: Text(l10n.ok),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) {
      unawaited(_logMediaCutter(
        'effects dialog closed without applying index=$index '
        'applyToWholeFile=$applyToWholeFile resultNull=${result == null} '
        'mounted=$mounted',
      ));
      return;
    }
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
              secondaryEffectAmountPercent:
                  result.secondaryEffectAmountPercent,
              thirdEffectAmountPercent: result.thirdEffectAmountPercent,
              fourthEffectAmountPercent: result.fourthEffectAmountPercent,
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
      'part effects applied index=$index applyToWholeFile=$applyToWholeFile '
      'volume=${result.volumePercent}% '
      'effect=${result.effect.name}:${result.effectAmountPercent}% '
      'secondary=${result.secondaryEffect.name}:'
      '${result.secondaryEffectAmountPercent}% '
      'third=${result.thirdEffect.name}:${result.thirdEffectAmountPercent}% '
      'fourth=${result.fourthEffect.name}:'
      '${result.fourthEffectAmountPercent}%',
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
        final usesUnderwaterBubbles = _usesUnderwaterBubbles(part);
        final String? filter = usesUnderwaterBubbles
            ? _underwaterAudioFilterForPart(part)
            : _audioFilterForPart(part);
        final String? audioFilter = filter;
        final args = <String>[
          '-y',
          '-ss',
          _ffmpegTime(part.start),
          '-i',
          input,
        ];
        if (usesUnderwaterBubbles) {
          args.addAll([
            '-stream_loop',
            '-1',
            '-i',
            await _ensureUnderwaterBubblesSourcePath(),
          ]);
        }
        args.addAll([
          '-t',
          _ffmpegTime(part.duration),
        ]);
        if (_isVideoInput(input)) {
          args.addAll([
            '-map',
            '0:v:0?',
          ]);
        }
        if (usesUnderwaterBubbles) {
          args.addAll([
            '-filter_complex',
            audioFilter!,
            '-map',
            '[outa]',
          ]);
        } else {
          args.addAll([
            '-map',
            '0:a:0?',
            '-vn',
            '-sn',
            '-dn',
          ]);
          if (audioFilter != null) {
            args.addAll([
              '-filter:a',
              audioFilter,
            ]);
          }
        }
        final videoFilter = _videoFilter();
        if (videoFilter != null) {
          args.addAll([
            '-filter:v',
            videoFilter,
          ]);
        }
        args.addAll([
          ..._codecArguments(input),
          '-avoid_negative_ts',
          'make_zero',
          segment,
        ]);
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

  bool get _isPlayerActuallyPlaying => _isVideo
      ? (_videoController?.value.isPlaying ?? _playing)
      : (_audioPlayer.playing || _playing);

  void _cancelDeletedSkipTimer() {
    _deletedSkipTimer?.cancel();
    _deletedSkipTimer = null;
    _scheduledDeletedSkipBoundary = null;
    _scheduledDeletedSkipTarget = null;
  }

  void _scheduleDeletedPartSkipTimer({Duration? fromPosition}) {
    if (!_hasDeletedParts || !_isPlayerActuallyPlaying || _previewPartEnd != null ||
        _skippingDeletedPart) {
      return;
    }
    final position = _clampPosition(fromPosition ?? _position);
    for (var index = 0; index < _parts.length; index++) {
      final part = _parts[index];
      if (!part.keep) continue;
      if (position < part.start || position >= part.end) continue;
      final nextIndex = index + 1;
      if (nextIndex >= _parts.length || _parts[nextIndex].keep) {
        if (_scheduledDeletedSkipBoundary != null) _cancelDeletedSkipTimer();
        return;
      }

      var target = _parts[nextIndex].end;
      for (var scan = nextIndex + 1; scan < _parts.length; scan++) {
        if (_parts[scan].keep) break;
        target = _parts[scan].end;
      }

      final boundary = part.end;
      if (_scheduledDeletedSkipBoundary == boundary &&
          _scheduledDeletedSkipTarget == target &&
          _deletedSkipTimer != null) {
        return;
      }
      _cancelDeletedSkipTimer();
      _scheduledDeletedSkipBoundary = boundary;
      _scheduledDeletedSkipTarget = target;
      final delayMs = boundary.inMilliseconds - position.inMilliseconds;
      final delay = Duration(milliseconds: delayMs <= 0 ? 1 : delayMs);
      unawaited(_logMediaCutter(
        'playback skip scheduled boundary=${_logPreciseDuration(boundary)} '
        'target=${_logPreciseDuration(target)} delayMs=${delay.inMilliseconds} '
        '${_logPlaybackState()}',
      ));
      _deletedSkipTimer = Timer(delay, () {
        _deletedSkipTimer = null;
        _scheduledDeletedSkipBoundary = null;
        _scheduledDeletedSkipTarget = null;
        if (!mounted || _previewPartEnd != null || !_isPlayerActuallyPlaying) return;
        unawaited(_skipDeletedPartDuringPlayback(target));
      });
      return;
    }
  }

  void _checkDeletedPartDuringPlayback(Duration position) {
    if (_skippingDeletedPart || _previewPartEnd != null || !_isPlayerActuallyPlaying) return;
    final target = _skipDeletedPartsForward(position);
    if (target == position) return;
    unawaited(_skipDeletedPartDuringPlayback(target));
  }

  Future<void> _skipDeletedPartDuringPlayback(Duration target) async {
    if (_skippingDeletedPart) return;
    _cancelDeletedSkipTimer();
    _skippingDeletedPart = true;
    try {
      unawaited(_logMediaCutter(
        'playback skipped deleted part target=${_logPreciseDuration(target)} '
        '${_logPlaybackState()}',
      ));
      await _seekTo(target, clearPreview: false);
      if (target >= _duration) await _pause();
    } finally {
      _skippingDeletedPart = false;
      if (mounted && _isPlayerActuallyPlaying && _previewPartEnd == null) {
        _scheduleDeletedPartSkipTimer(fromPosition: target);
      }
    }
  }

  String? _audioFilterForPart(
    _MediaPart part, {
    Set<_MediaPartEffect> skipEffects = const {},
  }) {
    final filters = <String>[];
    if (part.volumePercent != 100) {
      filters.add('volume=${part.volumeFactor.toStringAsFixed(3)}');
    }

    for (final slot in _activeEffectSlots(part)) {
      if (skipEffects.contains(slot.effect)) continue;
      final amount = slot.amountPercent.clamp(0, 100) / 100.0;
      final filter = _audioFilterForEffect(slot.effect, part, amount);
      if (filter != null) filters.add(filter);
    }

    if (filters.isEmpty) return null;
    return filters.join(',');
  }

  String? _underwaterAudioFilterForPart(_MediaPart part) {
    final baseFilter = _audioFilterForPart(
      part,
      skipEffects: {_MediaPartEffect.underwater},
    );
    final underwaterSlot = _activeEffectSlots(part).firstWhere(
      (slot) =>
          slot.effect == _MediaPartEffect.underwater &&
          slot.amountPercent > 0,
      orElse: () => const _MediaEffectSlot(
        effect: _MediaPartEffect.underwater,
        amountPercent: 50,
      ),
    );
    final amount = underwaterSlot.amountPercent.clamp(0, 100) / 100.0;
    final lowpass = (1300 - 650 * amount).round().clamp(550, 1300);
    final delay1 = (50 + 50 * amount).round();
    final delay2 = (110 + 70 * amount).round();
    final decay1 = (0.12 + 0.12 * amount).toStringAsFixed(2);
    final decay2 = (0.08 + 0.10 * amount).toStringAsFixed(2);
    final voiceFilter = [
      if (baseFilter != null && baseFilter.isNotEmpty) baseFilter,
      'lowpass=f=$lowpass',
      'aecho=0.75:0.55:$delay1|$delay2:$decay1|$decay2',
    ].join(',');
    return '[0:a:0]$voiceFilter[uwVoice];'
        '[1:a:0]aresample=44100,highpass=f=55,lowpass=f=7000,'
        'volume=${(0.03 + 0.14 * amount).toStringAsFixed(3)}[uwBubbles];'
        '[uwVoice][uwBubbles]amix=inputs=2:normalize=0:duration=first,'
        'acompressor=threshold=-18dB:ratio=2.5:attack=6:release=140,'
        'alimiter=limit=0.90[outa]';
  }

  List<_MediaPartEffect> _activeEffects(_MediaPart part) =>
      _activeEffectSlots(part).map((slot) => slot.effect).toList();

  bool _usesUnderwaterBubbles(_MediaPart part) =>
      _activeEffectSlots(part).any(
        (slot) =>
            slot.effect == _MediaPartEffect.underwater &&
            slot.amountPercent > 0,
      );

  String? _audioFilterForEffect(
    _MediaPartEffect effect,
    _MediaPart part,
    double amount,
  ) {
    if (amount <= 0.0001) return null;
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
        final irAmplitude = (0.06 + 0.18 * amount).toStringAsFixed(3);
        final dryVolume = (1.00 - 0.48 * amount).toStringAsFixed(3);
        final wetVolume = (0.16 + 1.02 * amount).toStringAsFixed(3);
        final widenFeedback = (0.02 + 0.14 * amount).toStringAsFixed(3);
        final widenCrossfeed = (0.03 + 0.13 * amount).toStringAsFixed(3);
        final tail1 = (0.04 + 0.26 * amount).toStringAsFixed(3);
        final tail2 = (0.03 + 0.19 * amount).toStringAsFixed(3);
        final tail3 = (0.02 + 0.12 * amount).toStringAsFixed(3);
        return 'aresample=44100,asplit=2[cat2Dry][cat2Wet];'
            "aevalsrc=exprs='if(eq(n,0),1,(2*random(0)-1)*$irAmplitude*"
            "exp(-t/1.85))':s=44100:d=4.8:c=mono,"
            'highpass=f=80,lowpass=f=7200[cat2IR];'
            '[cat2Wet]adelay=58:all=1,'
            'aecho=0.86:0.66:65|138|245:0.38|0.28|0.20[cat2Pre];'
            '[cat2Pre][cat2IR]afir=dry=0:wet=1:length=1:irnorm=0.65:'
            'irfmt=mono:maxir=6,highpass=f=90,lowpass=f=7600,'
            'stereowiden=delay=25:feedback=$widenFeedback:'
            'crossfeed=$widenCrossfeed:drymix=0.82,'
            'volume=$wetVolume[cat2Verb];'
            '[cat2Dry]volume=$dryVolume[cat2Voice];'
            '[cat2Voice][cat2Verb]amix=inputs=2:normalize=0,'
            'aecho=0.82:0.78:420|840|1260:$tail1|$tail2|$tail3,'
            'equalizer=f=2400:t=q:w=1.2:g=${(1.5 * amount).toStringAsFixed(2)},'
            'acompressor=threshold=-19dB:'
            'ratio=${(1.2 + 1.8 * amount).toStringAsFixed(2)}:'
            'attack=8:release=220,alimiter=limit=0.88';
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
        final highFactor = 1.0 + 0.260 * amount;
        final lowFactor = 1.0 - 0.159 * amount;
        final doubleFactor = 1.0 + 0.018 * amount;
        final centerVolume = (1.0 - 0.05 * amount).toStringAsFixed(3);
        final highVolume = (0.58 * amount).toStringAsFixed(3);
        final lowVolume = (0.52 * amount).toStringAsFixed(3);
        final doubleVolume = (0.38 * amount).toStringAsFixed(3);
        final chorusOut = (0.08 + 0.60 * amount).toStringAsFixed(3);
        final depth1 = (0.36 * amount).toStringAsFixed(3);
        final depth2 = (0.29 * amount).toStringAsFixed(3);
        final depth3 = (0.23 * amount).toStringAsFixed(3);
        return 'aresample=44100,asplit=4[center][high][low][double];'
            '[center]volume=$centerVolume[c];'
            '[high]asetrate=44100*${highFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / highFactor).toStringAsFixed(6)},'
            'adelay=12:all=1,pan=stereo|FL=0.20*FL|FR=0.85*FR,'
            'volume=$highVolume[h];'
            '[low]asetrate=44100*${lowFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / lowFactor).toStringAsFixed(6)},'
            'adelay=20:all=1,pan=stereo|FL=0.85*FL|FR=0.20*FR,'
            'volume=$lowVolume[l];'
            '[double]asetrate=44100*${doubleFactor.toStringAsFixed(6)},'
            'aresample=44100,'
            'atempo=${(1 / doubleFactor).toStringAsFixed(6)},'
            'adelay=32:all=1,volume=$doubleVolume[d];'
            '[c][h][l][d]amix=inputs=4:normalize=0,'
            'chorus=0.72:$chorusOut:16|29|44:'
            '$depth1|$depth2|$depth3:0.25|0.43|0.62:2.8|3.8|4.8,'
            'highpass=f=90,'
            'equalizer=f=2800:t=q:w=1.2:g=${(2 * amount).toStringAsFixed(2)},'
            'acompressor=threshold=-18dB:'
            'ratio=${(1.2 + 1.8 * amount).toStringAsFixed(2)}:'
            'attack=8:release=140,alimiter=limit=0.88';
      case _MediaPartEffect.pitchLow:
        return _pitchFilter(0.85, amount);
      case _MediaPartEffect.pitchVeryLow:
        return _pitchFilter(0.75, amount);
      case _MediaPartEffect.pitchHigh:
        return _pitchFilter(1.15, amount);
      case _MediaPartEffect.pitchVeryHigh:
        return _pitchFilter(1.30, amount);
      case _MediaPartEffect.robot:
        final blend = amount.toStringAsFixed(4);
        final eqGain = (2.5 * amount).toStringAsFixed(2);
        final ratio = (1.0 + 1.2 * amount).toStringAsFixed(2);
        return 'highpass=f=${(40 + 60 * amount).round()},'
            'lowpass=f=${(18000 - 9500 * amount).round()},'
            "afftfilt=real='(1-$blend)*re+$blend*hypot(re,im)':"
            "imag='(1-$blend)*im':win_size=512:win_func=hann:"
            'overlap=0.75,equalizer=f=2400:t=q:w=1.4:g=$eqGain,'
            'acompressor=threshold=-14dB:ratio=$ratio:'
            'attack=8:release=100,alimiter=limit=0.92';
      case _MediaPartEffect.superRobot:
        final blend = amount.toStringAsFixed(4);
        final spectralFloor = (1.0 - 0.82 * amount).toStringAsFixed(4);
        final spectralDepth = (0.82 * amount).toStringAsFixed(4);
        final spectralPower = (2.0 + 8.0 * amount).toStringAsFixed(2);
        final chorusDepth1 = (0.22 * amount).toStringAsFixed(3);
        final chorusDepth2 = (0.16 * amount).toStringAsFixed(3);
        return 'highpass=f=${(40 + 60 * amount).round()},'
            'lowpass=f=${(18000 - 9000 * amount).round()},'
            "afftfilt=real='(1-$blend)*re+$blend*hypot(re,im)*"
            "($spectralFloor+$spectralDepth*"
            "pow(abs(cos(PI*b*sr/(2*nb*110))),$spectralPower))':"
            "imag='(1-$blend)*im':win_size=1024:win_func=hann:"
            'overlap=0.80,'
            'equalizer=f=1800:t=q:w=1.2:g=${(4 * amount).toStringAsFixed(2)},'
            'equalizer=f=4200:t=q:w=1.0:g=${(3 * amount).toStringAsFixed(2)},'
            'chorus=0.76:${(0.08 + 0.56 * amount).toStringAsFixed(3)}:'
            '8|14:$chorusDepth1|$chorusDepth2:0.32|0.48:1.4|2.0,'
            'acompressor=threshold=-18dB:'
            'ratio=${(1.2 + 2.3 * amount).toStringAsFixed(2)}:'
            'attack=4:release=90:makeup=${(1 + 0.25 * amount).toStringAsFixed(3)},'
            'alimiter=limit=0.90';
      case _MediaPartEffect.helicopter:
        final frequency = (6 + 12 * amount).toStringAsFixed(2);
        final depth = (0.45 + 0.50 * amount).toStringAsFixed(2);
        return 'tremolo=f=$frequency:d=$depth';
      case _MediaPartEffect.alien:
        final warlordFactor = 1.0 - 0.180 * amount;
        final clearFactor = 1.0 - 0.120 * amount;
        final signalFactor = 1.0 + 0.180 * amount;
        final spectralBlend = amount.toStringAsFixed(4);
        final warlordVolume = (0.15 + 0.67 * amount).toStringAsFixed(3);
        final clearVolume = (0.85 - 0.51 * amount).toStringAsFixed(3);
        final signalVolume = (0.20 * amount).toStringAsFixed(3);
        return 'aresample=44100,'
            'asplit=3[alienWarlord][alienClear][alienSignal];'
            '[alienWarlord]asetrate=44100*${warlordFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / warlordFactor).toStringAsFixed(6)},'
            "afftfilt=real='(1-$spectralBlend)*re+$spectralBlend*"
            "hypot(re,im)*(0.30+0.70*"
            "pow(abs(cos(PI*b*sr/(2*nb*95))),8))':"
            "imag='(1-$spectralBlend)*im':"
            'win_size=768:win_func=hann:overlap=0.80,'
            'equalizer=f=380:t=q:w=1.1:g=${(4 * amount).toStringAsFixed(2)},'
            'volume=$warlordVolume[alienW];'
            '[alienClear]asetrate=44100*${clearFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / clearFactor).toStringAsFixed(6)},'
            'highpass=f=${(40 + 60 * amount).round()},'
            'lowpass=f=${(16000 - 9500 * amount).round()},'
            'equalizer=f=2600:t=q:w=1.2:g=${(3 * amount).toStringAsFixed(2)},'
            'volume=$clearVolume[alienC];'
            '[alienSignal]asetrate=44100*${signalFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / signalFactor).toStringAsFixed(6)},'
            'highpass=f=900,tremolo=f=7.2:'
            'd=${(0.42 * amount).toStringAsFixed(3)},'
            'adelay=24:all=1,volume=$signalVolume[alienS];'
            '[alienW][alienC][alienS]amix=inputs=3:normalize=0,'
            'flanger=delay=${(0.5 + 2.0 * amount).toStringAsFixed(2)}:'
            'depth=${(0.3 + 3.5 * amount).toStringAsFixed(2)}:'
            'regen=${(16 * amount).toStringAsFixed(2)}:'
            'width=${(10 + 52 * amount).toStringAsFixed(2)}:'
            'speed=${(0.10 + 0.12 * amount).toStringAsFixed(2)}:'
            'shape=sinusoidal:phase=45:interp=quadratic,'
            'aecho=0.86:0.55:95|185:'
            '${(0.17 * amount).toStringAsFixed(3)}|'
            '${(0.09 * amount).toStringAsFixed(3)},'
            'equalizer=f=2100:t=q:w=1.0:g=${(3 * amount).toStringAsFixed(2)},'
            'acompressor=threshold=-18dB:'
            'ratio=${(1.2 + 2.0 * amount).toStringAsFixed(2)}:'
            'attack=5:release=110,alimiter=limit=0.88';
      case _MediaPartEffect.brightVoice:
        final gain = (3 + 6 * amount).toStringAsFixed(2);
        return 'equalizer=f=3500:t=q:w=1.0:g=$gain,highpass=f=120';
      case _MediaPartEffect.darkVoice:
        final gain = (3 + 6 * amount).toStringAsFixed(2);
        return 'equalizer=f=180:t=q:w=1.0:g=$gain,lowpass=f=4200';
      case _MediaPartEffect.ghost:
        final pitch = (0.98 - 0.08 * amount).toStringAsFixed(3);
        final tempo = (1 / (0.98 - 0.08 * amount)).toStringAsFixed(6);
        final highpass = (90 + 130 * amount).round();
        final lowpass = (7600 - 2400 * amount).round().clamp(5000, 7600);
        final lowGain = (1.5 + 3.5 * amount).toStringAsFixed(2);
        final metalGain = (2.5 + 5.5 * amount).toStringAsFixed(2);
        final flangerDelay = (1.2 + 2.4 * amount).toStringAsFixed(2);
        final flangerDepth = (1.6 + 3.8 * amount).toStringAsFixed(2);
        final flangerRegen = (8 + 24 * amount).toStringAsFixed(1);
        final flangerWidth = (42 + 38 * amount).toStringAsFixed(1);
        final flangerSpeed = (0.13 + 0.16 * amount).toStringAsFixed(2);
        final tremoloFrequency = (3.2 + 2.4 * amount).toStringAsFixed(2);
        final tremoloDepth = (0.08 + 0.28 * amount).toStringAsFixed(2);
        final delay1 = (110 + 50 * amount).round();
        final delay2 = (330 + 170 * amount).round();
        final delay3 = (680 + 320 * amount).round();
        final decay1 = (0.18 + 0.18 * amount).toStringAsFixed(2);
        final decay2 = (0.12 + 0.18 * amount).toStringAsFixed(2);
        final decay3 = (0.08 + 0.16 * amount).toStringAsFixed(2);
        return 'aresample=44100,asetrate=44100*$pitch,aresample=44100,'
            'atempo=$tempo,highpass=f=$highpass:p=2,'
            'lowpass=f=$lowpass:p=2,'
            'equalizer=f=430:t=q:w=1.1:g=$lowGain,'
            'equalizer=f=2350:t=q:w=0.85:g=$metalGain,'
            'flanger=delay=$flangerDelay:depth=$flangerDepth:'
            'regen=$flangerRegen:width=$flangerWidth:speed=$flangerSpeed:'
            'shape=sinusoidal:phase=55:interp=quadratic,'
            'tremolo=f=$tremoloFrequency:d=$tremoloDepth,'
            'aecho=0.78:0.78:$delay1|$delay2|$delay3:'
            '$decay1|$decay2|$decay3,'
            'acompressor=threshold=-20dB:ratio=3.4:attack=5:release=150:'
            'makeup=1.35,asoftclip=type=tanh:threshold=0.86:output=0.90,'
            'alimiter=limit=0.90';
      case _MediaPartEffect.telephone:
        final highpass = (60 + 260 * amount).round();
        final lowpass = (16000 - 12600 * amount).round();
        final gain1 = (5 * amount).toStringAsFixed(2);
        final gain2 = (4.5 * amount).toStringAsFixed(2);
        final ratio = (1.0 + 4.0 * amount).toStringAsFixed(2);
        final makeup = (1.0 + 0.4 * amount).toStringAsFixed(2);
        final outputVolume = (1.0 + 0.35 * amount).toStringAsFixed(2);
        final clipThreshold = (0.98 - 0.16 * amount).toStringAsFixed(2);
        return 'highpass=f=$highpass:p=2,lowpass=f=$lowpass:p=2,'
            'equalizer=f=850:t=q:w=1.1:g=$gain1,'
            'equalizer=f=2100:t=q:w=1.0:g=$gain2,'
            'acompressor=threshold=-20dB:ratio=$ratio:attack=3:release=70:'
            'makeup=$makeup,volume=$outputVolume,'
            'asoftclip=type=tanh:threshold=$clipThreshold:output=0.82,'
            'alimiter=limit=0.90';
      case _MediaPartEffect.oldRadio:
        final highpass = (220 + 180 * amount).round();
        final lowpass = (3600 - 1600 * amount).round().clamp(1800, 3600);
        final bits = (10 - 6 * amount).round().clamp(4, 10);
        final crushMix = (0.55 + 0.40 * amount).toStringAsFixed(2);
        final midGain = (5.0 + 6.0 * amount).toStringAsFixed(2);
        final upperGain = (2.0 + 5.0 * amount).toStringAsFixed(2);
        final ratio = (3.5 + 5.0 * amount).toStringAsFixed(2);
        final vibratoDepth = (0.025 + 0.090 * amount).toStringAsFixed(3);
        final tremoloDepth = (0.06 + 0.20 * amount).toStringAsFixed(2);
        return 'aresample=44100,pan=mono|c0=0.5*c0+0.5*c1,'
            'highpass=f=$highpass:p=2,lowpass=f=$lowpass:p=2,'
            'equalizer=f=900:t=q:w=0.9:g=$midGain,'
            'equalizer=f=2200:t=q:w=1.0:g=$upperGain,'
            'acrusher=level_in=1:level_out=1:bits=$bits:mix=$crushMix:'
            'mode=log:aa=0.85:samples=2,'
            'acompressor=threshold=-24dB:ratio=$ratio:attack=3:release=90:'
            'makeup=2.2,vibrato=f=4.5:d=$vibratoDepth,'
            'tremolo=f=0.85:d=$tremoloDepth,'
            'asoftclip=type=tanh:threshold=0.72:output=0.82,'
            'volume=1.25,alimiter=limit=0.90,'
            'pan=stereo|FL=c0|FR=c0';
      case _MediaPartEffect.megaphone:
        final voiceHighpass = (70 + 290 * amount).round();
        final voiceLowpass = (16000 - 9900 * amount).round();
        final voiceVolume = (1.0 - 0.18 * amount).toStringAsFixed(3);
        final metalVolume = (0.30 * amount).toStringAsFixed(3);
        final echo1 = (0.30 * amount).toStringAsFixed(3);
        final echo2 = (0.17 * amount).toStringAsFixed(3);
        return 'pan=mono|c0=0.5*c0+0.5*c1,'
            'asplit=2[mega3Voice][mega3Metal];'
            '[mega3Voice]highpass=f=$voiceHighpass:p=2,'
            'lowpass=f=$voiceLowpass:p=2,'
            'equalizer=f=1050:t=q:w=0.85:g=${(6 * amount).toStringAsFixed(2)},'
            'equalizer=f=2350:t=q:w=0.9:g=${(5 * amount).toStringAsFixed(2)},'
            'equalizer=f=4100:t=q:w=1.1:g=${(3 * amount).toStringAsFixed(2)},'
            'volume=$voiceVolume[mega3V];'
            '[mega3Metal]highpass=f=520,lowpass=f=5800,'
            "afftfilt=real='hypot(re,im)':imag='0':"
            'win_size=384:win_func=hann:overlap=0.75,'
            'aecho=0.80:0.72:5|11|20:'
            '${(0.54 * amount).toStringAsFixed(3)}|'
            '${(0.41 * amount).toStringAsFixed(3)}|'
            '${(0.28 * amount).toStringAsFixed(3)},'
            'volume=$metalVolume[mega3M];'
            '[mega3V][mega3M]amix=inputs=2:normalize=0,'
            'flanger=delay=${(0.4 + 1.4 * amount).toStringAsFixed(2)}:'
            'depth=${(0.15 + 1.20 * amount).toStringAsFixed(2)}:'
            'regen=${(27 * amount).toStringAsFixed(2)}:'
            'width=${(8 + 48 * amount).toStringAsFixed(2)}:'
            'speed=${(0.10 + 0.05 * amount).toStringAsFixed(2)}:'
            'shape=sinusoidal:phase=25:interp=quadratic,'
            'aecho=0.86:0.64:118|238:$echo1|$echo2,'
            'acompressor=threshold=-22dB:'
            'ratio=${(1.2 + 3 * amount).toStringAsFixed(2)}:'
            'attack=3:release=85:makeup=${(1 + 0.5 * amount).toStringAsFixed(2)},'
            'equalizer=f=1800:t=q:w=1.0:g=${(2 * amount).toStringAsFixed(2)},'
            'alimiter=limit=0.88,pan=stereo|FL=c0|FR=c0';
      case _MediaPartEffect.underwater:
        final lowpass = (1300 - 650 * amount).round().clamp(550, 1300);
        final delay1 = (50 + 50 * amount).round();
        final delay2 = (110 + 70 * amount).round();
        final decay1 = (0.12 + 0.12 * amount).toStringAsFixed(2);
        final decay2 = (0.08 + 0.10 * amount).toStringAsFixed(2);
        return 'lowpass=f=$lowpass,'
            'aecho=0.75:0.55:$delay1|$delay2:$decay1|$decay2';
      case _MediaPartEffect.monster:
        final centerFactor = 1.0 - 0.180 * amount;
        final leftFactor = 1.0 - 0.500 * amount;
        final rightFactor = 1.0 - 0.450 * amount;
        final growlFactor = 1.0 - 0.320 * amount;
        final centerVolume = (1.0 - 0.60 * amount).toStringAsFixed(3);
        final leftVolume = (0.78 * amount).toStringAsFixed(3);
        final rightVolume = (0.72 * amount).toStringAsFixed(3);
        final growlVolume = (0.46 * amount).toStringAsFixed(3);
        final spectralBlend = amount.toStringAsFixed(4);
        return 'aresample=44100,'
            'asplit=4[mon2Center][mon2Left][mon2Right][mon2Growl];'
            '[mon2Center]asetrate=44100*${centerFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / centerFactor).toStringAsFixed(6)},'
            'highpass=f=80,lowpass=f=6200,'
            'equalizer=f=2400:t=q:w=1.2:g=${(3.5 * amount).toStringAsFixed(2)},'
            'volume=$centerVolume[mon2C];'
            '[mon2Left]asetrate=44100*${leftFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / leftFactor).toStringAsFixed(6)},'
            "afftfilt=real='(1-$spectralBlend)*re+$spectralBlend*"
            "hypot(re,im)*(0.30+0.70*"
            "pow(abs(cos(PI*b*sr/(2*nb*68))),8))':"
            "imag='(1-$spectralBlend)*im':"
            'win_size=768:win_func=hann:overlap=0.82,lowpass=f=3400,'
            'pan=stereo|FL=1.0*FL|FR=0.08*FR,'
            'volume=$leftVolume[mon2L];'
            '[mon2Right]asetrate=44100*${rightFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / rightFactor).toStringAsFixed(6)},'
            "afftfilt=real='(1-$spectralBlend)*re+$spectralBlend*"
            "hypot(re,im)':imag='(1-$spectralBlend)*im':"
            'win_size=768:win_func=hann:overlap=0.82,lowpass=f=3600,'
            'adelay=24:all=1,pan=stereo|FL=0.08*FL|FR=1.0*FR,'
            'volume=$rightVolume[mon2R];'
            '[mon2Growl]asetrate=44100*${growlFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / growlFactor).toStringAsFixed(6)},'
            'lowpass=f=4200,tremolo=f=18:'
            'd=${(0.48 * amount).toStringAsFixed(3)},'
            'volume=${(1 + 1.2 * amount).toStringAsFixed(2)},'
            'asoftclip=type=tanh:'
            'threshold=${(0.92 - 0.30 * amount).toStringAsFixed(2)}:'
            'output=0.62:oversample=4,volume=$growlVolume[mon2G];'
            '[mon2C][mon2L][mon2R][mon2G]amix=inputs=4:normalize=0,'
            'equalizer=f=150:t=q:w=1.0:g=${(5 * amount).toStringAsFixed(2)},'
            'equalizer=f=2200:t=q:w=1.1:g=${(2.5 * amount).toStringAsFixed(2)},'
            'acompressor=threshold=-22dB:'
            'ratio=${(1.2 + 2.8 * amount).toStringAsFixed(2)}:'
            'attack=4:release=140,alimiter=limit=0.86';
      case _MediaPartEffect.chipmunk:
        final mainFactor = 1.0 + 0.520 * amount;
        final doubleFactor = 1.0 + 0.610 * amount;
        final clearFactor = 1.0 + 0.430 * amount;
        final mainVolume = (1.0 - 0.22 * amount).toStringAsFixed(3);
        final doubleVolume = (0.38 * amount).toStringAsFixed(3);
        final clearVolume = (0.30 * amount).toStringAsFixed(3);
        return 'aresample=44100,'
            'asplit=3[chipMain][chipDouble][chipClear];'
            '[chipMain]asetrate=44100*${mainFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / mainFactor).toStringAsFixed(6)},'
            'highpass=f=${(60 + 70 * amount).round()},'
            'equalizer=f=3600:t=q:w=1.1:g=${(4 * amount).toStringAsFixed(2)},'
            'volume=$mainVolume[chipM];'
            '[chipDouble]asetrate=44100*${doubleFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / doubleFactor).toStringAsFixed(6)},'
            'highpass=f=180,adelay=18:all=1,'
            'pan=stereo|FL=0.35*FL|FR=0.90*FR,'
            'equalizer=f=4800:t=q:w=1.2:g=${(3 * amount).toStringAsFixed(2)},'
            'volume=$doubleVolume[chipD];'
            '[chipClear]asetrate=44100*${clearFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / clearFactor).toStringAsFixed(6)},'
            'adelay=9:all=1,pan=stereo|FL=0.90*FL|FR=0.35*FR,'
            'volume=$clearVolume[chipC];'
            '[chipM][chipD][chipC]amix=inputs=3:normalize=0,'
            'chorus=0.78:${(0.08 + 0.54 * amount).toStringAsFixed(3)}:'
            '10|17:${(0.20 * amount).toStringAsFixed(3)}|'
            '${(0.15 * amount).toStringAsFixed(3)}:'
            '0.36|0.52:1.5|2.1,highpass=f=120,'
            'equalizer=f=5200:t=q:w=1.2:g=${(2.5 * amount).toStringAsFixed(2)},'
            'acompressor=threshold=-18dB:'
            'ratio=${(1.1 + 1.5 * amount).toStringAsFixed(2)}:'
            'attack=4:release=90,alimiter=limit=0.88';
      case _MediaPartEffect.dream:
        final highFactor = 1.0 + 0.498 * amount;
        final lowFactor = 1.0 - 0.251 * amount;
        final shimmerFactor = 1.0 + amount;
        final voiceVolume = (1.0 - 0.42 * amount).toStringAsFixed(3);
        final highVolume = (0.32 * amount).toStringAsFixed(3);
        final lowVolume = (0.28 * amount).toStringAsFixed(3);
        final shimmerVolume = (0.16 * amount).toStringAsFixed(3);
        return 'aresample=44100,'
            'asplit=4[dreamVoice][dreamHigh][dreamLow][dreamShimmer];'
            '[dreamVoice]highpass=f=90,lowpass=f=7600,'
            'equalizer=f=3000:t=q:w=1.2:g=${(2.5 * amount).toStringAsFixed(2)},'
            'volume=$voiceVolume[dreamV];'
            '[dreamHigh]asetrate=44100*${highFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / highFactor).toStringAsFixed(6)},'
            'adelay=28:all=1,pan=stereo|FL=0.25*FL|FR=0.90*FR,'
            'highpass=f=180,volume=$highVolume[dreamH];'
            '[dreamLow]asetrate=44100*${lowFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / lowFactor).toStringAsFixed(6)},'
            'adelay=42:all=1,pan=stereo|FL=0.90*FL|FR=0.25*FR,'
            'lowpass=f=5200,volume=$lowVolume[dreamL];'
            '[dreamShimmer]asetrate=44100*${shimmerFactor.toStringAsFixed(6)},'
            'aresample=44100,atempo=${(1 / shimmerFactor).toStringAsFixed(6)},'
            'adelay=75:all=1,highpass=f=1200,'
            'volume=$shimmerVolume[dreamS];'
            '[dreamV][dreamH][dreamL][dreamS]amix=inputs=4:normalize=0,'
            'chorus=0.76:${(0.08 + 0.58 * amount).toStringAsFixed(3)}:'
            '22|38|56:${(0.30 * amount).toStringAsFixed(3)}|'
            '${(0.24 * amount).toStringAsFixed(3)}|'
            '${(0.18 * amount).toStringAsFixed(3)}:'
            '0.20|0.34|0.49:2.2|3.1|4.0,'
            'aecho=0.76:0.72:240|520|920:'
            '${(0.28 * amount).toStringAsFixed(3)}|'
            '${(0.18 * amount).toStringAsFixed(3)}|'
            '${(0.10 * amount).toStringAsFixed(3)},'
            'tremolo=f=2.8:d=${(0.07 * amount).toStringAsFixed(3)},'
            'stereowiden=delay=18:'
            'feedback=${(0.10 * amount).toStringAsFixed(3)}:'
            'crossfeed=${(0.18 * amount).toStringAsFixed(3)}:drymix=0.82,'
            'equalizer=f=4600:t=q:w=1.1:g=${(2 * amount).toStringAsFixed(2)},'
            'acompressor=threshold=-18dB:'
            'ratio=${(1.1 + 1.3 * amount).toStringAsFixed(2)}:'
            'attack=9:release=170,alimiter=limit=0.88';
      case _MediaPartEffect.distortion:
        final dryVolume = (1.0 - 0.66 * amount).toStringAsFixed(3);
        final wetVolume = (0.72 * amount).toStringAsFixed(3);
        final drive = (1.0 + 6.0 * amount).toStringAsFixed(3);
        final clip = (0.98 - 0.54 * amount).toStringAsFixed(3);
        final crushMix = (0.20 * amount).toStringAsFixed(3);
        return 'asplit=2[dist6Dry][dist6Wet];'
            '[dist6Dry]highpass=f=90,volume=$dryVolume[dist6D];'
            '[dist6Wet]highpass=f=90,'
            'acompressor=threshold=-28dB:'
            'ratio=${(1.0 + 4.0 * amount).toStringAsFixed(2)}:'
            'attack=3:release=80:makeup=${(1 + 1.8 * amount).toStringAsFixed(2)},'
            'volume=${(1 + 2.2 * amount).toStringAsFixed(2)},'
            "aeval=exprs='clip(val(ch)*$drive,-$clip,$clip)':c=same,"
            'volume=${(1 + 0.65 * amount).toStringAsFixed(2)},'
            'acrusher=bits=${(16 - 6 * amount).round()}:'
            'mix=$crushMix:mode=lin:aa=0.85:samples=1,'
            'equalizer=f=2400:t=q:w=1.0:g=${(3.5 * amount).toStringAsFixed(2)},'
            'equalizer=f=5600:t=q:w=1.1:g=${(2 * amount).toStringAsFixed(2)},'
            'asoftclip=type=atan:'
            'threshold=${(0.98 - 0.22 * amount).toStringAsFixed(2)}:'
            'output=0.78:oversample=8,volume=$wetVolume[dist6W];'
            '[dist6D][dist6W]amix=inputs=2:normalize=0,'
            'volume=${(1.0 - 0.22 * amount).toStringAsFixed(3)},'
            'alimiter=limit=0.88';
      case _MediaPartEffect.loFi:
        final sampleRate = (44100 - 32100 * amount).round();
        final bits = (16 - 10 * amount).round().clamp(6, 16);
        final dryVolume = (1.0 - 0.80 * amount).toStringAsFixed(3);
        final chipVolume = (0.78 * amount).toStringAsFixed(3);
        return 'pan=mono|c0=0.5*c0+0.5*c1,'
            'asplit=2[lofi2Dry][lofi2Chip];'
            '[lofi2Dry]highpass=f=120,lowpass=f=6800,'
            'volume=$dryVolume[lofi2D];'
            '[lofi2Chip]aresample=$sampleRate,aresample=44100,'
            'acrusher=bits=$bits:'
            'mix=${(0.82 * amount).toStringAsFixed(3)}:'
            'mode=lin:aa=${(0.90 - 0.48 * amount).toStringAsFixed(3)}:'
            'samples=${(1 + 2 * amount).round()},'
            'vibrato=f=4.2:d=${(0.10 * amount).toStringAsFixed(3)},'
            'tremolo=f=9.5:d=${(0.10 * amount).toStringAsFixed(3)},'
            'highpass=f=${(80 + 100 * amount).round()},'
            'lowpass=f=${(12000 - 7200 * amount).round()},'
            'equalizer=f=1250:t=q:w=1.0:g=${(5 * amount).toStringAsFixed(2)},'
            'volume=${(1 + 0.5 * amount).toStringAsFixed(2)},'
            'asoftclip=type=atan:'
            'threshold=${(0.96 - 0.24 * amount).toStringAsFixed(2)}:'
            'output=0.72:oversample=4,volume=$chipVolume[lofi2C];'
            '[lofi2D][lofi2C]amix=inputs=2:normalize=0,'
            'acompressor=threshold=-20dB:'
            'ratio=${(1.1 + 2.1 * amount).toStringAsFixed(2)}:'
            'attack=4:release=100,alimiter=limit=0.86,'
            'pan=stereo|FL=c0|FR=c0';
      case _MediaPartEffect.reverseEcho:
        final voiceVolume = (1.0 - 0.42 * amount).toStringAsFixed(3);
        final swellVolume = (0.72 * amount).toStringAsFixed(3);
        final whisperVolume = (0.30 * amount).toStringAsFixed(3);
        return 'asplit=3[revVoice][revSwell][revWhisper];'
            '[revVoice]highpass=f=90,lowpass=f=7600,'
            'equalizer=f=2800:t=q:w=1.2:g=${(2 * amount).toStringAsFixed(2)},'
            'volume=$voiceVolume[revV];'
            '[revSwell]areverse,'
            'aecho=0.76:0.88:320|680|1080:'
            '${(0.46 * amount).toStringAsFixed(3)}|'
            '${(0.30 * amount).toStringAsFixed(3)}|'
            '${(0.18 * amount).toStringAsFixed(3)},'
            'areverse,highpass=f=120,lowpass=f=6800,'
            'stereowiden=delay=20:'
            'feedback=${(0.10 * amount).toStringAsFixed(3)}:'
            'crossfeed=${(0.16 * amount).toStringAsFixed(3)}:drymix=0.80,'
            'volume=$swellVolume[revS];'
            '[revWhisper]highpass=f=1700,lowpass=f=7800,areverse,'
            'aecho=0.72:0.82:180|460:'
            '${(0.34 * amount).toStringAsFixed(3)}|'
            '${(0.20 * amount).toStringAsFixed(3)},areverse,'
            'tremolo=f=4.8:d=${(0.22 * amount).toStringAsFixed(3)},'
            'adelay=35:all=1,pan=stereo|FL=0.28*FL|FR=0.92*FR,'
            'volume=$whisperVolume[revW];'
            '[revV][revS][revW]amix=inputs=3:normalize=0,'
            'equalizer=f=3500:t=q:w=1.1:g=${(2.5 * amount).toStringAsFixed(2)},'
            'acompressor=threshold=-18dB:'
            'ratio=${(1.1 + 1.5 * amount).toStringAsFixed(2)}:'
            'attack=7:release=150,alimiter=limit=0.88';
      case _MediaPartEffect.fadeIn:
        final fade = _fadeDurationSeconds(part.duration, amount);
        return 'afade=t=in:st=0:d=$fade';
      case _MediaPartEffect.fadeOut:
        final fade = _fadeDurationSeconds(part.duration, amount);
        final start = (_seconds(part.duration) - double.parse(fade))
            .clamp(0.0, double.infinity)
            .toStringAsFixed(3);
        return 'afade=t=out:st=$start:d=$fade';
    }
  }

  String _pitchFilter(double targetFactor, double amount) {
    final factor = 1.0 + (targetFactor - 1.0) * amount;
    final compensation = 1 / factor;
    return 'asetrate=44100*${factor.toStringAsFixed(6)},'
        'aresample=44100,'
        'atempo=${compensation.toStringAsFixed(6)}';
  }

  String _fadeDurationSeconds(Duration duration, double amount) {
    final seconds = _seconds(duration);
    final maximum = seconds <= 0 ? 0.2 : (seconds / 3).clamp(0.2, 3.0);
    final fade = (maximum * amount).clamp(0.05, maximum);
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
        secondaryEffectAmountPercent:
            inherited?.secondaryEffectAmountPercent ?? 50,
        thirdEffectAmountPercent:
            inherited?.thirdEffectAmountPercent ?? 50,
        fourthEffectAmountPercent:
            inherited?.fourthEffectAmountPercent ?? 50,
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
      case _MediaPartEffect.superRobot:
        return l10n.mediaCutterPartEffectSuperRobot;
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
    int amountPercent,
  ) {
    if (effect == _MediaPartEffect.none) return;
    pieces.add(
      '${_effectSlotLabel(l10n, slot)} ${_effectLabel(l10n, effect)} '
      '$amountPercent%',
    );
  }

  String _partDetailsSummary(AppLocalizations l10n, _MediaPart part) {
    final duration = _formatHumanDuration(part.duration);
    final pieces = <String>[];

    if (part.volumePercent != 100) {
      pieces.add(_localizedVolumeSummary(part.volumePercent));
    }
    _addEffectSlotSummary(
      l10n,
      pieces,
      1,
      part.effect,
      part.effectAmountPercent,
    );
    _addEffectSlotSummary(
      l10n,
      pieces,
      2,
      part.secondaryEffect,
      part.secondaryEffectAmountPercent,
    );
    _addEffectSlotSummary(
      l10n,
      pieces,
      3,
      part.thirdEffect,
      part.thirdEffectAmountPercent,
    );
    _addEffectSlotSummary(
      l10n,
      pieces,
      4,
      part.fourthEffect,
      part.fourthEffectAmountPercent,
    );
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
