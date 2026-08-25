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

  test('clean SonarTube search results start with Back, omit search chrome, and keep UIKit on iOS', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final start = source.indexOf(
      'Widget _buildSearchResultsAccessible(AppLocalizations l10n)',
    );
    final end = source.indexOf('\n  @override\n  Widget build(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);

    final back = method.indexOf('sonartube_search_results_back');
    final title = method.indexOf('sonartube_search_results_title');
    expect(back, greaterThanOrEqualTo(0));
    expect(title, greaterThan(back));
    expect(method, contains('l10n.back'));
    expect(method, contains('l10n.searchResults'));
    expect(method, isNot(contains('sonartube_favorites_button')));
    expect(method, isNot(contains('sonartube_search_field')));
    expect(method, isNot(contains('sonartube_search_button')));
    expect(method, contains('UniversalAccessibleList('));
  });
}
