import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared text fields expose clear after the field in semantic order', () {
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
    expect(source, contains('explicitChildNodes: true'));
    expect(source, contains('sortKey: const OrdinalSortKey(1)'));
    expect(source, contains('sortKey: const OrdinalSortKey(2)'));
    expect(source, contains('tooltip: clearLabel'));
    expect(source, contains('_clearFlutterTextField(row, controller)'));
    expect(source, contains("_change(row, 'textChanged', '');"));
    expect(source, contains('focusNode.requestFocus();'));
    expect(source, contains('sendSemanticsEvent(const FocusSemanticEvent())'));
  });

  test('UIKit clear button is a non-overlapping sibling after the field', () {
    final source = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(source, contains('private let clearButton = UIButton(type: .system)'));
    expect(source, contains('UIImage(systemName: "xmark.circle.fill")'));
    expect(source, contains('clearButton.accessibilityLabel = label'));
    expect(source, contains('isAccessibilityElement = false'));
    expect(source, contains('contentView.isAccessibilityElement = false'));
    expect(source, contains('field.isAccessibilityElement = true'));
    expect(source, contains('clearButton.isAccessibilityElement = true'));
    expect(source, contains('clearButton.accessibilityTraits = .button'));
    expect(source, contains('contentView.addSubview(clearButton)'));
    expect(
      source,
      contains(
        'clearButton.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 8)',
      ),
    );
    expect(source, isNot(contains('field.rightView = clearButton')));
    expect(source, isNot(contains('clearAccessibilityElement')));
    expect(source, contains('clearButton.isHidden = !hasText'));
    expect(source, contains('[field as Any, clearButton as Any]'));
    expect(source, contains('field.sendActions(for: .editingChanged)'));
    expect(
      source,
      contains('UIAccessibility.post(notification: .layoutChanged, argument: field)'),
    );
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

  test('SonarTube reuses a separate ordered clear-search field everywhere', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('Widget _buildSearchField(AppLocalizations l10n)'));
    expect(source, contains('explicitChildNodes: true'));
    expect(source, contains('sortKey: const OrdinalSortKey(1)'));
    expect(source, contains('sortKey: const OrdinalSortKey(2)'));
    expect(source, contains('tooltip: l10n.clearSearch'));
    expect(source, contains('onPressed: _clearSearchText'));
    expect(source, contains('sendSemanticsEvent(const FocusSemanticEvent())'));
    expect(
      '_buildSearchField(l10n)'.allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(source, isNot(contains('suffixIcon: ValueListenableBuilder<TextEditingValue>(')));
  });

  test('Dropbox keeps clear search after the field in both renderer paths', () {
    final source =
        File('lib/screens/dropbox_browser_screen.dart').readAsStringSync();
    expect(source, contains('clearAsSearch: true'));
    expect(source, isNot(contains("id: 'clear_search'")));
    expect(source, contains('tooltip: l10n.clearSearch'));
    expect(source, contains('explicitChildNodes: true'));
    expect(source, contains('sortKey: const OrdinalSortKey(1)'));
    expect(source, contains('sortKey: const OrdinalSortKey(2)'));
    expect(source, contains('_searchFocusNode.requestFocus();'));
    expect(source, isNot(contains('suffixIcon: _searchQuery.isEmpty')));
  });
}
