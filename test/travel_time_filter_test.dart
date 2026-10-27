import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/screens/travel_screen.dart';
import 'package:sonarpad_mobile_starter/services/travel_service.dart';
import 'travel_screen_test.dart' as helpers;

class TimeTravel extends helpers.FakeTravel {
  final List<String?> legs = [];
  @override
  Future<Map<String, dynamic>> results({int page = 1, String? outbound}) async {
    final data = await super.results(page: page, outbound: outbound);
    legs.add(outbound);
    data['status'] = 'complete';
    (data['items'] as List).first['departureTime'] = page == 2
        ? '2027-01-02T08:30:00+09:00'
        : '2027-01-02T20:30:00+02:00';
    return data;
  }
}

void main() {
  test('bands use local departure hour and cover boundaries', () {
    for (var hour = 0; hour < 24; hour++) {
      final date = '2027-01-02T${hour.toString().padLeft(2, '0')}:59:00+09:00';
      final matching = TravelTimeBand.values
          .where((b) => b != TravelTimeBand.all && b.matches(date))
          .toList();
      expect(matching, [
        hour < 6
            ? TravelTimeBand.night
            : hour < 12
            ? TravelTimeBand.morning
            : hour < 18
            ? TravelTimeBand.afternoon
            : TravelTimeBand.evening,
      ]);
    }
    expect(TravelTimeBand.morning.matches(null), isFalse);
    expect(TravelTimeBand.morning.matches('2027-01-02T08:99'), isFalse);
    expect(TravelTimeBand.all.matches(null), isTrue);
  });
  test('saved searches retain independent filters and support old data', () {
    final q = TravelQuery(
      outboundTime: TravelTimeBand.morning,
      inboundTime: TravelTimeBand.evening,
    );
    expect(q.copy().outboundTime, TravelTimeBand.morning);
    expect(q.copy().inboundTime, TravelTimeBand.evening);
    final old = q.toJson()
      ..remove('outboundTime')
      ..remove('inboundTime');
    expect(TravelQuery.fromJson(old).outboundTime, TravelTimeBand.all);
  });
  testWidgets('search has accessible separate time sliders', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      helpers.app(
        TravelSearchScreen(initial: TravelQuery(returnDate: DateTime(2027))),
      ),
    );
    await tester.pumpAndSettle();
    expect(helpers.row(tester, 'outbound-time').kind, 'slider');
    expect(helpers.row(tester, 'outbound-time').valueLabel, 'Tutto il giorno');
    helpers.row(tester, 'outbound-time').onValueChanged!(1.0);
    await tester.pump();
    expect(helpers.row(tester, 'outbound-time').value, 'morning');
    expect(helpers.row(tester, 'inbound-time').value, 'all');
  });
  testWidgets('filter includes later pages and switching uses cached results', (
    tester,
  ) async {
    final service = TimeTravel();
    await tester.pumpWidget(
      helpers.app(
        TravelResultsScreen(
          service: service,
          query: TravelQuery(outboundTime: TravelTimeBand.morning),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.reads, 3);
    expect(
      helpers
          .rows(tester)
          .where((r) => r.id.startsWith('journey-'))
          .map((r) => r.id),
      ['journey-choice-2'],
    );
    helpers.row(tester, 'departure-time').onValueChanged!(4.0);
    await tester.pumpAndSettle();
    expect(
      helpers.row(tester, 'empty').title,
      'Nessun viaggio in questa fascia oraria.',
    );
    await helpers.row(tester, 'show-all-day').onActivate!();
    await tester.pumpAndSettle();
    expect(service.reads, 3);
    expect(service.searches, 0);
    expect(
      helpers.rows(tester).where((r) => r.id.startsWith('journey-')).length,
      3,
    );
  });
  testWidgets('return applies its own time filter and outbound identifier', (
    tester,
  ) async {
    final service = TimeTravel();
    final q = TravelQuery(
      outboundTime: TravelTimeBand.evening,
      inboundTime: TravelTimeBand.morning,
    );
    await tester.pumpWidget(
      helpers.app(
        TravelResultsScreen(
          service: service,
          query: q,
          outbound: {'choice_id': 'outbound-selected'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.legs, everyElement('outbound-selected'));
    expect(helpers.row(tester, 'departure-time').value, 'morning');
    expect(
      helpers
          .rows(tester)
          .where((r) => r.id.startsWith('journey-'))
          .map((r) => r.id),
      ['journey-choice-2'],
    );
    expect(q.outboundTime, TravelTimeBand.evening);
  });
}
