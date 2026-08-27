import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('radio results restore focus to the station after returning from player', () {
    final source =
        File('lib/screens/radio_search_results_screen.dart').readAsStringSync();

    expect(
      source,
      contains('await _restoreResultFocusAfterPlayer(station);'),
      reason: 'Both normal playback and play-and-record must restore the '
          'result-row focus after the player route closes.',
    );
    expect(
      RegExp(r'await _restoreResultFocusAfterPlayer\(station\);')
          .allMatches(source)
          .length,
      2,
    );
    expect(
      source,
      contains('_resultsAccessibleListController.focusAccessibleRow('),
    );
    expect(source, contains('station.streamUrl'));
    expect(
      source,
      contains('mode: AccessibleFocusMode.routeReturnJump'),
      reason: 'The result list must use the robust route-return handoff so '
          'the page selector cannot steal VoiceOver focus.',
    );
    expect(source, contains('await WidgetsBinding.instance.endOfFrame;'));
  });

  test('radio return-focus stays renderer neutral', () {
    final source =
        File('lib/screens/radio_search_results_screen.dart').readAsStringSync();
    const forbidden = [
      'useNativeIosAccessibleViews',
      'NativeIosAccessibleList(',
      'NativeIosListRow(',
      'native_ios_accessible_view.dart',
    ];
    for (final token in forbidden) {
      expect(source, isNot(contains(token)), reason: 'Forbidden token: $token');
    }
  });
}
