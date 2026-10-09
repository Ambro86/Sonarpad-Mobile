import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'sonarmusic_service.dart';

/// Separate from SonarTube: Music favorites and listening history.
class SonarMusicLibraryService {
  static const favoritesKey = 'sonarpad_sonarmusic_favorites_v1';
  static const historyKey = 'sonarpad_sonarmusic_history_v1';

  Future<List<SonarMusicItem>> favorites() => _load(favoritesKey);
  Future<List<SonarMusicItem>> recent() => _load(historyKey);
  Future<bool> toggle(SonarMusicItem item) async {
    final current = await favorites();
    final had = current.any((existing) => existing.key == item.key);
    current.removeWhere((existing) => existing.key == item.key);
    if (!had) current.insert(0, item);
    await _save(favoritesKey, current);
    return !had;
  }
  Future<void> remember(SonarMusicItem item) async {
    if (!item.playable) return;
    final current = await recent();
    current.removeWhere((existing) => existing.key == item.key);
    current.insert(0, item);
    if (current.length > 100) current.removeRange(100, current.length);
    await _save(historyKey, current);
  }
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(historyKey);
  }
  Future<List<SonarMusicItem>> _load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final items = <SonarMusicItem>[];
    for (final encoded in prefs.getStringList(key) ?? <String>[]) {
      try {
        final value = jsonDecode(encoded);
        if (value is! Map) continue;
        final item = SonarMusicItem.fromJson(Map<String, dynamic>.from(value));
        if (item.id.isNotEmpty) items.add(item);
      } catch (_) { /* Do not drop the rest of the library. */ }
    }
    return items;
  }
  Future<void> _save(String key, List<SonarMusicItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, items.map((e) => jsonEncode(e.toJson())).toList());
  }
}
