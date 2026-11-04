import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_api.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_collections.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_service.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_state.dart';

class MemoryCollections extends CloudSyncCollections {
  CloudState value = {
    'radio': [
      {
        'id': 'a',
        'data': {'name': 'A'},
      },
    ],
  };
  bool failWrite = false;
  @override
  Future<CloudState> read() async =>
      parseCloudState(jsonDecode(jsonEncode(value)));
  @override
  CloudState project(CloudState state) => state;
  @override
  Future<void> write(CloudState state) async {
    if (failWrite) throw StateError('disk');
    value = state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'automatic sync batches edits, backs off, replays pending and pulls periodically',
    () async {
      var now = DateTime.utc(2026, 11, 4);
      var fail = false;
      final bodies = <String>[];
      final collections = MemoryCollections();
      final api = CloudSyncApi(
        logger: (_) async {},
        client: MockClient((r) async {
          if (r.url.queryParameters['action'] == 'create') {
            return http.Response('{"group_id":"g","sequence":0}', 200);
          }
          bodies.add(r.body);
          if (fail)
            return http.Response('{"error":"service_unavailable"}', 503);
          final body = jsonDecode(r.body) as Map;
          return http.Response(
            jsonEncode({
              'group_id': 'g',
              'sequence': body['sequence'],
              'state': body['state'],
            }),
            200,
          );
        }),
      );
      final service = CloudSyncService(
        api: api,
        collections: collections,
        clock: () => now,
      );
      await service.automaticTick();
      expect(bodies, isEmpty); // Never create/link an account automatically.
      await service.connect();
      await service
          .automaticTick(); // Opening an already linked app pulls once.
      expect(bodies.length, 2);
      collections.value['radio']!.add({
        'id': 'b',
        'data': {'name': 'B'},
      });
      now = now.add(const Duration(seconds: 10));
      await service.automaticTick();
      expect(bodies.length, 2);
      now = now.add(const Duration(seconds: 20));
      fail = true;
      await service.automaticTick(); // Does not throw or erase local edits.
      expect(bodies.length, 3);
      expect(CloudSyncService.automaticFailed, isTrue);
      now = now.add(const Duration(seconds: 30));
      await service.automaticTick();
      expect(bodies.length, 4);
      now = now.add(const Duration(seconds: 30));
      service.wake(); // Foregrounding must not defeat failure backoff.
      await service.automaticTick();
      expect(bodies.length, 4);
      collections.value['radio']!.add({
        'id': 'c',
        'data': {'name': 'C'},
      });
      fail = false;
      now = now.add(const Duration(seconds: 30));
      await service.automaticTick();
      expect(bodies[2], bodies[3]);
      expect(bodies[3], bodies[4]);
      expect(collections.value['radio']!.length, 3);
      expect(
        CloudSyncService.automaticPending,
        isTrue,
      ); // Edit during retry still needs uploading.
      now = now.add(const Duration(seconds: 30));
      await service.automaticTick();
      expect(CloudSyncService.automaticPending, isFalse);
      expect(CloudSyncService.automaticFailed, isFalse);
      final count = bodies.length;
      now = now.add(const Duration(seconds: 179));
      await service.automaticTick();
      expect(bodies.length, count);
      now = now.add(const Duration(seconds: 1));
      await service.automaticTick();
      expect(bodies.length, count + 1);
      api.close();
    },
  );

  test(
    'slow automatic request leaves event loop free and excludes concurrent sync',
    () async {
      SharedPreferences.setMockInitialValues({
        'sonarpad_cloud_sync_v1': jsonEncode({
          'group_id': 'g',
          'sequence': 0,
          'baseline': {},
        }),
      });
      FlutterSecureStorage.setMockInitialValues({
        'sonarpad_cloud_sync_token': 'a' * 64,
      });
      final response = Completer<http.Response>();
      final entered = Completer<void>();
      final api = CloudSyncApi(
        logger: (_) async {},
        client: MockClient((r) {
          entered.complete();
          return response.future;
        }),
      );
      final service = CloudSyncService(
        api: api,
        collections: MemoryCollections(),
      );
      final running = service.automaticTick();
      await entered.future;
      await Future<void>.delayed(Duration.zero);
      expect(CloudSyncService.busy, isTrue);
      await expectLater(
        service.synchronize(),
        throwsA(isA<CloudSyncApiException>()),
      );
      response.complete(http.Response('{"error":"service_unavailable"}', 503));
      await running;
      expect(CloudSyncService.busy, isFalse);
      expect((await service.metadata())['pending'], isNotNull);
      api.close();
    },
  );

