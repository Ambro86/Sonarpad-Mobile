import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';
import 'sonartube_service.dart';

/// YouTube Music catalog; public items do not contain expiring stream URLs.
/// SonarTube's player/exports are reused, without changing SonarTube itself.
class SonarMusicItem {
  const SonarMusicItem({
    required this.kind, required this.id, required this.title,
    this.videoId, this.browseId, this.url, this.artist, this.artistId,
    this.album, this.albumId, this.duration, this.thumbnail,
    this.subtitle, this.description, this.available = true,
  });
  final String kind;
  final String id;
  final String title;
  final String? videoId, browseId, url, artist, artistId, album, albumId;
  final String? duration, thumbnail, subtitle, description;
  final bool available;
  bool get playable => available &&
      (kind == 'song' || kind == 'video' || kind == 'episode') &&
      videoId != null && videoId!.isNotEmpty;
  bool get browsable => !playable && (browseId != null || id.isNotEmpty);
  String get key => '$kind:$id';

  factory SonarMusicItem.fromJson(Map<String, dynamic> value) {
    String? string(Object? v) => v == null || v.toString().trim().isEmpty
        ? null : v.toString().trim();
    String? artistId;
    final artists = value['artists'];
    if (artists is List) {
      for (final a in artists) {
        if (a is Map && string(a['id']) != null) {
          artistId = string(a['id']); break;
        }
      }
    }
    final kind = string(value['kind']) ?? 'unknown';
    final id = string(value['id']) ?? string(value['video_id']) ?? '';
    final videoId = string(value['video_id']);
    final browseId = string(value['browse_id']);
    return SonarMusicItem(kind: kind, id: id,
      title: string(value['title']) ?? id,
      videoId: videoId, browseId: browseId,
      url: string(value['url']), artist: string(value['artist']),
      artistId: artistId, album: string(value['album']),
      albumId: string(value['album_id']), duration: string(value['duration']),
      thumbnail: string(value['thumbnail']), subtitle: string(value['subtitle']),
      description: string(value['description']), available: value['available'] != false);
  }
  Map<String, Object?> toJson() => {
    'kind': kind, 'id': id, 'title': title, 'video_id': videoId,
    'browse_id': browseId, 'url': url, 'artist': artist,
    'artists': artistId == null ? null : [{'name': artist, 'id': artistId}],
    'album': album, 'album_id': albumId, 'duration': duration,
    'thumbnail': thumbnail, 'subtitle': subtitle, 'description': description,
    'available': available,
  };
  SonarTubeItem toVideoItem() => SonarTubeItem(
    kind: SonarTubeItemKind.video, id: videoId ?? id, title: title,
    url: url ?? 'https://music.youtube.com/watch?v=${videoId ?? id}',
    channel: artist, channelId: artistId, thumbnailUrl: thumbnail,
    duration: duration);
}

class SonarMusicPage {
  const SonarMusicPage({required this.items, this.nextToken,
    this.title, this.description});
  final List<SonarMusicItem> items;
  final String? nextToken, title, description;
  bool get hasMore => nextToken != null && nextToken!.isNotEmpty;
}

class SonarMusicService {
  SonarMusicService({http.Client? client, Uri? endpoint, String? clientToken,
    SonarTubeService? tubeService, this.directCatalog = true})
      : _client = client ?? http.Client(),
        endpoint = endpoint ?? Uri.parse('https://sonarpad.com/api/youtube_music_resolve.php'),
        _clientToken = clientToken ?? const String.fromEnvironment('SONARPAD_ROUTE_CLIENT_TOKEN'),
        _tube = tubeService ?? SonarTubeService(
          endpoint: endpoint ?? Uri.parse('https://sonarpad.com/api/youtube_music_resolve.php'),
          clientToken: clientToken);
  final http.Client _client;
  final Uri endpoint;
  final String _clientToken;
  final SonarTubeService _tube;
  final bool directCatalog;
  String _hl = 'it', _gl = 'IT';
  static const _musicKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const _base = 'https://music.youtube.com/youtubei/v1';
  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36';

