import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('added-track volume sliders match the Settings cell-based UIKit slider model', () {
    final source = File('lib/screens/media_cutter_add_track_screen.dart').readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    for (final id in ['original_volume', 'new_track_volume']) {
      final start = source.indexOf("id: '$id'");
      expect(start, greaterThanOrEqualTo(0));
      final nextRow = source.indexOf('AccessibleListRow(', start + 20);
      final block = source.substring(start, nextRow < 0 ? source.length : nextRow);
      expect(block, contains("kind: 'slider'"));
      expect(block, contains('valueLabel:'));
      expect(block, isNot(contains('nativeSliderAccessibilityElement: true')));
    }

    final speedStart = settings.indexOf("id: 'tts_speed'");
    final speedEnd = settings.indexOf("id: 'tts_pitch'", speedStart);
    final speedBlock = settings.substring(speedStart, speedEnd);
    expect(speedBlock, isNot(contains('nativeSliderAccessibilityElement: true')));
  });
}
