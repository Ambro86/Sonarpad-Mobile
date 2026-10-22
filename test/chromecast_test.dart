import 'package:sonarpad_mobile_starter/services/protected_wakelock.dart';
import 'package:flutter/foundation.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/chromecast_media.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:sonarpad_mobile_starter/screens/chromecast_screen.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/services/chromecast_session.dart';

class FakeSession extends ChromecastSession {
  final events = StreamController<ChromecastStatus>.broadcast();
  final commands = <String>[];
  bool reject = false;
  bool rejectConnect = false;
  final handoff = <String>[];
  final rates = <double>[];
  int closes = 0;
  Duration? requestedPosition;
  final volumes = <double>[];
  Completer<void>? volumeGate;
  Completer<void>? loadGate, connectGate, rateGate;
  @override
  Stream<ChromecastStatus> get updates => events.stream;
  @override
  Future<void> connect(ChromecastDevice device) async {
    await connectGate?.future;
    if (rejectConnect) throw StateError('connect_failed');
  }

  @override
  Future<void> load({
    required String url,
    required String mime,
    required String title,
    required Duration position,
    bool live = false,
    bool autoplay = true,
  }) async {
    await loadGate?.future;
    requestedPosition = position;
    handoff.add(autoplay ? 'load_playing' : 'load_paused');
    if (reject) throw StateError('load_failed');
    status = ChromecastStatus(
      state: autoplay ? 'PLAYING' : 'PAUSED',
      supportedMediaCommands: 1 << 13,
      position: position,
      duration: const Duration(minutes: 5),
      sessionId: 1,
    );
  }

