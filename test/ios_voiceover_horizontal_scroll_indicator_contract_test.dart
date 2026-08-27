import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native accessible scroll views hide horizontal indicators only while VoiceOver runs',
    () {
      final native = File(
        'ios/Runner/SonarpadNativeAccessibleView.swift',
      ).readAsStringSync();

      // SonarTube channels, podcasts and the other shared accessible lists use
      // the same native UITableView. Sighted users keep the normal indicator;
      // VoiceOver users do not get a separate horizontal-scrollbar stop.
      expect(
        native,
        contains(
          'tableView.showsHorizontalScrollIndicator = '
          '!UIAccessibility.isVoiceOverRunning',
        ),
      );

      // Apply the same rule to the shared grid renderer as well, so the policy
      // is global for the UIKit accessibility renderer rather than screen-specific.
      expect(
        native,
        contains(
          'collectionView.showsHorizontalScrollIndicator = '
          '!UIAccessibility.isVoiceOverRunning',
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

      // Do not globally remove the vertical indicator: individual screens can
      // still opt out with the existing showVerticalScrollIndicator contract.
      expect(
        native,
        contains(
          'tableView.showsVerticalScrollIndicator = '
          'map["showVerticalScrollIndicator"] as? Bool ?? true',
        ),
      );
    },
  );
}
