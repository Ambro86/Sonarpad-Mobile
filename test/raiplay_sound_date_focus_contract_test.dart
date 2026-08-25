import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RaiPlay Sound date return waits for dismissed UIKit focus before focusing item', () {
    final source = File('lib/screens/raiplaysound_screen.dart').readAsStringSync();

    expect(
      source,
      contains('mode: AccessibleFocusMode.routeReturnJump'),
    );
    expect(
      source,
      contains('routeReturnWaitForForeignFocusClear: true'),
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
