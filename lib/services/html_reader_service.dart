import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class ArticleContent {
  final String title;
  final String content;

  ArticleContent({required this.title, required this.content});
}

class HtmlReaderService {
  static String decodeUnicode(String input) {
    // Dart's jsonDecode handles this, or regex
    return input.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      final hex = match.group(1);
      if (hex != null) {
        return String.fromCharCode(int.parse(hex, radix: 16));
      }
      return match.group(0)!;
    });
  }

  // A simplified extract json string method since Dart doesn't have the exact Rust parser.
  static JsonExtractResult? extractJsonString(String s) {
    StringBuffer result = StringBuffer();
    bool escaped = false;
    int endPos = s.length;
    for (int i = 0; i < s.length; i++) {
      String c = s[i];
      if (escaped) {
        if (c == '"') {
          result.write('"');
        } else if (c == '\\') {
          result.write('\\');
        } else if (c == 'n') {
          result.write('\n');
        } else if (c == 'r') {
          result.write('\r');
        } else if (c == 't') {
          result.write('\t');
        } else if (c == 'u') {
          if (i + 4 < s.length) {
            String hex = s.substring(i + 1, i + 5);
            try {
              result.write(String.fromCharCode(int.parse(hex, radix: 16)));
              i += 4;
            } catch (_) {
              result.write('\\u');
            }
          }
        } else {
          result.write('\\');
          result.write(c);
        }
        escaped = false;
      } else if (c == '\\') {
        escaped = true;
      } else if (c == '"') {
        endPos = i + 1;
        return JsonExtractResult(result.toString(), endPos);
      } else {
        result.write(c);
      }
    }
    if (result.isNotEmpty) {
      return JsonExtractResult(result.toString(), s.length);
    }
    return null;
  }

  static String decodeHtmlEntities(String input) {
    if (input.trim().isEmpty) return '';
    var current = input;
    // Alcuni feed consegnano entità una o due volte codificate, per esempio
    // &amp;ograve; oppure &amp;#39;. Decodifichiamo più passaggi, ma con limite
    // basso per evitare loop strani.
    for (var i = 0; i < 3; i += 1) {
      final decoded = html_parser.parseFragment(current).text ?? current;
      if (decoded == current) break;
      current = decoded;
    }
    return _decodeLooseHtmlEntities(current);
  }

  static String _decodeLooseHtmlEntities(String input) {
    if (input.isEmpty) return input;

    final named = <String, String>{
      // Entità base e spazi.
      'nbsp': ' ',
      'ensp': ' ',
      'emsp': ' ',
      'thinsp': ' ',
      'apos': "'",
      'quot': '"',
      'amp': '&',
      'lt': '<',
      'gt': '>',

      // Punteggiatura tipografica spesso presente nei feed RSS.
      'hellip': '…',
      'rsquo': '’',
      'lsquo': '‘',
      'sbquo': '‚',
      'ldquo': '“',
      'rdquo': '”',
      'bdquo': '„',
      'lsaquo': '‹',
      'rsaquo': '›',
      'laquo': '«',
      'raquo': '»',
      'ndash': '–',
      'mdash': '—',
      'bull': '•',
      'middot': '·',
      'copy': '©',
      'reg': '®',
      'trade': '™',
      'euro': '€',
      'pound': '£',
      'yen': '¥',
      'deg': '°',
      'ordm': 'º',
      'ordf': 'ª',
      'iquest': '¿',
      'iexcl': '¡',

      // Vocali accentate e caratteri usati in italiano, francese, spagnolo,
      // portoghese, tedesco e altre lingue europee. Queste servono anche
      // quando il feed perde la &, per esempio egrave; o ntilde;.
      'agrave': 'à',
      'aacute': 'á',
      'acirc': 'â',
      'atilde': 'ã',
      'auml': 'ä',
      'aring': 'å',
      'aelig': 'æ',
      'ccedil': 'ç',
      'egrave': 'è',
      'eacute': 'é',
      'ecirc': 'ê',
      'euml': 'ë',
      'igrave': 'ì',
      'iacute': 'í',
      'icirc': 'î',
      'iuml': 'ï',
      'ntilde': 'ñ',
      'ograve': 'ò',
      'oacute': 'ó',
      'ocirc': 'ô',
      'otilde': 'õ',
      'ouml': 'ö',
      'oslash': 'ø',
      'oelig': 'œ',
      'ugrave': 'ù',
      'uacute': 'ú',
      'ucirc': 'û',
      'uuml': 'ü',
      'yacute': 'ý',
      'yuml': 'ÿ',
      'szlig': 'ß',

      'Agrave': 'À',
      'Aacute': 'Á',
      'Acirc': 'Â',
      'Atilde': 'Ã',
      'Auml': 'Ä',
      'Aring': 'Å',
      'AElig': 'Æ',
      'Ccedil': 'Ç',
      'Egrave': 'È',
      'Eacute': 'É',
      'Ecirc': 'Ê',
      'Euml': 'Ë',
      'Igrave': 'Ì',
      'Iacute': 'Í',
      'Icirc': 'Î',
      'Iuml': 'Ï',
      'Ntilde': 'Ñ',
      'Ograve': 'Ò',
      'Oacute': 'Ó',
      'Ocirc': 'Ô',
      'Otilde': 'Õ',
      'Ouml': 'Ö',
      'Oslash': 'Ø',
      'OElig': 'Œ',
      'Ugrave': 'Ù',
      'Uacute': 'Ú',
      'Ucirc': 'Û',
      'Uuml': 'Ü',
      'Yacute': 'Ý',
    };

    String decodeToken(String token) {
      final bare = token.startsWith('&') ? token.substring(1) : token;
      final withoutSemicolon = bare.endsWith(';')
          ? bare.substring(0, bare.length - 1)
          : bare;
      if (withoutSemicolon.startsWith('#x') ||
          withoutSemicolon.startsWith('#X')) {
        final hex = withoutSemicolon.substring(2);
        final code = int.tryParse(hex, radix: 16);
        if (code != null) return String.fromCharCode(code);
        return token;
      }
      if (withoutSemicolon.startsWith('#')) {
        final code = int.tryParse(withoutSemicolon.substring(1));
        if (code != null) return String.fromCharCode(code);
        return token;
      }
      return named[withoutSemicolon] ?? token;
    }

    var out = input;
    // Entità corrette o residue, es. &ograve;, &#39;, &nbsp;.
    out = out.replaceAllMapped(
      RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[A-Za-z][A-Za-z0-9]+);'),
      (match) => decodeToken(match.group(0)!),
    );
    // Alcuni testi arrivano già privati della &, es. ograve; oppure #39;.
    // Evitiamo lookbehind per compatibilità: conserviamo il prefisso.
    final looseNames = named.keys.map(RegExp.escape).join('|');
    out = out.replaceAllMapped(
      RegExp('(^|[^A-Za-z0-9&])(#x[0-9a-fA-F]+|#\\d+|$looseNames);'),
      (match) => '${match.group(1)!}${decodeToken(match.group(2)!)}',
    );
    return out;
  }

  static int clampToCharBoundary(String s, int idx) {
    if (idx >= s.length) return s.length;
    return idx; // Dart handles strings as UTF-16, this is fine
  }

  static bool looksLikeTeaser(String value) {
    final v = value.trim();
    if (v.length < 120) return true;
    return v.contains('&hellip;') ||
        v.contains('&#8230;') ||
        v.contains('[&hellip;]') ||
        v.contains('[…]') ||
        v.contains('[...]') ||
        v.endsWith('…') ||
        v.endsWith('...');
  }

  static bool looksLikeUiChrome(String value) {
    final v = value.toLowerCase();
    return v.contains('cookie') ||
        v.contains('privacy policy') ||
        v.contains('terms and conditions') ||
        v.contains('sign up') ||
        v.contains('log in') ||
        v.contains('subscribe') ||
        v.contains('newsletter') ||
        v.contains('all rights reserved') ||
        v.contains('enable js') ||
        v.contains('advert') ||
        v.contains('sponsored') ||
        v.contains('consent') ||
        // Polacco
        v.contains('subskrybuj') ||
        v.contains('zaloguj') ||
        v.contains('zarejestruj') ||
        v.contains('akceptuj') ||
        v.contains('polityka prywatno') ||
        v.contains('regulamin') ||
        v.contains('wszystkie prawa zastrze') ||
        // Portoghese
        v.contains('subscrever') ||
        v.contains('assinar') ||
        v.contains('assinatura') ||
        v.contains('entrar') ||
        v.contains('iniciar sess') ||
        v.contains('aceitar cookies') ||
        v.contains('política de privacidade') ||
        v.contains('todos os direitos reservados');
  }

  static int countSentences(String value) {
    return value.split(RegExp(r'[.!?]')).length - 1;
  }

  static List<String> extractJsonValues(String jsonText, String key) {
    List<String> out = [];
    int searchPos = 0;
    while (true) {
      int textStart = jsonText.indexOf(key, searchPos);
      if (textStart < 0) break;
      int absStart = textStart + key.length;
      if (absStart < jsonText.length) {
        final res = extractJsonString(jsonText.substring(absStart));
        if (res != null) {
          out.add(res.value);
          searchPos = absStart + res.endPos;
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return out;
  }

  static List<String> extractJsonValuesLoose(String jsonText, String keyName) {
    List<String> out = [];
    String token = '"$keyName"';
    int searchPos = 0;
    while (true) {
      int found = jsonText.indexOf(token, searchPos);
      if (found < 0) break;
      int i = found + token.length;
      while (i < jsonText.length && jsonText[i].trim().isEmpty) {
        i++;
      }
      if (i >= jsonText.length || jsonText[i] != ':') {
        searchPos = found + token.length;
        continue;
      }
      i++;
      while (i < jsonText.length && jsonText[i].trim().isEmpty) {
        i++;
      }
      if (i >= jsonText.length || jsonText[i] != '"') {
        searchPos = found + token.length;
        continue;
      }
      i++;
      final res = extractJsonString(jsonText.substring(i));
      if (res != null) {
        out.add(res.value);
        searchPos = i + res.endPos;
      } else {
        break;
      }
    }
    return out;
  }

  static String cleanText(String input) {
    var text = decodeHtmlEntities(decodeUnicode(input))
        .replaceAll('ÃƒÂ¨', 'è')
        .replaceAll('ÃƒÂ ', 'à')
        .replaceAll('ÃƒÂ¹', 'ù')
        .replaceAll('ÃƒÂ²', 'ò')
        .replaceAll('ÃƒÂ¬', 'ì')
        .replaceAll('Ã‚Â ', ' ')
        .replaceAll('ÃƒÂ©', 'é')
        .replaceAll('Ã‚', '');

    text = decodeHtmlEntities(text)
        .replaceAll('\u00a0', ' ')
        .replaceAll(r'\"', '"')
        .replaceAll('\\n', '\n')
        .replaceAll('\\/', '/');

    final cleaned = StringBuffer();
    var inTag = false;
    for (var i = 0; i < text.length; i += 1) {
      if (text[i] == '<') {
        inTag = true;
      } else if (text[i] == '>') {
        inTag = false;
        cleaned.write(' ');
      } else if (!inTag) {
        cleaned.write(text[i]);
      }
    }

    return _stripLooseHtmlTagMarkers(
      decodeHtmlEntities(cleaned.toString()),
    );
  }

  static String _stripLooseHtmlTagMarkers(String input) {
    if (input.isEmpty) return input;
    var text = input;
    // Se un feed trasforma i tag in testo, possono restare righe/parole come
    // "h1", "/h1", "p" o "br". Li togliamo solo quando sono token isolati,
    // così non tocchiamo parole normali.
    text = text.replaceAll(
      RegExp(r'(^|\s)/?(?:h[1-6]|p|br|strong|em|span|div)(?=\s|$)', caseSensitive: false),
      ' ',
    );
    return text;
  }

  static String collapseBlankLines(String s) {
    StringBuffer out = StringBuffer();
    int blankRun = 0;
    Set<String> seenShort = {};
    List<String> lines = s.split('\n');
    String? prevLine;

    for (var line in lines) {
      String l = line.trim();
      if (l.isEmpty) {
        blankRun++;
        if (blankRun <= 1) {
          out.write('\n');
          prevLine = '';
        }
      } else {
        if (prevLine != null && prevLine.toLowerCase() == l.toLowerCase()) {
          continue;
        }
        if (l.length <= 40) {
          String key = l.toLowerCase();
          if (seenShort.contains(key)) continue;
          seenShort.add(key);
        }
        blankRun = 0;
        out.write(l);
        out.write('\n');
        prevLine = l;
      }
    }
    String result = out.toString();
    while (result.endsWith('\n')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  static String? pickBestJsonArticleText(String jsonText) {
    final keys = [
      'articleBody',
      'body',
      'bodyHtml',
      'content',
      'contentHtml',
      'full_text',
      'text',
    ];
    String best = '';
    for (var key in keys) {
      String strict = '"$key":"';
      final vals = [
        ...extractJsonValues(jsonText, strict),
        ...extractJsonValuesLoose(jsonText, key)
      ];
      for (var val in vals) {
        if (val.length < 80) continue;
        String cleaned = cleanText(val);
        cleaned = collapseBlankLines(cleaned);
        String trimmed = cleaned.trim();
        if (trimmed.length < 300) continue;
        if (looksLikeTeaser(trimmed) || looksLikeUiChrome(trimmed)) continue;
        if (countSentences(trimmed) < 2) continue;
        if (trimmed.length > best.length) {
          best = trimmed;
        }
      }
    }
    return best.isEmpty ? null : best;
  }

  static String? pickTeaserJsonArticleText(String jsonText) {
    String best = '';
    String strict = '"articleBody":"';
    final vals = [
      ...extractJsonValues(jsonText, strict),
      ...extractJsonValuesLoose(jsonText, "articleBody")
    ];
    for (var val in vals) {
      String cleaned = collapseBlankLines(cleanText(val));
      String trimmed = cleaned.trim();
      if (trimmed.length >= 40 && trimmed.length > best.length) {
        best = trimmed;
      }
    }
    return best.isEmpty ? null : best;
  }

  static String trimAfterKnownTrailers(String input) {
    final markers = [
      "ABOUT THE AUTHOR",
      "Related Stories",
      "CBC's Journalistic Standards and Practices",
      "Corrections and clarifications",
    ];
    int cut = input.length;
    for (var marker in markers) {
      int idx = input.indexOf(marker);
      if (idx >= 0 && idx < cut) {
        cut = idx;
      }
    }
    return input.substring(0, cut).trim();
  }

  static String? extractCbcInitialStateArticleText(String htmlContent) {
    String best = '';
    for (var val in extractJsonValues(htmlContent, '"bodyHtml":"')) {
      if (val.length < 300) continue;
      String cleaned = collapseBlankLines(cleanText(val));
      String trimmed = trimAfterKnownTrailers(cleaned.trim());
      if (trimmed.length < 300) continue;
      if (looksLikeUiChrome(trimmed)) continue;
      if (countSentences(trimmed) < 3) continue;
      if (trimmed.length > best.length) {
        best = trimmed;
      }
    }
    if (best.isEmpty) {
      List<String> lines = [];
      for (var val
          in extractJsonValues(htmlContent, '"type":"text","content":"')) {
        String cleaned = collapseBlankLines(cleanText(val));
        String trimmed = cleaned.trim();
        if (trimmed.length < 20) continue;
        if (looksLikeUiChrome(trimmed)) continue;
        if (trimmed.contains("ABOUT THE AUTHOR") ||
            trimmed.contains("Related Stories") ||
            trimmed.contains("Journalistic Standards") ||
            trimmed.contains("Corrections and clarifications")) {
          continue;
        }
        if (lines.isNotEmpty && lines.last == trimmed) continue;
        lines.add(trimmed);
      }
      if (lines.isNotEmpty) {
        String joined = lines.join("\n\n");
        String trimmed = trimAfterKnownTrailers(joined.trim());
        if (trimmed.length >= 300 && countSentences(trimmed) >= 3) {
          best = trimmed;
        }
      }
    }
    return best.isEmpty ? null : best;
  }

  static ArticleContent? extractJinaMarkdownFixture(
      String rawContent, String languageCode) {
    if (!rawContent.contains("URL Source:") ||
        !rawContent.contains("Markdown Content:") ||
        !rawContent.contains("Title:")) {
      return null;
    }
    String title = "Titolo sconosciuto";
    for (var line in rawContent.split('\n')) {
      if (line.startsWith("Title:")) {
        String t = line.substring(6).trim();
        if (t.isNotEmpty) {
          title = t;
          break;
        }
      }
    }

    String marker = "Markdown Content:";
    int startIdx = rawContent.indexOf(marker);
    if (startIdx < 0) return null;
    startIdx += marker.length;
    String bodySrc = rawContent.substring(startIdx);

    List<String> lines = [];
    for (var line in bodySrc.split('\n')) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) {
        lines.add("");
        continue;
      }
      if (trimmed.toLowerCase() ==
          "[you make our work possible.](https://iowacapitaldispatch.com/donate/?oa_referrer=midstorybox)") {
        break;
      }
      if (trimmed.startsWith("If you value") || trimmed.startsWith("Support")) {
        break;
      }
      lines.add(trimmed);
    }
    String body = collapseBlankLines(cleanText(lines.join('\n')));
    String content = body.trim();
    if (content.length < 300 || countSentences(content) < 3) {
      return null;
    }
    return ArticleContent(title: title, content: content);
  }

  static String authorPrefix(String languageCode) {
    switch (languageCode) {
      case 'it':
        return "Di";
      case 'fr':
        return "Par";
      case 'es':
        return "Por";
      case 'pt':
        return "Por";
      case 'pl':
        return "Autor";
      case 'de':
        return "Von";
      case 'en':
        return "By";
      default:
        return "Di";
    }
  }

  static String pickTitle(Document document, String languageCode) {
    final selectors = ["meta[property='og:title']", "h1", "title"];
    for (var sel in selectors) {
      final elements = document.querySelectorAll(sel);
      if (elements.isNotEmpty) {
        var el = elements.first;
        String t =
            sel.contains("meta") ? (el.attributes['content'] ?? '') : el.text;
        String cleanT = t.trim();
        if (cleanT.length > 5 && !cleanT.toLowerCase().endsWith(".com")) {
          return decodeUnicode(cleanT);
        }
      }
    }
    return "Titolo non trovato";
  }

  static String? pickMetaDescription(Document document) {
    final selectors = [
      "meta[name='description']",
      "meta[property='og:description']",
      "meta[name='twitter:description']",
    ];
    String best = '';
    for (var sel in selectors) {
      final elements = document.querySelectorAll(sel);
      if (elements.isNotEmpty) {
        final content = elements.first.attributes['content'];
        if (content != null) {
          String clean = decodeUnicode(content.trim());
          if (clean.length > best.length) best = clean;
        }
      }
    }
    return best.length >= 40 ? best : null;
  }


  static ArticleContent? extractStructuredDataArticleFromRawHtml(
    String htmlContent,
    String fallbackTitle,
    String languageCode,
  ) {
    final scriptRe = RegExp(
      r'''<script\b[^>]*type=["\']application/ld\+json["\'][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
    );

    for (final match in scriptRe.allMatches(htmlContent)) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      final article = _articleContentFromJsonLd(raw, fallbackTitle);
      if (article != null) return article;
    }

    // Alcuni siti espongono articleBody in modo valido ma con attributi o
    // formattazioni che possono sfuggire al selettore DOM. Come ultima rete
    // di sicurezza leggiamo direttamente i campi testuali dal sorgente HTML.
    final rawBody = pickBestJsonArticleText(htmlContent) ??
        pickTeaserJsonArticleText(htmlContent);
    if (rawBody != null) {
      final cleaned = collapseBlankLines(cleanText(rawBody)).trim();
      if (cleaned.length >= 300 && countSentences(cleaned) >= 2) {
        return ArticleContent(title: fallbackTitle, content: cleaned);
      }
    }

    return null;
  }

  static ArticleContent? _articleContentFromJsonLd(
    String rawJson,
    String fallbackTitle,
  ) {
    for (final node in _jsonLdArticleNodes(rawJson)) {
      final bodyCandidates = <String>[
        _jsonStringValue(node['articleBody']),
        _jsonStringValue(node['text']),
        _jsonStringValue(node['description']),
      ].where((value) => value.trim().isNotEmpty).toList();

      bodyCandidates.sort((a, b) => b.length.compareTo(a.length));
      for (final candidate in bodyCandidates) {
        final cleaned = collapseBlankLines(cleanText(candidate)).trim();
        if (cleaned.length < 300) continue;
        if (countSentences(cleaned) < 2) continue;
        if (looksLikeUiChrome(cleaned)) continue;

        final headline = _jsonStringValue(node['headline']).trim();
        final name = _jsonStringValue(node['name']).trim();
        final title = headline.isNotEmpty
            ? headline
            : name.isNotEmpty
                ? name
                : fallbackTitle;

        return ArticleContent(title: title, content: cleaned);
      }
    }
    return null;
  }


  static ArticleContent? extractStructuredDataArticle(
    Document document,
    String fallbackTitle,
    String languageCode,
  ) {
    final scripts = document.querySelectorAll("script[type*='ld+json']");
    for (final script in scripts) {
      final raw = script.text.trim();
      if (raw.isEmpty) continue;
      final article = _articleContentFromJsonLd(raw, fallbackTitle);
      if (article != null) return article;
    }
    return null;
  }

  static Iterable<Map<String, dynamic>> _jsonLdArticleNodes(String rawJson) sync* {
    Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      return;
    }

    Iterable<Object?> walk(Object? value) sync* {
      if (value is List) {
        for (final item in value) {
          yield* walk(item);
        }
        return;
      }
      if (value is Map) {
        yield value;
        final graph = value['@graph'];
        if (graph != null) {
          yield* walk(graph);
        }
        final mainEntity = value['mainEntity'];
        if (mainEntity != null) {
          yield* walk(mainEntity);
        }
      }
    }

    for (final item in walk(decoded)) {
      if (item is! Map) continue;
      final node = <String, dynamic>{};
      item.forEach((key, value) => node[key.toString()] = value);
      final hasArticleText = _jsonStringValue(node['articleBody']).trim().isNotEmpty ||
          _jsonStringValue(node['text']).trim().isNotEmpty;
      if (hasArticleText && _isArticleJsonLdType(node['@type'])) {
        yield node;
      }
    }
  }

  static bool _isArticleJsonLdType(Object? type) {
    if (type == null) return true;
    if (type is List) return type.any(_isArticleJsonLdType);
    final text = type.toString().toLowerCase();
    return text.contains('article') ||
        text.contains('newsarticle') ||
        text.contains('blogposting') ||
        text.contains('reportage');
  }

  static String _jsonStringValue(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) {
      return value.map(_jsonStringValue).where((part) => part.trim().isNotEmpty).join('\n\n');
    }
    if (value is Map) {
      final text = value['text'] ?? value['value'] ?? value['name'];
      return _jsonStringValue(text);
    }
    return value.toString();
  }

  static String? pickRedditLinkPostUrl(Document document) {
    final elements = document.querySelectorAll(
        "shreddit-post[post-type='link'] div[slot='post-media-container'] a[href]");
    for (var el in elements) {
      final href = el.attributes['href'];
      if (href != null) {
        String trimmed = href.trim();
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
          return trimmed;
        }
      }
    }
    return null;
  }

  static bool isKnownJsNoiseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    return lower.startsWith("window.addeventlistener") ||
        lower.startsWith("window.datalayer.push") ||
        lower.startsWith("const softregwall =") ||
        lower.contains("event: 'show_paywall'") ||
        lower.contains("category: 'regwall'") ||
        lower.contains("action: 'overlay'") ||
        lower.contains("label: 'visualizzazione soft regwall") ||
        lower.contains("if (softregwall") ||
        lower.contains("window.datalayer = window.datalayer") ||
        (lower.contains("\"categoryname\":\"undefined\"") &&
            lower.contains("\"enabled\":\"true\""));
  }

  static bool isKnownTextNoiseLine(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.isEmpty) {
      return false;
    }

    // Fatto Quotidiano Paywall/Boilerplate
    if (lower == "facciamo un giornale con un solo padrone: i lettori.") {
      return true;
    }
    if (lower.contains("sfoglia ogni giorno i contenuti di fq in edicola")) {
      return true;
    }
    if (lower.contains("paga in modo rapido con:")) {
      return true;
    }
    if (lower.contains("rinnovo automatico. disattiva quando vuoi")) {
      return true;
    }
    if (lower.contains("hai bisogno di ulteriori informazioni?")) {
      return true;
    }
    if (lower.contains(
        "resta in contatto con la community de il fatto quotidiano")) {
      return true;
    }
    if (lower == "abbiamo a cuore la tua privacy") {
      return true;
    }

    // Corriere / RCS Boilerplate
    if (lower.contains(
        "per non perdere le ultime novità su tecnologia e innovazione")) {
      return true;
    }
    if (lower.contains("rcs mediagroup s.p.a.")) {
      return true;
    }

    // Twitter embeds remnants
    if (lower.startsWith("— ") &&
        lower.contains("(@") &&
        lower.contains("style=\"min-height:")) {
      return true;
    }
    if (lower.contains("\" style=\"min-height:200px\">")) {
      return true;
    }

    // Related articles / headers sometimes injected
    if (lower == "leggi anche") {
      return true;
    }
    if (lower == "leggi anche:") {
      return true;
    }

    return false;
  }

  static String stripPostExtractionNoise(String content) {
    List<String> lines = content.split('\n');
    List<String> validLines = [];
    bool inRegwallBlock = false;
    for (var line in lines) {
      String trimmed = line.trim();
      if (trimmed.startsWith("if (softRegwall")) {
        inRegwallBlock = true;
        continue;
      }
      if (inRegwallBlock) {
        if (trimmed == "}") {
          inRegwallBlock = false;
        } else if (trimmed == "});") {
          // Wait for next }
        }
        continue;
      }
      if (!isKnownJsNoiseLine(line) && !isKnownTextNoiseLine(line)) {
        // Also remove weird trailing HTML remnants from twitter
        if (trimmed.endsWith("\" style=\"min-height:200px\">")) {
          trimmed =
              trimmed.replaceAll(RegExp(r'" style="min-height:200px">$'), '');
          validLines.add(trimmed);
        } else {
          validLines.add(line);
        }
      }
    }
    return validLines.join('\n');
  }

  static void cleanDomBeforeExtraction(Document document) {
    // Remove unwanted elements
    final selectorsToRemove = [
      'aside',
      'footer',
      'nav',
      'header',
      '.paywall',
      '.cookie-banner',
      '#cookie-banner',
      '.newsletter',
      '.promo',
      '.advertisement',
      '.related-articles',
      '.related',
      '.social-share',
      '.comments',
      '.ad',
      '.ads',
      '.widget',
      '.sidebar',
      '.menu',
      '#menu',
      '[class*="paywall"]',
      '[class*="cookie"]',
      '[class*="advertisement"]',
      '[class*="newsletter"]',
      // Nota: [class*="related"] rimosso perché troppo aggressivo
      // (colpirebbe classi come 'unrelated', 'correlation-related', ecc.)
      '.related-articles',
      '.related-posts',
      '.related-news',
      '[id*="paywall"]',
      '[id*="cookie"]',
      '[id*="advertisement"]',
      '[id*="newsletter"]',
      '[id*="related-articles"]',
      '[id*="related-posts"]',
    ];

    for (var selector in selectorsToRemove) {
      for (var element in document.querySelectorAll(selector)) {
        element.remove();
      }
    }
  }

  static ArticleContent? readerModeExtract(
      String htmlContent, String languageCode) {
    if (!htmlContent.contains("<html")) {
      var article = extractJinaMarkdownFixture(htmlContent, languageCode);
      if (article != null) return article;
    }

    final document = html_parser.parse(htmlContent);
    final title = pickTitle(document, languageCode);
    final rawStructuredDataArticle = extractStructuredDataArticleFromRawHtml(
      htmlContent,
      title,
      languageCode,
    );
    if (rawStructuredDataArticle != null) {
      return rawStructuredDataArticle;
    }

    final structuredDataArticle = extractStructuredDataArticle(
      document,
      title,
      languageCode,
    );
    if (structuredDataArticle != null) {
      return structuredDataArticle;
    }
    cleanDomBeforeExtraction(document);

    StringBuffer bodyAcc = StringBuffer();
    String authorInfo = '';
    bool foundAnything = false;

    // 1. ESTRAZIONE DA JSON-LD
    final ldScripts =
        document.querySelectorAll("script[type='application/ld+json']");
    for (var element in ldScripts) {
      final json = element.text;
      bool hasRichJsonBody = false;

      if (authorInfo.isEmpty) {
        int authorIdx = json.indexOf('"author"');
        if (authorIdx >= 0) {
          int nameIdx = json.indexOf('"name":"', authorIdx);
          if (nameIdx >= 0) {
            final res = extractJsonString(json.substring(nameIdx + 8));
            if (res != null) {
              String trimmed = res.value.trim();
              if (trimmed.toLowerCase() != title.toLowerCase() &&
                  trimmed.toLowerCase() != "home" &&
                  trimmed.length >= 3) {
                authorInfo += trimmed;
              }
            }
          }
        }
        if (authorInfo.isEmpty) {
          int aIdx = json.indexOf('"name":"');
          if (aIdx >= 0) {
            final res = extractJsonString(json.substring(aIdx + 8));
            if (res != null) {
              String trimmed = res.value.trim();
              if (trimmed.toLowerCase() != title.toLowerCase() &&
                  trimmed.toLowerCase() != "home" &&
                  trimmed.length >= 3) {
                authorInfo += trimmed;
              }
            }
          }
        }
        int dIdx = json.indexOf('"datePublished":"');
        if (dIdx >= 0) {
          final res = extractJsonString(json.substring(dIdx + 17));
          if (res != null) {
            String dateStr = res.value;
            String date =
                dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
            authorInfo += " ($date)";
          }
        }
      }

      for (var key in [
        "\"description\":\"",
        "\"articleBody\":\"",
        "\"subtitle\":\""
      ]) {
        int searchPos = 0;
        while (true) {
          int keyPos = json.indexOf(key, searchPos);
          if (keyPos < 0) break;
          int absStart = keyPos + key.length;
          if (absStart < json.length) {
            final res = extractJsonString(json.substring(absStart));
            if (res != null) {
              if (key == "\"description\":\"") {
                int windowStart = keyPos - 400 < 0 ? 0 : keyPos - 400;
                String window = json.substring(windowStart, keyPos);
                bool isPersonOrOrg = window.contains("\"@type\":\"Person\"") ||
                    window.contains("\"@type\":\"Organization\"");
                bool isArticle = window.contains("\"@type\":\"Article\"") ||
                    window.contains("\"@type\":\"NewsArticle\"") ||
                    window.contains("\"@type\":\"TechArticle\"") ||
                    window.contains("\"@type\":\"BlogPosting\"");
                if (isPersonOrOrg || !isArticle) {
                  searchPos = absStart + res.endPos;
                  continue;
                }
              }
              if (res.value.length > 40 &&
                  !res.value.contains("http") &&
                  !bodyAcc.toString().contains(res.value) &&
                  !looksLikeTeaser(res.value)) {
                bodyAcc.write(res.value);
                bodyAcc.write("\n\n");
                if (key == "\"articleBody\":\"") {
                  hasRichJsonBody = true;
                }
              }
              searchPos = absStart + res.endPos;
            } else {
              break;
            }
          } else {
            break;
          }
        }
      }
      if (!hasRichJsonBody) {
        String? bestJsonBody = pickBestJsonArticleText(json);
        if (bestJsonBody != null &&
            !bodyAcc.toString().contains(bestJsonBody)) {
          bodyAcc.write(bestJsonBody);
          bodyAcc.write("\n\n");
          hasRichJsonBody = true;
        }
      }
      if (hasRichJsonBody) foundAnything = true;
    }

    // 2. ESTRAZIONE DA NEXT_DATA
    if (!foundAnything) {
      final nextScripts = document.querySelectorAll("script#__NEXT_DATA__");
      if (nextScripts.isNotEmpty) {
        String jsonText = nextScripts.first.text;

        Set<String> seenParagraphs = {};
        List<String> contentBlocks = jsonText.split("\"type\":\"paragraph\"");
        for (var contentBlock in contentBlocks) {
          int contentStart = contentBlock.indexOf("\"content\":[");
          if (contentStart >= 0) {
            String afterContent = contentBlock.substring(contentStart);
            StringBuffer paraText = StringBuffer();
            int searchPos = 0;
            while (true) {
              int textStart = afterContent.indexOf("\"text\":\"", searchPos);
              if (textStart < 0) break;
              int absStart = textStart + 8;
              if (absStart < afterContent.length) {
                final res = extractJsonString(afterContent.substring(absStart));
                if (res != null) {
                  if (res.value.isNotEmpty && !res.value.startsWith('{')) {
                    paraText.write(res.value);
                  }
                  searchPos = absStart + res.endPos;
                } else {
                  break;
                }
              } else {
                break;
              }
            }
            String pt = paraText.toString();
            if (pt.length > 20 && !seenParagraphs.contains(pt)) {
              seenParagraphs.add(pt);
              bodyAcc.write(pt);
              bodyAcc.write("\n\n");
              foundAnything = true;
            }
          }
        }

        if (!foundAnything) {
          Set<String> seenTextContent = {};
          for (var val in extractJsonValues(
              jsonText, "\"__typename\":\"Text\",\"content\":\"")) {
            String cleaned = collapseBlankLines(cleanText(val));
            String trimmed = cleaned.trim();
            if (trimmed.length < 30 ||
                trimmed.contains("http") ||
                trimmed.contains('{') ||
                trimmed.contains("categoryName") ||
                looksLikeUiChrome(trimmed)) {
              continue;
            }
            if (!seenTextContent.contains(trimmed)) {
              seenTextContent.add(trimmed);
              bodyAcc.write(trimmed);
              bodyAcc.write("\n\n");
              foundAnything = true;
            }
          }
        }

        if (!foundAnything) {
          int searchPos = 0;
          while (true) {
            int textStart = jsonText.indexOf("\"text\":\"", searchPos);
            if (textStart < 0) break;
            int absStart = textStart + 8;
            if (absStart < jsonText.length) {
              final res = extractJsonString(jsonText.substring(absStart));
              if (res != null) {
                if (res.value.length > 30 &&
                    !res.value.contains("http") &&
                    !res.value.contains("{")) {
                  bodyAcc.write(res.value);
                  bodyAcc.write("\n\n");
                  foundAnything = true;
                  searchPos = absStart + res.endPos;
                } else {
                  break;
                }
              } else {
                break;
              }
            } else {
              break;
            }
          }
        }

        if (!foundAnything) {
          String? best = pickBestJsonArticleText(jsonText);
          if (best != null) {
            bodyAcc.write(best);
            bodyAcc.write("\n\n");
            foundAnything = true;
          }
        }
      }
    }

    if (bodyAcc.length < 300 &&
        htmlContent.contains("cbc.ca") &&
        htmlContent.contains("__INITIAL_STATE__")) {
      String? cbcBody = extractCbcInitialStateArticleText(htmlContent);
      if (cbcBody != null) {
        bodyAcc.write(cbcBody);
        bodyAcc.write("\n\n");
        foundAnything = true;
      }
    }

    if (!foundAnything || bodyAcc.length < 300) {
      final contentSelectors = [
        ".body-article .content h2, .body-article .content h3, .body-article .content p, .body-article .content li",
        ".blog-detail-wrapper .rich-text h2, .blog-detail-wrapper .rich-text h3, .blog-detail-wrapper .rich-text p, .blog-detail-wrapper .rich-text li",
        ".node-text .textarea-content-body",
        ".node-summary",
        ".section--content-news .left-content p",
        ".section--content-news .title-quote-text p",
        ".story__text p, .story__text h2, .story__text li",
        "#article-body .story__text",
        ".post-content > h2, .post-content > h3, .post-content > p, .post-content > li",
        ".entry-content h2, .entry-content h3, .entry-content p, .entry-content li",
        ".wp-block-post-content h2, .wp-block-post-content h3, .wp-block-post-content p, .wp-block-post-content li",
        ".ifq-post__content p",
        ".ifq-post__content",
        ".media-content.news-txt p, .media-content.news-txt figcaption, .media-content.news-txt .image-caption",
        ".col-md-8.pb-5 .mt-4 p",
        "p[data-type='paragraph']",
        "article [data-testid='article-body'] p",
        "article [data-testid='paragraph']",
        "article [data-type='paragraph']",
        ".prose p",
        ".wsj-article-body p",
        "article p",
        ".atext",
        ".art-text",
        ".story-content p",
        ".article-body p",
        "#col-sx-interna p",
        // selettori semantici aggiuntivi
        "main article p",
        "main p",
        "[role='main'] p",
        ".content p",
        ".article p",
        ".text p",
        ".body p",
        ".post p",
        "[class*='article'] p",
        "[class*='content'] p",
        "[class*='story'] p",
        "[class*='text'] p",
        "[class*='body'] p",
      ];
      String bestSelAcc = '';
      for (var selStr in contentSelectors) {
        final seenTexts = <String>{};
        StringBuffer selAcc = StringBuffer();
        final elements = document.querySelectorAll(selStr);
        for (var element in elements) {
          String text = element.text.trim();
          if (text.isEmpty) continue;
          if (text.toLowerCase().contains("enable js")) continue;
          if (looksLikeUiChrome(text)) continue;
          if (text.length < 20) continue;
          // deduplicazione per paragrafo
          if (seenTexts.contains(text)) continue;
          seenTexts.add(text);
          selAcc.write(text);
          selAcc.write("\n\n");
        }
        if (selAcc.length > bestSelAcc.length) {
          bestSelAcc = selAcc.toString();
        }
      }
      if (bestSelAcc.length > 200) {
        bodyAcc.write(bestSelAcc);
      } else if (bestSelAcc.isEmpty) {
        // Heuristic fallback: tutti i <p> con almeno 80 chars e almeno 1 frase
        final seenFallback = <String>{};
        final allParas = document.querySelectorAll('p');
        StringBuffer fallbackAcc = StringBuffer();
        for (var p in allParas) {
          final text = p.text.trim();
          if (text.length < 80) continue;
          if (looksLikeUiChrome(text)) continue;
          if (countSentences(text) < 1) continue;
          if (seenFallback.contains(text)) continue;
          seenFallback.add(text);
          fallbackAcc.write(text);
          fallbackAcc.write('\n\n');
        }
        if (fallbackAcc.length > 200) {
          bodyAcc.write(fallbackAcc.toString());
        }
      }
    }

    if (bodyAcc.toString().trim().length < 40) {
      String? teaser = pickTeaserJsonArticleText(htmlContent);
      if (teaser != null) {
        bodyAcc.write(teaser);
        bodyAcc.write("\n\n");
      }
    }

    StringBuffer finalText = StringBuffer();
    if (authorInfo.isNotEmpty) {
      String prefix = authorPrefix(languageCode);
      finalText.write("$prefix $authorInfo\n\n");
    }
    finalText.write(bodyAcc.toString());

    String content = stripPostExtractionNoise(cleanText(finalText.toString()));
    String finalContent = collapseBlankLines(content);

    String? metaDesc = pickMetaDescription(document);
    if (metaDesc != null) {
      bool shouldFallback = bodyAcc.toString().trim().length < 120 ||
          countSentences(finalContent) < 2 ||
          looksLikeUiChrome(finalContent);
      if (shouldFallback) {
        StringBuffer fallback = StringBuffer();
        if (authorInfo.isNotEmpty) {
          String prefix = authorPrefix(languageCode);
          fallback.write("$prefix $authorInfo\n\n");
        }
        fallback.write(metaDesc.trim());
        String fallbackContent = collapseBlankLines(
            stripPostExtractionNoise(cleanText(fallback.toString())));
        if (fallbackContent.length > finalContent.length) {
          finalContent = fallbackContent;
        }
      }
    }

    if (finalContent.trim().length < 10) {
      String? url = pickRedditLinkPostUrl(document);
      if (url != null) {
        finalContent = "Link esterno: $url";
      }
    }

    // Non salviamo più file debug nella cartella Documenti visibile
    // all'utente. I log diagnostici restano disponibili da Impostazioni >
    // Copia log tramite AppLogger.

    return ArticleContent(title: title, content: finalContent);
  }
}

class JsonExtractResult {
  final String value;
  final int endPos;
  JsonExtractResult(this.value, this.endPos);
}
