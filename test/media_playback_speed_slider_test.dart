import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/media_playback_speed.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_episode_player_screen.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
// The public platform interface is supplied by the video_player dependency.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _VideoBackend extends VideoPlayerPlatform {
  final requestedRates = <double>[];
  double speed = 1;
  bool playing = false;
  bool rejectNextRate = false;
  Completer<void>? holdNextRate;
  int _rateCallsInFlight = 0;
  int maximumRateCallsInFlight = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(minutes: 10),
      size: const Size(640, 360),
    ),
  );

  @override
  Future<void> setPlaybackSpeed(int playerId, double playbackSpeed) async {
    requestedRates.add(playbackSpeed);
    _rateCallsInFlight++;
    if (_rateCallsInFlight > maximumRateCallsInFlight) {
      maximumRateCallsInFlight = _rateCallsInFlight;
    }
    final gate = holdNextRate;
    holdNextRate = null;
    try {
      if (gate != null) await gate.future;
      speed = playbackSpeed;
      if (rejectNextRate) {
        rejectNextRate = false;
        throw PlatformException(code: 'rate_unavailable');
      }
    } finally {
      _rateCallsInFlight--;
    }
  }

  @override
  Future<void> play(int playerId) async {
    playing = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing = false;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();

  @override
  Future<void> dispose(int playerId) async {}
}

Finder _speedControl(bool fullscreen) => find.byKey(
  ValueKey(
    fullscreen ? 'media_playback_speed' : 'accessible_row_playback_speed',
  ),
);

