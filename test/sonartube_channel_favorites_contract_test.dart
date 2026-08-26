import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube root keeps video and channel favorites grouped', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains("id: 'favorites'"));
    expect(source, contains("ValueKey('sonartube_favorites_button')"));
    expect(source, contains('l10n.sonarTubeFavorites'));
    expect(source, contains("'/sonartube/favorites'"));
    expect(source, isNot(contains("id: 'video_favorites'")));
    expect(source, isNot(contains("id: 'channel_favorites'")));
  });

  test('channel page exposes add or remove favorite before its videos', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('bool get _isChannelCollection'));
    expect(source, contains("id: 'channel_favorite'"));
    expect(source, contains("ValueKey('sonartube_collection_channel_favorite')"));
    expect(source, contains('l10n.sonarTubeAddChannelFavorite'));
    expect(source, contains('l10n.sonarTubeRemoveChannelFavorite'));
    expect(
      source.indexOf("id: 'channel_favorite'"),
      lessThan(source.indexOf(r"id: 'item_$i'")),
    );
  });

  test('favorites screen keeps videos channels and playlists in one collection', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('final favorites = await widget.favoritesService.loadFavorites();'));
    expect(source, contains('_favorites = favorites;'));
    expect(source, contains('SonarTubeItemKind.video => l10n.sonarTubeVideo'));
    expect(source, contains('SonarTubeItemKind.channel => l10n.sonarTubeChannel'));
    expect(source, contains('SonarTubeItemKind.playlist => l10n.sonarTubePlaylist'));
    expect(source, isNot(contains('_SonarTubeFavoritesView')));
  });

  test('all locales include channel-specific favorite labels', () {
    final files = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(file.path));

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, contains('"sonarTubeVideoFavorites"'), reason: file.path);
      expect(source, contains('"sonarTubeChannelFavorites"'), reason: file.path);
      expect(source, contains('"sonarTubeNoVideoFavorites"'), reason: file.path);
      expect(source, contains('"sonarTubeNoChannelFavorites"'), reason: file.path);
      expect(source, contains('"sonarTubeAddChannelFavorite"'), reason: file.path);
      expect(source, contains('"sonarTubeRemoveChannelFavorite"'), reason: file.path);
    }
  });
}
