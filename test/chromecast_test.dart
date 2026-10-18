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
  int closes = 0;
  Duration? requestedPosition;
  final volumes = <double>[];
  Completer<void>? volumeGate;
  @override
  Stream<ChromecastStatus> get updates => events.stream;
  @override
  Future<void> connect(ChromecastDevice device) async {}
  @override
  Future<void> load({
    required String url,
    required String mime,
    required String title,
    required Duration position,
    bool live = false,
    bool autoplay = true,
  }) async {
    requestedPosition = position;
    if (reject) throw StateError('load_failed');
    status = ChromecastStatus(
      state: 'PLAYING',
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

void main() {
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
      final session = FakeSession();
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
                      position: () => const Duration(seconds: 42),
                      onStarted: () async {
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
      await tester.ensureVisible(find.text('Resume on this device'));
      await tester.tap(find.text('Resume on this device'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(result?.resume, isTrue);
      expect(result?.position, const Duration(seconds: 87));
      expect(bookmarks.last, const Duration(seconds: 87));
      expect(session.closes, greaterThanOrEqualTo(1));
      await session.events.close();
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      configureAccessibleRendererRuntime(useFlutterOnIos: false);
    });
  }

  testWidgets(
    'A failed load leaves local playback untouched and allows retry',
    (tester) async {
      final session = FakeSession()..reject = true;
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
            position: () => Duration.zero,
            onStarted: () async {
              started = true;
            },
            onPosition: (_) async {},
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
      expect(started, isFalse);
      expect(find.textContaining('Casting failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.events.close();
    },
  );
}
