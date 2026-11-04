import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_api.dart';

void main() {
  final token = List.filled(64, 'a').join();
  test(
    'uses production endpoint and logs correlation without secrets',
    () async {
      final logs = <String>[];
      final api = CloudSyncApi(
        logger: (s) async => logs.add(s),
        client: MockClient((r) async {
          expect(
            r.url.toString(),
            'https://sonarpad.com/synk/index.php?action=join',
          );
          expect(r.headers['Authorization'], 'Bearer $token');
          expect(r.followRedirects, false);
          expect(jsonDecode(r.body)['code'], '12345678');
          return http.Response(
            '{"group_id":"private-group","state":{}}',
            200,
            headers: {'x-request-id': 'deadbeefdeadbeef'},
          );
        }),
      );
      await api.request(CloudSyncAction.join, token, {'code': '12345678'});
      expect(logs.join(), contains('request_id=deadbeefdeadbeef'));
      for (final secret in [token, '12345678', 'private-group']) {
        expect(logs.join(), isNot(contains(secret)));
      }
      api.close();
    },
  );

  test('raw server errors and transport messages never reach logs', () async {
    final logs = <String>[];
    final api = CloudSyncApi(
      logger: (s) async => logs.add(s),
      client: MockClient(
        (r) async => http.Response(
          '{"error":"PRIVATE_FAVORITES_AND_TOKEN"}',
          500,
          headers: {'x-request-id': 'PRIVATE_TOKEN'},
        ),
      ),
    );
    await expectLater(
      api.request(CloudSyncAction.sync, token, {}),
      throwsA(
        isA<CloudSyncApiException>().having(
          (e) => e.code,
          'code',
          'http_error',
        ),
      ),
    );
    expect(logs.join(), isNot(contains('PRIVATE')));
    expect(logs.join(), contains('status=500'));
    api.close();
  });

  test('diagnostic failures do not fail a successful request', () async {
    final api = CloudSyncApi(
      logger: (_) async => throw StateError('disk'),
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(await api.request(CloudSyncAction.state, token, {}), isEmpty);
    api.close();
  });

  test('timeout reports a safe error', () async {
    final logs = <String>[];
    final api = CloudSyncApi(
      timeout: const Duration(milliseconds: 1),
      logger: (s) async => logs.add(s),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.request(CloudSyncAction.state, token, {}),
      throwsA(
        isA<CloudSyncApiException>().having((e) => e.code, 'code', 'timeout'),
      ),
    );
    expect(logs.join(), contains('error=timeout'));
    api.close();
  });
}
