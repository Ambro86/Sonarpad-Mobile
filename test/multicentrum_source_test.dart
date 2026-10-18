import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/multicentrum_catalog.dart';
import 'package:sonarpad_mobile_starter/services/parafarmaco_service.dart';

void main() {
  test(
    'brand search includes every official product despite many packages',
    () async {
      final service = ParafarmacoService(
        client: MockClient(
          (_) async => http.Response(
            List.generate(
              40,
              (index) =>
                  '''
          <div class="result-header" data-codice="$index" data-isfarmaco="false">
            <div class="result-title">Multicentrum confezione $index</div>
          </div>
        ''',
            ).join(),
            200,
          ),
        ),
      );
      final results = await service.searchProducts('multicentrum');
      final official = results
          .where(
            (result) => result.sourceName == 'Multicentrum (sito ufficiale)',
          )
          .toList();
      expect(
        official.map((result) => result.name),
        unorderedEquals(multicentrumCatalog.map((product) => product.name)),
      );
      expect(official.map((result) => result.sourceUrl).toSet().length, 24);
      expect(
        official.any((result) => result.name.contains('Age Science')),
        isTrue,
      );
      expect(official.any((result) => result.name.contains('Kids')), isTrue);
      expect(
        official.any((result) => result.name.contains('Flora Intestinale')),
        isTrue,
      );
    },
  );

  test(
    'each catalogue name finds its exact variant first without Codifa',
    () async {
      final service = ParafarmacoService(
        client: MockClient(
          (_) async => http.Response(
            '<div class="app-alert">Nessun risultato</div>',
            200,
          ),
        ),
      );
      for (final product in multicentrumCatalog) {
        final results = await service.searchProducts(product.name);
        expect(results.first.name, product.name, reason: product.name);
        expect(
          results.first.sourceUrl,
          'https://www.multicentrum.it${product.path}',
        );
      }
      for (final query in [
        'Multicentrum Donna 50 plus',
        'Multicentrum Duobiotico',
        'Multicentrum MyMag',
        'Multicentrum Vitagummies',
      ]) {
        expect(await service.searchProducts(query), isNotEmpty, reason: query);
      }
      final fifty = await service.searchProducts('Multicentrum Donna 50 plus');
      expect(fifty.map((result) => result.name), ['Multicentrum Donna 50+']);
    },
  );

  for (final status in [200, 503]) {
    test(
      'official Mamma source survives empty or failed Codifa ($status)',
      () async {
        final service = ParafarmacoService(
          client: MockClient(
            (_) async => http.Response(
              '<div class="app-alert">Nessun risultato</div>',
              status,
            ),
          ),
        );
        final results = await service.searchProducts(' Multicentrum Mamma ');
        expect(results.first.name, 'Multicentrum Mamma');
        expect(results.first.sourceName, 'Multicentrum (sito ufficiale)');
        expect(
          results.first.sourceUrl,
          'https://www.multicentrum.it/prodotti/gravidanza/multicentrum-mamma/',
        );
        expect(service.isMedicationResult(results.first), isFalse);
        expect(service.excludeAifaMedicationDuplicates(results, []), results);
      },
    );
  }

  test('specific variants do not return the plain Mamma product', () async {
    final service = ParafarmacoService(
      client: MockClient(
        (_) async =>
            http.Response('<div class="app-alert">Nessun risultato</div>', 200),
      ),
    );
    for (final name in [
      'Multicentrum Mamma DHA',
      'Multicentrum Premamma',
      'Multicentrum Neo Mamma DHA',
    ]) {
      final results = await service.searchProducts(name);
      expect(results.first.name, name);
      expect(
        results.any((result) => result.name == 'Multicentrum Mamma'),
        isFalse,
      );
    }
    expect(await service.searchProducts('altro integratore'), isEmpty);
  });

  test(
    'manufacturer detail excludes navigation and other product variants',
    () async {
      final service = ParafarmacoService(
        client: MockClient((request) async {
          if (request.url.host != 'www.multicentrum.it') {
            return http.Response(
              '<div class="app-alert">Nessun risultato</div>',
              200,
            );
          }
          return http.Response('''
        <div>Menu prodotti e offerte</div>
        <div class="product-detail-top-block">
          <h1>Multicentrum Mamma</h1>
          <h2>Descrizione</h2>
          <p>Integratore alimentare di vitamine e minerali per la gravidanza.
          La scheda del produttore descrive questa specifica formulazione,
          distinta dalle altre varianti della gamma disponibili sul sito.</p>
          <a href="/dove-comprare/">Acquistalo qui</a>
        </div>
        <div class="tabs">
          <h2>Avvertenze</h2>
          <p>Leggere le avvertenze riportate sulla confezione e rispettare
          le indicazioni del produttore per la specifica variante acquistata.
          Verificare sempre le informazioni aggiornate della confezione.</p>
          <h2>Composizione</h2>
          <p>La composizione completa e le quantita dei singoli componenti
          sono riportate sulla confezione della specifica variante del prodotto.</p>
        </div>
        <div><h2>Prodotti associati</h2>Neo Mamma DHA: altro prodotto</div>
      ''', 200);
        }),
      );
      final product = (await service.searchProducts(
        'multicentrum mamma',
      )).first;
      final detail = await service.loadDetail(product);
      expect(detail.name, 'Multicentrum Mamma');
      expect(detail.fullText, contains('specifica formulazione'));
      expect(detail.fullText, isNot(contains('Menu prodotti')));
      expect(detail.fullText, isNot(contains('Acquistalo qui')));
      expect(detail.fullText, isNot(contains('Neo Mamma DHA')));
      expect(
        detail.sectionText(ParafarmacoSectionType.warnings),
        contains('Leggere le avvertenze'),
      );
    },
  );

  for (final status in [200, 404]) {
    test(
      'missing manufacturer content uses an attributed summary ($status)',
      () async {
        final service = ParafarmacoService(
          client: MockClient(
            (request) async => http.Response(
              request.url.host == 'www.multicentrum.it'
                  ? '<h1>Prodotti associati</h1>Contenuto non disponibile'
                  : '<div class="app-alert">Nessun risultato</div>',
              request.url.host == 'www.multicentrum.it' ? status : 200,
            ),
          ),
        );
        final product = (await service.searchProducts(
          'multicentrum mamma',
        )).first;
        final detail = await service.loadDetail(product);
        expect(detail.name, 'Multicentrum Mamma');
        expect(detail.sourceUrl, product.sourceUrl);
        expect(detail.fullText, contains('scheda sintetica'));
        expect(detail.fullText, isNot(contains('Prodotti associati')));
        expect(
          detail.sections.containsKey(ParafarmacoSectionType.usage),
          isFalse,
        );
      },
    );
  }
}
