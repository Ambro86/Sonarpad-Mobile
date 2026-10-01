import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Romanian language is labelled Romena in Italian UI', () {
    final source = File('lib/l10n/localized_dynamic_labels.dart').readAsStringSync();
    expect(
      source,
      contains("'ro' => localeName.toLowerCase().startsWith('it') ? 'Romena' : 'Română'"),
    );
    expect(
      source,
      contains("'romanian' => localeName.toLowerCase().startsWith('it') ? 'Romena' : 'Română'"),
    );
  });
}
