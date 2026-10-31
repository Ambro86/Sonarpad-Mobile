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
  bool bookingSucceeds = false;
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
                  {
                    'title': 'Base',
                    'description': 'Condizioni<br>prova',
                    'cancellationDescription': 'Non rimborsabile',
                  },
                ],
                'amenities': [
                  {'name': 'Valigia non inclusa'},
                  {'name': '<b>Bagaglio a mano incluso</b>'},
                  {'name': 'Valigia non inclusa'},
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
      if (bookingSucceeds) {
        return {
          'status': 'created',
          'passenger_url':
              'https://www.omio.com/app/booking/test/passenger-details',
        };
      }
      throw const TravelException('timeout');
    }
    if (route == '/v1/booking/form') {
      return {
        'components': [
          {
            'name': '0.email-0',
            'title': 'Email',
            'component': 'Email',
            'validation': [
              {'type': 'required'},
            ],
          },
        ],
      };
    }
    throw StateError('Unexpected route');
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    binding.platformDispatcher.localeTestValue = const Locale('it', 'IT');
  });
  tearDown(binding.platformDispatcher.clearLocaleTestValue);
  testWidgets('landing contains only new search and recent journeys', (
    tester,
  ) async {
    await TravelWelcomeConsent().accept();
    await tester.pumpWidget(app(const TravelScreen()));
    await tester.pumpAndSettle();
    expect(rows(tester).map((r) => r.id), ['new', 'recent']);
    expect(find.text('Ricerca viaggi'), findsWidgets);
  });
  testWidgets('welcome acceptance persists after reopening travel', (
    tester,
  ) async {
    await tester.pumpWidget(app(const TravelScreen()));
    await tester.pumpAndSettle();
    expect(rows(tester).where((r) => r.id == 'new'), isEmpty);
    expect(row(tester, 'welcome-2').title, contains('affiliazione'));
    expect(await TravelWelcomeConsent().isAccepted(), isFalse);
    await row(tester, 'accept').onActivate!();
    await tester.pumpAndSettle();
    expect(await TravelWelcomeConsent().isAccepted(), isTrue);
    expect(rows(tester).map((r) => r.id), ['new', 'recent']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(const TravelScreen()));
    await tester.pumpAndSettle();
    expect(rows(tester).map((r) => r.id), ['new', 'recent']);
  });
  testWidgets('declining closes travel without saving acceptance', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SizedBox()));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const TravelScreen()),
    );
    await tester.pumpAndSettle();
    row(tester, 'decline').onActivate!();
    await tester.pumpAndSettle();
    expect(find.byType(TravelScreen), findsNothing);
    expect(await TravelWelcomeConsent().isAccepted(), isFalse);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const TravelScreen()),
    );
    await tester.pumpAndSettle();
    expect(row(tester, 'accept').enabled, isTrue);
    expect(rows(tester).where((r) => r.id == 'new'), isEmpty);
  });
  testWidgets(
    'form uses accessible sliders and reveals return date only on toggle',
    (tester) async {
      await tester.pumpWidget(app(const TravelSearchScreen()));
      await tester.pumpAndSettle();
      expect(row(tester, 'currency').value, 'EUR');
      expect(row(tester, 'country').value, 'IT');
      for (final id in [
        'currency',
        'country',
        'mode',
        'outbound-day',
        'outbound-month',
        'outbound-year',
        'passengers',
        'age-0',
      ]) {
        expect(row(tester, id).kind, 'slider');
        expect(row(tester, id).sliderStep, 1);
        expect(row(tester, id).sliderIncreasedValueLabel, isNotEmpty);
        expect(row(tester, id).sliderDecreasedValueLabel, isNotEmpty);
      }
      expect(row(tester, 'age-0').options.length, 111);
      final currency = row(tester, 'currency');
      final nextCurrencyLabel = currency.sliderIncreasedValueLabel;
      final currencySemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere(
            (widget) =>
                widget.properties.label == currency.title &&
                widget.properties.onIncrease != null,
          );
      currencySemantics.properties.onIncrease!();
      await tester.pumpAndSettle();
      expect(row(tester, 'currency').valueLabel, nextCurrencyLabel);
      await row(tester, 'outbound-day').onValueChanged!(30.0);
      await row(tester, 'outbound-month').onValueChanged!(0.0);
      await tester.pumpAndSettle();
      await row(tester, 'outbound-day').onValueChanged!(30.0);
      await tester.pumpAndSettle();
      expect(row(tester, 'outbound-day').value, '31');
      await row(tester, 'outbound-month').onValueChanged!(1.0);
      await tester.pumpAndSettle();
      expect(
        int.parse(row(tester, 'outbound-day').value!),
        inInclusiveRange(28, 29),
      );
      expect(rows(tester).where((r) => r.id.startsWith('return-')), isEmpty);
      await row(tester, 'roundtrip').onValueChanged!(true);
      await tester.pumpAndSettle();
      expect(rows(tester).where((r) => r.id.startsWith('return-')).length, 3);
      await row(tester, 'passengers').onValueChanged!(2.0);
      await tester.pumpAndSettle();
      expect(row(tester, 'age-2').kind, 'slider');
      await row(tester, 'age-2').onValueChanged!('4');
      await tester.pumpAndSettle();
      expect(row(tester, 'age-2').value, '4');
      await row(tester, 'roundtrip').onValueChanged!(false);
      await tester.pumpAndSettle();
      expect(rows(tester).where((r) => r.id.startsWith('return-')), isEmpty);
    },
  );
  testWidgets(
    'continue after fares opens the internal passenger form without launching Omio',
    (tester) async {
      final service = FakeTravel()..bookingSucceeds = true;
      await tester.pumpWidget(
        app(TravelResultsScreen(service: service, query: TravelQuery())),
      );
      await tester.pumpAndSettle();
      row(tester, 'journey-choice-1').onActivate!();
      await tester.pumpAndSettle();
      final fareList = tester.element(
        find.byType(UniversalAccessibleList).last,
      );
      final selectFare = row(tester, 'offer-fare-1').onActivate!;
      await selectFare();
      await selectFare(); // Ignore duplicate activation during the transition.
      await tester.pump();
      expect(find.text('Caricamento in corso…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(UniversalAccessibleList), findsNothing);

      await tester.pumpAndSettle();
      expect(
        identical(
          fareList,
          tester.element(find.byType(UniversalAccessibleList).last),
        ),
        isFalse,
      );
      expect(
        tester
            .widget<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList).last,
            )
            .initialFocusId,
        'fare-review-heading',
      );
      expect(row(tester, 'continue').title, 'Continua per inserire i dati');
      expect(row(tester, 'duration-0').title, 'Durata del viaggio: 1 ora');
      row(tester, 'continue').onActivate!();
      await tester.pumpAndSettle();
      expect(find.byType(TravelPassengersScreen), findsOneWidget);
      expect(row(tester, '0.email-0').kind, 'textField');
      expect(service.bookings, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
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
      expect(
        row(tester, 'offer-fare-1').subtitle,
        'Valigia non inclusa\nBagaglio a mano incluso\nCondizioni\nprova\nNon rimborsabile',
      );
      await row(tester, 'offer-fare-1').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'fare-0').title, contains('Valigia non inclusa'));
      expect(row(tester, 'fare-0').title, contains('Non rimborsabile'));
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
