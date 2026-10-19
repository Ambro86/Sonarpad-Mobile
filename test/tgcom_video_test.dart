import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/tgcom_video_service.dart';

const articleUrl =
    'https://www.tgcom24.mediaset.it/2026/video/francia-gli-studenti-in-protesta-bloccano-anche-il-louvre_117871344-02k.shtml';
void main() {
  final fixture = File(
    'test/fixtures/tgcom_video_louvre.html',
  ).readAsStringSync();
  test(
    'Reported video preserves the full articleBody despite RSS equality',
    () {
      final video = TgcomVideoService.parse(fixture)!;
      expect(video.guid, 'FD00000000549529');
      expect(video.description, startsWith('Proseguono anche avanti'));
      expect(
        video.description,
        contains('ha riferito una delle manifestanti.'),
      );
      expect(video.description, isNot(contains('LOUVRE BLOCCATO x sito SRV')));
      expect(
        video.title,
        'Francia, gli studenti in protesta bloccano anche il Louvre',
      );
    },
  );
  test(
    'Only TGcom video pages and validated VideoObject identifiers qualify',
    () {
      expect(TgcomVideoService.supports(articleUrl), isTrue);
      expect(
        TgcomVideoService.supports(
          articleUrl.replaceFirst('www.tgcom24.mediaset.it', 'evil.example'),
        ),
        isFalse,
      );
      expect(
        TgcomVideoService.supports(
          articleUrl.replaceFirst('/video/', '/mondo/'),
        ),
        isFalse,
      );
      expect(
        TgcomVideoService.parse(
          fixture.replaceAll('link-ott-prod.mediaset.net', 'evil.example'),
        ),
        isNull,
      );
      expect(
        TgcomVideoService.parse('<article>Just a short article</article>'),
        isNull,
      );
    },
  );
  test('Resolves redirects into a refreshable Sonarpad video episode', () async {
    var calls = 0;
    final service = TgcomVideoService(
      client: MockClient((request) async {
        calls++;
        if (request.url.host == 'link.theplatform.eu') {
          expect(request.url.queryParameters['formats'], 'M3U');
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://vod01.msf.cdn.mediaset.net/video.m3u8?token=temporary',
            },
          );
        }
        return http.Response(
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nvideo/playlist.m3u8',
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    final video = TgcomVideoService.parse(fixture)!;
    final episode = await service.resolve(video);
    expect(episode.id, 'news-video:FD00000000549529');
    expect(episode.videoUrl, episode.audioUrl);
    expect(episode.videoUrl, contains('.m3u8?token=temporary'));
    await service.resolve(video);
    expect(calls, 4); // Resolve again rather than reusing expiring URLs.
  });
  for (final status in [403, 404, 200]) {
    test(
      'Rejects HTTP $status / HTML instead of sending it to the player',
      () async {
        final service = TgcomVideoService(
          client: MockClient(
            (_) async => http.Response('<html>Unavailable</html>', status),
          ),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.resolve(TgcomVideoService.parse(fixture)!),
          throwsFormatException,
        );
      },
    );
  }
  test('Live reported TGcom video resolves to playable HLS', () async {
    final service = TgcomVideoService();
    addTearDown(service.dispose);
    final video = await service.fetch(articleUrl);
    expect(video, isNotNull);
    final episode = await service.resolve(video!);
    final client = http.Client();
    addTearDown(client.close);
    final master = await client.get(Uri.parse(episode.videoUrl!));
    expect(master.statusCode, 200);
    expect(master.body, contains('#EXTM3U'));
    final variant = master.body
        .split('\n')
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty && !s.startsWith('#'));
    final playlistUri = Uri.parse(episode.videoUrl!).resolve(variant);
    final playlist = await client.get(playlistUri);
    expect(playlist.statusCode, 200);
    expect(playlist.body, contains('#EXTINF:'));
    final segment = playlist.body
        .split('\n')
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty && !s.startsWith('#'));
    final data = await client.get(playlistUri.resolve(segment));
    expect(data.statusCode, 200);
    expect(data.bodyBytes.length, greaterThan(1000));
  }, skip: !const bool.fromEnvironment('RUN_LIVE_TGCOM_TESTS'));
}
