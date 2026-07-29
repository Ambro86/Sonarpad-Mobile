import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 55 experimental effects have a curated destination', () {
    final raw = File('MIGRAZIONE_EFFETTI_DSP.json').readAsStringSync();
    final migration = (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
    expect(migration, hasLength(55));
    expect(migration.keys.toSet(), hasLength(55));
    expect(migration.values, everyElement(isNotEmpty));

    final cutter = File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    for (final target in migration.values.toSet()) {
      expect(
        cutter,
        contains('_MediaPartEffect.$target'),
        reason: 'Missing curated effect target: $target',
      );
    }
  });
}