Future<void> _pumpPlayer(
  WidgetTester tester, {
  bool fullscreen = false,
  bool audioOnly = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = fullscreen
      ? const Size(1000, 700)
      : const Size(480, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await AppSettingsService().setDisplayVideoInPortrait(fullscreen);
  await AppSettingsService().setAutoBookmarkEnabled(false);
  // Initialize just_audio's asynchronous idle streams outside FakeAsync.
  // The speed gestures below use normal widget pumping.
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PodcastEpisodePlayerScreen(
          episode: const PodcastEpisode(
            title: 'Prova velocità',
            description: '',
            audioUrl: 'file:///recorded-video.mp4',
          ),
          speedCategory: MediaPlaybackSpeedCategory.sonartube,
          isVideoSupported: !audioOnly,
          startWithVideo: !audioOnly,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
  await tester.ensureVisible(_speedControl(fullscreen));
  await tester.pump();
}

Future<void> _disposePlayer(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const SizedBox());
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

void main() {
  late _VideoBackend backend;
  late VideoPlayerPlatform originalPlatform;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.just_audio.methods'),
          (call) async {
            if (call.method == 'disposeAllPlayers' ||
                call.method == 'disposePlayer') {
              return <String, dynamic>{};
            }
            throw PlatformException(code: 'test_audio_unavailable');
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
    originalPlatform = VideoPlayerPlatform.instance;
    backend = _VideoBackend();
    VideoPlayerPlatform.instance = backend;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
  });

  testWidgets(
    'SonarMusic audio-only player exposes speed even if audio loading fails',
    (tester) async {
      await _pumpPlayer(tester, audioOnly: true);
      final list = tester.widget<UniversalAccessibleList>(
        find.byType(UniversalAccessibleList),
      );
      final row = list.sections
          .expand((section) => section.rows)
          .singleWhere((row) => row.id == 'playback_speed');
      expect(row.kind, 'slider');
      expect(row.nativeSliderAccessibilityElement, isTrue);
      expect(row.value, '1× (Normale)');
      expect(
        list.sections
            .expand((section) => section.rows)
            .any((row) => row.id == 'video'),
        isFalse,
      );
      await _disposePlayer(tester);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  for (final fullscreen in [false, true]) {
    testWidgets(
      '${fullscreen ? 'fullscreen' : 'shared'} speed slider keeps its node '
      'and applies the final rapid adjustment serially',
      (tester) async {
        await _pumpPlayer(tester, fullscreen: fullscreen);
        final control = _speedControl(fullscreen);
        final initialNode = tester.getSemantics(control);
        final nodeId = initialNode.id;
        expect(initialNode.getSemanticsData().value, '1× (Normale)');
        expect(
          initialNode.getSemanticsData().hasAction(SemanticsAction.increase),
          isTrue,
        );
        expect(backend.playing, isTrue);

        backend.requestedRates.clear();
        final gate = Completer<void>();
        backend.holdNextRate = gate;
        for (final expectedValue in ['1,25×', '1,5×', '1,75×']) {
          final node = tester.getSemantics(control);
          node.owner!.performAction(node.id, SemanticsAction.increase);
          await tester.pump();
          final updated = tester.getSemantics(control);
          expect(updated.id, nodeId);
          expect(updated.getSemanticsData().value, expectedValue);
          expect(
            updated.getSemanticsData().hasAction(SemanticsAction.increase),
            isTrue,
          );
        }
        // While the first rate is waiting on the backend, the slider remains
        // adjustable and no concurrent platform rate requests are started.
        expect(backend.requestedRates, [1.25]);
        gate.complete();
        await tester.pumpAndSettle();
        expect(backend.maximumRateCallsInFlight, 1);
        expect(backend.requestedRates, containsAllInOrder([1.25, 1.75]));
        expect(backend.requestedRates, isNot(contains(1.5)));
        expect(backend.speed, 1.75);
        expect(backend.playing, isTrue);
        expect(tester.getSemantics(control).id, nodeId);
        expect(
          await AppSettingsService().loadMediaPlaybackSpeed(
            MediaPlaybackSpeedCategory.sonartube,
          ),
          1.75,
        );

        if (!fullscreen) {
          final list = tester.widget<UniversalAccessibleList>(
            find.byType(UniversalAccessibleList),
          );
          final row = list.sections
              .expand((section) => section.rows)
              .singleWhere((row) => row.id == 'playback_speed');
          expect(row.options.map((option) => option.label), [
            '0,5×',
            '0,75×',
            '1× (Normale)',
            '1,25×',
            '1,5×',
            '1,75×',
            '2×',
          ]);
        }
        await _disposePlayer(tester);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  testWidgets(
    'a newer slider choice survives a recovered rejection without a stale error',
    (tester) async {
      await _pumpPlayer(tester);
      final control = _speedControl(false);
      final nodeId = tester.getSemantics(control).id;
      final slider = find.descendant(
        of: control,
        matching: find.byType(Slider),
      );
      final gate = Completer<void>();
      backend.holdNextRate = gate;
      backend.rejectNextRate = true;
      backend.requestedRates.clear();
      tester.widget<Slider>(slider).onChanged!(6);
      await tester.pump();
      expect(backend.requestedRates, [2]);
      tester.widget<Slider>(slider).onChanged!(4);
      await tester.pump();
      expect(tester.getSemantics(control).getSemanticsData().value, '1,5×');
      gate.complete();
      await tester.pumpAndSettle();
      expect(backend.maximumRateCallsInFlight, 1);
      expect(backend.requestedRates, containsAllInOrder([2, 1, 1.5]));
      expect(backend.speed, 1.5);
      expect(backend.playing, isTrue);
      expect(tester.getSemantics(control).id, nodeId);
      expect(tester.getSemantics(control).getSemanticsData().value, '1,5×');
      expect(
        await AppSettingsService().loadMediaPlaybackSpeed(
          MediaPlaybackSpeedCategory.sonartube,
        ),
        1.5,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastEpisodePlayerScreen)),
      );
      expect(find.text(l10n.mediaPlaybackSpeedUnavailable), findsNothing);
      await _disposePlayer(tester);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'rejected slider rate restores playback value preference and semantics node',
    (tester) async {
      await AppSettingsService().saveMediaPlaybackSpeed(
        MediaPlaybackSpeedCategory.sonartube,
        1.25,
      );
      await _pumpPlayer(tester);
      final control = _speedControl(false);
      final initialNode = tester.getSemantics(control);
      expect(initialNode.getSemanticsData().value, '1,25×');
      backend.rejectNextRate = true;
      initialNode.owner!.performAction(
        initialNode.id,
        SemanticsAction.decrease,
      );
      await tester.pumpAndSettle();
      expect(backend.speed, 1.25);
      expect(backend.playing, isTrue);
      expect(tester.getSemantics(control).id, initialNode.id);
      expect(tester.getSemantics(control).getSemanticsData().value, '1,25×');
      expect(
        await AppSettingsService().loadMediaPlaybackSpeed(
          MediaPlaybackSpeedCategory.sonartube,
        ),
        1.25,
      );
      await tester.pump(const Duration(seconds: 3));
      await _disposePlayer(tester);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
