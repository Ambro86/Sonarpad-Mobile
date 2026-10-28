import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/concert_search_service.dart';
import 'package:sonarpad_mobile_starter/screens/concert_search_screen.dart';
import 'travel_screen_test.dart' show app, row, rows;

class _LiveHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'market category, dates and pagination are passed directly to Eventim',
    () async {
      for (final market in ConcertMarket.all) {
        final service = ConcertSearchService(
          logger: (_) async {},
          client: MockClient((request) async {
            final q = request.url.queryParameters;
            expect(request.url.host, 'public-api.eventim.com');
            expect(q['categories'], market.category);
            expect(q['webId'], market.webId);
            expect(q['page'], '2');
            expect(q['date_from'], '2027-02-01');
            expect(q['city_names'], 'test-city');
            return http.Response(
              jsonEncode({
                'products': [],
                'page': 2,
                'totalPages': 2,
                'totalResults': 20,
              }),
              200,
            );
          }),
        );
        final page = await service.search(
          market,
          city: 'test-city',
          from: DateTime(2027, 2, 1),
          page: 2,
        );
        expect(page.page, 2);
        service.close();
      }
    },
  );
  test(
    'no retry on access denial; event links restricted to selected seller',
    () async {
      var count = 0;
      final service = ConcertSearchService(
        logger: (_) async {},
        client: MockClient((_) async {
          count++;
          return http.Response('', 403);
        }),
      );
      await expectLater(
        service.search(ConcertMarket.all.first),
        throwsA(isA<ConcertSearchException>()),
      );
      expect(count, 1);
      for (final url in [
        'http://www.ticketone.it/event/a',
        'https://www.ticketone.it.evil.test/',
        'https://user@www.ticketone.it/',
        'https://www.ticketone.it:444/',
      ]) {
        expect(
          () => ConcertSearchService.eventUrl(ConcertMarket.all.first, url),
          throwsA(isA<ConcertSearchException>()),
        );
      }
      service.close();
    },
  );
  test(
    'Safari is used from the first request and retained for subsequent pages',
    () async {
      var regularCalls = 0, browserCalls = 0, creations = 0;
      final logs = <String>[];
      final service = ConcertSearchService(
        logger: (line) async {
          logs.add(line);
        },
        client: MockClient((_) async {
          regularCalls++;
          return http.Response('Access Denied', 403);
        }),
        browserClientFactory: () async {
          creations++;
          return MockClient((request) async {
            browserCalls++;
            expect(request.url.queryParameters['city_names'], 'Torino');
            return http.Response(
              jsonEncode({
                'products': [],
                'page': int.parse(request.url.queryParameters['page']!),
                'totalPages': 2,
                'totalResults': 21,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          });
        },
      );
      try {
        await service.search(ConcertMarket.all.first, city: 'Torino');
        await service.search(ConcertMarket.all.first, city: 'Torino', page: 2);
        expect(regularCalls, 0);
        expect(browserCalls, 2);
        expect(creations, 1);
        expect(
          logs.any((s) => s.contains('profile=safariIos1811 http=200')),
          isTrue,
        );
      } finally {
        service.close();
      }
    },
  );
  test(
    'Safari denial stops; authentication and rate limits do not switch clients',
    () async {
      for (final status in [401, 403, 429]) {
        var browserCalls = 0;
        final service = ConcertSearchService(
          logger: (_) async {},
          client: MockClient(
            (_) async => throw StateError('Dart client must not be used'),
          ),
          browserClientFactory: () async => MockClient((_) async {
            browserCalls++;
            return http.Response('Access Denied', status);
          }),
        );
        try {
          await expectLater(
            service.search(ConcertMarket.all.first),
            throwsA(
              isA<ConcertSearchException>().having(
                (e) => e.code,
                'code',
                'access',
              ),
            ),
          );
          expect(browserCalls, 1);
        } finally {
          service.close();
        }
      }
    },
  );
  testWidgets(
    'accessible date sliders, clean city choice and results; chosen city remembered',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = ConcertSearchService(
        logger: (_) async {},
        client: MockClient((request) async {
          final city = request.url.path.endsWith('/cities');
          return http.Response(
            jsonEncode({
              city ? 'cities' : 'products': city
                  ? [
                      {'cityId': '217', 'name': 'Torino'},
                    ]
                  : [
                      {
                        'name': 'Concerto prova',
                        'productId': '1',
                        'link': 'https://www.ticketone.it/event/test',
                        'typeAttributes': {
                          'liveEntertainment': {
                            'startDate': '2027-02-01T21:30:00+01:00',
                            'location': {'city': 'Torino', 'name': 'Sala'},
                          },
                        },
                      },
                    ],
              'page': 1,
              'totalPages': 2,
              'totalResults': 25,
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(app(ConcertSearchScreen(service: service)));
      await tester.pumpAndSettle();
      expect(row(tester, 'country').kind, 'slider');
      row(tester, 'dates').onValueChanged!(true);
      await tester.pumpAndSettle();
      expect(row(tester, 'from-day').kind, 'slider');
      expect(row(tester, 'to-year').kind, 'slider');
      row(tester, 'city').onValueChanged!('torino');
      row(tester, 'search').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'item-0').title, 'Torino');
      row(tester, 'item-0').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'item-0').title, contains('21:30'));
      expect(rows(tester).any((r) => r.id == 'city'), isFalse);
      expect(row(tester, 'next').enabled, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'concert_chosen_city',
        ),
        'Torino',
      );
      await tester.pumpWidget(const SizedBox());
      service.close();
    },
  );
  test(
    'live Dart client searches each configured concert catalogue',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final service = ConcertSearchService(logger: (_) async {});
      try {
        for (final market in ConcertMarket.all) {
          final result = await service.search(market);
          expect(result.items, isNotEmpty, reason: market.country);
          expect(result.total, greaterThan(0), reason: market.country);
          final event = result.items.first;
          ConcertSearchService.eventUrl(market, event['link']);
          // ignore: avoid_print
          print(
            'LIVE ${market.country}: ${result.total} results, ${result.pages} pages',
          );
        }
      } finally {
        service.close();
      }
    }, _LiveHttpOverrides()),
    skip: !const bool.fromEnvironment('RUN_LIVE_CONCERT_TESTS'),
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
