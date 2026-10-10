import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';

class PreviewPlayer extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final started = Completer<void>();
  Completer<void>? playback;
  bool interrupted = false;
  int plays = 0;
  int stops = 0;
  LoopMode loop = LoopMode.one;
  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  Duration get position => Duration.zero;
  @override
  Duration? get duration => const Duration(seconds: 3);
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Future<void> setVolume(double volume) async {}
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
    processingState = ProcessingState.ready;
    return duration;
  }

  @override
  Future<void> play() {
    plays++;
    playing = true;
    playback = Completer<void>();
    if (!started.isCompleted) started.complete();
    return playback!.future;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreviewPlayer player;
  late AudioPlayerService service;
  final file = File('voice-preview.mp3');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
    player = PreviewPlayer();
    service = AudioPlayerService(player: player, isAndroid: true);
  });
  tearDown(() async {
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
}
