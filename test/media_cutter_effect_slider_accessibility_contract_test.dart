import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Media Cutter effect sliders use the same cell-based UIKit semantics as Settings', () {
    final source = File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final native = File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    final volumeStart = source.indexOf("id: 'volume'");
    final volumeEnd = source.indexOf("id: 'effect_\$slot'", volumeStart);
    final volumeBlock = source.substring(volumeStart, volumeEnd);
    expect(volumeBlock, contains("kind: 'slider'"));
    expect(volumeBlock, contains('valueLabel: \'\$volumePercent%\''));
    expect(volumeBlock, contains('sliderStep: 10'));
    expect(volumeBlock, isNot(contains('nativeSliderAccessibilityElement: true')));

    final amountStart = source.indexOf("id: 'amount_\$slot'");
    final amountEnd = source.indexOf("id: 'preview'", amountStart);
    final amountBlock = source.substring(amountStart, amountEnd);
    expect(amountBlock, contains("kind: 'slider'"));
    expect(amountBlock, contains('sliderStep: 10'));
    expect(amountBlock, isNot(contains('nativeSliderAccessibilityElement: true')));

    // The known-good Voice Speed slider in Settings also uses the default
    // cell-based adjustable element, rather than exposing the accessory UISlider.
    final speedStart = settings.indexOf("id: 'tts_speed'");
    final speedEnd = settings.indexOf("id: 'tts_pitch'", speedStart);
    final speedBlock = settings.substring(speedStart, speedEnd);
    expect(speedBlock, contains("kind: 'slider'"));
    expect(speedBlock, isNot(contains('nativeSliderAccessibilityElement: true')));

    // UIKit must keep one accessibility element (the table cell), update its
    // value synchronously, and avoid a row reload during adjustable gestures.
    expect(native, contains('cell.isAccessibilityElement = !exposeNativeSlider'));
    expect(native, contains('cell.accessibilityValue = spokenValue'));
    expect(native, contains('channel.invokeMethod("event", arguments: ["type": "slider"'));
    final adjustStart = native.indexOf('private func adjustSlider(at indexPath: IndexPath');
    final adjustEnd = native.indexOf('private func formatSliderValue', adjustStart);
    final adjustBlock = native.substring(adjustStart, adjustEnd);
    expect(adjustBlock, isNot(contains('reloadRows')));
    expect(adjustBlock, isNot(contains('layoutChanged')));

    // The effect dialog must not rebuild the native PlatformView while
    // VoiceOver is inside accessibilityIncrement/accessibilityDecrement.
    // UIKit has already updated the focused cell synchronously; rebuilding the
    // dialog here is what made focus escape before the new value was spoken.
    final eventStart = source.indexOf('onEvent: (event) async {', volumeStart);
    final previewStart = source.indexOf("if (event.id == 'preview'", eventStart);
    final sliderEventBlock = source.substring(eventStart, previewStart);
    expect(sliderEventBlock, contains('if (useNativeIosAccessibleViews)'));
    expect(sliderEventBlock, contains('volumePercent = next;'));
    expect(sliderEventBlock, contains('amountPercent: nextAmount'));
    expect(
      sliderEventBlock,
      contains('setDialogState(() => volumePercent = next);'),
    );
  });
}
