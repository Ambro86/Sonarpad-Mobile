import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android secondary actions survive TalkBack direct-touch long press', () {
    final renderer = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();

    expect(
      renderer,
      contains('final interactiveChild = isAndroidPlatform && row.actions.isNotEmpty'),
      reason:
          'Every Android shared row with secondary actions must intercept the '
          'real pointer long press used by TalkBack double-tap-and-hold.',
    );
    expect(renderer, contains('GestureDetector('));
    expect(renderer, contains('behavior: HitTestBehavior.translucent'));
    expect(renderer, contains('excludeFromSemantics: true'));
    expect(
      renderer,
      contains('onLongPress: () => unawaited(_showSecondaryActions(row))'),
    );
    expect(renderer, contains('child: interactiveChild'));
    expect(
      renderer,
      contains('customSemanticsActions: {'),
      reason:
          'The pointer fallback must supplement, not replace, TalkBack custom actions.',
    );
  });
}
