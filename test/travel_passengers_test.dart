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
    if (route == '/v1/booking/form') {
      return {
        'components': [
          {'components': fields},
        ],
      };
    }
    if (route == '/v1/booking/passengers') {
      submitted = body;
      if (failSubmit) throw const TravelException('timeout');
      return {'status': 'submitted'};
    }
    if (route == '/v1/booking/status') {
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
    await tester.pumpAndSettle();
  }

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
        await next(tester);
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
      await row(tester, '0.email-0').onValueChanged!('invalid');
      await next(tester);
      expect(row(tester, 'error').title, contains('Controlla'));
      await row(tester, '0.email-0').onValueChanged!('sample@example.com');
      await next(tester);
      await row(tester, '0.firstName-0').onValueChanged!('Example');
      await next(tester);
      await row(tester, '0.lastName-0').onValueChanged!('Traveller');
      await next(tester);
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
      await next(tester);
      expect(draft.values['0.dateOfBirth-0'], '1986-06-07');
      expect(row(tester, '0.countryOfResidence-0').kind, 'slider');
      draft.values['0.countryOfResidence-0'] = 'IT';
      await next(tester);
      await row(tester, 'skip-field').onActivate!();
      await tester.pumpAndSettle();
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
    expect(row(tester, 'unsupported').title, contains('Omio'));
    expect(rows(tester).where((r) => r.id == 'next-field'), isEmpty);
    expect(service.submitted, isNull);
  });
}
