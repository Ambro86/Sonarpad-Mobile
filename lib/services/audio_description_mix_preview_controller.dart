import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';
import 'ai_audiodescription_service.dart';
import 'audio_player_service.dart';

typedef AudioDescriptionMixPreviewRenderer =
    Future<AudioDescriptionMixPreview> Function(
      AiAudioDescriptionService service,
    );

enum _PreviewState { idle, preparing, playing, paused }

/// Debounces adjustments and keeps one preview render/player active at a time.
/// The renderer owns the mix: playback never applies the source gain again.
class AudioDescriptionMixPreviewController extends ChangeNotifier {
  AudioDescriptionMixPreviewController({
    AiAudioDescriptionService Function()? serviceFactory,
    AudioPlayerService Function()? audioFactory,
    this.adjustmentDelay = const Duration(milliseconds: 900),
  }) : _serviceFactory = serviceFactory ?? AiAudioDescriptionService.new,
       _audioFactory = audioFactory ?? AudioPlayerService.new;

  final Duration adjustmentDelay;
  final AiAudioDescriptionService Function() _serviceFactory;
  final AudioPlayerService Function() _audioFactory;
  AiAudioDescriptionService? _service;
  AudioPlayerService? _audio;
  Timer? _timer;
  Future<void> _worker = Future<void>.value();
  Future<void> _interruptions = Future<void>.value();
  Future<void>? _closing;
  int _revision = 0;
  bool _closed = false;
  _PreviewState _state = _PreviewState.idle;
  Object? _error;
  Object? _interruptionError;
  bool _playbackStarted = false;

  bool get isPreparing => _state == _PreviewState.preparing;
  bool get isPlaying => _state == _PreviewState.playing;
  bool get isPaused => _state == _PreviewState.paused;
  bool get isActive => _state != _PreviewState.idle;
  Object? get error => _error;

  /// A resumable session exists only after this sample has really started.
  /// Idle, rendering, loading, failed and completed samples have no controls.
  bool get canPauseOrResume => _playbackStarted && (isPlaying || isPaused);

  void schedule(AudioDescriptionMixPreviewRenderer render) {
    _request(render, adjustmentDelay);
  }

  void playNow(AudioDescriptionMixPreviewRenderer render) {
    _request(render, Duration.zero);
  }

  /// Retain the rendered sample and its position until resumed or replaced.
  Future<void> pause() => _setPaused(true);

  Future<void> resume() => _setPaused(false);

  Future<void> _setPaused(bool paused) async {
    if (_closed || (paused ? !isPlaying : !isPaused)) return;
    final audio = _audio;
    if (audio == null) return;
    final revision = _revision;
    _error = null;
    _state = paused ? _PreviewState.paused : _PreviewState.playing;
    try {
      final change = paused
          ? audio.pauseVoicePreview()
          : audio.resumeVoicePreview();
      notifyListeners();
      // The render/playback worker remains pending through a real pause.
      // Waiting for it here would prevent the user from resuming the sample.
      await change;
    } catch (error, stack) {
      if (_current(revision)) {
        await stop();
        if (_current(revision + 1)) {
          _error = error;
          notifyListeners();
        }
      }
      await AppLogger.log('Audio mix preview pause/resume failed $error\n$stack');
    }
  }

  void _request(AudioDescriptionMixPreviewRenderer render, Duration delay) {
    if (_closed) return;
    final revision = ++_revision;
    _timer?.cancel();
    _error = null;
    _interruptionError = null;
    _playbackStarted = false;
    _state = _PreviewState.preparing;
    notifyListeners();
    _interrupt(revision);
    if (delay == Duration.zero) {
      _start(revision, render);
    } else {
      _timer = Timer(delay, () {
        _timer = null;
        _start(revision, render);
      });
    }
  }

  bool _current(int revision) => !_closed && revision == _revision;

  void _interrupt(int revision) {
    // Cancellation runs outside the render queue, so a pending synthesis or
    // playback cannot block its own Stop command. Interruptions themselves
    // are ordered, and every subsequent render waits for all of them.
    _interruptions = _interruptions
        .then((_) async {
          final service = _service;
          final audio = _audio;
          await Future.wait<void>([
            if (service != null) service.cancelPreview(),
            if (audio != null) audio.stop(),
          ]);
        })
        .catchError((Object error, StackTrace stack) async {
          if (_current(revision)) _interruptionError = error;
          await AppLogger.log('Audio mix preview stop failed $error\n$stack');
        });
  }

  void _start(int revision, AudioDescriptionMixPreviewRenderer render) {
    final previous = _worker;
    _worker = () async {
      try {
        await previous;
        await _interruptions;
        if (!_current(revision)) return;
        final interruptionError = _interruptionError;
        if (interruptionError != null) throw interruptionError;
        final service = _service ??= _serviceFactory();
        final sample = await render(service);
        if (!_current(revision)) return;
        final audio = _audio ??= _audioFactory();
        // Use the same media session and master volume as exported media.
        // The encoded sample already contains source gain, TTS and ducking.
        final playback = audio.playVoicePreview(
          File(sample.path),
          sessionType: AudioSessionType.playback,
          onPlaybackStarted: () {
            if (!_current(revision)) return;
            _playbackStarted = true;
            notifyListeners();
          },
        );
        // Keep the internal player state available for cancellation during
        // loading. The UI additionally waits for canPauseOrResume, so merely
        // installing the session does not expose Pausa before audio starts.
        _state = _PreviewState.playing;
        notifyListeners();
        await playback;
      } catch (error, stack) {
        if (_current(revision)) {
          _error = error;
          await AppLogger.log('Audio mix preview failed $error\n$stack');
        }
      } finally {
        if (_current(revision)) {
          _playbackStarted = false;
          _state = _PreviewState.idle;
          notifyListeners();
        }
      }
    }();
  }

  /// Drain both generation and playback before another TTS/export operation.
  Future<void> stop() async {
    if (_closed) {
      await _closing;
      return;
    }
    final revision = ++_revision;
    _timer?.cancel();
    _timer = null;
    _playbackStarted = false;
    _state = _PreviewState.idle;
    _error = null;
    _interruptionError = null;
    notifyListeners();
    _interrupt(revision);
    await Future.wait<void>([_worker, _interruptions]);
    if (_current(revision) && _interruptionError != null) {
      _error = _interruptionError;
      notifyListeners();
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    ++_revision;
    _timer?.cancel();
    _timer = null;
    _playbackStarted = false;
    _state = _PreviewState.idle;
    _interrupt(_revision);
    await Future.wait<void>([_worker, _interruptions]);
    final service = _service;
    try {
      if (service != null) await service.cleanupMixPreviewCache();
    } catch (error, stack) {
      await AppLogger.log('Audio mix preview cleanup failed $error\n$stack');
    } finally {
      service?.dispose();
      try {
        await _audio?.dispose();
      } catch (error, stack) {
        await AppLogger.log(
          'Audio mix preview player dispose failed $error\n$stack',
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
