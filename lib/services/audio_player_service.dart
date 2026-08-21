import 'dart:io';
import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
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
  static const _audioSessionTimeout = Duration(seconds: 4);
  static Future<void>? _pendingDispose;

  final AudioPlayer _player = AudioPlayer();
  bool _stopRequested = false;
  bool _sessionReady = false;
  AudioSessionType _currentSessionType = AudioSessionType.speech;

  // ignore: unused_field
  StreamSubscription<Duration>? _positionSubscription;
  String? _currentMediaId;
  String? _currentTitle;
  Duration? _currentDuration;
  final AppSettingsService _settings = AppSettingsService();

  AudioPlayerService() {
    _initBookmarkListener();
  }

  String get _playerDebugState =>
      'playing=${_player.playing},processingState=${_player.processingState},'
      'position=${_player.position},duration=${_player.duration},'
      'session=$_currentSessionType,sessionReady=$_sessionReady,'
      'stopRequested=$_stopRequested,mediaId=$_currentMediaId,'
      'title="${_currentTitle ?? 'none'}"';

  int _lastSavedBookmarkSecond = -1;

  void _initBookmarkListener() {
    _player.durationStream.listen((d) {
      AppLogger.log('Sonarpad audio: durationStream emitted $d');
      _currentDuration = d;
    }, onError: (Object error, StackTrace stackTrace) {
      AppLogger.log('Sonarpad audio: durationStream error: $error');
    }, onDone: () {
      AppLogger.log('Sonarpad audio: durationStream done');
    });
    _player.playerStateStream.listen((state) {
      AppLogger.log('Sonarpad audio: playerStateStream emitted $state');
      if (state.processingState == ProcessingState.completed ||
          !state.playing) {
        saveCurrentBookmark();
      }
    }, onError: (Object error, StackTrace stackTrace) {
      AppLogger.log('Sonarpad audio: playerStateStream error: $error');
    }, onDone: () {
      AppLogger.log('Sonarpad audio: playerStateStream done');
    });
    _positionSubscription = _player.positionStream.listen((pos) async {
      if (_currentMediaId != null &&
          _currentSessionType == AudioSessionType.playback) {
        final currentSecond = pos.inSeconds;
        // Salva ogni 15 secondi, assicurandoci di non martellare il disco
        if (currentSecond > 0 && currentSecond % 15 == 0) {
          if (_lastSavedBookmarkSecond != currentSecond) {
            _lastSavedBookmarkSecond = currentSecond;
            AppLogger.log(
                'Sonarpad audio: background auto-save at $currentSecond sec');
            await saveCurrentBookmark();
          }
        }
      }
    }, onError: (Object error, StackTrace stackTrace) {
      AppLogger.log('Sonarpad audio: positionStream error: $error');
    }, onDone: () {
      AppLogger.log('Sonarpad audio: positionStream done');
    });
  }

  Future<void> saveCurrentBookmark() async {
    if (_currentMediaId == null ||
        _currentSessionType != AudioSessionType.playback) {
      return;
    }

    final pos = _player.position;
    if (pos.inSeconds < 3) {
      return; // Abbassato per permettere test rapidi
    }

    AppLogger.log(
        'Sonarpad audio: saveCurrentBookmark() called, position: ${pos.inSeconds}s, duration: ${_currentDuration?.inSeconds}s');

    if (await _settings.isAutoBookmarkEnabled()) {
      bool isFinished = false;

      if (_currentDuration != null && _currentDuration!.inSeconds > 0) {
        final durationSecs = _currentDuration!.inSeconds;
        final remaining = durationSecs - pos.inSeconds;

        if (durationSecs > 600) {
          if (remaining < 30) {
            isFinished = true;
          }
        } else {
          if ((pos.inSeconds / durationSecs) > 0.95) {
            isFinished = true;
          }
        }
      }

      if (isFinished) {
        AppLogger.log(
            'Sonarpad audio: saveCurrentBookmark() saving 0 (finished)');
        await _settings.saveMediaBookmark(_currentMediaId!, 0);
      } else {
        AppLogger.log(
            'Sonarpad audio: saveCurrentBookmark() saving ${pos.inSeconds}');
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
      AppLogger.log(
          'Sonarpad audio: waiting for previous player to dispose...');
      await _pendingDispose;
      AppLogger.log('Sonarpad audio: previous player dispose completed');
    }

    final stopwatch = Stopwatch()..start();
    AppLogger.log(
        'Sonarpad audio: prepare session start type=$type state=$_playerDebugState');
    final session = await AudioSession.instance;
    AppLogger.log(
        'Sonarpad audio: AudioSession.instance completed after ${stopwatch.elapsedMilliseconds}ms');

    if (!_sessionReady || _currentSessionType != type) {
      if (type == AudioSessionType.playback) {
        AppLogger.log('Sonarpad audio: configuring music session');
        await session.configure(const AudioSessionConfiguration.music());
      } else {
        AppLogger.log('Sonarpad audio: configuring speech session');
        await session.configure(const AudioSessionConfiguration.speech());
      }
      _currentSessionType = type;
      _sessionReady = true;
      AppLogger.log('Sonarpad audio: session configured type=$type');
    }

    AppLogger.log('Sonarpad audio: setActive(true) start');
    await session.setActive(true).timeout(
      _audioSessionTimeout,
      onTimeout: () async {
        await AppLogger.log(
          'Sonarpad audio: setActive(true) timeout after '
          '${_audioSessionTimeout.inSeconds}s; continuing state=$_playerDebugState',
        );
        return true;
      },
    );
    AppLogger.log(
      'Sonarpad audio: setActive(true) completed/continued after '
      '${stopwatch.elapsedMilliseconds}ms',
    );
    if (type == AudioSessionType.playback) {
      AppLogger.log('Sonarpad audio: loadMediaVolume start');
      final vol = await _settings.loadMediaVolume();
      AppLogger.log('Sonarpad audio: loadMediaVolume completed vol=$vol');
      await _player.setVolume(vol);
      AppLogger.log('Sonarpad audio: player volume set for playback');
    } else {
      await _player.setVolume(1);
      AppLogger.log('Sonarpad audio: player volume set for speech');
    }
    AppLogger.log(
        'Sonarpad audio: prepare session done after ${stopwatch.elapsedMilliseconds}ms state=$_playerDebugState');
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
    await _settings.saveMediaVolume(volume);
  }

  /// Attiva il wakelock (schermo sempre acceso) se non siamo su desktop/web.
  Future<void> _enableWakelock() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      AppLogger.log('Sonarpad audio: wakelock enable start');
      await WakelockPlus.enable();
      AppLogger.log('Sonarpad audio: wakelock enabled');
    }
  }

  /// Disattiva il wakelock quando la riproduzione termina o viene fermata.
  Future<void> _disableWakelock() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      AppLogger.log('Sonarpad audio: wakelock disable start');
      await WakelockPlus.disable();
      AppLogger.log('Sonarpad audio: wakelock disabled');
    }
  }

  Future<void> playUrl(
    String url, {
    AudioSessionType sessionType = AudioSessionType.playback,
    String? title,
    String? mediaId,
    Map<String, String>? headers,
  }) async {
    AppLogger.log(
      'Sonarpad audio: playUrl start url=$url, title="${title ?? 'none'}", '
      'mediaId=$mediaId, sessionType=$sessionType',
    );
    _stopRequested = false;
    await setUrl(
      url,
      sessionType: sessionType,
      title: title,
      mediaId: mediaId,
      headers: headers,
    );
    if (!_stopRequested) {
      await play();
    } else {
      AppLogger.log(
        'Sonarpad audio: playUrl skipped play because stop requested '
        'state=$_playerDebugState',
      );
    }
  }

  Future<void> setUrl(
    String url, {
    AudioSessionType sessionType = AudioSessionType.playback,
    String? title,
    String? mediaId,
    Map<String, String>? headers,
  }) async {
    if (_pendingDispose != null) {
      AppLogger.log(
          'Sonarpad audio: waiting for previous player to dispose in setUrl...');
      await _pendingDispose;
      AppLogger.log(
          'Sonarpad audio: previous player dispose completed in setUrl');
    }
    String itemTitle = title ?? 'Sonarpad';

    _stopRequested = false;
    _currentMediaId = mediaId;
    _currentTitle = itemTitle;
    final stopwatch = Stopwatch()..start();
    AppLogger.log(
      'Sonarpad audio: setUrl start url=$url, mediaId=$mediaId, '
      'sessionType=$sessionType, title="$itemTitle"',
    );
    await _prepareAudioSession(sessionType);
    AppLogger.log(
      'Sonarpad audio: setUrl session prepared after '
      '${stopwatch.elapsedMilliseconds}ms title="$itemTitle"',
    );

    final source = AudioSource.uri(
      Uri.parse(url),
      headers: headers,
      tag: MediaItem(
        id: mediaId ?? url,
        album: 'Sonarpad',
        title: itemTitle,
      ),
    );
    AppLogger.log(
      'Sonarpad audio: setAudioSource start title="$itemTitle" '
      'state=$_playerDebugState',
    );
    final duration = await _player.setAudioSource(source);
    AppLogger.log(
      'Sonarpad audio: setAudioSource completed after '
      '${stopwatch.elapsedMilliseconds}ms title="$itemTitle" '
      'duration=$duration state=$_playerDebugState',
    );

    if (sessionType == AudioSessionType.playback &&
        _currentMediaId != null &&
        await _settings.isAutoBookmarkEnabled()) {
      AppLogger.log(
          'Sonarpad audio: bookmark lookup start mediaId=$_currentMediaId title="$itemTitle"');
      final savedPos = await _settings.getMediaBookmark(_currentMediaId!);
      AppLogger.log(
          'Sonarpad audio: bookmark lookup completed savedPos=$savedPos title="$itemTitle"');
      if (savedPos != null && savedPos >= 3) {
        bool shouldSeek = true;
        if (duration != null && duration.inSeconds > 0) {
          if (savedPos >= (duration.inSeconds - 30)) {
            shouldSeek = false;
          }
        }

        if (shouldSeek) {
          try {
            AppLogger.log(
                'Sonarpad audio: bookmark seek start seconds=$savedPos');
            await _player.seek(Duration(seconds: savedPos));
            AppLogger.log(
                'Sonarpad audio: bookmark seek completed state=$_playerDebugState');
          } catch (e) {
            AppLogger.log('Sonarpad audio: seek error: $e');
          }
        }
      }
    }
  }

  Future<void> play() async {
    if (!_stopRequested) {
      final stopwatch = Stopwatch()..start();
      AppLogger.log('Sonarpad audio: play start state=$_playerDebugState');
      await _enableWakelock();
      AppLogger.log('Sonarpad audio: player.play() await start');
      await _player.play();
      AppLogger.log(
          'Sonarpad audio: play completed after ${stopwatch.elapsedMilliseconds}ms state=$_playerDebugState');
    } else {
      AppLogger.log(
          'Sonarpad audio: play skipped because stop requested state=$_playerDebugState');
    }
  }

  Future<void> startSilentPlaybackSession({
    String title = 'Sonarpad',
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
    await saveCurrentBookmark();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> resumeSequentialPlayback() async {
    if (_player.processingState == ProcessingState.completed &&
        _player.hasNext) {
      AppLogger.log(
        'Sonarpad audio: resume sequential playback seeking to next item',
      );
      await _player.seekToNext();
    }
    await play();
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
          title: 'Sonarpad',
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

  /// Riproduce più file in una coda unica, senza fermare il player tra i chunk.
  Future<void> playFilesSequentially(
    List<File> files, {
    void Function(int index, File file)? onChunkStarted,
    AudioSessionType sessionType = AudioSessionType.speech,
    String title = 'Sonarpad',
    bool resetAfterCompletion = true,
  }) async {
    _stopRequested = false;
    if (files.isEmpty) return;
    await _prepareAudioSession(sessionType);
    await _enableWakelock();
    try {
      final sources = <AudioSource>[];
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        AppLogger.log(
          'Sonarpad audio: chunk ${i + 1}/${files.length} path=${file.path} '
          'exists=$exists size=$size',
        );
        sources.add(
          AudioSource.uri(
            Uri.file(file.path),
            tag: MediaItem(
              id: file.path,
              album: 'Sonarpad',
              title: title,
            ),
          ),
        );
      }

      var lastNotifiedIndex = -1;
      final indexSub = _player.currentIndexStream.listen((index) {
        if (index == null || index < 0 || index >= files.length) return;
        if (index == lastNotifiedIndex) return;
        lastNotifiedIndex = index;
        onChunkStarted?.call(index, files[index]);
      });
      try {
        final duration = await _player.setAudioSources(
          sources,
          initialIndex: 0,
          initialPosition: Duration.zero,
        );
        AppLogger.log(
          'Sonarpad audio: playlist duration=$duration chunks=${files.length} '
          'sessionType=$sessionType resetAfterCompletion=$resetAfterCompletion',
        );
        if (lastNotifiedIndex != 0) {
          lastNotifiedIndex = 0;
          onChunkStarted?.call(0, files[0]);
        }
        final completedFuture = _player.playerStateStream.firstWhere(
          (state) =>
              state.processingState == ProcessingState.completed ||
              _stopRequested,
        );
        if (!_stopRequested) {
          AppLogger.log('Sonarpad audio: playlist play');
          await _player.play();
        }
        final completedState = await completedFuture;
        AppLogger.log(
          'Sonarpad audio: playlist finished playing=${completedState.playing} '
          'processingState=${completedState.processingState}',
        );
      } finally {
        await indexSub.cancel();
        if (!_stopRequested && resetAfterCompletion) {
          try {
            // just_audio keeps `playing == true` when a source reaches the
            // completed state. Seeking a completed-but-still-playing playlist
            // back to zero therefore starts it again immediately. Pause first
            // so resetting the cursor cannot replay the whole TTS a second time.
            if (_player.playing) {
              await _player.pause();
            }
            await _player.seek(Duration.zero, index: 0);
          } catch (e) {
            AppLogger.log('Sonarpad audio: playlist reset error: $e');
          }
        } else if (!resetAfterCompletion) {
          AppLogger.log(
            'Sonarpad audio: playlist reset skipped after completion',
          );
        }
      }
    } finally {
      await _disableWakelock();
    }
  }

  Future<void> playFileStreamSequentially(
    Stream<File> files, {
    void Function(int index, File file)? onChunkStarted,
    AudioSessionType sessionType = AudioSessionType.speech,
    String title = 'Sonarpad',
    int initialBufferCount = 1,
    bool Function()? isPaused,
  }) async {
    _stopRequested = false;
    await _prepareAudioSession(sessionType);
    await _enableWakelock();
    final queuedFiles = <File>[];
    StreamSubscription<int?>? indexSub;
    try {
      var lastNotifiedIndex = -1;
      indexSub = _player.currentIndexStream.listen((index) {
        if (index == null || index < 0 || index >= queuedFiles.length) return;
        if (index == lastNotifiedIndex) return;
        lastNotifiedIndex = index;
        onChunkStarted?.call(index, queuedFiles[index]);
      });

      var started = false;
      final pendingSources = <AudioSource>[];
      Future<void> startPlayback(List<AudioSource> sources) async {
        final safeSources = List<AudioSource>.of(sources);
        if (safeSources.isEmpty) return;

        // Just Audio può conservare per pochi istanti il currentIndex della playlist
        // precedente. Se la nuova playlist è più corta, su iOS può comparire:
        // RangeError: Invalid value: Not in inclusive range 0..1: 2.
        // Prima di caricare la nuova sequenza riportiamo quindi il player a un
        // indice sicuramente valido; se il reset non è possibile, proseguiamo e
        // usiamo comunque il fallback sotto.
        try {
          await _player.stop();
          if (_player.sequence.isNotEmpty) {
            await _player.seek(Duration.zero, index: 0);
          }
        } catch (e) {
          AppLogger.log(
              'Sonarpad audio: stream playlist pre-reset ignored: $e');
        }

        Duration? duration;
        try {
          duration = await _player.setAudioSources(
            safeSources,
            initialIndex: 0,
            initialPosition: Duration.zero,
          );
        } catch (e) {
          AppLogger.log(
            'Sonarpad audio: stream playlist setAudioSources failed, '
            'fallback to single source + append. error=$e sources=${safeSources.length}',
          );
          await _player.setAudioSource(
            safeSources.first,
            initialPosition: Duration.zero,
          );
          for (final extraSource in safeSources.skip(1)) {
            await _player.addAudioSource(extraSource);
          }
          duration = _player.duration;
        }

        AppLogger.log(
          'Sonarpad audio: stream playlist start duration=$duration '
          'initialSources=${safeSources.length} sessionType=$sessionType',
        );
        lastNotifiedIndex = 0;
        onChunkStarted?.call(0, queuedFiles[0]);
        started = true;
        if (!_stopRequested && !(isPaused?.call() ?? false)) {
          AppLogger.log('Sonarpad audio: stream playlist play');
          await _player.play();
        }
      }

      await for (final file in files) {
        if (_stopRequested) break;
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        queuedFiles.add(file);
        final index = queuedFiles.length - 1;
        AppLogger.log(
          'Sonarpad audio: stream chunk ${index + 1} path=${file.path} '
          'exists=$exists size=$size',
        );
        final source = AudioSource.uri(
          Uri.file(file.path),
          tag: MediaItem(
            id: file.path,
            album: 'Sonarpad',
            title: title,
          ),
        );

        if (!started) {
          pendingSources.add(source);
          if (pendingSources.length >= initialBufferCount) {
            await startPlayback(pendingSources);
          }
        } else {
          await _player.addAudioSource(source);
          AppLogger.log(
            'Sonarpad audio: stream playlist appended chunk ${index + 1}',
          );
          if (_player.processingState == ProcessingState.completed &&
              !(isPaused?.call() ?? false) &&
              !_stopRequested) {
            AppLogger.log(
              'Sonarpad audio: stream playlist resumed after late append',
            );
            await _player.seek(Duration.zero, index: index);
            await _player.play();
          }
        }
      }

      if (!started && pendingSources.isNotEmpty && !_stopRequested) {
        await startPlayback(pendingSources);
      }

      if (started &&
          !_stopRequested &&
          _player.processingState != ProcessingState.completed) {
        final completedState = await _player.playerStateStream.firstWhere(
          (state) =>
              state.processingState == ProcessingState.completed ||
              _stopRequested,
        );
        AppLogger.log(
          'Sonarpad audio: stream playlist finished '
          'playing=${completedState.playing} '
          'processingState=${completedState.processingState}',
        );
      } else if (started) {
        AppLogger.log(
          'Sonarpad audio: stream playlist ended state=$_playerDebugState',
        );
      }
    } finally {
      await indexSub?.cancel();
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
    await saveCurrentBookmark();
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
      await saveCurrentBookmark();
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
      await _settings.saveMediaBookmark(
          _currentMediaId!, 0); // Cancella bookmark
    }
    await _player.seek(position);
  }

  Future<void> dispose() async {
    final completer = Completer<void>();
    _pendingDispose = completer.future;

    await saveCurrentBookmark();
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
