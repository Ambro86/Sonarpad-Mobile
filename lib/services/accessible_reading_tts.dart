import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_player_service.dart';
import '../utils/app_logger.dart';

/// Local Android voices use the same media session as recorded speech, so
/// TalkBack/headset media commands pause the audio without losing the sentence.
/// Other platforms keep FlutterTts's native speech and accessibility behavior.
class AccessibleReadingTts extends FlutterTts {
  AccessibleReadingTts({required AudioPlayerService audio, bool? isAndroid})
    : _audio = audio,
      _android = isAndroid ?? Platform.isAndroid;

  final AudioPlayerService _audio;
  final bool _android;
  bool _awaitCompletion = false;
  Completer<void>? _cancelled;
  Future<void>? _reading;
  bool _paused = false;
  bool _playbackStarted = false;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) {
    _awaitCompletion = awaitCompletion;
    return super.awaitSpeakCompletion(awaitCompletion);
  }

  @override
  Future<dynamic> platformCallHandler(MethodCall call) async {
    // Synthesis completion is not playback completion. The file may still be
    // playing (or paused) when the native engine reports it has been written.
    if (_android && call.method.startsWith('synth.')) return;
    return super.platformCallHandler(call);
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    if (!_android) return super.speak(text, focus: focus);
    if (text.isEmpty) {
      if (_cancelled != null && _paused) {
        _paused = false;
        continueHandler?.call();
        if (_playbackStarted) unawaited(_audio.play());
      }
      return 1;
    }
    if (_cancelled != null) await stop();
    final cancelled = Completer<void>();
    _cancelled = cancelled;
    _paused = false;
    _playbackStarted = false;
    final reading = _read(text, cancelled);
    _reading = reading;
    if (_awaitCompletion) {
      await reading;
    } else {
      unawaited(
        reading.catchError((Object error) {
          errorHandler?.call(error.toString());
        }),
      );
    }
    return 1;
  }

  Future<void> _read(String text, Completer<void> cancelled) async {
    Directory? directory;
    StreamSubscription<bool>? playing;
    StreamSubscription<void>? completed;
    var audible = false;
    var ended = false;
    bool active() => identical(_cancelled, cancelled) && !cancelled.isCompleted;
    try {
      final root = await getTemporaryDirectory();
      if (!active()) return;
      directory = await root.createTemp('sonarpad-system-reading-');
      final file = File('${directory.path}/speech.wav');
      await super.awaitSynthCompletion(true);
      if (!active()) return;
      final result = await Future.any<dynamic>([
        super
            .synthesizeToFile(text, file.path, true)
            .timeout(
              const Duration(seconds: 90),
              onTimeout: () async {
                if (!active()) return 0;
                await super.stop();
                throw TimeoutException('system_tts_synthesis_timeout');
              },
            ),
        cancelled.future.then((_) => null),
      ]);
      if (!active()) return;
      if (result != 1 || !await file.exists() || await file.length() <= 44) {
        throw StateError('system_tts_empty_audio');
      }
      while (_paused && active()) {
        await Future.any<void>([
          Future<void>.delayed(const Duration(milliseconds: 20)),
          cancelled.future,
        ]);
      }
      if (!active()) return;
      await AppLogger.log(
        'Android local reading: media-session playback ready',
      );
      completed = _audio.completionStream.listen((_) => ended = true);
      playing = _audio.playingStream.listen((isPlaying) {
        if (!active() || ended) return;
        if (isPlaying) {
          if (!audible) {
            audible = true;
            _playbackStarted = true;
            startHandler?.call();
            if (_paused) unawaited(_audio.pause());
          } else if (_paused) {
            _paused = false;
            continueHandler?.call();
          }
        } else if (audible && !_paused) {
          _paused = true;
          pauseHandler?.call();
          unawaited(
            AppLogger.log('Android local reading: media-session paused'),
          );
        }
      });
      await Future.any<void>([
        _audio.playFilesSequentially([file]),
        cancelled.future,
      ]);
      if (active()) completionHandler?.call();
    } finally {
      await playing?.cancel();
      await completed?.cancel();
      if (identical(_cancelled, cancelled)) {
        _cancelled = null;
        _paused = false;
      }
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  @override
  Future<dynamic> pause() async {
    if (!_android) return super.pause();
    if (_cancelled == null) return 1;
    _paused = true;
    pauseHandler?.call();
    await _audio.pause();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    if (!_android) return super.stop();
    final cancelled = _cancelled;
    _cancelled = null;
    final reading = _reading;
    final result = await super.stop();
    if (cancelled != null) {
      await _audio.stop();
      if (!cancelled.isCompleted) cancelled.complete();
      try {
        await reading;
      } catch (_) {
        // The caller of speak receives synthesis/playback failures.
      }
      cancelHandler?.call();
    }
    return result;
  }
}
