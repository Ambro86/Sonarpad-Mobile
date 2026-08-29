import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('SonarTube labels video duration through localization', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(
      RegExp(r'l10n\.sourceDurationValue\(item\.duration!\)').allMatches(source).length,
      greaterThanOrEqualTo(2),
      reason: 'Both the main SonarTube list and recent videos must label duration.',
    );
  });

  test('every locale provides the localized duration label', () {
    final localeFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_[^/\\]+\.arb$').hasMatch(file.path))
        .toList();

    expect(localeFiles, isNotEmpty);
    for (final file in localeFiles) {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(
        data['sourceDurationValue'],
        isA<String>().having((value) => value, 'value', contains('{duration}')),
        reason: '${file.path} must localize the SonarTube duration label.',
      );
    }
  });
}
