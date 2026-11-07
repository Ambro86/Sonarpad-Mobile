import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/radio_station.dart';
import 'package:sonarpad_mobile_starter/screens/radio_player_screen.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:sonarpad_mobile_starter/screens/chromecast_screen.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'sonartube_audio_track_player_test.dart'
    show
        PlayerTestAudioPlatform,
        PlayerTestVideoBackend,
        PlayerTestNoLogFiles,
        pumpTestPlayer,
        disposeTestPlayer;

// Isolated from track-switch tests: just_audio keeps process-wide native state.
void main() {
  late PlayerTestVideoBackend video;
  late PlayerTestAudioPlatform audio;
  late VideoPlayerPlatform originalVideo;
  late JustAudioPlatform originalAudio;
  setUp(() {
    PathProviderPlatform.instance = PlayerTestNoLogFiles();
    SharedPreferences.setMockInitialValues({});
    originalVideo = VideoPlayerPlatform.instance;
    originalAudio = JustAudioPlatform.instance;
    video = PlayerTestVideoBackend();
    audio = PlayerTestAudioPlatform();
    VideoPlayerPlatform.instance = video;
    JustAudioPlatform.instance = audio;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => call.method == 'setActive' ? true : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.arthenica.com/ffmpeg_kit_event'),
          (_) async => null,
        );
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    VideoPlayerPlatform.instance = originalVideo;
    JustAudioPlatform.instance = originalAudio;
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
  });
  for (final enabled in [true, false]) {
    testWidgets('TV Cast respects the visibility setting: $enabled', (tester) async {
      await AppSettingsService().setChromecastButtonEnabled(enabled);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RadioPlayerScreen(
            station: const RadioStation(name: 'TV test',
              streamUrl: 'https://example.org/live.m3u8', languageCode: 'en'),
            tvChannel: TvChannel(name: 'TV test',
              url: 'https://example.org/live.m3u8', category: 'TV'),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final form = tester.widget<UniversalAccessibleList>(
        find.byType(UniversalAccessibleList).first);
      final rows = form.sections.expand((section) => section.rows);
      expect(rows.any((row) => row.id == 'chromecast'), enabled);
      if (enabled) {
        unawaited(Future<void>.value(form.onEvent!(
          const AccessibleListEvent(type: 'activate', id: 'chromecast'))));
        await tester.pumpAndSettle();
        final cast = tester.widget<ChromecastScreen>(find.byType(ChromecastScreen));
        expect(cast.live, isTrue);
        expect(cast.media.url, 'https://example.org/live.m3u8');
        expect(cast.media.mime, 'application/x-mpegURL');
      }
      await disposeTestPlayer(tester);
    });
  }
  testWidgets('Cast return reuses local audio and restores remote position', (
    tester,
  ) async {
    await pumpTestPlayer(tester, audioOnly: true, remote: true);
    expect(audio.latest!.playing, isTrue);
    final originalPlayer = audio.latest;
    final playerForm = tester.widget<UniversalAccessibleList>(
      find.byType(UniversalAccessibleList).first,
    );
    unawaited(
      Future<void>.value(
        playerForm.onEvent!(
          const AccessibleListEvent(type: 'activate', id: 'chromecast'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cast = tester.widget<ChromecastScreen>(find.byType(ChromecastScreen));
    await tester.runAsync(() => cast.onStarted());
    await tester.pumpAndSettle();
    expect(audio.latest!.playing, isFalse);
    final context = tester.element(find.byType(ChromecastScreen));
    await tester.runAsync(() async {
      Navigator.of(
        context,
      ).pop(const ChromecastReturn(Duration(seconds: 87), true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    for (var i = 0; i < 30 && !audio.latest!.playing; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ChromecastScreen), findsNothing);
    expect(audio.latest, same(originalPlayer));
    expect(audio.latest!.playing, isTrue);
    expect(audio.latest!.position.inSeconds, 87);
    await disposeTestPlayer(tester);
  });
}
