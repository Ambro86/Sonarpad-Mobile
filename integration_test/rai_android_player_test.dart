import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonarpad_mobile_starter/services/rai_android_player_service.dart';
import 'package:sonarpad_mobile_starter/services/android_media_playback_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android Rai native playback: redirects, cookies, tracks, pause and video',
    (tester) async {
      if (!Platform.isAndroid) return;
      final player = RaiAndroidPlayerService();
      final background = AndroidMediaPlaybackService();
      final received = <Map<dynamic, dynamic>>[];
      final subscription = player.events.listen((event) {
        if (event is Map) received.add(event);
      });
      Future<void> until(bool Function() ready) async {
        final deadline = DateTime.now().add(const Duration(seconds: 25));
        while (!ready() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 250));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(ready(), isTrue, reason: received.toString());
      }

      try {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: RaiAndroidVideoView())),
        );
        background.onPause = player.pause;
        await background.start(title: 'Rai native test', pauseLabel: 'Pause');
        await player.open(
          url: const String.fromEnvironment(
            'RAI_TEST_URL',
            defaultValue: 'http://10.0.2.2:18765/master.m3u8',
          ),
          headers: {
            'User-Agent': 'Sonarpad-Android-Test',
            'X-Sonarpad-Test': 'rai-fixture',
          },
          preferAudioDescription: true,
          videoEnabled: false,
          volume: 0,
        );
        await until(
          () => received.any(
            (e) => e['type'] == 'position' && (e['positionMs'] as num) > 1000,
          ),
        );
        expect(
          received.any(
            (e) =>
                e['type'] == 'audio_tracks' &&
                e['selectedIsAudioDescription'] == true,
          ),
          isTrue,
        );
        received.clear();
        await player.setPreferAudioDescription(false);
        await until(
          () => received.any(
            (e) =>
                e['type'] == 'audio_tracks' &&
                e['selectedIsAudioDescription'] == false,
          ),
        );
        await player.pause();
        await until(
          () => received.any(
            (e) => e['type'] == 'state' && e['playing'] == false,
          ),
        );
        received.clear();
        await player.setVideoEnabled(true);
        await player.play();
        await until(
          () =>
              received.any((e) => e['type'] == 'state' && e['playing'] == true),
        );
        expect(received.where((e) => e['type'] == 'error'), isEmpty);
      } finally {
        await player.dispose();
        await subscription.cancel();
        await background.dispose();
      }
    },
  );
}
