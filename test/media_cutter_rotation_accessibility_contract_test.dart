import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media cutter rotation picker exposes the localized current value', () {
    final screen = File(
      'lib/screens/media_cutter_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('value: _videoRotation.name'));
    expect(
      screen,
      contains('valueLabel: _videoRotationLabel(l10n, _videoRotation)'),
    );
    expect(
      screen,
      contains('subtitle: _videoRotationLabel(l10n, _videoRotation)'),
    );
    expect(
      screen,
      contains('accessibilityLabel: l10n.mediaCutterVideoRotation'),
    );
  });
}
