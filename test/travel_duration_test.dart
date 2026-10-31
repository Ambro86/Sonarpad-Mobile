import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/screens/travel_screen.dart';
import 'package:sonarpad_mobile_starter/l10n/travel_strings.dart';

void main() {
  String? duration(String? from, String? to, [String locale = 'it']) =>
      travelJourneyDuration({
        'departureTime': from,
        'arrivalTime': to,
      }, TravelStrings(locale));
  test('journey duration uses complete dates and offsets', () {
    expect(
      duration('2026-11-01T08:00:00+01:00', '2026-11-01T14:00:00+01:00'),
      'Durata del viaggio: 6 ore',
    );
    expect(
      duration('2026-11-01T23:30:00+01:00', '2026-11-02T06:45:00+01:00'),
      'Durata del viaggio: 7 ore 15 minuti',
    );
    expect(
      duration('2026-11-01T08:00:00+01:00', '2026-11-03T10:01:00+01:00'),
      'Durata del viaggio: 50 ore 1 minuto',
    );
    expect(
      duration('2026-11-01T08:00:00+01:00', '2026-11-01T08:30:00Z'),
      'Durata del viaggio: 1 ora 30 minuti',
    );
    expect(
      duration('2026-10-25T01:30:00+02:00', '2026-10-25T03:30:00+01:00'),
      'Durata del viaggio: 3 ore',
    );
    expect(
      duration('2026-11-01T08:00:00Z', '2026-11-01T08:01:00Z'),
      'Durata del viaggio: 1 minuto',
    );
    expect(
      duration('2026-11-01T08:00:00Z', '2026-11-01T09:05:00Z', 'en'),
      'Journey duration: 1 hour 5 minutes',
    );
  });
  test('missing or invalid timestamps do not invent a duration', () {
    expect(duration(null, '2026-11-01T09:00:00Z'), isNull);
    expect(duration('invalid', '2026-11-01T09:00:00Z'), isNull);
    expect(duration('2026-11-01T08:00:00', '2026-11-01T09:00:00'), isNull);
    expect(duration('2026-11-01T09:00:00Z', '2026-11-01T08:00:00Z'), isNull);
    expect(duration('2026-11-01T09:00:00Z', '2026-11-01T09:00:00Z'), isNull);
  });
}
