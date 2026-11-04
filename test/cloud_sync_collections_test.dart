import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_collections.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_state.dart';

Map<String, dynamic> row(String id, Map<String, dynamic> data) => {
  'id': id,
  'data': data,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('old Windows virtual favorites entry does not block real feeds', () async {
    final adapter=CloudSyncCollections();
    final state=<String,List<Map<String,dynamic>>>{'news_sources':[
      row('it:sonarpad://rss/favorites',{'language':'it','title':'Favorites','url':'sonarpad://rss/favorites','folder_path':[]}),
      row('it:https://example.org/feed',{'language':'it','title':'Feed','url':'https://example.org/feed','folder_path':[]}),
    ]};
    expect(adapter.project(state)['news_sources']!.single['id'],'it:https://example.org/feed');
    await adapter.write(state);
    expect((await adapter.read())['news_sources']!.single['id'],'it:https://example.org/feed');
  });
  test(
    'desktop collections round trip through existing mobile persistence',
    () async {
      final adapter = CloudSyncCollections();
      final state = <String, List<Map<String, dynamic>>>{
        'radio': [
          row('https://example.invalid/radio', {
            'name': 'Radio',
            'stream_url': 'https://example.invalid/radio',
            'language_code': 'it',
          }),
        ],
        'tv': [
          row('test tv', {'name': 'Test TV'}),
        ],
        'podcasts': [
          row('https://example.invalid/feed', {
            'title': 'Podcast',
            'url': 'https://example.invalid/feed',
          }),
        ],
        'sonartube': [
          row('https://www.youtube.com/playlist?list=test', {
            'title': 'Playlist',
            'url': 'https://www.youtube.com/playlist?list=test',
          }),
        ],
        'news_sources': [
          row('it:https://example.invalid/news', {
            'language': 'it',
            'title': 'Custom News',
            'url': 'https://example.invalid/news',
            'folder_path': ['News', 'Local'],
          }),
        ],
        'news_folders': [
          row('it:["News","Local"]', {
            'language': 'it',
            'path': ['News', 'Local'],
          }),
        ],
        'news_articles': [
          row('https://example.invalid/article', {
            'title': 'Article',
            'link': 'https://example.invalid/article',
            'description': 'Text',
          }),
        ],
      };
      await adapter.write(state);
      final local = await adapter.read();
      expect(local, adapter.project(state));
      expect(local.containsKey('news_articles'), false);
      await adapter.write(state);
      expect(await adapter.read(), local);
    },
  );

  test(
    'invalid remote URL is rejected before replacing local preferences',
    () async {
      final adapter = CloudSyncCollections();
      final original = await adapter.read();
      final bad = parseCloudState(original);
      bad['radio'] = [
        row('bad', {
          'name': 'Bad',
          'stream_url': 'file:///private',
          'language_code': 'it',
        }),
      ];
      await expectLater(adapter.write(bad), throwsFormatException);
      expect(await adapter.read(), original);
    },
  );
}
