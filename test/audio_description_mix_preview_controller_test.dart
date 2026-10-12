import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_mix_preview_controller.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';

AudioDescriptionMixPreview _sample(String name) => AudioDescriptionMixPreview(
  path: '$name.mp3',
  durationSec: 10,
  sourceStartSec: 30,
  narrationStartSec: 2,
  narrationDurationSec: 3,
);

class _Service extends Fake implements AiAudioDescriptionService {
  int cancellations = 0;
  int cleanups = 0;
  int disposals = 0;
  Object? cancelError;

  @override
  Future<void> cancelPreview() async {
    cancellations++;
    final error = cancelError;
    if (error != null) throw error;
  }

  @override
  Future<void> cleanupMixPreviewCache() async => cleanups++;

  @override
  void dispose() => disposals++;
}

class _Audio extends Fake implements AudioPlayerService {
  final files = <String>[];
  final sessionTypes = <AudioSessionType>[];
  Completer<void>? playing;
  int stops = 0;
  int disposals = 0;

  @override
  Future<void> playVoicePreview(
    File file, {
    AudioSessionType sessionType = AudioSessionType.speech,
  }) {
    files.add(file.path);
    sessionTypes.add(sessionType);
    playing = Completer<void>();
    return playing!.future;
  }

  void finish() {
    final current = playing;
    if (current != null && !current.isCompleted) current.complete();
  }

  @override
  Future<void> stop() async {
    stops++;
    finish();
  }

  @override
  Future<void> dispose() async {
    disposals++;
    finish();
  }
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

Future<void> _until(bool Function() done) async {
  final elapsed = Stopwatch()..start();
  while (!done()) {
    if (elapsed.elapsed > const Duration(seconds: 5)) {
      throw StateError('Timed out waiting for controller');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Service service;
  late _Audio audio;
  late AudioDescriptionMixPreviewController controller;

  setUp(() {
    service = _Service();
    audio = _Audio();
    controller = AudioDescriptionMixPreviewController(
      serviceFactory: () => service,
      audioFactory: () => audio,
      adjustmentDelay: const Duration(milliseconds: 40),
    );
  });

  tearDown(() async {
    await controller.close();
    controller.dispose();
  });

  test('rapid adjustments render only the last choice after a pause', () async {
    final rendered = <String>[];
    void request(String name) => controller.schedule((actualService) async {
      expect(actualService, same(service));
      rendered.add(name);
      return _sample(name);
    });
    request('1.0');
    request('0.75');
    request('0.5');
    expect(rendered, isEmpty);
    expect(controller.isPreparing, isTrue);
    await _until(() => audio.files.isNotEmpty);
    expect(rendered, ['0.5']);
    expect(audio.files, ['0.5.mp3']);
    expect(audio.sessionTypes, [AudioSessionType.playback]);
    expect(controller.isPlaying, isTrue);
    audio.finish();
    await _tick();
    expect(controller.isActive, isFalse);
    expect(controller.error, isNull);
  });

  test('replacement drains old rendering and never plays its result', () async {
    final oldRender = Completer<AudioDescriptionMixPreview>();
    addTearDown(() {
      if (!oldRender.isCompleted) oldRender.complete(_sample('obsolete'));
    });
    var newRenders = 0;
    controller.playNow((_) => oldRender.future);
    await _tick();
    controller.playNow((actualService) async {
      expect(actualService, same(service));
      newRenders++;
      return _sample('current');
    });
    await _tick();
    expect(service.cancellations, greaterThan(0));
    expect(newRenders, 0);
    expect(audio.files, isEmpty);
    oldRender.complete(_sample('obsolete'));
    await _tick();
    expect(newRenders, 1);
    expect(audio.files, ['current.mp3']);
    expect(controller.isPlaying, isTrue);
  });

  test('Stop drains in-flight work and removes a pending adjustment', () async {
    final heldRender = Completer<AudioDescriptionMixPreview>();
    addTearDown(() {
      if (!heldRender.isCompleted) heldRender.complete(_sample('cancelled'));
    });
    controller.playNow((_) => heldRender.future);
    await _tick();
    controller.schedule((_) async => _sample('queued'));
    var drained = false;
    final stop = controller.stop().then((_) => drained = true);
    await _tick();
    expect(drained, isFalse);
    expect(controller.isActive, isFalse);
    heldRender.complete(_sample('cancelled'));
    await _tick();
    await stop;
    expect(drained, isTrue);
    expect(audio.files, isEmpty);
    expect(service.cleanups, 0);
    controller.playNow((actualService) async {
      expect(actualService, same(service));
      return _sample('next');
    });
    await _tick();
    expect(audio.files, ['next.mp3']);
  });

  test('close stops playback before cleanup and is idempotent', () async {
    controller.playNow((_) async => _sample('one'));
    await _tick();
    expect(audio.playing!.isCompleted, isFalse);
    final first = controller.close();
    final second = controller.close();
    expect(second, same(first));
    await _tick();
    await first;
    expect(audio.playing!.isCompleted, isTrue);
    expect(service.cleanups, 1);
    expect(service.disposals, 1);
    expect(audio.disposals, 1);
    controller.playNow((_) async => _sample('after-close'));
    await _tick();
    expect(audio.files, ['one.mp3']);
  });

  test('failed rendering exposes an error and a retry can recover', () async {
    final failure = StateError('source unavailable');
    controller.playNow((_) async => throw failure);
    await _until(() => !controller.isActive);
    expect(controller.error, same(failure));
    expect(controller.isActive, isFalse);
    expect(audio.files, isEmpty);
    controller.playNow((_) async => _sample('recovered'));
    await _tick();
    expect(controller.error, isNull);
    expect(audio.files, ['recovered.mp3']);
  });

  test('failed cancellation blocks overlap until a successful stop', () async {
    controller.playNow((_) async => _sample('first'));
    await _tick();
    service.cancelError = StateError('stop failed');
    controller.playNow((_) async => _sample('unsafe'));
    await _until(() => !controller.isActive);
    expect(audio.files, ['first.mp3']);
    expect(controller.error, same(service.cancelError));
    service.cancelError = null;
    await controller.stop();
    expect(controller.error, isNull);
    controller.playNow((_) async => _sample('safe'));
    await _tick();
    expect(audio.files, ['first.mp3', 'safe.mp3']);
  });
}
