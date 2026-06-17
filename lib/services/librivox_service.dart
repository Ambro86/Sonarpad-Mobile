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
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      final books = await _fetchBooks(
        limit: limit,
        offset: offset,
      );
      return LibrivoxPage(
        books: books,
        hasMore: books.length >= limit,
      );
    }

    final terms = _searchTerms(normalizedQuery);
    if (terms.isEmpty) {
      return const LibrivoxPage(books: [], hasMore: false);
    }

    final candidates = <int, LibrivoxBook>{};
    final apiTerms = <String>{normalizedQuery, ...terms}
        .where((term) => term.trim().isNotEmpty)
        .toList();

    // LibriVox supports searches on title and author, but in practice the
    // API can be very strict depending on how the parameter is sent.  Use the
    // documented path form first, then fall back to a local scan of the
    // catalogue so searches like "wilde" or "importance" still work.
    for (final term in apiTerms) {
      final titleMatches = await _fetchBooks(
        limit: _searchCandidateLimit,
        offset: 0,
        searchField: 'title',
        searchValue: term,
      );
      for (final book in titleMatches) {
        candidates[book.id] = book;
      }

      final authorMatches = await _fetchBooks(
        limit: _searchCandidateLimit,
        offset: 0,
        searchField: 'author',
        searchValue: term,
      );
      for (final book in authorMatches) {
        candidates[book.id] = book;
      }
    }

    var catalogScanReachedEnd = true;
    var matches = _sortedMatches(candidates.values, terms);
    final targetCount = offset + limit + 1;
    if (matches.length < targetCount) {
      catalogScanReachedEnd = await _addCatalogFallbackMatches(
        candidates,
        terms,
        targetCount: targetCount,
      );
      matches = _sortedMatches(candidates.values, terms);
    }

    final start = offset.clamp(0, matches.length).toInt();
    final end = (start + limit).clamp(start, matches.length).toInt();
    return LibrivoxPage(
      books: matches.sublist(start, end),
      hasMore: end < matches.length ||
          (!catalogScanReachedEnd && matches.length >= end),
    );
  }

  List<LibrivoxBook> _sortedMatches(
    Iterable<LibrivoxBook> books,
    List<String> terms,
  ) {
    return books.where((book) => _matchesAllTerms(book, terms)).toList()
      ..sort((a, b) {
        final scoreCompare = _matchScore(b, terms).compareTo(
          _matchScore(a, terms),
        );
        if (scoreCompare != 0) return scoreCompare;
        final titleCompare = a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            );
        if (titleCompare != 0) return titleCompare;
        return a.id.compareTo(b.id);
      });
  }

  Future<bool> _addCatalogFallbackMatches(
    Map<int, LibrivoxBook> candidates,
    List<String> terms, {
    required int targetCount,
  }) async {
    var scanOffset = 0;
    var scanned = 0;
    var reachedEnd = false;

    while (scanOffset < _fallbackMaxScanBooks) {
      final books = await _fetchBooks(
        limit: _fallbackPageLimit,
        offset: scanOffset,
      );
      if (books.isEmpty) {
        reachedEnd = true;
        break;
      }

      for (final book in books) {
        if (_matchesAllTerms(book, terms)) {
          candidates[book.id] = book;
        }
      }

      final currentMatchCount = candidates.values
          .where((book) => _matchesAllTerms(book, terms))
          .length;
      if (currentMatchCount >= targetCount) {
        break;
      }

      scanned += books.length;
      scanOffset += books.length;
      if (books.length < _fallbackPageLimit) {
        reachedEnd = true;
        break;
      }
      if (scanned >= _fallbackMaxScanBooks) {
        break;
      }
    }

    return reachedEnd;
  }

  Future<List<LibrivoxBook>> _fetchBooks({
    required int limit,
    required int offset,
    String? searchField,
    String? searchValue,
  }) async {
    final params = {
      'format': 'json',
      'extended': '1',
      'coverart': '1',
      'limit': '$limit',
      'offset': '$offset',
    };
    final cleanField = searchField?.trim();
    final cleanValue = searchValue?.trim();
    final pathSegments = <String>[
      'api',
      'feed',
      'audiobooks',
      if ((cleanField == 'title' || cleanField == 'author' || cleanField == 'genre') &&
          cleanValue != null &&
          cleanValue.isNotEmpty) ...[
        cleanField!,
        cleanValue,
      ],
    ];
    final uri = Uri(
      scheme: 'https',
      host: 'librivox.org',
      pathSegments: pathSegments,
      queryParameters: params,
    );
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'SonarpadMobile/0.1'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 404) {
      return const [];
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore LibriVox ${response.statusCode}');
    }

    return _booksFromResponse(response.bodyBytes);
  }

  List<String> _searchTerms(String query) {
    final normalized = _normalizeForSearch(query);
    return normalized
        .split(RegExp(r'\s+'))
        .map((term) => term.trim())
        .where((term) => term.length > 1)
        .where((term) => !_ignoredSearchTerms.contains(term))
        .toList();
  }

  bool _matchesAllTerms(LibrivoxBook book, List<String> terms) {
    if (terms.isEmpty) return true;
    final haystack = _normalizeForSearch(
      '${book.title} ${book.authorLabel} ${book.description} ${book.language}',
    );
    final matchedTerms = terms.where(haystack.contains).length;
    if (matchedTerms == terms.length) return true;
    return terms.length >= 3 && matchedTerms >= terms.length - 1;
  }

  int _matchScore(LibrivoxBook book, List<String> terms) {
    final title = _normalizeForSearch(book.title);
    final authors = _normalizeForSearch(book.authorLabel);
    final description = _normalizeForSearch(book.description);
    var score = 0;
    for (final term in terms) {
      if (title.contains(term)) score += 4;
      if (authors.contains(term)) score += 3;
      if (description.contains(term)) score += 1;
    }
    return score;
  }

  String _normalizeForSearch(String value) {
    final lower = value.toLowerCase();
    final withoutAccents = lower
        .replaceAll(RegExp('[àáâãäåāăą]'), 'a')
        .replaceAll(RegExp('[çćĉċč]'), 'c')
        .replaceAll(RegExp('[ďđ]'), 'd')
        .replaceAll(RegExp('[èéêëēĕėęě]'), 'e')
        .replaceAll(RegExp('[ìíîïĩīĭįı]'), 'i')
        .replaceAll(RegExp('[ñńņň]'), 'n')
        .replaceAll(RegExp('[òóôõöøōŏő]'), 'o')
        .replaceAll(RegExp('[ŕŗř]'), 'r')
        .replaceAll(RegExp('[śŝşš]'), 's')
        .replaceAll(RegExp('[ùúûüũūŭůűų]'), 'u')
        .replaceAll(RegExp('[ýÿŷ]'), 'y')
        .replaceAll(RegExp('[źżž]'), 'z');
    return withoutAccents
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static const int _searchCandidateLimit = 100;
  static const int _fallbackPageLimit = 500;
  static const int _fallbackMaxScanBooks = 20000;

  static const Set<String> _ignoredSearchTerms = {
    'a',
    'an',
    'and',
    'de',
    'del',
    'della',
    'di',
    'e',
    'el',
    'gli',
    'i',
    'il',
    'in',
    'la',
    'le',
    'les',
    'of',
    'on',
    'the',
    'un',
    'una',
    'und',
  };

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
    ).timeout(const Duration(seconds: 30));
    
    if (response.statusCode == 404) {
      throw Exception('Audiolibro non trovato.');
    }
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
    final decoded = jsonDecode(utf8.decode(bodyBytes, allowMalformed: true)) as Map<String, dynamic>;
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