  void setLocaleName(String locale) {
    final name = locale.toLowerCase().replaceAll('-', '_');
    _hl = switch(name) {'pt_br' => 'pt', 'zh_cn' => 'zh-CN', _ => name};
    _gl = switch(name) {
      'cs' => 'CZ', 'de' => 'DE', 'en' => 'US', 'es' => 'ES',
      'fr' => 'FR', 'pt' => 'PT', 'pt_br' => 'BR', 'pl' => 'PL',
      'ro' => 'RO', 'uk' => 'UA', 'zh_cn' => 'CN', _ => 'IT',
    };
    _tube.setLocaleName(locale);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (_clientToken.isNotEmpty) 'X-Sonarpad-Route-Token': _clientToken,
  };
  Future<Map<String, dynamic>> _server(Map<String, String> params) async {
    final uri = endpoint.replace(queryParameters: {...params, 'format': 'json', 'hl': _hl, 'gl': _gl});
    final response = await _client.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      throw Exception('SonarMusic server HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('SonarMusic JSON non valido');
    final map = Map<String, dynamic>.from(decoded);
    if (map['ok'] != true) throw Exception('SonarMusic: ${map['error'] ?? 'errore sconosciuto'}');
    return map;
  }

  Future<Map<String, dynamic>> _direct(String path, Map<String, Object?> payload) async {
    final version = '1.${DateTime.now().toUtc().year}${DateTime.now().toUtc().month.toString().padLeft(2, '0')}${DateTime.now().toUtc().day.toString().padLeft(2, '0')}.01.00';
    final uri = Uri.parse('$_base/$path?prettyPrint=false&key=$_musicKey');
    final response = await _client.post(uri,
      headers: {
        'Content-Type': 'application/json', 'Accept': 'application/json',
        'User-Agent': _userAgent, 'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
        'X-YouTube-Client-Name': '67', 'X-YouTube-Client-Version': version,
        'Cookie': 'SOCS=CAI',
      },
      body: jsonEncode({
        'context': {'client': {'clientName': 'WEB_REMIX',
          'clientVersion': version, 'hl': _hl, 'gl': _gl}},
        ...payload,
      }),
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('Music direct HTTP ${response.statusCode}');
    final result = jsonDecode(utf8.decode(response.bodyBytes));
    if (result is! Map) throw const FormatException('Music direct JSON');
    return Map<String, dynamic>.from(result);
  }

  String? _filter(String type) => switch(type) {
    'song' => 'EgWKAQIIAWoMEA4QChADEAQQCRAF',
    'video' => 'EgWKAQIQAWoMEA4QChADEAQQCRAF',
    'album' => 'EgWKAQIYAWoMEA4QChADEAQQCRAF',
    'artist' => 'EgWKAQIgAWoMEA4QChADEAQQCRAF',
    'playlist' => 'Eg-KAQwIABAAGAAgACgBMABqChAEEAMQCRAFEAo=',
    _ => null,
  };

  Future<SonarMusicPage> search(String query, {String type = 'all',
      String? token, int page = 1}) async {
    if (directCatalog) {
      try {
        final data = await _direct('search', token != null && token.isNotEmpty
            ? {'continuation': token}
            : {'query': query, if (_filter(type) != null) 'params': _filter(type)});
        final items = _collect(data);
        if (items.isNotEmpty) {
          return SonarMusicPage(items: items, nextToken: _nextToken(data));
        }
      } catch (e) {
        await AppLogger.log('SonarMusic direct search failed; PHP fallback: $e');
      }
    }
    final data = await _server({'q': query, 'type': type, 'page': '$page',
      if (token != null && token.isNotEmpty) 'token': token});
    return _fromServer(data);
  }

  Future<SonarMusicPage> browse(String browseId, {String? token, int page = 1}) async {
    final id = browseId.startsWith('VL') || browseId.startsWith('MPRE') ||
        browseId.startsWith('UC') || browseId.startsWith('MPSP') || browseId.startsWith('MPED')
        ? browseId : 'VL$browseId';
    if (directCatalog) {
      try {
        final data = await _direct('browse', token != null && token.isNotEmpty
            ? {'continuation': token} : {'browseId': id});
        final items = _collect(data);
        if (items.isNotEmpty) {
          return SonarMusicPage(items: items,
              title: _readText(_map(_map(data['header'])?['musicImmersiveHeaderRenderer'])?['title']),
              nextToken: _nextToken(data));
        }
      } catch (e) {
        await AppLogger.log('SonarMusic direct browse failed; PHP fallback: $e');
      }
    }
    final data = await _server({'browse': id, 'page': '$page',
      if (token != null && token.isNotEmpty) 'token': token});
    return _fromServer(data);
  }

  Future<List<String>> suggestions(String query) async {
    try {
      final data = await _server({'suggest': query});
      return ((data['suggestions'] as List?) ?? [])
          .whereType<String>().toList(growable: false);
    } catch (_) { return const []; }
  }

  Future<SonarMusicItem> openUrl(String input) async {
    final raw = input.trim();
    final video = _tube.youtubeVideoIdFromInput(raw);
    if (video != null) {
      return SonarMusicItem(kind: 'video', id: video,
        title: 'YouTube Music', videoId: video,
        url: 'https://music.youtube.com/watch?v=$video');
    }
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.host.endsWith('youtube.com')) {
      final list = uri.queryParameters['list'];
      if (list != null && list.isNotEmpty) {
        return SonarMusicItem(kind: 'playlist',
          id: 'VL$list', browseId: 'VL$list', title: 'Playlist', url: raw);
      }
      final parts = uri.pathSegments;
      if (parts.length >= 2 && (parts.first == 'browse' || parts.first == 'channel')) {
        return SonarMusicItem(kind: parts.first == 'channel' ? 'artist' : 'album',
          id: parts[1], browseId: parts[1], title: 'YouTube Music', url: raw);
      }
    }
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(raw)) {
      return SonarMusicItem(
        kind: 'song', id: raw, videoId: raw, title: 'YouTube Music');
    }
    if (RegExp(r'^(MPRE|UC|VL|PL|OLAK5uy_|RD)[A-Za-z0-9_-]+$').hasMatch(raw)) {
      final id = raw.startsWith('PL') || raw.startsWith('OLAK5uy_') || raw.startsWith('RD') ? 'VL$raw' : raw;
      return SonarMusicItem(kind: id.startsWith('UC') ? 'artist' : id.startsWith('MPRE') ? 'album' : 'playlist',
        id: id, browseId: id, title: 'YouTube Music');
    }
    throw const FormatException('Inserire un URL YouTube Music valido');
  }

