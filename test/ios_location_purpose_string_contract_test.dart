import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS includes both location purpose strings required by App Store validation', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
    expect(plist, contains('<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>'));

    final workflow = File('.github/workflows/ios_testflight.yml').readAsStringSync();
    expect(workflow, contains('plist["NSLocationWhenInUseUsageDescription"]'));
    expect(workflow, contains('plist["NSLocationAlwaysAndWhenInUseUsageDescription"]'));
  });
}
