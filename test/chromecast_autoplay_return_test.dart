import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_episode_player_screen.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
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
  testWidgets('Cast next item returns to the correct local source and bookmark', (tester) async {
    final settings = AppSettingsService();
    await settings.setAutoBookmarkEnabled(true);
    const first = PodcastEpisode(title: 'First', description: '',
      audioUrl: 'https://example.org/first.mp3', id: 'sonarmusic:first');
    const second = PodcastEpisode(title: 'Second', description: '',
      audioUrl: 'https://example.org/second.mp3', id: 'sonarmusic:second');
    var advances = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PodcastEpisodePlayerScreen(episode: first,
          autoNavigateNext: true, hasNextEpisode: () => advances == 0,
          navigateEpisode: (_) async { advances++; return second; }),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    for (var i = 0; i < 30 && audio.latest?.playing != true; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(audio.latest?.playing, isTrue);
    final form = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList).first);
    unawaited(Future<void>.value(form.onEvent!(
      const AccessibleListEvent(type: 'activate', id: 'chromecast'))));
    await tester.pumpAndSettle();
    final cast = tester.widget<ChromecastScreen>(find.byType(ChromecastScreen));
    await tester.runAsync(() => cast.onStarted());
    final next = await tester.runAsync(() => cast.nextMedia!(() => true));
    expect(next!.title, 'Second');
    expect(audio.latest!.playing, isFalse);
    expect(audio.latest!.url, first.audioUrl, reason: 'Do not start next song locally');
    await tester.runAsync(() => cast.onPosition(const Duration(seconds: 73)));
    expect(await settings.getMediaBookmark(first.id!), isNull);
    expect(await settings.getMediaBookmark(second.id!), 73);
    expect(await cast.nextMedia!(() => true), isNull);
    final context = tester.element(find.byType(ChromecastScreen));
    await tester.runAsync(() async {
      Navigator.of(context).pop(const ChromecastReturn(Duration(seconds: 73), true));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    for (var i = 0; i < 30 && !audio.latest!.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(audio.latest!.url, second.audioUrl);
    expect(audio.latest!.position.inSeconds, 73);
    expect(audio.latest!.playing, isTrue);
    await disposeTestPlayer(tester);
  });

}
