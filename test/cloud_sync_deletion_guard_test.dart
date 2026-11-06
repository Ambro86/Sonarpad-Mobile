import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_api.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_service.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_state.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_deletions.dart';
import 'cloud_sync_service_test.dart' show MemoryCollections;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final collection in [
    'radio',
    'tv',
    'podcasts',
    'sonartube',
    'news_sources',
    'news_folders',
    'news_articles',
    'preferences',
  ]) {
    test(
      '$collection outgoing reductions require an explicit removal command',
      () async {
        final rows = List.generate(
          30,
          (i) => <String, dynamic>{
            'id': '$i',
            'data': {'name': 'Item $i'},
          },
        );
        final before = <String, List<Map<String, dynamic>>>{collection: rows};
        final after = <String, List<Map<String, dynamic>>>{
          collection: rows.take(25).toList(),
        };
        SharedPreferences.setMockInitialValues({
          'sonarpad_cloud_sync_v1': jsonEncode({
            'group_id': 'g',
            'sequence': 1,
            'baseline': before,
          }),
        });
        FlutterSecureStorage.setMockInitialValues({
          'sonarpad_cloud_sync_token': 'a' * 64,
        });
        final collections = MemoryCollections()..value = after;
        final calls = <String>[];
        final api = CloudSyncApi(
          logger: (_) async {},
          client: MockClient((r) async {
            final action = r.url.queryParameters['action']!;
            calls.add(action);
            if (action == 'confirm_deletions') {
              return http.Response('{"confirmed":true}', 200);
            }
            final request = jsonDecode(r.body) as Map;
            return http.Response(
              jsonEncode({
                'group_id': 'g',
                'sequence': request['sequence'],
                'state': request['state'],
              }),
              200,
            );
          }),
        );
        final service = CloudSyncService(api: api, collections: collections);
        await expectLater(
          service.synchronize(),
          throwsA(
            isA<CloudSyncApiException>().having(
              (e) => e.code,
              'code',
              'deletion_confirmation_required',
            ),
          ),
        );
        expect(calls, isEmpty);
        await service.automaticTick();
        expect(calls, isEmpty);
        final meta = await service.metadata();
        expect(meta['recovery'][0]['state'][collection].length, 30);

        await CloudSyncDeletions.record(
          collection,
          rows.skip(25).map((row) => row['id'] as String),
        );
        await service.synchronize();
        expect(calls, ['confirm_deletions', 'sync']);
        expect(collections.value[collection]!.length, 25);
        collections.value = {collection: []};
        await expectLater(
          service.synchronize(),
          throwsA(isA<CloudSyncApiException>()),
        );
        expect(calls.length, 2);

        api.close();
      },
    );
    test(
      '$collection incoming reduction requires a server deletion proof',
      () async {
        final rows = List.generate(
          30,
          (i) => <String, dynamic>{
            'id': '$i',
            'data': {'name': 'Item $i'},
          },
        );
        final before = <String, List<Map<String, dynamic>>>{collection: rows};
        SharedPreferences.setMockInitialValues({
          'sonarpad_cloud_sync_v1': jsonEncode({
            'group_id': 'g',
            'sequence': 1,
            'baseline': before,
          }),
        });
        FlutterSecureStorage.setMockInitialValues({
          'sonarpad_cloud_sync_token': 'a' * 64,
        });
        final collections = MemoryCollections()..value = before;
        var calls = 0;
        final api = CloudSyncApi(
          logger: (_) async {},
          client: MockClient((r) async {
            calls++;
            return http.Response(
              jsonEncode({
                'group_id': 'g',
                'sequence': 2,
                'state': {collection: rows.take(25).toList()},
              }),
              200,
            );
          }),
        );
        final service = CloudSyncService(api: api, collections: collections);
        await expectLater(
          service.synchronize(),
          throwsA(isA<CloudSyncApiException>()),
        );
        expect(collections.value[collection]!.length, 30);
        final meta = await service.metadata();
        expect(meta['deletion_review']['direction'], 'incoming');
        // Simulate a response carrying the server's accepted deletion proof.
        meta['response']['authorized_deletions'] = {
          collection: rows.skip(25).map((row) => row['id']).toList(),
        };
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sonarpad_cloud_sync_v1', jsonEncode(meta));
        await service.synchronize();
        expect(calls, 1);
        expect(collections.value[collection]!.length, 25);
        expect(
          (await service.metadata())['recovery'][0]['state'][collection].length,
          30,
        );
        api.close();
      },
    );
  }
  test('same-count replacement is a removal', () {
    final before = <String, List<Map<String, dynamic>>>{
      'radio': [
        {'id': 'a', 'data': {}},
      ],
    };
    final after = <String, List<Map<String, dynamic>>>{
      'radio': [
        {'id': 'b', 'data': {}},
      ],
    };
    expect(removedCloudItems(before, after)['radio']!.single['id'], 'a');
    expect(removedCloudItems(before, {}), isEmpty);
  });
}
