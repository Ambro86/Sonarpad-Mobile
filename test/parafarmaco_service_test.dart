import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/aifa_service.dart';
import 'package:sonarpad_mobile_starter/services/parafarmaco_service.dart';

void main() {
  group('ParafarmacoService deduplicazione AIFA', () {
    final service = ParafarmacoService();
    final aifaResults = <AifaDrugResult>[
      AifaDrugResult(
        denominazione: 'TANTUM VERDE',
        principiAttivi: 'Benzidamina cloridrato',
        aic9: '000000001',
        confezioni: const [],
      ),
    ];

    test('nasconde la scheda Codifa dello stesso medicinale', () {
      const medicine = ParafarmacoSearchResult(
        name: 'Tantum Verde 0,15% collutorio',
        category: 'Medicinale / scheda Codifa',
        sourceName: 'Codifa/Farmadati',
        sourceUrl: 'https://www.codifa.it/farmaci/t/tantum-verde-collutorio',
      );

      final filtered = service.excludeAifaMedicationDuplicates(const [
        medicine,
      ], aifaResults);

      expect(filtered, isEmpty);
    });

    test('mantiene un dispositivo con lo stesso marchio', () {
      const device = ParafarmacoSearchResult(
        name: 'Tantum Verde dispositivo per la gola',
        category: 'Dispositivo medico',
        sourceName: 'Codifa/Farmadati',
        sourceUrl:
            'https://www.codifa.it/parafarmaci/t/tantum-verde-dispositivo',
      );

      final filtered = service.excludeAifaMedicationDuplicates(const [
        device,
      ], aifaResults);

      expect(filtered, const [device]);
    });

    test('mantiene il medicinale Codifa se AIFA non lo ha trovato', () {
      const medicine = ParafarmacoSearchResult(
        name: 'Altro medicinale',
        category: 'Medicinale / scheda Codifa',
        sourceName: 'Codifa/Farmadati',
        sourceUrl: 'https://www.codifa.it/farmaci/a/altro-medicinale',
      );

      final filtered = service.excludeAifaMedicationDuplicates(const [
        medicine,
      ], aifaResults);

      expect(filtered, const [medicine]);
    });
  });

  group('ParafarmacoService indici Codifa/Farmadati', () {
    late ParafarmacoService service;

    setUp(() {
      service = ParafarmacoService(
        client: MockClient((request) async {
          if (request.url.path == '/integratori/m') {
            return http.Response(
              '<html><body>'
              '<a href="https://codifa-legacy.farmadati.it/integratori/m/massigen-integratori-di-vitamine-e-minerali">Massigen</a>'
              '</body></html>',
              200,
              headers: const {'content-type': 'text/html; charset=utf-8'},
            );
          }
          if (request.url.path == '/integratori/q') {
            return http.Response(
              '<html><body>'
              '<a href="http://codifa-legacy.farmadati.it/integratori/q/quetidia-integratori-per-sonno-e-stress">Quetidia</a>'
              '</body></html>',
              200,
              headers: const {'content-type': 'text/html; charset=utf-8'},
            );
          }
          return http.Response('<html><body></body></html>', 200);
        }),
      );
    });

    test('accetta i link assoluti del dominio legacy Farmadati', () async {
      final results = await service.searchProducts('massigen');

      expect(results.any((result) => result.name == 'Massigen'), isTrue);
      expect(
        results.firstWhere((result) => result.name == 'Massigen').sourceUrl,
        startsWith('https://codifa-legacy.farmadati.it/integratori/m/'),
      );
    });

    test(
      'canonicalizza in HTTPS anche i link legacy scritti in HTTP',
      () async {
        final results = await service.searchProducts('quetidia');

        expect(results.any((result) => result.name == 'Quetidia'), isTrue);
        expect(
          results.firstWhere((result) => result.name == 'Quetidia').sourceUrl,
          startsWith('https://codifa-legacy.farmadati.it/integratori/q/'),
        );
      },
    );
  });

  group('ParafarmacoService nuovo handler Codifa', () {
    late ParafarmacoService service;

    setUp(() {
      service = ParafarmacoService(
        client: MockClient((request) async {
          if (request.url.path == '/farmaci' &&
              request.url.queryParameters['handler'] == 'Search') {
            return http.Response(
              '<div id="searchContainer"><div class="result-item">'
              '<div class="result-header" data-codice="934488976" '
              'data-isfarmaco="false" data-codiceDitta="152K">'
              '<div class="result-title">QUETIDIA 30 COMPRESSE</div>'
              '<div class="result-ditta">NEURAXPHARM ITALY SpA</div>'
              '</div></div></div>',
              200,
              headers: const {'content-type': 'text/html; charset=utf-8'},
            );
          }
          if (request.url.path == '/farmaci' &&
              request.url.queryParameters['handler'] == 'Detail') {
            return http.Response(
              '<div class="detail-title-info"><h2>QUETIDIA 30CPR</h2></div>'
              '<iframe srcdoc="&lt;h1&gt;QUETIDIA&lt;/h1&gt;'
              '&lt;b&gt;Descrizione&lt;/b&gt;&lt;br&gt;Integratore alimentare per il rilassamento in caso di stress e per il benessere mentale. '
              '&lt;b&gt;Ingredienti&lt;/b&gt;&lt;br&gt;Magnesio, passiflora, tè verde e scutellaria. '
              '&lt;b&gt;Caratteristiche nutrizionali&lt;/b&gt;&lt;br&gt;Valori medi per una compressa: magnesio 75 mg. '
              '&lt;b&gt;Modalità d\'uso&lt;/b&gt;&lt;br&gt;Assumere una compressa al giorno con acqua. '
              '&lt;b&gt;Avvertenze&lt;/b&gt;&lt;br&gt;Non superare la dose giornaliera consigliata. Non assumere in caso di allergie verso uno o più componenti. Tenere fuori dalla portata dei bambini. '
              '&lt;b&gt;Conservazione&lt;/b&gt;&lt;br&gt;Conservare in luogo fresco e asciutto."'
              '></iframe>',
              200,
              headers: const {'content-type': 'text/html; charset=utf-8'},
            );
          }
          return http.Response('', 404);
        }),
      );
    });

    test('trova Quetidia come prodotto non AIFA', () async {
      final results = await service.searchProducts('quetidia');

      expect(results, hasLength(1));
      expect(results.single.name, 'QUETIDIA 30 COMPRESSE');
      expect(results.single.category, contains('Parafarmaco'));
      expect(results.single.code, '934488976');
      expect(results.single.sourceUrl, contains('handler=Detail'));
      expect(service.isMedicationResult(results.single), isFalse);
    });

    test('legge la scheda tecnica incorporata nel nuovo srcdoc', () async {
      final product = (await service.searchProducts('quetidia')).single;
      final detail = await service.loadDetail(product);

      expect(detail.name, 'QUETIDIA 30CPR');
      expect(detail.code, '934488976');
      expect(detail.fullText, contains('Integratore alimentare'));
      expect(
        detail.sections[ParafarmacoSectionType.indications],
        contains('rilassamento in caso di stress'),
      );
      expect(
        detail.sections[ParafarmacoSectionType.indications],
        isNot(contains('Ingredienti')),
      );
      expect(
        detail.sections[ParafarmacoSectionType.indications],
        isNot(contains('Valori medi')),
      );
      expect(
        detail.sectionText(ParafarmacoSectionType.indications),
        isNot(contains('Valori medi')),
      );
      expect(
        detail.sectionText(ParafarmacoSectionType.indications),
        isNot(contains('Ingredienti')),
      );
      expect(
        detail.sectionText(ParafarmacoSectionType.indications),
        isNot(contains('Scheda completa disponibile')),
      );
      expect(
        detail.sections[ParafarmacoSectionType.usage],
        contains('Assumere una compressa'),
      );
      expect(
        detail.sections[ParafarmacoSectionType.warnings],
        contains('Non superare la dose'),
      );
      expect(
        detail.sections[ParafarmacoSectionType.warnings],
        contains('allergie verso uno o più componenti'),
      );
      expect(
        detail.sections[ParafarmacoSectionType.warnings],
        isNot(contains('Conservare in luogo fresco')),
      );
      expect(
        detail.sections[ParafarmacoSectionType.composition],
        contains('Magnesio'),
      );
      expect(
        detail.sections[ParafarmacoSectionType.composition],
        isNot(contains('Valori medi')),
      );
    });

    test('ritenta la ricerca dopo un errore temporaneo Codifa', () async {
      var attempts = 0;
      final retryingService = ParafarmacoService(
        client: MockClient((request) async {
          attempts++;
          if (attempts == 1) return http.Response('', 503);
          return http.Response(
            '<div class="result-header" data-codice="934488976" '
            'data-isfarmaco="false">'
            '<div class="result-title">QUETIDIA 30 COMPRESSE</div></div>',
            200,
          );
        }),
      );

      final results = await retryingService.searchProducts('quetidia');

      expect(attempts, 2);
      expect(results.single.name, 'QUETIDIA 30 COMPRESSE');
    });
  });

  group('ParafarmacoService varianti sezioni Codifa', () {
    test('riconosce descrizione iniziale e Modalitá d’uso', () async {
      final service = ParafarmacoService(
        client: MockClient((request) async {
          if (request.url.queryParameters['handler'] == 'Search') {
            return http.Response(
              '<div class="result-header" data-codice="900654284" '
              'data-isfarmaco="false">'
              '<div class="result-title">COMPEED VESCICHE</div></div>',
              200,
            );
          }
          return http.Response(
            '<div class="detail-title-info"><h2>COMPEED VESCICHE</h2></div>'
            '<iframe srcdoc="&lt;h1&gt;COMPEED VESCICHE&lt;/h1&gt;&lt;br&gt;'
            'Trattamento per la guarigione e la prevenzione delle vesciche, con protezione della pelle dallo sfregamento.'
            '&lt;br&gt;&lt;b&gt;Modalitá d&#39;uso:&lt;/b&gt;&lt;br&gt;'
            'Applicare sulla pelle pulita e asciutta e lasciare applicato finché il cerotto non si stacca da solo.'
            '"></iframe>',
            200,
          );
        }),
      );

      final product = (await service.searchProducts('compeed')).single;
      final detail = await service.loadDetail(product);

      expect(
        detail.sections[ParafarmacoSectionType.indications],
        contains('prevenzione delle vesciche'),
      );
      expect(
        detail.sections[ParafarmacoSectionType.usage],
        contains('Applicare sulla pelle'),
      );
    });

    test('riconosce Modalità d’utilizzo', () async {
      final service = ParafarmacoService(
        client: MockClient((request) async {
          if (request.url.queryParameters['handler'] == 'Search') {
            return http.Response(
              '<div class="result-header" data-codice="926116955" '
              'data-isfarmaco="false">'
              '<div class="result-title">GENGIGEL</div></div>',
              200,
            );
          }
          return http.Response(
            '<div class="detail-title-info"><h2>GENGIGEL</h2></div>'
            '<iframe srcdoc="&lt;h1&gt;GENGIGEL&lt;/h1&gt;'
            '&lt;b&gt;Modalità d&#39;utilizzo&lt;/b&gt;&lt;br&gt;'
            'Stendere una piccola quantità di prodotto e massaggiare delicatamente la gengiva fino a coprire la zona interessata.'
            '"></iframe>',
            200,
          );
        }),
      );

      final product = (await service.searchProducts(
        'gengigel',
      )).firstWhere((result) => result.sourceUrl.contains('handler=Detail'));
      final detail = await service.loadDetail(product);

      expect(
        detail.sections[ParafarmacoSectionType.usage],
        contains('Stendere una piccola quantità'),
      );
    });

    test('un unico titolo <b> non versa valori medi in A cosa serve', () async {
      final service = ParafarmacoService(
        client: MockClient((request) async {
          if (request.url.queryParameters['handler'] == 'Search') {
            return http.Response(
              '<div class="result-header" data-codice="934488976" '
              'data-isfarmaco="false">'
              '<div class="result-title">QUETIDIA 30 COMPRESSE</div></div>',
              200,
            );
          }
          return http.Response(
            '<div class="detail-title-info"><h2>QUETIDIA 30CPR</h2></div>'
            '<iframe srcdoc="'
            '&lt;b&gt;Descrizione&lt;br&gt;Integratore alimentare per il rilassamento in caso di stress.&lt;br&gt;'
            'Ingredienti&lt;br&gt;Magnesio, passiflora e tè verde.&lt;br&gt;'
            'Caratteristiche nutrizionali&lt;br&gt;Valori medi per una compressa: magnesio 75 mg.&lt;br&gt;'
            'Modalità d&#39;uso&lt;br&gt;Assumere una compressa al giorno con acqua.&lt;br&gt;'
            'Avvertenze&lt;br&gt;Non superare la dose giornaliera consigliata in caso di allergie verso uno o più componenti.&lt;/b&gt;'
            '"></iframe>',
            200,
          );
        }),
      );

      final product = (await service.searchProducts('quetidia')).single;
      final detail = await service.loadDetail(product);
      final indications = detail.sectionText(
        ParafarmacoSectionType.indications,
      );

      expect(indications, contains('rilassamento in caso di stress'));
      expect(indications, isNot(contains('Valori medi')));
      expect(indications, isNot(contains('Ingredienti')));
      expect(indications, isNot(contains('Assumere una compressa')));
      expect(
        detail.sectionText(ParafarmacoSectionType.usage),
        contains('Assumere una compressa'),
      );
      expect(
        detail.sectionText(ParafarmacoSectionType.warnings),
        contains('uno o più componenti'),
      );
    });

    test('se la fonte omette una sezione non mescola la scheda completa', () {
      const detail = ParafarmacoDetail(
        name: 'Prodotto',
        category: 'Parafarmaco',
        sourceName: 'Codifa/Farmadati',
        sourceUrl: 'https://codifa.it/farmaci',
        sections: <ParafarmacoSectionType, String>{},
        fullText:
            'Scheda completa del prodotto con tutte le informazioni effettivamente pubblicate dalla fonte originale.',
      );

      for (final type in const [
        ParafarmacoSectionType.indications,
        ParafarmacoSectionType.usage,
        ParafarmacoSectionType.warnings,
        ParafarmacoSectionType.composition,
      ]) {
        expect(detail.sectionText(type), contains('non è disponibile'));
        expect(
          detail.sectionText(type),
          isNot(contains('scheda completa del prodotto')),
        );
      }
    });
  });

  group('ParafarmacoService indice parafarmaci legacy', () {
    test('sfoglia soltanto i parafarmaci della lettera selezionata', () async {
      final service = ParafarmacoService(
        client: MockClient((request) async {
          if (request.url.path == '/parafarmaci/m') {
            return http.Response(
              '<html><body><nav class="menu">'
              '<a href="/parafarmaci/m/massigen">Massigen</a>'
              '<a href="/parafarmaci/m/microlife">Microlife</a>'
              '<a href="/integratori/m/multicentrum">Multicentrum</a>'
              '<a href="/parafarmaci/a/altro">Altro</a>'
              '</nav></body></html>',
              200,
            );
          }
          return http.Response('<html><body></body></html>', 200);
        }),
      );

      final results = await service.browseParafarmaciByLetter('m');

      expect(results.map((result) => result.name).toList(), [
        'Massigen',
        'Microlife',
      ]);
      expect(
        results.every((result) => !service.isMedicationResult(result)),
        isTrue,
      );
    });
  });
}
