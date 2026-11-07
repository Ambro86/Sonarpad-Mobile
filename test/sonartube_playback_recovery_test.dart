import 'dart:convert';
import 'dart:async';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SonarMusic recovery uses the HLS video endpoint without direct resolution',
    () async {
      final requests = <Uri>[];
      final music = SonarMusicService(
        client: MockClient((request) async {
          requests.add(request.url);
          expect(request.url.path, '/api/youtube_resolve.php');
          expect(request.url.queryParameters['prefer'], 'hls');
          return http.Response(
            jsonEncode({
              'ok': true,
              'stream': 'https://cdn.example/track.m3u8',
              'is_live': false,
            }),
            200,
          );
        }),
      );
      final media = await music.recoverPlayback(
        const SonarMusicItem(
          kind: 'song',
          id: 'lvaC8GmvTrY',
          videoId: 'lvaC8GmvTrY',
          title: 'Track',
        ),
      );
      expect(media.audioUrl, endsWith('.m3u8'));
      expect(media.isLive, isFalse);
      expect(requests.length, 1);
    },
  );
  test('HLS timeout gets only one fresh server request', () async {
    var calls = 0;
    final service = SonarTubeService(
      client: MockClient((request) async {
        calls++;
        throw TimeoutException('offline');
      }),
    );
    const item = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'EN3BLMPVAT4',
      title: 'Track',
      url: 'https://www.youtube.com/watch?v=EN3BLMPVAT4',
    );
    await expectLater(
      service.recoverPlayback(item),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 2);
  });
  test(
    'player recovery changes resolver even when direct resolution succeeded',
    () async {
      final hosts = <String>[];
      final service = SonarTubeService(
        client: MockClient((request) async {
          hosts.add(request.url.host);
          if (request.url.host == 'www.youtube.com') {
            return http.Response(
              jsonEncode({
                'playabilityStatus': {'status': 'OK'},
                'streamingData': {
                  'formats': [
                    {
                      'itag': 18,
                      'url': 'https://unreachable.example/video.mp4',
                      'mimeType': 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
                      'audioQuality': 'AUDIO_QUALITY_LOW',
                      'height': 360,
                    },
                  ],
                },
                'videoDetails': {
                  'videoId': 'EN3BLMPVAT4',
                  'title': 'Course lesson',
                },
              }),
              200,
            );
          }
          expect(request.url.queryParameters['prefer'], 'hls');
          expect(
            request.url.queryParameters['url'],
            'https://www.youtube.com/watch?v=EN3BLMPVAT4',
          );
          return http.Response(
            jsonEncode({
              'ok': true,
              'stream': 'https://reachable.example/video.mp4',
            }),
            200,
          );
        }),
      );
      const item = SonarTubeItem(
        kind: SonarTubeItemKind.video,
        id: 'EN3BLMPVAT4',
        title: 'Course lesson',
        url: 'https://www.youtube.com/watch?v=EN3BLMPVAT4',
      );
      final original = await service.resolve(item);
      expect(original.audioUrl, contains('unreachable.example'));
      final recovered = await service.recoverPlayback(item);
      expect(recovered.audioUrl, contains('reachable.example'));
      expect(recovered.title, item.title);
      expect(hosts, ['www.youtube.com', 'sonarpad.com']);
    },
  );
}
