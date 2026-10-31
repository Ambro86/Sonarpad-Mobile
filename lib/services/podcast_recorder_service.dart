import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../utils/app_logger.dart';
import 'protected_wakelock.dart';

enum PodcastCaptureState { idle, recording, paused, ready }

class PodcastRecorderException implements Exception {
  const PodcastRecorderException(this.code);
  final String code;
}

/// The capture backend can be replaced in tests without touching a microphone.
abstract interface class PodcastMicrophone {
  Stream<RecordState> get states;
  Future<bool> permission();
  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
  Future<void> dispose();
}

class NativePodcastMicrophone implements PodcastMicrophone {
  final _recorder = AudioRecorder();
  @override
  Stream<RecordState> get states => _recorder.onStateChanged();
  @override
  Future<bool> permission() => _recorder.hasPermission();
  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 44100,
      numChannels: 1,
      autoGain: false,
      audioInterruption: AudioInterruptionMode.pause,
      iosConfig: IosRecordConfig(
        categoryOptions: [
          IosAudioCategoryOption.defaultToSpeaker,
          IosAudioCategoryOption.allowBluetooth,
          IosAudioCategoryOption.mixWithOthers,
        ],
      ),
    ),
    path: path,
  );
  @override
  Future<void> pause() => _recorder.pause();
  @override
  Future<void> resume() => _recorder.resume();
  @override
  Future<String?> stop() => _recorder.stop();
  @override
  Future<void> dispose() => _recorder.dispose();
}

abstract interface class PodcastMixer {
  Future<void> render(List<String> arguments);
  Future<void> cancel();
}

class NativePodcastMixer implements PodcastMixer {
  FFmpegSession? _session;
  bool _cancelled = false;
  @override
  Future<void> render(List<String> arguments) async {
    _cancelled = false;
    final done = Completer<FFmpegSession>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      done.complete,
    );
    _session = session;
    try {
      if (_cancelled) await session.cancel();
      final completed = await done.future;
      final result = await completed.getReturnCode();
      if (_cancelled || ReturnCode.isCancel(result)) {
        throw const PodcastRecorderException('cancelled');
      }
      if (!ReturnCode.isSuccess(result)) {
        throw const PodcastRecorderException('mix_failed');
      }
    } finally {
      _session = null;
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _session?.cancel();
  }
}

