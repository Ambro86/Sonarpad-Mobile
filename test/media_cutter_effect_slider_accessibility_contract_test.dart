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
    final adjustStart = native.indexOf('private func adjustSlider(at indexPath: IndexPath');
    final adjustEnd = native.indexOf('private func formatSliderValue', adjustStart);
    final adjustBlock = native.substring(adjustStart, adjustEnd);
    expect(adjustBlock, contains('channel.invokeMethod('));
    expect(adjustBlock, contains('"event",'));
    expect(
      adjustBlock,
      contains('arguments: ["type": "slider", "id": row.id, "value": row.sliderValue]'),
    );
    expect(adjustBlock, contains('SLIDER_DART_ACK source=accessibilityAdjust'));
    expect(adjustBlock, isNot(contains('reloadRows')));
    expect(adjustBlock, contains('recoverAdjustedSliderFocusIfNeeded'));
    expect(native, contains('SLIDER_FOCUS_RECOVERY'));
    expect(adjustBlock, contains('liveSliderSpokenValue'));

    // The effects dialog is non-dismissible from the modal barrier so the
    // Flutter "Dismiss" semantics node cannot steal VoiceOver focus during an
    // adjustable gesture. Dart still rebuilds the StatefulBuilder, but the
    // UniversalAccessibleList state survives and same-structure setData updates
    // the existing native cell in place, exactly like Settings.
    final dialogStart = source.indexOf('final result = await showDialog<_PartEffectSettings>');
    final dialogBuilderStart = source.indexOf('builder:', dialogStart);
    final dialogRouteBlock = source.substring(dialogStart, dialogBuilderStart);
    expect(dialogRouteBlock, contains('barrierDismissible: false'));
    final eventStart = source.indexOf('onEvent: (event) async {', volumeStart);
    final previewStart = source.indexOf("if (event.id == 'preview'", eventStart);
    final sliderEventBlock = source.substring(eventStart, previewStart);
    expect(sliderEventBlock, contains('setDialogState(() => volumePercent = next);'));
    expect(sliderEventBlock, contains('amountPercent: nextAmount'));
    expect(
      sliderEventBlock,
      isNot(contains('if (preserveAccessibleSliderFocusDuringValueChange) {')),
    );

    final adapter = File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final receivedLogStart = adapter.indexOf("if (event.type == 'slider') {");
    final dispatchStart = adapter.indexOf('await _dispatch(event);', receivedLogStart);
    final receivedLogBlock = adapter.substring(receivedLogStart, dispatchStart);
    expect(receivedLogBlock, contains('unawaited(AppLogger.log('));
    expect(receivedLogBlock, contains('DART_SLIDER_EVENT_RECEIVED'));


  });
}
