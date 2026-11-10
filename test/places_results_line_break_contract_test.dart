import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opening-hours results separate address and opening status', () {
    final source = File('lib/screens/orari_apertura_results_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(
      source,
      contains("if (_results[i].status.isNotEmpty) _results[i].status,\n                                ].join('\\n')"),
    );
    expect(source, contains('Text(result.address,'));
    expect(source, contains('Text(result.status,'));
  });

  test('places results separate metadata in both accessible and legacy layouts', () {
    final source = File('lib/screens/italiaonline_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(
      source,
      contains("if (_results[i].ratingText != null) _results[i].ratingText!,\n                  ].join('\\n')"),
    );
    expect(
      source,
      contains("if (r.ratingText != null) r.ratingText,\n        ].join('\\n')"),
    );
  });
}
