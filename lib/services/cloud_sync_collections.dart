import 'podcast_bookmarks_service.dart';
import 'collection_storage.dart';
import 'sonarmusic_library_service.dart';
import 'sonarmusic_service.dart';
import '../models/radio_station.dart';
import '../models/podcast.dart';
import 'cloud_sync_state.dart';
import 'radio_service.dart';
import 'tv_service.dart';
import 'podcast_service.dart';
import 'sonartube_favorites_service.dart';
import 'news_service.dart';
import 'cloud_sync_preferences.dart';

class CloudSyncCollections {
  static const musicFields = [
    'kind',
    'id',
    'title',
    'video_id',
    'browse_id',
    'browse_params',
    'artist',
    'duration',
    'subtitle',
    'available',
  ];
  static String musicId(Map<String, dynamic> data) {
    final params = data['browse_params'] as String? ?? '';
    return '${data['kind']}:${data['id']}${params.isEmpty ? '' : ':$params'}';
  }

  static Map<String, dynamic> musicData(SonarMusicItem item) {
    final data = item.toJson();
    return {
      for (final key in musicFields)
        key: key == 'available' ? item.available : (data[key] ?? ''),
    };
  }

  Map<String, dynamic> _item(String id, Map<String, dynamic> data) => {
    'id': id,
    'data': data,
  };

  Future<CloudState> read() => CollectionStorage.run(() async {
    final radio = await RadioService().loadFavorites();
    final tv = await TvService().loadFavorites();
    final podcasts = await PodcastService().loadSubscriptions();
    final videos = await SonarTubeFavoritesService().exportCloudFavorites();
    final music = await SonarMusicLibraryService().favorites();
    return {
      'sonarmusic': music.map((v) {
        final data = musicData(v);
        return _item(musicId(data), data);
      }).toList(),
      'podcast_bookmarks': await PodcastBookmarksService().read(),
      'preferences': await CloudSyncPreferences.read(),
      'radio': radio
          .map(
            (r) => _item(r.streamUrl.trim(), {
              'name': r.name,
              'stream_url': r.streamUrl,
              'language_code': r.languageCode,
            }),
          )
          .toList(),
      'tv': tv
          .map((t) => _item(t.name.trim().toLowerCase(), {'name': t.name}))
          .toList(),
      'podcasts': podcasts
          .map(
            (p) =>
                _item(p.feedUrl.trim(), {'title': p.title, 'url': p.feedUrl}),
          )
          .toList(),
      'sonartube': videos
          .map(
            (v) => _item(cloudYoutubeUrl(v['url'] as String), {
              'title': v['title'],
              'url': cloudYoutubeUrl(v['url'] as String),
            }),
          )
          .toList(),
      ...await NewsService().exportCloudCollections(),
    };
  });

  /// Keep only fields this client can represent. Unhandled collections and
  /// metadata stay on the server and are never interpreted as local deletions.
  CloudState project(CloudState state) {
    const fields = {
      'sonarmusic': musicFields,
      'podcast_bookmarks': PodcastBookmarksService.fields,
      'radio': ['name', 'stream_url', 'language_code'],
      'tv': ['name'],
      'podcasts': ['title', 'url'],
      'sonartube': ['title', 'url'],
      'news_sources': ['language', 'title', 'url', 'folder_path'],
      'news_folders': ['language', 'path'],
    };
    final result = <String, List<Map<String, dynamic>>>{};
    result['preferences'] = CloudSyncPreferences.project(
      state['preferences'] ?? [],
    );
    for (final name in fields.keys) {
      result[name] = (state[name] ?? [])
          .where((item) {
            if (name == 'news_sources' &&
                (item['data'] as Map)['url'] == 'sonarpad://rss/favorites') {
              return false;
            }
            if (!name.startsWith('news_')) return true;
            final data = item['data'] as Map<String, dynamic>;
            return NewsLanguage.values.any((l) => l.code == data['language']);
          })
          .map((item) {
            final data = item['data'] as Map<String, dynamic>;
            final projected = {
              for (final key in fields[name]!)
                if (data.containsKey(key)) key: data[key],
            };
            for (final key in fields[name]!) {
              if (!projected.containsKey(key)) {
                throw const FormatException('Missing cloud field');
              }
              if (name == 'podcast_bookmarks' &&
                  {'position_seconds', 'updated_at'}.contains(key)) {
                if (projected[key] is! int) throw const FormatException('Invalid podcast number');
                continue;
              }
              if (name == 'sonarmusic' && key == 'available') {
                if (projected[key] is! bool) {
                  throw const FormatException('Invalid music availability');
                }
                continue;
              }
              if (key != 'path' &&
                  key != 'folder_path' &&
                  projected[key] is! String) {
                throw const FormatException('Invalid cloud field');
              }
            }
            if (name == 'news_sources' || name == 'news_folders') {
              final key = name == 'news_sources' ? 'folder_path' : 'path';
              final path = projected[key];
              if (path is! List || path.any((v) => v is! String)) {
                throw const FormatException('Invalid cloud folder');
              }
            }
            for (final key in ['url', 'stream_url']) {
              if (projected.containsKey(key)) {
                final uri = Uri.tryParse(projected[key] as String);
                if (uri == null ||
                    !{'http', 'https'}.contains(uri.scheme) ||
                    uri.host.isEmpty) {
                  throw const FormatException('Invalid cloud URL');
                }
              }
            }
            if (name == 'sonarmusic' &&
                (projected['id'] == '' ||
                    projected['kind'] == '' ||
                    musicId(projected) != item['id'])) {
              throw const FormatException('Invalid SonarMusic identity');
            }
            if (name == 'podcast_bookmarks') PodcastBookmarksService.validate(_item(item['id'] as String, projected));
            return _item(item['id'] as String, projected);
          })
          .toList();
    }
    return result;
  }

