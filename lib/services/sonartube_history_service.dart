import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sonartube_service.dart';

class SonarTubeHistoryService {
  static const _key = 'sonarpad_sonartube_recent_videos';
  static const maxItems = 100;

  Future<List<SonarTubeItem>> loadRecentVideos() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getStringList(_key) ?? const <String>[];
    final recent = <SonarTubeItem>[];
    final seen = <String>{};
    for (final value in encoded) {
      try {
        final raw = jsonDecode(value);
        if (raw is! Map) continue;
        final item = _fromJson(Map<String, dynamic>.from(raw));
        if (item == null || item.kind != SonarTubeItemKind.video) continue;
        if (seen.add(item.id)) recent.add(item);
      } catch (_) {
        // Ignore a single corrupted entry without losing the remaining history.
      }
      if (recent.length >= maxItems) break;
    }
    return recent;
  }

  Future<void> addRecentVideo(SonarTubeItem item) async {
    if (item.kind != SonarTubeItemKind.video || item.id.trim().isEmpty) return;
    final recent = await loadRecentVideos();
    recent.removeWhere((candidate) => candidate.id == item.id);
    recent.insert(0, _forHistoryStorage(item));
    if (recent.length > maxItems) {
      recent.removeRange(maxItems, recent.length);
    }
    await _save(recent);
  }

  Future<void> removeRecentVideo(String videoId) async {
    final normalizedId = videoId.trim();
    if (normalizedId.isEmpty) return;
    final recent = await loadRecentVideos();
    recent.removeWhere((item) => item.id == normalizedId);
    await _save(recent);
  }

  Future<void> clearRecentVideos() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }

  SonarTubeItem _forHistoryStorage(SonarTubeItem item) => SonarTubeItem(
    kind: SonarTubeItemKind.video,
    id: item.id,
    title: item.title,
    url: _publicYoutubeUrl(item),
    channel: item.channel,
    channelId: item.channelId,
    thumbnailUrl: item.thumbnailUrl,
    duration: item.duration,
    published: item.published,
    views: item.views,
    description: item.description,
    isLive: item.isLive,
  );

  String _publicYoutubeUrl(SonarTubeItem item) {
    final original = Uri.tryParse(item.url.trim());
    final host = original?.host.toLowerCase() ?? '';
    if (original != null &&
        (host == 'youtube.com' ||
            host == 'www.youtube.com' ||
            host == 'm.youtube.com' ||
            host == 'youtu.be')) {
      return original.toString();
    }
    return Uri.https('www.youtube.com', '/watch', {'v': item.id}).toString();
  }

  Future<void> _save(List<SonarTubeItem> recent) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      recent.map((item) => jsonEncode(_toJson(item))).toList(growable: false),
    );
  }

  Map<String, dynamic> _toJson(SonarTubeItem item) => {
    'kind': item.kind.name,
    'id': item.id,
    'title': item.title,
    'url': item.url,
    'channel': item.channel,
    'channel_id': item.channelId,
    'thumbnail': item.thumbnailUrl,
    'duration': item.duration,
    'published': item.published,
    'views': item.views,
    'description': item.description,
    'isLive': item.isLive,
  };

  SonarTubeItem? _fromJson(Map<String, dynamic> raw) {
    if (raw['kind'] != 'video') return null;
    final id = raw['id']?.toString().trim();
    final title = raw['title']?.toString().trim();
    if (id == null || id.isEmpty || title == null || title.isEmpty) return null;
    return SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: id,
      title: title,
      url: raw['url']?.toString() ?? '',
      channel: raw['channel']?.toString(),
      channelId: raw['channel_id']?.toString(),
      thumbnailUrl: raw['thumbnail']?.toString(),
      duration: raw['duration']?.toString(),
      published: raw['published']?.toString(),
      views: raw['views']?.toString(),
      description: raw['description']?.toString(),
      isLive: raw['isLive'] == true,
    );
  }
}
