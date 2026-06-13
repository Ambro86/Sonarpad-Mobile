import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:rhttp_plus/rhttp_plus.dart' as rhttp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import 'news_sources/english_news_sources.dart';
import 'news_sources/italian_news_sources.dart';
import 'news_sources/news_rss_source.dart';

import 'html_reader_service.dart';
import 'news_sources/french_news_sources.dart';
import 'news_sources/spanish_news_sources.dart';
import 'news_sources/portuguese_news_sources.dart';
import 'news_sources/polish_news_sources.dart';
import 'news_sources/czech_news_sources.dart';

enum NewsLanguage { italian, english, french, spanish, portuguese, polish, czech }

extension NewsLanguageInfo on NewsLanguage {
  String get code => switch (this) {
        NewsLanguage.italian => 'it',
        NewsLanguage.english => 'en',
        NewsLanguage.french => 'fr',
        NewsLanguage.spanish => 'es',
        NewsLanguage.portuguese => 'pt',
        NewsLanguage.polish => 'pl',
        NewsLanguage.czech => 'cs',
      };

  String label(AppLocalizations l10n) => switch (this) {
        NewsLanguage.italian => l10n.italian,
        NewsLanguage.english => l10n.english,
        NewsLanguage.french => l10n.french,
        NewsLanguage.spanish => l10n.spanish,
        NewsLanguage.portuguese => l10n.radioLanguagePt,
        NewsLanguage.polish => l10n.radioLanguagePl,
        NewsLanguage.czech => l10n.radioLanguageCs,
      };

  List<NewsRssSource> get rssSources => switch (this) {
        NewsLanguage.italian => italianNewsSources,
        NewsLanguage.english => englishNewsSources,
        NewsLanguage.french => frenchNewsSources,
        NewsLanguage.spanish => spanishNewsSources,
        NewsLanguage.portuguese => portugueseNewsSources,
        NewsLanguage.polish => polishNewsSources,
        NewsLanguage.czech => czechNewsSources,
      };
}

enum _BrowserFetchProfile { chrome, iphone }

class NewsService {
  static final _corriereHomeFeedUri = Uri.parse(
    'https://xml2.corriereobjects.it/feed-hp/homepage-restyle-2025.xml',
  );

  static const _chromeClientSettings = rhttp.ClientSettings(
    emulator: rhttp.Emulation.chrome136,
    timeoutSettings: rhttp.TimeoutSettings(
      timeout: Duration(seconds: 30),
      connectTimeout: Duration(seconds: 15),
    ),
  );
  static const _iphoneClientSettings = rhttp.ClientSettings(
    emulator: rhttp.Emulation.safariIos1811,
    timeoutSettings: rhttp.TimeoutSettings(
      timeout: Duration(seconds: 30),
      connectTimeout: Duration(seconds: 15),
    ),
  );
  static Future<http.Client>? _chromeClientFuture;
  static Future<http.Client>? _iphoneClientFuture;

  final http.Client _client;
  final bool _useBrowserClient;
  NewsService({http.Client? client})
      : _client = client ?? http.Client(),
        _useBrowserClient = client == null;

  String _getPrefsKey(NewsLanguage language) =>
      'news_sources_order_${language.name}';
  String _getHiddenPrefsKey(NewsLanguage language) =>
      'news_sources_hidden_${language.name}';
  String _getCustomPrefsKey(NewsLanguage language) =>
      'news_custom_sources_${language.name}';
  String _getReadArticlesKey(NewsLanguage language, String sourceName) =>
      'news_read_articles_${language.name}_$sourceName';

