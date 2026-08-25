import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube exposes initial search prompt only through the text field', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(
      source,
      contains('placeholder: l10n.sonarTubeSearchPrompt'),
      reason: 'The search field must keep the prompt as its placeholder.',
    );
    expect(
      source,
      contains("if (!_loading && _items.isEmpty && (_query != null || _isCollection))"),
      reason: 'The empty-result row must not exist before the first search.',
    );
    expect(
      source,
      isNot(contains("title: _query == null && !_isCollection\n            ? l10n.sonarTubeSearchPrompt")),
      reason: 'VoiceOver must not encounter the initial search prompt as a second row.',
    );
  });
}
