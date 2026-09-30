// Port of the opt-in live tests in the Windows src/treccani.rs.
// flutter test --dart-define=TRECCANI_LIVE=true test/treccani_live_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sonarpad_mobile_starter/services/treccani_service.dart';

void main() {
  group('Treccani live', () {
    late http.Client client;
    late TreccaniService service;
    setUp(() {
      client = http.Client();
      service = TreccaniService(client: client);
    });
    tearDown(() => client.close());

    test('Del Noce complete entry', () async {
      final results = await service.search('del noce');
      final result = results.firstWhere(
        (r) => r.url.contains('/enciclopedia/augusto-del-noce'),
      );
      final article = await service.loadArticle(result);
      expect(article.text, contains('Filosofo italiano'));
      expect(article.text, contains("L'epoca della secolarizzazione"));
      expect(article.text.split('\n'), isNot(contains('Riforma cattolica')));
      expect(article.sections, isEmpty);
    });

    test('Chimica body and sections', () async {
      final results = await service.search('chimica');
      final article = await service.loadArticle(
        results.firstWhere((r) => r.url.contains('/enciclopedia/chimica')),
      );
      expect(article.text, contains('Scienza che studia le proprietà'));
      expect(article.text, contains('== Storia =='));
      expect(article.text, contains('== C. organica =='));
      expect(
        article.text.split('\n'),
        isNot(contains('Risonanza magnetica nucleare')),
      );
      expect(article.sections, hasLength(11));
    });

    test('Autorita by Del Noce legacy index', () async {
      final results = await service.search('del noce');
      final result = results.firstWhere(
        (r) =>
            r.url.toLowerCase().contains('autorita_') &&
            r.url.toLowerCase().contains('enciclopedia-del-novecento'),
      );
      final article = await service.loadArticle(result);
      expect(article.sections.map((s) => s.title), [
        "1. Eclissi dell'idea di autorità e crisi del mondo contemporaneo",
        '2. Autorità e potere',
        '3. Autorità e rivoluzione',
        "4. L'Occidente e il tramonto dell'autorità",
        "5. I totalitarismi e la negazione dell'autorità",
        "6. Lo spirito borghese e l'autorità",
        "7. L'idea di autorità nell'età liberale e nel primo dopoguerra",
        '8. Conclusioni',
        'Bibliografia',
      ]);
      expect(article.text, isNot(contains('.css-')));
      expect(article.text, contains("== 1. Eclissi dell'idea di autorità"));
      expect(article.text, contains('== Bibliografia =='));
    });

    test('40 distinct entries have real bodies', () async {
      const queries = [
        'chimica',
        'fisica',
        'matematica',
        'biologia',
        'astronomia',
        'geologia',
        'medicina',
        'informatica',
        'filosofia',
        'logica',
        'etica',
        'diritto',
        'economia',
        'sociologia',
        'psicologia',
        'linguistica',
        'letteratura',
        'poesia',
        'musica',
        'pittura',
        'scultura',
        'architettura',
        'fotografia',
        'cinema',
        'Roma',
        'Milano',
        'Napoli',
        'Sicilia',
        'Europa',
        'Rinascimento',
        'Illuminismo',
        'Risorgimento',
        'Dante Alighieri',
        'Leonardo da Vinci',
        'Galileo Galilei',
        'Alessandro Manzoni',
        'Maria Montessori',
        'Augusto Del Noce',
        'Enrico Fermi',
        'Rita Levi Montalcini',
      ];
      final seenUrls = <String>{};
      final failures = <String>[];
      for (final query in queries) {
        try {
          final results = await service.search(query);
          final result = results.firstWhere((r) => !seenUrls.contains(r.url));
          seenUrls.add(result.url);
          final article = await service.loadArticle(result);
          expect(
            article.text.runes.length,
            greaterThanOrEqualTo(100),
            reason: query,
          );
          final lines = article.text.split('\n').map((s) => s.trim());
          expect(
            lines.any(
              (s) =>
                  s.runes.length >= 80 &&
                  !s.startsWith('=') &&
                  !s.startsWith('- '),
            ),
            isTrue,
            reason: query,
          );
          expect(
            lines.any(
              (s) => [
                'tag',
                'categorie',
                'indice',
                'dal vocabolario',
                'lemmi correlati',
              ].contains(s.toLowerCase()),
            ),
            isFalse,
            reason: query,
          );
          for (final section in article.sections) {
            final marker = '=' * section.level.clamp(2, 6);
            final heading = '$marker ${section.title} $marker';
            expect(article.text, contains(heading), reason: query);
            expect(section.text, startsWith(heading), reason: query);
          }
        } catch (error) {
          failures.add('$query: $error');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
      expect(seenUrls, hasLength(40));
    }, timeout: const Timeout(Duration(minutes: 30)));
  }, skip: !const bool.fromEnvironment('TRECCANI_LIVE'));
}
