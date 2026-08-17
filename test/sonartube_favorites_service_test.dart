import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_favorites_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  test('persists and removes channel and playlist favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeFavoritesService();
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

    expect(await service.toggleFavorite(channel), isTrue);
    expect(await service.toggleFavorite(playlist), isTrue);

    final favorites = await SonarTubeFavoritesService().loadFavorites();
    expect(favorites.map((item) => item.title), [
      'Canale preferito',
      'Playlist preferita',
    ]);

    expect(await service.toggleFavorite(channel), isFalse);
    expect((await service.loadFavorites()).single.title, 'Playlist preferita');
  });

  test('rejects individual videos as favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeFavoritesService();
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    expect(() => service.toggleFavorite(video), throwsArgumentError);
  });
}
