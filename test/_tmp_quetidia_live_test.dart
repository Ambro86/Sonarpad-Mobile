import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:sonarpad_mobile_starter/services/parafarmaco_service.dart';

void main() {
  test('Quetidia A cosa serve non mostra valori medi o ingredienti', () async {
    HttpOverrides.global = null;
    final client = IOClient(HttpClient());
    addTearDown(client.close);
    final service = ParafarmacoService(client: client);
    final results = await service.searchProducts('Quetidia');
    final product = results.firstWhere(
      (item) =>
          item.sourceName == 'Codifa/Farmadati' &&
          !service.isMedicationResult(item) &&
          item.sourceUrl.contains('handler=Detail'),
    );
    final detail = await service.loadDetail(product);
    final indications = detail.sectionText(ParafarmacoSectionType.indications);
    final warnings = detail.sectionText(ParafarmacoSectionType.warnings);

    expect(indications, contains('rilassamento in caso di stress'));
    expect(indications, isNot(contains('Valori medi')));
    expect(indications, isNot(contains('Ingredienti')));
    expect(indications, isNot(contains('Caratteristiche nutrizionali')));
    expect(indications, isNot(contains('Scheda completa disponibile')));
    expect(
      detail.sectionText(ParafarmacoSectionType.usage),
      contains('Assumere'),
    );
    expect(warnings, isNot(contains('Valori medi')));
    expect(
      warnings.toLowerCase(),
      anyOf(contains('componenti'), contains('non è disponibile')),
    );
    if (!warnings.contains('non è disponibile')) {
      expect(warnings, isNot(contains('Conservare in luogo')));
    }
  });
}
