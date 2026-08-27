import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native accessible scroll views hide both indicators while VoiceOver runs',
    () {
      final native = File(
        'ios/Runner/SonarpadNativeAccessibleView.swift',
      ).readAsStringSync();

      // SonarTube channels, podcasts and the other shared accessible lists use
      // the same native UITableView. Sighted users keep the indicators requested
      // by the screen; VoiceOver users must not encounter scrollbar stops.
      expect(
        native,
        contains('tableView.showsHorizontalScrollIndicator = !voiceOverRunning'),
      );
      expect(
        native,
        contains(
          'tableView.showsVerticalScrollIndicator = '
          'requestedVerticalScrollIndicator && !voiceOverRunning',
        ),
      );

      // Pickers and grids follow the same VoiceOver-only policy.
      expect(
        RegExp(
          r'tableView\.showsVerticalScrollIndicator = !voiceOverRunning',
        ).allMatches(native).length,
        greaterThanOrEqualTo(1),
      );
      expect(
        native,
        contains(
          'collectionView.showsHorizontalScrollIndicator = !voiceOverRunning',
        ),
      );
      expect(
        native,
        contains(
          'collectionView.showsVerticalScrollIndicator = !voiceOverRunning',
        ),
      );

      // Keep the state live if VoiceOver is enabled/disabled while Sonarpad is
      // already open instead of requiring the user to recreate the screen.
      expect(
        RegExp(
          'UIAccessibility\\.voiceOverStatusDidChangeNotification',
        ).allMatches(native).length,
        greaterThanOrEqualTo(3),
      );

      // Preserve per-screen sighted behavior: screens that already requested no
      // vertical indicator still remain indicator-free even without VoiceOver.
      expect(
        native,
        contains(
          'requestedVerticalScrollIndicator = '
          'map["showVerticalScrollIndicator"] as? Bool ?? true',
        ),
      );
    },
  );
}
