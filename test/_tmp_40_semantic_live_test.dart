import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:sonarpad_mobile_starter/services/parafarmaco_service.dart';

void main() {
  test('40 parafarmaci aprono solo la sezione richiesta', () async {
    HttpOverrides.global = null;
    final client = IOClient(HttpClient());
    final service = ParafarmacoService(client: client);
    const queries = <String>[
      'Quetidia',
      'Polase',
      'Supradyn',
      'Multicentrum',
      'Redoxon',
      'Carnidyn Plus',
      'Magnesio Supremo',
      'Enterolactis Plus',
      'Lactoflorene Plus',
      'Sustenium Plus',
      'Grintuss adulti',
      'Compeed vesciche',
      'Rinoway',
      'Libenar',
      'Sterimar',
      'Drenax Forte',
      'Valeriana System',
      'ZzzQuil Natura',
      'Gengigel',
      'Artelac Complete',
      'Hylo Comod',
      'Tonimer',
      'Isomar',
      'Narhinel',
      'Physiomer',
      'Esoxx One',
      'Vidermina',
      'Armolipid Plus',
      'Dicoflor',
      'Prolife 10 Forte',
      'Yovis',
      'Kilocal',
      'Dulcosoft',
      'Noremifa',
      'Neovis Plus',
      'Cebion',
      'Pineal Notte',
      'NeoBianacid',
      'Sedivitax',
      'Psyllogel',
    ];
    const types = <ParafarmacoSectionType>[
      ParafarmacoSectionType.indications,
      ParafarmacoSectionType.usage,
      ParafarmacoSectionType.warnings,
      ParafarmacoSectionType.composition,
    ];
    const forbiddenAnywhere = <ParafarmacoSectionType, List<String>>{
      ParafarmacoSectionType.indications: [
        'valori medi',
        'caratteristiche nutrizionali',
        'scheda completa disponibile',
      ],
      ParafarmacoSectionType.usage: [
        'valori medi',
        'caratteristiche nutrizionali',
        'scheda completa disponibile',
      ],
      ParafarmacoSectionType.warnings: [
        'valori medi',
        'caratteristiche nutrizionali',
        'scheda completa disponibile',
      ],
      ParafarmacoSectionType.composition: ['scheda completa disponibile'],
    };
    const forbiddenHeadings = <ParafarmacoSectionType, List<String>>{
      ParafarmacoSectionType.indications: [
        'ingredienti',
        'componenti',
        'composizione',
        'modalita d uso',
        'avvertenze',
        'conservazione',
        'formato',
      ],
      ParafarmacoSectionType.usage: [
        'ingredienti',
        'componenti',
        'composizione',
        'avvertenze',
        'conservazione',
        'formato',
      ],
      ParafarmacoSectionType.warnings: [
        'ingredienti',
        'composizione',
        'modalita d uso',
        'conservazione',
        'formato',
      ],
      ParafarmacoSectionType.composition: [
        'modalita d uso',
        'avvertenze',
        'conservazione',
        'formato',
        'valori medi',
        'caratteristiche nutrizionali',
      ],
    };

    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp('[àá]'), 'a')
        .replaceAll(RegExp('[èé]'), 'e')
        .replaceAll(RegExp('[ìí]'), 'i')
        .replaceAll(RegExp('[òó]'), 'o')
        .replaceAll(RegExp('[ùú]'), 'u')
        .replaceAll(RegExp('[’\']'), ' ');

    var found = 0;
    var opened = 0;
    var checkedSections = 0;
    var directSections = 0;
    var unavailableSections = 0;
    final failures = <String>[];
    final unavailable = <String>[];
    final previews = <String>[];

    for (final query in queries) {
      try {
        List<ParafarmacoSearchResult> products = const [];
        for (var attempt = 0; attempt < 2 && products.isEmpty; attempt++) {
          final results = await service.searchProducts(query);
          products = results
              .where(
                (result) =>
                    result.sourceName == 'Codifa/Farmadati' &&
                    !service.isMedicationResult(result) &&
                    result.sourceUrl.contains('handler=Detail'),
              )
              .toList();
        }
        if (products.isEmpty) {
          failures.add('$query: non trovato');
          continue;
        }
        found++;
        final detail = await service.loadDetail(products.first);
        opened++;

        for (final type in types) {
          final direct = detail.sections[type]?.trim() ?? '';
          final displayed = detail.sectionText(type).trim();
          final normalizedDisplayed = normalize(displayed);

          if (direct.length < 40) {
            final dumpsCompleteSheet =
                normalizedDisplayed.contains('scheda completa disponibile') ||
                (displayed.length > 200 &&
                    displayed.contains(detail.fullText.trim()));
            if (!displayed.contains('non è disponibile') ||
                dumpsCompleteSheet) {
              failures.add(
                '$query/${type.name}: fallback contaminato: ${displayed.substring(0, displayed.length < 160 ? displayed.length : 160)}',
              );
              continue;
            }
            unavailable.add('$query/${type.name}');
            unavailableSections++;
            checkedSections++;
            continue;
          }

          if (displayed != direct) {
            failures.add('$query/${type.name}: testo mostrato alterato');
            continue;
          }

          final anywhereHits = forbiddenAnywhere[type]!.where(
            (needle) => normalizedDisplayed.contains(needle),
          );
          if (anywhereHits.isNotEmpty) {
            failures.add(
              '$query/${type.name}: contiene ${anywhereHits.join(', ')}: ${displayed.substring(0, displayed.length < 160 ? displayed.length : 160)}',
            );
            continue;
          }

          final headingHits = forbiddenHeadings[type]!.where((label) {
            return displayed
                .split('\n')
                .map(normalize)
                .any((line) => line == label || line.startsWith('$label '));
          });
          if (headingHits.isNotEmpty) {
            failures.add(
              '$query/${type.name}: mescola intestazioni ${headingHits.join(', ')}: ${displayed.substring(0, displayed.length < 160 ? displayed.length : 160)}',
            );
            continue;
          }

          if (type == ParafarmacoSectionType.indications) {
            final composition =
                detail.sections[ParafarmacoSectionType.composition];
            if (composition != null &&
                composition.trim().length >= 40 &&
                normalize(direct) == normalize(composition)) {
              failures.add('$query/indications: identica alla composizione');
              continue;
            }
            previews.add(
              '$query: ${direct.substring(0, direct.length < 90 ? direct.length : 90)}',
            );
          }

          directSections++;
          checkedSections++;
        }
      } catch (error) {
        failures.add('$query: $error');
      }
    }
    client.close();

    print(
      'SEMANTIC40 found=$found opened=$opened checked=$checkedSections/160 '
      'direct=$directSections unavailable=$unavailableSections failures=${failures.length}',
    );
    for (final preview in previews) {
      print('SEMANTIC40 INDICATIONS $preview');
    }
    for (final item in unavailable) {
      print('SEMANTIC40 UNAVAILABLE $item');
    }
    for (final failure in failures) {
      print('SEMANTIC40 FAILURE $failure');
    }

    expect(found, 40, reason: failures.join('\n'));
    expect(opened, 40, reason: failures.join('\n'));
    expect(checkedSections, 160, reason: failures.join('\n'));
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
