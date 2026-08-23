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
}
