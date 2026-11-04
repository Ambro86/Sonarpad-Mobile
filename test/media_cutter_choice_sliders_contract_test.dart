import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Media Cutter uses discrete sliders for all selectable controls', () {
    final source = File(
      'lib/screens/media_cutter_screen.dart',
    ).readAsStringSync();
    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();
    final nativeTests = File(
      'ios/RunnerTests/RunnerTests.swift',
    ).readAsStringSync();

    // Native rows expose discrete slider events and localized options.
    for (final id in ['seek_step', 'rotation', 'save_scope', 'audio_video']) {
      expect(
        source,
        contains("id: '$id'"),
        reason: 'Missing native choice $id',
      );
      expect(source, contains("id: '$id',"), reason: 'Missing slider row $id');
    }
    // The Android/Flutter fallback has one stable semantics control per choice.
    for (final id in ['seek_step', 'rotation', 'save_scope', 'audio_video']) {
      expect(
        source,
        contains("id: '$id',"),
        reason: 'Missing fallback choice $id',
      );
    }
    expect(source, contains("id: 'effect_\$slot'"));
    expect(source, contains("id: 'amount_\$slot'"));
    expect(source, contains("id: 'effect_\$slotNumber'"));
    expect(source, contains('Widget _buildFlutterChoiceSlider('));
    expect(source, contains('slider: true'));
    expect(source, contains('onIncrease: enabled && index < last'));
    expect(source, isNot(contains('DropdownButtonFormField')));
    expect(source, isNot(contains('_showEffectPickerDialog')));
    expect(source, contains("transientRowIds: const ['export_image']"));

    // Only new/removed transient rows are inserted/deleted. Existing effect
    // sliders and their UIKit accessory objects stay alive and retain focus.
    expect(native, contains('let retainedOld = old.rows.filter'));
    expect(native, contains('let retainedNew = new.rows.filter'));
    expect(native, contains('if let updated = newById[row.id]'));
    expect(native, contains('if let previous = oldById[row.id]'));
    expect(
      nativeTests,
      contains('testMediaCutterEffectSlidersKeepIndependentCellsOnInsertion'),
    );
  });
}
