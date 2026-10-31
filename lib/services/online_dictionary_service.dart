import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

/// Wiktionary lookup and plain-text rules ported from Windows wiktionary.rs.
class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.language,
    required this.definitions,
    required this.synonyms,
    this.limited = false,
  });
  final String word;
  final String language;
  final List<String> definitions;
  final List<String> synonyms;
  final bool limited;
  Uri get source => Uri.https('$language.wiktionary.org', '/wiki/$word');
}

class DictionaryRequestException implements Exception {
  const DictionaryRequestException(this.code);
  final String code;
}

class OnlineDictionaryService {
  OnlineDictionaryService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  void close() => _client.close();

  Future<Map<String, dynamic>> _request(
    String language,
    Map<String, String> parameters,
  ) async {
    final response = await _client
        .get(
          Uri.https('$language.wiktionary.org', '/w/api.php', {
            ...parameters,
            'format': 'json',
            'formatversion': '2',
          }),
          headers: {'User-Agent': 'SonarpadMobile/1.0 (Wiktionary dictionary)'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw DictionaryRequestException('http_${response.statusCode}');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (data['error'] != null) {
      final code = data['error']['code'];
      throw DictionaryRequestException(
        code == 'missingtitle' ? 'not_found' : 'api_error',
      );
    }
    return data;
  }

  Future<DictionaryEntry> lookup(String word, {String language = 'it'}) async {
    word = word.trim();
    if (word.isEmpty ||
        !RegExp(r'^[a-z]{2,3}(?:-[a-z]+)?$').hasMatch(language)) {
      throw const DictionaryRequestException('invalid_query');
    }
    final info = await _request(language, {
      'action': 'query',
      'prop': 'info',
      'titles': word,
      'redirects': '1',
    });
    final pages = info['query']?['pages'] as List? ?? const [];
    if (pages.isEmpty || pages.first['missing'] == true) {
      throw const DictionaryRequestException('not_found');
    }
    final page = pages.first as Map;
    final title = page['title'] as String? ?? word;
    final limited = (page['length'] as num? ?? 0) > 30000;
    final parsed = await _request(language, {
      'action': 'parse',
      'page': title,
      'prop': 'wikitext',
      'section': '1',
    });
    final text = parsed['parse']?['wikitext'] as String?;
    if (text == null) {
      throw const DictionaryRequestException('invalid_response');
    }
    final entry = WiktionaryParser.parse(
      text,
      word: title,
      language: language,
      limited: limited,
    );
    if (entry.definitions.isEmpty) {
      throw const DictionaryRequestException('not_found');
    }
    return entry;
  }
}

class WiktionaryParser {
  static final _letters = RegExp(r'\p{L}', unicode: true);
  static final _alphanumeric = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static const _codes = {
    'en',
    'it',
    'es',
    'pt',
    'sv',
    'vi',
    'cs',
    'pl',
    'fr',
    'sr',
    'de',
  };
  static const _grammar = {
    'w',
    'm',
    'f',
    'n',
    'mf',
    'fm',
    'sg',
    'pl',
    'sing',
    'plural',
    'case',
    'nom',
    'gen',
    'dat',
    'acc',
    'voc',
  };

  static List<String> _parts(String input) {
    final parts = <String>[];
    var braces = 0, links = 0, start = 0;
    for (var i = 0; i < input.length; i++) {
      final pair = i + 1 < input.length ? input.substring(i, i + 2) : '';
      if (pair == '{{') {
        braces++;
        i++;
      } else if (pair == '}}') {
        braces--;
        i++;
      } else if (pair == '[[') {
        links++;
        i++;
      } else if (pair == ']]') {
        links--;
        i++;
      } else if (input[i] == '|' && braces == 0 && links == 0) {
        parts.add(input.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(input.substring(start));
    return parts;
  }

  static String _template(String text) {
    final parts = _parts(text);
    if (parts.first.trim().toLowerCase() == 'w') return '';
    var chosen = '';
    for (var part in parts.skip(1)) {
      part = part.trim();
      if (part.startsWith('ft=')) {
        if (_letters.hasMatch(part.substring(3))) chosen = part.substring(3);
      } else if (!part.contains('=') &&
          part.isNotEmpty &&
          (_letters.hasMatch(part) || !_letters.hasMatch(chosen))) {
        chosen = part;
      }
    }
    return chosen;
  }

  static String clean(String input) {
    var text = input.replaceAll(RegExp(r'<!--.*?(?:-->|$)', dotAll: true), '');
    text = text.replaceAll(
      RegExp(
        r'<ref\b[^>]*?/>|<ref\b[^>]*>.*?(?:</ref\s*>|$)',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    // Images are not part of a definition; remove balanced links including captions.
    text = _links(text, imagesOnly: true);
    while (text.contains('{{')) {
      final start = text.indexOf('{{');
      var depth = 0, end = -1;
      for (var i = start; i + 1 < text.length; i++) {
        final pair = text.substring(i, i + 2);
        if (pair == '{{') {
          depth++;
          i++;
        } else if (pair == '}}') {
          depth--;
          i++;
          if (depth == 0) {
            end = i + 1;
            break;
          }
        }
      }
      if (end < 0) {
        text = text.substring(0, start);
        break;
      }
      text = text.replaceRange(
        start,
        end,
        _template(text.substring(start + 2, end - 2)),
      );
    }
    text = _links(text);
    text = text.replaceAllMapped(
      RegExp(r'\[https?://[^\s\]]+(?:\s+([^\]]*))?\]'),
      (m) => m[1] ?? '',
    );
    text = html.parseFragment(text).text ?? '';
    return text.replaceAll("''", '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _links(String text, {bool imagesOnly = false}) {
    final out = StringBuffer();
    for (var i = 0; i < text.length;) {
      if (!text.startsWith('[[', i)) {
        out.write(text[i++]);
        continue;
      }
      final start = i;
      var depth = 1;
      i += 2;
      final contentStart = i;
      while (i < text.length && depth > 0) {
        if (text.startsWith('[[', i)) {
          depth++;
          i += 2;
        } else if (text.startsWith(']]', i)) {
          depth--;
          i += 2;
        } else {
          i++;
        }
      }
      if (depth != 0) {
        out.write(text.substring(start));
        break;
      }
      final content = text.substring(contentStart, i - 2);
      final image = RegExp(
        r'^(File|Image|Fichier|Datei|Immagine):',
        caseSensitive: false,
      ).hasMatch(content);
      if (image) continue;
      out.write(
        imagesOnly ? text.substring(start, i) : _links(_parts(content).last),
      );
    }
    return out.toString();
  }

  static String _grammarToken(String token) =>
      token.toLowerCase().replaceAll(RegExp(r'^[^a-z-]+|[^a-z-]+$'), '');
  static String normalize(String text) {
    final words = text.split(RegExp(r'\s+'));
    final qid = RegExp(r'^[Qq]\d+[a-zA-Z]?$');
    while (words.isNotEmpty &&
        (_codes.contains(words.first) || qid.hasMatch(words.first))) {
      words.removeAt(0);
    }
    var grammarCount = 0;
    while (grammarCount < words.length &&
        _grammar.contains(_grammarToken(words[grammarCount]))) {
      grammarCount++;
    }
    if (grammarCount == words.length) return '';
    if (grammarCount >= 2) words.removeRange(0, grammarCount);
    while (words.isNotEmpty &&
        (RegExp(
              r'^[a-z]$|^[a-fA-F0-9]{6}(?:[a-fA-F0-9]{2})?$',
            ).hasMatch(words.last) ||
            qid.hasMatch(words.last))) {
      words.removeLast();
    }
    text = words
        .join(' ')
        .replaceFirst(RegExp(r'[\s.,;]*\d{4}-\d{1,2}-\d{1,2}$'), '')
        .replaceFirst(RegExp(r'^[Qq]\d+(?:[a-zA-Z](?=\W|$))?\s*'), '')
        .trim();
    if (text == 'ing-form' ||
        text == 'inflection of' ||
        _codes.contains(text) ||
        qid.hasMatch(text)) {
      return '';
    }
    return text;
  }

  static DictionaryEntry parse(
    String text, {
    required String word,
    required String language,
    bool limited = false,
  }) {
    final definitions = <String>[];
    final synonyms = <String>[];
    var block = '';
    final singleLemma = RegExp(r'^[\p{Ll}][\p{L}\x27’-]*\.$', unicode: true);
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trimLeft();
      if (line.startsWith('{{')) {
        block = line.startsWith('{{Bedeutungen}}')
            ? 'definitions'
            : line.startsWith('{{Synonyme}}') || line.startsWith('{{-sin-}}')
            ? 'synonyms'
            : '';
      }
      if (block == 'synonyms' && !limited) {
        final match = RegExp(
          r'^:\s*\[[\d\s,–—?*\-]+\]\s*(.*)$',
        ).firstMatch(line);
        final value =
            match?[1] ?? (line.startsWith('*') ? line.substring(1) : null);
        if (value != null) {
          final cleaned = normalize(clean(value));
          if (cleaned.isNotEmpty) synonyms.add(cleaned);
        }
      }
      if (definitions.length >= (limited ? 5 : 1000)) continue;
      String? value;
      var subpoint = false;
      if (language == 'de') {
        if (block == 'definitions') {
          final body = line.replaceFirst('{{Bedeutungen}}', '');
          value = RegExp(
            r'^:\s*\[[\d\s,–—?*\-]+\]\s*(.*)$',
          ).firstMatch(body.trim())?[1];
        }
      } else if (line.startsWith('# ')) {
        value = line.substring(2);
      } else if (line.startsWith('#*') && !line.startsWith('#**')) {
        value = line.substring(2);
        subpoint = true;
      } else {
        final match = RegExp(r'^;\s*\d+([^\n]*)').firstMatch(line);
        if (match != null) {
          value = match[1]!;
          if (value.contains(':')) {
            value = value.substring(value.indexOf(':') + 1);
          }
          subpoint = true;
        }
      }
      if (value == null) continue;
      var cleaned = normalize(clean(value));
      if (cleaned.isEmpty || !_alphanumeric.hasMatch(cleaned)) continue;
      if ((subpoint || definitions.isNotEmpty) &&
          singleLemma.hasMatch(cleaned)) {
        continue;
      }
      if (subpoint &&
          RegExp(
            r'^\p{Ll}+\s+[Pp](?:ág\.?|ag\.?|\.)\s*\d',
            unicode: true,
          ).hasMatch(cleaned)) {
        continue;
      }
      cleaned = String.fromCharCodes(cleaned.runes.take(500));
      definitions.add(cleaned);
    }
    if (language == 'es' && definitions.length > 1) {
      definitions.removeWhere(
        (s) => RegExp(
          r'^[\p{L}-]+(?:ar|er|ir)[.,;:]?$',
          unicode: true,
        ).hasMatch(s),
      );
    }
    return DictionaryEntry(
      word: word,
      language: language,
      definitions: definitions,
      synonyms: synonyms,
      limited: limited,
    );
  }
}
