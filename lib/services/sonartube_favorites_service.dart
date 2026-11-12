import 'collection_storage.dart';
import 'cloud_sync_deletions.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sonartube_service.dart';
import 'cloud_sync_state.dart';
import '../utils/app_logger.dart';

class SonarTubeFavoritesService {
  static const _key = 'sonarpad_sonartube_favorites';

  Future<List<SonarTubeItem>> loadFavorites({
    bool strict = false,
  }) => CollectionStorage.run(() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getStringList(_key) ?? const [];
    final favorites = <SonarTubeItem>[];
    for (final value in encoded) {
      try {
        final raw = jsonDecode(value);
        if (raw is! Map) {
          if (strict) {
            throw const FormatException('Invalid stored SonarTube favorite');
          }
          continue;
        }
        final item = _fromJson(Map<String, dynamic>.from(raw));
        if (item != null) {
          favorites.add(item);
        } else if (strict) {
          throw const FormatException('Invalid stored SonarTube favorite');
        }
      } catch (_) {
        if (strict) rethrow;
        // Ignora una singola voce danneggiata senza perdere gli altri preferiti.
      }
    }
    return favorites;
  });

  Future<void> clearFavorites() => CollectionStorage.run(() async {
    final current = await loadFavorites(strict: true);
    await CloudSyncDeletions.record(
      'sonartube', current.map((item) => cloudYoutubeUrl(item.url)),
    );
    await _save([]);
  });

  Future<void> reorderFavorites(List<String> keys) =>
      CollectionStorage.run(() async {
        final current = await loadFavorites(strict: true);
        final byKey = {for (final item in current) itemKey(item): item};
        final ordered = <SonarTubeItem>[];
        for (final key in keys) {
          final item = byKey.remove(key);
          if (item != null) ordered.add(item);
        }
        ordered.addAll(byKey.values);
        await _save(ordered);
      });

  Future<bool> toggleFavorite(SonarTubeItem item) => CollectionStorage.run(
    () async {
      final favorites = await loadFavorites(strict: true);
      final key = itemKey(item);
      final wasFavorite = favorites.any((favorite) => itemKey(favorite) == key);
      if (wasFavorite) {
        await CloudSyncDeletions.record(
          'sonartube',
          favorites
              .where((favorite) => itemKey(favorite) == key)
              .map((favorite) => cloudYoutubeUrl(favorite.url)),
        );
      }
      favorites.removeWhere((favorite) => itemKey(favorite) == key);
      if (!wasFavorite) favorites.add(_forFavoriteStorage(item));
      await _save(favorites);
      return !wasFavorite;
    },
  );

  /// Aggiorna i metadati salvati di un preferito senza aggiungerlo se non
  /// esiste. I valori nuovi non vuoti vincono, mentre i dati gia' presenti
  /// vengono conservati quando [item] non li contiene.
  Future<SonarTubeItem?> updateFavoriteMetadata(SonarTubeItem item) =>
      CollectionStorage.run(() async {
        final favorites = await loadFavorites(strict: true);
        final key = itemKey(item);
        final index = favorites.indexWhere(
          (favorite) => itemKey(favorite) == key,
        );
        if (index < 0) return null;

        final existing = favorites[index];
        final updated = _forFavoriteStorage(_mergeFavorite(existing, item));
        if (item.url.trim().isNotEmpty &&
            cloudYoutubeUrl(item.url) != cloudYoutubeUrl(existing.url)) {
          await AppLogger.log(
            '[CloudSync] sonartube_metadata_url_preserved '
            'kind=${existing.kind.name} identity_unchanged=true',
          );
        }
        if (jsonEncode(_toJson(existing)) != jsonEncode(_toJson(updated))) {
          favorites[index] = updated;
          await _save(favorites);
        }
        return updated;
      });

  SonarTubeItem _mergeFavorite(SonarTubeItem existing, SonarTubeItem incoming) {
    String? prefer(String? newer, String? older) {
      final value = newer?.trim();
      return value != null && value.isNotEmpty ? value : older;
    }

    return SonarTubeItem(
      kind: existing.kind,
      id: existing.id,
      title: incoming.title.trim().isNotEmpty ? incoming.title : existing.title,
      // The saved URL is also the cross-device identity. A metadata refresh
      // (for example /channel/UC... -> /@handle) must never replace it.
      url: existing.url,
      channel: prefer(incoming.channel, existing.channel),
      channelId: prefer(incoming.channelId, existing.channelId),
      thumbnailUrl: prefer(incoming.thumbnailUrl, existing.thumbnailUrl),
      duration: prefer(incoming.duration, existing.duration),
      published: prefer(incoming.published, existing.published),
      views: prefer(incoming.views, existing.views),
      subscribers: prefer(incoming.subscribers, existing.subscribers),
      handle: prefer(incoming.handle, existing.handle),
      description: prefer(incoming.description, existing.description),
      videoCount: incoming.videoCount ?? existing.videoCount,
      isLive: incoming.isLive || existing.isLive,
    );
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
      handle: item.handle,
      description: item.description,
      videoCount: item.videoCount,
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
      SonarTubeItemKind.video => Uri.https('www.youtube.com', '/watch', {
        'v': item.id,
      }).toString(),
      SonarTubeItemKind.channel => Uri.https(
        'www.youtube.com',
        '/channel/${item.id}',
      ).toString(),
      SonarTubeItemKind.playlist => Uri.https('www.youtube.com', '/playlist', {
        'list': item.id,
      }).toString(),
    };
  }

  String itemKey(SonarTubeItem item) => '${item.kind.name}:${item.id}';

  Future<void> _save(List<SonarTubeItem> favorites) async {
    final preferences = await SharedPreferences.getInstance();
    final before = await loadFavorites(strict: true);
    List<Map<String, dynamic>> rows(List<SonarTubeItem> items) => items
        .map(
          (item) => <String, dynamic>{
            'id': cloudYoutubeUrl(item.url),
            'data': <String, dynamic>{},
          },
        )
        .toList();
    if (removedCloudItems(
      {'sonartube': rows(before)},
      {'sonartube': rows(favorites)},
    ).isNotEmpty) {
      final recovery = List<dynamic>.from(
        jsonDecode(preferences.getString('${_key}_recovery') ?? '[]') as List,
      );
      recovery.add({
        'time': DateTime.now().toUtc().toIso8601String(),
        'items': preferences.getStringList(_key) ?? [],
      });
      if (recovery.length > 10) recovery.removeAt(0);
      if (!await preferences.setString(
        '${_key}_recovery',
        jsonEncode(recovery),
      )) {
        throw StateError('sonartube_recovery_save_failed');
      }
      await AppLogger.log(
        '[CloudSync] sonartube_local_write caller=${StackTrace.current.toString().split('\n').take(5).join(' | ')}',
      );
      await logCloudReductions(
        {'sonartube': rows(before)},
        {'sonartube': rows(favorites)},
        'sonartube_local_write',
      );
    }
    final saved = await preferences.setStringList(
      _key,
      favorites.map((item) => jsonEncode(_toJson(item))).toList(),
    );
    if (!saved) throw StateError('sonartube_favorites_save_failed');
  }

  Future<void> replaceCloudFavorites(List<Map<String, dynamic>> values) =>
      CollectionStorage.run(() async {
        final items = values.map(_fromJson).whereType<SonarTubeItem>().toList();
        if (items.length != values.length) {
          throw const FormatException('Invalid SonarTube cloud favorites');
        }
        await _save(items.map(_forFavoriteStorage).toList());
      });

  Future<List<Map<String, dynamic>>> exportCloudFavorites() async =>
      (await loadFavorites(strict: true)).map(_toJson).toList();

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
    'handle': item.handle,
    'description': item.description,
    'video_count': item.videoCount,
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
      handle: raw['handle']?.toString(),
      description: raw['description']?.toString(),
      videoCount: int.tryParse(raw['video_count']?.toString() ?? ''),
      isLive: raw['isLive'] == true,
    );
  }
}
