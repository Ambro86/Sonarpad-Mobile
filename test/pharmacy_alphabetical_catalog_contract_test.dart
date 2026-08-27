import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pharmacy home exposes separate A-Z drug and parafarmaco catalogs', () {
    final source = File('lib/screens/aifa_search_screen.dart').readAsStringSync();

    expect(source, contains("id: 'drugs_az'"));
    expect(source, contains("title: 'Farmaci A-Z'"));
    expect(source, contains("id: 'parafarmaci_az'"));
    expect(source, contains("title: 'Parafarmaci A-Z'"));
    expect(source, contains('PharmacyAlphabeticalKind.drugs'));
    expect(source, contains('PharmacyAlphabeticalKind.parafarmaci'));
  });

  test('A-Z catalog supports a letter picker and a clean letter-only screen', () {
    final source =
        File('lib/screens/pharmacy_alphabetical_screen.dart').readAsStringSync();

    expect(source, contains('LetterJumpOptionPickerScreen<String>'));
    expect(source, contains("id: 'select_letter'"));
    expect(source, contains('_PharmacyAlphabeticalLetterScreen'));
    expect(source, contains('browseDrugsByLetter'));
    expect(source, contains('browseParafarmaciByLetter'));
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

  test('pharmacy A-Z is available in both UIKit and pure Flutter renderers', () {
    final home = File('lib/screens/aifa_search_screen.dart').readAsStringSync();
    final catalog =
        File('lib/screens/pharmacy_alphabetical_screen.dart').readAsStringSync();

    // Home: UIKit/native path uses the shared accessible model; Flutter path
    // exposes the same two actions as real Material buttons.
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
    expect(
      RegExp(r"title: 'Parafarmaci A-Z'").allMatches(home).length,
      greaterThanOrEqualTo(1),
    );
    expect(
      RegExp(r"label: const Text\('Parafarmaci A-Z'\)").hasMatch(home),
      isTrue,
    );

    // Catalog and clean letter-only screen: both have native/UIKit and
    // Flutter list builders selected by the same renderer switch.
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
