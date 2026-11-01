import 'dart:convert';

import 'package:http/http.dart' as http;

class NewsTranslationHttpError extends StateError {
  NewsTranslationHttpError(this.statusCode) : super('translation_http_error');
  final int statusCode;
}

class NewsTranslation {
  const NewsTranslation({
    required this.title,
    required this.text,
    this.isPartial = false,
  });
  final String title;
  final String text;
  final bool isPartial;
}

/// Google translation used by Sonarpad desktop, without an AI provider.
class NewsTranslationService {
  NewsTranslationService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  bool _closed = false;
  static const _key = 'AIzaSyDLEeFI5OtFBwYBIoK_jj5m32rZK5CkCXA';

  static String normalizeLanguage(String value) =>
      value.toLowerCase().replaceAll('_', '-').split('-').first;

  /// The 1,500-character target is soft: never truncate a long sentence.
  /// Whitespace, decimal numbers and URLs survive the split unchanged.
  static List<String> splitSentences(String text, {int maxChars = 1500}) {
    final boundaries = RegExp(r'''[.:?!。：？！]+["'”’»)]*(?=\s|$)''');
    final chunks = <String>[];
    var start = 0;
    var sentenceStart = 0;
    var count = 0;
    final ends = [...boundaries.allMatches(text).map((m) => m.end)];
    if (ends.isEmpty || ends.last != text.length) ends.add(text.length);
    for (final end in ends) {
      final size = text.substring(sentenceStart, end).runes.length;
      if (count > 0 && count + size > maxChars) {
        chunks.add(text.substring(start, sentenceStart));
        start = sentenceStart;
        count = 0;
      }
      count += size;
      sentenceStart = end;
    }
    chunks.add(text.substring(start));
    return chunks;
  }

  static String parseTranslation(Object? value) {
    if (value is! List || value.isEmpty) {
      throw const FormatException('translation_missing_response');
    }
    if (value.length > 1 && value[1] is List) {
      final sentences = value[1] as List;
      // A malformed segment must fail, not silently omit part of the article.
      if (sentences.isNotEmpty &&
          sentences.every((s) => s is List && s.isNotEmpty && s[0] is String)) {
        final text = sentences.map((s) => s[0] as String).join();
        if (text.trim().isNotEmpty) return text;
      }
    }
    if (value[0] is String && (value[0] as String).trim().isNotEmpty) {
      return value[0] as String;
    }
    throw const FormatException('translation_missing_response');
  }

  Future<String> _translate(
    String text,
    String target,
    void Function(String) onChunk,
    String source,
  ) async {
    final translated = StringBuffer();
    for (final chunk in splitSentences(text)) {
      if (_closed) throw StateError('translation_cancelled');
      if (chunk.trim().isEmpty) {
        translated.write(chunk);
        onChunk(translated.toString());
        continue;
      }
      final uri = Uri.https('translate-pa.googleapis.com', '/v1/translate', {
        'params.client': 'gtx',
        'query.source_language': source,
        'query.target_language': target,
        'query.display_language': target,
        'query.text': chunk,
        'key': _key,
        'data_types': ['TRANSLATION', 'SENTENCE_SPLITS'],
      });
      final response = await _client
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json+protobuf',
              'User-Agent': 'Mozilla/5.0',
            },
          )
          .timeout(const Duration(seconds: 30));
      if (_closed) throw StateError('translation_cancelled');
      if (response.statusCode != 200) {
        // Never include the request URL (key and article text) in errors/logs.
        throw NewsTranslationHttpError(response.statusCode);
      }
      final result = parseTranslation(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
      final leading = chunk.length - chunk.trimLeft().length;
      final trailing = chunk.trimRight().length;
      translated
        ..write(chunk.substring(0, leading))
        ..write(result.trim())
        ..write(chunk.substring(trailing));
      onChunk(translated.toString());
    }
    return translated.toString();
  }

  Future<NewsTranslation> translateArticle({
    required String title,
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'auto',
    void Function(int completed, int total)? onProgress,
  }) async {
    final target = normalizeLanguage(targetLanguage);
    if (text.trim().isEmpty || target.isEmpty) {
      throw ArgumentError('translation_missing_input');
    }
    final total = splitSentences(title).length + splitSentences(text).length;
    var completed = 0;
    var translatedTitle = '';
    var translatedText = '';
    onProgress?.call(0, total);
    try {
      await _translate(title, target, (partial) {
        translatedTitle = partial;
        onProgress?.call(++completed, total);
      }, normalizeLanguage(sourceLanguage));
      await _translate(text, target, (partial) {
        translatedText = partial;
        onProgress?.call(++completed, total);
      }, normalizeLanguage(sourceLanguage));
      return NewsTranslation(title: translatedTitle, text: translatedText);
    } catch (_) {
      // Cancellation is deliberate; a network/format failure preserves work.
      if (_closed ||
          (translatedTitle.trim().isEmpty && translatedText.trim().isEmpty)) {
        rethrow;
      }
      return NewsTranslation(
        title: translatedTitle.trim().isEmpty ? title : translatedTitle,
        text: translatedText,
        isPartial: true,
      );
    }
  }

  void close() {
    _closed = true;
    _client.close();
  }
}
