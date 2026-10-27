import 'dart:async';
import 'dart:io';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/screens/travel_screen.dart';
import 'package:sonarpad_mobile_starter/services/travel_service.dart';
import 'travel_screen_test.dart' show app, row, rows;

class PassengerService extends TravelService {
  PassengerService() : super(clientToken: 'test', logger: (_) async {});
  final calls = <String>[];
  Map<String, dynamic>? submitted;
  bool failSubmit = false;
  final statusResponses = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? stateResponse;
  Completer<Map<String, dynamic>>? submitResponse;
  final fields = <Map<String, dynamic>>[
    {
      'name': '0.email-0',
      'title': 'Email',
      'component': 'Email',
      'validation': [
        {'type': 'required'},
      ],
    },
    {
      'name': '0.firstName-0',
      'title': 'Nome',
      'component': 'Text',
      'validation': [
        {'type': 'required'},
      ],
    },
    {
      'name': '0.lastName-0',
      'title': 'Cognome',
      'component': 'Text',
      'validation': [
        {'type': 'required'},
      ],
    },
    {
      'name': '0.dateOfBirth-0',
      'title': 'Data di nascita',
      'component': 'Date',
      'validation': [
        {'type': 'required'},
        {'type': 'pastDate'},
      ],
    },
    {
      'name': '0.countryOfResidence-0',
      'title': 'Paese',
      'component': 'CountryOfResidence',
      'validation': [
        {'type': 'required'},
      ],
    },
    {
      'name': '0.discountCard-0',
      'title': 'CartaFreccia',
      'component': 'DiscountCard',
    },
  ];
  @override
  Future<Map<String, dynamic>> request(
    String route, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    String? method,
    String? idempotencyKey,
  }) async {
    calls.add(route);
    if (route == '/v1/country-states') return await stateResponse!.future;
    if (route == '/v1/booking/form') {
      return {
        'components': [
          {'components': fields},
        ],
      };
    }
    if (route == '/v1/booking/passengers') {
      submitted = body;
      if (submitResponse != null) return await submitResponse!.future;
      if (failSubmit) throw const TravelException('timeout');
      return {'status': 'submitted'};
    }
    if (route == '/v1/booking/status') {
      if (statusResponses.isNotEmpty) return statusResponses.removeAt(0);
      return {
        'status': 'RESERVED',
        'payment_url': 'https://www.omio.com/app/booking/test/checkout',
      };
    }
    throw StateError('Unexpected endpoint');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> next(WidgetTester tester) async {
    row(tester, 'next-field').onActivate!();
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester,
    PassengerService service,
    TravelPassengerDraft draft, {
    int count = 1,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      app(
        TravelPassengersScreen(
          service: service,
          query: TravelQuery(
            departure: DateTime(2027, 10, 24),
            ages: List.filled(count, 41),
          ),
          fallbackUrl:
              'https://www.omio.com/app/booking/test/passenger-details',
          draft: draft,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Missing postcode focuses its field instead of the error text', (tester) async {
    final service = PassengerService();
    service.fields
      ..clear()
      ..addAll([
        {'name': '0.firstName-0', 'title': 'Nome', 'component': 'Text',
          'validation': [{'type': 'required'}]},
        {'name': '0.postalCode-0', 'title': 'CAP', 'component': 'Text',
          'validation': [{'type': 'required'}]},
      ]);
    final draft = TravelPassengerDraft();
    await mount(tester, service, draft);
    await row(tester, '0.firstName-0').onValueChanged!('Mario');
    await next(tester);
    final list = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
    expect(list.initialFocusId, '0.postalCode-0');
    expect(row(tester, 'error').title, contains('CAP'));
    expect(draft.position, 0);
    expect(row(tester, 'next-field').finishEditingOnActivate, isTrue);
    await tester.enterText(find.byType(TextField).last, '00100');
    expect(tester.testTextInput.isVisible, isTrue);
    final nextButton = find.text(row(tester, 'next-field').title);
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    expect(draft.position, 1);
    expect(draft.values['0.postalCode-0'], '00100');
    expect(tester.testTextInput.isVisible, isFalse);
    expect(row(tester, 'submit-passengers').enabled, isTrue);
  });

  test('iOS opted-in form action commits editing before activating Continue', () {
    final swift = File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();
    final start = swift.indexOf('  private func sendActivation(at indexPath: IndexPath)');
    final end = swift.indexOf('  @objc private func toggleControlChanged', start);
    final action = swift.substring(start, end);
    expect(action, contains('if row.finishEditingOnActivate'));
    expect(action.indexOf('sendActions(for: .editingChanged)'), lessThan(action.indexOf('tableView.endEditing(true)')));
    expect(action.indexOf('tableView.endEditing(true)'), lessThan(action.indexOf('channel.invokeMethod')));
  });

  testWidgets(
    'three travellers remain in order when later journeys use two then three',
    (tester) async {
      PassengerService serviceFor(int count) {
        final service = PassengerService();
        service.fields.clear();
        // Provider fields are deliberately interleaved; the UI must group by traveller.
        for (final field in ['firstName', 'lastName']) {
          for (var i = count - 1; i >= 0; i--) {
            service.fields.add({
              'name': '$i.$field-0',
              'title': field,
              'component': 'Text',
              'validation': [
                {'type': 'required'},
              ],
            });
          }
        }
        return service;
      }

      await mount(tester, serviceFor(3), TravelPassengerDraft(), count: 3);
      for (var i = 0; i < 3; i++) {
        await row(tester, '$i.firstName-0').onValueChanged!('Name$i');
        await row(tester, '$i.lastName-0').onValueChanged!('Surname$i');
        await next(tester);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final two = TravelPassengerDraft();
      await mount(tester, serviceFor(2), two, count: 2);
      expect(row(tester, '0.firstName-0').value, 'Name0');
      expect(two.values['1.firstName-0'], 'Name1');
      expect(two.values.keys.any((k) => k.startsWith('2.')), isFalse);
      await row(tester, '0.firstName-0').onValueChanged!('Updated0');
      await next(tester);
      expect(
        (await TravelPassengerMemory().load(passenger: 2))['firstName'],
        'Name2',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final three = TravelPassengerDraft();
      await mount(tester, serviceFor(3), three, count: 3);
      expect(three.values['0.firstName-0'], 'Updated0');
      expect(three.values['1.firstName-0'], 'Name1');
      expect(three.values['2.firstName-0'], 'Name2');
      await TravelPassengerMemory().clear();
      for (var i = 0; i < 3; i++) {
        expect(await TravelPassengerMemory().load(passenger: i), isEmpty);
      }
    },
  );

  test(
    'previous single-traveller defaults belong only to the first traveller',
    () async {
      SharedPreferences.setMockInitialValues({
        'sonarpad_travel_passenger_defaults_v1': '{"firstName":"Previous"}',
      });
      final memory = TravelPassengerMemory();
      expect((await memory.load())['firstName'], 'Previous');
      expect(await memory.load(passenger: 1), isEmpty);
      await memory.save('lastName', 'Updated');
      expect((await memory.load())['firstName'], 'Previous');
      await memory.clear();
      expect(await memory.load(), isEmpty);
    },
  );

  testWidgets(
    'passenger details persist across screens, dates use sliders, submission requires confirmation',
    (tester) async {
      final service = PassengerService(), draft = TravelPassengerDraft();
      await mount(tester, service, draft);
      expect(row(tester, '0.firstName-0').kind, 'textField');
      expect(row(tester, '0.lastName-0').kind, 'textField');
      expect(row(tester, '0.countryOfResidence-0').value, 'IT');
      expect(row(tester, '0.dateOfBirth-0:year').value, '1960');
      await row(tester, '0.email-0').onValueChanged!('invalid');
      await next(tester);
      expect(row(tester, 'error').title, contains('Controlla'));
      await row(tester, '0.email-0').onValueChanged!('sample@example.com');
      await row(tester, '0.firstName-0').onValueChanged!('Example');
      await row(tester, '0.lastName-0').onValueChanged!('Traveller');
      for (final part in ['day', 'month', 'year']) {
        expect(row(tester, '0.dateOfBirth-0:$part').kind, 'slider');
      }
      await row(tester, '0.dateOfBirth-0:day').onValueChanged!(7.0);
      await tester.pumpAndSettle();
      await row(tester, '0.dateOfBirth-0:month').onValueChanged!(6.0);
      await tester.pumpAndSettle();
      await row(tester, '0.dateOfBirth-0:year').onValueChanged!(
        (1986 - (DateTime.now().year - 120) + 1).toDouble(),
      );
      await tester.pumpAndSettle();
      expect(draft.values['0.dateOfBirth-0'], '1986-06-07');
      expect(row(tester, '0.countryOfResidence-0').kind, 'slider');
      draft.values['0.countryOfResidence-0'] = 'IT';
      final inputList = tester.element(
        find.byType(UniversalAccessibleList).last,
      );
      await next(tester);
      expect(
        identical(
          inputList,
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
        'review-passenger-0',
      );
      expect(service.submitted, isNull);
      expect(
        row(tester, 'review-0.email-0').title,
        contains('sample@example.com'),
      );
      row(tester, 'submit-passengers').onActivate!();
      await tester.pumpAndSettle();
      expect(service.submitted, {
        'confirm': true,
        'answers': {
          '0': {
            'email-0': 'sample@example.com',
            'firstName-0': 'Example',
            'lastName-0': 'Traveller',
            'dateOfBirth-0': '1986-06-07',
            'countryOfResidence-0': 'IT',
          },
        },
      });
      expect(row(tester, 'checkout').enabled, isTrue);
      expect(service.calls.where((r) => r.contains('payment')), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final reopened = TravelPassengerDraft();
      await mount(tester, PassengerService(), reopened);
      expect(row(tester, '0.email-0').value, 'sample@example.com');
      expect(reopened.values['0.firstName-0'], 'Example');
      expect(reopened.values['0.dateOfBirth-0'], '1986-06-07');
      final saved = await TravelPassengerMemory().load();
      expect(saved.keys.toSet(), {
        'email',
        'firstName',
        'lastName',
        'dateOfBirth',
        'countryOfResidence',
      });
      await row(tester, 'forget').onActivate!();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(await TravelPassengerMemory().load(), isEmpty);
    },
  );

  testWidgets(
    'uncertain passenger submission cannot be repeated after reopening',
    (tester) async {
      final service = PassengerService()..failSubmit = true;
      service.fields.removeRange(1, service.fields.length);
      final draft = TravelPassengerDraft();
      await mount(tester, service, draft);
      await row(tester, '0.email-0').onValueChanged!('sample@example.com');
      await next(tester);
      row(tester, 'submit-passengers').onActivate!();
      await tester.pumpAndSettle();
      expect(rows(tester).where((r) => r.id == 'submit-passengers'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount(tester, service, draft);
      expect(rows(tester).where((r) => r.id == 'submit-passengers'), isEmpty);
      expect(
        service.calls.where((r) => r == '/v1/booking/passengers').length,
        1,
      );
    },
  );

  testWidgets(
    'phone fields prefill Italy and normalize prefix with numeric keyboards',
    (tester) async {
      final service = PassengerService();
      service.fields
        ..clear()
        ..add({
          'name': '0.phoneNumber-0',
          'title': 'Telefono',
          'component': 'PhoneNumber',
          'validation': [
            {'type': 'required'},
          ],
        });
      final draft = TravelPassengerDraft();
      await mount(tester, service, draft);
      expect(row(tester, '0.phoneNumber-0:prefix').value, '+39');
      expect(row(tester, '0.phoneNumber-0:prefix').keyboardType, 'phone');
      expect(row(tester, '0.phoneNumber-0:number').keyboardType, 'number');
      expect(row(tester, '0.phoneNumber-0:country').value, 'IT');
      await row(tester, '0.phoneNumber-0:prefix').onValueChanged!('39');
      await row(tester, '0.phoneNumber-0:number').onValueChanged!(
        '123 456 789',
      );
      await next(tester);
      expect(draft.values['0.phoneNumber-0'], {
        'countryDiallingCode': '+39',
        'nationalNumber': '123456789',
        'countryIsoCode': 'IT',
      });
      expect(row(tester, 'submit-passengers').enabled, isTrue);
    },
  );

  testWidgets('state loading does not show a false unsupported-field warning', (
    tester,
  ) async {
    final service = PassengerService()
      ..stateResponse = Completer<Map<String, dynamic>>();
    service.fields
      ..clear()
      ..addAll([
        {
          'name': '0.addressCountry-0',
          'title': 'Paese',
          'component': 'Country',
          'validation': [
            {'type': 'required'},
          ],
        },
        {
          'name': '0.state-0',
          'title': 'Provincia',
          'component': 'CountryState',
          'validation': [
            {'type': 'required'},
          ],
        },
      ]);
    await mount(tester, service, TravelPassengerDraft(), settle: false);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Caricamento in corso…'), findsOneWidget);
    expect(find.byKey(const Key('cancel-passenger-loading')), findsOneWidget);
    expect(find.text('Paese'), findsNothing);
    expect(find.text('Provincia'), findsNothing);
    service.stateResponse!.complete({
      'states': [
        {'value': 'TO', 'label': 'Torino'},
      ],
    });
    await tester.pumpAndSettle();
    expect(row(tester, '0.state-0').kind, 'slider');
    expect(rows(tester).any((r) => r.id.startsWith('unsupported')), isFalse);
    await row(tester, '0.state-0').onValueChanged!(1.0);
    await tester.pumpAndSettle();
    await next(tester);
    expect(row(tester, 'submit-passengers').enabled, isTrue);
  });

  testWidgets(
    'address postcode country state and phone are restored for future journeys',
    (tester) async {
      PassengerService addressService() {
        final service = PassengerService();
        service.stateResponse = Completer<Map<String, dynamic>>()
          ..complete({
            'items': [
              {'value': 'TO', 'label': 'Torino'},
            ],
          });
        service.fields
          ..clear()
          ..addAll([
            for (final name in [
              'addressStreet',
              'addressHouseNumber',
              'addressPostalCode',
              'addressCity',
            ])
              {'name': '0.$name-0', 'title': name, 'component': 'Text'},
            {
              'name': '0.countryOfResidence-0',
              'title': 'Residenza',
              'component': 'CountryOfResidence',
            },
            {
              'name': '0.addressCountry-0',
              'title': 'Paese',
              'component': 'Country',
            },
            {
              'name': '0.addressState-0',
              'title': 'Provincia',
              'component': 'CountryState',
            },
            {
              'name': '0.phoneNumber-0',
              'title': 'Telefono',
              'component': 'PhoneNumber',
            },
          ]);
        return service;
      }

      final first = TravelPassengerDraft();
      await mount(tester, addressService(), first);
      expect(row(tester, '0.addressPostalCode-0').keyboardType, 'number');
      final values = {
        'addressStreet': 'Via Esempio',
        'addressHouseNumber': '12',
        'addressPostalCode': '00100',
        'addressCity': 'Torino',
      };
      for (final entry in values.entries) {
        await row(tester, '0.${entry.key}-0').onValueChanged!(entry.value);
      }
      await row(tester, '0.addressState-0').onValueChanged!(1.0);
      await tester.pumpAndSettle();
      await row(tester, '0.phoneNumber-0:number').onValueChanged!('12345678');
      await next(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final reopened = TravelPassengerDraft();
      await mount(tester, addressService(), reopened);
      for (final entry in values.entries) {
        expect(row(tester, '0.${entry.key}-0').value, entry.value);
      }
      expect(row(tester, '0.countryOfResidence-0').value, 'IT');
      expect(row(tester, '0.addressCountry-0').value, 'IT');
      expect(row(tester, '0.addressState-0').value, 'TO');
      expect(row(tester, '0.phoneNumber-0:number').value, '12345678');
      expect(await TravelPassengerMemory().load(passenger: 1), isEmpty);
    },
  );

  testWidgets('unsupported required fields do not allow submission', (
    tester,
  ) async {
    final service = PassengerService();
    service.fields
      ..clear()
      ..add({
        'name': '0.unknown-0',
        'component': 'NewWidget',
        'validation': [
          {'type': 'required'},
        ],
      });
    await mount(tester, service, TravelPassengerDraft());
    expect(row(tester, 'unsupported-0.unknown-0').title, contains('Omio'));
    expect(rows(tester).where((r) => r.id == 'next-field'), isEmpty);
    expect(service.submitted, isNull);
  });

  testWidgets(
    'residence list filters by prefix without changing saved selection',
    (tester) async {
      final service = PassengerService();
      const cities = [
        'Roma',
        'Torino',
        'Trapani',
        'Trento',
        'Bologna',
        'Milano',
        'Napoli',
        'Genova',
        'Palermo',
        'Venezia',
      ];
      service.fields
        ..clear()
        ..add({
          'name': '0.addressCity-0',
          'title': 'Città',
          'component': 'Select',
          'options': [
            for (final city in cities) {'value': city, 'label': city},
          ],
        });
      final draft = TravelPassengerDraft()..values['0.addressCity-0'] = 'Roma';
      await mount(tester, service, draft);
      expect(row(tester, '0.addressCity-0').valueLabel, 'Roma');
      await row(tester, '0.addressCity-0:filter').onValueChanged!(' t ');
      await tester.pumpAndSettle();
      expect(row(tester, '0.addressCity-0').sliderMax, 3);
      expect(
        row(tester, '0.addressCity-0:filter-count').title,
        '3 risultati disponibili',
      );
      expect(draft.values['0.addressCity-0'], 'Roma');
      expect(
        row(tester, '0.addressCity-0:retained-choice').title,
        contains('Roma'),
      );
      await row(tester, '0.addressCity-0:filter').onValueChanged!('To');
      await tester.pumpAndSettle();
      expect(row(tester, '0.addressCity-0').sliderMax, 1);
      await row(tester, '0.addressCity-0').onValueChanged!(1.0);
      await tester.pumpAndSettle();
      expect(draft.values['0.addressCity-0'], 'Torino');
      await row(tester, '0.addressCity-0:filter').onValueChanged!('xyz');
      await tester.pumpAndSettle();
      expect(
        row(tester, '0.addressCity-0:filter-count').title,
        'Nessun risultato',
      );
      expect(rows(tester).any((r) => r.id == '0.addressCity-0'), isFalse);
      expect(draft.values['0.addressCity-0'], 'Torino');
      await row(tester, '0.addressCity-0:filter').onValueChanged!('');
      await tester.pumpAndSettle();
      expect(row(tester, '0.addressCity-0').sliderMax, 10);
      expect(row(tester, '0.addressCity-0').valueLabel, 'Torino');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cancel waiting preserves submission guard and stops status polling',
    (tester) async {
      final service = PassengerService()
        ..submitResponse = Completer<Map<String, dynamic>>();
      final draft = TravelPassengerDraft()
        ..fields = [
          {'name': '0.firstName-0', 'component': 'Text', 'title': 'Nome'},
        ]
        ..values['0.firstName-0'] = 'Test'
        ..position = 1;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TravelPassengersScreen(
                      service: service,
                      query: TravelQuery(
                        departure: DateTime(2027, 10, 24),
                        ages: [40],
                      ),
                      fallbackUrl:
                          'https://www.omio.com/app/booking/test/passenger-details',
                      draft: draft,
                    ),
                  ),
                ),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      row(tester, 'submit-passengers').onActivate!();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(draft.attempted, isTrue);
      await tester.tap(find.byKey(const Key('cancel-passenger-loading')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Open form'), findsOneWidget);
      service.submitResponse!.complete({'status': 'submitted'});
      await tester.pumpAndSettle();
      expect(
        service.calls.where((s) => s == '/v1/booking/passengers').length,
        1,
      );
      expect(service.calls, isNot(contains('/v1/booking/status')));
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      expect(rows(tester).any((r) => r.id == 'submit-passengers'), isFalse);
      expect(draft.attempted, isTrue);
    },
  );
  testWidgets('pending booking recovers without resubmitting passengers', (tester) async {
    final service = PassengerService()..statusResponses.addAll([
      {'status': 'PROCESSING', 'checkout_state': 'waiting',
       'recovery': {'retry_after_seconds': 2}},
      {'status': 'RESERVED', 'checkout_state': 'ready',
       'payment_url': 'https://www.omio.com/app/booking/test/checkout'},
    ]);
    final draft = TravelPassengerDraft()..attempted = true..submitted = true;
    await mount(tester, service, draft);
    row(tester, 'status').onActivate!();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(draft.paymentUrl, contains('/checkout'));
    expect(row(tester, 'checkout').enabled, isTrue);
    expect(service.calls.where((c) => c == '/v1/booking/status').length, 2);
    expect(service.calls, isNot(contains('/v1/booking/passengers')));
  });

  testWidgets('exhausted recovery explains delay and preserves same booking fallback', (tester) async {
    final service = PassengerService()..statusResponses.add(
      {'status': 'PROCESSING', 'checkout_state': 'manual'},
    );
    final draft = TravelPassengerDraft()..attempted = true..submitted = true;
    await mount(tester, service, draft);
    row(tester, 'status').onActivate!();
    await tester.pumpAndSettle();
    expect(row(tester, 'error').title, contains('non ha ancora'));
    expect(row(tester, 'fallback').title, contains('stessa prenotazione'));
    expect(row(tester, 'status').enabled, isTrue);
    expect(draft.paymentUrl, isNull);
    expect(service.calls, isNot(contains('/v1/booking/passengers')));
  });

  testWidgets('uncertain submission can check status without sending again', (tester) async {
    final service = PassengerService();
    final draft = TravelPassengerDraft()..attempted = true;
    await mount(tester, service, draft);
    row(tester, 'status').onActivate!();
    await tester.pumpAndSettle();
    expect(draft.paymentUrl, isNotNull);
    expect(service.calls, isNot(contains('/v1/booking/passengers')));
  });

}
