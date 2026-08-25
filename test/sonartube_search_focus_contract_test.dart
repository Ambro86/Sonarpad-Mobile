import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube search focuses the first result renderer-neutrally', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('FocusScope.of(context).unfocus();'));
    expect(source, contains('shouldFocusFirstResult = result.items.isNotEmpty;'));
    expect(source, contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(
      source,
      contains("await _accessibleListController.focusTo('item_0', animated: false);"),
    );
  });

  test('SonarTube search does not focus a result when none exists', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(
      source,
      contains('!shouldFocusFirstResult || !useSharedAccessibleViewModel'),
    );
  });
}
