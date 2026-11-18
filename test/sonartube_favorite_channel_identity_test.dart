import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_favorites_service.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_collections.dart';

const channelId = 'UCtn7DJgu_AHaAWc2kO-o9eA';
const channelUrl = 'https://www.youtube.com/@ZackShutt';
Map<String, dynamic> channel(String id, String handle) => {
  'channelRenderer': {
    'channelId': id,
    'title': {'simpleText': 'Zack Shutt'},
    'navigationEndpoint': {'browseEndpoint': {'browseId': id, 'canonicalBaseUrl': '/$handle'}},
    'subscriberCountText': {'simpleText': '10K subscribers'},
  },
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('recovered channel ID is also used by every channel collection', () async {
    const item = SonarTubeItem(kind: SonarTubeItemKind.channel, id: '@ZackShutt',
        channelId: channelId, title: 'Zack Shutt', url: channelUrl);
    final kinds = <String>[];
    final service = SonarTubeService(client: MockClient((request) async {
      expect(request.url.queryParameters['browse'], channelId);
      kinds.add(request.url.queryParameters['kind']!);
      return http.Response(jsonEncode({'ok': true, 'items': [], 'page': 1}), 200);
    }));
    await service.channelPlaylists(item);
    await service.channelCourses(item);
    await service.channelPodcasts(item);
    await service.channelShorts(item);
    expect(kinds, ['channel_playlists', 'channel_courses', 'channel_podcasts', 'channel_shorts']);
  });
  for (final locale in ['it', 'en']) {
    for (final damaged in [false, true]) {
      test('$locale: search/save/sync/reopen channel (legacy handle=$damaged)', () async {
        SharedPreferences.setMockInitialValues({});
        final favoriteService = SonarTubeFavoritesService();
        final service = SonarTubeService(client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('/search')) {
            return http.Response(jsonEncode({'contents': [
              channel('UCabcdefghijklmnopqrstuv', '@someoneElse'),
              channel(channelId, '@ZackShutt'),
            ]}), 200);
          }
          expect(request.url.path, '/youtubei/v1/browse');
          expect(body['browseId'], channelId);
          return http.Response(jsonEncode({'contents': [{
            'videoRenderer': {
              'videoId': 'abcdefghijk', 'title': {'simpleText': 'Video'},
              'viewCountText': {'simpleText': '10 views'},
            },
          }]}), 200);
        }));
        service.setLocaleName(locale);
        if (damaged) {
          // Already damaged by an older cloud import, with otherwise complete metadata.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('sonarpad_sonartube_favorites', [jsonEncode({
            'kind': 'channel', 'id': '@ZackShutt', 'title': 'Zack Shutt',
            'url': channelUrl, 'handle': '@ZackShutt', 'subscribers': '10K',
          })]);
        } else {
          final results = await service.search('Zack Shutt', type: SonarTubeSearchType.channels);
          final result = results.items.singleWhere((item) => item.id == channelId);
          expect((await service.browse(result)).items, hasLength(1));
          await favoriteService.toggleFavorite(result);
          final cloud = CloudSyncCollections();
          final exported = await cloud.read();
          await cloud.write({'sonartube': exported['sonartube']!});
          expect((await favoriteService.loadFavorites()).single.id, channelId);
        }
        final saved = (await favoriteService.loadFavorites()).single;
        final restored = await service.refreshChannelMetadata(saved);
        expect(restored.canonicalChannelId, channelId);
        await favoriteService.updateFavoriteMetadata(restored);
        final reloaded = (await favoriteService.loadFavorites()).single;
        expect(reloaded.url, channelUrl);
        expect(reloaded.canonicalChannelId, channelId);
        expect((await service.browse(reloaded)).items.single.id, 'abcdefghijk');
        expect(await favoriteService.toggleFavorite(reloaded), isFalse);
        expect(await favoriteService.loadFavorites(), isEmpty);
      });
    }
  }
}
