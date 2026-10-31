import 'package:flutter/material.dart';
import 'package:sonarpad_mobile_starter/services/concert_disability_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sonarpad_mobile_starter/screens/concert_disability_screen.dart';
import 'travel_screen_test.dart' show app, row, rows;

void main() {
  test('22 distinct official profiles, conservative organiser matching', () {
    final profiles = ConcertDisabilityContact.all;
    expect(profiles.length, 22);
    expect(profiles.map((p) => p.id).toSet().length, 22);
    for (final profile in profiles) {
      expect(Uri.parse(profile.source).host, 'www.ticketone.it');
      expect(Uri.parse(profile.instructions).scheme, 'https');
      for (final alias in profile.aliases) {
        expect(
          ConcertDisabilityContact.match('$alias S.R.L., Via Roma 1'),
          profile,
        );
        expect(ConcertDisabilityContact.match('$alias Fake srl'), isNull);
        expect(
          ConcertDisabilityContact.match('Other promoter, $alias'),
          isNull,
        );
      }
    }
    expect(ConcertDisabilityContact.match(''), isNull);
    expect(ConcertDisabilityContact.match('Stage Entertainment srl'), isNull);
    expect(ConcertDisabilityContact.match('Show Bees srl'), isNull);
    expect(
      ConcertDisabilityContact.match('FRIENDS e PARTNERS S.P.A., Milano')?.name,
      'Friends & Partners',
    );
  });

  for (final profile in ConcertDisabilityContact.all.where(
    (p) => p.name != 'Vivo Concerti',
  )) {
    testWidgets('verified handoffs: ${profile.name}', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        app(
          ConcertDisabilityScreen(
            eventTitle: 'Test concert',
            contact: profile,
            opener: (uri, _) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      expect(opened, isEmpty);
      expect(row(tester, 'disability-selected').title, profile.name);
      expect(rows(tester).any((r) => r.id == 'disability-calendar'), isFalse);
      row(tester, 'disability-contact-info').onActivate!();
      await tester.pumpAndSettle();
      expect(opened.single.toString(), profile.instructions);
      for (final email in profile.emails) {
        row(tester, 'disability-mail-$email').onActivate!();
        await tester.pumpAndSettle();
        expect(opened.last.toString(), 'mailto:$email');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('manual chooser preserves actual event organiser', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const ConcertDisabilityScreen(
          eventTitle: 'My concert',
          organiser: 'Unknown promoter',
        ),
      ),
    );
    row(tester, 'disability-choose-organiser').onActivate!();
    await tester.pumpAndSettle();
    expect(rows(tester).where((r) => r.id.startsWith('organiser-')).length, 22);
    row(tester, 'organiser-8').onActivate!();
    await tester.pumpAndSettle();
    expect(row(tester, 'disability-event').title, 'My concert');
    expect(
      row(tester, 'disability-organiser').title,
      contains('Unknown promoter'),
    );
    expect(row(tester, 'disability-selected').title, 'Friends & Partners');
    await tester.pumpWidget(const SizedBox());
  });

  test('Vivo routing requires the actual organiser name', () {
    expect(ConcertDisabilityScreen.isVivo('Vivo Concerti srl, Milano'), isTrue);
    expect(ConcertDisabilityScreen.isVivo('VIVO CONCERTI S.R.L.'), isTrue);
    expect(
      ConcertDisabilityScreen.isVivo('Another promoter, Vivo Concerti srl'),
      isFalse,
    );
    expect(ConcertDisabilityScreen.isVivo('Vivo Concerti Fake'), isFalse);
    expect(ConcertDisabilityScreen.isVivo(''), isFalse);
  });

  testWidgets(
    'unknown organiser has official fallback without assuming accreditation provider',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        app(
          ConcertDisabilityScreen(
            eventTitle: 'Concerto di prova',
            opener: (_, _) async {
              opened++;
              return true;
            },
          ),
        ),
      );
      expect(row(tester, 'disability-event').title, 'Concerto di prova');
      expect(rows(tester).any((r) => r.id == 'disability-calendar'), isFalse);
      expect(rows(tester).any((r) => r.id == 'disability-vivo-mail'), isFalse);
      expect(
        row(tester, 'disability-request-not-booking').title,
        contains('non equivale'),
      );
      expect(opened, 0);
      row(tester, 'disability-directory').onActivate!();
      await tester.pumpAndSettle();
      expect(opened, 1);
    },
  );

  testWidgets(
    'Vivo offers explicit official handoffs with no documents or automatic requests',
    (tester) async {
      final opened = <(Uri, LaunchMode)>[];
      await tester.pumpWidget(
        app(
          ConcertDisabilityScreen(
            eventTitle: 'Irama, Torino, 21 dicembre',
            organiser: 'Vivo Concerti srl, Milano',
            opener: (uri, mode) async {
              opened.add((uri, mode));
              return true;
            },
          ),
        ),
      );
      expect(
        row(tester, 'disability-organiser').title,
        contains('Vivo Concerti'),
      );
      expect(
        row(tester, 'disability-calendar-help').title,
        contains('stesso artista, città e data'),
      );
      expect(opened, isEmpty);
      row(tester, 'disability-calendar').onActivate!();
      await tester.pumpAndSettle();
      expect(opened.single, (
        Uri.parse('https://www.mani-amiche.it/agenda.php'),
        LaunchMode.inAppBrowserView,
      ));
      row(tester, 'disability-vivo-mail').onActivate!();
      await tester.pumpAndSettle();
      expect(opened.last.$1.toString(), 'mailto:info@vivoconcerti.com');
      expect(opened.last.$2, LaunchMode.externalApplication);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
