import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/screens/travel_screen.dart';
import 'package:sonarpad_mobile_starter/services/travel_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'travel_screen_test.dart' show app, row, rows, FakeTravel;
import 'travel_passengers_test.dart' show PassengerService;

class FerryService extends FakeTravel {
  final quotes = <Map<String, dynamic>>[];
  bool carAvailable = true, single = false, categoryNeeded = false;
  Completer<Map<String, dynamic>>? configPending;
  final requested = <String>[];
  @override
  Future<Map<String, dynamic>> request(
    String route, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    String? method,
    String? idempotencyKey,
  }) async {
    requested.add(route);
    if (route == '/v1/ferry/accommodations') {
      if (configPending != null) return configPending!.future;
      return {
        'seatingOption': {
          'required': true,
          'singleOptionSelection': single,
          'seatingCategories': [
            {
              'name': 'Cabine',
              'options': [
                for (final id in ['PP', 'CABIN', 'any', 'SOLD'])
                  {
                    'key': id,
                    'name': id,
                    'maxQuantity': 4,
                    'isSoldOut': id == 'SOLD',
                    'price': {'valueInCents': 2500, 'currency': 'EUR'},
                  },
              ],
            },
          ],
        },
      };
    }
    if (route == '/v1/ferry/vehicles') {
      return {
        'vehicles': {
          'vehicleClasses': [
            if (carAvailable) {'type': 'CAR'},
            {'type': 'MOTORCYCLE'},
          ],
        },
      };
    }
    if (route == '/v1/ferry/vehicle-models') {
      return {
        'items': [
          {
            'id': 'test-model',
            'brand': 'Hyundai',
            'model': 'i10',
            'year': 2023,
            'dimensions': {'length': 381, 'height': 152},
          },
        ],
        'pagination': {
          'currentPage': int.parse(query['page']!),
          'totalPages': 2,
        },
      };
    }
    if (route == '/v1/ferry/accommodations/preview') {
      quotes.add(body!);
      if (categoryNeeded && body['vehicle']?['category'] == null) {
        return {
          'needs_vehicle_category': true,
          'vehicle_options': [
            {
              'externalCode': 'A0',
              'classLabel': 'Auto',
              'dimensionsLabel': '381 cm',
              'price': {'valueInCents': 2970, 'currency': 'EUR'},
            },
          ],
        };
      }
      return {
        'selection_token': 'token-${body['offer_choice']}',
        'quote': {
          'selected_items': [
            for (final item in body['items'])
              {
                ...item,
                'price': {'valueInCents': 4127, 'currency': 'EUR'},
              },
          ],
          'seating_price': {'valueInCents': 0, 'currency': 'EUR'},
          if (body['vehicle'] != null)
            'vehicle_price': {'valueInCents': 2970, 'currency': 'EUR'},
        },
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

class PriceService extends PassengerService {
  Map<String, dynamic>? confirmation;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> request(
    String route, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    String? method,
    String? idempotencyKey,
  }) async {
    if (route == '/v1/booking/confirm-price') {
      confirmation = body;
      expect(idempotencyKey, isNotEmpty);
      if (fail) throw const TravelException('timeout');
      return {'status': 'price_confirmed'};
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

class CapturedFerryForm extends PassengerService {
  @override
  Future<Map<String, dynamic>> request(
    String route, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    String? method,
    String? idempotencyKey,
  }) async {
    if (route == '/v1/booking/form') {
      return jsonDecode(
            File('test/fixtures/travel_ferry_form.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
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
  testWidgets(
    'captured GNV form is native, including document number and expiry sliders',
    (tester) async {
      final service = CapturedFerryForm();
      final draft = TravelPassengerDraft();
      await tester.pumpWidget(
        app(
          TravelPassengersScreen(
            service: service,
            query: TravelQuery(
              mode: 'ferry',
              departure: DateTime(2030, 11, 13),
              returnDate: DateTime(2030, 11, 20),
            ),
            fallbackUrl:
                'https://www.omio.com/app/booking/test/passenger-details',
            draft: draft,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        rows(tester).where((r) => r.id.startsWith('unsupported-')),
        isEmpty,
      );
      expect(row(tester, '0.travelDocumentNumber-0').kind, 'textField');
      expect(
        row(tester, '0.travelDocumentExpirationDate-0:year').kind,
        'slider',
      );
      expect(row(tester, '0.title-0').title, contains('Sig.'));
      for (final field in draft.fields!) {
        final name = field['name'] as String;
        if (name.contains('email')) {
          draft.values[name] = 'test@example.org';
        } else if (name.contains('title')) {
          draft.values[name] = 'Mr';
        } else if (name.contains('travelDocumentType')) {
          draft.values[name] = 'NATIONAL_ID';
        } else if (name.contains('dateOfBirth')) {
          draft.values[name] = '1990-01-01';
        } else if (name.contains('ExpirationDate')) {
          draft.values[name] = '2030-11-14';
        } else if (field['component'] == 'PhoneNumber') {
          draft.values[name] = {
            'countryDiallingCode': '+39',
            'nationalNumber': '123456789',
            'countryIsoCode': 'IT',
          };
        } else if ([
          'Country',
          'CountryOfResidence',
        ].contains(field['component'])) {
          draft.values[name] = 'IT';
        } else {
          draft.values[name] = 'TEST123';
        }
      }
      row(tester, 'next-field').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'error').title, contains('scadenza'));
      expect(service.submitted, isNull);
      draft.values['0.travelDocumentExpirationDate-0'] = '2031-01-01';
      row(tester, 'next-field').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'submit-passengers').enabled, isTrue);
    },
  );
  Future<void> mount(
    WidgetTester tester,
    FerryService service, {
    int count = 1,
  }) async {
    await tester.pumpWidget(
      app(
        TravelFerryScreen(
          service: service,
          query: TravelQuery(mode: 'ferry', ages: List.filled(count, 40)),
          offerChoice: 'out',
          group: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> change(WidgetTester tester, String id, dynamic value) async {
    row(tester, id).onValueChanged!(value);
    await tester.pumpAndSettle();
  }

  Future<void> activate(WidgetTester tester, String id) async {
    row(tester, id).onActivate!();
    await tester.pumpAndSettle();
  }

  testWidgets('ferry uses the existing accessible mode slider', (tester) async {
    await tester.pumpWidget(app(const TravelSearchScreen()));
    await tester.pumpAndSettle();
    await change(tester, 'mode', 3.0);
    expect(row(tester, 'mode').value, 'ferry');
    expect(row(tester, 'mode').valueLabel, 'Navi e traghetti');
    expect(rows(tester).where((r) => r.id == 'discount-cards'), isEmpty);
  });
  testWidgets(
    'allocations count passengers, exclude sold-out options and require complete allocation',
    (tester) async {
      final s = FerryService();
      await mount(tester, s, count: 2);
      expect(row(tester, 'quantity-PP').kind, 'slider');
      expect(
        rows(
          tester,
        ).where((r) => r.id == 'quantity-any' || r.id == 'quantity-SOLD'),
        isEmpty,
      );
      expect(row(tester, 'preview').enabled, isFalse);
      await change(tester, 'quantity-PP', 1.0);
      expect(row(tester, 'preview').enabled, isFalse);
      await change(tester, 'quantity-CABIN', 1.0);
      expect(row(tester, 'preview').enabled, isTrue);
      await activate(tester, 'preview');
      expect(s.quotes.single['items'], [
        {'id': 'PP', 'quantity': 1},
        {'id': 'CABIN', 'quantity': 1},
      ]);
      expect(s.quotes.single.containsKey('vehicle'), isFalse);
      expect(row(tester, 'quote-PP').title, contains('41,27'));
      expect(row(tester, 'aggregate').title, contains('0,00'));
      expect(
        tester
            .widget<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList).last,
            )
            .initialFocusId,
        'ferry-review-heading',
      );
      expect(s.bookings, 0);
    },
  );
  testWidgets('single option and per-leg car availability are respected', (
    tester,
  ) async {
    final s = FerryService()
      ..single = true
      ..carAvailable = false;
    await mount(tester, s);
    expect(rows(tester).where((r) => r.id == 'car-toggle'), isEmpty);
    await change(tester, 'quantity-PP', 1.0);
    await change(tester, 'quantity-CABIN', 1.0);
    expect(row(tester, 'quantity-PP').value, '0');
    await activate(tester, 'preview');
    expect(s.quotes.single['items'], [
      {'id': 'CABIN', 'quantity': 1},
    ]);
  });
  testWidgets(
    'car requires explicit model, plate, dimensions; category and quotes never book',
    (tester) async {
      final s = FerryService()..categoryNeeded = true;
      await mount(tester, s);
      expect(row(tester, 'car-toggle').toggleValue, isFalse);
      await change(tester, 'quantity-PP', 1.0);
      await change(tester, 'car-toggle', true);
      expect(row(tester, 'preview').enabled, isFalse);
      await activate(tester, 'model-search');
      await change(tester, 'model-query', 'Hyundai i10');
      await activate(tester, 'search');
      expect(rows(tester).where((r) => r.id == 'model-query'), isEmpty);
      expect(row(tester, 'model-test-model').title, contains('381 × 152'));
      await activate(tester, 'next');
      expect(rows(tester).where((r) => r.id == 'previous'), isNotEmpty);
      await activate(tester, 'model-test-model');
      await change(tester, 'plate', 'TEST123');
      expect(row(tester, 'preview').enabled, isFalse);
      await change(tester, 'dimensions', true);
      await activate(tester, 'preview');
      expect(rows(tester).where((r) => r.id == 'ferry-confirm'), isEmpty);
      await activate(tester, 'category-A0');
      expect(s.quotes.last['vehicle'], {
        'model_id': 'test-model',
        'registration_plate': 'TEST123',
        'confirm_dimensions': true,
        'category': 'A0',
      });
      expect(row(tester, 'vehicle-price').title, contains('29,70'));
      expect(s.bookings, 0);
      await activate(tester, 'ferry-edit');
      await change(tester, 'car-toggle', false);
      await activate(tester, 'preview');
      expect(s.quotes.last.containsKey('vehicle'), isFalse);
    },
  );
  testWidgets('leaving while loading does not issue more requests', (
    tester,
  ) async {
    final s = FerryService()..configPending = Completer();
    await tester.pumpWidget(
      app(
        TravelFerryScreen(
          service: s,
          query: TravelQuery(mode: 'ferry'),
          offerChoice: 'out',
          group: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    s.configPending!.complete({});
    await tester.pump();
    expect(s.requested, ['/v1/ferry/accommodations']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('fare flow sends only confirmed ferry tokens to booking', (
    tester,
  ) async {
    final s = FerryService()..bookingSucceeds = true;
    await tester.pumpWidget(
      app(
        TravelResultsScreen(
          service: s,
          query: TravelQuery(mode: 'ferry', from: 'Genova', to: 'Palermo'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await activate(tester, 'journey-choice-1');
    await activate(tester, 'offer-fare-1');
    await activate(tester, 'continue');
    expect(s.bookings, 0);
    await change(tester, 'quantity-PP', 1.0);
    await activate(tester, 'preview');
    expect(s.bookings, 0);
    await activate(tester, 'ferry-confirm');
    expect(s.bookingBody?['accommodations'], {'fare-1': 'token-fare-1'});
    expect(s.bookings, 1);
  });
  for (final fail in [false, true]) {
    testWidgets(
      'price change needs explicit consent; uncertain confirmation is not repeated ($fail)',
      (tester) async {
        final s = PriceService()..fail = fail;
        s.statusResponses.add({
          'status': 'PRICE_CHANGE',
          'price_change_confirmation_required': true,
          'total': {'lowestUnitValue': 12345, 'currency': 'EUR'},
        });
        final draft = TravelPassengerDraft()
          ..submitted = true
          ..attempted = true;
        await tester.pumpWidget(
          app(
            TravelPassengersScreen(
              service: s,
              query: TravelQuery(mode: 'ferry'),
              fallbackUrl:
                  'https://www.omio.com/app/booking/test/passenger-details',
              draft: draft,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await activate(tester, 'status');
        expect(s.confirmation, isNull);
        expect(row(tester, 'new-price').title, contains('123,45'));
        await activate(tester, 'confirm-price');
        expect(s.confirmation, {
          'confirm': true,
          'expected_total': {'lowestUnitValue': 12345, 'currency': 'EUR'},
        });
        if (fail) {
          expect(row(tester, 'confirm-price').enabled, isFalse);
        } else {
          expect(draft.paymentUrl, isNotNull);
          expect(draft.priceChange, isNull);
        }
        expect(s.calls.where((r) => r == '/v1/bookings'), isEmpty);
      },
    );
  }
}
