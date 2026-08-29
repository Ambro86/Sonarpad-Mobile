import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared text fields expose contextual clear controls', () {
    final source = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();

    expect(source, contains('final bool clearAsSearch;'));
    expect(
      source,
      contains("clearAsSearch || textInputAction == 'search'"),
    );
    expect(source, contains("'clearTextLabel': l10n.clearText"));
    expect(source, contains("'clearSearchLabel': l10n.clearSearch"));
    expect(source, contains('tooltip: clearLabel'));
    expect(source, contains('controller.clear();'));
    expect(source, contains("_change(row, 'textChanged', '');"));
  });

  test('UIKit clear button is Apple-style and keeps Dart text synchronized', () {
    final source = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(source, contains('private let clearButton = UIButton(type: .system)'));
    expect(source, contains('UIImage(systemName: "xmark.circle.fill")'));
    expect(source, contains('clearButton.accessibilityLabel = label'));
    expect(source, contains('field.sendActions(for: .editingChanged)'));
    expect(
      'cell.configureClearButton(label: row.clearAsSearch ? clearSearchLabel : clearTextLabel)'
          .allMatches(source)
          .length,
      2,
    );
  });

  test('clear-text accessibility label is localized in every ARB locale', () {
    final l10nDir = Directory('lib/l10n');
    final arbFiles = l10nDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'));

    for (final file in arbFiles) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(
        json['clearText'],
        isA<String>().having((value) => value.trim(), 'value', isNotEmpty),
        reason: '${file.path} must localize clearText.',
      );
    }
  });

  test('Dropbox does not keep a duplicate shared clear-search row', () {
    final source =
        File('lib/screens/dropbox_browser_screen.dart').readAsStringSync();
    expect(source, contains('clearAsSearch: true'));
    expect(source, isNot(contains("id: 'clear_search'")));
    expect(source, contains('tooltip: l10n.clearSearch'));
  });
}
