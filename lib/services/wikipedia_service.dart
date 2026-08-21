import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class WikipediaSearchResult {
  final int pageId;
  final String title;
  const WikipediaSearchResult({required this.pageId, required this.title});
}

class WikipediaArticle {
  final String title;
  final String text;
  final String url;
  final List<WikipediaArticleSection> sections;
  const WikipediaArticle(
      {required this.title,
      required this.text,
      required this.url,
      required this.sections});
}

class WikipediaArticleSection {
  final String title;
  final int level;
  final String text;
  const WikipediaArticleSection(
      {required this.title, required this.level, required this.text});
}

class WikipediaService {
  final http.Client _client;
  WikipediaService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<WikipediaSearchResult>> search(String query,
      {String lang = 'it'}) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'srlimit': '10',
      'format': 'json',
      'formatversion': '2',
    });
    final response =
        await _client.get(uri, headers: {'User-Agent': 'SonarpadMobile/0.1'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_searchError(lang, response.statusCode));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final hits = (json['query']['search'] as List).cast<Map<String, dynamic>>();
    return hits
        .map((e) => WikipediaSearchResult(
            pageId: e['pageid'] as int, title: e['title'] as String))
        .toList();
  }

  Future<WikipediaArticle> importArticle(int pageId,
      {String lang = 'it'}) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'parse',
      'pageid': '$pageId',
      'prop': 'text',
      'disableeditsection': '1',
      'format': 'json',
      'formatversion': '2',
    });
    final response =
        await _client.get(uri, headers: {'User-Agent': 'SonarpadMobile/0.1'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_importError(lang, response.statusCode));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final parse = json['parse'] as Map<String, dynamic>;
    final title = parse['title'] as String;
    final html = parse['text'] as String;
    final text = _parseArticleHtmlToText(html);
    final url =
        'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';
    return WikipediaArticle(
        title: title,
        text: text,
        url: url,
        sections: _extractArticleSections(text));
  }

  String _parseArticleHtmlToText(String html) {
    final document = html_parser.parseFragment(html);
    final container = document.querySelector('.mw-parser-output');
    if (container == null) {
      _removeUnwantedElements(document);
      return _normalizeTextBlock(document.text ?? '');
    }

    _removeUnwantedElements(container);
    final blocks = <String>[];
    for (final child in container.children) {
      if (_shouldSkipElement(child)) continue;

      final name = child.localName ?? '';
      if (!_acceptedBlockNames.contains(name) &&
          _wrappedHeadingName(child) == null) {
        continue;
      }

      final text = _normalizeTextBlock(_nodeText(child));
      if (text.isEmpty) continue;

      final wrappedHeading = _wrappedHeadingName(child);
      if (wrappedHeading != null) {
        blocks.add(_headingText(wrappedHeading, text));
      } else if (name.startsWith('h')) {
        blocks.add(_headingText(name, text));
      } else {
        blocks.add(text);
      }
    }

    final fullText = _normalizeTextBlock(container.text);
    if (blocks.isEmpty) {
      return fullText;
    }

    final structuredText = blocks.join('\n\n');
    if (fullText.length > structuredText.length * 2) {
      return fullText;
    }
    return structuredText;
  }

  static const _acceptedBlockNames = {
    'p',
    'ul',
    'ol',
    'dl',
    'div',
    'blockquote',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  };

  void _removeUnwantedElements(dom.Node root) {
    final elements = root is dom.DocumentFragment
        ? root.querySelectorAll(_unwantedSelector)
        : root is dom.Element
            ? root.querySelectorAll(_unwantedSelector)
            : const <dom.Element>[];
    for (final element in elements) {
      element.remove();
    }
  }

  static const _unwantedSelector =
      'style, script, noscript, table, figure, figcaption, sup.reference, '
      '.mw-editsection, .reference, .reflist, .navbox, .vertical-navbox, '
      '.authority-control, .metadata, .infobox, .sinottico, .thumb, .tright, '
      '.tleft, .toc, .hatnote, .ambox, .ombox, .mbox, .avviso, '
      '.sistersitebox, .mw-empty-elt, .noprint, .printfooter, .catlinks, '
      '.portal, .portalbox, .CdA, .itwiki-template-occhiello, '
      '.itwiki-template-occhiello-progetto';

  bool _shouldSkipElement(dom.Element element) {
    final name = element.localName;
    if (name == 'table' ||
        name == 'style' ||
        name == 'script' ||
        name == 'figure' ||
        name == 'figcaption' ||
        name == 'noscript') {
      return true;
    }

    const skippedClasses = {
      'mw-editsection',
      'reference',
      'reflist',
      'navbox',
      'vertical-navbox',
      'authority-control',
      'metadata',
      'infobox',
      'sinottico',
      'thumb',
      'tright',
      'tleft',
      'toc',
      'hatnote',
      'ambox',
      'ombox',
      'mbox',
      'avviso',
      'sistersitebox',
      'noprint',
      'printfooter',
      'catlinks',
      'portal',
      'portalbox',
      'CdA',
      'itwiki-template-occhiello',
      'itwiki-template-occhiello-progetto',
      'mw-empty-elt',
    };
    return element.classes.any(skippedClasses.contains);
  }

  String _nodeText(dom.Node node) {
    if (node is dom.Text) {
      return node.data;
    }
    if (node is! dom.Element || _shouldSkipElement(node)) {
      return '';
    }
    if (node.localName == 'br') {
      return '\n';
    }
    final buffer = StringBuffer();
    for (final child in node.nodes) {
      final childText = _nodeText(child);
      if (childText.isEmpty) continue;
      if (child is dom.Element &&
          _acceptedBlockNames.contains(child.localName ?? '') &&
          buffer.isNotEmpty &&
          !buffer.toString().endsWith('\n')) {
        buffer.write('\n');
      }
      buffer.write(childText);
    }
    return buffer.toString();
  }

  String? _wrappedHeadingName(dom.Element element) {
    if (element.classes.contains('mw-heading2')) return 'h2';
    if (element.classes.contains('mw-heading3')) return 'h3';
    if (element.classes.contains('mw-heading4')) return 'h4';
    if (element.classes.contains('mw-heading5')) return 'h5';
    if (element.classes.contains('mw-heading6')) return 'h6';
    return null;
  }

  String _headingText(String name, String text) {
    final marks = switch (name) {
      'h2' => '==',
      'h3' => '===',
      'h4' => '====',
      'h5' => '=====',
      'h6' => '======',
      _ => '',
    };
    return marks.isEmpty ? text : '$marks $text $marks';
  }

  String _normalizeTextBlock(String text) {
    final out = StringBuffer();
    var blankRun = 0;
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (_looksLikeCssOrTemplateNoise(trimmed)) {
        continue;
      }
      if (trimmed.isEmpty) {
        blankRun += 1;
        if (blankRun <= 1 && out.isNotEmpty) {
          out.write('\n');
        }
        continue;
      }
      blankRun = 0;
      if (out.isNotEmpty && !out.toString().endsWith('\n')) {
        out.write('\n');
      }
      out.write(trimmed);
    }
    return out.toString().trim();
  }

  bool _looksLikeCssOrTemplateNoise(String line) {
    if (line.isEmpty) return false;
    if (line.startsWith('.mw-parser-output') ||
        line.startsWith('body.skin-') ||
        line.startsWith('html.skin-') ||
        line.startsWith('html:not(') ||
        line.startsWith('@media ') ||
        line.startsWith('}@media ') ||
        line.startsWith('/*') ||
        line.startsWith('*/')) {
      return true;
    }
    final cssMarkers = <String>[
      '{',
      '}',
      'font-size:',
      'background:',
      'background-color:',
      'border:',
      'display:',
      'margin:',
      'padding:',
      'width:',
      'text-align:',
    ];
    final hasSelectorStart = line.startsWith('.') ||
        line.startsWith('#') ||
        line.startsWith('body.') ||
        line.startsWith('html.');
    if (hasSelectorStart && cssMarkers.any(line.contains)) {
      return true;
    }
    return false;
  }

  List<WikipediaArticleSection> _extractArticleSections(String text) {
    final lines = text.split('\n');
    final headings = <({int lineIndex, int level, String title})>[];
    for (var i = 0; i < lines.length; i += 1) {
      final heading = _headingTitle(lines[i]);
      if (heading != null) {
        headings
            .add((lineIndex: i, level: heading.level, title: heading.title));
      }
    }

    final sections = <WikipediaArticleSection>[];
    for (var i = 0; i < headings.length; i += 1) {
      final heading = headings[i];
      var end = lines.length;
      for (var j = i + 1; j < headings.length; j += 1) {
        if (headings[j].level <= heading.level) {
          end = headings[j].lineIndex;
          break;
        }
      }
      final sectionText =
          lines.sublist(heading.lineIndex, end).join('\n').trim();
      if (sectionText.isNotEmpty) {
        sections.add(WikipediaArticleSection(
            title: heading.title, level: heading.level, text: sectionText));
      }
    }
    return sections;
  }

  ({int level, String title})? _headingTitle(String line) {
    final trimmed = line.trim();
    for (var level = 2; level <= 6; level += 1) {
      final marks = '=' * level;
      final prefix = '$marks ';
      final suffix = ' $marks';
      if (!trimmed.startsWith(prefix) || !trimmed.endsWith(suffix)) {
        continue;
      }
      final body = trimmed
          .substring(prefix.length, trimmed.length - suffix.length)
          .trim();
      if (body.isEmpty || body.contains('==')) {
        return null;
      }
      return (level: level, title: body);
    }
    return null;
  }

  String _searchError(String lang, int statusCode) => switch (lang) {
        'en' => 'Wikipedia error: $statusCode',
        'fr' => 'Erreur Wikipedia : $statusCode',
        'es' => 'Error de Wikipedia: $statusCode',
        'pt' || 'pt_BR' || 'pt-BR' => 'Erro da Wikipédia: $statusCode',
        'zh' || 'zh_CN' || 'zh-CN' => '维基百科错误：$statusCode',
        _ => 'Errore Wikipedia: $statusCode',
      };

  String _importError(String lang, int statusCode) => switch (lang) {
        'en' => 'Wikipedia import error: $statusCode',
        'fr' => 'Erreur d\'importation Wikipedia : $statusCode',
        'es' => 'Error de importación de Wikipedia: $statusCode',
        'pt' || 'pt_BR' || 'pt-BR' =>
          'Erro ao importar da Wikipédia: $statusCode',
        'zh' || 'zh_CN' || 'zh-CN' => '维基百科导入错误：$statusCode',
        _ => 'Errore importazione Wikipedia: $statusCode',
      };
}
