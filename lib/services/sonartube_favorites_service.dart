import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sonartube_service.dart';

class SonarTubeFavoritesService {
  static const _key = 'sonarpad_sonartube_favorites';

  Future<List<SonarTubeItem>> loadFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getStringList(_key) ?? const [];
    final favorites = <SonarTubeItem>[];
    for (final value in encoded) {
      try {
        final raw = jsonDecode(value);
        if (raw is! Map) continue;
        final item = _fromJson(Map<String, dynamic>.from(raw));
        if (item != null) favorites.add(item);
      } catch (_) {
        // Ignora una singola voce danneggiata senza perdere gli altri preferiti.
      }
    }
    return favorites;
  }

  Future<bool> toggleFavorite(SonarTubeItem item) async {
    final favorites = await loadFavorites();
    final key = itemKey(item);
    final wasFavorite = favorites.any((favorite) => itemKey(favorite) == key);
    favorites.removeWhere((favorite) => itemKey(favorite) == key);
    if (!wasFavorite) favorites.add(_forFavoriteStorage(item));
    await _save(favorites);
    return !wasFavorite;
  }

  SonarTubeItem _forFavoriteStorage(SonarTubeItem item) {
    final publicUrl = _publicYoutubeUrl(item);
    return SonarTubeItem(
      kind: item.kind,
      id: item.id,
      title: item.title,
      url: publicUrl,
      channel: item.channel,
      channelId: item.channelId,
      thumbnailUrl: item.thumbnailUrl,
      duration: item.duration,
      published: item.published,
      views: item.views,
      subscribers: item.subscribers,
      description: item.description,
      isLive: item.isLive,
    );
  }

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

    return switch (item.kind) {
      SonarTubeItemKind.video =>
        Uri.https('www.youtube.com', '/watch', {'v': item.id}).toString(),
      SonarTubeItemKind.channel =>
        Uri.https('www.youtube.com', '/channel/${item.id}').toString(),
      SonarTubeItemKind.playlist =>
        Uri.https('www.youtube.com', '/playlist', {'list': item.id}).toString(),
    };
  }

  String itemKey(SonarTubeItem item) => '${item.kind.name}:${item.id}';

  Future<void> _save(List<SonarTubeItem> favorites) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      favorites.map((item) => jsonEncode(_toJson(item))).toList(),
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
    'subscribers': item.subscribers,
    'description': item.description,
    'isLive': item.isLive,
  };

  SonarTubeItem? _fromJson(Map<String, dynamic> raw) {
    final kind = switch (raw['kind']) {
      'video' => SonarTubeItemKind.video,
      'channel' => SonarTubeItemKind.channel,
      'playlist' => SonarTubeItemKind.playlist,
      _ => null,
    };
    final id = raw['id']?.toString().trim();
    final title = raw['title']?.toString().trim();
    if (kind == null ||
        id == null ||
        id.isEmpty ||
        title == null ||
        title.isEmpty) {
      return null;
    }
    return SonarTubeItem(
      kind: kind,
      id: id,
      title: title,
      url: raw['url']?.toString() ?? '',
      channel: raw['channel']?.toString(),
      channelId: raw['channel_id']?.toString(),
      thumbnailUrl: raw['thumbnail']?.toString(),
      duration: raw['duration']?.toString(),
      published: raw['published']?.toString(),
      views: raw['views']?.toString(),
      subscribers: raw['subscribers']?.toString(),
      description: raw['description']?.toString(),
      isLive: raw['isLive'] == true,
    );
  }
}