  Future<SonarTubeResolvedMedia> resolve(SonarMusicItem song) async {
    if (!song.playable) throw const FormatException('Brano non riproducibile');
    // Existing native Dart InnerTube player first; music PHP only if it fails.
    try {
      final direct = await _tube.resolveUrl(
        'https://music.youtube.com/watch?v=${song.videoId}',
        fallbackTitle: song.title, fallbackChannel: song.artist);
      if (direct.audioUrl.isNotEmpty) return direct;
    } catch (e) {
      await AppLogger.log('SonarMusic Dart player failed id=${song.videoId}; music PHP fallback: $e');
    }
    final data = await _server({'url': song.videoId!, 'quality': 'audio'});
    final stream = data['stream_audio']?.toString() ?? data['stream']?.toString() ?? '';
    if (stream.isEmpty) throw const FormatException('Audio musicale non disponibile');
    return SonarTubeResolvedMedia(title: data['title']?.toString() ?? song.title,
      audioUrl: stream, videoUrl: null,
      channel: data['artist']?.toString() ?? song.artist);
  }

  SonarMusicPage _fromServer(Map<String, dynamic> data) {
    final result = <SonarMusicItem>[];
    final seen = <String>{};
    void add(Object? items) {
      if (items is! List) return;
      for (final raw in items) {
        if (raw is! Map) continue;
        final item = SonarMusicItem.fromJson(Map<String, dynamic>.from(raw));
        if (item.id.isNotEmpty && seen.add(item.key)) result.add(item);
      }
    }
    add(data['items']);
    if (result.isEmpty) {
      final sections = data['sections'];
      if (sections is List) {
        for (final section in sections) {
          if (section is Map) {
            add(section['items']);
          }
        }
      }
    }
    return SonarMusicPage(items: result,
      nextToken: data['next_token']?.toString(),
      title: data['title']?.toString(), description: data['description']?.toString());
  }

