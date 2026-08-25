import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube load more focuses the first appended row renderer-neutrally', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('final firstAppendedIndex = _items.length;'));
    expect(source, contains('shouldFocusFirstAppendedItem = true;'));
    expect(source, contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(
      source,
      contains("_accessibleListController.focusTo(\n      'item_\$firstAppendedIndex',"),
    );

    const forbiddenNativeScreenTokens = [
      'useNativeIosAccessibleViews',
      'NativeIosAccessibleList(',
      'NativeIosListRow(',
      "native_ios_accessible_view.dart",
    ];
    for (final token in forbiddenNativeScreenTokens) {
      expect(
        source,
        isNot(contains(token)),
        reason: 'SonarTube must leave Flutter/UIKit selection to the shared adapter.',
      );
    }
  });
  test('clean SonarTube search load more focuses the first appended result', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('_searchLoadMoreFocusIndex = firstAppendedIndex;'));
    expect(source, contains('_focusFirstAppendedSearchResult(firstAppendedIndex)'));
    expect(source, contains('Scrollable.ensureVisible('));
    expect(source, contains('sendSemanticsEvent(const FocusSemanticEvent())'));
    expect(source, contains("debugLabel: 'sonartube_search_load_more_target'"));
  });

}
