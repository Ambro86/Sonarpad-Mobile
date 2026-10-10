import 'dart:io';

import 'android_media_playback_service.dart';

/// Chooses exactly one background owner for the shared audio/video player.
/// Separate audio already has just_audio_background; embedded video audio uses
/// the native service. Temporary rate changes and autoplay keep the same lease.
class AndroidVideoPlaybackService {
  AndroidVideoPlaybackService({bool? supported})
    : _supported = supported ?? Platform.isAndroid,
      _background = AndroidMediaPlaybackService(supported: supported);

  final bool _supported;
  final AndroidMediaPlaybackService _background;
  bool _requested = false;
  bool _externalAudio = false;
  bool _disposed = false;
  (bool, bool)? _lastState;

  bool get playbackRequested => !_supported || (_requested && !_disposed);

  set onPause(Future<void> Function() callback) {
    _background.onPause = () async {
      _requested = false;
      await callback();
    };
  }

  Future<void> prepare({
    required String title,
    required String pauseLabel,
    required bool externalAudio,
    required bool shouldPlay,
  }) async {
    if (!_supported || _disposed) return;
    _requested = shouldPlay;
    _externalAudio = externalAudio;
    _lastState = null;
    if (!shouldPlay || externalAudio) {
      await _background.stop();
    } else {
      await _background.start(title: title, pauseLabel: pauseLabel);
    }
  }

  Future<void> update({
    required bool playing,
    required bool buffering,
    required bool completed,
    required bool failed,
    required bool transitioning,
    required bool keepForNext,
  }) async {
    if (!_supported || _disposed || _externalAudio || !_requested) return;
    if ((failed && !transitioning) ||
        (completed && !transitioning && !keepForNext)) {
      await pause();
      return;
    }
    // A paused engine during a seek/rate change is not a user pause.
    final state = (playing, buffering || transitioning || completed);
    if (_lastState == state) return;
    _lastState = state;
    await _background.update(playing: state.$1, buffering: state.$2);
  }

  Future<void> pause() async {
    _requested = false;
    _lastState = null;
    await _background.stop();
  }

  Future<void> dispose() async {
    _disposed = true;
    _requested = false;
    await _background.dispose();
  }
}