  static Map<String, dynamic>? _map(Object? obj) => obj is Map
      ? Map<String, dynamic>.from(obj) : null;
  static String _readText(Object? raw) {
    if (raw is String) return raw;
    final m = _map(raw);
    if (m == null) return '';
    if (m['simpleText'] is String) return m['simpleText'] as String;
    final runs = m['runs'];
    if (runs is List) return runs.map((e) => _map(e)?['text']?.toString() ?? '').join();
    return '';
  }
  static Map<String, dynamic>? _endpoint(Object? raw, String key) {
    final navigation = _map(_map(raw)?['navigationEndpoint']);
    return _map(navigation?[key]);
  }
  static String? _str(Object? raw) => raw == null || raw.toString().trim().isEmpty
      ? null : raw.toString();

  List<SonarMusicItem> _collect(Map<String, dynamic> data) {
    final results = <SonarMusicItem>[];
    final seen = <String>{};
    void add(SonarMusicItem? item) {
      if (item != null && item.id.isNotEmpty && item.title.isNotEmpty && seen.add(item.key)) {
        results.add(item);
      }
    }
    void walk(Object? node, [int depth = 0]) {
      if (depth > 32 || node == null) return;
      if (node is List) { for (final v in node) { walk(v, depth + 1); } return; }
      final m = _map(node);
      if (m == null) return;
      final row = _map(m['musicResponsiveListItemRenderer']);
      if (row != null) add(_parseRow(row));
      final card = _map(m['musicTwoRowItemRenderer']);
      if (card != null) add(_parseTwoRow(card));
      final top = _map(m['musicCardShelfRenderer']);
      if (top != null) add(_parseTwoRow(top));
      for (final e in m.entries) {
        if (e.key == 'menu' || e.key == 'navigationEndpoint' || e.key == 'trackingParams') continue;
        if (e.value is List || e.value is Map) walk(e.value, depth + 1);
      }
    }
    walk(data);
    return results;
  }

  SonarMusicItem? _parseRow(Map<String, dynamic> row) {
    final columns = (row['flexColumns'] as List?) ?? const [];
    if (columns.isEmpty) return null;
    final first = _map(_map(columns[0])?['musicResponsiveListItemFlexColumnRenderer']);
    final title = _readText(first?['text']);
    if (title.isEmpty) return null;
    final meta = <String>[];
    String? artist, artistId, albumId;
    for (final column in columns.skip(1)) {
      final text = _map(_map(column)?['musicResponsiveListItemFlexColumnRenderer'])?['text'];
      final s = _readText(text);
      if (s.isNotEmpty) meta.add(s);
      final runs = _map(text)?['runs'];
      if (runs is List) {
        for (final r in runs) {
          final run = _map(r);
          final browser = _endpoint(run, 'browseEndpoint');
          final id = _str(browser?['browseId']);
          if (id != null && id.startsWith('UC')) { artist ??= _str(run?['text']); artistId ??= id; }
          if (id != null && id.startsWith('MPRE')) albumId ??= id;
        }
      }
    }
    final fixed = row['fixedColumns'];
    String? duration;
    if (fixed is List) {
      for (final column in fixed) {
        final t = _readText(_map(_map(column)?['musicResponsiveListItemFixedColumnRenderer'])?['text']);
        if (RegExp(r'^\d+:\d\d(?::\d\d)?$').hasMatch(t)) duration = t;
      }
    }
    final navigation = _map(row['navigationEndpoint']);
    final browser = _map(navigation?['browseEndpoint']);
    final browseId = _str(browser?['browseId']);
    final overlay = _map(_map(_map(row['overlay'])?['musicItemThumbnailOverlayRenderer'])?['content']);
    final play = _map(_map(overlay?['musicPlayButtonRenderer'])?['playNavigationEndpoint']);
    final watch = _map(navigation?['watchEndpoint']) ?? _map(play?['watchEndpoint']);
    final videoId = _str(row['playlistItemData'] is Map ? (row['playlistItemData'] as Map)['videoId'] : null)
        ?? _str(watch?['videoId']);
    final videoType = _str(_map(_map(watch?['watchEndpointMusicSupportedConfigs'])?['watchEndpointMusicConfig'])?['musicVideoType']) ?? '';
    final kind = browseId?.startsWith('UC') == true && videoId == null ? 'artist'
      : browseId?.startsWith('MPRE') == true && videoId == null ? 'album'
      : browseId != null && (browseId.startsWith('VL') || browseId.startsWith('PL')) && videoId == null ? 'playlist'
      : videoType.contains('OMV') || videoType.contains('UGC') ? 'video'
      : videoId != null ? 'song' : 'unknown';
    if (kind == 'unknown') return null;
    final id = videoId ?? browseId!;
    final thumb = _map(_map(row['thumbnail'])?['musicThumbnailRenderer']);
    return SonarMusicItem(kind: kind, id: id, title: title, videoId: videoId,
      browseId: browseId, artist: artist ?? (meta.isNotEmpty ? meta.first.split(' • ').first : null),
      artistId: artistId, albumId: albumId, duration: duration,
      subtitle: meta.join(' • '), thumbnail: _thumb(thumb?['thumbnail']),
      url: videoId != null ? 'https://music.youtube.com/watch?v=$videoId' : null);
  }

