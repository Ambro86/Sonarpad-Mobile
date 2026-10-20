import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';

Map<String, dynamic> section(String title, String params) => {
  'musicCarouselShelfRenderer': {
    'header': {'musicCarouselShelfBasicHeaderRenderer': {
      'title': {'runs': [{'text': title}]},
      'moreContentButton': {'buttonRenderer': {'navigationEndpoint': {'browseEndpoint': {
        'browseId': 'MPADartist', 'params': params,
      }}}},
    }}, 'contents': [],
  },
};

void main() {
  test('pagination retains anonymous visitor context', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final body = jsonDecode(request.body) as Map;
      if (calls == 2) {
        expect(body['context']['client']['visitorData'], 'visitor-example');
        expect(request.headers['X-Goog-Visitor-Id'], 'visitor-example');
        expect(body['continuation'], 'page-two');
      }
      return http.Response(jsonEncode({
        'responseContext': {'visitorData': 'visitor-example'},
        'contents': [{'musicTwoRowItemRenderer': {
          'title': {'runs': [{'text': 'Album $calls'}]},
          'navigationEndpoint': {'browseEndpoint': {'browseId': 'MPRE$calls'}},
        }}], 'continuations': [{'nextContinuationData': {'continuation': 'page-two'}}],
      }), 200);
    });
    addTearDown(client.close);
    final service = SonarMusicService(client: client);
    final first = await service.search('Grateful Dead', type: 'album');
    await service.search('Grateful Dead', type: 'album', token: first.nextToken, page: 2);
    expect(calls, 2);
  });

  test('artist PHP response retains album sections alongside top songs', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({
      'ok': true,
      'items': [{'kind': 'song', 'id': 'abcdefghijk', 'title': 'Song', 'video_id': 'abcdefghijk'}],
      'sections': [{'items': [{'kind': 'collection', 'id': 'MPADartist', 'browse_id': 'MPADartist', 'browse_params': 'albums', 'title': 'Albums'}]}],
    }), 200));
    addTearDown(client.close);
    final page = await SonarMusicService(client: client, directCatalog: false).browse('UCartist');
    expect(page.items.map((item) => item.kind), ['song', 'collection']);
  });
  test('artist exposes distinct Albums and Singles endpoints and persists parameters', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final body = jsonDecode(request.body) as Map;
      if (calls == 1) {
        return http.Response(jsonEncode({'contents': [section('Albums', 'albums%3D'), section('Singles', 'singles%3D')]}), 200);
      }
      expect(body['browseId'], 'MPADartist');
      expect(body['params'], 'albums%3D');
      return http.Response(jsonEncode({'contents': {'gridRenderer': {'items': [{
        'musicTwoRowItemRenderer': {
          'title': {'runs': [{'text': 'American Beauty'}]},
          'navigationEndpoint': {'browseEndpoint': {'browseId': 'MPREalbum'}},
        },
      }]}}}), 200);
    });
    addTearDown(client.close);
    final service = SonarMusicService(client: client);
    final artist = await service.browse('UCartist');
    expect(artist.items, hasLength(2));
    expect(artist.items.map((item) => item.key).toSet(), hasLength(2));
    final saved = SonarMusicItem.fromJson(artist.items.first.toJson());
    final albums = await service.browse(saved.browseId!, params: saved.browseParams);
    expect(albums.items.single.title, 'American Beauty');
    expect(albums.items.single.kind, 'album');
  });

  test('album title navigation is parsed even without a row endpoint', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'music.youtube.com');
      return http.Response(jsonEncode({'contents': [{'musicResponsiveListItemRenderer': {
        'flexColumns': [{'musicResponsiveListItemFlexColumnRenderer': {'text': {'runs': [{
          'text': 'American Beauty', 'navigationEndpoint': {'browseEndpoint': {'browseId': 'MPREalbum'}},
        }]}}}],
      }}]}), 200);
    });
    addTearDown(client.close);
    final result = await SonarMusicService(client: client).search('Grateful Dead', type: 'album');
    expect(result.items.single.kind, 'album');
  });

  test('malformed item without an endpoint is skipped without requiring PHP', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'music.youtube.com') {
        return http.Response(jsonEncode({'contents': [
          for (var i = 0; i < 3; i++) {'musicTwoRowItemRenderer': {
            'title': {'runs': [{'text': 'Album $i'}]},
            if (i < 2) 'navigationEndpoint': {'browseEndpoint': {'browseId': 'MPRE$i'}},
          }},
        ]}), 200);
      }
      fail('Malformed entries must not force a PHP request');
    });
    addTearDown(client.close);
    final result = await SonarMusicService(client: client).search('Grateful Dead', type: 'album');
    expect(result.items, hasLength(2));
  });

  test('PHP discography request preserves endpoint and parameters', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['browse'], 'MPADartist');
      expect(request.url.queryParameters['params'], 'albums%3D');
      return http.Response('{"ok":true,"items":[]}', 200);
    });
    addTearDown(client.close);
    await SonarMusicService(client: client, directCatalog: false).browse('MPADartist', params: 'albums%3D');
  });
}
