import 'dart:io';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'protected_wakelock.dart';
import 'recording_health_monitor.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

class RadioRecordingService extends ChangeNotifier with WidgetsBindingObserver {
  static const _ffmpegUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  final String directoryName;
  final bool includeVideo;
  final Duration stopRetryInterval;
  Future<File?>? _stopOperation;

  FFmpegSession? _session;
  File? _outputFile;
  int _ffmpegLogLines = 0;
  Timer? _monitorTimer;
  RecordingHealthMonitor? _health;
  Completer<void>? _completion;
  bool _stopping = false, _checking = false, _holdingAwake = false;
  bool stoppedUnexpectedly = false;
  int _mediaMs = 0;
  bool _paused = false;
  Completer<void>? _transition;
  File? _finalOutput;
  Directory? _partsDirectory;
  final List<File> _parts = [];
  Future<File> Function(String)? _restart;
  bool get isPaused => _paused;
  bool get isTransitioning => _transition != null;
  bool get stalled => !_paused && (_health?.stalled ?? false);

  Future<void> _beginMonitoring() async {
    _health = RecordingHealthMonitor(DateTime.now());
    if (Platform.isIOS || Platform.isAndroid) {
      await WakelockPlus.coordinator.acquire(this);
      _holdingAwake = true;
    }
    WidgetsBinding.instance.addObserver(this);
    _monitorTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_checkProgress()),
    );
    AppLogger.log(
      'Radio recording: monitoring started screenHeld=$_holdingAwake',
    );
  }

  Future<void> _endMonitoring() async {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    if (_holdingAwake) {
      _holdingAwake = false;
      try {
        await WakelockPlus.coordinator.release(this);
      } catch (error) {
        AppLogger.log(
          'Radio recording: screen release failed ${error.runtimeType}',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.log(
      'Radio recording: lifecycle=$state active=$isRecording stopping=$_stopping mediaMs=$_mediaMs',
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkProgress());
    }
  }

  Future<void> _checkProgress() async {
    if (_checking || !isRecording || _stopping || _paused) return;
    _checking = true;
    try {
      if (_holdingAwake) await WakelockPlus.coordinator.refresh();
      final file = _outputFile;
      final bytes = file != null && await file.exists()
          ? await file.length()
          : 0;
      if (!isRecording || _stopping) return;
      final now = DateTime.now();
      final changed =
          _health?.update(now: now, bytes: bytes, mediaMs: _mediaMs) ?? false;
      AppLogger.log(
        'Radio recording: progress bytes=$bytes mediaMs=$_mediaMs idleSec=${_health?.idleFor(now).inSeconds} stalled=$stalled lifecycle=${WidgetsBinding.instance.lifecycleState}',
      );
      if (changed) notifyListeners();
    } catch (error) {
      AppLogger.log(
        'Radio recording: progress check failed ${error.runtimeType}',
      );
    } finally {
      _checking = false;
    }
  }

  RadioRecordingService({
    this.directoryName = 'Radio Registrazioni',
    this.includeVideo = false,
    this.stopRetryInterval = const Duration(seconds: 10),
  });

  bool get isRecording => _session != null || _paused || isTransitioning;
  File? get outputFile => _finalOutput ?? _outputFile;

  Future<Directory> recordingsDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, directoryName));
  }

  Future<List<File>> listRecordings() async {
    final dir = await recordingsDirectory();
    await AppLogger.log(
      'Radio recording: list directory="${dir.path}" includeVideo=$includeVideo',
    );
    if (!await dir.exists()) {
      await AppLogger.log('Radio recording: list directory missing');
      return const [];
    }

    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) {
        await AppLogger.log(
          'Radio recording: ignored non-file "${entity.path}"',
        );
        continue;
      }
      final ext = p.extension(entity.path).toLowerCase();
      final allowed = includeVideo
          ? const ['.mp4', '.ts', '.mkv', '.m4a', '.aac']
          : const ['.mp3', '.m4a', '.aac'];
      if (allowed.contains(ext)) {
        await AppLogger.log(
          'Radio recording: found file="${entity.path}" size=${await entity.length()}',
        );
        files.add(entity);
      } else {
        await AppLogger.log(
          'Radio recording: ignored file="${entity.path}" extension="$ext"',
        );
      }
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    await AppLogger.log('Radio recording: list count=${files.length}');
    return files;
  }

  Future<File> start({
    required String stationName,
    required String streamUrl,
    String? videoStreamUrl,
    String? audioStreamUrl,
    String? httpUserAgent,
  }) async {
    if (isRecording) throw StateError('recording_already_active');
    _parts.clear();
    _finalOutput = null;
    _partsDirectory = null;
    _restart = (path) => _startSegment(
      stationName: stationName,
      streamUrl: streamUrl,
      videoStreamUrl: videoStreamUrl,
      audioStreamUrl: audioStreamUrl,
      httpUserAgent: httpUserAgent,
      outputOverride: path,
    );
    final file = await _startSegment(
      stationName: stationName,
      streamUrl: streamUrl,
      videoStreamUrl: videoStreamUrl,
      audioStreamUrl: audioStreamUrl,
      httpUserAgent: httpUserAgent,
    );
    _finalOutput = file;
    _parts.add(file);
    return file;
  }

  Future<File> _startSegment({
    required String stationName,
    required String streamUrl,
    String? videoStreamUrl,
    String? audioStreamUrl,
    String? httpUserAgent,
    String? outputOverride,
  }) async {
    if (_session != null) {
      throw StateError('Registrazione gia in corso.');
    }

    final dir = await recordingsDirectory();
    await dir.create(recursive: true);
    final raiVideoUrl = videoStreamUrl;
    final raiAudioUrl = audioStreamUrl;
    final effectiveUserAgent = _effectiveUserAgent(httpUserAgent);
    final isRaiAudioDescriptionRecording =
        raiVideoUrl != null && raiAudioUrl != null;
    final ext = isRaiAudioDescriptionRecording
        ? '.mp4'
        : _recordingExtension(streamUrl);
    final file = File(
      outputOverride ??
          p.join(
            dir.path,
            '${_safeFileName(stationName)} - ${_timestamp()}$ext',
          ),
    );
    final List<String> arguments;
    if (raiVideoUrl != null && raiAudioUrl != null) {
      arguments = _raiAudioDescriptionRecordingArguments(
        videoUrl: raiVideoUrl,
        audioUrl: raiAudioUrl,
        outputPath: file.path,
        userAgent: effectiveUserAgent,
      );
    } else {
      arguments = _recordingArguments(
        streamUrl: streamUrl,
        outputPath: file.path,
        userAgent: effectiveUserAgent,
      );
    }

    await AppLogger.log(
      'Radio recording: start station="$stationName" output="${file.path}"',
    );
    if (isRaiAudioDescriptionRecording) {
      await AppLogger.log(
        'Radio recording: RAI AD mode videoUrl=$videoStreamUrl audioUrl=$audioStreamUrl',
      );
    }
    await AppLogger.log('Radio recording: ffmpeg args=${arguments.join(' ')}');
    _outputFile = file;
    _ffmpegLogLines = 0;
    _stopping = false;
    stoppedUnexpectedly = false;
    _mediaMs = 0;
    _completion = Completer<void>();
    try {
      await _beginMonitoring();
      final startedSession = await FFmpegKit.executeWithArgumentsAsync(
        arguments,
        (session) async {
          try {
            final returnCode = await session.getReturnCode();
            final exists = await file.exists();
            final size = exists ? await file.length() : 0;
            stoppedUnexpectedly = !_stopping;
            await AppLogger.log(
              'Radio recording: finished output="${file.path}" '
              'returnCode=${returnCode?.getValue()} exists=$exists size=$size unexpected=$stoppedUnexpectedly mediaMs=$_mediaMs',
            );
          } finally {
            _session = null;
            await _endMonitoring();
            if (!_completion!.isCompleted) _completion!.complete();
            notifyListeners();
          }
        },
        (log) async {
          final message = log.getMessage().trim();
          if (message.isNotEmpty && _shouldLogFfmpegLine(message)) {
            _ffmpegLogLines += 1;
            await AppLogger.log(
              'Radio recording ffmpeg: ${message.replaceAll(RegExp(r"https?://[^\s]+"), "[stream]")}',
            );
          }
        },
        (statistics) {
          _mediaMs = statistics.getTime().round();
        },
      );
      _session = _completion!.isCompleted ? null : startedSession;
    } catch (_) {
      await _endMonitoring();
      _session = null;
      rethrow;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final earlyReturnCode = await _session?.getReturnCode();
    if (earlyReturnCode != null || _completion!.isCompleted) {
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      await AppLogger.log(
        'Radio recording: early finish output="${file.path}" '
        'returnCode=${earlyReturnCode?.getValue()} exists=$exists size=$size',
      );
      if (!exists || size == 0) {
        _session = null;
        _outputFile = null;
        throw Exception('Registrazione non creata dallo stream.');
      }
    }
    return file;
  }

  Future<void> pause() async {
    if (_paused || isTransitioning || _session == null) return;
    final transition = Completer<void>();
    _transition = transition;
    _paused = true;
    notifyListeners();
    try {
      await _stopSegment();
      stoppedUnexpectedly = false;
      await AppLogger.log('Radio recording: paused parts=${_parts.length}');
    } catch (_) {
      _paused = _session == null;
      rethrow;
    } finally {
      _transition = null;
      transition.complete();
      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (!_paused || isTransitioning || _restart == null) return;
    final transition = Completer<void>();
    _transition = transition;
    notifyListeners();
    try {
      // Reconnect to the live stream: suspending the old network reader would
      // retain buffered adverts and record them when the user resumes.
      _partsDirectory ??= await _finalOutput!.parent.createTemp(
        '.recording-parts-',
      );
      final path = p.join(
        _partsDirectory!.path,
        'part_${_parts.length}${p.extension(_finalOutput!.path)}',
      );
      final file = await _restart!(path);
      _parts.add(file);
      _paused = false;
      await AppLogger.log('Radio recording: resumed parts=${_parts.length}');
    } finally {
      _transition = null;
      transition.complete();
      notifyListeners();
    }
  }

  Future<File?> stop() =>
      _stopOperation ??= _stopAndFinalize().whenComplete(() {
        _stopOperation = null;
      });

  Future<File?> _stopAndFinalize() async {
    await _transition?.future;
    final transition = Completer<void>();
    _transition = transition;
    notifyListeners();
    try {
      await _stopSegment();
      _paused = false;
      if (_parts.length > 1) {
        await _joinParts();
      }
      return _finalOutput ?? _outputFile;
    } finally {
      _transition = null;
      transition.complete();
      notifyListeners();
    }
  }

  Future<void> _joinParts() async {
    final directory = _partsDirectory!;
    final list = File(p.join(directory.path, 'parts.txt'));
    // FFmpeg concat uses its own quoting, not shell quoting.
    String escape(String path) => path.replaceAll("'", "'\\''");
    await list.writeAsString(
      _parts.map((f) => "file '${escape(f.path)}'\n").join(),
    );
    final joined = File(
      p.join(directory.path, 'joined${p.extension(_finalOutput!.path)}'),
    );
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      list.path,
      '-map',
      '0',
      '-c',
      'copy',
      joined.path,
    ]);
    if ((await session.getReturnCode())?.getValue() != 0 ||
        !await joined.exists() ||
        await joined.length() == 0) {
      await AppLogger.log(
        'Radio recording: join failed; parts retained at ${directory.path}',
      );
      throw StateError('recording_join_failed');
    }
    // Keep the first segment recoverable until the completed file is in place.
    final originalPath = _finalOutput!.path;
    final backup = await _finalOutput!.rename(
      p.join(directory.path, 'original${p.extension(originalPath)}'),
    );
    try {
      await joined.rename(originalPath);
    } catch (_) {
      await backup.rename(originalPath);
      rethrow;
    }
    await directory.delete(recursive: true);
    _partsDirectory = null;
    _outputFile = _finalOutput;
    _parts
      ..clear()
      ..add(_finalOutput!);
    await AppLogger.log(
      'Radio recording: paused sections excluded, join complete',
    );
  }

  Future<File?> _stopSegment() async {
    final session = _session;
    final file = _outputFile;
    if (session == null) return file;
    _stopping = true;
    await AppLogger.log(
      'Radio recording: stop requested; awaiting finalization',
    );
    final completion = _completion!;
    // Reissue cancellation for this session only. Never clear the session or
    // offer the file while the native writer may still be alive.
    for (var attempt = 1; attempt <= 3 && !completion.isCompleted; attempt++) {
      await AppLogger.log(
        'Radio recording: cancel attempt=$attempt session=${session.getSessionId()}',
      );
      try {
        await FFmpegKit.cancel(
          session.getSessionId(),
        ).timeout(stopRetryInterval);
        await completion.future.timeout(stopRetryInterval);
      } on TimeoutException {
        await AppLogger.log(
          'Radio recording: cancellation pending attempt=$attempt mediaMs=$_mediaMs',
        );
        if (attempt == 3 && !completion.isCompleted) rethrow;
      }
    }
    if (file == null || !await file.exists() || await file.length() == 0) {
      throw StateError('recording_output_missing');
    }
    await AppLogger.log(
      'Radio recording: finalized bytes=${await file.length()}',
    );
    return file;
  }

  String _recordingExtension(String streamUrl) {
    if (includeVideo) {
      if (_isDashStream(streamUrl)) {
        return '.aac';
      }
      return '.mp4';
    }
    return '.m4a';
  }

  List<String> _recordingArguments({
    required String streamUrl,
    required String outputPath,
    required String userAgent,
  }) {
    if (includeVideo) {
      if (_isDashStream(streamUrl)) {
        return [
          '-y',
          ..._networkInputOptions(streamUrl),
          '-user_agent',
          userAgent,
          '-i',
          streamUrl,
          '-vn',
          '-c:a',
          'aac',
          '-b:a',
          '128k',
          '-f',
          'adts',
          outputPath,
        ];
      }
      return [
        '-y',
        ..._networkInputOptions(streamUrl),
        '-user_agent',
        userAgent,
        '-i',
        streamUrl,
        '-c',
        'copy',
        outputPath,
      ];
    }
    return [
      '-y',
      ..._networkInputOptions(streamUrl),
      '-user_agent',
      userAgent,
      '-i',
      streamUrl,
      '-vn',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      outputPath,
    ];
  }

  List<String> _raiAudioDescriptionRecordingArguments({
    required String videoUrl,
    required String audioUrl,
    required String outputPath,
    required String userAgent,
  }) {
    return [
      '-y',
      ..._networkInputOptions(videoUrl),
      '-user_agent',
      userAgent,
      '-i',
      videoUrl,
      ..._networkInputOptions(audioUrl),
      '-user_agent',
      userAgent,
      '-i',
      audioUrl,
      '-map',
      '0:v:0?',
      '-map',
      '1:a:0?',
      '-c:v',
      'copy',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-shortest',
      outputPath,
    ];
  }

  bool _isDashStream(String streamUrl) {
    final path =
        Uri.tryParse(streamUrl)?.path.toLowerCase() ?? streamUrl.toLowerCase();
    return path.endsWith('.mpd');
  }

  List<String> _networkInputOptions(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return const [];
    return [
      // Microseconds. Bound a blocked network read independently of UI timeouts.
      '-rw_timeout', '5000000',
      if (uri.path.toLowerCase().endsWith('.m3u8')) ...[
        // HLS otherwise keeps skipping failed segments/reloading up to 1000
        // times during one read. Healthy reads reset these counters.
        '-max_reload', '3',
        '-m3u8_hold_counters', '3',
      ],
    ];
  }

  String _effectiveUserAgent(String? httpUserAgent) {
    final value = httpUserAgent?.trim() ?? '';
    return value.isEmpty ? _ffmpegUserAgent : value;
  }

  bool _shouldLogFfmpegLine(String message) {
    // Repeated timestamp warnings must not consume the budget for later errors.
    if (_ffmpegLogLines >= 40 &&
        message.toLowerCase().contains('invalid timestamps')) {
      return false;
    }
    if (_ffmpegLogLines >= 200) return false;
    final lower = message.toLowerCase();
    return lower.contains('error') ||
        lower.contains('forbidden') ||
        lower.contains('failed') ||
        lower.contains('invalid') ||
        lower.contains('server returned') ||
        lower.contains('not found') ||
        lower.contains('timed out') ||
        lower.contains('unable');
  }

  String _safeFileName(String value) {
    const invalid = '<>:"/\\|?*';
    final buffer = StringBuffer();
    var previousWasSpace = false;
    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final isSpace = char.trim().isEmpty;
      final replacement = invalid.contains(char) || isSpace ? ' ' : char;
      if (replacement == ' ') {
        if (previousWasSpace) continue;
        previousWasSpace = true;
      } else {
        previousWasSpace = false;
      }
      buffer.write(replacement);
    }
    final cleaned = buffer.toString().trim();
    return cleaned.isEmpty ? 'Radio' : cleaned;
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
  }
}
