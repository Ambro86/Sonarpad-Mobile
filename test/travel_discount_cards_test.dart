import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/travel_service.dart';
import 'package:sonarpad_mobile_starter/screens/travel_screen.dart';
import 'travel_screen_test.dart' as fixtures;

class CardService extends fixtures.FakeTravel {
  List<Map<String, dynamic>>? received;
  @override
  Future<List<TravelCity>> cities(String term, String country) async => [
    TravelCity(term, term, 'FR', ''),
  ];
  @override
  Future<void> search(TravelQuery q, TravelCity from, TravelCity to) async {
    received = q.discountCards;
  }

  @override
  Future<Map<String, dynamic>> request(
    String route, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    String? method,
    String? idempotencyKey,
  }) async {
    if (route == '/v1/discount-cards') {
      expectSync(query, {
        'departure_id': 'Paris',
        'arrival_id': 'Lyon',
        'mode': 'train',
      });
      return {
        'items': [
          {
            'provider': 'sncfConnect',
            'code': 'SNCF_PassSenior',
            'name': 'Carte Senior',
            'min_age': 60,
          },
        ],
      };
    }
    return super.request(
      route,
      query: query,
      body: body,
      method: method,
      idempotencyKey: idempotencyKey,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'cards are sent only for opted-in train or bus searches and are not logged',
    () async {
      final sent = <Map<String, dynamic>>[];
      final logs = <String>[];
      final service = TravelService(
        clientToken: 'test',
        logger: (s) async {
          logs.add(s);
        },
        client: MockClient((request) async {
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{}', 201);
        }),
      );
      final q = TravelQuery(useDiscountCards: true)
        ..discountCards = [
          {'passenger_index': 0, 'provider': 'assertis', 'code': 'DIS'},
        ];
      const a = TravelCity('a', 'A', 'GB', ''),
          b = TravelCity('b', 'B', 'GB', '');
      await service.search(q, a, b);
      expect(sent.last['discount_cards'], q.discountCards);
      q.mode = 'flight';
      await service.search(q, a, b);
      expect(sent.last.containsKey('discount_cards'), isFalse);
      q.mode = 'bus';
      q.discountCards = [
        {'passenger_index': 0, 'provider': 'redcoach', 'code': 'STU'},
      ];
      await service.search(q, a, b);
      expect(sent.last['discount_cards'], q.discountCards);
      q.mode = 'train';
      q.useDiscountCards = false;
      await service.search(q, a, b);
      expect(sent.last.containsKey('discount_cards'), isFalse);
      expect(logs.join(), isNot(contains('DIS')));
      await service.close();
    },
  );

  testWidgets(
    'cards use accessible sliders, respect ages and keep passenger indexes',
    (tester) async {
      final service = CardService();
      final q = TravelQuery(
        from: 'Paris',
        to: 'Lyon',
        ages: [40, 70],
        useDiscountCards: true,
      );
      await tester.pumpWidget(
        fixtures.app(
          TravelSearchScreen(initial: q, serviceFactory: () => service),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        Future.sync(() => fixtures.row(tester, 'search').onActivate!()),
      );
      await tester.pumpAndSettle();
      expect(
        fixtures.rows(tester).map((r) => '${r.id}: ${r.title}').join('\n'),
        contains('card-0'),
      );
      expect(fixtures.row(tester, 'card-0').kind, 'text');
      final senior = fixtures.row(tester, 'card-1');
      expect(senior.kind, 'slider');
      expect(senior.options.length, 2);
      senior.onValueChanged!(1.0);
      await tester.pumpAndSettle();
      await fixtures.row(tester, 'continue').onActivate!();
      await tester.pumpAndSettle();
      expect(service.received, [
        {
          'passenger_index': 1,
          'provider': 'sncfConnect',
          'code': 'SNCF_PassSenior',
        },
      ]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
