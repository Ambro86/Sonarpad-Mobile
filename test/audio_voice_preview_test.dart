import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';

class PreviewPlayer extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final started = Completer<void>();
  final loading = Completer<void>();
  final pausing = Completer<void>();
  Completer<void>? playback;
  Completer<void>? sourceGate;
  Completer<void>? pauseGate;
  Object? pauseError;
  Object? playError;
  bool interrupted = false;
  int loads = 0;
  int pauses = 0;
  int plays = 0;
  int stops = 0;
  Duration currentPosition = Duration.zero;
  LoopMode loop = LoopMode.one;
  final volumes = <double>[];
  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  Duration get position => currentPosition;
  @override
  Duration? get duration => const Duration(seconds: 3);
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);
  @override
  Future<void> setLoopMode(LoopMode mode) async {
    loop = mode;
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loads++;
    if (!loading.isCompleted) loading.complete();
    await sourceGate?.future;
    currentPosition = Duration.zero;
    processingState = ProcessingState.ready;
    return duration;
  }

  @override
  Future<void> play() {
    plays++;
    final error = playError;
    if (error != null) return Future<void>.error(error);
    playing = true;
    playback = Completer<void>();
    if (!started.isCompleted) started.complete();
    states.add(PlayerState(playing, processingState));
    return playback!.future;
  }

  @override
  Future<void> pause() async {
    pauses++;
    final error = pauseError;
    if (error != null) throw error;
    // Match just_audio: pausing an already interrupted player returns before
    // clearing the automatic-resume flag.
    if (!playing) return;
    if (!pausing.isCompleted) pausing.complete();
    await pauseGate?.future;
    interrupted = false;
    playing = false;
    resolvePlay();
    states.add(PlayerState(playing, processingState));
  }

  void resolvePlay() {
    if (playback != null && !playback!.isCompleted) playback!.complete();
  }

  void interrupt() {
    if (!playing) return;
    playing = false;
    interrupted = true;
    resolvePlay();
    states.add(PlayerState(playing, processingState));
  }

  void regainFocus() {
    if (interrupted) {
      interrupted = false;
      unawaited(play());
    }
  }

  void complete({bool focusLost = false}) {
    processingState = ProcessingState.completed;
    if (focusLost) interrupt();
    states.add(PlayerState(playing, processingState));
    resolvePlay();
  }

  @override
  Future<void> stop() async {
    stops++;
    interrupted = false;
    playing = false;
    processingState = ProcessingState.idle;
    resolvePlay();
    states.add(PlayerState(playing, processingState));
  }

  @override
  Future<void> dispose() async {
    resolvePlay();
    await states.close();
  }
}

