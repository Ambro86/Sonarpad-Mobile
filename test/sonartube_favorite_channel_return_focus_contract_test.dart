import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('favorite channels stay on Favorites and restore focus on Back', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    final favoritesStart = source.indexOf('class _SonarTubeFavoritesScreenState');
    expect(favoritesStart, greaterThanOrEqualTo(0));
    final favorites = source.substring(favoritesStart);

    // Compatibility contract for the original channel-only regression test.
    // The implementation is now shared by every favorite kind, so avoid
    // depending on indentation or on the old channel-only activation branch.
    expect(favorites, contains('Future<void> _openFavoriteItem('));
    expect(favorites, contains('if (item.kind == SonarTubeItemKind.channel) {'));
    expect(favorites, contains('await _openFavoriteChannel(item);'));
    expect(favorites, contains('Future<void> _openFavoriteChannel('));
    expect(
      favorites,
      contains("settings: const RouteSettings(name: '/sonartube/channel')"),
    );
    expect(favorites, contains('await _restoreFavoriteFocus(item);'));
    expect(
      favorites,
      contains('mode: AccessibleFocusMode.routeReturnJump'),
    );

    // Opening a favorite must keep the Favorites route on the stack.
    expect(favorites, isNot(contains('Navigator.pop(context, item)')));
  });
}
