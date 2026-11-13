import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'collection_storage.dart';

/// Shared with desktop: the original episode URL, never the local cache path.
class PodcastBookmarksService {
  static const key = 'podcast_bookmarks';
  static const prefix = 'podcast:';
  static const fields = ['url', 'title', 'position_seconds', 'updated_at'];

  static bool isUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty;
  }

  static void validate(Map<String, dynamic> row) {
    final d = row['data'] as Map<String, dynamic>;
    if (d['url'] is! String ||
        !isUrl(d['url']) ||
        d['url'] != (d['url'] as String).trim() ||
        row['id'] != d['url'] ||
        d['title'] is! String ||
        d['position_seconds'] is! int ||
        d['position_seconds'] < 0 ||
        d['position_seconds'] > 2147483647 ||
        d['updated_at'] is! int ||
        d['updated_at'] < 0 ||
        d['updated_at'] > 9007199254740991) {
      throw const FormatException('Invalid podcast bookmark');
    }
  }

  Future<List<Map<String, dynamic>>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<void> replace(List<Map<String, dynamic>> rows) =>
      CollectionStorage.run(() async {
        for (final row in rows) {
          validate(row);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode(rows));
      });

  Future<void> register(
    String url,
    String title,
    String legacyId,
  ) => CollectionStorage.run(() async {
    final rows = await read();
    if (rows.any((r) => r['id'] == url)) return;
    final prefs = await SharedPreferences.getInstance();
    rows.add({
      'id': url,
      'data': {
        'url': url, 'title': title,
        'position_seconds': prefs.getInt('bookmark_$legacyId') ?? 0,
        // Imported legacy positions have no reliable time and cannot overwrite
        // a position already saved on another device.
        'updated_at': 0,
      },
    });
    await replace(rows);
  });

  Future<int?> position(String url) async {
    for (final row in await read()) {
      if (row['id'] == url) return row['data']['position_seconds'] as int;
    }
    return null;
  }

  Future<void> save(
    String url,
    int seconds, {
    bool reset = false,
  }) => CollectionStorage.run(() async {
    if (!isUrl(url)) return;
    final rows = await read();
    final index = rows.indexWhere((r) => r['id'] == url);
    if (index < 0) return;
    final data = Map<String, dynamic>.from(rows[index]['data'] as Map);
    if (!reset && data['position_seconds'] == seconds) return;
    data['position_seconds'] = seconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    final previousTime = data['updated_at'] as int;
    data['updated_at'] = now > previousTime ? now : previousTime + 1;
    rows[index] = {'id': url, 'data': data};
    // Keep a zero-position record: completion/removal must also reach devices
    // which were offline, instead of resurrecting their older bookmark.
    await replace(rows);
  });
}
