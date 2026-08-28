import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pharmacy home exposes the reliable AIFA A-Z drug catalog only', () {
    final source = File('lib/screens/aifa_search_screen.dart').readAsStringSync();

    expect(source, contains("id: 'drugs_az'"));
    expect(source, contains("title: 'Farmaci A-Z'"));
    expect(source, contains('PharmacyAlphabeticalKind.drugs'));
    expect(source, isNot(contains("id: 'parafarmaci_az'")));
    expect(source, isNot(contains("title: 'Parafarmaci A-Z'")));
  });

  test('A-Z catalog supports a letter picker and a clean letter-only screen', () {
    final source =
        File('lib/screens/pharmacy_alphabetical_screen.dart').readAsStringSync();

    expect(source, contains('LetterJumpOptionPickerScreen<String>'));
    expect(source, contains("id: 'select_letter'"));
    expect(source, contains('_PharmacyAlphabeticalLetterScreen'));
    expect(source, contains('browseDrugsByLetter'));
    expect(source, contains('initial != null && initial.isNotEmpty'));
  });

  test('alphabetical drug catalog uses daily official AIFA registry', () {
    final aifa = File('lib/services/aifa_service.dart').readAsStringSync();
    final products =
        File('lib/services/parafarmaco_service.dart').readAsStringSync();

    expect(
      aifa,
      contains('https://drive.aifa.gov.it/farmaci/confezioni_fornitura.csv'),
    );
    expect(aifa, contains('anagrafica_farmaci_aifa.csv'));
    expect(aifa, contains('Duration(hours: 24)'));
    expect(products, contains('AifaService().browseDrugNamesByLetter'));
  });

  test('alphabetical drug selection returns to official AIFA results only', () {
    final source =
        File('lib/screens/pharmacy_alphabetical_screen.dart').readAsStringSync();
    final results =
        File('lib/screens/aifa_search_results_screen.dart').readAsStringSync();

    expect(source, contains('aifaOnly: true'));
    expect(source, contains('saveRecentSearch: false'));
    expect(results, contains('if (widget.aifaOnly)'));
  });

  test('Farmaci A-Z is available in both UIKit and pure Flutter renderers', () {
    final home = File('lib/screens/aifa_search_screen.dart').readAsStringSync();
    final catalog =
        File('lib/screens/pharmacy_alphabetical_screen.dart').readAsStringSync();

    expect(home, contains('useSharedAccessibleViewModel'));
    expect(home, contains('UniversalAccessibleList('));
    expect(home, contains('FilledButton.tonalIcon('));
    expect(
      RegExp(r"title: 'Farmaci A-Z'").allMatches(home).length,
      greaterThanOrEqualTo(1),
    );
    expect(
      RegExp(r"label: const Text\('Farmaci A-Z'\)").hasMatch(home),
      isTrue,
    );

    expect(catalog, contains('Widget _buildSharedAccessibleList('));
    expect(catalog, contains('Widget _buildFlutterList('));
    expect(catalog, contains('UniversalAccessibleList('));
    expect(catalog, contains('ListView.separated('));
    expect(
      RegExp(r'useSharedAccessibleViewModel').allMatches(catalog).length,
      greaterThanOrEqualTo(2),
    );
  });
}
