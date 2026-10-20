import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

Map<String, dynamic> lockup(String type, String id) => {
  'lockupViewModel': {
    'contentType': 'LOCKUP_CONTENT_TYPE_$type', 'contentId': id,
    'metadata': {'lockupMetadataViewModel': {'title': {'content': 'Course podcast $id'}}},
  },
};

void main() {
  test('direct empty course page follows continuation without server fallback', () async {
    var calls = 0;
    final client = MockClient((request) async {
      expect(request.url.host, 'www.youtube.com');
      calls++;
      return http.Response(jsonEncode({'contents': [
        lockup(calls == 1 ? 'PLAYLIST' : 'COURSE', 'PL$calls'),
        if (calls == 1) {'continuationItemRenderer': {'continuationEndpoint': {'continuationCommand': {'token': 'next'}}}},
      ]}), 200);
    });
    addTearDown(client.close);
    final page = await SonarTubeService(client: client).search('science', type: SonarTubeSearchType.courses);
    expect(calls, 2);
    expect(page.items.single.id, 'PL2');
    expect(page.page, 2);
  });
  for (final type in [SonarTubeSearchType.courses, SonarTubeSearchType.podcasts]) {
    final category = type == SonarTubeSearchType.courses ? 'course' : 'podcast';
    test('${type.name} uses actual collection type and preserves pagination', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.host, 'www.youtube.com');
        final body = jsonDecode(request.body) as Map;
        if (calls == 1) {
          expect(body['query'], 'science');
          expect(body['params'], 'EgIQAw==');
        } else {
          expect(body['continuation'], 'page-2');
          expect(body.containsKey('params'), isFalse);
        }
        return http.Response(jsonEncode({'contents': [
          lockup('COURSE', 'PLcourse$calls'),
          lockup('PODCAST', 'PLpodcast$calls'),
          lockup('PLAYLIST', 'PLordinary$calls'),
          {'continuationItemRenderer': {'continuationEndpoint': {'continuationCommand': {'token': 'page-${calls + 1}'}}}},
        ]}), 200);
      });
      addTearDown(client.close);
      final service = SonarTubeService(client: client);
      final first = await service.search('science', type: type);
      expect(first.items.single.id, 'PL${category}1');
      expect(first.items.single.kind, SonarTubeItemKind.playlist);
      final next = await service.search('science', type: type, token: first.nextToken, page: 2);
      expect(next.items.single.id, 'PL${category}2');
      expect(next.page, 2);
    });

    test('${type.name} fallback filters ordinary playlists and skips empty pages', () async {
      var calls = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'www.youtube.com') return http.Response('Unavailable', 503);
        calls++;
        expect(request.url.queryParameters['type'], category);
        expect(request.url.queryParameters['page'], '$calls');
        if (calls > 1) expect(request.url.queryParameters['token'], 'page-2');
        return http.Response(jsonEncode({
          'ok': true, 'page': calls, 'next_token': calls == 1 ? 'page-2' : null,
          'items': [
            {'kind': 'playlist', 'id': 'PLordinary', 'title': 'Course podcast'},
            if (calls > 1) {'kind': 'playlist', 'id': 'PLactual', 'title': 'Science', 'collection_type': category},
          ],
        }), 200);
      });
      addTearDown(client.close);
      final service = SonarTubeService(client: client, endpoint: Uri.parse('https://example.test/resolve'));
      final result = await service.search('science', type: type);
      expect(result.items.single.id, 'PLactual');
      expect(result.page, 2);
      expect(calls, 2);
    });
  }
  test('empty filtered searches stop after three pages and expose continuation', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(jsonEncode({'ok': true, 'page': calls, 'items': [], 'next_token': 'page-${calls + 1}'}), 200);
    });
    addTearDown(client.close);
    final page = await SonarTubeService(client: client, enableDirectNavigation: false).search('nothing', type: SonarTubeSearchType.courses);
    expect(calls, 3);
    expect(page.nextToken, 'page-4');
  });
}
