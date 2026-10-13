import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_lookup.dart';
import '../utils/app_logger.dart';

enum GutendexFailureKind {
  searchHttp,
  downloadHttp,
  epubDownloadHttp,
  invalidId,
  downloadTimeout,
  unreadableArchive,
}

class GutendexException implements Exception {
  final GutendexFailureKind kind;
  final int? statusCode;

  const GutendexException.searchHttp(int code)
      : kind = GutendexFailureKind.searchHttp,
        statusCode = code;
  const GutendexException.downloadHttp(int code)
      : kind = GutendexFailureKind.downloadHttp,
        statusCode = code;
  const GutendexException.epubDownloadHttp(int code)
      : kind = GutendexFailureKind.epubDownloadHttp,
        statusCode = code;
  const GutendexException.invalidId()
      : kind = GutendexFailureKind.invalidId,
        statusCode = null;
  const GutendexException.downloadTimeout()
      : kind = GutendexFailureKind.downloadTimeout,
        statusCode = null;
  const GutendexException.unreadableArchive()
      : kind = GutendexFailureKind.unreadableArchive,
        statusCode = null;

  String localizedMessage(AppLocalizations l10n) => switch (kind) {
        GutendexFailureKind.searchHttp =>
          l10n.gutenbergSearchHttpError(statusCode!),
        GutendexFailureKind.downloadHttp =>
          l10n.gutenbergDownloadHttpError(statusCode!),
        GutendexFailureKind.epubDownloadHttp =>
          l10n.gutenbergEpubDownloadHttpError(statusCode!),
        GutendexFailureKind.invalidId => l10n.gutenbergInvalidBookId,
        GutendexFailureKind.downloadTimeout => l10n.gutenbergDownloadTimeout,
        GutendexFailureKind.unreadableArchive => l10n.gutenbergUnreadableArchive,
      };

  @override
  String toString() => localizedMessage(lookupSupportedAppLocalizations('it'));
}

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

  String titleLabel(AppLocalizations l10n) =>
      title.trim().isEmpty ? l10n.gutenbergUntitledBook : title;

  String authorLabel(AppLocalizations l10n) =>
      authors.isEmpty ? l10n.gutenbergUnknownAuthor : authors.join(', ');

  String get languageLabel => languages.join(', ');
}

class GutendexDownload {
  final String fileName;
  final List<int>? bytes;
  final String? text;

  const GutendexDownload._({
    required this.fileName,
    this.bytes,
    this.text,
  });

  const GutendexDownload.file({
    required String fileName,
    required List<int> bytes,
  }) : this._(fileName: fileName, bytes: bytes);

  const GutendexDownload.text({
    required String fileName,
    required String text,
  }) : this._(fileName: fileName, text: text);

  bool get isFile => bytes != null;
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
      throw GutendexException.searchHttp(response.statusCode);
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
    final url = _sonarpadDownloadUrl(book, 'txt');
    final response = await _download(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GutendexException.downloadHttp(response.statusCode);
    }
    return _cleanGutenbergText(_decodeDownloadedText(response.bodyBytes, url));
  }

  Future<GutendexDownload> downloadForImport(
    GutendexBook book, {
    AppLocalizations? localizations,
  }) async {
    final url = _sonarpadDownloadUrl(book, 'epub');
    await AppLogger.log('Gutenberg download: Sonarpad EPUB $url');
    final response = await _download(url);
    await AppLogger.log(
      'Gutenberg download: Sonarpad EPUB status=${response.statusCode} bytes=${response.bodyBytes.length}',
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final title = book.titleLabel(
        localizations ?? lookupSupportedAppLocalizations('it'),
      );
      return GutendexDownload.file(
        fileName: '$title.epub',
        bytes: response.bodyBytes,
      );
    }
    throw GutendexException.epubDownloadHttp(response.statusCode);
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
      title: json['title'] as String? ?? '',
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

  String _sonarpadDownloadUrl(GutendexBook book, String format) {
    if (book.id <= 0) {
      throw const GutendexException.invalidId();
    }
    return Uri.https('sonarpad.com', '/api/gutenberg/download.php', {
      'id': book.id.toString(),
      'format': format,
    }).toString();
  }

  Future<http.Response> _download(String url) async {
    try {
      await AppLogger.log('Gutenberg download: GET $url');
      return await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': 'SonarpadMobile/0.1'},
      ).timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw const GutendexException.downloadTimeout();
    }
  }

  String _decodeDownloadedText(List<int> bytes, String sourceUrl) {
    if (_isZipUrl(sourceUrl) || _looksLikeZip(bytes)) {
      return _decodeTextFromZip(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  bool _isZipUrl(String value) {
    final uri = Uri.tryParse(value);
    final path = (uri?.path ?? value).toLowerCase();
    return path.endsWith('.zip');
  }

  bool _looksLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  String _decodeTextFromZip(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = archive.files.where((file) => file.isFile).toList()
      ..sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final aText = aName.endsWith('.txt') ? 0 : 1;
        final bText = bName.endsWith('.txt') ? 0 : 1;
        if (aText != bText) return aText.compareTo(bText);
        return aName.compareTo(bName);
      });

    for (final file in files) {
      final content = file.content;
      if (content is! List<int>) continue;
      final text = utf8.decode(content, allowMalformed: true).trim();
      if (text.isNotEmpty) return text;
    }

    throw const GutendexException.unreadableArchive();
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
