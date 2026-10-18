import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/chromecast_session.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  test(
    'live app Cast sender plays audio and a resolved SonarTube video',
    () async {
      final host = Platform.environment['SONARPAD_CAST_HOST']!;
      final resolved = await SonarTubeService(
        endpoint: Uri.parse('http://127.0.0.1:9'),
      ).resolveUrl('RE3_PGwDwhw', fallbackTitle: 'SonarTube Cast test');
      expect(
        resolved.videoUrl,
        isNull,
        reason: 'This live sample must have a combined stream',
      );
      for (final media in [
        (
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          'audio/mpeg',
        ),
        (resolved.audioUrl, 'video/mp4'),
      ]) {
        final session = ChromecastSession();
        try {
          // ignore: avoid_print
          print('Cast live: ${media.$2} connect');
          await session.connect(
            ChromecastDevice('test', 'Sonarpad-Test', host, 8009),
          );
          // ignore: avoid_print
          print('Cast live: load');
          await session.load(
            url: media.$1,
            mime: media.$2,
            title: 'Sonarpad Cast test',
            position: Duration.zero,
          );
          final deadline = DateTime.now().add(const Duration(seconds: 25));
          while (session.status.position.inSeconds < 2 &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(seconds: 1));
            await session.refresh();
          }
          expect(session.status.position.inSeconds, greaterThanOrEqualTo(2));
          // ignore: avoid_print
          print('Cast live: pause');
          await session.command('PAUSE');
          await Future<void>.delayed(const Duration(seconds: 1));
          await session.refresh();
          expect(session.status.state, 'PAUSED');
          // ignore: avoid_print
          print('Cast live: seek');
          await session.seek(const Duration(seconds: 30));
          await session.command('PLAY');
          await Future<void>.delayed(const Duration(seconds: 4));
          await session.refresh();
          expect(session.status.position.inSeconds, greaterThan(30));
          expect(session.status.state, 'PLAYING');
          // ignore: avoid_print
          print('Cast live: volume');
          await session.setVolume(0.5);
          await session.refresh();
          expect(session.status.volume, closeTo(0.5, 0.05));
        } finally {
          await session.close();
        }
      }
    },
    skip: Platform.environment['SONARPAD_CAST_HOST'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
