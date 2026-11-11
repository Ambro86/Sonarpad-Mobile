import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/italiaonline_detail_screen.dart';
import 'package:sonarpad_mobile_starter/services/italiaonline_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  const days = [
    'Oggi',
    'Domani',
    'venerdì',
    'sabato',
    'domenica',
    'lunedì',
    'martedì',
  ];

  Future<DetailResponse> fixtureDetail() async {
    final service = ItaliaOnlineService(
      clientToken: 'test-only',
      client: MockClient((request) async => http.Response(
        jsonEncode({
          'ok': true,
          'data': {
            'risultati': [
              {
                'id': '121',
                'nome': '121 Torino',
                'indirizzo': 'Torino',
                'telefoni': <String>[],
                'categorie': ['Bar'],
                'descrizione': '',
                'stelle': 4,
                'numero_recensioni': 2474,
                'stato_apertura': 'Chiuso · Apre alle ore 05',
                'orari_apertura': [
                  for (final day in days)
                    {
                      'giorno': day,
                      'data': null,
                      'fasce': ['05–00'],
                    },
                ],
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      )),
    );
    final response = await service.searchActivities(
      SearchQuery(
        kind: DirectoryKind.pagineGialle,
        what: '121',
        where: 'Torino',
        language: 'it',
      ),
      includeItalianDirectories: false,
    );
    return response.results.single.inlineDetail!;
  }

  test('la scheda 121 separa valutazione, stato e sette giorni', () async {
    final detail = await fixtureDetail();
    final paragraphs = placeDetailParagraphs(detail.description);
    expect(paragraphs, hasLength(9));
    expect(paragraphs[0], contains('Valutazione:'));
    expect(paragraphs[0], contains('2474 recensioni'));
    expect(paragraphs[1], 'Stato apertura: Chiuso · Apre alle ore 05');
    for (var i = 0; i < days.length; i++) {
      final prefix = i == 0 ? 'Orari di apertura: ${days[i]}' : days[i];
      expect(paragraphs[i + 2], '$prefix: dalle 05:00 alle 00:00');
    }
    expect(paragraphs.every((p) => !p.contains('\n')), isTrue);
    expect(placeDetailParagraphs('Uno\r\nDue\rTre\n\nQuattro'),
        ['Uno', 'Due', 'Tre', 'Quattro']);
    expect(placeDetailParagraphs(null), isEmpty);
  });

  testWidgets('i risultati di dettaglio hanno nove righe accessibili distinte',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final detail = await fixtureDetail();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ItaliaOnlineDetailScreen(detail: detail),
    ));
    final accessibleList = tester.widget<UniversalAccessibleList>(
      find.byType(UniversalAccessibleList),
    );
    final rows = accessibleList.sections.expand((s) => s.rows)
        .where((r) => r.id.startsWith('description_'))
        .toList();
    final expected = placeDetailParagraphs(detail.description);
    expect(rows, hasLength(9));
    for (var i = 0; i < expected.length; i++) {
      expect(rows[i].id, 'description_$i');
      expect(rows[i].kind, 'text');
      expect(rows[i].title, expected[i]);
    }
    expect(rows.any((r) => r.id == 'description'), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('anche la visualizzazione Flutter crea un Text per paragrafo',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final detail = await fixtureDetail();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ItaliaOnlineDetailScreen(detail: detail),
    ));
    for (final paragraph in placeDetailParagraphs(detail.description)) {
      expect(find.text(paragraph), findsOneWidget);
    }
    expect(find.text(detail.description!), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
