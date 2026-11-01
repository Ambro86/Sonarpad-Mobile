import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/concert_disability_screen.dart';
import 'package:sonarpad_mobile_starter/screens/concert_search_screen.dart';
import 'package:sonarpad_mobile_starter/services/concert_disability_contacts.dart';
import 'package:sonarpad_mobile_starter/services/concert_search_service.dart';
import 'travel_screen_test.dart' show row, rows;

Widget spanish(Widget child) => MaterialApp(
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  final data = jsonDecode(
    File('test/fixtures/concert_disability_es_catalog.json').readAsStringSync(),
  );
  final events = data['events'] as List;
  test('40 distinct Spanish events, six venues, five catalogue cities', () {
    expect(events.length, 40);
    expect(events.map((e) => e['productId']).toSet().length, 40);
    expect(
      events.map((e) => '${e['expectedProfile']}:${e['name']}').toSet().length,
      40,
    );
    expect(events.map((e) => e['expectedProfile']).toSet().length, 6);
    expect(
      events
          .map(
            (e) => e['typeAttributes']['liveEntertainment']['location']['city'],
          )
          .toSet()
          .length,
      5,
    );
    for (final e in events) {
      expect(Uri.parse(e['link']).host, 'www.entradas.com');
      expect(
        RegExp(
          r'Top Seat|VIP|Nacidos después|parking',
          caseSensitive: false,
        ).hasMatch(e['name']),
        isFalse,
      );
    }
  });
  test('namesakes, different halls and other countries are not confused', () {
    for (final pair in [
      ['Movistar Arena', 'Buenos Aires'],
      ['Movistar Arena', 'Bogotá'],
      ['La Sala del Movistar Arena', 'Madrid'],
      ['Sant Jordi Club', 'Barcelona'],
      ['Conservatori del Liceu', 'Barcelona'],
      ['Roig Arena', 'Madrid'],
      ['Cartuja Center', ''],
      ['', 'Sevilla'],
    ]) {
      expect(
        ConcertDisabilityContact.matchSpanishVenue(pair[0], pair[1]),
        isNull,
        reason: '$pair',
      );
    }
    expect(
      ConcertDisabilityContact.matchSpanishVenue(
        'Bizkaia Arena BEC!',
        'Bilbao',
      )?.id,
      'es-bec',
    );
    expect(
      ConcertDisabilityContact.matchSpanishVenue(
        'Bilbao Arena Miribilla',
        'Bilbao',
      )?.id,
      'es-bilbao',
    );
  });
  for (final e in events) {
    testWidgets('Spanish event ${e['productId']}: ${e['name']}', (
      tester,
    ) async {
      final loc = e['typeAttributes']['liveEntertainment']['location'];
      final profile = ConcertDisabilityContact.matchSpanishVenue(
        loc['name'],
        loc['city'],
      );
      expect(profile?.id, e['expectedProfile']);
      expect(profile?.instructions, e['officialInstructions']);
      final opened = <Uri>[];
      await tester.pumpWidget(
        spanish(
          ConcertDisabilityScreen(
            eventTitle: e['name'],
            country: 'ES',
            venue: loc['name'],
            city: loc['city'],
            opener: (uri, _) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(row(tester, 'disability-selected').title, profile!.name);
      expect(
        row(tester, 'disability-conditions').title,
        contains('baja visión'),
      );
      expect(row(tester, 'disability-guidance').title, isNotEmpty);
      expect(
        rows(tester).any(
          (r) =>
              r.id == 'disability-directory' || r.id == 'disability-calendar',
        ),
        isFalse,
      );
      row(tester, 'disability-contact-info').onActivate!();
      await tester.pumpAndSettle();
      expect(opened.single.toString(), profile.instructions);
      for (final email in profile.emails) {
        row(tester, 'disability-mail-$email').onActivate!();
        await tester.pumpAndSettle();
        expect(opened.last, Uri(scheme: 'mailto', path: email));
      }
      for (final phone in profile.phones) {
        row(tester, 'disability-phone-$phone').onActivate!();
        await tester.pumpAndSettle();
        expect(opened.last, Uri(scheme: 'tel', path: phone));
      }
      if (profile.id == 'es-movistar') {
        expect(
          row(tester, 'disability-guidance').title,
          contains('No selecciones PMR'),
        );
      }
      if (profile.id == 'es-bilbao') {
        expect(
          row(tester, 'disability-guidance').title,
          contains('no se aplica automáticamente'),
        );
      }
    });
  }
  testWidgets('unknown venue keeps original event and Spanish manual choices', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      spanish(
        ConcertDisabilityScreen(
          eventTitle: 'Evento',
          country: 'ES',
          venue: 'Desconocido',
          city: 'Madrid',
          organiser: 'Vivo Concerti Srl',
          contact: ConcertDisabilityContact.germany.first,
          openEvent: () async {
            opened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      row(tester, 'disability-unmatched').title,
      contains('contacto verificado'),
    );
    expect(rows(tester).any((r) => r.id == 'disability-selected'), isFalse);
    row(tester, 'disability-open-event').onActivate!();
    expect(opened, isTrue);
    row(tester, 'disability-choose-organiser').onActivate!();
    await tester.pumpAndSettle();
    expect(rows(tester).where((r) => r.id.startsWith('es-')).length, 6);
    expect(
      rows(tester).any(
        (r) =>
            r.id.startsWith('de-') ||
            r.id.startsWith('fr-') ||
            r.id.startsWith('organiser-'),
      ),
      isFalse,
    );
    row(tester, 'es-cartuja').onActivate!();
    await tester.pumpAndSettle();
    expect(row(tester, 'disability-selected').title, contains('Sevilla'));
  });
  testWidgets('Spanish search opens native accessible venue information', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sonarpad_concert_welcome_accepted_v1': true,
      'concert_country': 'ES',
    });
    final service = ConcertSearchService(
      logger: (_) async {},
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'products': [events.first],
              'page': 1,
              'totalPages': 1,
              'totalResults': 1,
            }),
          ),
          200,
        ),
      ),
    );
    await tester.pumpWidget(spanish(ConcertSearchScreen(service: service)));
    await tester.pumpAndSettle();
    row(tester, 'search').onActivate!();
    await tester.pumpAndSettle();
    row(tester, 'item-0').onActivate!();
    await tester.pumpAndSettle();
    row(tester, 'disability-access').onActivate!();
    await tester.pumpAndSettle();
    expect(row(tester, 'disability-selected').title, 'Movistar Arena — Madrid');
    expect(
      row(tester, 'disability-phone-+34914449949').title,
      startsWith('Llamar'),
    );
    await tester.pumpWidget(const SizedBox());
    service.close();
  });
}
