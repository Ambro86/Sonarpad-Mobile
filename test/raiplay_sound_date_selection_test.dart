import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/raiplaysound_screen.dart';
import 'package:sonarpad_mobile_starter/services/raiplay_sound_service.dart';

Map<String, dynamic> _pagePayload(int itemCount) => {
  'title': 'Programma RaiPlay Sound',
  'block': {
    'cards': List.generate(itemCount, (index) {
      final day = index + 1;
      return {
        'title': 'Episodio $day',
        'path_id': '/episodi/$day.json',
        'create_date': '${day.toString().padLeft(2, '0')}-07-2026',
        'downloadable_audio': {'url': '/audio/$day.mp3'},
      };
    }),
  },
};

void main() {
  test('parses RaiPlay Sound day-month-year episode dates', () async {
    final service = RaiPlaySoundService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(_pagePayload(2)), 200),
      ),
    );

    final page = await service.loadPage('https://example.test/page.json');

    expect(page.items, hasLength(2));
    expect(page.items.first.publishedAt, DateTime(2026, 7, 1));
    expect(page.items.last.publishedAt, DateTime(2026, 7, 2));
  });

  testWidgets('selecting a date jumps to the matching RaiPlay Sound item', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = RaiPlaySoundService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(_pagePayload(30)), 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RaiPlaySoundScreen(
          url: 'https://example.test/page.json',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seleziona data'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('30 luglio 2026'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('30 luglio 2026'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pumpAndSettle();

    expect(find.textContaining('Episodio 30'), findsOneWidget);
  });
}
