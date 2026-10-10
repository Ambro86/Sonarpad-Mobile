import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/android_media_playback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sonarpad/mediakit_background');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final services = <AndroidMediaPlaybackService>[];

  AndroidMediaPlaybackService service({bool supported = true}) {
    final result = AndroidMediaPlaybackService(supported: supported);
    services.add(result);
    return result;
  }

  Future<void> start(AndroidMediaPlaybackService target) =>
      target.start(title: 'La7', pauseLabel: 'Pausa');

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() async {
    for (final target in services) {
      await target.dispose();
    }
    services.clear();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('other platforms never contact the Android service', () async {
    final target = service(supported: false);
    await start(target);
    await target.update(playing: true, buffering: false);
    await target.stop();
    expect(calls, isEmpty);
  });

  test(
    'buffering and stream replacements retain the existing service',
    () async {
      final target = service();
      await start(target);
      await target.update(playing: true, buffering: false);
      await target.update(playing: false, buffering: true);
      await start(target);
      await target.update(playing: true, buffering: false);
      expect(calls.map((call) => call.method), [
        'start',
        'update',
        'update',
        'update',
      ]);
      await target.stop();
      await target.update(playing: true, buffering: false);
      expect(calls.last.method, 'stop');
      await start(target);
      expect(calls.last.method, 'start');
    },
  );

  test(
    'dispose waits for pending startup and then releases the service',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'start') {
          entered.complete();
          await release.future;
        }
        return null;
      });
      final target = service();
      final starting = start(target);
      await entered.future;
      final disposing = target.dispose();
      release.complete();
      await Future.wait([starting, disposing]);
      await start(target);
      expect(calls.map((call) => call.method), ['start', 'stop']);
    },
  );

  test('a startup error does not poison subsequent service commands', () async {
    var fail = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'start' && fail) {
        fail = false;
        throw PlatformException(code: 'background_start');
      }
      return null;
    });
    final target = service();
    await expectLater(start(target), throwsA(isA<PlatformException>()));
    await start(target);
    await target.stop();
    expect(calls.map((call) => call.method), ['start', 'start', 'stop']);
  });

  test('native interruption during startup permits a later restart', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    var firstStart = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'start' && firstStart) {
        firstStart = false;
        entered.complete();
        await release.future;
      }
      return null;
    });
    final target = service();
    var paused = false;
    target.onPause = () async {
      paused = true;
    };
    final starting = start(target);
    await entered.future;
    final id = (calls.single.arguments as Map)['id'];
    final delivered = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('pause', id)),
      (_) => delivered.complete(),
    );
    await delivered.future;
    release.complete();
    await starting;
    expect(paused, isTrue);
    await start(target);
    expect(calls.map((call) => call.method), ['start', 'start']);
  });

  test(
    'old screen stop carries its own owner, never the new screen owner',
    () async {
      final old = service();
      final next = service();
      await start(old);
      final oldId = (calls.last.arguments as Map)['id'];
      await start(next);
      final nextId = (calls.last.arguments as Map)['id'];
      await old.dispose();
      expect(oldId, isNot(nextId));
      expect((calls.last.arguments as Map)['id'], oldId);
    },
  );

  test(
    'lock screen pause targets the owning player and suppresses late updates',
    () async {
      final target = service();
      var paused = 0;
      target.onPause = () async {
        paused++;
      };
      await start(target);
      final id = (calls.single.arguments as Map)['id'];
      final delivered = Completer<void>();
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall('pause', id)),
        (_) => delivered.complete(),
      );
      await delivered.future;
      await target.update(playing: true, buffering: false);
      expect(paused, 1);
      expect(calls.map((call) => call.method), ['start']);
      await start(target);
      expect(calls.last.method, 'start');
    },
  );
}