  Future<List<NewsArticle>> getReadArticles(NewsLanguage language, String sourceName) async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getStringList(_getReadArticlesKey(language, sourceName)) ?? [];
    return listStr.map((s) {
      try {
        final map = jsonDecode(s);
        return NewsArticle(
          id: map['id'],
          title: map['title'],
          link: map['link'],
          summary: map['summary'],
          source: map['source'],
          publishedAt: map['publishedAt'] != null ? DateTime.parse(map['publishedAt']) : null,
        );
      } catch (_) {
        return null;
      }
    }).whereType<NewsArticle>().toList();
  }

  Future<void> addReadArticle(NewsLanguage language, String sourceName, NewsArticle article) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getReadArticlesKey(language, sourceName);
    var current = await getReadArticles(language, sourceName);
    current.removeWhere((a) => a.id == article.id);
    current.insert(0, article);
    if (current.length > 50) {
      current = current.take(50).toList(); // Maximum 50 read articles per source
    }
    final listStr = current.map((a) => jsonEncode({
      'id': a.id,
      'title': a.title,
      'link': a.link,
      'summary': a.summary,
      'source': a.source,
      'publishedAt': a.publishedAt?.toIso8601String(),
    })).toList();
    await prefs.setStringList(key, listStr);
  }

  Future<void> clearReadArticles(NewsLanguage language, String sourceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getReadArticlesKey(language, sourceName));
  }

  Future<List<NewsRssSource>> getCustomSources(NewsLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    final customListStr =
        prefs.getStringList(_getCustomPrefsKey(language)) ?? [];
    return customListStr
        .map((s) {
          try {
            return NewsRssSource.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<NewsRssSource>()
        .toList();
  }

  Future<void> addCustomSource(
      NewsLanguage language, String name, String urlOrSearch) async {
    final prefs = await SharedPreferences.getInstance();
    final customSources = await getCustomSources(language);

    String finalUrl = urlOrSearch.trim();
    if (!finalUrl.toLowerCase().startsWith('http://') &&
        !finalUrl.toLowerCase().startsWith('https://')) {
      if (finalUrl.contains('.') && !finalUrl.contains(' ')) {
        finalUrl = 'https://$finalUrl';
      } else {
        final query = Uri.encodeComponent(finalUrl);
        String hl, gl, ceid;
        switch (language) {
          case NewsLanguage.italian:
            hl = 'it';
            gl = 'IT';
            ceid = 'IT:it';
            break;
          case NewsLanguage.english:
            hl = 'en-US';
            gl = 'US';
            ceid = 'US:en';
            break;
          case NewsLanguage.french:
            hl = 'fr';
            gl = 'FR';
            ceid = 'FR:fr';
            break;
          case NewsLanguage.spanish:
            hl = 'es-419';
            gl = '419';
            ceid = '419:es';
            break;
          case NewsLanguage.portuguese:
            hl = 'pt-PT';
            gl = 'PT';
            ceid = 'PT:pt-150';
            break;
          case NewsLanguage.polish:
            hl = 'pl';
            gl = 'PL';
            ceid = 'PL:pl';
            break;
          case NewsLanguage.czech:
            hl = 'cs';
            gl = 'CZ';
            ceid = 'CZ:cs';
            break;
        }
        finalUrl =
            'https://news.google.com/rss/search?q=$query&hl=$hl&gl=$gl&ceid=$ceid';
      }
    }

    // Controlla se esiste già
    if (customSources.any((s) => s.uri.toString() == finalUrl)) {
      throw Exception('Sorgente già presente');
    }

    final newSource = NewsRssSource(
      name: name,
      uri: Uri.parse(finalUrl),
      isCustom: true,
    );

    customSources.add(newSource);
    final stringList =
        customSources.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_getCustomPrefsKey(language), stringList);
  }

  Future<void> removeCustomSource(NewsLanguage language, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final customSources = await getCustomSources(language);

    customSources.removeWhere((s) => s.name == name);
    final stringList =
        customSources.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_getCustomPrefsKey(language), stringList);

    // Rimuovilo anche dai nascosti/ordinati
    final hiddenNames = prefs.getStringList(_getHiddenPrefsKey(language)) ?? [];
    if (hiddenNames.remove(name)) {
      await prefs.setStringList(_getHiddenPrefsKey(language), hiddenNames);
    }
    final order = prefs.getStringList(_getPrefsKey(language)) ?? [];
    if (order.remove(name)) {
      await prefs.setStringList(_getPrefsKey(language), order);
    }
  }

  Future<List<NewsRssSource>> getOrderedSources(NewsLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    final defaultSources = language.rssSources;
    final customSources = await getCustomSources(language);

    final allSources = [...defaultSources, ...customSources];
    final hiddenNames = prefs.getStringList(_getHiddenPrefsKey(language)) ?? [];

    final savedOrder = prefs.getStringList(_getPrefsKey(language));
    if (savedOrder == null || savedOrder.isEmpty) {
      return allSources.where((s) => !hiddenNames.contains(s.name)).toList();
    }

    final ordered = <NewsRssSource>[];
    for (final name in savedOrder) {
      if (hiddenNames.contains(name)) continue;
      final source = allSources.where((s) => s.name == name).firstOrNull;
      if (source != null) ordered.add(source);
    }

    for (final source in allSources) {
      if (!hiddenNames.contains(source.name) &&
          !ordered.any((s) => s.name == source.name)) {
        ordered.add(source);
      }
    }
    return ordered;
  }

  Future<void> saveSourcesOrder(
      NewsLanguage language, List<NewsRssSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _getPrefsKey(language), sources.map((s) => s.name).toList());
  }

  Future<void> hideSource(NewsLanguage language, NewsRssSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList(_getHiddenPrefsKey(language)) ?? [];
    if (!hidden.contains(source.name)) {
      hidden.add(source.name);
      await prefs.setStringList(_getHiddenPrefsKey(language), hidden);
    }
  }

  Future<void> restoreHiddenSources(NewsLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getHiddenPrefsKey(language));
    await prefs
        .remove(_getPrefsKey(language)); // Also reset order when restoring
  }

  Future<List<NewsArticle>> fetchTopNews(
    NewsLanguage language, {
    NewsRssSource? source,
  }) async {
    if (source != null) {
      return fetchSourceNews(source);
    }

    final sources = await getOrderedSources(language);
    final articles = <NewsArticle>[];
    for (final src in sources) {
      try {
        articles.addAll(await _fetchRssSource(src, language: language));
      } catch (e) {
        debugPrint('Sonarpad news: errore fetch ${src.name}: $e');
      }
    }
    _sortNewestFirst(articles);
    return articles.take(40).toList();
  }

  Future<List<NewsArticle>> fetchSourceNews(
    NewsRssSource source, {
    NewsLanguage? language,
  }) async {
    final articles = await _fetchRssSource(source, language: language);
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

  Future<Map<String, String>?> getUserLocationData() async {
    try {
      final response = await _client.get(Uri.parse('https://ipwho.is/'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        var city = data['city']?.toString();
        final countryCode = data['country_code']?.toString();
        if (city != null &&
            city.isNotEmpty &&
            countryCode != null &&
            countryCode.isNotEmpty) {
          
          if (countryCode == 'IT') {
            city = switch (city) {
              'Rome' => 'Roma',
              'Milan' => 'Milano',
              'Turin' => 'Torino',
              'Naples' => 'Napoli',
              'Florence' => 'Firenze',
              'Venice' => 'Venezia',
              'Genoa' => 'Genova',
              'Padua' => 'Padova',
              _ => city,
            };
          }

          return {'city': city, 'countryCode': countryCode};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<NewsArticleContent> fetchArticleContent(NewsArticle article,
      {required NewsLanguage language}) async {
    final resolvedUrl = await _resolveArticleUrl(article.link);
    if (_isGoogleNewsArticleUrl(resolvedUrl)) {
      return NewsArticleContent(text: article.summary, url: article.link);
    }
    final langHeader = _acceptLanguageHeader(language);
    final fetch = await _browserGetWithFallback(
      Uri.parse(resolvedUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Accept-Language': langHeader,
      },
    );
    final response = fetch.response;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Articolo non raggiungibile: ${response.statusCode}');
    }
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (_isGoogleConsentPage(html) || _isGoogleFullCoveragePage(html)) {
      return NewsArticleContent(text: article.summary, url: article.link);
    }
    var text = _extractArticleText(html, language: language);
    final resolvedUri = Uri.parse(resolvedUrl);
    final ampUri = _ampArticleUri(resolvedUri);
    if (fetch.profile != _BrowserFetchProfile.iphone &&
        _isWeakArticleText(
          text,
          article.summary,
          includeTruncated: ampUri != null,
        )) {
      final iphoneResponse = await _browserGetWithProfile(
        _BrowserFetchProfile.iphone,
        Uri.parse(resolvedUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          'Accept-Language': langHeader,
        },
      );
      if (iphoneResponse.statusCode >= 200 && iphoneResponse.statusCode < 300) {
        final iphoneHtml = utf8.decode(
          iphoneResponse.bodyBytes,
          allowMalformed: true,
        );
        final iphoneText = _extractArticleText(iphoneHtml, language: language);
        if (iphoneText.trim().length > text.trim().length) {
          text = iphoneText;
        }
      }
    }
    if (ampUri != null &&
        _isWeakArticleText(
          text,
          article.summary,
          includeTruncated: true,
        )) {
      final ampFetch = await _browserGetWithFallback(ampUri);
      final ampResponse = ampFetch.response;
      if (ampResponse.statusCode >= 200 && ampResponse.statusCode < 300) {
        final ampHtml = utf8.decode(
          ampResponse.bodyBytes,
          allowMalformed: true,
        );
        final ampText = _extractArticleText(ampHtml, language: language);
        if (ampText.trim().length > text.trim().length) {
          text = ampText;
        }
      }
    }
    return NewsArticleContent(
      text: text.isEmpty ? article.summary : text,
      url: resolvedUrl,
    );
  }

  Future<List<NewsArticle>> _fetchRssSource(
    NewsRssSource rssSource, {
    NewsLanguage? language,
  }) async {
    final langHeader = language != null
        ? _acceptLanguageHeader(language)
        : 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7';
    final fetch = await _browserGetWithFallback(
      _normalizedRssUri(rssSource.uri),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Accept-Language': langHeader,
      },
    );
    final response = fetch.response;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore RSS ${rssSource.name}: ${response.statusCode}');
    }
    final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
    try {
      final doc = XmlDocument.parse(decodedBody);
      final items = doc.findAllElements('item');
      if (items.isEmpty) {
        return _articlesFromAtomEntries(doc, rssSource);
      }
      var index = 0;
      return items.map((item) {
        index++;
        final title = _text(item, 'title');
        final link = _text(item, 'link');
        final description = _cleanRssDescription(_rssDescription(item));
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
          publishedAt:
              DateTime.tryParse(pubDateRaw) ?? _parseRssDate(pubDateRaw),
        );
      }).toList();
    } catch (_) {
      return _extractArticlesFromHtml(decodedBody, rssSource);
    }
  }

  String _rssDescription(XmlElement item) {
    final description = _text(item, 'description');
    if (description.isNotEmpty) return description;
    for (final element in item.descendantElements) {
      if (element.name.local == 'encoded') {
        return element.innerText.trim();
      }
    }
    return '';
  }

  List<NewsArticle> _articlesFromAtomEntries(
    XmlDocument doc,
    NewsRssSource rssSource,
  ) {
    final entries = doc.findAllElements('entry');
    var index = 0;
    return entries.map((entry) {
      index++;
      final title = _text(entry, 'title');
      final link = _atomLink(entry);
      final summary = _cleanHtml(
        _text(entry, 'summary').isNotEmpty
            ? _text(entry, 'summary')
            : _text(entry, 'content'),
      );
      final publishedRaw = _text(entry, 'published');
      final updatedRaw = _text(entry, 'updated');
      return NewsArticle(
        id: '${rssSource.name}_atom_$index',
        title: title.trim(),
        link: link,
        summary: summary,
        source: rssSource.name,
        publishedAt: DateTime.tryParse(
          publishedRaw.isNotEmpty ? publishedRaw : updatedRaw,
        ),
      );
    }).toList();
  }

  String _atomLink(XmlElement entry) {
    final links = entry.findElements('link').toList();
    if (links.isEmpty) return '';
    final alternate = links.firstWhere(
      (link) {
        final rel = link.getAttribute('rel');
        return rel == null || rel == 'alternate';
      },
      orElse: () => links.first,
    );
    return alternate.getAttribute('href') ?? alternate.innerText.trim();
  }

  List<NewsArticle> _extractArticlesFromHtml(
      String htmlStr, NewsRssSource rssSource) {
    final doc = html_parser.parse(htmlStr);
    final links = doc.querySelectorAll('a');
    final articles = <NewsArticle>[];
    final seenHrefs = <String>{};
    var index = 0;

    for (final link in links) {
      final href = link.attributes['href'];
      if (href == null ||
          href.isEmpty ||
          href.startsWith('#') ||
          href.startsWith('javascript:')) {
        continue;
      }

      final text = link.text.trim();
      if (text.length < 30) {
        continue;
      }

      final fullUrl = _resolveRelativeUrl(href, rssSource.uri.toString());
      if (seenHrefs.contains(fullUrl)) {
        continue;
      }
      seenHrefs.add(fullUrl);

      index++;
      articles.add(NewsArticle(
        id: '${rssSource.name}_html_$index',
        title: text.replaceAll(RegExp(r'\s+'), ' '),
        link: fullUrl,
        summary: '',
        source: rssSource.name,
        publishedAt: DateTime.now(),
      ));
      if (articles.length >= 30) break;
    }
    return articles;
  }

  String _resolveRelativeUrl(String href, String baseUrl) {
    if (href.startsWith('http')) return href;
    try {
      final base = Uri.parse(baseUrl);
      return base.resolve(href).toString();
    } catch (_) {
      return href;
    }
  }

  String _text(XmlElement parent, String name) {
    final elements = parent.findElements(name);
    if (elements.isEmpty) return '';
    return elements.first.innerText.trim();
  }

  Uri _normalizedRssUri(Uri uri) {
    if (_isCorriereHomeFeedUri(uri)) {
      return _corriereHomeFeedUri;
    }
    return uri;
  }

  bool _isCorriereHomeFeedUri(Uri uri) {
    final host = uri.host.toLowerCase();
    var path = uri.path.toLowerCase();
    while (path.endsWith('/') && path.isNotEmpty) {
      path = path.substring(0, path.length - 1);
    }
    switch (host) {
      case 'corriere.it':
      case 'www.corriere.it':
        return path.isEmpty || path == '/rss' || path == '/rss/homepage.xml';
      case 'xml2.corriereobjects.it':
        return path == '/feed-hp/homepage.xml' ||
            path == '/feed-hp/homepage-restyle-2025.xml';
      default:
        return false;
    }
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
    final htmlResponse = await _browserGet(
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
    final response = await _browserPost(
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

  String _extractArticleText(String html, {required NewsLanguage language}) {
    final article = HtmlReaderService.readerModeExtract(html, language.code);
    if (article != null && article.content.isNotEmpty) {
      return article.content;
    }

    // Fallback using simple parsing
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

  /// Costruisce l'header Accept-Language corretto per la lingua selezionata.
  static String _acceptLanguageHeader(NewsLanguage language) {
    return switch (language) {
      NewsLanguage.italian => 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
      NewsLanguage.english => 'en-US,en;q=0.9',
      NewsLanguage.french => 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
      NewsLanguage.spanish => 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
      NewsLanguage.portuguese => 'pt-PT,pt;q=0.9,en-US;q=0.8,en;q=0.7',
      NewsLanguage.polish => 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
      NewsLanguage.czech => 'cs-CZ,cs;q=0.9,en-US;q=0.8,en;q=0.7',
    };
  }

  bool _isWeakArticleText(
    String text,
    String fallbackDescription, {
    bool includeTruncated = false,
  }) {
    final trimmed = text.trim();
    return trimmed.isEmpty ||
        trimmed.length < 80 ||
        (includeTruncated &&
            trimmed.length < 1200 &&
            _looksLikeTruncatedArticleText(trimmed)) ||
        trimmed == fallbackDescription.trim();
  }

  bool _looksLikeTruncatedArticleText(String text) {
    final trimmed = text.trimRight();
    if (trimmed.endsWith('...') || trimmed.endsWith('…')) {
      return true;
    }
    if (trimmed.isEmpty) {
      return false;
    }
    const sentenceEnd = '.!?»”")\']';
    return !sentenceEnd.contains(trimmed[trimmed.length - 1]);
  }

  static Future<http.Client> _browserClient(_BrowserFetchProfile profile) {
    return switch (profile) {
      _BrowserFetchProfile.chrome => _chromeClientFuture ??=
          rhttp.RhttpCompatibleClient.create(settings: _chromeClientSettings),
      _BrowserFetchProfile.iphone => _iphoneClientFuture ??=
          rhttp.RhttpCompatibleClient.create(settings: _iphoneClientSettings),
    };
  }

  Future<http.Response> _browserGet(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    return (await _browserGetWithFallback(uri, headers: headers)).response;
  }

  Future<({http.Response response, _BrowserFetchProfile profile})>
      _browserGetWithFallback(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    if (!_useBrowserClient) {
      return (
        response: await _client.get(uri, headers: headers),
        profile: _BrowserFetchProfile.chrome,
      );
    }

    if (_shouldUseIphoneDirect(uri)) {
      return (
        response: await _browserGetWithProfile(
          _BrowserFetchProfile.iphone,
          uri,
          headers: headers,
        ),
        profile: _BrowserFetchProfile.iphone,
      );
    }

    http.Response? chromeResponse;
    try {
      chromeResponse = await _browserGetWithProfile(
        _BrowserFetchProfile.chrome,
        uri,
        headers: headers,
      );
      if (!_shouldFallbackBrowserResponse(chromeResponse)) {
        return (
          response: chromeResponse,
          profile: _BrowserFetchProfile.chrome,
        );
      }
    } catch (_) {}

    http.Response? iphoneResponse;
    try {
      iphoneResponse = await _browserGetWithProfile(
        _BrowserFetchProfile.iphone,
        uri,
        headers: headers,
      );
      if (!_shouldFallbackBrowserResponse(iphoneResponse)) {
        return (
          response: iphoneResponse,
          profile: _BrowserFetchProfile.iphone,
        );
      }
    } catch (_) {}

    if (chromeResponse != null &&
        !_shouldFallbackBrowserResponse(chromeResponse)) {
      return (
        response: chromeResponse,
        profile: _BrowserFetchProfile.chrome,
      );
    }

    return (
      response: await _client.get(uri),
      profile: _BrowserFetchProfile.chrome,
    );
  }

  Future<http.Response> _browserGetWithProfile(
    _BrowserFetchProfile profile,
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final client = await _browserClient(profile);
    return client.get(
      uri,
      headers: _headersForProfile(profile, headers, navigation: true),
    );
  }

  Future<http.Response> _browserPost(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    if (!_useBrowserClient) {
      return _client.post(uri, headers: headers, body: body);
    }
    http.Response? chromeResponse;
    try {
      chromeResponse = await _browserPostWithProfile(
        _BrowserFetchProfile.chrome,
        uri,
        headers: headers,
        body: body,
      );
      if (chromeResponse.statusCode >= 200 && chromeResponse.statusCode < 300) {
        return chromeResponse;
      }
    } catch (_) {}

    http.Response? iphoneResponse;
    try {
      iphoneResponse = await _browserPostWithProfile(
        _BrowserFetchProfile.iphone,
        uri,
        headers: headers,
        body: body,
      );
      if (iphoneResponse.statusCode >= 200 && iphoneResponse.statusCode < 300) {
        return iphoneResponse;
      }
    } catch (_) {}

    if (chromeResponse != null &&
        chromeResponse.statusCode >= 200 &&
        chromeResponse.statusCode < 300) {
      return chromeResponse;
    }

    return _client.post(uri, body: body);
  }

  Future<http.Response> _browserPostWithProfile(
    _BrowserFetchProfile profile,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = await _browserClient(profile);
    return client.post(
      uri,
      headers: _headersForProfile(profile, headers),
      body: body,
    );
  }

  bool _shouldUseIphoneDirect(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('wsj.com') ||
        host.contains('dowjones.com') ||
        host.contains('barrons.com') ||
        host.contains('podbean.com');
  }

  Uri? _ampArticleUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!host.endsWith('lastampa.it') || uri.path.endsWith('/amp/')) {
      return null;
    }
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return uri.replace(path: '$path/amp/');
  }

  bool _shouldFallbackBrowserResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 400) return true;
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (_looksLikeFeed(html)) return false;
    final lower = html.toLowerCase();
    return lower.contains('just a moment') ||
        lower.contains('dd-captcha') ||
        lower.contains('checking your browser') ||
        lower.contains('enable javascript and cookies') ||
        lower.contains('cf-chl') ||
        response.bodyBytes.length < 3000;
  }

  bool _looksLikeFeed(String value) {
    var trimmed = value.trimLeft();
    if (trimmed.startsWith('\uFEFF')) {
      trimmed = trimmed.substring(1).trimLeft();
    }
    final lower = trimmed.toLowerCase();
    return lower.startsWith('<?xml') ||
        lower.startsWith('<rss') ||
        lower.startsWith('<feed');
  }

  Map<String, String> _headersForProfile(
    _BrowserFetchProfile profile,
    Map<String, String>? headers, {
    bool navigation = false,
  }) {
    final result = <String, String>{...?headers};
    switch (profile) {
      case _BrowserFetchProfile.chrome:
        result['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';
        result.putIfAbsent(
          'Accept-Language',
          () => 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
        );
        if (navigation) {
          result['Accept'] =
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7';
          result['Cache-Control'] = 'max-age=0';
          result['Sec-Ch-Ua'] =
              '"Google Chrome";v="136", "Chromium";v="136", "Not_A Brand";v="24"';
          result['Sec-Ch-Ua-Mobile'] = '?0';
          result['Sec-Ch-Ua-Platform'] = '"Windows"';
          result['Upgrade-Insecure-Requests'] = '1';
          result['Sec-Fetch-Dest'] = 'document';
          result['Sec-Fetch-Mode'] = 'navigate';
          result['Sec-Fetch-Site'] = 'none';
          result['Sec-Fetch-User'] = '?1';
          result['Referer'] = 'https://www.google.com/';
        }
      case _BrowserFetchProfile.iphone:
        result['User-Agent'] =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1';
        result.putIfAbsent(
          'Accept-Language',
          () => 'it-IT,it;q=0.9,en-US;q=0.8',
        );
        if (navigation) {
          result['Accept'] =
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
          result['Upgrade-Insecure-Requests'] = '1';
          result['Connection'] = 'keep-alive';
        }
    }
    return result;
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
