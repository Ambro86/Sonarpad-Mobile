import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/sonarpad_audiodescriptions_favorites_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarpad_audiodescriptions_service.dart';

SonarpadAudiodescriptionItem _item({
  String type = 'file',
  required String title,
  required String path,
}) => SonarpadAudiodescriptionItem(
  type: type,
  title: title,
  path: path,
  filename: '$title.mp4',
  downloadFilename: '$title.mp4',
  modifiedTimestamp: 0,
  mimeType: type == 'folder' ? '' : 'video/mp4',
  streamUrl: 'https://example.org/private-stream?expires=1',
  downloadUrl: 'https://example.org/private-download?expires=1',
  plot: '',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('films and whole series are kept in a device-local list', () async {
    const storage = SonarpadAudiodescriptionsFavoritesService();
    final film = _item(title: 'Film', path: 'films/film.mp4');
    final series = _item(type: 'folder', title: 'Serie', path: 'series/serie');
    expect(await storage.toggle(film), isTrue);
    expect(await storage.toggle(series), isTrue);
    expect((await storage.load()).map((e) => e.path), [series.path, film.path]);
    expect(await storage.toggle(film), isFalse);
    expect((await storage.load()).map((e) => e.path), [series.path]);
  });

  test('does not save access codes or expiring audio/video URLs', () async {
    const storage = SonarpadAudiodescriptionsFavoritesService();
    await storage.toggle(_item(title: 'Test', path: 'films/test.mp4'));
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getStringList(
      SonarpadAudiodescriptionsFavoritesService.storageKey,
    )!;
    expect(encoded, hasLength(1));
    final saved = jsonDecode(encoded.single) as Map<String, dynamic>;
    expect(saved['path'], 'films/test.mp4');
    expect(saved.containsKey('stream_url'), isFalse);
    expect(saved.containsKey('download_url'), isFalse);
  });

  test('same title in different folders stays distinct', () async {
    const storage = SonarpadAudiodescriptionsFavoritesService();
    await storage.toggle(_item(title: 'Episodio 1', path: 'serieA/ep1.mp4'));
    await storage.toggle(_item(title: 'Episodio 1', path: 'serieB/ep1.mp4'));
    expect(await storage.load(), hasLength(2));
  });

  test('refreshes a saved film before playback instead of using the old URL', () async {
    final api = SonarpadAudiodescriptionsService(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], 'folder');
        expect(body['folder'], 'films');
        return http.Response(jsonEncode({
          'ok': true,
          'items': [
            {
              'type': 'file',
              'title': 'Film',
              'path': 'films/film.mp4',
              'filename': 'film.mp4',
              'download_filename': 'film.mp4',
              'modified_timestamp': 0,
              'mime_type': 'video/mp4',
              'plot': '',
              'stream_url': 'https://example.org/fresh',
              'download_url': 'https://example.org/download-fresh',
            }
          ],
        }), 200);
      }),
    );
    final bookmark = _item(title: 'Film', path: 'films/film.mp4');
    final fresh = await api.refreshFavorite('code', bookmark);
    expect(fresh?.streamUrl, 'https://example.org/fresh');
    expect(fresh?.streamUrl, isNot(bookmark.streamUrl));
  });

  test('all catalog views expose one rotor action and a sighted-only heart', () {
    final screen = File(
      'lib/screens/sonarpad_audiodescriptions_screen.dart',
    ).readAsStringSync();
    for (final rowPrefix in const ['recent_', 'all_', 'folder_', 'search_']) {
      expect(screen, contains("'$rowPrefix"), reason: rowPrefix);
    }
    expect(screen, contains("AccessibleCustomAction(id: 'favorite', label: favoriteLabel)"));
    expect(screen, contains("AccessibleVisualAction(\n              id: 'favorite'"));
    expect(screen, contains("event.action == 'favorite'"));
    expect(screen, contains('ExcludeSemantics('));
    expect(screen, contains('SonarpadAudiodescriptionsFavoritesScreen'));
  });
}
