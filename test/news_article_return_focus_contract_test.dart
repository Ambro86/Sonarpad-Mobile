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
      reason: 'Back may still be excluded while the article route itself is '
          'closing so VoiceOver does not steal the initial return focus.',
    );
    expect(source, contains('valueListenable: _suppressBackSemantics'));
    expect(source, contains('excluding: suppress'));

    final pushIndex = source.indexOf('await navigator.push(');
    final restoreIndex = source.indexOf(
      'widget.suppressBackSemantics.value = false;',
      pushIndex,
    );
    final reloadIndex = source.indexOf('await _loadReadArticles();', pushIndex);
    expect(pushIndex, greaterThanOrEqualTo(0));
    expect(restoreIndex, greaterThan(pushIndex));
    expect(reloadIndex, greaterThan(restoreIndex));
    expect(
      source,
      isNot(contains('Future<void>.delayed(const Duration(seconds: 3)')),
      reason: 'Back must not stay hidden while the native focus handoff retries.',
    );
    expect(
      source,
      contains('_handleArticleAccessibilityFocus(article.id)'),
      reason: 'The article focus handoff still needs its accessibility callback.',
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
