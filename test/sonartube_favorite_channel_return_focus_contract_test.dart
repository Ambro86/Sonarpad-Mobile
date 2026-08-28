import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('favorite channels open above Favorites and restore the same row on Back', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final start = source.indexOf('class _SonarTubeFavoritesScreenState');
    expect(start, greaterThanOrEqualTo(0));
    final favorites = source.substring(start);

    expect(
      favorites,
      contains("AccessibleListController(debugName: 'sonartube-favorites')"),
    );
    expect(favorites, contains('Future<void> _openFavoriteChannel('));
    expect(favorites, contains("settings: const RouteSettings(name: '/sonartube/channel')"));
    expect(favorites, contains('await Navigator.push<void>('));
    expect(favorites, contains('await _load();'));
    expect(favorites, contains('await _restoreFavoriteFocus(item);'));
    expect(
      favorites,
      contains('_accessibleListController.focusAccessibleRow('),
    );
    expect(
      favorites,
      contains('mode: AccessibleFocusMode.routeReturnJump'),
    );
    expect(favorites, contains('controller: _accessibleListController'));

    // Both the shared UIKit/Flutter model and the legacy Flutter fallback keep
    // Favorites on the navigation stack when the selected favorite is a channel.
    expect(
      favorites,
      contains('if (item.kind == SonarTubeItemKind.channel) {\n            await _openFavoriteChannel(item);'),
    );
    expect(
      favorites,
      contains('onTap: item.kind == SonarTubeItemKind.channel\n                                        ? () => _openFavoriteChannel(item)'),
    );
  });
}