Future<void> _until(bool Function() done) async {
  final elapsed = Stopwatch()..start();
  while (!done()) {
    if (elapsed.elapsed > const Duration(seconds: 5)) {
      throw StateError('Timed out waiting for preview player');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreviewPlayer player;
  late AudioPlayerService service;
  final file = File('voice-preview.mp3');
  setUp(() {
    SharedPreferences.setMockInitialValues({'sonarpad_media_volume': 0.7});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
    player = PreviewPlayer();
    service = AudioPlayerService(player: player, isAndroid: true);
  });
  tearDown(() async {
    if (player.sourceGate?.isCompleted == false) player.sourceGate!.complete();
    if (player.pauseGate?.isCompleted == false) player.pauseGate!.complete();
    await service.dispose();
  });

  test('Android stops at EOF and disables inherited loop mode', () async {
    final preview = service.playVoicePreview(file);
    await player.started.future;
    expect(player.loop, LoopMode.off);
    player.complete();
    await preview;
    expect(player.playing, isFalse);
    expect(player.stops, 2);
    player.interrupt();
    player.regainFocus();
    expect(player.plays, 1);
  });

  test('EOF clears a pending focus resume even when already paused', () async {
    final preview = service.playVoicePreview(file);
    await player.started.future;
    player.complete(focusLost: true);
    await preview;
    player.regainFocus();
    expect(player.plays, 1);
    expect(player.interrupted, isFalse);
  });

  test('temporary interruption does not finish the preview', () async {
    var finished = false;
    final preview = service.playVoicePreview(file).then((_) => finished = true);
    await player.started.future;
    player.interrupt();
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    player.regainFocus();
    player.complete();
    await preview;
    expect(player.playing, isFalse);
  });

  test('explicit stop cancels a paused preview and prevents resume', () async {
    final preview = service.playVoicePreview(file);
    await player.started.future;
    player.interrupt();
    await service.stop();
    await preview;
    player.regainFocus();
    expect(player.plays, 1);
  });

  test('ordinary pause still stops the existing voice-test preview', () async {
    final preview = service.playVoicePreview(file);
    await player.started.future;
    await service.pause();
    await preview;
    await service.resumeVoicePreview();
    expect(player.plays, 1);
    expect(player.playing, isFalse);
  });

  test('dispose releases an interrupted preview wait', () async {
    final preview = service.playVoicePreview(file);
    await player.started.future;
    player.interrupt();
    await service.dispose();
    await preview;
  });

  test('non-Android keeps the existing playFile behavior', () async {
    await service.dispose();
    player = PreviewPlayer();
    service = AudioPlayerService(player: player, isAndroid: false);
    final preview = service.playVoicePreview(file);
    await player.started.future;
    player.complete();
    await preview;
    expect(player.stops, 0);
    expect(player.playing, isTrue);
    expect(player.loop, LoopMode.one);
  });

  for (final isAndroid in [true, false]) {
    test('mixed preview pause/resume retains sample, position and volume, Android=$isAndroid', () async {
      await service.dispose();
      player = PreviewPlayer();
      service = AudioPlayerService(player: player, isAndroid: isAndroid);
      var finished = false;
      final preview = service.playVoicePreview(
        file,
        sessionType: AudioSessionType.playback,
      ).then((_) => finished = true);
      await player.started.future;
      player.currentPosition = const Duration(milliseconds: 1400);
      final volumeChanges = player.volumes.length;
      await service.pauseVoicePreview();
      expect(player.playing, isFalse);
      expect(finished, isFalse);
      expect(player.position, const Duration(milliseconds: 1400));
      expect(player.stops, 1, reason: 'A true pause does not stop the sample');
      await service.resumeVoicePreview();
      expect(player.playing, isTrue);
      expect(finished, isFalse);
      expect(player.position, const Duration(milliseconds: 1400));
      expect(player.loads, 1);
      expect(player.plays, 2);
      expect(player.volumes.length, volumeChanges);
      player.complete();
      await preview;
      expect(player.playing, isFalse);
      await service.resumeVoicePreview();
      expect(player.plays, 2, reason: 'EOF releases the resumable session');
    });

    test('pause during initial mixed-preview loading prevents autoplay, Android=$isAndroid', () async {
      await service.dispose();
      player = PreviewPlayer();
      service = AudioPlayerService(player: player, isAndroid: isAndroid);
      final gate = player.sourceGate = Completer<void>();
      var finished = false;
      final preview = service.playVoicePreview(
        file,
        sessionType: AudioSessionType.playback,
      ).then((_) => finished = true);
      await player.loading.future;
      await service.pauseVoicePreview();
      gate.complete();
      await _until(() => player.pauses > 0);
      expect(player.plays, 0);
      expect(player.playing, isFalse);
      expect(finished, isFalse);
      await service.resumeVoicePreview();
      expect(player.plays, 1);
      expect(player.loads, 1);
      player.complete();
      await preview;
    });

    test(
      'mixed preview uses final media volume and EOF stop, Android=$isAndroid',
      () async {
        await service.dispose();
        player = PreviewPlayer();
        service = AudioPlayerService(player: player, isAndroid: isAndroid);
        final preview = service.playVoicePreview(
          file,
          sessionType: AudioSessionType.playback,
        );
        await player.started.future;
        expect(player.volumes.last, 0.7);
        expect(player.loop, LoopMode.off);
        player.complete(focusLost: true);
        await preview;
        player.regainFocus();
        expect(player.playing, isFalse);
        expect(player.plays, 1);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getDouble('sonarpad_media_volume'), 0.7);
      },
    );
  }

  test('an explicit mixed-preview pause survives automatic focus regain', () async {
    var finished = false;
    final preview = service.playVoicePreview(
      file,
      sessionType: AudioSessionType.playback,
    ).then((_) => finished = true);
    await player.started.future;
    player.interrupt();
    await service.pauseVoicePreview();
    expect(player.interrupted, isTrue);
    player.regainFocus();
    await _until(() => !player.playing);
    expect(player.pauses, 2);
    expect(player.interrupted, isFalse);
    expect(finished, isFalse);
    expect(player.loads, 1);
    await service.resumeVoicePreview();
    expect(player.playing, isTrue);
    player.complete();
    await preview;
  });

  for (final stopInsteadOfEof in [true, false]) {
    test('stop/EOF invalidates a queued preview resume, stop=$stopInsteadOfEof', () async {
      final preview = service.playVoicePreview(
        file,
        sessionType: AudioSessionType.playback,
      );
      await player.started.future;
      final gate = player.pauseGate = Completer<void>();
      final pause = service.pauseVoicePreview();
      await player.pausing.future;
      final resume = service.resumeVoicePreview();
      final stop = stopInsteadOfEof ? service.stop() : null;
      if (!stopInsteadOfEof) player.complete();
      gate.complete();
      await pause;
      await resume;
      await stop;
      await preview;
      expect(player.plays, 1);
      expect(player.loads, 1);
      expect(player.playing, isFalse);
      player.regainFocus();
      expect(player.plays, 1);
    });
  }

  for (final failOnPause in [true, false]) {
    test('mix transport errors release playback instead of hanging, pause=$failOnPause', () async {
      final preview = service.playVoicePreview(
        file,
        sessionType: AudioSessionType.playback,
      );
      await player.started.future;
      final failure = StateError('preview transport failed');
      final failed = expectLater(preview, throwsA(same(failure)));
      if (failOnPause) {
        player.pauseError = failure;
        await service.pauseVoicePreview();
      } else {
        await service.pauseVoicePreview();
        player.playError = failure;
        await service.resumeVoicePreview();
      }
      await failed;
      expect(player.playing, isFalse);
      final plays = player.plays;
      await service.resumeVoicePreview();
      expect(player.plays, plays);
    });
  }
}
