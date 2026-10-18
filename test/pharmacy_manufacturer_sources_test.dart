import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/parafarmaco_service.dart';
import 'package:sonarpad_mobile_starter/services/pharmacy_manufacturer_catalog.dart';

void main() {
  ParafarmacoService emptySearchService() => ParafarmacoService(
    client: MockClient(
      (_) async =>
          http.Response('<div class="app-alert">Nessun risultato</div>', 200),
    ),
  );

  test('complete catalogues remain searchable when Codifa is empty', () async {
    final service = emptySearchService();
    for (final brand in ['Aboca', 'Supradyn']) {
      final expected = pharmacyManufacturerCatalog.where(
        (p) => p.brand == brand,
      );
      final results = await service.searchProducts(brand);
      expect(
        results.map((r) => r.sourceUrl),
        containsAll(expected.map((p) => p.url)),
      );
      expect(expected.length, brand == 'Aboca' ? 135 : 20);
      for (final product in expected) {
        final matches = await service.searchProducts('$brand ${product.name}');
        expect(
          matches.map((r) => r.sourceUrl),
          contains(product.url),
          reason: product.name,
        );
      }
    }
  });

  test(
    'product line searches prioritize official sources and preserve variants',
    () async {
      final service = emptySearchService();
      for (final query in ['grintuss', 'neobianacid', 'melilax pediatric']) {
        final results = await service.searchProducts(query);
        expect(results.first.sourceName, 'Aboca (sito ufficiale)');
      }
      final pediatric = await service.searchProducts('grintuss pediatric');
      expect(
        pediatric.every((r) => r.name.toLowerCase().contains('pediatric')),
        isTrue,
      );
      final vitaminC = await service.searchProducts(
        'supradyn expert vitamina c',
      );
      expect(
        vitaminC.any((r) => r.name == 'Supradyn Expert Vitamina D'),
        isFalse,
      );
      expect(
        vitaminC.any((r) => r.name == 'Supradyn Expert Vitamina C'),
        isTrue,
      );
      expect(await service.searchProducts('capsule'), isEmpty);
    },
  );

  test('Aboca sections come only from the selected product panels', () async {
    const usage =
        'Seguire le istruzioni specifiche riportate sulla confezione del prodotto selezionato, senza utilizzare quelle di altre varianti.';
    const warnings =
        'Leggere attentamente tutte le avvertenze della specifica confezione prima di utilizzare il prodotto selezionato.';
    final service = ParafarmacoService(
      client: MockClient((request) async {
        if (request.url.host != 'www.aboca.com') {
          return http.Response(
            '<div class="app-alert">Nessun risultato</div>',
            200,
          );
        }
        return http.Response(
          '''<main><div class="product-page"><h1>Grintuss Adulti Sciroppo</h1>
        <div class="prmoreinfo"><h3 class="prmoreinfo__title">Maggiori informazioni</h3>
        <div class="prmoreinfo__description"><div class="prtexts">
        Descrizione della specifica variante presente nella scheda del produttore.
        Le informazioni qui disponibili si riferiscono esclusivamente al prodotto selezionato.
        Consultare tutte le sezioni della scheda per leggere le informazioni pubblicate.
        </div></div></div>
        <div class="prmoreinfo"><h3 class="prmoreinfo__title">Modo d’uso</h3>
        <div class="prmoreinfo__description"><div class="prtexts">$usage</div></div></div>
        <div class="prmoreinfo"><h3 class="prmoreinfo__title">Avvertenze</h3>
        <div class="prmoreinfo__description"><div class="prtexts">$warnings</div></div></div>
        <div class="prothers">Altro prodotto Pediatric: altre istruzioni</div>
      </div></main>''',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );
    final result = (await service.searchProducts(
      'grintuss adulti sciroppo',
    )).first;
    final detail = await service.loadDetail(result);
    expect(detail.sectionText(ParafarmacoSectionType.usage), usage);
    expect(detail.sectionText(ParafarmacoSectionType.warnings), warnings);
    expect(
      detail.sections.containsKey(ParafarmacoSectionType.composition),
      isFalse,
    );
    expect(detail.fullText, isNot(contains('Pediatric')));
  });

  test('readable Supradyn pages stop before recommendations', () async {
    final service = ParafarmacoService(
      client: MockClient((request) async {
        if (request.url.host != 'www.supradyn.it') {
          return http.Response(
            '<div class="app-alert">Nessun risultato</div>',
            200,
          );
        }
        return http.Response('''<nav>Menu globale</nav><main>
        <h1>Supradyn Ricarica</h1><h2>Descrizione</h2>
        <p>Questa descrizione riguarda solo la variante selezionata del prodotto.
        Le informazioni di questa scheda provengono dal sito del produttore e
        vanno consultate insieme alle informazioni aggiornate della confezione.</p>
        <h2>Come assumerlo</h2>
        <p>Seguire le istruzioni riportate sulla confezione della variante
        acquistata e verificare le informazioni complete prima dell'utilizzo.</p>
        <h2>Avvertenze</h2><p>Leggere attentamente le avvertenze pubblicate
        per questo prodotto, che possono essere diverse da quelle di altri
        prodotti appartenenti alla stessa gamma del produttore.</p>
        <h2>Scopri la gamma Supradyn</h2><p>Altro prodotto: dosi diverse.</p>
      </main>''', 200);
      }),
    );
    final result = (await service.searchProducts('Supradyn Ricarica')).first;
    final detail = await service.loadDetail(result);
    expect(detail.fullText, isNot(contains('scheda sintetica')));
    expect(detail.fullText, isNot(contains('Menu globale')));
    expect(detail.fullText, isNot(contains('dosi diverse')));
    expect(
      detail.sectionText(ParafarmacoSectionType.usage),
      contains('Seguire le istruzioni'),
    );
  });

  for (final status in [403, 200]) {
    test(
      'blocked or unrecognized manufacturer page retains source without invented doses ($status)',
      () async {
        final service = ParafarmacoService(
          client: MockClient(
            (request) async => http.Response(
              request.url.host == 'www.supradyn.it'
                  ? '<main><h1>Access denied</h1></main>'
                  : '<div class="app-alert">Nessun risultato</div>',
              request.url.host == 'www.supradyn.it' ? status : 200,
            ),
          ),
        );
        final result = (await service.searchProducts(
          'Supradyn Ricarica',
        )).first;
        final detail = await service.loadDetail(result);
        expect(detail.sourceUrl, result.sourceUrl);
        expect(detail.fullText, contains('scheda sintetica'));
        expect(detail.fullText, isNot(contains('Access denied')));
        expect(
          detail.sections.containsKey(ParafarmacoSectionType.usage),
          isFalse,
        );
      },
    );
  }
}
