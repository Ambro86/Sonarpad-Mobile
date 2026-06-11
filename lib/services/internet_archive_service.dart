import 'dart:convert';

import 'package:http/http.dart' as http;

enum InternetArchiveSource { oldTimeRadio, speeches, liveMusic }

class InternetArchivePage {
  final List<InternetArchiveItem> items;
  final bool hasMore;

  const InternetArchivePage({required this.items, required this.hasMore});
}

class InternetArchiveItem {
  final String identifier;
  final String title;
  final String creator;
  final String description;
  final InternetArchiveSource source;
  final List<InternetArchiveTrack> tracks;

  const InternetArchiveItem({
    required this.identifier,
    required this.title,
    required this.creator,
    required this.description,
    required this.source,
    required this.tracks,
  });

  String get creatorLabel => creator.isEmpty ? identifier : creator;

  Map<String, dynamic> toLibraryJson() => {
        'identifier': identifier,
        'title': title,
        'creator': creator,
        'description': description,
        'source': source.name,
        'tracks': tracks.map((track) => track.toJson()).toList(),
      };

  factory InternetArchiveItem.fromLibraryJson(Map<String, dynamic> json) {
    final sourceName = _stringValue(json['source']);
    return InternetArchiveItem(
      identifier: _stringValue(json['identifier']),
      title: _stringValue(json['title'], fallback: 'Internet Archive'),
      creator: _stringValue(json['creator']),
      description: _stringValue(json['description']),
      source: InternetArchiveSource.values.firstWhere(
        (source) => source.name == sourceName,
        orElse: () => InternetArchiveSource.oldTimeRadio,
      ),
      tracks: (json['tracks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(InternetArchiveTrack.fromJson)
          .toList(),
    );
  }

  String encodeForLibrary() => jsonEncode(toLibraryJson());
}

class InternetArchiveTrack {
  final String title;
  final String fileName;
  final String audioUrl;
  final String format;
  final String length;

  const InternetArchiveTrack({
    required this.title,
    required this.fileName,
    required this.audioUrl,
    required this.format,
    required this.length,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'fileName': fileName,
        'audioUrl': audioUrl,
        'format': format,
        'length': length,
      };

  factory InternetArchiveTrack.fromJson(Map<String, dynamic> json) =>
      InternetArchiveTrack(
        title: _stringValue(json['title'], fallback: 'Audio'),
        fileName: _stringValue(json['fileName']),
        audioUrl: _stringValue(json['audioUrl']),
        format: _stringValue(json['format']),
        length: _stringValue(json['length']),
      );
}

InternetArchiveItem internetArchiveItemFromLibraryPath(String value) {
  final decoded = jsonDecode(value) as Map<String, dynamic>;
  return InternetArchiveItem.fromLibraryJson(decoded);
}

class InternetArchiveService {
  final http.Client _client;

  InternetArchiveService({http.Client? client})
      : _client = client ?? http.Client();

  Future<InternetArchivePage> searchItems({
    required InternetArchiveSource source,
    required String query,
    int page = 1,
    int rows = 50,
  }) async {
    final uri = Uri.parse(
      'https://archive.org/advancedsearch.php?'
      '${_queryString({
        'q': [_searchQuery(source, query)],
        'output': ['json'],
        'page': ['$page'],
        'rows': ['$rows'],
        'sort[]': ['downloads desc'],
        'fl[]': ['identifier', 'title', 'creator', 'description'],
      })}',
    );

    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'SonarpadMobile/0.1'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Internet Archive ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
    final responseBody = decoded['response'] as Map<String, dynamic>? ?? {};
    final rawDocs = responseBody['docs'];
    final items = rawDocs is List
        ? rawDocs
            .whereType<Map<String, dynamic>>()
            .map((json) => _itemFromSearchJson(json, source))
            .toList()
        : <InternetArchiveItem>[];
    final total = _intValue(responseBody['numFound']);
    return InternetArchivePage(
      items: items,
      hasMore: page * rows < total,
    );
  }

  Future<InternetArchiveItem> fetchItem(
    InternetArchiveItem item,
  ) async {
    final uri = Uri.https('archive.org', '/metadata/${item.identifier}');
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'SonarpadMobile/0.1'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Internet Archive ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
    final files = decoded['files'];
    final tracks = files is List
        ? files
            .whereType<Map<String, dynamic>>()
            .map((json) => _trackFromFileJson(item.identifier, json))
            .whereType<InternetArchiveTrack>()
            .toList()
        : <InternetArchiveTrack>[];
    return InternetArchiveItem(
      identifier: item.identifier,
      title: item.title,
      creator: item.creator,
      description: item.description,
      source: item.source,
      tracks: tracks,
    );
  }

  InternetArchiveItem _itemFromSearchJson(
    Map<String, dynamic> json,
    InternetArchiveSource source,
  ) {
    final identifier = _stringValue(json['identifier']);
    return InternetArchiveItem(
      identifier: identifier,
      title: _stringValue(json['title'], fallback: identifier),
      creator: _stringValue(json['creator']),
      description: _stringValue(json['description']),
      source: source,
      tracks: const [],
    );
  }

  InternetArchiveTrack? _trackFromFileJson(
    String identifier,
    Map<String, dynamic> json,
  ) {
    final name = _stringValue(json['name']);
    if (name.isEmpty) return null;
    final format = _stringValue(json['format']);
    if (!_isAudioFormat(format, name)) return null;
    return InternetArchiveTrack(
      title: _stringValue(json['title'], fallback: _displayFileName(name)),
      fileName: name,
      audioUrl: Uri.https('archive.org', '/download/$identifier/$name')
          .toString(),
      format: format,
      length: _stringValue(json['length']),
    );
  }

  bool _isAudioFormat(String format, String name) {
    final lowerFormat = format.toLowerCase();
    final lowerName = name.toLowerCase();
    return lowerFormat.contains('vbr mp3') ||
        lowerFormat == 'mp3' ||
        lowerFormat.contains('ogg') ||
        lowerName.endsWith('.mp3') ||
        lowerName.endsWith('.ogg');
  }

  String _searchQuery(InternetArchiveSource source, String query) {
    final base = switch (source) {
      InternetArchiveSource.oldTimeRadio =>
        'collection:oldtimeradio AND mediatype:audio',
      InternetArchiveSource.liveMusic =>
        'collection:etree AND mediatype:audio',
      InternetArchiveSource.speeches =>
        'mediatype:audio AND (subject:speech OR title:speech OR description:speech)',
    };
    final trimmed = query.trim();
    if (trimmed.isEmpty) return base;
    final escaped = trimmed.replaceAll('"', '');
    return '$base AND '
        '(title:"$escaped" OR creator:"$escaped" OR description:"$escaped")';
  }

  String _displayFileName(String name) {
    final lastSlash = name.lastIndexOf('/');
    final basename = lastSlash >= 0 ? name.substring(lastSlash + 1) : name;
    final dot = basename.lastIndexOf('.');
    return dot > 0 ? basename.substring(0, dot) : basename;
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _queryString(Map<String, List<String>> values) {
    final parts = <String>[];
    for (final entry in values.entries) {
      for (final value in entry.value) {
        parts.add(
          '${Uri.encodeQueryComponent(entry.key)}='
          '${Uri.encodeQueryComponent(value)}',
        );
      }
    }
    return parts.join('&');
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is List && value.isNotEmpty) {
    return _stringValue(value.first, fallback: fallback);
  }
  return fallback;
}
