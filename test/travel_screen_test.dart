import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/travel_screen.dart';
import 'package:sonarpad_mobile_starter/services/travel_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

Widget app(Widget child) => MaterialApp(
  locale: const Locale('it'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
List<AccessibleListRow> rows(WidgetTester tester) => tester
    .widgetList<UniversalAccessibleList>(find.byType(UniversalAccessibleList))
    .last
    .sections
    .expand((s) => s.rows)
    .toList();
AccessibleListRow row(WidgetTester tester, String id) =>
    rows(tester).firstWhere((r) => r.id == id);

class FakeTravel extends TravelService {
  FakeTravel() : super(clientToken: 'test', logger: (_) async {});
  int reads = 0, searches = 0, bookings = 0;
  String? selectedCity;
  Map<String, dynamic>? bookingBody;
  String? bookingKey;
  @override
  Future<void> start(String locale, String currency) async {}
  @override
  Future<void> close() async {}
  @override
  Future<List<TravelCity>> cities(String term, String country) async =>
      term == 'Torino'
      ? [
          const TravelCity('wrong', 'Torino', 'XX', ''),
          const TravelCity('true-turin', 'Torino', 'IT', 'Piemonte'),
        ]
      : [const TravelCity('palermo', 'Palermo', 'IT', 'Sicilia')];
  @override
  Future<void> search(TravelQuery q, TravelCity from, TravelCity to) async {
    selectedCity = from.id;
    searches++;
  }

  @override
  Future<Map<String, dynamic>> results({int page = 1, String? outbound}) async {
    reads++;
    return {
      'status': 'polling',
      'count': 22,
      'page': page,
      'page_size': 10,
      'has_next': page < 3,
      'items': [
        {
          'choice_id': 'choice-$page',
          'departureTime': '2027-01-02T20:30:00+02:00',
          'arrivalTime': '2027-01-02T21:30:00+02:00',
          'departureStationName': 'Torino',
          'arrivalStationName': 'Palermo',
          'totalPrice': 1500,
          'stops': 0,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> request(
    String route, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    String? method,
    String? idempotencyKey,
  }) async {
    if (route == '/v1/search/selection') {
      return {
        'groups': [
          {
            'group': 0,
            'offers': [
              {
                'offer_choice': 'fare-1',
                'fare': [
                  {'title': 'Base', 'description': 'Condizioni<br>prova'},
                ],
                'price': {'valueInCents': 1500, 'currency': 'EUR'},
              },
            ],
          },
        ],
      };
    }
    if (route == '/v1/bookings') {
      bookings++;
      bookingBody = body;
      bookingKey = idempotencyKey;
      throw const TravelException('timeout');
    }
    throw StateError('Unexpected route');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('landing contains only new search and recent journeys', (
    tester,
  ) async {
    await tester.pumpWidget(app(const TravelScreen()));
    await tester.pumpAndSettle();
    expect(rows(tester).map((r) => r.id), ['new', 'recent']);
    expect(find.text('Ricerca viaggi'), findsWidgets);
  });
  testWidgets(
    'form uses pickers for all ages and reveals return date only on toggle',
    (tester) async {
      await tester.pumpWidget(app(const TravelSearchScreen()));
      await tester.pumpAndSettle();
      expect(row(tester, 'currency').value, 'EUR');
      expect(row(tester, 'country').value, 'IT');
      expect(row(tester, 'age-0').kind, 'picker');
      expect(row(tester, 'age-0').options.length, 111);
      expect(rows(tester).where((r) => r.id.startsWith('return-')), isEmpty);
      await row(tester, 'roundtrip').onValueChanged!(true);
      await tester.pumpAndSettle();
      expect(rows(tester).where((r) => r.id.startsWith('return-')).length, 3);
      await row(tester, 'passengers').onValueChanged!('3');
      await tester.pumpAndSettle();
      expect(row(tester, 'age-2').kind, 'picker');
      await row(tester, 'age-2').onValueChanged!('4');
      await tester.pumpAndSettle();
      expect(row(tester, 'age-2').value, '4');
      await row(tester, 'roundtrip').onValueChanged!(false);
      await tester.pumpAndSettle();
      expect(rows(tester).where((r) => r.id.startsWith('return-')), isEmpty);
    },
  );
  testWidgets(
    'remembered city ID avoids disambiguation and partial results are selectable',
    (tester) async {
      final service = FakeTravel();
      await RecentTravelService().saveLast(
        TravelQuery(
          from: 'Torino',
          to: 'Palermo',
          departureCity: const TravelCity(
            'true-turin',
            'Torino',
            'IT',
            'Piemonte',
          ),
        ),
      );
      await tester.pumpWidget(
        app(TravelSearchScreen(serviceFactory: () => service)),
      );
      await tester.pumpAndSettle();
      expect(row(tester, 'from').value, 'Torino');
      row(tester, 'search').onActivate!();
      await tester.pumpAndSettle();
      expect(
        service.searches,
        1,
        reason: rows(tester).map((r) => '${r.id}: ${r.title}').join(' | '),
      );
      expect(service.reads, 1);
      expect(service.selectedCity, 'true-turin');
      expect(row(tester, 'partial').title, contains('provvisori'));
      expect(rows(tester).where((r) => r.id == 'from'), isEmpty);
      await row(tester, 'next').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'journey-choice-2').title, contains('20:30'));
      row(tester, 'journey-choice-2').onActivate!();
      await tester.pumpAndSettle();
      await row(tester, 'offer-fare-1').onActivate!();
      await tester.pumpAndSettle();
      expect(service.bookings, 0);
      await row(tester, 'continue').onActivate!();
      await tester.pumpAndSettle();
      expect(service.bookings, 1);
      expect(service.bookingBody, {
        'offers': ['fare-1'],
        'confirm': true,
      });
      expect(service.bookingKey, isNotEmpty);
      expect(row(tester, 'continue').enabled, isFalse);
      expect(row(tester, 'error').title, contains('Non ripetere'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
