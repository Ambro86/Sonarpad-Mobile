import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('letter navigation opens a clean filtered Material screen instead of jumping', () {
    final source = File(
      'lib/widgets/letter_jump_option_picker_screen.dart',
    ).readAsStringSync();

    expect(source, contains('class _LetterFilteredOptionsScreen<T>'));
    expect(source, contains('optionsForLetter: _optionsForLetter'));
    expect(source, contains('final options = optionsForLetter(letter);'));
    expect(source, contains('itemCount: options.length + 2'));
    expect(source, contains('ElevatedButton.icon('));
    expect(source, contains('header: true'));
    expect(source, isNot(contains('focusAccessibleRow(')));
    expect(source, isNot(contains('routeReturnJump')));
    expect(source, isNot(contains('scrollToIndex(')));
  });

  test('letter chooser uses the shared accessible model for the complete A-Z list', () {
    final source = File(
      'lib/widgets/letter_jump_option_picker_screen.dart',
    ).readAsStringSync();

    expect(source, contains("id: 'letter_\$index'"));
    expect(source, contains('for (var index = 0; index < letters.length; index++)'));
    expect(source, contains('UniversalAccessibleList('));
    expect(source, isNot(contains('SingleChildScrollView(')));
  });

  test('Podcast country source contains countries well after N', () {
    final source = File('lib/services/podcast_service.dart').readAsStringSync();

    expect(source, contains("PodcastCountry('us', 'Stati Uniti')"));
    expect(source, contains("PodcastCountry('ve', 'Venezuela')"));
    expect(source, contains("PodcastCountry('zw', 'Zimbabwe')"));
  });
}
