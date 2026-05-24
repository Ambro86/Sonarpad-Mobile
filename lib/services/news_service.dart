import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import 'news_sources/english_news_sources.dart';
import 'news_sources/italian_news_sources.dart';
import 'news_sources/news_rss_source.dart';

enum NewsLanguage { italian, english }

extension NewsLanguageInfo on NewsLanguage {
  String label(AppLocalizations l10n) => switch (this) {
        NewsLanguage.italian => l10n.italian,
        NewsLanguage.english => l10n.english,
      };

  List<NewsRssSource> get rssSources => switch (this) {
        NewsLanguage.italian => italianNewsSources,
        NewsLanguage.english => englishNewsSources,
      };
}

class NewsService {
  final http.Client _client;
  NewsService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<NewsArticle>> fetchTopNews(
    NewsLanguage language, {
    NewsRssSource? source,
  }) async {
    if (source != null) {
      return fetchSourceNews(source);
    }

    final articles = <NewsArticle>[];
    for (final source in language.rssSources) {
      articles.addAll(await _fetchRssSource(source));
    }
    _sortNewestFirst(articles);
    return articles.take(40).toList();
  }

  Future<List<NewsArticle>> fetchSourceNews(NewsRssSource source) async {
    final articles = await _fetchRssSource(source);
    _sortNewestFirst(articles);
    return articles.take(40).toList();
  }

