import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class TreccaniSearchResult {
  final String title;
  final String url;
  final String description;

  const TreccaniSearchResult({
    required this.title,
    required this.url,
    required this.description,
  });
}

class TreccaniArticle {
  final String title;
  final String text;
  final String url;
  final List<TreccaniArticleSection> sections;

  const TreccaniArticle({
    required this.title,
    required this.text,
    required this.url,
    required this.sections,
  });
}

class TreccaniArticleSection {
  final String title;
  final int level;
  final String text;

  const TreccaniArticleSection({
    required this.title,
    required this.level,
    required this.text,
  });
}

enum TreccaniErrorType {
  invalidUrl,
  notFound,
  http,
  invalidResponse,
}

class TreccaniServiceException implements Exception {
  final TreccaniErrorType type;
  final int? statusCode;

  const TreccaniServiceException(this.type, {this.statusCode});

  @override
  String toString() =>
      'TreccaniServiceException(${type.name}'
      '${statusCode == null ? '' : ', HTTP $statusCode'})';
}

class TreccaniService {
  static final Uri _baseUri = Uri.parse('https://www.treccani.it');
  final http.Client _client;

  TreccaniService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<TreccaniSearchResult>> search(
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = _baseUri.resolve(
      '/enciclopedia/ricerca/${Uri.encodeComponent(trimmed)}/',
    );
    final response = await _client
        .get(
          uri,
          headers: const {
            'User-Agent': 'Sonarpad mobile Treccani reader',
            'Accept-Language': 'it-IT,it;q=0.9',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TreccaniServiceException(
        TreccaniErrorType.http,
        statusCode: response.statusCode,
      );
    }
    return parseSearchHtml(response.body, limit: limit);
  }

  Future<TreccaniArticle> loadArticle(TreccaniSearchResult result) async {
    final normalizedUrl = _normalizeResultUrl(result.url);
    if (normalizedUrl == null) {
      throw const TreccaniServiceException(TreccaniErrorType.invalidUrl);
    }
    final response = await _client
        .get(
          Uri.parse(normalizedUrl),
          headers: const {
            'User-Agent': 'Sonarpad mobile Treccani reader',
            'Accept-Language': 'it-IT,it;q=0.9',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TreccaniServiceException(
        TreccaniErrorType.http,
        statusCode: response.statusCode,
      );
    }
    return parseArticleHtml(response.body, url: normalizedUrl);
  }

  static List<TreccaniSearchResult> parseSearchHtml(
    String html, {
    int limit = 20,
  }) {
    final document = html_parser.parse(html);
    final results = <TreccaniSearchResult>[];
    final seenUrls = <String>{};

    for (final script
        in document.querySelectorAll('script[type="application/json"]')) {
      final jsonText = script.text.trim();
      if (jsonText.isEmpty) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(jsonText);
      } catch (_) {
        continue;
      }
      final matches = _findMatchesArray(decoded);
      if (matches == null) continue;

      for (final item in matches) {
        if (item is! Map) continue;
        final rawUrl = item['url']?.toString() ?? '';
        final url = _normalizeResultUrl(rawUrl);
        if (url == null || !seenUrls.add(url)) continue;

        final title = (item['title']?.toString() ?? '').trim();
        if (title.isEmpty) continue;
        final section = (item['section']?.toString() ?? '')
            .trim()
            .toLowerCase();
        if (section.isNotEmpty && section != 'enciclopedia') continue;
        final description = (item['description']?.toString() ?? '').trim();
        results.add(TreccaniSearchResult(
          title: title,
          url: url,
          description: description,
        ));
        if (results.length >= limit) return results;
      }
    }

    if (results.length < limit) {
      for (final link in document.querySelectorAll('a[href]')) {
        final url = _normalizeResultUrl(link.attributes['href'] ?? '');
        if (url == null || !seenUrls.add(url)) continue;
        final title = _normalizeText(link.text);
        final generic = title.toLowerCase();
        if (title.isEmpty ||
            generic == 'leggi' ||
            generic == 'scopri' ||
            generic == 'vai' ||
            generic == 'approfondisci') {
          continue;
        }
        results.add(TreccaniSearchResult(
          title: title,
          url: url,
          description: '',
        ));
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  static TreccaniArticle parseArticleHtml(
    String html, {
    required String url,
  }) {
    final document = html_parser.parse(html);
    final title = document
        .querySelectorAll('h1')
        .map(_elementVisibleText)
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (title.isEmpty) {
      throw const TreccaniServiceException(TreccaniErrorType.notFound);
    }

    var bestBlocks = <String>[];
    var bestScore = 0;
    for (final root in document.querySelectorAll('article, main, [role="main"]')) {
      final blocks = _extractBlocks(
        root.querySelectorAll('h1, h2, h3, h4, h5, h6, p, li'),
        title,
      );
      final score = _articleBlocksScore(blocks, title);
      if (score > bestScore) {
        bestScore = score;
        bestBlocks = blocks;
      }
    }

    final documentBlocks = _extractBlocks(
      document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, li'),
      title,
    );
    final documentScore = _articleBlocksScore(documentBlocks, title);
    if (bestScore == 0 || documentScore > (bestScore * 3) ~/ 2) {
      bestBlocks = documentBlocks;
      bestScore = documentScore;
    }

    if (bestScore == 0) {
      throw const TreccaniServiceException(TreccaniErrorType.notFound);
    }

    final text = _normalizeArticleText(bestBlocks.join('\n\n'));
    return TreccaniArticle(
      title: title,
      text: text,
      url: url,
      sections: _extractArticleSections(text),
    );
  }

  static List<dynamic>? _findMatchesArray(Object? value) {
    if (value is Map) {
      final matches = value['matches'];
      if (matches is List) return matches;
      for (final nested in value.values) {
        final found = _findMatchesArray(nested);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final nested in value) {
        final found = _findMatchesArray(nested);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String? _normalizeResultUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    Uri resolved;
    try {
      resolved = _baseUri.resolve(trimmed);
    } catch (_) {
      return null;
    }
    final host = resolved.host.toLowerCase();
    if (host != 'treccani.it' && !host.endsWith('.treccani.it')) return null;
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
    final path = resolved.path.toLowerCase();
    if (!path.startsWith('/enciclopedia/') ||
        path.contains('/enciclopedia/ricerca/')) {
      return null;
    }
    return resolved.toString();
  }

  static String _normalizeText(String text) =>
      text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');

  static String _elementVisibleText(dom.Element element) {
    final buffer = StringBuffer();

    void visit(dom.Node node) {
      if (node is dom.Text) {
        buffer.write(node.data);
        buffer.write(' ');
        return;
      }
      if (node is dom.Element) {
        final name = node.localName?.toLowerCase();
        if (name == 'style' || name == 'script') return;
      }
      for (final child in node.nodes) {
        visit(child);
      }
    }

    visit(element);
    return _normalizeText(buffer.toString());
  }

  static String _normalizeArticleText(String text) {
    final output = StringBuffer();
    var previousBlank = false;
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (!previousBlank && output.isNotEmpty) output.write('\n');
        previousBlank = true;
        continue;
      }
      if (output.isNotEmpty && !output.toString().endsWith('\n')) {
        output.write('\n');
      }
      output.write(trimmed);
      previousBlank = false;
    }
    return output.toString().trim();
  }

  static String _headingMarker(int level, String text) {
    final bounded = level.clamp(2, 6).toInt();
    final marker = '=' * bounded;
    return '$marker $text $marker';
  }

  static bool _elementHasSkippedAncestor(dom.Element element) {
    dom.Node? current = element.parentNode;
    while (current is dom.Element) {
      final ancestor = current;
      final name = ancestor.localName?.toLowerCase() ?? '';
      if (name == 'header' ||
          name == 'nav' ||
          name == 'aside' ||
          name == 'footer' ||
          name == 'form') {
        return true;
      }
      final href = (ancestor.attributes['href'] ?? '').toLowerCase();
      if (href.startsWith('/enciclopedia/tag/')) return true;
      final marker = '${ancestor.id} ${ancestor.classes.join(' ')}'.toLowerCase();
      const ignored = [
        'breadcrumb',
        'related',
        'correlat',
        'social',
        'share',
        'subscription',
        'advert',
        'banner',
        'modal',
        'cookie',
        'newsletter',
      ];
      if (ignored.any(marker.contains)) return true;
      current = ancestor.parentNode;
    }
    return false;
  }

  static bool _isBoilerplate(String text) {
    final normalized = text.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'indice' ||
        normalized == 'categorie' ||
        normalized == 'tag' ||
        normalized == 'dal vocabolario' ||
        normalized == 'lemmi correlati' ||
        normalized == 'scarica' ||
        normalized == 'salta al contenuto' ||
        normalized.startsWith('vuoi navigare il sito treccani') ||
        normalized.startsWith("scarica l'app");
  }

  static bool _isCopyright(String text) {
    final normalized = text.trim().toLowerCase();
    return normalized.startsWith('©') ||
        normalized.contains(
          'istituto della enciclopedia italiana fondata da giovanni treccani',
        ) ||
        normalized.contains('riproduzione riservata');
  }

  static ({int level, String title})? _headingTitle(String line) {
    final trimmed = line.trim();
    for (var level = 2; level <= 6; level += 1) {
      final marker = '=' * level;
      final prefix = '$marker ';
      final suffix = ' $marker';
      if (!trimmed.startsWith(prefix) || !trimmed.endsWith(suffix)) continue;
      final body = trimmed
          .substring(prefix.length, trimmed.length - suffix.length)
          .trim();
      if (body.isEmpty || body.contains('==')) return null;
      return (level: level, title: body);
    }
    return null;
  }

  static String? _legacySmallcapsHeading(dom.Element element, String text) {
    if (element.localName != 'p') return null;
    final labels = element
        .querySelectorAll('span.tc-smallcaps')
        .map(_elementVisibleText)
        .where((label) => label.isNotEmpty)
        .toList();
    if (labels.length != 1) return null;
    final label = labels.single;
    if (text.toLowerCase() == 'bibliografia' &&
        label.toLowerCase() == 'bibliografia') {
      return 'Bibliografia';
    }
    final separator = text.indexOf('. ');
    if (separator <= 0) return null;
    final number = text.substring(0, separator);
    final title = text.substring(separator + 2);
    if (number.length > 3 ||
        !RegExp(r'^\d+$').hasMatch(number) ||
        title.toLowerCase() != label.toLowerCase()) {
      return null;
    }
    return '$number. $title';
  }

  static List<TreccaniArticleSection> _extractArticleSections(String text) {
    final lines = text.split('\n');
    final headings = <({int lineIndex, int level, String title})>[];
    for (var i = 0; i < lines.length; i += 1) {
      final heading = _headingTitle(lines[i]);
      if (heading != null) {
        headings.add((
          lineIndex: i,
          level: heading.level,
          title: heading.title,
        ));
      }
    }

    final sections = <TreccaniArticleSection>[];
    for (var i = 0; i < headings.length; i += 1) {
      final current = headings[i];
      var end = lines.length;
      for (var j = i + 1; j < headings.length; j += 1) {
        if (headings[j].level <= current.level) {
          end = headings[j].lineIndex;
          break;
        }
      }
      final sectionText = lines.sublist(current.lineIndex, end).join('\n').trim();
      if (sectionText.isNotEmpty) {
        sections.add(TreccaniArticleSection(
          title: current.title,
          level: current.level,
          text: sectionText,
        ));
      }
    }
    return sections;
  }

  static List<String> _extractBlocks(
    List<dom.Element> elements,
    String title,
  ) {
    final containsTitle = elements.any(
      (element) =>
          element.localName == 'h1' &&
          _elementVisibleText(element).toLowerCase() == title.toLowerCase(),
    );

    final blocks = <String>[];
    var foundTitle = !containsTitle;
    var skipIndexEntries = false;
    var skipAuxiliaryEntries = false;
    final seenBlocks = <String>{};

    blocks.add(title);
    seenBlocks.add(title.toLowerCase());

    for (final element in elements) {
      if (_elementHasSkippedAncestor(element)) continue;
      final tag = element.localName?.toLowerCase() ?? '';
      final text = _elementVisibleText(element);
      if (text.isEmpty) continue;
      if (tag == 'h1') {
        if (text.toLowerCase() == title.toLowerCase()) foundTitle = true;
        continue;
      }
      if (!foundTitle) continue;
      if (_isCopyright(text)) break;
      if (text.toLowerCase() == 'indice') {
        skipIndexEntries = true;
        continue;
      }
      if (skipIndexEntries && tag == 'li') continue;
      if (skipIndexEntries && tag != 'li') skipIndexEntries = false;

      final normalized = text.toLowerCase();
      if (normalized == 'categorie' ||
          normalized == 'tag' ||
          normalized == 'dal vocabolario' ||
          normalized == 'lemmi correlati') {
        skipAuxiliaryEntries = true;
        continue;
      }
      if (skipAuxiliaryEntries) {
        final startsArticleBody =
            tag == 'h2' ||
            tag == 'h3' ||
            tag == 'h4' ||
            tag == 'h5' ||
            tag == 'h6' ||
            (tag == 'p' &&
                (text.length >= 80 ||
                    text.endsWith('.') ||
                    text.endsWith('!') ||
                    text.endsWith('?')));
        if (startsArticleBody) {
          skipAuxiliaryEntries = false;
        } else {
          continue;
        }
      }
      if (_isBoilerplate(text)) continue;

      final legacyHeading = _legacySmallcapsHeading(element, text);
      final isArticleMetadataHeading =
          (tag == 'h5' || tag == 'h6') &&
          (normalized.startsWith('enciclopedia ') ||
              normalized.startsWith('di '));
      final String block;
      if (legacyHeading != null) {
        block = _headingMarker(2, legacyHeading);
      } else if (normalized == 'enciclopedia on line' ||
          isArticleMetadataHeading) {
        block = text;
      } else {
        block = switch (tag) {
          'h2' => _headingMarker(2, text),
          'h3' => _headingMarker(3, text),
          'h4' => _headingMarker(4, text),
          'h5' => _headingMarker(5, text),
          'h6' => _headingMarker(6, text),
          'li' => '- $text',
          _ => text,
        };
      }
      if (seenBlocks.add(block.toLowerCase())) blocks.add(block);
    }

    return blocks;
  }

  static int _articleBlocksScore(List<String> blocks, String title) {
    var score = 0;
    for (final block in blocks) {
      if (block.toLowerCase() == title.toLowerCase()) continue;
      if (block.startsWith('- ') || _headingTitle(block) != null) continue;
      score += block.length;
    }
    return score;
  }
}
