import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_favorites_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  test('persists and removes video, channel and playlist favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeFavoritesService();
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video preferito',
      url: 'https://youtu.be/abcdefghijk?si=original',
      channel: 'Canale video',
    );
    const channel = SonarTubeItem(
      kind: SonarTubeItemKind.channel,
      id: 'UC123',
      title: 'Canale preferito',
      url: 'https://www.youtube.com/channel/UC123',
    );
    const playlist = SonarTubeItem(
      kind: SonarTubeItemKind.playlist,
      id: 'PL123',
      title: 'Playlist preferita',
      url: 'https://www.youtube.com/playlist?list=PL123',
    );

    expect(await service.toggleFavorite(video), isTrue);
    expect(await service.toggleFavorite(channel), isTrue);
    expect(await service.toggleFavorite(playlist), isTrue);

    final favorites = await SonarTubeFavoritesService().loadFavorites();
    expect(favorites.map((item) => item.title), [
      'Video preferito',
      'Canale preferito',
      'Playlist preferita',
    ]);
    final storedVideo = favorites.first;
    expect(storedVideo.kind, SonarTubeItemKind.video);
    expect(storedVideo.url, 'https://youtu.be/abcdefghijk?si=original');

    expect(await service.toggleFavorite(video), isFalse);
    expect(
      (await service.loadFavorites()).map((item) => item.title),
      ['Canale preferito', 'Playlist preferita'],
    );
  });

  test('video favorites never persist a temporary resolved media URL', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeFavoritesService();
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://temporary.example.invalid/resolved/audio-stream.m4a',
    );

    expect(await service.toggleFavorite(video), isTrue);
    final stored = (await service.loadFavorites()).single;

    expect(stored.url, 'https://www.youtube.com/watch?v=abcdefghijk');
    expect(stored.url, isNot(contains('temporary.example.invalid')));
  });

  test('updates static metadata only for an existing favorite', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeFavoritesService();
    const oldChannel = SonarTubeItem(
      kind: SonarTubeItemKind.channel,
      id: 'UC123',
      title: 'Canale preferito',
      url: 'https://www.youtube.com/channel/UC123',
    );
    const refreshedChannel = SonarTubeItem(
      kind: SonarTubeItemKind.channel,
      id: 'UC123',
      title: 'Canale preferito',
      url: 'https://www.youtube.com/@canalepreferito',
      handle: '@canalepreferito',
      subscribers: '123 mila iscritti',
    );

    expect(await service.updateFavoriteMetadata(refreshedChannel), isNull);
    expect(await service.toggleFavorite(oldChannel), isTrue);

    final updated = await service.updateFavoriteMetadata(refreshedChannel);
    expect(updated, isNotNull);
    expect(updated!.handle, '@canalepreferito');
    expect(updated.subscribers, '123 mila iscritti');

    final stored = (await service.loadFavorites()).single;
    expect(stored.handle, '@canalepreferito');
    expect(stored.subscribers, '123 mila iscritti');
  });
}
