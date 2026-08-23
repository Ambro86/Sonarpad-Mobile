import 'dart:convert';

import 'package:http/http.dart' as http;

enum SonarTubeItemKind { video, channel, playlist }

class SonarTubeItem {
  const SonarTubeItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.url,
    this.channel,
    this.thumbnailUrl,
    this.duration,
    this.published,
    this.views,
    this.description,
    this.isLive = false,
  });

  final SonarTubeItemKind kind;
  final String id;
  final String title;
  final String url;
  final String? channel;
  final String? thumbnailUrl;
  final String? duration;
  final String? published;
  final String? views;
  final String? description;
  final bool isLive;
}

class SonarTubePage {
  const SonarTubePage({
    required this.items,
    required this.page,
    this.nextToken,
  });

  final List<SonarTubeItem> items;
  final int page;
  final String? nextToken;

  bool get hasMore => nextToken != null && nextToken!.isNotEmpty;
}

class SonarTubeResolvedMedia {
  const SonarTubeResolvedMedia({
    required this.title,
    required this.audioUrl,
    this.videoUrl,
    this.channel,
  });

  final String title;
  final String audioUrl;
  final String? videoUrl;
  final String? channel;
}

class SonarTubeService {
  static const _compiledClientToken = String.fromEnvironment(
    'SONARPAD_ROUTE_CLIENT_TOKEN',
  );

  SonarTubeService({http.Client? client, Uri? endpoint, String? clientToken})
    : _client = client ?? http.Client(),
      endpoint =
          endpoint ?? Uri.parse('https://sonarpad.com/api/youtube_resolve.php'),
      _clientToken = clientToken ?? _compiledClientToken;

  final http.Client _client;
  final Uri endpoint;
  final String _clientToken;

  Future<SonarTubePage> search(String query, {String? token, int page = 1}) {
    return _loadPage({
      'q': query,
      'type': 'all',
      'format': 'json',
      if (token != null && token.isNotEmpty) 'token': token,
      'page': '$page',
    });
  }

  Future<SonarTubePage> browse(
    SonarTubeItem collection, {
    String? token,
    int page = 1,
  }) {
    if (collection.kind == SonarTubeItemKind.video) {
      throw ArgumentError('Un video non è una raccolta SonarTube.');
    }
    final seedVideoId = _mixSeedVideoId(collection);
    return _loadPage({
      'browse': collection.id,
      'kind': collection.kind.name,
      'title': collection.title,
      'format': 'json',
      'seed': ?seedVideoId,
      if (token != null && token.isNotEmpty) 'token': token,
      'page': '$page',
    });
  }

  String? _mixSeedVideoId(SonarTubeItem collection) {
    if (collection.kind != SonarTubeItemKind.playlist ||
        !collection.id.startsWith('RD')) {
      return null;
    }
    final uri = Uri.tryParse(collection.url);
    final seed = uri?.queryParameters['v'];
    if (seed != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(seed)) {
      return seed;
    }
    if (collection.id.length == 13) {
      final derived = collection.id.substring(2);
      if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(derived)) {
        return derived;
      }
    }
    return null;
  }

  Future<SonarTubeResolvedMedia> resolve(SonarTubeItem item) {
    if (item.kind != SonarTubeItemKind.video) {
      throw ArgumentError('È possibile risolvere soltanto un video.');
    }
    return resolveUrl(
      item.url.isEmpty ? item.id : item.url,
      fallbackTitle: item.title,
      fallbackChannel: item.channel,
    );
  }

  Future<SonarTubeResolvedMedia> resolveUrl(
    String url, {
    required String fallbackTitle,
    String? fallbackChannel,
  }) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      throw ArgumentError.value(url, 'url');
    }
    final data = await _request({
      'url': trimmedUrl,
      'quality': 'best',
      'prefer': 'auto',
      'format': 'json',
    });

    final stream = _string(data['stream']);
    final streamVideo = _string(data['stream_video']);
    final streamAudio = _string(data['stream_audio']);
    if (stream == null) {
      throw const FormatException('Nessun flusso riproducibile disponibile.');
    }

    final hasSeparateStreams =
        streamVideo != null && streamAudio != null && stream == streamVideo;
    return SonarTubeResolvedMedia(
      title: _string(data['title']) ?? fallbackTitle,
      channel: _string(data['channel']) ?? fallbackChannel,
      audioUrl: hasSeparateStreams ? streamAudio : stream,
      videoUrl: hasSeparateStreams ? streamVideo : null,
    );
  }

  Future<SonarTubePage> _loadPage(Map<String, String> query) async {
    final data = await _request(query);
    final rawItems = data['items'] is List
        ? data['items'] as List
        : data['videos'] is List
        ? data['videos'] as List
        : const [];
    final items = rawItems
        .whereType<Map>()
        .map((raw) => _parseItem(Map<String, dynamic>.from(raw)))
        .whereType<SonarTubeItem>()
        .toList(growable: false);
    return SonarTubePage(
      items: items,
      page: _int(data['page']) ?? 1,
      nextToken: _string(data['next_token']),
    );
  }

  Future<Map<String, dynamic>> _request(Map<String, String> query) async {
    final uri = endpoint.replace(
      queryParameters: {...endpoint.queryParameters, ...query},
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (_clientToken.isNotEmpty) 'X-Sonarpad-Route-Token': _clientToken,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('Risposta SonarTube non valida.');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['ok'] != true) {
      final detail = _string(data['detail']);
      final error = _string(data['error']) ?? 'Errore SonarTube';
      throw Exception(detail == null ? error : '$error: $detail');
    }
    return data;
  }

  SonarTubeItem? _parseItem(Map<String, dynamic> raw) {
    final kind = switch (_string(raw['kind'])) {
      'video' => SonarTubeItemKind.video,
      'channel' => SonarTubeItemKind.channel,
      'playlist' => SonarTubeItemKind.playlist,
      _ => null,
    };
    final id = _string(raw['id']);
    final title = _string(raw['title']);
    if (kind == null || id == null || title == null) return null;
    return SonarTubeItem(
      kind: kind,
      id: id,
      title: title,
      url: _string(raw['url']) ?? '',
      channel: _string(raw['channel']),
      thumbnailUrl: _string(raw['thumbnail']),
      duration: _string(raw['duration']),
      published: _string(raw['published']),
      views: _string(raw['views']),
      description: _string(raw['description']),
      isLive: raw['live'] == true,
    );
  }

  String? _string(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
