import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('news article return uses the route-return focus handoff', () {
    final source = File('lib/screens/news_screen.dart').readAsStringSync();

    expect(
      source,
      contains('mode: AccessibleFocusMode.routeReturnJump'),
      reason: 'Returning from an article must use the same robust route-return '
          'focus path used by letter/date jumps.',
    );
    expect(
      source,
      contains('suppressBackSemanticsDuringRouteReturn'),
      reason: 'The Back button must be temporarily removed from accessibility '
          'while VoiceOver is handed to the target article.',
    );
    expect(source, contains('valueListenable: _suppressBackSemantics'));
    expect(source, contains('excluding: suppress'));
    expect(
      source,
      contains('_handleArticleAccessibilityFocus(article.id)'),
      reason: 'Back semantics must be restored only after the target row '
          'actually receives accessibility focus.',
    );
    expect(source, contains('routeReturnSemanticsSettleDelay: Duration.zero'));
    expect(source, contains('routeReturnUseFocusProxy: false'));
    expect(source, contains('routeReturnWaitForForeignFocusClear: true'));
  });

  test('news screen stays renderer neutral', () {
    final source = File('lib/screens/news_screen.dart').readAsStringSync();
    const forbidden = [
      'useNativeIosAccessibleViews',
      'NativeIosAccessibleList(',
      'NativeIosListRow(',
      "native_ios_accessible_view.dart",
    ];
    for (final token in forbidden) {
      expect(source, isNot(contains(token)), reason: 'Forbidden token: $token');
    }
  });
}