class PodcastRecorderService extends ChangeNotifier {
  PodcastRecorderService({
    PodcastMicrophone? microphone,
    PodcastMixer? mixer,
    Future<Directory> Function()? directory,
    Future<void> Function(bool)? keepAwake,
  }) : _microphone = microphone ?? NativePodcastMicrophone(),
       _mixer = mixer ?? NativePodcastMixer(),
       _directory = directory ?? _defaultDirectory,
       _keepAwake = keepAwake {
    _subscription = _microphone.states.listen(
      _captureChanged,
      onError: (Object e) {
        unawaited(
          AppLogger.log('Podcast recorder native error=${e.runtimeType}'),
        );
        unawaited(
          pause().catchError((Object error) {
            unawaited(
              AppLogger.log(
                'Podcast recorder interruption pause failed type=${error.runtimeType}',
              ),
            );
          }),
        );
      },
    );
  }

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join(
      (await getApplicationSupportDirectory()).path,
      'podcast_recorder_draft',
    ),
  );
  final PodcastMicrophone _microphone;
  final PodcastMixer _mixer;
  final Future<Directory> Function() _directory;
  final Future<void> Function(bool)? _keepAwake;
  StreamSubscription<RecordState>? _subscription;
  Directory? _folder;
  Future<void> _settingsWrite = Future<void>.value();
  final _clock = Stopwatch();
  Timer? _ticker;
  bool _disposed = false;
  Future<void>? _closing;
  bool _transition = false;
  bool _cancelMix = false;
  bool busy = false;
  bool saved = false;
  bool recovered = false;
  String name = '';
  double microphoneVolume = 1;
  double musicVolume = .2;
  String? musicPath;
  String? introPath;
  String? outroPath;
  String _jinglePath(bool intro) =>
      p.join(_folder!.path, 'jingles', intro ? 'intro.audio' : 'outro.audio');
  String? output;
  PodcastCaptureState state = PodcastCaptureState.idle;
  Duration get elapsed => _clock.elapsed;
  String get _raw => p.join(_folder!.path, 'microphone.wav');
  String get _metadata => p.join(_folder!.path, 'draft.json');
  bool get hasDraft => state != PodcastCaptureState.idle;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _awake(bool enabled) async {
    try {
      if (_keepAwake != null) {
        await _keepAwake(enabled);
      } else if (enabled) {
        await WakelockPlus.coordinator.acquire(this);
      } else {
        await WakelockPlus.coordinator.release(this);
      }
    } catch (e) {
      unawaited(
        AppLogger.log('Podcast recorder wakelock error=${e.runtimeType}'),
      );
    }
  }

  Future<void> initialize() async {
    _folder = await _directory();
    await _folder!.create(recursive: true);
    if (await File(_jinglePath(true)).exists()) introPath = _jinglePath(true);
    if (await File(_jinglePath(false)).exists()) outroPath = _jinglePath(false);
    final raw = File(_raw);
    if (await raw.exists() && await raw.length() > 44) {
      state = PodcastCaptureState.ready;
      recovered = true;
      try {
        final metadata =
            jsonDecode(await File(_metadata).readAsString()) as Map;
        name = metadata['name'] as String? ?? '';
        microphoneVolume = ((metadata['microphone'] as num?)?.toDouble() ?? 1)
            .clamp(0, 2);
        musicVolume = ((metadata['music'] as num?)?.toDouble() ?? .2).clamp(
          0,
          1,
        );
        final path = metadata['musicPath'] as String?;
        if (path != null &&
            p.isWithin(_folder!.path, path) &&
            await File(path).exists()) {
          musicPath = path;
        }
      } catch (_) {
        /* The original recording remains usable without metadata. */
      }
    }
    _notify();
  }

  Future<void> _persist() {
    final contents = jsonEncode({
      'name': name,
      'microphone': microphoneVolume,
      'music': musicVolume,
      'musicPath': musicPath,
    });
    final next = _settingsWrite.then((_) async {
      await File(_metadata).writeAsString(contents);
    });
    _settingsWrite = next.catchError((Object _) {});
    return next;
  }

  void _captureChanged(RecordState value) {
    if (_disposed || _transition) return;
    if (value == RecordState.pause && state == PodcastCaptureState.recording) {
      _clock.stop();
      state = PodcastCaptureState.paused;
      unawaited(_awake(false));
      _notify();
    } else if (value == RecordState.stop &&
        (state == PodcastCaptureState.recording ||
            state == PodcastCaptureState.paused)) {
      _clock.stop();
      _ticker?.cancel();
      state = PodcastCaptureState.ready;
      unawaited(_awake(false));
      _notify();
      unawaited(
        AppLogger.log('Podcast recorder stopped by platform; retain draft'),
      );
    }
  }

  Future<void> start() async {
    if (busy || hasDraft) return;
    busy = true;
    _transition = true;
    _notify();
    try {
      if (!await _microphone.permission()) {
        throw const PodcastRecorderException('permission');
      }
      await _persist();
      await _microphone.start(_raw);
      _clock.reset();
      _clock.start();
      saved = false;
      recovered = false;
      state = PodcastCaptureState.recording;
      await _awake(true);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
      unawaited(AppLogger.log('Podcast recorder started; microphone only'));
    } finally {
      busy = false;
      _transition = false;
      _notify();
    }
  }

  Future<void> pause() async {
    if (busy || state != PodcastCaptureState.recording) return;
    busy = true;
    _transition = true;
    try {
      await _microphone.pause();
      _clock.stop();
      state = PodcastCaptureState.paused;
      await _awake(false);
    } finally {
      busy = false;
      _transition = false;
      _notify();
    }
  }

  Future<void> resume() async {
    if (busy || state != PodcastCaptureState.paused) return;
    busy = true;
    _transition = true;
    try {
      await _microphone.resume();
      _clock.start();
      state = PodcastCaptureState.recording;
      await _awake(true);
    } finally {
      busy = false;
      _transition = false;
      _notify();
    }
  }

  Future<void> stop() async {
    if (busy ||
        (state != PodcastCaptureState.recording &&
            state != PodcastCaptureState.paused)) {
      return;
    }
    busy = true;
    _transition = true;
    _notify();
    try {
      await _microphone.stop();
      _clock.stop();
      _ticker?.cancel();
      state = PodcastCaptureState.ready;
      if (!await File(_raw).exists() || await File(_raw).length() <= 44) {
        throw const PodcastRecorderException('empty');
      }
      await _persist();
      unawaited(
        AppLogger.log(
          'Podcast recorder stopped durationMs=${elapsed.inMilliseconds}',
        ),
      );
    } finally {
      await _awake(false);
      busy = false;
      _transition = false;
      _notify();
    }
  }

  // Persistent assets live below the draft folder: draft cleanup only removes
  // top-level files, so saved/discarded recordings never remove these choices.
  Future<void> chooseJingle(String? source, {required bool intro}) async {
    if (busy ||
        state == PodcastCaptureState.recording ||
        state == PodcastCaptureState.paused) {
      return;
    }
    busy = true;
    _notify();
    final target = File(_jinglePath(intro));
    final pending = File('${target.path}.pending');
    try {
      if (source == null) {
        if (await target.exists()) await target.delete();
      } else {
        _validateAudio(source);
        await target.parent.create(recursive: true);
        await File(source).copy(pending.path);
        await pending.rename(target.path);
      }
      if (intro) {
        introPath = source == null ? null : target.path;
      } else {
        outroPath = source == null ? null : target.path;
      }
      output = null;
      saved = false;
    } finally {
      if (await pending.exists()) await pending.delete();
      busy = false;
      _notify();
    }
  }

  static void _validateAudio(String source) {
    if (!const [
      '.mp3',
      '.m4a',
      '.wav',
      '.aac',
      '.ogg',
      '.flac',
      '.opus',
    ].contains(p.extension(source).toLowerCase())) {
      throw const PodcastRecorderException('music');
    }
  }

  Future<void> chooseMusic(String source) async {
    if (busy ||
        state == PodcastCaptureState.recording ||
        state == PodcastCaptureState.paused) {
      return;
    }
    final extension = p.extension(source).toLowerCase();
    _validateAudio(source);
    final target = p.join(_folder!.path, 'music$extension');
    await File(source).copy('$target.pending');
    await File('$target.pending').rename(target);
    musicPath = target;
    output = null;
    saved = false;
    await _persist();
    _notify();
  }

  Future<void> updateMix({
    double? microphone,
    double? music,
    bool removeMusic = false,
  }) async {
    if (busy) return;
    if (microphone != null) microphoneVolume = microphone.clamp(0, 2);
    if (music != null) musicVolume = music.clamp(0, 1);
    if (removeMusic) musicPath = null;
    output = null;
    saved = false;
    await _persist();
    _notify();
  }

  static List<String> mixArguments({
    required String voice,
    required String destination,
    required double microphone,
    required double music,
    String? background,
    String? intro,
    String? outro,
  }) {
    final mic = microphone.clamp(0, 2).toStringAsFixed(3);
    final bed = music.clamp(0, 1).toStringAsFixed(3);
    var graph = background == null
        ? '[0:a]volume=$mic,alimiter=limit=0.95:level=0:latency=1[out]'
        : '[0:a]volume=$mic[voice];[1:a]volume=$bed[bed];'
              '[voice][bed]amix=inputs=2:duration=first:dropout_transition=0:normalize=0,'
              'alimiter=limit=0.95:level=0:latency=1[out]';
    final clips = <String>[];
    var index = background == null ? 1 : 2;
    const normalize =
        'aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo,asetpts=PTS-STARTPTS';
    if (intro != null || outro != null) {
      graph = graph.replaceAll('[out]', '[body]');
      graph += ';[body]$normalize[main]';
      if (intro != null) {
        graph += ';[$index:a]$normalize[opening]';
        index++;
        clips.add('[opening]');
      }
      clips.add('[main]');
      if (outro != null) {
        graph += ';[$index:a]$normalize[closing]';
        clips.add('[closing]');
      }
      graph += ';${clips.join()}concat=n=${clips.length}:v=0:a=1[out]';
    }
    return [
      '-y',
      '-i',
      voice,
      if (background != null) ...['-stream_loop', '-1', '-i', background],
      if (intro != null) ...['-i', intro],
      if (outro != null) ...['-i', outro],
      '-filter_complex',
      graph,
      '-map',
      '[out]',
      '-vn',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-ar',
      '44100',
      '-ac',
      '2',
      '-movflags',
      '+faststart',
      destination,
    ];
  }

  Future<String> render() async {
    if (busy || state != PodcastCaptureState.ready) {
      throw const PodcastRecorderException('state');
    }
    if (output != null && await File(output!).exists()) return output!;
    busy = true;
    _cancelMix = false;
    _notify();
    final destination = p.join(_folder!.path, 'podcast.m4a');
    try {
      await _persist();
      await _mixer.render(
        mixArguments(
          voice: _raw,
          destination: destination,
          microphone: microphoneVolume,
          music: musicVolume,
          background: musicPath,
          intro: introPath,
          outro: outroPath,
        ),
      );
      if (_cancelMix) throw const PodcastRecorderException('cancelled');
      if (!await File(destination).exists() ||
          await File(destination).length() < 32) {
        throw const PodcastRecorderException('empty');
      }
      output = destination;
      unawaited(
        AppLogger.log(
          'Podcast recorder mix complete music=${musicPath != null}',
        ),
      );
      return destination;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> cancelRender() async {
    _cancelMix = true;
    await _mixer.cancel();
  }

  /// Only deletes files in this feature's private draft folder, never imported originals.
  Future<void> discard() async {
    if (busy) return;
    if (state == PodcastCaptureState.recording ||
        state == PodcastCaptureState.paused) {
      await stop();
    }
    await _settingsWrite;
    for (final item in await _folder!.list().toList()) {
      if (item is File) await item.delete();
    }
    state = PodcastCaptureState.idle;
    output = null;
    musicPath = null;
    saved = false;
    recovered = false;
    _clock.reset();
    _notify();
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (_disposed) return;
    _disposed = true;
    _ticker?.cancel();
    _clock.stop();
    try {
      await _subscription?.cancel();
      await _mixer.cancel();
      if (state == PodcastCaptureState.recording ||
          state == PodcastCaptureState.paused) {
        await _microphone.stop();
      }
      if (_folder != null) {
        if (saved) {
          await _settingsWrite;
          for (final file in await _folder!.list().toList()) {
            if (file is File) await file.delete();
          }
        } else {
          await _persist();
        }
      }
    } catch (e) {
      unawaited(
        AppLogger.log(
          'Podcast recorder close failed type=${e.runtimeType}; draft retained',
        ),
      );
    } finally {
      try {
        await _microphone.dispose();
      } catch (e) {
        unawaited(
          AppLogger.log(
            'Podcast recorder dispose failed type=${e.runtimeType}',
          ),
        );
      } finally {
        await _awake(false);
      }
    }
    // Unsaved raw audio stays in Application Support and is recovered next time.
    super.dispose();
  }
}
