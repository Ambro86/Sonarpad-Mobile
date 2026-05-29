import 'dart:io';
import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_settings_service.dart';
import '../utils/app_logger.dart';

/// Tipo di sessione audio.
///
/// - [speech]: per la lettura TTS (Edge TTS), usa la categoria `speech`.
/// - [playback]: per radio, podcast, RaiPlay. Usa la categoria `playback`
///   che abilita la riproduzione in background su iOS.
enum AudioSessionType { speech, playback }

class AudioPlayerService {
  static Future<void>? _pendingDispose;

  final AudioPlayer _player = AudioPlayer();
  bool _stopRequested = false;
  bool _sessionReady = false;
  AudioSessionType _currentSessionType = AudioSessionType.speech;

  // ignore: unused_field
  StreamSubscription<Duration>? _positionSubscription;
  String? _currentMediaId;
  Duration? _currentDuration;
  final AppSettingsService _settings = AppSettingsService();

  AudioPlayerService() {
    _initBookmarkListener();
  }

  int _lastSavedBookmarkSecond = -1;

  void _initBookmarkListener() {
    _player.durationStream.listen((d) {
       AppLogger.log('Sonarpad audio: durationStream emitted $d');
       _currentDuration = d;
    });
    _player.playerStateStream.listen((state) {
       AppLogger.log('Sonarpad audio: playerStateStream emitted $state');
       if (state.processingState == ProcessingState.completed || !state.playing) {
          _saveCurrentBookmark();
       }
    });
    _positionSubscription = _player.positionStream.listen((pos) async {
       if (_currentMediaId != null && _currentSessionType == AudioSessionType.playback) {
          final currentSecond = pos.inSeconds;
          // Salva ogni 15 secondi, assicurandoci di non martellare il disco
          if (currentSecond > 0 && currentSecond % 15 == 0) {
              if (_lastSavedBookmarkSecond != currentSecond) {
                  _lastSavedBookmarkSecond = currentSecond;
                  AppLogger.log('Sonarpad audio: background auto-save at $currentSecond sec');
                  await _saveCurrentBookmark();
              }
          }
       }
    });
  }

  Future<void> _saveCurrentBookmark() async {
    if (_currentMediaId == null || _currentSessionType != AudioSessionType.playback) return;
    
    final pos = _player.position;
    if (pos.inSeconds < 3) return; // Abbassato per permettere test rapidi

    AppLogger.log('Sonarpad audio: _saveCurrentBookmark() called, position: ${pos.inSeconds}s, duration: ${_currentDuration?.inSeconds}s');

    if (await _settings.isAutoBookmarkEnabled()) {
       bool isFinished = false;
       
       if (_currentDuration != null && _currentDuration!.inSeconds > 0) {
           final durationSecs = _currentDuration!.inSeconds;
           final remaining = durationSecs - pos.inSeconds;
           
           if (durationSecs > 600) {
              if (remaining < 30) isFinished = true;
           } else {
              if ((pos.inSeconds / durationSecs) > 0.95) isFinished = true;
           }
       }

       if (isFinished) {
          AppLogger.log('Sonarpad audio: _saveCurrentBookmark() saving 0 (finished)');
          await _settings.saveMediaBookmark(_currentMediaId!, 0);
       } else {
          AppLogger.log('Sonarpad audio: _saveCurrentBookmark() saving ${pos.inSeconds}');
          await _settings.saveMediaBookmark(_currentMediaId!, pos.inSeconds);
       }
    }
  }

  Stream<bool> get playingStream => _player.playingStream;

  Stream<Duration> get positionStream => _player.positionStream;
  
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get isPlaying => _player.playing;

  Future<void> _prepareAudioSession(AudioSessionType type) async {
    if (_pendingDispose != null) {
      AppLogger.log('Sonarpad audio: waiting for previous player to dispose...');
      await _pendingDispose;
    }

    final session = await AudioSession.instance;

    if (!_sessionReady || _currentSessionType != type) {
      if (type == AudioSessionType.playback) {
        await session.configure(const AudioSessionConfiguration.music());
      } else {
        await session.configure(const AudioSessionConfiguration.speech());
      }
      _currentSessionType = type;
      _sessionReady = true;
      AppLogger.log('Sonarpad audio: session configured type=$type');
    }

    await session.setActive(true);
    if (type == AudioSessionType.playback) {
      final vol = await _settings.loadMediaVolume();
      await _player.setVolume(vol);
    } else {
      await _player.setVolume(1);
    }
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
    await _settings.saveMediaVolume(volume);
  }

