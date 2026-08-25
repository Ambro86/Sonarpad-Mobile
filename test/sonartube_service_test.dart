import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  test('search parses videos, channels, playlists and pagination', () async {
    late Uri requestedUri;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      clientToken: 'test-route-client-token',
      client: MockClient((request) async {
        requestedUri = request.url;
        expect(
          request.headers['X-Sonarpad-Route-Token'],
          'test-route-client-token',
        );
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 1,
            'next_token': 'next-page',
            'items': [
              {
                'kind': 'video',
                'id': 'abcdefghijk',
                'title': 'Video accessibile',
                'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                'duration': '12:34',
                'channel_id': 'UCabcdefghijklmnopqrstuv',
              },
              {
                'kind': 'channel',
                'id': 'UC123',
                'title': 'Canale accessibile',
                'url': 'https://www.youtube.com/channel/UC123',
              },
              {
                'kind': 'playlist',
                'id': 'PL123',
                'title': 'Playlist accessibile',
                'url': 'https://www.youtube.com/playlist?list=PL123',
              },
            ],
          }),
          200,
        );
      }),
    );

    final page = await service.search('accessibilità');

    expect(requestedUri.queryParameters['q'], 'accessibilità');
    expect(requestedUri.queryParameters['type'], 'all');
    expect(page.items.map((item) => item.kind), [
      SonarTubeItemKind.video,
      SonarTubeItemKind.channel,
      SonarTubeItemKind.playlist,
    ]);
    expect(page.hasMore, isTrue);
    expect(page.items.first.channelId, 'UCabcdefghijklmnopqrstuv');
  });

  test(
    'browse requests the real collection id and continuation token',
    () async {
      late Uri requestedUri;
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'ok': true,
              'page': 2,
              'items': [
                {
                  'kind': 'video',
                  'id': 'abcdefghijk',
                  'title': 'Video del canale',
                  'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                },
              ],
            }),
            200,
          );
        }),
      );
      const channel = SonarTubeItem(
        kind: SonarTubeItemKind.channel,
        id: 'UC123',
        title: 'Canale accessibile',
        url: 'https://www.youtube.com/channel/UC123',
      );

      final page = await service.browse(
        channel,
        token: 'continuation',
        page: 2,
      );

      expect(requestedUri.queryParameters['browse'], 'UC123');
      expect(requestedUri.queryParameters['kind'], 'channel');
      expect(requestedUri.queryParameters['token'], 'continuation');
      expect(page.items.single.title, 'Video del canale');
    },
  );

  test(
    'resolve keeps separate video and audio streams for the player',
    () async {
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        client: MockClient((request) async {
          expect(request.url.queryParameters['format'], 'json');
          return http.Response(
            jsonEncode({
              'ok': true,
              'title': 'Video risolto',
              'channel': 'Canale',
              'stream': 'https://media.test/video.mp4',
              'stream_video': 'https://media.test/video.mp4',
              'stream_audio': 'https://media.test/audio.m4a',
            }),
            200,
          );
        }),
      );
      const video = SonarTubeItem(
        kind: SonarTubeItemKind.video,
        id: 'abcdefghijk',
        title: 'Video',
        url: 'https://www.youtube.com/watch?v=abcdefghijk',
      );

      final media = await service.resolve(video);

      expect(media.videoUrl, 'https://media.test/video.mp4');
      expect(media.audioUrl, 'https://media.test/audio.m4a');
      expect(media.title, 'Video risolto');
    },
  );
  test('browse sends the seed video for a generated YouTube Mix', () async {
    late Uri requestedUri;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({'ok': true, 'page': 1, 'items': []}),
          200,
        );
      }),
    );
    const mix = SonarTubeItem(
      kind: SonarTubeItemKind.playlist,
      id: 'RDabcdefghijk',
      title: 'Mix',
      url: 'https://www.youtube.com/watch?v=abcdefghijk&list=RDabcdefghijk',
    );

    await service.browse(mix);

    expect(requestedUri.queryParameters['browse'], 'RDabcdefghijk');
    expect(requestedUri.queryParameters['seed'], 'abcdefghijk');
  });

  test('resolveUrl accepts a direct YouTube trailer URL', () async {
    late Uri requestedUri;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'ok': true,
            'stream': 'https://media.test/trailer.mp4',
          }),
          200,
        );
      }),
    );

    final media = await service.resolveUrl(
      'https://www.youtube.com/watch?v=trailer12345',
      fallbackTitle: 'Titolo film',
    );

    expect(
      requestedUri.queryParameters['url'],
      'https://www.youtube.com/watch?v=trailer12345',
    );
    expect(media.audioUrl, 'https://media.test/trailer.mp4');
    expect(media.title, 'Titolo film');
  });


  test('comments use the dedicated resolver mode and parse pagination', () async {
    late Uri requestedUri;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 2,
            'next_token': 'comments-next',
            'items': [
              {
                'id': 'comment-1',
                'text': 'Commento di prova',
                'author': 'Autore',
                'published': '1 giorno fa',
              },
            ],
          }),
          200,
        );
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    final page = await service.comments(video, token: 'token-1', page: 2);

    expect(requestedUri.queryParameters['comments'], '1');
    expect(requestedUri.queryParameters['token'], 'token-1');
    expect(page.items.single.text, 'Commento di prova');
    expect(page.hasMore, isTrue);
  });

  test('channel action uses stored channel id without a request', () async {
    var requested = false;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requested = true;
        return http.Response('{}', 500);
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
      channel: 'Canale',
      channelId: 'UCabcdefghijklmnopqrstuv',
    );

    final channel = await service.channelForVideo(video);

    expect(requested, isFalse);
    expect(channel.kind, SonarTubeItemKind.channel);
    expect(channel.id, 'UCabcdefghijklmnopqrstuv');
  });

  test('transcribe uses resolver transcript mode and requested app language', () async {
    late Uri requestedUri;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'ok': true,
            'title': 'Video trascritto',
            'lang': 'it',
            'auto_generated': true,
            'transcript': 'Testo completo della trascrizione.',
          }),
          200,
        );
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    final transcript = await service.transcribe(video);

    expect(requestedUri.queryParameters['transcribe'], '1');
    expect(requestedUri.queryParameters['format'], 'json');
    expect(requestedUri.queryParameters['lang'], 'auto');
    expect(transcript.text, 'Testo completo della trascrizione.');
    expect(transcript.autoGenerated, isTrue);
  });

  test('transcribe maps missing captions to transcript unavailable', () async {
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': false, 'error': 'no_captions'}),
          200,
        );
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    await expectLater(
      service.transcribe(video),
      throwsA(isA<SonarTubeTranscriptUnavailableException>()),
    );
  });

}
