import 'dart:convert';

import 'package:http/http.dart' as http;

class LibrivoxPage {
  final List<LibrivoxBook> books;
  final bool hasMore;

  const LibrivoxPage({
    required this.books,
    required this.hasMore,
  });
}

class LibrivoxBook {
  final int id;
  final String title;
  final String description;
  final String language;
  final String totalTime;
  final String urlLibrivox;
  final String? coverArtUrl;
  final List<String> authors;
  final List<LibrivoxTrack> sections;

  const LibrivoxBook({
    required this.id,
    required this.title,
    required this.description,
    required this.language,
    required this.totalTime,
    required this.urlLibrivox,
    required this.coverArtUrl,
    required this.authors,
    required this.sections,
  });

  String get authorLabel =>
      authors.isEmpty ? 'Autore sconosciuto' : authors.join(', ');

  Map<String, dynamic> toLibraryJson() => {
        'id': id,
        'title': title,
        'description': description,
        'language': language,
        'totalTime': totalTime,
        'urlLibrivox': urlLibrivox,
        if (coverArtUrl != null) 'coverArtUrl': coverArtUrl,
        'authors': authors,
        'sections': sections.map((track) => track.toJson()).toList(),
      };

  factory LibrivoxBook.fromLibraryJson(Map<String, dynamic> json) =>
      LibrivoxBook(
        id: _parseInt(json['id']),
        title: _parseString(json['title'], fallback: 'Senza titolo'),
        description: _parseString(json['description']),
        language: _parseString(json['language']),
        totalTime: _parseString(json['totalTime']),
        urlLibrivox: _parseString(json['urlLibrivox']),
        coverArtUrl: _parseNullableString(json['coverArtUrl']),
        authors: (json['authors'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        sections: (json['sections'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LibrivoxTrack.fromJson)
            .toList(),
      );

  String encodeForLibrary() => jsonEncode(toLibraryJson());
}

class LibrivoxTrack {
  final int id;
  final int number;
  final String title;
  final String listenUrl;
  final String playTime;

  const LibrivoxTrack({
    required this.id,
    required this.number,
    required this.title,
    required this.listenUrl,
    required this.playTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'title': title,
        'listenUrl': listenUrl,
        'playTime': playTime,
      };

  factory LibrivoxTrack.fromJson(Map<String, dynamic> json) => LibrivoxTrack(
        id: _parseInt(json['id']),
        number: _parseInt(json['number']),
        title: _parseString(json['title'], fallback: 'Capitolo'),
        listenUrl: _parseString(json['listenUrl']),
        playTime: _parseString(json['playTime']),
      );
}

LibrivoxBook librivoxBookFromLibraryPath(String value) {
  final decoded = jsonDecode(value) as Map<String, dynamic>;
  return LibrivoxBook.fromLibraryJson(decoded);
}

class LibrivoxService {
  final http.Client _client;

  LibrivoxService({http.Client? client}) : _client = client ?? http.Client();

  Future<LibrivoxPage> searchBooks(
    String query, {
    int offset = 0,
    int limit = 50,
  }) async {
    final params = {
      'format': 'json',
      'extended': '1',
      'coverart': '1',
      'limit': '$limit',
      'offset': '$offset',
      if (query.trim().isNotEmpty) 'title': query.trim(),
    };
    final uri = Uri.https(
      'librivox.org',
      '/api/feed/audiobooks',
      params,
    );
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'SonarpadMobile/0.1'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore LibriVox ${response.statusCode}');
    }

    final books = _booksFromResponse(response.bodyBytes);
    return LibrivoxPage(
      books: books,
      hasMore: books.length >= limit,
    );
  }

  Future<LibrivoxBook> fetchBook(int id) async {
    final uri = Uri.https('librivox.org', '/api/feed/audiobooks', {
      'format': 'json',
      'extended': '1',
      'coverart': '1',
      'id': '$id',
    });
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'SonarpadMobile/0.1'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore LibriVox ${response.statusCode}');
    }

    final books = _booksFromResponse(response.bodyBytes);
    if (books.isEmpty) {
      throw Exception('Audiolibro non trovato.');
    }
    return books.first;
  }

  List<LibrivoxBook> _booksFromResponse(List<int> bodyBytes) {
    final decoded = jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
    final rawBooks = decoded['books'];
    if (rawBooks is! List) return const [];
    return rawBooks
        .whereType<Map<String, dynamic>>()
        .map(_bookFromJson)
        .toList();
  }

  LibrivoxBook _bookFromJson(Map<String, dynamic> json) {
    return LibrivoxBook(
      id: _intValue(json['id']),
      title: _stringValue(json['title'], fallback: 'Senza titolo'),
      description: _stringValue(json['description']),
      language: _stringValue(json['language']),
      totalTime: _stringValue(json['totaltime']),
      urlLibrivox: _stringValue(json['url_librivox']),
      coverArtUrl: _nullableString(json['coverart_jpg']) ??
          _nullableString(json['coverart_thumbnail']),
      authors: _authorsFromJson(json['authors']),
      sections: _sectionsFromJson(json['sections']),
    );
  }

  List<String> _authorsFromJson(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((author) {
          final first = _stringValue(author['first_name']);
          final last = _stringValue(author['last_name']);
          return '$first $last'.trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();
  }

  List<LibrivoxTrack> _sectionsFromJson(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((section) => LibrivoxTrack(
              id: _intValue(section['id']),
              number: _intValue(section['section_number']),
              title: _stringValue(
                section['title'],
                fallback: 'Capitolo',
              ),
              listenUrl: _stringValue(section['listen_url']),
              playTime: _stringValue(section['playtime']),
            ))
        .where((track) => track.listenUrl.isNotEmpty)
        .toList();
  }

  int _intValue(Object? value) {
    return _parseInt(value);
  }

  String _stringValue(Object? value, {String fallback = ''}) {
    return _parseString(value, fallback: fallback);
  }

  String? _nullableString(Object? value) {
    return _parseNullableString(value);
  }
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _parseString(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

String? _parseNullableString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}