  Future<void> write(CloudState state) => CollectionStorage.run(() async {
    final included = state.keys.toSet();
    final current = await read();
    state = project({
      ...current,
      ...state,
    }); // Validate the entire response before writing anything.
    final oldRadios = {
      for (final r in await RadioService().loadFavorites()) r.streamUrl: r,
    };
    final radios = state['radio']!.map((item) {
      final d = item['data'] as Map<String, dynamic>;
      return (oldRadios[d['stream_url']] ??
              RadioStation(
                name: d['name'],
                streamUrl: d['stream_url'],
                languageCode: d['language_code'],
              ))
          .copyWith(name: d['name'], languageCode: d['language_code']);
    }).toList();
    final oldTv = {
      for (final t in await TvService().loadFavorites())
        t.name.trim().toLowerCase(): t,
    };
    final tv = state['tv']!.map((item) {
      final d = item['data'] as Map<String, dynamic>;
      return oldTv[item['id']] ??
          TvChannel(name: d['name'], url: '', category: '');
    }).toList();
    final oldPodcasts = {
      for (final p in await PodcastService().loadSubscriptions()) p.feedUrl: p,
    };
    final podcasts = state['podcasts']!.map((item) {
      final d = item['data'] as Map<String, dynamic>;
      return PodcastSubscription(
        title: d['title'],
        feedUrl: d['url'],
        artworkUrl: oldPodcasts[d['url']]?.artworkUrl,
      );
    }).toList();
    final oldVideos = {
      for (final v in await SonarTubeFavoritesService().exportCloudFavorites())
        cloudYoutubeUrl(v['url'] as String): v,
    };
    final videos = state['sonartube']!.map((item) {
      final d = item['data'] as Map<String, dynamic>;
      final uri = Uri.parse(d['url'] as String);
      final id =
          uri.queryParameters['v'] ??
          uri.queryParameters['list'] ??
          uri.pathSegments.lastOrNull;
      if (id == null || id.isEmpty) {
        throw const FormatException('Invalid SonarTube favorite');
      }
      return <String, dynamic>{
        ...?oldVideos[item['id']],
        ...d,
        'kind': uri.queryParameters.containsKey('v')
            ? 'video'
            : uri.queryParameters.containsKey('list')
            ? 'playlist'
            : 'channel',
        'id': id,
      };
    }).toList();
    if (included.contains('sonarmusic')) {
      final musicLibrary = SonarMusicLibraryService();
      final oldMusic = {
        for (final v in await musicLibrary.favorites())
          musicId(musicData(v)): v,
      };
      await musicLibrary.replaceCloudFavorites([
        for (final row in state['sonarmusic']!)
          SonarMusicItem.fromJson({
            ...?oldMusic[row['id']]?.toJson(),
            ...row['data'] as Map<String, dynamic>,
          }),
      ]);
    }
    if (included.contains('podcast_bookmarks')) {
      await PodcastBookmarksService().replace(state['podcast_bookmarks']!);
    }
    if (included.contains('radio')) {
      await RadioService().saveFavorites(
        radios,
        updateOrder: true,
        fromCloud: true,
      );
    }
    if (included.contains('tv')) {
      await TvService().saveFavorites(tv, fromCloud: true);
    }
    if (included.contains('podcasts')) {
      await PodcastService().saveSubscriptions(podcasts, fromCloud: true);
    }
    if (included.contains('sonartube')) {
      await SonarTubeFavoritesService().replaceCloudFavorites(videos);
    }
    if (included.contains('news_sources') ||
        included.contains('news_folders')) {
      await NewsService().replaceCloudCollections(state);
    }
    if (included.contains('preferences')) {
      await CloudSyncPreferences.write(
        state['preferences']!,
        baseline: current['preferences']!,
      );
    }
  });
}
