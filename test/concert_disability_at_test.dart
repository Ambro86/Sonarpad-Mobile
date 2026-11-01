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

Widget austrian(Widget child) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  final data = jsonDecode(
    File('test/fixtures/concert_disability_at_catalog.json').readAsStringSync(),
  );
  final events = data['events'] as List;
  test('40 distinct Austrian events, six venues and four cities', () {
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
      4,
    );
    for (final e in events) {
      expect(Uri.parse(e['link']).host, 'www.oeticket.com');
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
      ['Wiener Stadthalle - Halle D', 'Graz'],
      ['Konzerthaus Karlsruhe', 'Karlsruhe'],
      ['Konzerthaus Klagenfurt', 'Klagenfurt'],
      ['Messe Innsbruck', 'Innsbruck'],
      ['Helmut List Halle', 'Graz'],
      ['Musikverein Wien', ''],
      ['', 'Wien'],
    ]) {
      expect(
        ConcertDisabilityContact.matchAustrianVenue(pair[0], pair[1]),
        isNull,
      );
    }
    for (final hall in ['D', 'E', 'F']) {
      expect(
        ConcertDisabilityContact.matchAustrianVenue(
          'Wiener Stadthalle - Halle $hall',
          'Vienna',
        )?.id,
        'at-stadthalle',
      );
    }
  });
  for (final e in events) {
    testWidgets('Austrian event ${e['productId']}: ${e['name']}', (
      tester,
    ) async {
      final loc = e['typeAttributes']['liveEntertainment']['location'];
      final profile = ConcertDisabilityContact.matchAustrianVenue(
        loc['name'],
        loc['city'],
      );
      expect(profile?.id, e['expectedProfile']);
      expect(profile?.instructions, e['officialInstructions']);
      final opened = <Uri>[];
      await tester.pumpWidget(
        austrian(
          ConcertDisabilityScreen(
            eventTitle: e['name'],
            country: 'AT',
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
      expect(row(tester, 'disability-conditions').title, contains('Blindheit'));
      final guidance = row(tester, 'disability-guidance').title;
      expect(guidance, isNotEmpty);
      expect(guidance, isNot(contains('disabilityAt')));
      if (profile.id == 'at-musikverein') {
        expect(guidance, contains('Gastveranstaltungen'));
        expect(guidance, contains('Sehbeeinträchtigungen'));
      }
      if (profile.id == 'at-innsbruck') {
        expect(guidance, contains('keine zentrale Konzertkasse'));
      }
      if (profile.id == 'at-graz') {
        expect(guidance, contains('Reservierungsbestätigung'));
      }
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
    });
  }
  testWidgets(
    'unknown venue keeps original event and Austrian manual choices',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        austrian(
          ConcertDisabilityScreen(
            eventTitle: 'Evento',
            country: 'AT',
            venue: 'Desconocido',
            city: 'Wien',
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
        contains('verifizierter Kontakt'),
      );
      expect(rows(tester).any((r) => r.id == 'disability-selected'), isFalse);
      row(tester, 'disability-open-event').onActivate!();
      expect(opened, isTrue);
      row(tester, 'disability-choose-organiser').onActivate!();
      await tester.pumpAndSettle();
      expect(rows(tester).where((r) => r.id.startsWith('at-')).length, 6);
      expect(
        rows(tester).any(
          (r) =>
              r.id.startsWith('de-') ||
              r.id.startsWith('fr-') ||
              r.id.startsWith('organiser-'),
        ),
        isFalse,
      );
      row(tester, 'at-graz').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'disability-selected').title, contains('Graz'));
    },
  );
  testWidgets('Austrian search opens native accessible venue information', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sonarpad_concert_welcome_accepted_v1': true,
      'concert_country': 'AT',
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
    await tester.pumpWidget(austrian(ConcertSearchScreen(service: service)));
    await tester.pumpAndSettle();
    row(tester, 'search').onActivate!();
    await tester.pumpAndSettle();
    row(tester, 'item-0').onActivate!();
    await tester.pumpAndSettle();
    row(tester, 'disability-access').onActivate!();
    await tester.pumpAndSettle();
    expect(row(tester, 'disability-selected').title, 'Wiener Stadthalle');
    expect(
      row(tester, 'disability-phone-+43198100480').title,
      startsWith('Kontaktstelle'),
    );
    await tester.pumpWidget(const SizedBox());
    service.close();
  });
}