  /// Attiva il wakelock (schermo sempre acceso) se non siamo su desktop/web.
  Future<void> _enableWakelock() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await WakelockPlus.enable();
      AppLogger.log('Sonarpad audio: wakelock enabled');
    }
  }

  /// Disattiva il wakelock quando la riproduzione termina o viene fermata.
  Future<void> _disableWakelock() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await WakelockPlus.disable();
      AppLogger.log('Sonarpad audio: wakelock disabled');
    }
  }

  Future<void> playUrl(
    String url, {
    AudioSessionType sessionType = AudioSessionType.playback,
    String? title,
    String? mediaId,
  }) async {
    _stopRequested = false;
    await setUrl(url, sessionType: sessionType, title: title, mediaId: mediaId);
    if (!_stopRequested) {
      await play();
    }
  }

  Future<void> setUrl(
    String url, {
    AudioSessionType sessionType = AudioSessionType.playback,
    String? title,
    String? mediaId,
  }) async {
    if (_pendingDispose != null) {
      AppLogger.log('Sonarpad audio: waiting for previous player to dispose in setUrl...');
      await _pendingDispose;
    }
    _stopRequested = false;
    _currentMediaId = mediaId;
    await _prepareAudioSession(sessionType);
    AppLogger.log('Sonarpad audio: setUrl=$url, mediaId=$mediaId');

    String itemTitle = title ??
        (sessionType == AudioSessionType.speech
            ? 'Lettura Vocale'
            : 'Riproduzione Audio');

    final source = AudioSource.uri(
      Uri.parse(url),
      tag: MediaItem(
        id: url,
        album: 'Sonarpad',
        title: itemTitle,
      ),
    );
    final duration = await _player.setAudioSource(source);
    AppLogger.log('Sonarpad audio: duration=$duration');

    if (sessionType == AudioSessionType.playback && _currentMediaId != null && await _settings.isAutoBookmarkEnabled()) {
       final savedPos = await _settings.getMediaBookmark(_currentMediaId!);
       if (savedPos != null && savedPos >= 3) {
          bool shouldSeek = true;
          if (duration != null && duration.inSeconds > 0) {
             if (savedPos >= (duration.inSeconds - 30)) {
                shouldSeek = false;
             }
          }
          
          if (shouldSeek) {
             try {
                await _player.seek(Duration(seconds: savedPos));
             } catch (e) {
                AppLogger.log('Sonarpad audio: seek error: $e');
             }
          }
       }
    }
  }

  Future<void> play() async {
    if (!_stopRequested) {
      AppLogger.log('Sonarpad audio: play');
      await _enableWakelock();
      await _player.play();
    }
  }

  Future<void> startSilentPlaybackSession({
    String title = 'Lettura Documento',
  }) async {
    _stopRequested = false;
    await _prepareAudioSession(AudioSessionType.speech);
    await _enableWakelock();
    final file = await _silentWavFile();
    await _player.setVolume(0);
    await _player.setLoopMode(LoopMode.one);
    await _player.setAudioSource(
      AudioSource.uri(
        Uri.file(file.path),
        tag: MediaItem(
          id: file.path,
          album: 'Sonarpad',
          title: title,
        ),
      ),
    );
    if (!_stopRequested) {
      await _player.play();
    }
  }

  Future<void> pause() async {
    AppLogger.log('Sonarpad audio: pause');
    await _player.pause();
    await _disableWakelock();
    await _saveCurrentBookmark();
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
    AppLogger.log(
      'Sonarpad audio: playFile path=${file.path} exists=$exists size=$size',
    );
    final duration = await _player.setAudioSource(
      AudioSource.uri(
        Uri.file(file.path),
        tag: MediaItem(
          id: file.path,
          album: 'Sonarpad',
          title: 'Lettura Documento',
        ),
      ),
    );
    AppLogger.log('Sonarpad audio: playFile duration=$duration');
    if (!_stopRequested) {
      AppLogger.log('Sonarpad audio: playFile play');
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
        AppLogger.log(
          'Sonarpad audio: chunk ${i + 1}/${files.length} path=${file.path} '
          'exists=$exists size=$size',
        );
        final duration = await _player.setAudioSource(
          AudioSource.uri(
            Uri.file(file.path),
            tag: MediaItem(
              id: file.path,
              album: 'Sonarpad',
              title: 'Lettura Documento',
            ),
          ),
        );
        AppLogger.log('Sonarpad audio: chunk ${i + 1} duration=$duration');
        if (_stopRequested) break;
        AppLogger.log('Sonarpad audio: chunk ${i + 1} play');
        if (!_stopRequested) {
          if (i == 0 || _player.playing) {
            await _player.play();
          }
        }
        final completedState = await _player.playerStateStream.firstWhere(
          (state) =>
              state.processingState == ProcessingState.completed ||
              _stopRequested,
        );
        AppLogger.log(
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
    await seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  Future<void> seekForward(
      [Duration duration = const Duration(seconds: 15)]) async {
    final current = _player.position;
    final newPosition = current + duration;
    final max = _player.duration;
    
    if (max != null && max > Duration.zero) {
      await seek(newPosition > max ? max : newPosition);
    } else {
      await seek(newPosition);
    }
  }

  Future<void> stop() async {
    _stopRequested = true;
    AppLogger.log('Sonarpad audio: stop requested');
    await _saveCurrentBookmark();
    await _player.stop();
    await _player.setLoopMode(LoopMode.off);
    await _player.setVolume(1);
    await _disableWakelock();
  }

  Future<void> stopAndDispose() async {
    final completer = Completer<void>();
    _pendingDispose = completer.future;

    try {
      _stopRequested = true;
      AppLogger.log('Sonarpad audio: stopAndDispose requested');
      await _saveCurrentBookmark();
      await _player.stop();
      await _disableWakelock();
      await _player.dispose();
      AppLogger.log('Sonarpad audio: dispose complete');
    } catch (e) {
      AppLogger.log('Sonarpad audio: stopAndDispose error: $e');
    }

    completer.complete();
    if (_pendingDispose == completer.future) {
      _pendingDispose = null;
    }
  }

  Future<void> seek(Duration position) async {
    if (position.inSeconds < 10 && _currentMediaId != null) {
       await _settings.saveMediaBookmark(_currentMediaId!, 0); // Cancella bookmark
    }
    await _player.seek(position);
  }

  Future<void> dispose() async {
    final completer = Completer<void>();
    _pendingDispose = completer.future;

    await _saveCurrentBookmark();
    await _disableWakelock();
    try {
      await _player.dispose();
      AppLogger.log('Sonarpad audio: dispose complete');
    } catch (e) {
      AppLogger.log('Sonarpad audio: dispose error: $e');
    }

    completer.complete();
    if (_pendingDispose == completer.future) {
      _pendingDispose = null;
    }
  }

  Future<File> _silentWavFile() async {
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}${Platform.pathSeparator}sonarpad_silence.wav');
    if (!await file.exists()) {
      await file.writeAsBytes(_silentWavBytes(), flush: true);
    }
    return file;
  }

  Uint8List _silentWavBytes() {
    const sampleRate = 8000;
    const seconds = 1;
    const channels = 1;
    const bitsPerSample = 16;
    const bytesPerSample = bitsPerSample ~/ 8;
    const dataSize = sampleRate * seconds * channels * bytesPerSample;
    const fileSize = 36 + dataSize;
    final bytes = Uint8List(44 + dataSize);
    final data = ByteData.view(bytes.buffer);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i += 1) {
        bytes[offset + i] = value.codeUnitAt(i);
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, fileSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
    data.setUint16(32, channels * bytesPerSample, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, dataSize, Endian.little);

    return bytes;
  }
}
