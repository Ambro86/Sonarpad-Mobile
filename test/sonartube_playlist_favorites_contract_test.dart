import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opened SonarTube playlists expose the same persistent favorite control as channels', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(
      source,
      contains(
        'bool get _isPlaylistCollection =>\n'
        '      widget.collection?.kind == SonarTubeItemKind.playlist;',
      ),
    );
    expect(source, contains("id: 'playlist_favorite'"));
    expect(
      source,
      contains("'sonartube_collection_playlist_favorite'"),
    );
    expect(
      source,
      contains("event.id == 'playlist_favorite' && _isPlaylistCollection"),
    );
    expect(source, contains('_hasCollectionFavoriteButton'));
  });

  test('playlist favorites are persisted and reopened through the normal collection path', () {
    final favorites = File(
      'lib/services/sonartube_favorites_service.dart',
    ).readAsStringSync();
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(
      favorites,
      contains("'playlist' => SonarTubeItemKind.playlist"),
    );
    expect(
      favorites,
      contains("Uri.https('www.youtube.com', '/playlist', {'list': item.id})"),
    );
    expect(
      screen,
      contains('SonarTubeItemKind.playlist => l10n.sonarTubePlaylist'),
    );
    expect(screen, contains('await widget.onOpenItem(item);'));
  });
}
