import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Media Cutter effect slider diagnostics trace UIKit, Dart bridge and focus', () {
    final swift = File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();
    final cutter = File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final universal = File('lib/widgets/universal_accessible_view.dart').readAsStringSync();

    expect(swift, contains('SLIDER_GESTURE source=adjustableCell'));
    expect(swift, contains('SLIDER_ADJUST_BEGIN'));
    expect(swift, contains('SLIDER_ADJUST_SYNC'));
    expect(swift, contains('SLIDER_DART_ACK source=accessibilityAdjust'));
    expect(swift, contains('SLIDER_FOCUS_AFTER'));
    expect(swift, contains('sliderFocusSnapshot'));
    expect(swift, contains('"media_cutter_effects"'));
    expect(swift, contains('"settings"'));

    expect(cutter, contains("debugTag: 'media_cutter_effects'"));
    expect(cutter, contains('effects slider dart begin id=volume'));
    expect(cutter, contains('effects slider dart end id=volume'));
    expect(cutter, contains('effects slider dart begin id=amount_'));

    expect(settings, contains("debugTag: 'settings'"));
    expect(settings, contains('Settings slider dart begin'));
    expect(universal, contains('DART_SLIDER_EVENT_RECEIVED'));
    expect(universal, contains('DART_SLIDER_EVENT_DISPATCHED'));
    expect(universal, contains('DART_WIDGET_UPDATE setDataPending=true'));
  });
}
