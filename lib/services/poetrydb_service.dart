import 'dart:convert';

import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_lookup.dart';

class PoetryDbRequestException implements Exception {
  final int statusCode;

  const PoetryDbRequestException(this.statusCode);

  String localizedMessage(AppLocalizations l10n) =>
      l10n.poetryDbHttpError(statusCode);

  @override
  String toString() => localizedMessage(lookupSupportedAppLocalizations('it'));
}

enum PoetryDbSearchField { title, author }

class PoetryDbPoem {
  final String title;
  final String author;
  final List<String> lines;
  final int lineCount;

  const PoetryDbPoem({
    required this.title,
    required this.author,
    required this.lines,
    required this.lineCount,
  });

  String titleLabel(AppLocalizations l10n) =>
      title.trim().isEmpty ? l10n.catalogUntitled : title;

  String authorLabel(AppLocalizations l10n) =>
      author.trim().isEmpty ? l10n.catalogUnknownAuthor : author;

  String toDocumentText({AppLocalizations? localizations}) {
    final l10n = localizations ?? lookupSupportedAppLocalizations('it');
    final buffer = StringBuffer()
      ..writeln(titleLabel(l10n))
      ..writeln(authorLabel(l10n))
      ..writeln();
    for (final line in lines) {
      buffer.writeln(line);
    }
    return buffer.toString().trim();
  }
}

class PoetryDbService {
  final http.Client _client;

  PoetryDbService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PoetryDbPoem>> search(
    String query, {
    required PoetryDbSearchField field,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final inputField = switch (field) {
      PoetryDbSearchField.title => 'title',
      PoetryDbSearchField.author => 'author',
    };
    final uri = Uri.https(
      'poetrydb.org',
      '/$inputField/$trimmed',
    );
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'SonarpadMobile/0.1'},
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PoetryDbRequestException(response.statusCode);
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is Map<String, dynamic>) {
      final status = decoded['status'];
      if (status is int && status == 404) return const [];
      return const [];
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_poemFromJson)
        .where((poem) => poem.lines.isNotEmpty)
        .toList();
  }

  PoetryDbPoem _poemFromJson(Map<String, dynamic> json) {
    return PoetryDbPoem(
      title: _stringValue(json['title']),
      author: _stringValue(json['author']),
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      lineCount: _intValue(json['linecount']),
    );
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _stringValue(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }
}