  @override
  Future<void> command(
    String type, [
    Map<String, dynamic> extra = const {},
  ]) async {
    commands.add(type);
    handoff.add(type);
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> setPlaybackRate(double rate) async {
    rates.add(rate);
    await rateGate?.future;
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
    await volumeGate?.future;
  }

  @override
  Future<void> seek(Duration target) async {
    requestedPosition = target;
  }

  @override
  Future<void> close({bool stop = true}) async {
    closes++;
  }
}

class RateSession extends ChromecastSession {
  final requested = <double>[];
  bool ignoreRate = false;
  RateSession({bool supported = true}) {
    status = ChromecastStatus(
      sessionId: 1,
      supportedMediaCommands: supported ? 1 << 13 : 0,
    );
  }
  @override
  Future<void> refresh() async {}
  @override
  Future<void> command(
    String type, [
    Map<String, dynamic> extra = const {},
  ]) async {
    if (type == 'SET_PLAYBACK_RATE') {
      final rate = extra['playbackRate'] as double;
      requested.add(rate);
      if (!ignoreRate) {
        status = ChromecastStatus(
          sessionId: 1,
          supportedMediaCommands: 1 << 13,
          playbackRate: rate,
        );
      }
    }
  }
}

void main() {
  test(
    'Cast speed requires capability and confirmation from the receiver',
    () async {
      final supported = RateSession();
      await supported.setPlaybackRate(1.5);
      expect(supported.status.playbackRate, 1.5);
      supported.ignoreRate = true;
      await expectLater(supported.setPlaybackRate(2), throwsStateError);
      expect(supported.requested, [1.5, 2.0, 1.5]);
      expect(supported.status.playbackRate, 1.5);
      final unsupported = RateSession(supported: false);
      await expectLater(
        unsupported.setPlaybackRate(1.5),
        throwsUnsupportedError,
      );
      expect(unsupported.requested, isEmpty);
      await supported.close(stop: false);
      await unsupported.close(stop: false);
    },
  );
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
  });
  test('Cast accepts remote media and preserves MIME and selected audio', () {
    const source = PodcastEpisode(
      title: 'Video',
      description: '',
      audioUrl: 'https://example.org/video?mime=video%2Fmp4',
    );
    expect(ChromecastMedia.fromEpisode(source, video: true)!.mime, 'video/mp4');
    const split = PodcastEpisode(
      title: 'Video',
      description: '',
      audioUrl: 'https://example.org/italian.m4a',
      videoUrl: 'https://example.org/video.mp4',
    );
    expect(ChromecastMedia.fromEpisode(split, video: true), isNull);
    expect(
      ChromecastMedia.fromEpisode(split, video: false)!.url,
      split.audioUrl,
    );
    for (final url in [
      'file:///local.mp4',
      '/local.mp4',
      'content://video/1',
    ]) {
      expect(
        ChromecastMedia.fromEpisode(
          PodcastEpisode(title: '', description: '', audioUrl: url),
          video: true,
        ),
        isNull,
      );
    }
  });

  test('Cast visibility defaults on and is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsService();
    expect(await settings.isChromecastButtonEnabled(), isTrue);
    await settings.setChromecastButtonEnabled(false);
    expect(await AppSettingsService().isChromecastButtonEnabled(), isFalse);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('Cast controls and adjustable focus stay stable on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      configureAccessibleRendererRuntime(useFlutterOnIos: true);
      var awake = false;
      final wakeLock = WakeLockCoordinator(
        read: () async => awake,
        write: (value) async { awake = value; },
      );
      final session = FakeSession()..positionRestoreFailed = true;
      var started = 0;
      final bookmarks = <Duration>[];
      ChromecastReturn? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<ChromecastReturn>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChromecastScreen(
                      media: const ChromecastMedia(
                        'https://example.org/media.mp4',
                        'video/mp4',
                      ),
                      title: 'Video',
                      wakeLockCoordinator: wakeLock,
                      position: () => const Duration(seconds: 42),
                      onStarted: () async {
                        await wakeLock.toggle(false);
                        session.handoff.add('pause_local');
                        started++;
                      },
                      onPosition: (p) async {
                        bookmarks.add(p);
                      },
                      sessionFactory: () => session,
                      discoveryOverride: () => Stream.value([
                        const ChromecastDevice(
                          'id',
                          'Test TV',
                          '127.0.0.1',
                          8009,
                        ),
                      ]),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(started, 0);
      await tester.tap(find.text('Test TV'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(started, 1);
      expect(awake, isTrue, reason: 'Local pause must not release Cast protection');
      final rows = tester.widget<UniversalAccessibleList>(
        find.byType(UniversalAccessibleList),
      ).sections.expand((section) => section.rows).toList();
      expect(rows.any((row) => row.id == 'error'), isFalse);
      final deviceIndex = rows.indexWhere((row) => row.id == 'device_name');
      expect(rows[deviceIndex - 1].id, 'resume_here');
      expect(session.handoff, ['pause_local', 'load_playing']);
      final speed = find.byKey(const ValueKey('cast_speed'));
      final speedElement = tester.element(speed);
      tester.widget<Slider>(speed).onChanged!(1.5);
      await tester.pumpAndSettle();
      expect(session.rates, [1.5]);
      expect(tester.element(speed), same(speedElement));
      expect(tester.widget<Slider>(speed).onChanged, isNotNull);
      expect(session.requestedPosition, const Duration(seconds: 42));
      final slider = find.byKey(const ValueKey('cast_volume'));
      final element = tester.element(slider);
      session.volumeGate = Completer<void>();
      tester.widget<Slider>(slider).onChanged!(0.4);
      await tester.pump(const Duration(milliseconds: 300));
      tester.widget<Slider>(slider).onChanged!(0.6);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.element(slider), same(element));
      expect(tester.widget<Slider>(slider).onChanged, isNotNull);
      session.volumeGate!.complete();
      await tester.pumpAndSettle();
      expect(session.volumes, [0.4, 0.6]);
      session.status = const ChromecastStatus(
        state: 'PAUSED',
        position: Duration(seconds: 87),
        duration: Duration(minutes: 5),
        sessionId: 1,
      );
      session.events.add(session.status);
      await tester.pumpAndSettle();
      expect(awake, isTrue, reason: 'Keep screen awake while Cast is paused too');
      awake = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(awake, isTrue);
      await tester.ensureVisible(find.text('Resume on this device'));
      await tester.tap(find.text('Resume on this device'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(result?.resume, isTrue);
      expect(awake, isFalse, reason: 'Leaving Cast releases its own hold');
      expect(result?.position, const Duration(seconds: 87));
      expect(bookmarks.last, const Duration(seconds: 87));
      expect(session.closes, greaterThanOrEqualTo(1));
      await session.events.close();
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      configureAccessibleRendererRuntime(useFlutterOnIos: false);
    });
  }

  for (final phase in ['connect', 'load', 'speed']) {
    testWidgets('Back remains available during stalled $phase', (tester) async {
      var awake = false;
      final wakeLock = WakeLockCoordinator(
        read: () async => awake,
        write: (value) async { awake = value; },
      );
      final gate = Completer<void>();
      final session = FakeSession();
      if (phase == 'connect') session.connectGate = gate;
      if (phase == 'load') session.loadGate = gate;
      if (phase == 'speed') session.rateGate = gate;
      var paused = 0, recovered = 0;
      var localPosition = const Duration(seconds: 40);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('Local player')),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => ChromecastScreen(
              media: const ChromecastMedia(
                'https://example.org/a.mp3',
                'audio/mpeg',
              ),
              title: 'Audio',
              wakeLockCoordinator: wakeLock,
              initialSpeed: 1.5,
              position: () => localPosition,
              onStarted: () async {
                paused++;
                localPosition = Duration.zero;
              },
              onStartFailed: () async {
                recovered++;
              },
              onPosition: (_) async {},
              sessionFactory: () => session,
              discoveryOverride: () => Stream.value([
                const ChromecastDevice('id', 'Test TV', 'localhost', 8009),
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test TV'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(awake, isTrue);
      if (phase == 'speed') {
        expect(session.requestedPosition, const Duration(seconds: 40));
        expect(find.byKey(const ValueKey('cast_volume')), findsOneWidget);
        expect(find.text('Loading...'), findsNothing);
      }
      await navigator.currentState!.maybePop();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local player'), findsOneWidget);
      expect(awake, isFalse);
      expect(recovered, phase == 'load' ? 1 : 0);
      expect(paused, phase == 'connect' ? 0 : 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(paused, phase == 'connect' ? 0 : 1);
      expect(recovered, phase == 'load' ? 1 : 0);
      await session.events.close();
    });
  }

  for (final failAfterPause in [false, true]) {
    testWidgets(
      'Failed handoff recovers local playback: after pause=$failAfterPause',
      (tester) async {
        var awake = false;
        final wakeLock = WakeLockCoordinator(
          read: () async => awake,
          write: (value) async { awake = value; },
        );
        final session = FakeSession()
          ..reject = failAfterPause
          ..rejectConnect = !failAfterPause;
        var recovered = false;
        var started = false;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChromecastScreen(
              media: const ChromecastMedia(
                'https://example.org/a.mp3',
                'audio/mpeg',
              ),
              title: 'Audio',
              wakeLockCoordinator: wakeLock,
              position: () => Duration.zero,
              onStarted: () async {
                started = true;
              },
              onPosition: (_) async {},
              onStartFailed: () async {
                recovered = true;
              },
              sessionFactory: () => session,
              discoveryOverride: () => Stream.value([
                const ChromecastDevice('id', 'Test TV', '127.0.0.1', 8009),
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test TV'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(awake, isFalse);
        expect(started, failAfterPause);
        expect(recovered, failAfterPause);
        expect(find.textContaining('Casting failed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await session.events.close();
      },
    );
  }
}
