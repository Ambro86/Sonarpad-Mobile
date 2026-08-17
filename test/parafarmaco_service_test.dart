import 'package:flutter_test/flutter_test.dart';
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
}
