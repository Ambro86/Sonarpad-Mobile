import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_library_service.dart';

void main() {
  test('direct search preserves artist, song and pagination', () async {
    final service = SonarMusicService(client: MockClient((request) async {
      expect(request.url.host, 'music.youtube.com');
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['query'], 'elisa');
      return http.Response(jsonEncode({
        'contents': [
          {'musicResponsiveListItemRenderer': {
            'flexColumns': [
              {'musicResponsiveListItemFlexColumnRenderer': {'text': {'runs': [{'text': 'Luce'}]}}},
              {'musicResponsiveListItemFlexColumnRenderer': {'text': {'runs': [
                {'text': 'Elisa', 'navigationEndpoint': {'browseEndpoint': {'browseId': 'UCexample123'}}}
              ]}}},
            ],
            'navigationEndpoint': {'watchEndpoint': {'videoId': 'abc12345678'}},
          }},
          {'musicTwoRowItemRenderer': {
            'title': {'runs': [{'text': 'Elisa'}]},
            'navigationEndpoint': {'browseEndpoint': {'browseId': 'UCexample123'}}
          }},
          {'musicShelfRenderer': {'continuations': [
            {'nextContinuationData': {'continuation': 'music-next'}}
          ]}},
        ]
      }), 200);
    }), endpoint: Uri.parse('https://example.test/api/youtube_music_resolve.php'));
    final page = await service.search('elisa', type: 'song');
    expect(page.items.length, 2);
    expect(page.items.first.videoId, 'abc12345678');
    expect(page.items.first.artistId, 'UCexample123');
    expect(page.items.last.kind, 'artist');
    expect(page.nextToken, 'music-next');
  });

  test('music PHP is fallback for failed direct catalog', () async {
    final service = SonarMusicService(clientToken: 'test-token',
      endpoint: Uri.parse('https://example.test/api/youtube_music_resolve.php'),
      client: MockClient((request) async {
        if (request.method == 'POST') return http.Response('unavailable', 503);
        expect(request.url.path, '/api/youtube_music_resolve.php');
        expect(request.url.queryParameters['type'], 'album');
        expect(request.headers.entries.any((header) =>
          header.key.toLowerCase() == 'x-sonarpad-route-token' &&
          header.value == 'test-token'), isTrue);
        return http.Response(jsonEncode({'ok': true, 'items': [
          {'kind': 'album', 'id': 'MPREalbum123', 'browse_id': 'MPREalbum123', 'title': 'Album test'}
        ], 'next_token': 't2'}), 200);
      }));
    final page = await service.search('prova', type: 'album');
    expect(page.items.single.title, 'Album test');
    expect(page.nextToken, 't2');
  });

  test('favorites and recently played remain independent from SonarTube', () async {
    SharedPreferences.setMockInitialValues({});
    final library = SonarMusicLibraryService();
    const music = SonarMusicItem(kind: 'song', id: 'abc12345678',
      videoId: 'abc12345678', title: 'Un brano');
    expect(await library.toggle(music), true);
    expect((await library.favorites()).single.title, 'Un brano');
    await library.remember(music);
    await library.remember(music);
    expect((await library.recent()).length, 1);
    await library.clearHistory();
    expect(await library.recent(), isEmpty);
    expect((await library.favorites()).length, 1);
  });

  test('album and playlist links open collection rather than player', () async {
    final service = SonarMusicService(directCatalog: false);
    final album = await service.openUrl('https://music.youtube.com/browse/MPREabc123');
    expect(album.browsable, isTrue);
    expect(album.playable, isFalse);
    final playlist = await service.openUrl('https://music.youtube.com/playlist?list=PLabc123');
    expect(playlist.browseId, 'VLPLabc123');
    final song = await service.openUrl('https://music.youtube.com/watch?v=abc12345678');
    expect(song.playable, isTrue);
  });
}
