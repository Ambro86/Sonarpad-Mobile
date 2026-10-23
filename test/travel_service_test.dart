import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/travel_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'authenticated flow preserves session, locale, currency, ages and dates',
    () async {
      final calls = <http.Request>[];
      final logs = <String>[];
      final service = TravelService(
        clientToken: 'test-build-token',
        logger: (s) async {
          logs.add(s);
        },
        client: MockClient((r) async {
          calls.add(r);
          expect(r.url.host, 'sonarpad.com');
          expect(r.followRedirects, isFalse);
          expect(r.headers['X-Sonarpad-Route-Token'], 'test-build-token');
          final route = r.url.queryParameters['route'];
          if (route == '/v1/sessions') {
            expect(jsonDecode(r.body), {'locale': 'en-US', 'currency': 'GBP'});
            return http.Response(
              jsonEncode({
                'token': 'test-session-private',
                'locale': 'en',
                'currency': 'GBP',
              }),
              201,
            );
          }
          expect(r.headers['X-Sonarpad-Session'], 'test-session-private');
          if (route == '/v1/cities') {
            return http.Response(
              jsonEncode({
                'items': [
                  {'id': '2', 'name': 'Paris', 'country': 'US'},
                  {'id': '1', 'name': 'Paris', 'country': 'FR'},
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      await service.start('en_US', 'GBP');
      final cities = await service.cities('Paris', 'FR');
      expect(cities.first.id, '1');
      expect(cities.length, 2);
      await service.search(
        TravelQuery(
          departure: DateTime(2027, 1, 2),
          returnDate: DateTime(2027, 1, 5),
          ages: [40, 3],
          mode: 'flight',
        ),
        cities[0],
        cities[1],
      );
      expect(jsonDecode(calls.last.body), containsPair('ages', [40, 3]));
      expect(
        jsonDecode(calls.last.body),
        containsPair('return_date', '2027-01-05'),
      );
      await service.results(page: 2, outbound: 'private-choice');
      expect(
        calls.last.url.queryParameters['outbound_choice'],
        'private-choice',
      );
      await service.close();
      final text = logs.join('\n');
      for (final secret in [
        'test-build-token',
        'test-session-private',
        'private-choice',
        'Paris',
        '2027-01-05',
      ]) {
        expect(text, isNot(contains(secret)));
      }
      expect(text, contains('/v1/search/inbounds'));
    },
  );
  test(
    'missing token fails locally; unsafe error bodies never reach logs',
    () async {
      final logs = <String>[];
      var calls = 0;
      final noToken = TravelService(
        clientToken: '',
        logger: (s) async {
          logs.add(s);
        },
        client: MockClient((r) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        noToken.start('it', 'EUR'),
        throwsA(isA<TravelException>()),
      );
      expect(calls, 0);
      await noToken.close();
      final service = TravelService(
        clientToken: 'test',
        logger: (s) async {
          logs.add(s);
        },
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'error': {'message': 'PRIVATE_BODY'},
              'request_id': 'abcd1234',
              'diagnostic': {
                'profile': 'chrome131',
                'error_type': 'Timeout',
                'retry_handled': true,
                'cookie': 'PRIVATE_COOKIE',
              },
            }),
            502,
          ),
        ),
      );
      await expectLater(
        service.results(),
        throwsA(
          isA<TravelException>()
              .having((e) => e.status, 'status', 502)
              .having((e) => e.reference, 'reference', 'abcd1234'),
        ),
      );
      expect(logs.join(), contains('retry_handled=true'));
      expect(logs.join(), isNot(contains('PRIVATE')));
      await service.close();
    },
  );
  test(
    'selected cities survive local persistence; history excludes sessions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final history = RecentTravelService();
      final q = TravelQuery(
        from: 'Torino',
        to: 'Palermo',
        departureCity: const TravelCity('turin-it', 'Torino', 'IT', 'Piemonte'),
        arrivalCity: const TravelCity('palermo-it', 'Palermo', 'IT', 'Sicilia'),
      );
      await history.saveLast(q);
      await history.add(q);
      await history.add(q);
      expect((await history.loadLast())!.departureCity!.id, 'turin-it');
      expect((await history.loadLast())!.arrivalCity!.id, 'palermo-it');
      expect((await history.load()).length, 1);
      await history.clear();
      expect(await history.load(), isEmpty);
      expect(DateUtilsTravel.clamp(2028, 2, 31), DateTime(2028, 2, 29));
      expect(DateUtilsTravel.clamp(2027, 2, 31), DateTime(2027, 2, 28));
    },
  );
}
