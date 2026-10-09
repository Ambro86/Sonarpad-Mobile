import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sonarpad_audiodescriptions_service.dart';

/// Personal, device-local favorites. No access codes or temporary media URLs
/// are persisted: a bookmarked film gets a fresh URL when it is opened.
class SonarpadAudiodescriptionsFavoritesService {
  static const storageKey = 'sonarpad_audiodescriptions_favorites_v1';

  const SonarpadAudiodescriptionsFavoritesService();

  static String itemKey(SonarpadAudiodescriptionItem item) =>
      '${item.isFolder ? 'folder' : 'file'}:${item.path.trim()}';

  Future<List<SonarpadAudiodescriptionItem>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final favorites = <SonarpadAudiodescriptionItem>[];
    final seen = <String>{};
    for (final encoded in preferences.getStringList(storageKey) ?? const <String>[]) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is! Map) {
          continue;
        }
        final item = SonarpadAudiodescriptionItem.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        if (item.path.isEmpty || item.title.isEmpty) {
          continue;
        }
        if (seen.add(itemKey(item))) {
          favorites.add(item);
        }
      } catch (_) {
        // An invalid saved entry must not hide the remaining favorites.
      }
    }
    return favorites;
  }

  Future<bool> toggle(SonarpadAudiodescriptionItem item) async {
    if (item.path.trim().isEmpty) {
      return false;
    }
    final favorites = await load();
    final key = itemKey(item);
    final existed = favorites.any((favorite) => itemKey(favorite) == key);
    favorites.removeWhere((favorite) => itemKey(favorite) == key);
    if (!existed) {
      favorites.insert(0, item);
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      storageKey,
      favorites.map((favorite) => jsonEncode({
        'type': favorite.type,
        'title': favorite.title,
        'path': favorite.path,
        'filename': favorite.filename,
        'download_filename': favorite.downloadFilename,
        'modified_timestamp': favorite.modifiedTimestamp,
        'mime_type': favorite.mimeType,
        'plot': favorite.plot,
        // Intentionally no stream_url / download_url: they can expire.
      })).toList(growable: false),
    );
    return !existed;
  }
}
