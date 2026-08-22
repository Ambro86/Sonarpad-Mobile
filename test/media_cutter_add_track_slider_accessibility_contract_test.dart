import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('added-track volume sliders use native adjustable UIKit sliders', () {
    final source = File(
      'lib/screens/media_cutter_add_track_screen.dart',
    ).readAsStringSync();

    for (final id in <String>['original_volume', 'new_track_volume']) {
      final start = source.indexOf("id: '$id'");
      expect(start, greaterThanOrEqualTo(0), reason: '$id row must exist');
      final end = source.indexOf('AccessibleListRow(', start + 1);
      final block = source.substring(
        start,
        end >= 0 ? end : source.length,
      );
      expect(block, contains("kind: 'slider'"));
      expect(block, contains('nativeSliderAccessibilityElement: true'));
      expect(block, contains('valueLabel: _percentValue('));
      expect(block, contains('sliderIncreasedValueLabel:'));
      expect(block, contains('sliderDecreasedValueLabel:'));
    }
  });
}
