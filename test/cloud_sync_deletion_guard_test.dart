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
    'sonarmusic',
    'news_sources',
    'news_folders',
    'news_articles',
    'preferences',
  ]) {
    test(
      '$collection unexpected outgoing removals are cancelled without stopping sync',
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
        await service.synchronize();
        expect(calls, ['sync']);
        expect(collections.value, before);
        await service.automaticTick();
        expect(calls, ['sync', 'sync']);
        expect(CloudSyncService.automaticFailed, isFalse);
        final meta = await service.metadata();
        expect(meta['recovery'][0]['state'][collection].length, 30);
        expect(meta['deletion_review'], isNull);
        expect(meta['pending'], isNull);

        // Explicit removals still propagate, while an additional unproven loss
        // in the same batch is restored.
        await CloudSyncDeletions.record(
          collection,
          rows.skip(25).map((row) => row['id'] as String),
        );
        collections.value = {collection: rows.take(24).toList()};
        await service.synchronize();
        expect(calls, ['sync', 'sync', 'confirm_deletions', 'sync']);
        expect(collections.value[collection]!.length, 25);
        collections.value = {collection: []};
        await service.synchronize();
        expect(collections.value[collection]!.length, 25);
        expect(calls.last, 'sync');
        expect(calls.length, 5);

        api.close();
      },
    );
    test(
      '$collection incoming unproven loss is restored and explicit deletion still applies',
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
        var authorized = false;
        final api = CloudSyncApi(
          logger: (_) async {},
          client: MockClient((r) async {
            calls++;
            final request = jsonDecode(r.body) as Map;
            return http.Response(
              jsonEncode({
                'group_id': 'g',
                'sequence': request['sequence'],
                'state': {collection: rows.take(25).toList()},
                if (authorized)
                  'authorized_deletions': {
                    collection: rows.skip(25).map((row) => row['id']).toList(),
                  },
              }),
              200,
            );
          }),
        );
        final service = CloudSyncService(api: api, collections: collections);
        await service.synchronize();
        expect(collections.value[collection]!.length, 30);
        final meta = await service.metadata();
        expect(meta['last_cancelled_deletions']['direction'], 'incoming');
        expect(meta['deletion_review'], isNull);
        expect(meta['pending'], isNull);
        expect(CloudSyncService.automaticPending, isTrue);
        authorized = true;
        await service.synchronize();
        expect(calls, 2);
        expect(collections.value[collection]!.length, 25);
        expect(
          (await service.metadata())['recovery'][0]['state'][collection].length,
          30,
        );
        api.close();
      },
    );
  }
  final favorites = <Map<String, dynamic>>[
    for (final id in ['a', 'b', 'c'])
      {
        'id': id,
        'data': {'title': id},
      },
  ];
  CloudState state(List<Map<String, dynamic>> rows, String search) => {
    'sonartube': rows,
    'preferences': [
      {
        'id': 'sonartube.search_type',
        'data': {'value': search},
      },
    ],
  };
  void seed(Map<String, dynamic> meta) {
    SharedPreferences.setMockInitialValues({
      'sonarpad_cloud_sync_v1': jsonEncode({
        'group_id': 'g',
        'sequence': 1,
        ...meta,
      }),
    });
    FlutterSecureStorage.setMockInitialValues({
      'sonarpad_cloud_sync_token': 'a' * 64,
    });
  }

  test(
    'old blocked 3 to 0 request resumes, keeps other edits and completes again',
    () async {
      final before = state(favorites, 'videos');
      final local = state([], 'channels');
      seed({
        'baseline': before,
        'blocked_before_send': true,
        'deletion_review': {
          'direction': 'outgoing',
          'before': before,
          'after': local,
        },
        'pending': {'sequence': 2, 'baseline': before, 'state': local},
      });
      final collections = MemoryCollections()..value = local;
      var calls = 0;
      final api = CloudSyncApi(
        logger: (_) async {},
        client: MockClient((r) async {
          expect(r.url.queryParameters['action'], 'sync');
          final body = jsonDecode(r.body) as Map;
          expect(body.containsKey('pending_local_state'), isFalse);
          final sent = parseCloudState(body['state']);
          expect(sent['sonartube']!.length, 3);
          expect(sent['preferences']!.single['data']['value'], 'channels');
          sent['sonartube']![0]['data']['title'] = 'Remote title';
          calls++;
          return http.Response(
            jsonEncode({
              'group_id': 'g',
              'sequence': body['sequence'],
              'state': sent,
            }),
            200,
          );
        }),
      );
      final service = CloudSyncService(api: api, collections: collections);
      await service.synchronize();
      expect(collections.value['sonartube']!.length, 3);
      expect(
        collections.value['sonartube']!.first['data']['title'],
        'Remote title',
      );
      expect(collections.value['preferences'], local['preferences']);
      final meta = await service.metadata();
      for (final key in [
        'pending',
        'response',
        'pending_local_state',
        'deletion_review',
        'blocked_before_send',
      ]) {
        expect(meta[key], isNull, reason: key);
      }
      expect(meta['last_sync'], isNotNull);
      await service.synchronize();
      expect(calls, 2);
      expect(CloudSyncService.automaticPending, isFalse);
      api.close();
    },
  );

  for (final explicit in [false, true]) {
    test(
      'concurrent loss is cancelled and new edits survive; explicit removal=$explicit',
      () async {
        final before = state(favorites, 'videos');
        seed({'baseline': before});
        final collections = MemoryCollections()..value = before;
        final actions = <String>[];
        final api = CloudSyncApi(
          logger: (_) async {},
          client: MockClient((r) async {
            final action = r.url.queryParameters['action']!;
            actions.add(action);
            if (action == 'confirm_deletions') {
              return http.Response('{"confirmed":true}', 200);
            }
            final body = jsonDecode(r.body) as Map;
            var remote = parseCloudState(body['state']);
            if (actions.length == 1) {
              if (explicit) await CloudSyncDeletions.record('sonartube', ['a']);
              collections.value = state([
                {'id': 'new-local', 'data': {}},
              ], 'channels');
              remote['sonartube']!.add({'id': 'new-remote', 'data': {}});
            }
            return http.Response(
              jsonEncode({
                'group_id': 'g',
                'sequence': body['sequence'],
                'state': remote,
              }),
              200,
            );
          }),
        );
        final service = CloudSyncService(api: api, collections: collections);
        await service.synchronize();
        expect(
          collections.value['sonartube']!.map((r) => r['id']),
          unorderedEquals([
            if (!explicit) 'a',
            'b',
            'c',
            'new-local',
            'new-remote',
          ]),
        );
        expect(
          collections.value['preferences']!.single['data']['value'],
          'channels',
        );
        await service.synchronize();
        expect(actions, ['sync', if (explicit) 'confirm_deletions', 'sync']);
        expect(await CloudSyncDeletions.read(), isEmpty);
        expect(CloudSyncService.automaticPending, isFalse);
        api.close();
      },
    );
  }

  test(
    'repaired request is stable across network retry and unproven empty response',
    () async {
      final before = state(favorites, 'videos');
      seed({'baseline': before});
      final collections = MemoryCollections()..value = state([], 'channels');
      final bodies = <String>[];
      final api = CloudSyncApi(
        logger: (_) async {},
        client: MockClient((r) async {
          expect(r.url.queryParameters['action'], 'sync');
          bodies.add(r.body);
          if (bodies.length == 1) {
            return http.Response('{"error":"service_unavailable"}', 503);
          }
          final body = jsonDecode(r.body) as Map;
          return http.Response(
            jsonEncode({
              'group_id': 'g',
              'sequence': body['sequence'],
              'state': state([], 'channels'),
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
      final retry = CloudSyncService(api: api, collections: collections);
      await retry.synchronize();
      expect(bodies[0], bodies[1]);
      expect(collections.value['sonartube'], favorites);
      expect(
        collections.value['preferences']!.single['data']['value'],
        'channels',
      );
      expect((await retry.metadata())['pending'], isNull);
      expect(CloudSyncService.automaticPending, isTrue);
      api.close();
    },
  );

  test(
    'cached incoming response from an old blocked sync is recovered without a new request',
    () async {
      final before = state(favorites, 'videos');
      final empty = state([], 'channels');
      seed({
        'baseline': before,
        'pending': {'sequence': 2, 'baseline': before, 'state': before},
        'response': {'group_id': 'g', 'sequence': 2, 'state': empty},
        'deletion_review': {
          'direction': 'incoming',
          'before': before,
          'after': empty,
        },
      });
      final collections = MemoryCollections()..value = before;
      final api = CloudSyncApi(
        logger: (_) async {},
        client: MockClient((_) async {
          fail('The journal response must be reused');
        }),
      );
      final service = CloudSyncService(api: api, collections: collections);
      await service.synchronize();
      expect(collections.value, state(favorites, 'channels'));
      final meta = await service.metadata();
      expect(meta['sequence'], 2);
      expect(meta['deletion_review'], isNull);
      expect(meta['pending'], isNull);
      api.close();
    },
  );

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
