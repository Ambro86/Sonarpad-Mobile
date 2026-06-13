import 'dart:convert';

import 'package:http/http.dart' as http;

class GutendexPage {
  final int count;
  final String? next;
  final List<GutendexBook> books;

  const GutendexPage({
    required this.count,
    required this.next,
    required this.books,
  });
}

class GutendexBook {
  final int id;
  final String title;
  final List<String> authors;
  final List<String> languages;
  final List<String> summaries;
  final Map<String, String> formats;
  final int downloadCount;

  const GutendexBook({
    required this.id,
    required this.title,
    required this.authors,
    required this.languages,
    required this.summaries,
    required this.formats,
    required this.downloadCount,
  });

  String get authorLabel =>
      authors.isEmpty ? 'Autore sconosciuto' : authors.join(', ');

  String get languageLabel => languages.join(', ');
}

class GutendexService {
  final http.Client _client;

  GutendexService({http.Client? client}) : _client = client ?? http.Client();

  Future<GutendexPage> searchBooks(
    String query, {
    String? language,
    String? pageUrl,
  }) async {
    final uri = pageUrl != null
        ? _sonarpadPageUri(pageUrl)
        : Uri.https('sonarpad.com', '/api/gutenberg/search.php', {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (language != null && language.trim().isNotEmpty)
              'lang': language.trim(),
            'page_size': '20',
          });
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'SonarpadMobile/0.1'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore Gutenberg ${response.statusCode}');
    }

    final decoded = jsonDecode(
            utf8.decode(response.bodyBytes, allowMalformed: true))
        as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_bookFromJson)
        .toList();
    final next = decoded['next'] as String?;
    return GutendexPage(
      count: decoded['count'] as int? ?? results.length,
      next: next == null ? null : _sonarpadPageUri(next).toString(),
      books: results,
    );
  }

  Future<String> downloadPlainText(GutendexBook book) async {
    final url = _plainTextUrl(book);
    if (url == null) {
      throw Exception('Nessun formato testo disponibile per questo libro.');
    }
    final response = await _client.get(
      Uri.parse(url),
      headers: {'User-Agent': 'SonarpadMobile/0.1'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore download ${response.statusCode}');
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    return _cleanGutenbergText(text);
  }

  GutendexBook _bookFromJson(Map<String, dynamic> json) {
    final authors = (json['authors'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((author) => author['name'] as String? ?? '')
        .where((name) => name.trim().isNotEmpty)
        .toList();
    final formats = <String, String>{};
    final rawFormats = json['formats'];
    if (rawFormats is Map<String, dynamic>) {
      for (final entry in rawFormats.entries) {
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty) {
          formats[entry.key] = value;
        }
      }
    }
    return GutendexBook(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Senza titolo',
      authors: authors,
      languages: (json['languages'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      summaries: (json['summaries'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      formats: formats,
      downloadCount: json['download_count'] as int? ?? 0,
    );
  }

  Uri _sonarpadPageUri(String value) {
    final uri = Uri.parse(value);
    if (uri.hasScheme) return uri;
    return Uri.parse('https://sonarpad.com').resolve(value);
  }

  String? _plainTextUrl(GutendexBook book) {
    for (final entry in book.formats.entries) {
      final key = entry.key.toLowerCase();
      final url = entry.value.toLowerCase();
      if (key.startsWith('text/plain') && !url.endsWith('.zip')) {
        return entry.value;
      }
    }
    for (final entry in book.formats.entries) {
      if (entry.key.toLowerCase().startsWith('text/plain')) {
        return entry.value;
      }
    }
    return null;
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final single = _stringValue(value);
    return single.isEmpty ? const [] : [single];
  }

  String _cleanGutenbergText(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    var start = 0;
    var end = lines.length;

    for (var i = 0; i < lines.length; i += 1) {
      final upper = lines[i].toUpperCase();
      if (upper.contains('*** START OF') || upper.contains('***START OF')) {
        start = i + 1;
        break;
      }
    }
    for (var i = start; i < lines.length; i += 1) {
      final upper = lines[i].toUpperCase();
      if (upper.contains('*** END OF') || upper.contains('***END OF')) {
        end = i;
        break;
      }
    }

    final out = StringBuffer();
    var blankRun = 0;
    for (final line in lines.sublist(start, end)) {
      final trimmed = line.trimRight();
      if (trimmed.trim().isEmpty) {
        blankRun += 1;
        if (blankRun <= 2 && out.isNotEmpty) {
          out.write('\n');
        }
        continue;
      }
      blankRun = 0;
      out.writeln(trimmed);
    }
    return out.toString().trim();
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}