  test('pending request survives failure and retries identical body', () async {
    final collections = MemoryCollections();
    final requests = <String>[];
    final api = CloudSyncApi(
      logger: (_) async {},
      client: MockClient((r) async {
        if (r.url.queryParameters['action'] == 'create') {
          return http.Response(
            '{"group_id":"g","device_id":"a","sequence":0}',
            200,
          );
        }
        requests.add(r.body);
        if (requests.length == 1) throw StateError('offline');
        final body = jsonDecode(r.body) as Map;
        return http.Response(
          jsonEncode({
            'group_id': 'g',
            'sequence': body['sequence'],
            'state': body['state'],
          }),
          200,
        );
      }),
    );
    final first = CloudSyncService(api: api, collections: collections);
    await expectLater(first.connect(), throwsA(isA<CloudSyncApiException>()));
    collections.value['radio']!.add({
      'id': 'b',
      'data': {'name': 'B'},
    });
    final resumed = CloudSyncService(api: api, collections: collections);
    await resumed.synchronize();
    expect(requests[0], requests[1]);
    expect(collections.value['radio']!.length, 2);
    expect((await resumed.metadata())['baseline']['radio'].length, 1);
    api.close();
  });

  test('local apply failure reuses response without another upload', () async {
    final collections = MemoryCollections()..failWrite = true;
    int uploads = 0;
    final api = CloudSyncApi(
      logger: (_) async {},
      client: MockClient((r) async {
        if (r.url.queryParameters['action'] == 'create')
          return http.Response('{"group_id":"g","sequence":0}', 200);
        uploads++;
        return http.Response(
          jsonEncode({
            'group_id': 'g',
            'sequence': 1,
            'state': collections.value,
          }),
          200,
        );
      }),
    );
    final service = CloudSyncService(api: api, collections: collections);
    await expectLater(service.connect(), throwsStateError);
    collections.failWrite = false;
    await service.synchronize();
    expect(uploads, 1);
    expect((await service.metadata()).containsKey('pending'), false);
    api.close();
  });

  test(
    'remote deletion wins over offline edit; independent additions survive',
    () {
      final base = <String, List<Map<String, dynamic>>>{
        'radio': [
          {
            'id': 'a',
            'data': {'name': 'A'},
          },
        ],
      };
      final local = <String, List<Map<String, dynamic>>>{
        'radio': [
          {
            'id': 'a',
            'data': {'name': 'Edited'},
          },
          {
            'id': 'b',
            'data': {'name': 'B'},
          },
        ],
      };
      final merged = mergeCloudState(
        {
          'radio': [],
          'tv': [
            {
              'id': 'tv',
              'data': {'name': 'TV'},
            },
          ],
        },
        base,
        local,
      );
      expect(merged['radio']!.map((v) => v['id']), ['b']);
      expect(merged['tv']!.length, 1);
    },
  );
  test(
    'preference scope is frozen on retry and excludes collections',
    () async {
      final collections = MemoryCollections();
      collections.value['preferences'] = [
        {
          'id': 'cutter.mode',
          'data': {'value': 'advanced'},
        },
      ];
      final requests = <Map>[];
      final api = CloudSyncApi(
        logger: (_) async {},
        client: MockClient((r) async {
          if (r.url.queryParameters['action'] == 'create')
            return http.Response(
              '{"group_id":"g","device_id":"a","sequence":0}',
              200,
            );
          final body = jsonDecode(r.body) as Map;
          requests.add(body);
          if (requests.length == 1) throw StateError('offline');
          return http.Response(
            jsonEncode({
              'group_id': 'g',
              'sequence': body['sequence'],
              'state': {...body['state'], 'radio': []},
            }),
            200,
          );
        }),
      );
      final service = CloudSyncService(api: api, collections: collections);
      await service.setScope(preferences: false, enabled: false);
      await expectLater(
        service.connect(),
        throwsA(isA<CloudSyncApiException>()),
      );
      await expectLater(
        service.setScope(preferences: true, enabled: false),
        throwsA(isA<CloudSyncApiException>()),
      );
      await service.synchronize();
      expect(requests[0], requests[1]);
      expect((requests[0]['state'] as Map).keys, ['preferences']);
      expect((await service.metadata())['baseline'].keys, ['preferences']);
      expect(collections.value.keys, [
        'preferences',
      ]); // Adapter receives selected scope only.
      api.close();
    },
  );
}
