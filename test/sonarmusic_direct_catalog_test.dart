import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';

Map<String, dynamic> browse(String id, String type) => {'browseEndpoint': {
  'browseId': id, 'browseEndpointContextSupportedConfigs': {
    'browseEndpointContextMusicConfig': {'pageType': type},
  },
}};
Map<String, dynamic> watch(String id, String type) => {'watchEndpoint': {
  'videoId': id, 'watchEndpointMusicSupportedConfigs': {
    'watchEndpointMusicConfig': {'musicVideoType': type},
  },
}};
Map<String, dynamic> overlay(Map<String, dynamic> endpoint) => {
  'musicItemThumbnailOverlayRenderer': {'content': {'musicPlayButtonRenderer': {
    'playNavigationEndpoint': endpoint,
  }}},
};

void main() {
  test('native Dart handles cards, overlays, explicit page types and title endpoints', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'music.youtube.com');
      return http.Response(jsonEncode({'contents': [
        {'musicResponsiveListItemRenderer': {
          'flexColumns': [{'musicResponsiveListItemFlexColumnRenderer': {'text': {'runs': [{'text': 'Album'}]}}}],
          'navigationEndpoint': browse('MPREalbum', 'MUSIC_PAGE_TYPE_ALBUM'),
          'overlay': overlay(watch('preview0001', 'MUSIC_VIDEO_TYPE_ATV')),
        }},
        {'musicTwoRowItemRenderer': {
          'title': {'runs': [{'text': 'Video'}]},
          'onTap': watch('video000001', 'MUSIC_VIDEO_TYPE_OFFICIAL_SOURCE_MUSIC'),
        }},
        {'musicCardShelfRenderer': {
          'title': {'runs': [{'text': 'Song'}]},
          'overlay': overlay(watch('song0000001', 'MUSIC_VIDEO_TYPE_ATV')),
          'subtitle': {'runs': [
            {'text': 'Artist', 'navigationEndpoint': browse('UCartist', 'MUSIC_PAGE_TYPE_ARTIST')},
            {'text': ' • '}, {'text': '3:45'},
          ]},
        }},
        {'musicTwoRowItemRenderer': {
          'title': {'runs': [{'text': 'Podcast'}]},
          'navigationEndpoint': browse('MPSPpodcast', 'MUSIC_PAGE_TYPE_PODCAST_SHOW_DETAIL_PAGE'),
        }},
        {'musicTwoRowItemRenderer': {
          'title': {'runs': [{'text': 'Episode'}]},
          'overlay': overlay(watch('episode0001', 'MUSIC_VIDEO_TYPE_PODCAST_EPISODE')),
        }},
        {'musicResponsiveListItemRenderer': {
          'navigationEndpoint': {'clickTrackingParams': 'only-tracking'},
          'flexColumns': [{'musicResponsiveListItemFlexColumnRenderer': {'text': {'runs': [{
            'text': 'Playlist', 'navigationEndpoint': browse('VLplaylist', 'MUSIC_PAGE_TYPE_PLAYLIST'),
          }]}}}],
        }},
        {'musicTwoRowItemRenderer': {
          'title': {'runs': [{'text': 'Artist'}]},
          'navigationEndpoint': browse('UCartist', 'MUSIC_PAGE_TYPE_ARTIST'),
        }},
      ]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    addTearDown(client.close);
    final page = await SonarMusicService(client: client).search('music');
    expect(page.items.map((item) => item.kind), ['album', 'video', 'song', 'podcast', 'episode', 'playlist', 'artist']);
    expect(page.items.first.id, 'MPREalbum');
    expect(page.items.first.videoId, isNull);
    expect(page.items[2].artist, 'Artist');
    expect(page.items[2].duration, '3:45');
    expect(page.items[4].playable, isTrue);
  });

  test('empty native results do not force PHP fallback', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'music.youtube.com');
      return http.Response('{"contents":[]}', 200);
    });
    addTearDown(client.close);
    expect((await SonarMusicService(client: client).search('no matches')).items, isEmpty);
  });
}
