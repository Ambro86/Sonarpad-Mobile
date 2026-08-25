import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RaiPlay Sound date return keeps the existing renderer and focuses in place', () {
    final source = File('lib/screens/raiplaysound_screen.dart').readAsStringSync();

    expect(
      source,
      contains('_waitForDateSelectorReturnToSettle()'),
    );
    expect(
      source,
      contains("_accessibleListController.focusTo(\n        'item_\$itemIndex',"),
    );
    expect(
      source,
      isNot(contains('mode: AccessibleFocusMode.routeReturnJump')),
    );
    expect(
      source,
      contains('routeReturnWaitForForeignFocusClear: false'),
    );
    expect(
      source,
      contains('routeReturnSemanticsSettleDelay: Duration.zero'),
    );
    expect(
      source,
      contains('routeReturnUseFocusProxy: false'),
    );
  });
}
