import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

const playlist = SonarTubeItem(
  kind: SonarTubeItemKind.playlist,
  id: 'PLA5MwkwfgUBM',
  url: 'https://www.youtube.com/playlist?list=PLA5MwkwfgUBM',
  title: "Il viaggio dell'anima con l'Imitazione di Cristo",
);

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/sonartube_shorts_playlist.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  test(
    'channel Shorts playlist exposes its three videos without fallback',
    () async {
      var fallbackCalls = 0;
      final client = MockClient((request) async {
        if (request.url.host != 'www.youtube.com') {
          fallbackCalls++;
          return http.Response(jsonEncode({'ok': true, 'items': []}), 200);
        }
        expect(jsonDecode(request.body)['browseId'], 'VL${playlist.id}');
        return http.Response(
          jsonEncode(fixture),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final result = await SonarTubeService(client: client).browse(playlist);
      expect(result.items, hasLength(3));
      expect(result.items.first.id, 't3M339KcKZA');
      expect(
        result.items.first.title,
        '01 Come la Vanità Distorce la Vera Sapienza',
      );
      expect(result.items.first.views, '87 visualizzazioni');
      expect(
        result.items.first.url,
        'https://www.youtube.com/watch?v=t3M339KcKZA',
      );
      expect(result.items.first.thumbnailUrl, contains('/t3M339KcKZA/'));
      expect(fallbackCalls, 0);
    },
  );

  test(
    'mixed playlist keeps videos, deduplicates Shorts and follows continuation',
    () async {
      var calls = 0;
      final shorts = fixture['contents'] as List;
      final client = MockClient((request) async {
        expect(request.url.host, 'www.youtube.com');
        calls++;
        if (calls == 2) {
          expect(jsonDecode(request.body)['continuation'], 'next-shorts');
        }
        return http.Response(
          jsonEncode({
            'contents': [
              if (calls == 1)
                {
                  'playlistVideoRenderer': {
                    'videoId': 'normalVideo',
                    'title': {'simpleText': 'Traditional video'},
                    'viewCountText': {'simpleText': '100 views'},
                  },
                },
              shorts[calls - 1],
              shorts[calls - 1],
              {
                'playlistVideoRenderer': {
                  'videoId': 'unavailable',
                  'title': {'simpleText': 'Unavailable'},
                },
              },
              if (calls == 1)
                {
                  'continuationItemRenderer': {
                    'continuationEndpoint': {
                      'continuationCommand': {'token': 'next-shorts'},
                    },
                  },
                },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final service = SonarTubeService(client: client);
      final first = await service.browse(playlist);
      expect(first.items.map((v) => v.id), ['normalVideo', 't3M339KcKZA']);
      final next = await service.browse(
        playlist,
        token: first.nextToken,
        page: 2,
      );
      expect(next.items, hasLength(1));
      expect(next.items.single.id, isNot(first.items.last.id));
      expect(next.page, 2);
    },
  );

  for (final id in ['PLA5MwkwfgUBM', 'PLBeBCNdoyrBU']) {
    test('live Sentiero di luce Shorts playlist $id', () async {
      final network = http.Client();
      addTearDown(network.close);
      final client = MockClient((request) async {
        expect(
          request.url.host,
          'www.youtube.com',
          reason: 'Direct browse must parse the Shorts playlist',
        );
        final copy = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        return http.Response.fromStream(await network.send(copy));
      });
      addTearDown(client.close);
      final result = await SonarTubeService(client: client).browse(
        SonarTubeItem(
          kind: SonarTubeItemKind.playlist,
          id: id,
          title: id,
          url: 'https://www.youtube.com/playlist?list=$id',
        ),
      );
      expect(result.items, isNotEmpty);
      expect(
        result.items.every(
          (v) =>
              v.kind == SonarTubeItemKind.video && v.url.contains('/watch?v='),
        ),
        isTrue,
      );
      // ignore: avoid_print
      print('Verified playlist $id: ${result.items.length} videos');
    }, skip: !const bool.fromEnvironment('RUN_LIVE_SHORTS_PLAYLISTS'));
  }
}
