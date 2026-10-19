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
