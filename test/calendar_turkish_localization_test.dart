import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/calendar/calendar_localization_data.g.dart';
import 'package:sonarpad_mobile_starter/services/calendar/calendar_service.dart';

Map<String, dynamic> _calendarJson(String locale) =>
    jsonDecode(File('assets/calendar/$locale.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('Turkish calendar contains every date and fully translated quote', () {
    final source = _calendarJson('en');
    final turkish = _calendarJson('tr');
    final sourceSaints = source['saints'] as Map<String, dynamic>;
    final saints = turkish['saints'] as Map<String, dynamic>;
    final sourceQuotes = (source['quotes'] as List<dynamic>).cast<String>();
    final quotes = (turkish['quotes'] as List<dynamic>).cast<String>();

    expect(turkish['locale'], 'tr');
    expect(saints.length, 365);
    expect(saints.keys.toList(), sourceSaints.keys.toList());
    expect(saints.values.every((value) => (value as String).trim().isNotEmpty),
        isTrue);
    expect(quotes.length, 128);
    expect(quotes.length, sourceQuotes.length);
    for (var i = 0; i < quotes.length; i++) {
      final quote = quotes[i];
      final original = sourceQuotes[i];
      final attributionStart = quote.lastIndexOf(' - ');
      final originalAttributionStart = original.lastIndexOf(' - ');
      expect(attributionStart, greaterThan(0), reason: 'quote $i');
      expect(quote.substring(attributionStart),
          original.substring(originalAttributionStart),
          reason: 'Author and order must be preserved for quote $i');
      expect(quote.substring(0, attributionStart),
          isNot(original.substring(0, originalAttributionStart)),
          reason: 'Quote $i must have a translated body');
    }

    expect(saints['17-6'], 'Pisalı Aziz Ranieri');
    expect(saints['18-6'], 'Azize Marina');
    expect(saints['26-3'], 'Aziz Emmanuel');
    expect(turkish['holidays'], isEmpty);
  });

  test('Turkish runtime data exactly matches the calendar JSON source', () {
    final turkish = _calendarJson('tr');
    expect(kCalendarSaintsByLocale['tr'], turkish['saints']);
    expect(kCalendarQuotesByLocale['tr'], turkish['quotes']);
    expect(kCalendarHolidaysByLocale['tr'], turkish['holidays']);
  });

  test('Turkish and regional variants resolve every quote without fallback', () {
    final service = CalendarService();
    final quotes = (_calendarJson('tr')['quotes'] as List<dynamic>).cast<String>();
    final start = DateTime.utc(1970, 1, 1);

    for (final locale in ['tr', 'tr_TR', 'tr-TR', 'TR']) {
      for (var index = 0; index < quotes.length; index++) {
        expect(service.getQuote(start.add(Duration(days: index)), locale),
            quotes[index],
            reason: '$locale quote $index');
      }
    }
  });

  test('Turkish calendar resolves all bundled saint days', () {
    final service = CalendarService();
    final saints = _calendarJson('tr')['saints'] as Map<String, dynamic>;

    for (final entry in saints.entries) {
      final dateParts = entry.key.split('-').map(int.parse).toList();
      final date = DateTime(2026, dateParts[1], dateParts[0]);
      expect(service.getSaint(date, 'tr_TR'), entry.value,
          reason: 'Turkish saint for ${entry.key}');
      expect(service.getHoliday(date, 'tr'), isNull,
          reason: 'No unverified Turkish public holidays are added');
    }
  });
}
