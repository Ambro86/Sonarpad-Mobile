import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weather search exposes a separate clear button with stable focus', () {
    final source = File('lib/screens/weather_screen.dart').readAsStringSync();

    expect(source, contains('final _searchFocusNode = FocusNode();'));
    expect(source, contains("debugLabel: 'weather_search_focus_target'"));
    expect(
      source,
      contains('ValueListenableBuilder<TextEditingValue>('),
    );
    expect(
      source,
      contains('if (value.text.isEmpty) return const SizedBox.shrink();'),
    );
    expect(source, contains('tooltip: l10n.clearSearch'));
    expect(source, contains('onPressed: _clearSearchText'));
    expect(source, contains('explicitChildNodes: true'));
    expect(source, contains('sortKey: const OrdinalSortKey(1)'));
    expect(source, contains('sortKey: const OrdinalSortKey(2)'));
    expect(source, contains('sortKey: const OrdinalSortKey(3)'));
    expect(source, contains('_searchCtrl.clear();'));
    expect(source, contains('_searchFocusNode.requestFocus();'));
    expect(
      source,
      contains('sendSemanticsEvent(const FocusSemanticEvent())'),
    );

    final fieldSortIndex = source.indexOf('sortKey: const OrdinalSortKey(1)');
    final clearSortIndex = source.indexOf('sortKey: const OrdinalSortKey(2)');
    final searchSortIndex = source.indexOf('sortKey: const OrdinalSortKey(3)');
    expect(fieldSortIndex, greaterThanOrEqualTo(0));
    expect(clearSortIndex, greaterThan(fieldSortIndex));
    expect(searchSortIndex, greaterThan(clearSortIndex));

    final fieldIndex = source.indexOf('child: TextField(');
    final clearIndex = source.indexOf('tooltip: l10n.clearSearch');
    final searchButtonIndex = source.indexOf(
      'child: Text(l10n.search)',
      clearIndex,
    );
    expect(fieldIndex, greaterThanOrEqualTo(0));
    expect(clearIndex, greaterThan(fieldIndex));
    expect(searchButtonIndex, greaterThan(clearIndex));

    final searchRowSource = source.substring(fieldIndex, searchButtonIndex);
    expect(
      searchRowSource,
      isNot(contains('suffixIcon:')),
      reason: 'The clear action must stay a separate VoiceOver sibling.',
    );
  });
}
