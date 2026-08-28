import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all SonarTube favorites stay on Favorites and restore focus on Back', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    final openFavoritesStart = source.indexOf('Future<void> _openFavorites()');
    final openRecentStart = source.indexOf('Future<void> _openRecentVideos()', openFavoritesStart);
    expect(openFavoritesStart, greaterThanOrEqualTo(0));
    expect(openRecentStart, greaterThan(openFavoritesStart));
    final openFavorites = source.substring(openFavoritesStart, openRecentStart);

    // Favorites is kept on the Navigator stack. Selecting a favorite no longer
    // pops the Favorites route and returns the item to the parent first.
    expect(openFavorites, contains('await Navigator.push<void>('));
    expect(openFavorites, contains('onOpenItem: _openItem'));
    expect(openFavorites, isNot(contains('Navigator.push<SonarTubeItem>')));

    final favoritesStart = source.indexOf('class _SonarTubeFavoritesScreenState');
    expect(favoritesStart, greaterThanOrEqualTo(0));
    final favorites = source.substring(favoritesStart);

    expect(
      favorites,
      contains("AccessibleListController(debugName: 'sonartube-favorites')"),
    );
    expect(favorites, contains('Future<void> _openFavoriteItem('));
    expect(favorites, contains('await widget.onOpenItem(item);'));
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

    // Preserve the already working channel-specific route/metadata refresh.
    expect(favorites, contains('Future<void> _openFavoriteChannel('));
    expect(
      favorites,
      contains("settings: const RouteSettings(name: '/sonartube/channel')"),
    );
    expect(
      favorites,
      contains('if (item.kind == SonarTubeItemKind.channel) {\n      await _openFavoriteChannel(item);'),
    );

    // Both the shared accessible renderer and Flutter fallback activate every
    // favorite kind (video, playlist, channel) through the same stay-in-
    // Favorites path.
    expect(
      favorites,
      contains("event.type == 'activate') {\n          await _openFavoriteItem(item);"),
    );
    expect(favorites, contains('onTap: () => _openFavoriteItem(item),'));

    // The Favorites screen must not pop itself with the selected item anymore.
    expect(favorites, isNot(contains('Navigator.pop(context, item)')));
  });
}
