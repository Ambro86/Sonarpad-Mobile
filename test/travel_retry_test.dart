import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/travel_service.dart';

void main() {
  test(
    'search retries transient provider timeouts up to three attempts',
    () async {
      var calls = 0;
      final logs = <String>[];
      final delays = <Duration>[];
      final service = TravelService(
        clientToken: 'test',
        logger: (s) async {
          logs.add(s);
        },
        retryDelay: (delay) async {
          delays.add(delay);
        },
        client: MockClient((r) async {
          calls++;
          return http.Response(
            jsonEncode(
              calls < 3
                  ? {
                      'diagnostic': {'error_type': 'Timeout'},
                    }
                  : {'status': 'created'},
            ),
            calls < 3 ? 502 : 201,
          );
        }),
      );
      final result = await service.request(
        '/v1/search',
        body: {'departure_id': 'private-city'},
      );
      expect(result['status'], 'created');
      expect(calls, 3);
      expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
      expect(logs.join(' '), contains('attempt=3/3'));
      expect(logs.join(' '), isNot(contains('private-city')));
      await service.close();
    },
  );
  test(
    'retries stop at three, and never duplicate bookings or passenger submissions',
    () async {
      for (final route in [
        '/v1/cities',
        '/v1/bookings',
        '/v1/booking/passengers',
      ]) {
        var calls = 0;
        final service = TravelService(
          clientToken: 'test',
          logger: (_) async {},
          retryDelay: (_) async {},
          client: MockClient((r) async {
            calls++;
            return http.Response('{}', 503);
          }),
        );
        await expectLater(
          service.request(
            route,
            body: route == '/v1/cities' ? null : {'confirm': true},
            idempotencyKey: 'test-idempotency',
          ),
          throwsA(isA<TravelException>()),
        );
        expect(calls, route == '/v1/cities' ? 3 : 1);
        await service.close();
      }
    },
  );
  test(
    'authorization failures and provider challenges are not retried',
    () async {
      for (final status in [401, 403, 502]) {
        var calls = 0;
        final service = TravelService(
          clientToken: 'test',
          logger: (_) async {},
          retryDelay: (_) async {},
          client: MockClient((r) async {
            calls++;
            return http.Response(
              '{"diagnostic":{"challenge_detected":true}}',
              status,
            );
          }),
        );
        await expectLater(
          service.request('/v1/cities'),
          throwsA(isA<TravelException>()),
        );
        expect(calls, 1);
        await service.close();
      }
    },
  );
  test(
    'a lost search response recovers the existing search on conflict',
    () async {
      final routes = <String>[];
      final service = TravelService(
        clientToken: 'test',
        logger: (_) async {},
        retryDelay: (_) async {},
        client: MockClient((r) async {
          routes.add(r.url.queryParameters['route']!);
          if (routes.length == 1) throw http.ClientException('connection lost');
          if (routes.length == 2) return http.Response('{}', 409);
          return http.Response('{"items":[],"status":"polling"}', 200);
        }),
      );
      await service.request('/v1/search', body: {'mode': 'train'});
      expect(routes, ['/v1/search', '/v1/search', '/v1/search/results']);
      await service.close();
    },
  );
}
