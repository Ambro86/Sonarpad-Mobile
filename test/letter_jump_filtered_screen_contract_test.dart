import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('letter navigation opens a clean filtered shared-accessible screen instead of jumping', () {
    final source = File(
      'lib/widgets/letter_jump_option_picker_screen.dart',
    ).readAsStringSync();

    expect(source, contains('class _LetterFilteredOptionsScreen<T>'));
    expect(source, contains('optionsForLetter: _optionsForLetter'));
    expect(source, contains('final options = optionsForLetter(letter);'));
    final start = source.indexOf('class _LetterFilteredOptionsScreen<T>');
    final filtered = source.substring(start, source.indexOf('String? _initialLetter', start));
    expect(filtered, contains('useSharedAccessibleViewModel'));
    expect(filtered, contains('UniversalAccessibleList('));
    expect(filtered, contains("id: 'back'"));
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
  test('letter picker can be disabled only by an explicit caller', () {
    final source = File(
      'lib/widgets/letter_jump_option_picker_screen.dart',
    ).readAsStringSync();

    expect(source, contains('this.enableLetterPicker = true'));
    expect(source, contains('widget.enableLetterPicker &&'));
  });

}
