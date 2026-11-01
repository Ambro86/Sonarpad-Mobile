import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/l10n/concert_disability_international_strings.dart';
import 'package:sonarpad_mobile_starter/l10n/ticketone_strings.dart';
import 'package:sonarpad_mobile_starter/screens/concert_disability_screen.dart';
import 'package:sonarpad_mobile_starter/screens/concert_search_screen.dart';
import 'package:sonarpad_mobile_starter/services/concert_disability_contacts.dart';
import 'package:sonarpad_mobile_starter/services/concert_search_service.dart';
import 'travel_screen_test.dart' show row, rows;

Widget localized(Widget child, String locale) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  const locales = {
    'CH': 'de',
    'NL': 'en',
    'PL': 'pl',
    'SE': 'en',
    'NO': 'en',
    'RO': 'ro',
    'BR': 'pt',
  };
  const hosts = {
    'CH': 'www.ticketcorner.ch',
    'NL': 'www.eventim.nl',
    'PL': 'www.eventim.pl',
    'SE': 'www.eventim.se',
    'NO': 'www.eventim.no',
    'RO': 'www.eventim.ro',
    'BR': 'www.eventim.com.br',
  };

  test('every catalogue country has a scoped disability flow', () {
    for (final market in ConcertMarket.all) {
      expect(
        market.categories,
        contains(market.category),
        reason: market.country,
      );
    }
    expect(ConcertMarket.all.map((m) => m.country).toSet(), {
      'IT',
      'FR',
      'DE',
      'ES',
      'GB',
      'AT',
      ...locales.keys,
    });
    expect(
      ConcertDisabilityContact.international.keys.toSet(),
      locales.keys.toSet(),
    );
  });

  test('all new guidance keys resolve for every supported app locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final t = TicketOneStrings(locale.toLanguageTag());
      final translated =
          concertDisabilityInternationalStrings[locale.languageCode];
      expect(translated, isNotNull, reason: locale.toLanguageTag());
      for (final key in concertDisabilityInternationalStrings['en']!.keys) {
        expect(
          translated!.containsKey(key),
          isTrue,
          reason: '${locale.toLanguageTag()}: $key must not use fallback',
        );
        expect(t.t(key), translated[key]);
        if (locale.languageCode != 'en') {
          expect(
            translated[key],
            isNot(concertDisabilityInternationalStrings['en']![key]),
            reason: '${locale.toLanguageTag()}: $key is still English',
          );
        }
      }
      expect(t.t('disabilityInternationalUnknown'), isNotEmpty);
      for (final profiles in ConcertDisabilityContact.international.values) {
        for (final p in profiles) {
          expect(t.t(p.guidanceKey!), isNotEmpty);
          expect(t.t(p.guidanceKey!), isNot(p.guidanceKey));
        }
      }
    }
    expect(
      TicketOneStrings('pt-BR').t('disabilityTitle'),
      contains('deficiência'),
    );
    expect(
      TicketOneStrings('ro').t('disabilityTitle'),
      contains('dizabilități'),
    );
    expect(
      TicketOneStrings('pl').t('disabilityTitle'),
      contains('niepełnosprawnościami'),
    );
  });

  test('Norwegian companion procedures must remain distinct', () {
    final t = TicketOneStrings('it');
    expect(
      t.t('disabilityIntlCosmopolite'),
      contains('senza un biglietto separato'),
    );
    expect(t.t('disabilityIntlByscenen'), contains('ledsagerbillett separato'));
    expect(
      t.t('disabilityIntlOlavshallen'),
      contains('prenotare anche il proprio biglietto'),
    );
    expect(t.t('disabilityIntlEnquire'), contains('Non abbiamo verificato'));
  });

  for (final country in locales.keys) {
    final events =
        (jsonDecode(
                  File(
                    'test/fixtures/concert_disability_${country.toLowerCase()}_catalog.json',
                  ).readAsStringSync(),
                )
                as Map)['events']
            as List;
    final profiles = ConcertDisabilityContact.international[country]!;
    final locale = locales[country]!;
    test(
      '$country: 40 real distinct catalogue events, no donations or add-ons',
      () {
        expect(events.length, 40);
        expect(events.map((e) => e['productId']).toSet().length, 40);
        if (country != 'SE') {
          expect(
            events
                .map((e) => '${e['expectedProfile']}:${e['name']}')
                .toSet()
                .length,
            40,
          );
        }
        for (final e in events) {
          expect(Uri.parse(e['link']).host, hosts[country]);
          final live = e['typeAttributes']['liveEntertainment'];
          expect(
            DateTime.parse(live['startDate']).year,
            greaterThanOrEqualTo(2026),
          );
          expect(live['location']['city'], isNotEmpty);
          expect(live['location']['city'], isNot(contains('Do Not Use')));
          expect(
            RegExp(
              r'\bVIP\b|parking|donation|top seat|hospitality|soundcheck|meet & greet',
              caseSensitive: false,
            ).hasMatch(e['name']),
            isFalse,
          );
        }
      },
    );

    test(
      '$country: exact venue/city matching rejects namesakes and foreign countries',
      () {
        for (final p in profiles) {
          expect(
            ConcertDisabilityContact.matchInternationalVenue(
              country,
              ' ${p.aliases.first.toUpperCase()} ',
              p.cities.first,
            )?.id,
            p.id,
          );
          for (final city in ['', 'Unrelated city']) {
            expect(
              ConcertDisabilityContact.matchInternationalVenue(
                country,
                p.aliases.first,
                city,
              ),
              isNull,
            );
          }
          expect(
            ConcertDisabilityContact.matchInternationalVenue(
              country,
              '${p.aliases.first} other hall',
              p.cities.first,
            ),
            isNull,
          );
          expect(
            ConcertDisabilityContact.matchInternationalVenue(
              'ZZ',
              p.aliases.first,
              p.cities.first,
            ),
            isNull,
          );
        }
      },
    );

    for (final e in events) {
      testWidgets('$country ${e['productId']}: ${e['name']}', (tester) async {
        final location = e['typeAttributes']['liveEntertainment']['location'];
        final profile = ConcertDisabilityContact.matchInternationalVenue(
          country,
          location['name'],
          location['city'],
        );
        expect(profile?.id, e['expectedProfile']);
        expect(profile?.instructions, e['officialInstructions']);
        final opened = <Uri>[];
        var originalOpened = false;
        await tester.pumpWidget(
          localized(
            ConcertDisabilityScreen(
              eventTitle: e['name'],
              country: country,
              venue: location['name'],
              city: location['city'],
              openEvent: () async {
                originalOpened = true;
              },
              opener: (uri, _) async {
                opened.add(uri);
                return true;
              },
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(opened, isEmpty);
        expect(originalOpened, isFalse);
        expect(row(tester, 'disability-event').title, e['name']);
        expect(
          rows(tester).any(
            (r) =>
                r.id == 'disability-directory' || r.id == 'disability-calendar',
          ),
          isFalse,
        );
        if (profile == null) {
          expect(row(tester, 'disability-unmatched').title, isNotEmpty);
          expect(
            rows(tester).any(
              (r) =>
                  r.id.startsWith('disability-mail-') ||
                  r.id.startsWith('disability-phone-'),
            ),
            isFalse,
          );
        } else {
          expect(row(tester, 'disability-selected').title, profile.name);
          expect(
            row(tester, 'disability-guidance').title,
            TicketOneStrings(locale).t(profile.guidanceKey!),
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
        }
        row(tester, 'disability-open-event').onActivate!();
        await tester.pumpAndSettle();
        expect(originalOpened, isTrue);
      });
    }

    testWidgets(
      '$country: unknown venue and manual choice stay in this country',
      (tester) async {
        await tester.pumpWidget(
          localized(
            ConcertDisabilityScreen(
              eventTitle: 'Unknown',
              country: country,
              venue: 'Unknown',
              city: 'Unknown',
              contact: ConcertDisabilityContact.all.first,
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(row(tester, 'disability-unmatched').title, isNotEmpty);
        expect(rows(tester).any((r) => r.id == 'disability-selected'), isFalse);
        row(tester, 'disability-choose-organiser').onActivate!();
        await tester.pumpAndSettle();
        expect(
          rows(tester)
              .where((r) => r.id != 'disability-choose-help')
              .map((r) => r.id)
              .toSet(),
          profiles.map((p) => p.id).toSet(),
        );
        row(tester, profiles.first.id).onActivate!();
        await tester.pumpAndSettle();
        expect(row(tester, 'disability-selected').title, profiles.first.name);
      },
    );

    testWidgets('$country: search result opens native disability information', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'sonarpad_concert_welcome_accepted_v1': true,
        'concert_country': country,
      });
      final selectedEvent = events.firstWhere(
        (e) => e['expectedProfile'] != null,
      );
      final service = ConcertSearchService(
        logger: (_) async {},
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'products': [selectedEvent],
                'page': 1,
                'totalPages': 1,
                'totalResults': 1,
              }),
            ),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        localized(ConcertSearchScreen(service: service), locale),
      );
      await tester.pumpAndSettle();
      row(tester, 'search').onActivate!();
      await tester.pumpAndSettle();
      row(tester, 'item-0').onActivate!();
      await tester.pumpAndSettle();
      row(tester, 'disability-access').onActivate!();
      await tester.pumpAndSettle();
      expect(
        row(tester, 'disability-selected').title,
        profiles
            .firstWhere((p) => p.id == selectedEvent['expectedProfile'])
            .name,
      );
      await tester.pumpWidget(const SizedBox());
      service.close();
    });
  }
}
