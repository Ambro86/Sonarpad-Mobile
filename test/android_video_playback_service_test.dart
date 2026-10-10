import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/android_video_playback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sonarpad/mediakit_background');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late AndroidVideoPlaybackService service;

  Future<void> prepare({
    bool external = false,
    bool play = true,
    String title = 'Video 1',
  }) => service.prepare(
    title: title,
    pauseLabel: 'Pausa',
    externalAudio: external,
    shouldPlay: play,
  );

  Future<void> update({
    bool playing = true,
    bool buffering = false,
    bool completed = false,
    bool failed = false,
    bool transitioning = false,
    bool next = false,
  }) => service.update(
    playing: playing,
    buffering: buffering,
    completed: completed,
    failed: failed,
    transitioning: transitioning,
    keepForNext: next,
  );

  setUp(() {
    calls.clear();
    service = AndroidVideoPlaybackService(supported: true);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() async {
    await service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'separate audio and paused videos do not create a second service',
    () async {
      await prepare(external: true);
      await update();
      expect(service.playbackRequested, isTrue);
      await prepare(play: false);
      await update(playing: false);
      expect(service.playbackRequested, isFalse);
      expect(calls, isEmpty);
    },
  );

  test(
    'embedded video retains protection during buffering and rate changes',
    () async {
      await prepare();
      await update();
      await update(); // Position-only events must not spam the platform channel.
      await update(playing: false, buffering: true);
      await update(playing: false, transitioning: true);
      await update();
      expect(calls.map((call) => call.method), [
        'start',
        'update',
        'update',
        'update',
      ]);
      await service.pause();
      await update();
      expect(service.playbackRequested, isFalse);
      expect(calls.last.method, 'stop');
    },
  );

  test(
    'switching to external audio releases embedded audio ownership',
    () async {
      await prepare();
      await prepare(external: true);
      await update();
      expect(calls.map((call) => call.method), ['start', 'stop']);
      await prepare();
      expect(calls.map((call) => call.method), ['start', 'stop', 'start']);
    },
  );

  test('end of video without autoplay releases protection', () async {
    await prepare();
    await update(playing: false, completed: true);
    expect(calls.last.method, 'stop');
    expect(service.playbackRequested, isFalse);
  });

  test('autoplay preserves service and refreshes the next title', () async {
    await prepare();
    final owner = (calls.single.arguments as Map)['id'];
    await update(playing: false, completed: true, next: true);
    await prepare(title: 'Video 2');
    expect(calls.map((call) => call.method), ['start', 'update', 'start']);
    expect((calls.last.arguments as Map)['id'], owner);
    expect((calls.last.arguments as Map)['title'], 'Video 2');
    await update(playing: false, completed: true);
    expect(calls.last.method, 'stop');
  });

  test(
    'a terminal error releases protection after a refresh attempt',
    () async {
      await prepare();
      await update(playing: false, failed: true, transitioning: true);
      expect(calls.last.method, 'update');
      await update(playing: false, failed: true);
      expect(calls.last.method, 'stop');
      expect(service.playbackRequested, isFalse);
    },
  );

  test('pause during native startup prevents delayed video autoplay', () async {
    final entered = Completer<void>();
    final ready = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'start') {
        entered.complete();
        await ready.future;
      }
      return null;
    });
    final starting = prepare();
    await entered.future;
    final pausing = service.pause();
    expect(service.playbackRequested, isFalse);
    ready.complete();
    await Future.wait([starting, pausing]);
    expect(service.playbackRequested, isFalse);
    expect(calls.map((call) => call.method), ['start', 'stop']);
  });

  test('native pause blocks resume even during a speed transition', () async {
    var paused = false;
    service.onPause = () async {
      paused = true;
    };
    await prepare();
    final id = (calls.single.arguments as Map)['id'];
    await update(playing: false, transitioning: true);
    final delivered = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('pause', id)),
      (_) => delivered.complete(),
    );
    await delivered.future;
    expect(paused, isTrue);
    expect(service.playbackRequested, isFalse);
    await update();
    expect(calls.length, 2);
  });

  test('other platforms keep their existing playback behavior', () async {
    await service.dispose();
    service = AndroidVideoPlaybackService(supported: false);
    await prepare();
    await update();
    await service.pause();
    expect(service.playbackRequested, isTrue);
    expect(calls, isEmpty);
  });
}
