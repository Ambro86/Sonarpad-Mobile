import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all clear-search implementations keep clear after the editable field', () {
    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();
    final shared = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();
    final weather = File('lib/screens/weather_screen.dart').readAsStringSync();
    final sonarTube =
        File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final dropbox =
        File('lib/screens/dropbox_browser_screen.dart').readAsStringSync();

    expect(
      native,
      contains(
        'clearButton.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 8)',
      ),
    );
    expect(native, contains('[field as Any, clearButton as Any]'));
    expect(native, isNot(contains('field.rightView = clearButton')));

    expect(shared, contains('explicitChildNodes: true'));
    expect(shared, contains('sortKey: const OrdinalSortKey(1)'));
    expect(shared, contains('sortKey: const OrdinalSortKey(2)'));
    expect(shared, contains('_clearFlutterTextField(row, controller)'));

    for (final source in [weather, sonarTube, dropbox]) {
      expect(source, contains('sortKey: const OrdinalSortKey(1)'));
      expect(source, contains('sortKey: const OrdinalSortKey(2)'));
      expect(source, contains('tooltip: l10n.clearSearch'));
    }

    expect(
      sonarTube,
      isNot(contains('suffixIcon: ValueListenableBuilder<TextEditingValue>(')),
    );
    expect(dropbox, isNot(contains('suffixIcon: _searchQuery.isEmpty')));
  });
}
