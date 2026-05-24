import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Tipo di sessione audio.
///
/// - [speech]: per la lettura TTS (Edge TTS), usa la categoria `speech`.
/// - [playback]: per radio, podcast, RaiPlay. Usa la categoria `playback`
///   che abilita la riproduzione in background su iOS.
enum AudioSessionType { speech, playback }

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _stopRequested = false;
  bool _sessionReady = false;
  AudioSessionType _currentSessionType = AudioSessionType.speech;

  Stream<bool> get playingStream => _player.playingStream;

  bool get isPlaying => _player.playing;

  Future<void> _prepareAudioSession(AudioSessionType type) async {
    final session = await AudioSession.instance;

    if (!_sessionReady || _currentSessionType != type) {
      if (type == AudioSessionType.playback) {
        await session.configure(const AudioSessionConfiguration.music());
      } else {
        await session.configure(const AudioSessionConfiguration.speech());
      }
      _currentSessionType = type;
      _sessionReady = true;
      debugPrint('Sonarpad audio: session configured type=$type');
    }

    await session.setActive(true);
    await _player.setVolume(1);
  }

  /// Attiva il wakelock (schermo sempre acceso) se non siamo su desktop/web.
  Future<void> _enableWakelock() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await WakelockPlus.enable();
      debugPrint('Sonarpad audio: wakelock enabled');
    }
  }

  /// Disattiva il wakelock quando la riproduzione termina o viene fermata.
  Future<void> _disableWakelock() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await WakelockPlus.disable();
      debugPrint('Sonarpad audio: wakelock disabled');
    }
  }

  Future<void> playUrl(
    String url, {
    AudioSessionType sessionType = AudioSessionType.playback,
  }) async {
    _stopRequested = false;
    await setUrl(url, sessionType: sessionType);
    if (!_stopRequested) {
      await play();
    }
  }

  Future<void> setUrl(
    String url, {
    AudioSessionType sessionType = AudioSessionType.playback,
  }) async {
    _stopRequested = false;
    await _prepareAudioSession(sessionType);
    debugPrint('Sonarpad audio: setUrl=$url');
    final duration = await _player.setUrl(url);
    debugPrint('Sonarpad audio: duration=$duration');
  }

  Future<void> play() async {
    if (!_stopRequested) {
      debugPrint('Sonarpad audio: play');
      await _enableWakelock();
      await _player.play();
    }
  }

  Future<void> pause() async {
    debugPrint('Sonarpad audio: pause');
    await _player.pause();
    await _disableWakelock();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> playFile(File file) async {
    _stopRequested = false;
    await _prepareAudioSession(AudioSessionType.speech);
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    debugPrint(
      'Sonarpad audio: playFile path=${file.path} exists=$exists size=$size',
    );
    final duration = await _player.setFilePath(file.path);
    debugPrint('Sonarpad audio: playFile duration=$duration');
    if (!_stopRequested) {
      debugPrint('Sonarpad audio: playFile play');
      await _enableWakelock();
      await _player.play();
    }
  }

  /// Riproduce più file in sequenza. Serve per la lettura "a streaming":
  /// il primo blocco parte subito, mentre i blocchi successivi vengono generati
  /// e riprodotti uno dopo l'altro.
  Future<void> playFilesSequentially(
    List<File> files, {
    void Function(int index, File file)? onChunkStarted,
  }) async {
    _stopRequested = false;
    await _prepareAudioSession(AudioSessionType.speech);
    await _enableWakelock();
    try {
      for (var i = 0; i < files.length; i++) {
        if (_stopRequested) break;
        final file = files[i];
        onChunkStarted?.call(i, file);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        debugPrint(
          'Sonarpad audio: chunk ${i + 1}/${files.length} path=${file.path} '
          'exists=$exists size=$size',
        );
        final duration = await _player.setFilePath(file.path);
        debugPrint('Sonarpad audio: chunk ${i + 1} duration=$duration');
        if (_stopRequested) break;
        debugPrint('Sonarpad audio: chunk ${i + 1} play');
        if (!_stopRequested) {
          await _player.play();
        }
        final completedState = await _player.playerStateStream.firstWhere(
          (state) =>
              state.processingState == ProcessingState.completed ||
              _stopRequested,
        );
        debugPrint(
          'Sonarpad audio: chunk ${i + 1} finished '
          'playing=${completedState.playing} '
          'processingState=${completedState.processingState}',
        );
        await _player.stop();
      }
    } finally {
      await _disableWakelock();
    }
  }

  Future<void> seekBackward(
      [Duration duration = const Duration(seconds: 15)]) async {
    final current = _player.position;
    final newPosition = current - duration;
    await _player
        .seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  Future<void> seekForward(
      [Duration duration = const Duration(seconds: 15)]) async {
    final current = _player.position;
    final max = _player.duration ?? Duration.zero;
    final newPosition = current + duration;
    await _player.seek(newPosition > max ? max : newPosition);
  }

  Future<void> stop() async {
    _stopRequested = true;
    debugPrint('Sonarpad audio: stop requested');
    await _player.stop();
    await _disableWakelock();
  }

  Future<void> dispose() async {
    await _disableWakelock();
    await _player.dispose();
  }
}
