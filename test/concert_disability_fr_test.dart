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

Widget french(Widget child) => MaterialApp(
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  test('40 real French catalogue results reject unrelated venues', () {
    final data = jsonDecode(
      File(
        'test/fixtures/concert_disability_fr_catalog.json',
      ).readAsStringSync(),
    );
    final events = data['events'] as List;
    expect(events.length, 40);
    final counts = <String, int>{};
    for (final event in events) {
      final loc = event['typeAttributes']['liveEntertainment']['location'];
      final profile = ConcertDisabilityContact.matchFrenchVenue(
        loc['name'],
        loc['city'],
      );
      if (profile != null) {
        counts.update(profile.id, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    expect(counts, {
      'fr-accor': 8,
      'fr-olympia': 4,
      'fr-palais-paris': 1,
      'fr-stade-france': 1,
      'fr-zenith-nantes': 8,
    });
    expect(
      ConcertDisabilityContact.matchFrenchVenue('Olympia', 'Arcachon'),
      isNull,
    );
    expect(
      ConcertDisabilityContact.matchFrenchVenue('Palais des Congrès', 'Tours'),
      isNull,
    );
    expect(
      ConcertDisabilityContact.matchFrenchVenue('Accor Arena', ''),
      isNull,
    );
    expect(
      ConcertDisabilityContact.matchFrenchVenue('Fake Accor Arena', 'Paris'),
      isNull,
    );
  });

  for (final profile in ConcertDisabilityContact.france) {
    testWidgets('French accessible handoffs: ${profile.id}', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        french(
          ConcertDisabilityScreen(
            eventTitle: 'Spectacle',
            country: 'FR',
            venue: profile.aliases.first,
            city: profile.cities.first,
            opener: (uri, _) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(row(tester, 'disability-selected').title, profile.name);
      expect(opened, isEmpty);
      expect(
        rows(tester).any(
          (r) =>
              r.id == 'disability-directory' || r.id == 'disability-calendar',
        ),
        isFalse,
      );
      expect(
        row(tester, 'disability-contact-info').title,
        startsWith('Consulter'),
      );
      row(tester, 'disability-contact-info').onActivate!();
      await tester.pumpAndSettle();
      expect(opened.last.toString(), profile.instructions);
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
      if (profile.id == 'fr-stade-france' || profile.id == 'fr-zenith-nantes') {
        expect(
          rows(tester).any((r) => r.id.startsWith('disability-mail-')),
          isFalse,
        );
        expect(row(tester, 'disability-guidance').title, contains('PSH'));
      }
    });
  }

  testWidgets(
    'unknown French venue never uses Italian promoter; chooser stays French',
    (tester) async {
      var eventOpened = false;
      await tester.pumpWidget(
        french(
          ConcertDisabilityScreen(
            eventTitle: 'Spectacle',
            country: 'FR',
            organiser: 'Vivo Concerti Srl',
            venue: 'Unknown',
            city: 'Lyon',
            openEvent: () async {
              eventOpened = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        row(tester, 'disability-unmatched').title,
        contains('contact vérifié'),
      );
      expect(
        rows(tester).any(
          (r) => r.id == 'disability-selected' || r.id == 'disability-calendar',
        ),
        isFalse,
      );
      row(tester, 'disability-open-event').onActivate!();
      expect(eventOpened, isTrue);
      row(tester, 'disability-choose-organiser').onActivate!();
      await tester.pumpAndSettle();
      expect(rows(tester).where((r) => r.id.startsWith('fr-')).length, 5);
      expect(rows(tester).any((r) => r.id.startsWith('organiser-')), isFalse);
      row(tester, 'fr-olympia').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'disability-selected').title, contains('Olympia'));
      expect(rows(tester).any((r) => r.id == 'disability-directory'), isFalse);
    },
  );

  testWidgets(
    'French search opens native disability information with catalogue venue',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'sonarpad_concert_welcome_accepted_v1': true,
        'concert_country': 'FR',
      });
      final service = ConcertSearchService(
        logger: (_) async {},
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'products': [
                {
                  'name': 'Test concert',
                  'link': 'https://www.eventim.fr/event/test/',
                  'typeAttributes': {
                    'liveEntertainment': {
                      'startDate': '2027-12-01T20:00:00+01:00',
                      'location': {'name': 'Accor Arena', 'city': 'Paris'},
                    },
                  },
                },
              ],
              'page': 1,
              'totalPages': 1,
              'totalResults': 1,
            }),
            200,
          ),
        ),
      );
      await tester.pumpWidget(french(ConcertSearchScreen(service: service)));
      await tester.pumpAndSettle();
      row(tester, 'search').onActivate!();
      await tester.pumpAndSettle();
      row(tester, 'item-0').onActivate!();
      await tester.pumpAndSettle();
      expect(rows(tester).any((r) => r.id == 'ticketone-login'), isFalse);
      row(tester, 'disability-access').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'disability-selected').title, 'Accor Arena — Paris');
      expect(
        row(tester, 'disability-phone-+33146915754').title,
        startsWith('Appeler'),
      );
      await tester.pumpWidget(const SizedBox());
      service.close();
    },
  );
}
