import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _stopRequested = false;
  bool _sessionReady = false;

  Future<void> _prepareAudioSession() async {
    if (_sessionReady) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await session.setActive(true);
    await _player.setVolume(1);
    _sessionReady = true;
    debugPrint('Sonarpad audio: session configured for speech volume=1');
  }

  Future<void> playUrl(String url) async {
    _stopRequested = false;
    await setUrl(url);
    if (!_stopRequested) {
      await play();
    }
  }

  Future<void> setUrl(String url) async {
    _stopRequested = false;
    await _prepareAudioSession();
    debugPrint('Sonarpad audio: playUrl setUrl=$url');
    final duration = await _player.setUrl(url);
    debugPrint('Sonarpad audio: playUrl duration=$duration');
  }

  Future<void> play() async {
    if (!_stopRequested) {
      debugPrint('Sonarpad audio: play');
      await _player.play();
    }
  }

  Future<void> pause() async {
    debugPrint('Sonarpad audio: pause requested');
    await _player.pause();
  }

  Future<void> playFile(File file) async {
    _stopRequested = false;
    await _prepareAudioSession();
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    debugPrint(
      'Sonarpad audio: playFile path=${file.path} exists=$exists size=$size',
    );
    final duration = await _player.setFilePath(file.path);
    debugPrint('Sonarpad audio: playFile duration=$duration');
    if (!_stopRequested) {
      debugPrint('Sonarpad audio: playFile play');
      await _player.play();
    }
  }

  /// Riproduce più file in sequenza. Serve per la lettura “a streaming”:
  /// il primo blocco parte subito, mentre i blocchi successivi vengono generati
  /// e riprodotti uno dopo l'altro.
  Future<void> playFilesSequentially(
    List<File> files, {
    void Function(int index, File file)? onChunkStarted,
  }) async {
    _stopRequested = false;
    await _prepareAudioSession();
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
      await play();
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
  }

  Future<void> stop() async {
    _stopRequested = true;
    debugPrint('Sonarpad audio: stop requested');
    await _player.stop();
  }

  Future<void> dispose() => _player.dispose();
}
