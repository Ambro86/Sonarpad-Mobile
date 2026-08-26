import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube search opens a clean shared-accessible results route without initial focus jump', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains("name: '/sonartube/search-results'"));
    expect(source, contains('searchQuery: query'));
    expect(source, contains('_buildSearchResultsAccessible(l10n)'));
    expect(source, contains('_buildSearchResultsMaterial(l10n)'));
    expect(
      source,
      isNot(
        contains(
          "await _accessibleListController.focusTo('item_0', animated: false);",
        ),
      ),
    );
    expect(source, isNot(contains('shouldFocusFirstResult')));
  });

  test('clean SonarTube search results keep Back outside the scrolling results', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final accessibleStart = source.indexOf(
      'Widget _buildSearchResultsAccessible(AppLocalizations l10n)',
    );
    final materialStart = source.indexOf(
      'Widget _buildSearchResultsMaterial(AppLocalizations l10n)',
      accessibleStart,
    );
    final buildStart = source.indexOf('\n  @override\n  Widget build(', materialStart);
    expect(accessibleStart, greaterThanOrEqualTo(0));
    expect(materialStart, greaterThan(accessibleStart));
    expect(buildStart, greaterThan(materialStart));

    final accessible = source.substring(accessibleStart, materialStart);
    final material = source.substring(materialStart, buildStart);

    expect(accessible, isNot(contains('persistentTopAction:')));
    expect(accessible, isNot(contains("id: 'persistent_back'")));
    expect(accessible, contains('l10n.searchResults'));
    expect(accessible, isNot(contains("id: 'back'")));
    expect(accessible, isNot(contains('sonartube_favorites_button')));
    expect(accessible, isNot(contains('sonartube_search_field')));
    expect(accessible, isNot(contains('sonartube_search_button')));

    expect(material, contains('appBar: AppBar('));
    expect(material, contains('leading: BackButton('));
    expect(material, contains("ValueKey('sonartube_search_results_back')"));
    expect(material, contains('l10n.searchResults'));
  });
}
