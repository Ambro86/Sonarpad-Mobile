import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  expect(start, greaterThanOrEqualTo(0), reason: 'Missing $startMarker');
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(end, greaterThan(start), reason: 'Missing $endMarker after $startMarker');
  return source.substring(start, end);
}

void main() {
  test('new clean SonarTube routes keep the shared renderer so iOS stays UIKit', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    final searchStart = source.indexOf(
      'Widget _buildSearchResultsAccessible(AppLocalizations l10n)',
    );
    final searchEnd = source.indexOf(
      'Widget _buildSearchResultsMaterial(AppLocalizations l10n)',
      searchStart,
    );
    expect(searchStart, greaterThanOrEqualTo(0));
    expect(searchEnd, greaterThan(searchStart));
    final search = source.substring(searchStart, searchEnd);
    expect(search, contains('UniversalAccessibleList('));

    final transcript = classBlock(
      source,
      'class _SonarTubeTranscriptScreenState',
      'class _SonarTubeCommentsScreen',
    );
    expect(transcript, contains('useSharedAccessibleViewModel'));
    expect(transcript, contains('UniversalAccessibleList('));

    final comments = classBlock(
      source,
      'class _SonarTubeCommentsScreenState',
      'class _SonarTubeFavoritesScreen',
    );
    expect(comments, contains('useSharedAccessibleViewModel'));
    expect(comments, contains('UniversalAccessibleList('));
  });

  test('date and letter filtered routes keep the shared renderer so iOS stays UIKit', () {
    final rai = File('lib/screens/raiplaysound_screen.dart').readAsStringSync();
    final dateStart = rai.indexOf('class _RaiPlaySoundDateItemsScreen');
    expect(dateStart, greaterThanOrEqualTo(0));
    final date = rai.substring(dateStart);
    expect(date, contains('useSharedAccessibleViewModel'));
    expect(date, contains('UniversalAccessibleList('));
    expect(date, contains("id: 'back'"));

    final letters = File(
      'lib/widgets/letter_jump_option_picker_screen.dart',
    ).readAsStringSync();
    final filtered = classBlock(
      letters,
      'class _LetterFilteredOptionsScreen<T>',
      'String? _initialLetter',
    );
    expect(filtered, contains('useSharedAccessibleViewModel'));
    expect(filtered, contains('UniversalAccessibleList('));
    expect(filtered, contains("id: 'back'"));
  });
}
