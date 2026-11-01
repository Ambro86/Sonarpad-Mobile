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

Widget german(Widget child) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  final data = jsonDecode(
    File('test/fixtures/concert_disability_de_catalog.json').readAsStringSync(),
  );
  final events = data['events'] as List;

  test(
    'audit contains 40 distinct events across eight German cities, no add-ons',
    () {
      expect(events.length, 40);
      expect(events.map((e) => e['productId']).toSet().length, 40);
      expect(
        events
            .map(
              (e) =>
                  e['typeAttributes']['liveEntertainment']['location']['city'],
            )
            .toSet()
            .length,
        8,
      );
      for (final event in events) {
        expect(
          RegExp(
            r'premium|VIP|Parkticket|Parkplatz|Loge|Voucher|Lucky Dip|Gallery|Upgrade',
            caseSensitive: false,
          ).hasMatch(event['name']),
          isFalse,
        );
        expect(Uri.parse(event['link']).host, 'www.eventim.de');
      }
    },
  );

  test('German venue matching is conservative and handles umlauts', () {
    expect(
      ConcertDisabilityContact.matchGermanVenue('LANXESS ARENA', 'Koeln')?.id,
      'de-lanxess',
    );
    expect(
      ConcertDisabilityContact.matchGermanVenue(
        'Olympiahalle Muenchen',
        'Muenchen',
      )?.id,
      'de-olympia',
    );
    for (final pair in [
      ['Olympiahalle', 'Innsbruck'],
      ['Uber Eats Music Hall', 'Berlin'],
      ['Parkscheine Barclays Arena', 'Hamburg'],
      ['Kleine Olympiahalle', 'München'],
      ['SAP Arena', 'Berlin'],
      ['SAP Arena', ''],
      ['', 'Mannheim'],
      ['Festhalle', 'Hamburg'],
      ['Westfalenhalle Fake', 'Dortmund'],
    ]) {
      expect(
        ConcertDisabilityContact.matchGermanVenue(pair[0], pair[1]),
        isNull,
        reason: '$pair',
      );
    }
    for (final profile in ConcertDisabilityContact.germany) {
      expect(profile.guidanceKey, isNotNull);
      expect(Uri.parse(profile.source).scheme, 'https');
      expect(Uri.parse(profile.instructions).scheme, 'https');
    }
  });

  for (final event in events) {
    testWidgets('real event ${event['productId']}: ${event['name']}', (
      tester,
    ) async {
      final loc = event['typeAttributes']['liveEntertainment']['location'];
      final profile = ConcertDisabilityContact.matchGermanVenue(
        loc['name'],
        loc['city'],
      );
      expect(profile?.id, event['expectedProfile']);
      expect(profile?.instructions, event['officialInstructions']);
      final opened = <Uri>[];
      await tester.pumpWidget(
        german(
          ConcertDisabilityScreen(
            eventTitle: event['name'],
            country: 'DE',
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
      expect(row(tester, 'disability-guidance').title, isNotEmpty);
      expect(
        row(tester, 'disability-conditions').title,
        contains('Sehbehinderung'),
      );
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
      if (profile.id == 'de-uber' || profile.id == 'de-barclays') {
        expect(
          rows(tester).any(
            (r) =>
                r.id.startsWith('disability-phone-') ||
                r.id.startsWith('disability-mail-'),
          ),
          isFalse,
        );
      }
      if (profile.id == 'de-festhalle') {
        expect(
          row(tester, 'disability-guidance').title,
          contains('Info-Hotline'),
        );
      }
      if (profile.id == 'de-olympia') {
        expect(
          row(tester, 'disability-guidance').title,
          contains('Nicht jedes Event'),
        );
      }
    });
  }

  testWidgets('unrecognised German venue does not borrow foreign contacts', (
    tester,
  ) async {
    var eventOpened = false;
    await tester.pumpWidget(
      german(
        ConcertDisabilityScreen(
          eventTitle: 'Event',
          country: 'DE',
          organiser: 'Vivo Concerti Srl',
          venue: 'Olympiahalle',
          city: 'Innsbruck',
          contact: ConcertDisabilityContact.france.first,
          openEvent: () async {
            eventOpened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      row(tester, 'disability-unmatched').title,
      contains('keine verifizierte Kontaktstelle'),
    );
    expect(rows(tester).any((r) => r.id == 'disability-selected'), isFalse);
    row(tester, 'disability-open-event').onActivate!();
    expect(eventOpened, isTrue);
    row(tester, 'disability-choose-organiser').onActivate!();
    await tester.pumpAndSettle();
    expect(rows(tester).where((r) => r.id.startsWith('de-')).length, 8);
    expect(
      rows(
        tester,
      ).any((r) => r.id.startsWith('fr-') || r.id.startsWith('organiser-')),
      isFalse,
    );
    row(tester, 'de-quarterback').onActivate!();
    await tester.pumpAndSettle();
    expect(row(tester, 'disability-selected').title, contains('Leipzig'));
    expect(rows(tester).any((r) => r.id == 'disability-directory'), isFalse);
  });

  testWidgets('German event search opens native accessible contact screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sonarpad_concert_welcome_accepted_v1': true,
      'concert_country': 'DE',
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
    await tester.pumpWidget(german(ConcertSearchScreen(service: service)));
    await tester.pumpAndSettle();
    row(tester, 'search').onActivate!();
    await tester.pumpAndSettle();
    row(tester, 'item-0').onActivate!();
    await tester.pumpAndSettle();
    expect(rows(tester).any((r) => r.id == 'ticketone-login'), isFalse);
    row(tester, 'disability-access').onActivate!();
    await tester.pumpAndSettle();
    expect(row(tester, 'disability-selected').title, 'Uber Arena — Berlin');
    expect(
      row(tester, 'disability-guidance').title,
      contains('je nach Veranstaltung'),
    );
    await tester.pumpWidget(const SizedBox());
    service.close();
  });
}
