import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RaiPlay Sound date selection opens a filtered shared-accessible list without jumping', () {
    final source = File('lib/screens/raiplaysound_screen.dart').readAsStringSync();

    expect(
      source,
      contains("settings: const RouteSettings(name: '/raiplaysound/date')"),
    );
    expect(source, contains('class _RaiPlaySoundDateItemsScreen'));
    final start = source.indexOf('class _RaiPlaySoundDateItemsScreen');
    final dateScreen = source.substring(start);
    expect(dateScreen, contains('useSharedAccessibleViewModel'));
    expect(dateScreen, contains('UniversalAccessibleList('));
    expect(dateScreen, contains("id: 'back'"));
    expect(source, contains('label: Text(l10n.back)'));
    expect(source, contains('ElevatedButton.icon('));
    expect(source, contains('final dateItems = _itemsForDate(date);'));
    expect(
      source,
      isNot(contains('_waitForDateSelectorReturnToSettle')),
    );
    expect(
      source,
      isNot(contains('mode: AccessibleFocusMode.routeReturnJump')),
    );
    expect(
      source,
      isNot(contains("_accessibleListController.focusTo(\n        'item_\$itemIndex'")),
    );
  });
}