  SonarMusicItem? _parseTwoRow(Map<String, dynamic> row) {
    final title = _readText(row['title']);
    if (title.isEmpty) return null;
    final titleRuns = _map(row['title'])?['runs'];
    final firstTitleRun = titleRuns is List && titleRuns.isNotEmpty ? titleRuns.first : null;
    final nav = _map(row['navigationEndpoint']) ??
      _map(_map(firstTitleRun)?['navigationEndpoint']) ??
      _map(row['onTap']);
    final browse = _map(nav?['browseEndpoint']);
    final browseId = _str(browse?['browseId']);
    final videoId = _str(_map(nav?['watchEndpoint'])?['videoId']);
    final kind = browseId?.startsWith('UC') == true ? 'artist'
      : browseId?.startsWith('MPRE') == true ? 'album'
      : browseId != null && (browseId.startsWith('VL') || browseId.startsWith('PL') || browseId.startsWith('RD')) ? 'playlist'
      : videoId != null ? 'song' : 'unknown';
    if (kind == 'unknown') return null;
    final thumbRenderer = _map(row['thumbnailRenderer']);
    return SonarMusicItem(kind: kind, id: videoId ?? browseId!,
      videoId: videoId, browseId: browseId, title: title,
      subtitle: _readText(row['subtitle']),
      artist: kind == 'artist' ? title : null,
      artistId: kind == 'artist' ? browseId : null,
      thumbnail: _thumb(_map(thumbRenderer?['musicThumbnailRenderer'])?['thumbnail'] ?? thumbRenderer?['thumbnail']),
      url: videoId != null ? 'https://music.youtube.com/watch?v=$videoId' : null);
  }

  static String? _thumb(Object? raw) {
    final data = _map(raw);
    final options = data?['thumbnails'];
    if (options is! List || options.isEmpty) return null;
    for (final item in options.reversed) {
      final url = _str(_map(item)?['url']);
      if (url != null) return url;
    }
    return null;
  }
  static String? _nextToken(Map<String, dynamic> data) {
    String? found;
    void walk(Object? node, [int depth = 0]) {
      if (found != null || depth > 32) return;
      if (node is List) { for (final v in node) { walk(v, depth + 1); } return; }
      final m = _map(node);
      if (m == null) return;
      final cont = _map(m['nextContinuationData']);
      if (_str(cont?['continuation']) != null) {
        found = cont!['continuation'] as String; return;
      }
      for (final value in m.values) {
        if (value is Map || value is List) walk(value, depth + 1);
      }
    }
    walk(data);
    return found;
  }
}

/// Adapts SonarMusic resolving to the existing SonarTube export workflow.
/// It never alters SonarTube's global resolver or settings.
class SonarMusicTubeAdapter extends SonarTubeService {
  SonarMusicTubeAdapter(this.music);
  final SonarMusicService music;
  @override
  Future<SonarTubeResolvedMedia> resolve(SonarTubeItem item) =>
    music.resolve(SonarMusicItem(kind: 'song', id: item.id,
      videoId: item.id, title: item.title, artist: item.channel,
      url: item.url, duration: item.duration));
}
