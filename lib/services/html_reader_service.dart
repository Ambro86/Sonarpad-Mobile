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
    final text = html_parser.parseFragment(input).text;
    return text ?? input;
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
        v.contains('consent');
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
    final decoded = decodeHtmlEntities(decodeUnicode(input));
    var text = decoded
        .replaceAll('ÃƒÂ¨', 'Ã¨')
        .replaceAll('ÃƒÂ ', 'Ã ')
        .replaceAll('ÃƒÂ¹', 'Ã¹')
        .replaceAll('ÃƒÂ²', 'Ã²')
        .replaceAll('ÃƒÂ¬', 'Ã¬')
        .replaceAll('Ã‚Â ', ' ')
        .replaceAll('ÃƒÂ©', 'Ã©')
        .replaceAll('Ã‚', '');

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\\"', '"')
        .replaceAll('\\n', '\n')
        .replaceAll('\\/', '/');

    StringBuffer cleaned = StringBuffer();
    bool inTag = false;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '<') {
        inTag = true;
      } else if (text[i] == '>') {
        inTag = false;
        cleaned.write(' ');
      } else if (!inTag) {
        cleaned.write(text[i]);
      }
    }
    return cleaned.toString();
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
    while(result.endsWith('\n')) {
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
      for (var val in extractJsonValues(htmlContent, '"type":"text","content":"')) {
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

  static ArticleContent? extractJinaMarkdownFixture(String rawContent, String languageCode) {
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
      if (trimmed.toLowerCase() == "[you make our work possible.](https://iowacapitaldispatch.com/donate/?oa_referrer=midstorybox)") break;
      if (trimmed.startsWith("If you value") || trimmed.startsWith("Support")) break;
      lines.add(trimmed);
    }
    String body = collapseBlankLines(cleanText(lines.join('\n')));
    String content = body.trim();
    if (content.length < 300 || countSentences(content) < 3) return null;
    return ArticleContent(title: title, content: content);
  }

  static String authorPrefix(String languageCode) {
    switch (languageCode) {
      case 'it': return "Di";
      case 'fr': return "Par";
      case 'es': return "Por";
      case 'en': return "By";
      default: return "Di";
    }
  }

  static String pickTitle(Document document, String languageCode) {
    final selectors = ["meta[property='og:title']", "h1", "title"];
    for (var sel in selectors) {
      final elements = document.querySelectorAll(sel);
      if (elements.isNotEmpty) {
        var el = elements.first;
        String t = sel.contains("meta") ? (el.attributes['content'] ?? '') : el.text;
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

  static String? pickRedditLinkPostUrl(Document document) {
    final elements = document.querySelectorAll("shreddit-post[post-type='link'] div[slot='post-media-container'] a[href]");
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
        (lower.contains("\"categoryname\":\"undefined\"") && lower.contains("\"enabled\":\"true\""));
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
      if (!isKnownJsNoiseLine(line)) {
        validLines.add(line);
      }
    }
    return validLines.join('\n');
  }

  static ArticleContent? readerModeExtract(String htmlContent, String languageCode) {
    if (!htmlContent.contains("<html")) {
      var article = extractJinaMarkdownFixture(htmlContent, languageCode);
      if (article != null) return article;
    }

    final document = html_parser.parse(htmlContent);
    final title = pickTitle(document, languageCode);

    StringBuffer bodyAcc = StringBuffer();
    String authorInfo = '';
    bool foundAnything = false;

    // 1. ESTRAZIONE DA JSON-LD
    final ldScripts = document.querySelectorAll("script[type='application/ld+json']");
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
            String date = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
            authorInfo += " ($date)";
          }
        }
      }

      for (var key in ["\"description\":\"", "\"articleBody\":\"", "\"subtitle\":\""]) {
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
                bool isPersonOrOrg = window.contains("\"@type\":\"Person\"") || window.contains("\"@type\":\"Organization\"");
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
          for (var val in extractJsonValues(jsonText, "\"__typename\":\"Text\",\"content\":\"")) {
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
                if (res.value.length > 30 && !res.value.contains("http") && !res.value.contains("{")) {
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

    if (bodyAcc.length < 300 && htmlContent.contains("cbc.ca") && htmlContent.contains("__INITIAL_STATE__")) {
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
      ];
      String bestSelAcc = '';
      for (var selStr in contentSelectors) {
        StringBuffer selAcc = StringBuffer();
        final elements = document.querySelectorAll(selStr);
        for (var element in elements) {
          String text = element.text;
          if (text.toLowerCase().contains("enable js")) continue;
          selAcc.write(text);
          selAcc.write("\n\n");
        }
        if (selAcc.length > bestSelAcc.length) {
          bestSelAcc = selAcc.toString();
        }
      }
      if (bestSelAcc.length > 200) {
        bodyAcc.write(bestSelAcc);
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
        String fallbackContent = collapseBlankLines(stripPostExtractionNoise(cleanText(fallback.toString())));
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

    return ArticleContent(title: title, content: finalContent);
  }
}

class JsonExtractResult {
  final String value;
  final int endPos;
  JsonExtractResult(this.value, this.endPos);
}
