import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  for (final type in [
    SonarTubeSearchType.playlists,
    SonarTubeSearchType.channels,
  ]) {
    final isPlaylist = type == SonarTubeSearchType.playlists;
    final expectedKind = isPlaylist
        ? SonarTubeItemKind.playlist
        : SonarTubeItemKind.channel;
    final apiType = isPlaylist ? 'playlist' : 'channel';
    final params = isPlaylist ? 'EgIQAw==' : 'EgIQAg==';

    test(
      '${type.name} search uses provider filter and its continuation',
      () async {
        final requests = <Map<String, dynamic>>[];
        final service = SonarTubeService(
          client: MockClient((request) async {
            expect(request.url.host, 'www.youtube.com');
            expect(request.url.path, '/youtubei/v1/search');
            final body = Map<String, dynamic>.from(
              jsonDecode(request.body) as Map,
            );
            requests.add(body);
            final isContinuation = body['continuation'] != null;
            final suffix = isContinuation ? '2' : '1';
            return http.Response(
              jsonEncode({
                'contents': [
                  {
                    'playlistRenderer': {
                      'playlistId': 'PL_flo_$suffix',
                      'title': {'simpleText': 'Flo playlist $suffix'},
                    },
                  },
                  {
                    'channelRenderer': {
                      'channelId': 'UC_flo_$suffix',
                      'title': {'simpleText': 'Flo canale $suffix'},
                    },
                  },
                  {
                    'videoRenderer': {
                      'videoId': 'abcdefghijk',
                      'title': {'simpleText': 'Video suggerito'},
                      'viewCountText': {'simpleText': '100 visualizzazioni'},
                    },
                  },
                  {
                    'continuationItemRenderer': {
                      'continuationEndpoint': {
                        'continuationCommand': {
                          'token': isContinuation ? 'page-3' : 'page-2',
                        },
                      },
                    },
                  },
                ],
              }),
              200,
            );
          }),
        );

        final first = await service.search('  flo  ', type: type);
        expect(requests, hasLength(1));
        expect(requests.single['query'], 'flo');
        expect(requests.single['params'], params);
        expect(first.items.single.kind, expectedKind);
        expect(first.nextToken, 'page-2');

        final second = await service.search(
          'flo',
          type: type,
          token: first.nextToken,
          page: 2,
        );
        expect(requests, hasLength(2));
        expect(requests.last['continuation'], 'page-2');
        expect(requests.last.containsKey('query'), isFalse);
        expect(requests.last.containsKey('params'), isFalse);
        expect(second.items.single.kind, expectedKind);
        expect(second.items.single.id, isNot(first.items.single.id));
        expect(second.page, 2);
        expect(second.nextToken, 'page-3');
      },
    );

    test(
      '${type.name} fallback keeps filter query token page and retries',
      () async {
        var directAttempts = 0;
        var fallbackAttempts = 0;
        final service = SonarTubeService(
          endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
          clientToken: 'test-token',
          client: MockClient((request) async {
            if (request.url.host == 'www.youtube.com') {
              directAttempts++;
              return http.Response('Temporary failure', 503);
            }
            fallbackAttempts++;
            expect(request.url.queryParameters['q'], 'flo');
            expect(request.url.queryParameters['type'], apiType);
            expect(request.url.queryParameters['token'], 'filtered-page-2');
            expect(request.url.queryParameters['page'], '2');
            if (fallbackAttempts == 1) {
              return http.Response('Temporary failure', 503);
            }
            return http.Response(
              jsonEncode({
                'ok': true,
                'page': 2,
                'next_token': 'filtered-page-3',
                'items': [
                  {
                    'kind': 'playlist',
                    'id': 'PL_flo',
                    'title': 'Flo playlist',
                    'url': 'https://www.youtube.com/playlist?list=PL_flo',
                  },
                  {
                    'kind': 'channel',
                    'id': 'UC_flo',
                    'title': 'Flo canale',
                    'url': 'https://www.youtube.com/channel/UC_flo',
                  },
                  {
                    'kind': 'video',
                    'id': 'abcdefghijk',
                    'title': 'Video suggerito',
                    'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                    'views': '100 visualizzazioni',
                  },
                ],
              }),
              200,
            );
          }),
        );

        final page = await service.search(
          'flo',
          type: type,
          token: 'filtered-page-2',
          page: 2,
        );
        expect(directAttempts, 2);
        expect(fallbackAttempts, 2);
        expect(page.items.single.kind, expectedKind);
        expect(page.page, 2);
        expect(page.nextToken, 'filtered-page-3');
      },
    );
  }
}
