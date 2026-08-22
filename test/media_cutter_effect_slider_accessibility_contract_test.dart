import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Media Cutter effect sliders use native adjustable VoiceOver controls', () {
    final cutter = File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    final shared = File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final native = File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    final volumeStart = cutter.indexOf("id: 'volume'");
    expect(volumeStart, greaterThanOrEqualTo(0));
    final volumeBlock = cutter.substring(volumeStart, volumeStart + 900);
    expect(volumeBlock, contains("kind: 'slider'"));
    expect(volumeBlock, contains('sliderStep: 10'));
    expect(volumeBlock, contains('nativeSliderAccessibilityElement: true'));
    expect(volumeBlock, contains("valueLabel: '\$volumePercent%'"));

    final amountStart = cutter.indexOf("id: 'amount_\$slot'");
    expect(amountStart, greaterThanOrEqualTo(0));
    final amountBlock = cutter.substring(amountStart, amountStart + 1100);
    expect(amountBlock, contains("kind: 'slider'"));
    expect(amountBlock, contains('sliderStep: 10'));
    expect(amountBlock, contains('nativeSliderAccessibilityElement: true'));
    expect(amountBlock, contains('amountPercent}%'));

    expect(shared, contains('nativeSliderAccessibilityElement'));
    expect(shared, contains("slider: true"));
    expect(shared, contains('onIncrease: enabled'));
    expect(shared, contains('onDecrease: enabled'));

    expect(native, contains('var nativeSliderAccessibilityElement: Bool'));
    expect(native, contains('let exposeNativeSlider = row.nativeSliderAccessibilityElement'));
    expect(native, contains('slider.isAccessibilityElement = exposeNativeSlider'));
    expect(native, contains('cell.isAccessibilityElement = !exposeNativeSlider'));
    expect(native, contains('slider.accessibilityTraits = row.enabled ? [.adjustable]'));
    expect(native, contains('slider.incrementHandler = row.enabled'));
    expect(native, contains('slider.decrementHandler = row.enabled'));
    expect(native, contains('slider.accessibilityValue = spokenValue'));
  });
}
