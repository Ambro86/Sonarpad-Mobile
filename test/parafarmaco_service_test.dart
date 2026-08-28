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

    test('canonicalizza in HTTPS anche i link legacy scritti in HTTP', () async {
      final results = await service.searchProducts('quetidia');

      expect(results.any((result) => result.name == 'Quetidia'), isTrue);
      expect(
        results.firstWhere((result) => result.name == 'Quetidia').sourceUrl,
        startsWith('https://codifa-legacy.farmadati.it/integratori/q/'),
      );
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

      expect(
        results.map((result) => result.name).toList(),
        ['Massigen', 'Microlife'],
      );
      expect(
        results.every((result) => !service.isMedicationResult(result)),
        isTrue,
      );
    });
  });

}
