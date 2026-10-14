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
  bool autoStart = true;
  final startCallbacks = <void Function()?>[];
  Completer<void>? playing;
  Completer<void>? resumeGate;
  Object? pauseError;
  bool paused = false;
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  int disposals = 0;

  @override
  Future<void> playVoicePreview(
    File file, {
    AudioSessionType sessionType = AudioSessionType.speech,
    void Function()? onPlaybackStarted,
  }) {
    files.add(file.path);
    sessionTypes.add(sessionType);
    paused = false;
    playing = Completer<void>();
    startCallbacks.add(onPlaybackStarted);
    if (autoStart) onPlaybackStarted?.call();
    return playing!.future;
  }

  void finish() {
    paused = false;
    final current = playing;
    if (current != null && !current.isCompleted) current.complete();
  }

  @override
  Future<void> pauseVoicePreview() async {
    pauses++;
    final error = pauseError;
    if (error != null) throw error;
    paused = true;
  }

  @override
  Future<void> resumeVoicePreview() async {
    resumes++;
    final current = playing;
    await resumeGate?.future;
    if (identical(playing, current) && current?.isCompleted == false) {
      paused = false;
    }
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

  test('controls wait for actual playback and reject stale start callbacks', () async {
    audio.autoStart = false;
    expect(controller.canPauseOrResume, isFalse);
    final render = Completer<AudioDescriptionMixPreview>();
    addTearDown(() {
      if (!render.isCompleted) render.complete(_sample('cleanup'));
    });
    controller.playNow((_) => render.future);
    await _tick();
    expect(controller.isPreparing, isTrue);
    expect(controller.canPauseOrResume, isFalse);
    render.complete(_sample('first'));
    await _until(() => audio.files.length == 1);
    expect(controller.canPauseOrResume, isFalse,
        reason: 'Installing a player session does not mean sound has started');
    audio.startCallbacks.first!();
    expect(controller.canPauseOrResume, isTrue);
    await controller.pause();
    expect(controller.canPauseOrResume, isTrue);
    await controller.resume();
    expect(controller.canPauseOrResume, isTrue);
    expect(audio.files, hasLength(1));
    controller.playNow((_) async => _sample('second'));
    expect(controller.canPauseOrResume, isFalse);
    await _until(() => audio.files.length == 2);
    audio.startCallbacks.first!();
    expect(controller.canPauseOrResume, isFalse,
        reason: 'The previous sample cannot expose controls on a new request');
    audio.startCallbacks.last!();
    expect(controller.canPauseOrResume, isTrue);
    audio.finish();
    await _until(() => !controller.isActive);
    expect(controller.canPauseOrResume, isFalse);
    await controller.resume();
    expect(audio.files, hasLength(2));
    await controller.stop();
    expect(controller.canPauseOrResume, isFalse);
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

  test('pause and resume retain the same rendered sample until EOF', () async {
    var renders = 0;
    controller.playNow((_) async {
      renders++;
      return _sample('retained');
    });
    await _tick();
    final playback = audio.playing!;
    final stops = audio.stops;
    final cancellations = service.cancellations;
    await controller.pause();
    expect(controller.isPaused, isTrue);
    expect(controller.isPlaying, isFalse);
    expect(controller.isActive, isTrue);
    expect(audio.paused, isTrue);
    expect(playback.isCompleted, isFalse);
    await controller.resume();
    expect(controller.isPaused, isFalse);
    expect(controller.isPlaying, isTrue);
    expect(audio.paused, isFalse);
    expect(audio.pauses, 1);
    expect(audio.resumes, 1);
    expect(audio.playing, same(playback));
    expect(audio.files, ['retained.mp3']);
    expect(renders, 1);
    expect(audio.stops, stops);
    expect(service.cancellations, cancellations);
    audio.finish();
    await _tick();
    expect(controller.isActive, isFalse);
    await controller.resume();
    expect(audio.resumes, 1, reason: 'EOF cannot resume a completed session');
  });

  test('the player session is installed before Pausa becomes available', () async {
    controller.addListener(() {
      if (controller.isPlaying) unawaited(controller.pause());
    });
    controller.playNow((_) async => _sample('loading'));
    await _tick();
    expect(controller.isPaused, isTrue);
    expect(audio.paused, isTrue);
    expect(audio.playing!.isCompleted, isFalse);
    expect(audio.files, ['loading.mp3']);
  });

  test('an adjustment replaces a paused sample and starts automatically', () async {
    controller.playNow((_) async => _sample('old-volume'));
    await _tick();
    await controller.pause();
    final oldPlayback = audio.playing!;
    controller.schedule((_) async => _sample('new-volume'));
    expect(controller.isPreparing, isTrue);
    expect(controller.isPaused, isFalse);
    await controller.resume();
    await _until(() => audio.files.length == 2);
    expect(oldPlayback.isCompleted, isTrue);
    expect(audio.files, ['old-volume.mp3', 'new-volume.mp3']);
    expect(controller.isPlaying, isTrue);
    expect(audio.paused, isFalse);
    expect(audio.resumes, 0, reason: 'Adjustments start their new sample');
  });

  test('stop drains a paused sample and leaves nothing to resume', () async {
    controller.playNow((_) async => _sample('paused'));
    await _tick();
    await controller.pause();
    await controller.stop();
    expect(audio.playing!.isCompleted, isTrue);
    expect(controller.isActive, isFalse);
    expect(controller.isPaused, isFalse);
    await controller.resume();
    expect(audio.resumes, 0);
  });

  for (final finishWithStop in [true, false]) {
    test('late resume completion cannot revive a finished preview, stop=$finishWithStop', () async {
      controller.playNow((_) async => _sample('first'));
      await _tick();
      await controller.pause();
      final gate = audio.resumeGate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final resuming = controller.resume();
      await _tick();
      if (finishWithStop) {
        await controller.stop();
      } else {
        audio.finish();
        await _tick();
      }
      expect(controller.isActive, isFalse);
      gate.complete();
      await resuming;
      expect(controller.isActive, isFalse);
      expect(audio.files, ['first.mp3']);
      expect(audio.playing!.isCompleted, isTrue);
    });
  }

  test('pause errors drain playback and leave a recoverable inline error', () async {
    controller.playNow((_) async => _sample('first'));
    await _tick();
    final failure = StateError('pause failed');
    audio.pauseError = failure;
    await controller.pause();
    expect(controller.isActive, isFalse);
    expect(controller.error, same(failure));
    expect(audio.playing!.isCompleted, isTrue);
    audio.pauseError = null;
    controller.playNow((_) async => _sample('retry'));
    await _tick();
    expect(controller.isPlaying, isTrue);
    expect(controller.error, isNull);
    expect(audio.files, ['first.mp3', 'retry.mp3']);
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
    await controller.pause();
    expect(controller.isPaused, isTrue);
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