  void _sortNewestFirst(List<NewsArticle> articles) {
    articles.sort((a, b) {
      final aDate = a.publishedAt;
      final bDate = b.publishedAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
  }

  Future<NewsArticleContent> fetchArticleContent(NewsArticle article) async {
    final resolvedUrl = await _resolveArticleUrl(article.link);
    if (_isGoogleNewsArticleUrl(resolvedUrl)) {
      return NewsArticleContent(text: article.summary, url: article.link);
    }
    final response = await _client.get(
      Uri.parse(resolvedUrl),
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Accept-Language': 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Articolo non raggiungibile: ${response.statusCode}');
    }
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (_isGoogleConsentPage(html) || _isGoogleFullCoveragePage(html)) {
      return NewsArticleContent(text: article.summary, url: article.link);
    }
    final text = _extractArticleText(html);
    return NewsArticleContent(
      text: text.isEmpty ? article.summary : text,
      url: resolvedUrl,
    );
  }

  Future<List<NewsArticle>> _fetchRssSource(NewsRssSource rssSource) async {
    final response = await _client.get(rssSource.uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore RSS ${rssSource.name}: ${response.statusCode}');
    }
    final doc = XmlDocument.parse(utf8.decode(response.bodyBytes));
    final items = doc.findAllElements('item');
    var index = 0;
    return items.map((item) {
      index++;
      final title = _text(item, 'title');
      final link = _text(item, 'link');
      final description = _cleanRssDescription(_text(item, 'description'));
      final source = item.findElements('source').isNotEmpty
          ? item.findElements('source').first.innerText.trim()
          : rssSource.name;
      final pubDateRaw = _text(item, 'pubDate');
      return NewsArticle(
        id: '${rssSource.name}_$index',
        title: _cleanGoogleTitle(title),
        link: link,
        summary: description,
        source: source,
        publishedAt: DateTime.tryParse(pubDateRaw) ?? _parseRssDate(pubDateRaw),
      );
    }).toList();
  }

  String _text(XmlElement parent, String name) {
    final elements = parent.findElements(name);
    if (elements.isEmpty) return '';
    return elements.first.innerText.trim();
  }

  String _cleanGoogleTitle(String title) {
    final idx = title.lastIndexOf(' - ');
    if (idx > 0) return title.substring(0, idx).trim();
    return title.trim();
  }

  String _cleanHtml(String value) {
    if (value.trim().isEmpty) return '';
    final text = html_parser.parse(value).body?.text ?? value;
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String _cleanRssDescription(String value) {
    if (value.trim().isEmpty) return '';
    final document = html_parser.parse(value);
    final firstLink = document.getElementsByTagName('a').firstOrNull;
    if (firstLink != null) return _cleanHtml(firstLink.text);
    return _cleanHtml(value);
  }

  DateTime? _parseRssDate(String value) {
    // Esempio: Fri, 15 May 2026 02:40:00 GMT
    try {
      return HttpDate.parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolveArticleUrl(String url) async {
    if (!_isGoogleNewsArticleUrl(url)) return url;
    final resolved = await _resolveGoogleNewsArticleUrl(url);
    return resolved ?? url;
  }

  bool _isGoogleNewsArticleUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.toLowerCase() != 'news.google.com') {
      return false;
    }
    final path = uri.path.toLowerCase();
    return path.contains('/rss/articles/') ||
        path.contains('/articles/') ||
        path.contains('/read/') ||
        path.contains('/__i/rss/rd/articles/');
  }

  Future<String?> _resolveGoogleNewsArticleUrl(String url) async {
    final htmlResponse = await _client.get(
      Uri.parse(url),
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    );
    if (htmlResponse.statusCode < 200 || htmlResponse.statusCode >= 300) {
      return null;
    }
    final html = utf8.decode(htmlResponse.bodyBytes, allowMalformed: true);
    if (_isGoogleConsentPage(html) || _isGoogleFullCoveragePage(html)) {
      return null;
    }
    final directUrl = _extractGoogleNewsDirectUrl(html);
    if (directUrl != null) return directUrl;

    final articleId = _extractGoogleNewsArticleId(url);
    final signature = _extractBetween(html, 'data-n-a-sg="', '"') ??
        _extractBetween(html, "data-n-a-sg='", "'");
    final timestamp = _extractBetween(html, 'data-n-a-ts="', '"') ??
        _extractBetween(html, "data-n-a-ts='", "'");
    if (articleId == null || signature == null || timestamp == null) {
      return null;
    }

    final requestInner =
        '["garturlreq",[["en-US","US",["WEB_TEST_1_0_0"],null,null,1,1,"US:en",null,180,null,null,null,null,null,0,null,null,[1608992183,723341000]],"en-US","US",1,[2,3,4,8],1,0,"655000234",0,0,null,0],"$articleId",$timestamp,"$signature"]';
    final fReq = jsonEncode([
      [
        ['Fbv4je', jsonEncode(requestInner)]
      ]
    ]);
    final response = await _client.post(
      Uri.parse(
        'https://news.google.com/_/DotsSplashUi/data/batchexecute?rpcids=Fbv4je',
      ),
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://news.google.com/',
        'Origin': 'https://news.google.com',
        'X-Same-Domain': '1',
      },
      body: 'f.req=${Uri.encodeQueryComponent(fReq)}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return _extractDecodedGoogleNewsUrl(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }

  String? _extractGoogleNewsArticleId(String url) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments;
    if (segments == null) return null;
    final index = segments.indexWhere((segment) => segment == 'articles');
    if (index < 0 || index + 1 >= segments.length) return null;
    final id = segments[index + 1].trim();
    return id.isEmpty ? null : id;
  }

  String? _extractGoogleNewsDirectUrl(String html) {
    final candidate = _extractBetween(html, 'data-n-au="', '"') ??
        _extractBetween(html, "data-n-au='", "'");
    if (candidate == null) return null;
    final uri = Uri.tryParse(candidate.trim());
    if (uri == null || _isGoogleNewsArticleUrl(candidate)) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return candidate.trim();
  }

  String? _extractDecodedGoogleNewsUrl(String response) {
    final normalized = response.replaceAll(r'\"', '"').replaceAll(r'\/', '/');
    final url = _extractBetween(normalized, '["garturlres","', '",')?.trim();
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return url;
  }

  String? _extractBetween(String value, String start, String end) {
    final from = value.indexOf(start);
    if (from < 0) return null;
    final rest = value.substring(from + start.length);
    final to = rest.indexOf(end);
    if (to < 0) return null;
    return rest.substring(0, to);
  }

  String _extractArticleText(String html) {
    final document = html_parser.parse(html);
    final articleElements = document.getElementsByTagName('article');
    final paragraphs = articleElements.isEmpty
        ? document.getElementsByTagName('p')
        : articleElements
            .expand((element) => element.getElementsByTagName('p'));
    final text = paragraphs
        .map((element) => _cleanHtml(element.text))
        .where((value) => value.length > 40)
        .join('\n\n')
        .trim();
    if (text.isNotEmpty) return text;

    final description = document
        .querySelector('meta[property="og:description"]')
        ?.attributes['content'];
    return _cleanHtml(description ?? '');
  }

  bool _isGoogleConsentPage(String html) {
    final lower = html.toLowerCase();
    return lower.contains('before you continue') ||
        lower.contains('prima di continuare su google') ||
        lower.contains('consent.google.com/save');
  }

  bool _isGoogleFullCoveragePage(String html) {
    final lower = html.toLowerCase();
    return lower.contains('full coverage') ||
        lower.contains('copertura giornalistica completa');
  }
}

extension FirstOrNullList<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class HttpDate {
  static DateTime parse(String value) {
    final months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final parts =
        value.split(RegExp(r'[ ,:]')).where((e) => e.isNotEmpty).toList();
    if (parts.length < 7) throw const FormatException('Data RSS non valida');
    final day = int.parse(parts[1]);
    final month = months[parts[2]]!;
    final year = int.parse(parts[3]);
    final hour = int.parse(parts[4]);
    final minute = int.parse(parts[5]);
    final second = int.parse(parts[6]);
    return DateTime.utc(year, month, day, hour, minute, second).toLocal();
  }
}
