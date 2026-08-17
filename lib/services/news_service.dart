import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:rhttp_plus/rhttp_plus.dart' as rhttp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../utils/app_logger.dart';
import 'news_sources/english_news_sources.dart';
import 'news_sources/italian_news_sources.dart';
import 'news_sources/news_rss_source.dart';

import 'html_reader_service.dart';
import 'news_sources/french_news_sources.dart';
import 'news_sources/spanish_news_sources.dart';
import 'news_sources/portuguese_news_sources.dart';
import 'news_sources/polish_news_sources.dart';
import 'news_sources/czech_news_sources.dart';

enum NewsLanguage {
  italian,
  english,
  french,
  spanish,
  portuguese,
  polish,
  czech
}

class _TinyfishArticleFetchResult {
  const _TinyfishArticleFetchResult({
    this.content,
    this.disabled = false,
  });

  final NewsArticleContent? content;
  final bool disabled;
}

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

  String get communityKey => switch (this) {
        NewsLanguage.italian => 'italian',
        NewsLanguage.english => 'english',
        NewsLanguage.french => 'french',
        NewsLanguage.spanish => 'spanish',
        NewsLanguage.portuguese => 'portuguese',
        NewsLanguage.polish => 'polish',
        NewsLanguage.czech => 'czech',
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

  static const _communityNewsSourcesUrl =
      'https://sonarpad.com/api/get_community_news_sources.php';
  static const _addCommunityNewsSourceUrl =
      'https://sonarpad.com/api/add_community_news_source.php';
  static const _tinyfishArticleFetchUrl =
      'https://sonarpad.com/api/tinyfish_fetch_article.php';
  static const _tinyfishPolicyTimeout = Duration(seconds: 4);
  static const _tinyfishArticleTimeout = Duration(seconds: 20);
  static const _tinyfishFallbackOnlyDefault = true;
  static const _communityHeaders = {
    'User-Agent': 'SonarpadMobile/0.1 (https://sonarpad.com)',
    'Accept': 'application/json',
  };

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
  static bool? _sessionTinyfishFallbackOnlyPolicy;
  static Future<bool>? _sessionTinyfishPolicyFuture;

  final http.Client _client;
  final bool _useBrowserClient;
  NewsService({http.Client? client})
      : _client = client ?? http.Client(),
        _useBrowserClient = client == null;

  /// Restituisce true quando l'estrazione non contiene altro che il titolo.
  ///
  /// Alcuni reader restituiscono il titolo della pagina come se fosse il
  /// corpo dell'articolo. Il confronto ignora spazi e punteggiatura e gestisce
  /// anche il titolo ripetuto, senza scartare un vero testo aggiuntivo.
  static bool isArticleTextOnlyTitle(String text, String title) {
    final textWords = _normalizedArticleWords(text);
    final titleWords = _normalizedArticleWords(title);
    if (textWords.isEmpty || titleWords.isEmpty) return false;
    if (textWords.length % titleWords.length != 0) return false;

    for (var i = 0; i < textWords.length; i++) {
      if (textWords[i] != titleWords[i % titleWords.length]) return false;
    }
    return true;
  }

  static List<String> _normalizedArticleWords(String value) {
    return value
        .toLowerCase()
        .replaceAll(
          RegExp(r'''[\s.,;:!?\u2026'"\u201c\u201d\u2018\u2019\u00ab\u00bb()\[\]{}<>|/\\\u2014\u2013_-]+'''),
          ' ',
        )
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
  }

  String _getPrefsKey(NewsLanguage language) =>
      'news_sources_order_${language.name}';
  String _getHiddenPrefsKey(NewsLanguage language) =>
      'news_sources_hidden_${language.name}';
  String _getCustomPrefsKey(NewsLanguage language) =>
      'news_custom_sources_${language.name}';
  String _getFoldersPrefsKey(NewsLanguage language) =>
      'news_source_folders_${language.name}';
  String _getSourceFoldersPrefsKey(NewsLanguage language) =>
      'news_source_folder_assignments_${language.name}';
  String _getFolderOrderPrefsKey(NewsLanguage language, String? folderId) =>
      folderId == null
          ? _getPrefsKey(language)
          : 'news_sources_order_${language.name}_folder_$folderId';
  String _getReadArticlesKey(NewsLanguage language, String sourceName) =>
      'news_read_articles_${language.name}_$sourceName';

  String _encodeReadArticle(NewsArticle article) => jsonEncode({
        'id': article.id,
        'title': article.title,
        'link': article.link,
        'summary': article.summary,
        'source': article.source,
        'publishedAt': article.publishedAt?.toIso8601String(),
      });

  Future<List<NewsArticle>> getReadArticles(
      NewsLanguage language, String sourceName) async {
    final prefs = await SharedPreferences.getInstance();
    final listStr =
        prefs.getStringList(_getReadArticlesKey(language, sourceName)) ?? [];
    return listStr
        .map((s) {
          try {
            final map = jsonDecode(s);
            return NewsArticle(
              id: map['id'],
              title: map['title'],
              link: map['link'],
              summary: map['summary'],
              source: map['source'],
              publishedAt: map['publishedAt'] != null
                  ? DateTime.parse(map['publishedAt'])
                  : null,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<NewsArticle>()
        .toList();
  }

  Future<void> addReadArticle(
      NewsLanguage language, String sourceName, NewsArticle article) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getReadArticlesKey(language, sourceName);
    var current = await getReadArticles(language, sourceName);
    current.removeWhere((a) => a.id == article.id);
    current.insert(0, article);
    if (current.length > 50) {
      current =
          current.take(50).toList(); // Maximum 50 read articles per source
    }
    final listStr = current.map(_encodeReadArticle).toList();
    await prefs.setStringList(key, listStr);
  }

  Future<void> removeReadArticle(
      NewsLanguage language, String sourceName, String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getReadArticlesKey(language, sourceName);
    final current = await getReadArticles(language, sourceName);
    current.removeWhere((a) => a.id == articleId);
    await prefs.setStringList(key, current.map(_encodeReadArticle).toList());
  }

  Future<void> clearReadArticles(
      NewsLanguage language, String sourceName) async {
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

  Future<List<NewsSourceFolder>> getFolders(NewsLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getStringList(_getFoldersPrefsKey(language)) ?? [];
    return listStr
        .map((s) {
          try {
            final folder = NewsSourceFolder.fromJson(jsonDecode(s));
            if (folder.id.trim().isEmpty || folder.name.trim().isEmpty) {
              return null;
            }
            return folder;
          } catch (_) {
            return null;
          }
        })
        .whereType<NewsSourceFolder>()
        .toList();
  }

  Future<void> _saveFolders(
    NewsLanguage language,
    List<NewsSourceFolder> folders,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _getFoldersPrefsKey(language),
      folders.map((folder) => jsonEncode(folder.toJson())).toList(),
    );
  }

  Future<Map<String, String>> _getSourceFolderAssignments(
      NewsLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonText = prefs.getString(_getSourceFoldersPrefsKey(language));
    if (jsonText == null || jsonText.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return {};
      return decoded
          .map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveSourceFolderAssignments(
    NewsLanguage language,
    Map<String, String> assignments,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _getSourceFoldersPrefsKey(language),
      jsonEncode(assignments),
    );
  }

  Future<NewsSourceFolder> createFolder(
    NewsLanguage language,
    String name,
  ) async {
    final folders = await getFolders(language);
    final knownNames = folders.map((folder) => folder.name).toSet();
    final folder = NewsSourceFolder(
      id: 'folder_${DateTime.now().microsecondsSinceEpoch}',
      name: _uniqueSourceName(name, knownNames),
    );
    folders.add(folder);
    await _saveFolders(language, folders);
    return folder;
  }

  Future<void> removeFolder(NewsLanguage language, String folderId) async {
    final folders = await getFolders(language);
    folders.removeWhere((folder) => folder.id == folderId);
    await _saveFolders(language, folders);

    final customSources = await getCustomSources(language);
    final updatedCustomSources = customSources
        .map((source) => source.parentFolderId == folderId
            ? source.copyWith(clearParentFolderId: true)
            : source)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _getCustomPrefsKey(language),
      updatedCustomSources
          .map((source) => jsonEncode(source.toJson()))
          .toList(),
    );

    final assignments = await _getSourceFolderAssignments(language);
    assignments.removeWhere((_, value) => value == folderId);
    await _saveSourceFolderAssignments(language, assignments);
    await prefs.remove(_getFolderOrderPrefsKey(language, folderId));
  }

  Future<void> moveSourceToFolder(
    NewsLanguage language,
    NewsRssSource source,
    String? folderId,
  ) async {
    if (source.isFolder) return;
    final prefs = await SharedPreferences.getInstance();

    if (source.isCustom) {
      final customSources = await getCustomSources(language);
      final updated = customSources.map((customSource) {
        if (customSource.name != source.name ||
            customSource.uri != source.uri) {
          return customSource;
        }
        return folderId == null
            ? customSource.copyWith(clearParentFolderId: true)
            : customSource.copyWith(parentFolderId: folderId);
      }).toList();
      await prefs.setStringList(
        _getCustomPrefsKey(language),
        updated.map((item) => jsonEncode(item.toJson())).toList(),
      );
    }

    final assignments = await _getSourceFolderAssignments(language);
    if (folderId == null) {
      assignments.remove(source.name);
    } else {
      assignments[source.name] = folderId;
    }
    await _saveSourceFolderAssignments(language, assignments);

    for (final key in prefs.getKeys().where(
        (key) => key.startsWith('news_sources_order_${language.name}'))) {
      final order = prefs.getStringList(key) ?? [];
      if (order.remove(_itemOrderKey(source)) || order.remove(source.name)) {
        await prefs.setStringList(key, order);
      }
    }
  }

  Future<String> addCommunityNewsSource({
    required NewsLanguage language,
    required String name,
    required String feedUrl,
    String? uiLanguageCode,
  }) async {
    final response = await _client.post(
      Uri.parse(_addCommunityNewsSourceUrl),
      headers: _communityHeaders,
      body: {
        'name': name,
        'url': feedUrl,
        'language': language.communityKey,
        'ui_language': uiLanguageCode ?? language.code,
      },
    ).timeout(const Duration(seconds: 15));

    final decoded = _decodeJsonMap(response.body);
    final message = (decoded['message'] ?? '').toString().trim();
    final error = (decoded['error'] ?? '').toString().trim();
    final ok = decoded['ok'] == true;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(error.isEmpty ? 'HTTP ${response.statusCode}' : error);
    }
    if (!ok) {
      throw Exception(error.isEmpty ? 'Richiesta rifiutata' : error);
    }
    return message;
  }

  Future<List<NewsRssSource>> fetchCommunityNewsSources(
    NewsLanguage language,
  ) async {
    final uri = Uri.parse(_communityNewsSourcesUrl).replace(
      queryParameters: {'language': language.communityKey},
    );
    final response = await _client
        .get(uri, headers: _communityHeaders)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Community HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final items = decoded is List
        ? decoded
        : decoded is Map
            ? decoded['items']
            : null;
    if (items is! List) return const [];

    final currentCustomSources = await getCustomSources(language);
    final knownUrls = <String>{
      ...language.rssSources
          .map((source) => source.uri.toString().trim().toLowerCase()),
      ...currentCustomSources
          .map((source) => source.uri.toString().trim().toLowerCase()),
    };
    final knownNames = <String>{
      ...language.rssSources.map((source) => source.name),
      ...currentCustomSources.map((source) => source.name),
    };

    final sources = <NewsRssSource>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final name = (raw['name'] ?? '').toString().trim();
      final url = (raw['url'] ?? '').toString().trim();
      final rawLanguage =
          (raw['language'] ?? '').toString().trim().toLowerCase();
      if (name.isEmpty || url.isEmpty) continue;
      if (rawLanguage.isNotEmpty && rawLanguage != language.communityKey) {
        continue;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) continue;
      if (knownUrls.contains(uri.toString().trim().toLowerCase())) continue;
      sources.add(NewsRssSource(
        name: _uniqueSourceName(name, knownNames),
        uri: uri,
        isCustom: true,
      ));
    }
    return sources;
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return const {};
  }

  Future<void> addCustomSource(
    NewsLanguage language,
    String name,
    String urlOrSearch, {
    String? parentFolderId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final customSources = await getCustomSources(language);

    final originalInput = urlOrSearch.trim();
    String finalUrl = originalInput;
    final lowerInput = originalInput.toLowerCase();
    final isExplicitUrl =
        lowerInput.startsWith('http://') || lowerInput.startsWith('https://');
    final looksLikeDomain =
        originalInput.contains('.') && !originalInput.contains(' ');

    if (!isExplicitUrl) {
      if (looksLikeDomain) {
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

    final uri = Uri.parse(finalUrl);
    var finalName = name.trim();
    if (finalName.isEmpty) {
      if (isExplicitUrl || looksLikeDomain) {
        finalName = await _fetchRssFeedTitle(uri, language: language) ?? '';
      }
      if (finalName.isEmpty) {
        finalName = (isExplicitUrl || looksLikeDomain) && uri.host.isNotEmpty
            ? uri.host
            : originalInput.isNotEmpty
                ? originalInput
                : 'RSS';
      }
      final knownNames = <String>{
        ...language.rssSources.map((source) => source.name),
        ...customSources.map((source) => source.name),
      };
      finalName = _uniqueSourceName(finalName, knownNames);
    }

    final newSource = NewsRssSource(
      name: finalName,
      uri: uri,
      isCustom: true,
      parentFolderId: parentFolderId,
    );

    customSources.add(newSource);
    final stringList =
        customSources.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_getCustomPrefsKey(language), stringList);
  }

  Future<String?> _fetchRssFeedTitle(
    Uri uri, {
    required NewsLanguage language,
  }) async {
    try {
      final fetch = await _browserGetWithFallback(
        _normalizedRssUri(uri),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          'Accept-Language': _acceptLanguageHeader(language),
        },
      );
      final response = fetch.response;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      try {
        final doc = XmlDocument.parse(body);
        final channel = doc.findAllElements('channel').firstOrNull;
        final channelTitle = channel == null ? null : _text(channel, 'title');
        if (channelTitle != null && channelTitle.trim().isNotEmpty) {
          return _cleanFeedTitle(channelTitle);
        }
        final feed = doc.findAllElements('feed').firstOrNull;
        final feedTitle = feed == null ? null : _text(feed, 'title');
        if (feedTitle != null && feedTitle.trim().isNotEmpty) {
          return _cleanFeedTitle(feedTitle);
        }
        final title =
            doc.findAllElements('title').firstOrNull?.innerText.trim();
        if (title != null && title.isNotEmpty) {
          return _cleanFeedTitle(title);
        }
      } catch (_) {
        final title =
            html_parser.parse(body).querySelector('title')?.text.trim();
        if (title != null && title.isNotEmpty) {
          return _cleanFeedTitle(title);
        }
      }
    } catch (_) {}
    return null;
  }

  String _cleanFeedTitle(String value) =>
      _cleanHtml(value).replaceAll(RegExp(r'\s+'), ' ').trim();

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
    final assignments = await _getSourceFolderAssignments(language);
    if (assignments.remove(name) != null) {
      await _saveSourceFolderAssignments(language, assignments);
    }
    for (final key in prefs.getKeys().where(
        (key) => key.startsWith('news_sources_order_${language.name}'))) {
      final order = prefs.getStringList(key) ?? [];
      if (order.remove('source:$name') || order.remove(name)) {
        await prefs.setStringList(key, order);
      }
    }
  }

  Future<int> importCustomSourcesFromOpml(
    NewsLanguage language,
    File file, {
    String? parentFolderId,
  }) async {
    final text = await file.readAsString();
    final document = XmlDocument.parse(text);
    final currentCustomSources = await getCustomSources(language);
    final folders = await getFolders(language);
    final folderByName = {
      for (final folder in folders) folder.name.trim().toLowerCase(): folder,
    };
    final knownUrls = <String>{
      ...language.rssSources
          .map((source) => source.uri.toString().trim().toLowerCase()),
      ...currentCustomSources
          .map((source) => source.uri.toString().trim().toLowerCase()),
    };
    final knownNames = <String>{
      ...language.rssSources.map((source) => source.name),
      ...currentCustomSources.map((source) => source.name),
    };
    final knownFolderNames = folders.map((folder) => folder.name).toSet();
    final toAdd = <NewsRssSource>[];

    NewsSourceFolder ensureFolder(String name) {
      final cleanName = name.trim().isEmpty ? 'RSS' : name.trim();
      final key = cleanName.toLowerCase();
      final existing = folderByName[key];
      if (existing != null) return existing;
      final folder = NewsSourceFolder(
        id: 'folder_${DateTime.now().microsecondsSinceEpoch}_${folderByName.length}',
        name: _uniqueSourceName(cleanName, knownFolderNames),
      );
      folderByName[folder.name.trim().toLowerCase()] = folder;
      folders.add(folder);
      return folder;
    }

    void importOutline(
        XmlElement outline, String? currentFolderId, List<String> folderPath) {
      final feedUrl =
          (_opmlAttribute(outline, 'xmlUrl') ?? _opmlAttribute(outline, 'url'))
              ?.trim();
      if (feedUrl != null && feedUrl.isNotEmpty) {
        final uri = Uri.tryParse(feedUrl);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) return;
        final normalizedUrl = uri.toString().trim().toLowerCase();
        if (!knownUrls.add(normalizedUrl)) return;

        final titleAttr = _opmlAttribute(outline, 'title')?.trim();
        final textAttr = _opmlAttribute(outline, 'text')?.trim();
        final fallbackName = uri.host.isEmpty ? feedUrl : uri.host;
        final baseName = titleAttr?.isNotEmpty == true
            ? titleAttr!
            : textAttr?.isNotEmpty == true
                ? textAttr!
                : fallbackName;

        toAdd.add(NewsRssSource(
          name: _uniqueSourceName(baseName, knownNames),
          uri: uri,
          isCustom: true,
          parentFolderId: currentFolderId ?? parentFolderId,
        ));
        return;
      }

      final childOutlines = outline.findElements('outline').toList();
      if (childOutlines.isEmpty) return;
      final hasFeedChildren = childOutlines.any((child) =>
          (_opmlAttribute(child, 'xmlUrl') ?? _opmlAttribute(child, 'url'))
                  ?.trim()
                  .isNotEmpty ==
              true ||
          child.findAllElements('outline').isNotEmpty);
      if (!hasFeedChildren) return;

      final titleAttr = _opmlAttribute(outline, 'title')?.trim();
      final textAttr = _opmlAttribute(outline, 'text')?.trim();
      final groupName = titleAttr?.isNotEmpty == true
          ? titleAttr!
          : textAttr?.isNotEmpty == true
              ? textAttr!
              : 'RSS';
      final nextPath = [...folderPath, groupName];
      final folder = ensureFolder(nextPath.join(' / '));
      for (final child in childOutlines) {
        importOutline(child, folder.id, nextPath);
      }
    }

    final body = document.findAllElements('body').firstOrNull;
    final topOutlines = body != null
        ? body.findElements('outline').toList()
        : document.findAllElements('outline').toList();
    for (final outline in topOutlines) {
      importOutline(outline, parentFolderId, const []);
    }

    if (toAdd.isEmpty) return 0;

    final updated = [...currentCustomSources, ...toAdd];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _getCustomPrefsKey(language),
      updated.map((source) => jsonEncode(source.toJson())).toList(),
    );
    await _saveFolders(language, folders);
    return toAdd.length;
  }

  Future<String> exportCustomSourcesToOpml(NewsLanguage language) async {
    final customSources = await getCustomSources(language);
    final folders = await getFolders(language);
    final folderById = {for (final folder in folders) folder.id: folder};
    final sourcesByFolder = <String?, List<NewsRssSource>>{};
    for (final source in customSources) {
      sourcesByFolder.putIfAbsent(source.parentFolderId, () => []).add(source);
    }
    final hasFolders = customSources.any((source) =>
        source.parentFolderId != null &&
        folderById.containsKey(source.parentFolderId));

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<opml version="1.0">')
      ..writeln('<head>')
      ..writeln('<title>Sonarpad RSS</title>')
      ..writeln('</head>')
      ..writeln('<body>');

    void writeSource(NewsRssSource source, String indent) {
      final title = _escapeOpmlAttribute(source.name);
      final url = _escapeOpmlAttribute(source.uri.toString());
      buffer.writeln(
        '$indent<outline text="$title" title="$title" type="rss" xmlUrl="$url" />',
      );
    }

    if (!hasFolders) {
      for (final source in customSources) {
        writeSource(source, '  ');
      }
    } else {
      for (final source in sourcesByFolder[null] ?? const <NewsRssSource>[]) {
        writeSource(source, '  ');
      }
      for (final folder in folders) {
        final folderSources =
            sourcesByFolder[folder.id] ?? const <NewsRssSource>[];
        if (folderSources.isEmpty) continue;
        final name = _escapeOpmlAttribute(folder.name);
        buffer.writeln('  <outline text="$name" title="$name">');
        for (final source in folderSources) {
          writeSource(source, '    ');
        }
        buffer.writeln('  </outline>');
      }
      final unknownFolderSources = customSources.where((source) =>
          source.parentFolderId != null &&
          !folderById.containsKey(source.parentFolderId));
      for (final source in unknownFolderSources) {
        writeSource(source, '  ');
      }
    }

    buffer
      ..writeln('</body>')
      ..writeln('</opml>');
    return buffer.toString();
  }

  String? _opmlAttribute(XmlElement element, String name) {
    for (final attribute in element.attributes) {
      if (attribute.name.local.toLowerCase() == name.toLowerCase()) {
        return attribute.value;
      }
    }
    return null;
  }

  String _uniqueSourceName(String baseName, Set<String> knownNames) {
    final cleanBaseName = baseName.trim().isEmpty ? 'RSS' : baseName.trim();
    var candidate = cleanBaseName;
    var suffix = 2;
    while (knownNames.contains(candidate)) {
      candidate = '$cleanBaseName ($suffix)';
      suffix++;
    }
    knownNames.add(candidate);
    return candidate;
  }

  String _escapeOpmlAttribute(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll("'", '&apos;');
  }

  Future<List<NewsRssSource>> getOrderedSources(
    NewsLanguage language, {
    String? folderId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final folders =
        folderId == null ? await getFolders(language) : <NewsSourceFolder>[];
    final defaultSources = language.rssSources;
    final customSources = await getCustomSources(language);
    final assignments = await _getSourceFolderAssignments(language);

    final allSources = [
      ...folders.map(NewsRssSource.folder),
      ...defaultSources.map((source) => source.copyWith(
            parentFolderId: assignments[source.name],
          )),
      ...customSources.map((source) => source.copyWith(
            parentFolderId: assignments[source.name] ?? source.parentFolderId,
          )),
    ];
    final hiddenNames = prefs.getStringList(_getHiddenPrefsKey(language)) ?? [];

    final visibleSources = allSources.where((source) {
      if (!source.isFolder && hiddenNames.contains(source.name)) return false;
      if (source.isFolder) return folderId == null;
      return source.parentFolderId == folderId;
    }).toList();

    final savedOrder =
        prefs.getStringList(_getFolderOrderPrefsKey(language, folderId));
    if (savedOrder == null || savedOrder.isEmpty) {
      return visibleSources;
    }

    final ordered = <NewsRssSource>[];
    for (final key in savedOrder) {
      final source = visibleSources
          .where((source) => _itemOrderKey(source) == key || source.name == key)
          .firstOrNull;
      if (source != null &&
          !ordered.any((s) => _itemOrderKey(s) == _itemOrderKey(source))) {
        ordered.add(source);
      }
    }

    for (final source in visibleSources) {
      if (!ordered.any((s) => _itemOrderKey(s) == _itemOrderKey(source))) {
        ordered.add(source);
      }
    }
    return ordered;
  }

  Future<void> saveSourcesOrder(
    NewsLanguage language,
    List<NewsRssSource> sources, {
    String? folderId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _getFolderOrderPrefsKey(language, folderId),
      sources.map(_itemOrderKey).toList(),
    );
  }

  String _itemOrderKey(NewsRssSource source) =>
      source.isFolder ? 'folder:${source.folderId}' : 'source:${source.name}';

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
    for (final src in sources.where((source) => !source.isFolder)) {
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
    return articles;
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
    final fallbackOnly = _tinyfishFallbackOnlyPolicyForCurrentSession();
    final policySource = _sessionTinyfishFallbackOnlyPolicy == null
        ? 'default_pending'
        : 'session_cache';

    unawaited(AppLogger.log(
      'News articolo: recupero contenuto avviato '
      'language=${language.code} fallbackOnly=$fallbackOnly '
      'policySource=$policySource '
      'originalUrl=${article.link} resolvedUrl=$resolvedUrl',
    ));

    if (fallbackOnly) {
      unawaited(AppLogger.log(
        'News articolo: ordine recupero = reader locale -> WebView -> Tinyfish',
      ));
      return _fetchArticleContentLocalBeforeWebView(
        article,
        language: language,
        resolvedUrl: resolvedUrl,
      );
    }

    unawaited(AppLogger.log(
      'News articolo: ordine recupero = Tinyfish -> reader locale -> WebView',
    ));
    return _fetchArticleContentTinyfishFirst(
      article,
      language: language,
      resolvedUrl: resolvedUrl,
    );
  }

  void prefetchTinyfishFallbackOnlyPolicy() {
    final cached = _sessionTinyfishFallbackOnlyPolicy;
    if (cached != null) {
      unawaited(AppLogger.log(
        'News Tinyfish: policy già in memoria per questa sessione '
        'fallbackOnly=$cached',
      ));
      return;
    }

    if (_sessionTinyfishPolicyFuture != null) {
      unawaited(AppLogger.log(
        'News Tinyfish: richiesta policy già in corso, riuso la stessa '
        'richiesta',
      ));
      return;
    }

    unawaited(AppLogger.log(
      'News Tinyfish: richiesta policy avviata in background per questa '
      'sessione',
    ));
    unawaited(loadTinyfishFallbackOnlyPolicyForSession());
  }

  Future<bool> loadTinyfishFallbackOnlyPolicyForSession() {
    final cached = _sessionTinyfishFallbackOnlyPolicy;
    if (cached != null) return Future.value(cached);

    final existing = _sessionTinyfishPolicyFuture;
    if (existing != null) return existing;

    final future = _loadTinyfishFallbackOnlyPolicyFromServer();
    _sessionTinyfishPolicyFuture = future;
    return future.whenComplete(() {
      if (identical(_sessionTinyfishPolicyFuture, future)) {
        _sessionTinyfishPolicyFuture = null;
      }
    });
  }

  bool _tinyfishFallbackOnlyPolicyForCurrentSession() {
    final cached = _sessionTinyfishFallbackOnlyPolicy;
    if (cached != null) return cached;

    prefetchTinyfishFallbackOnlyPolicy();
    return _tinyfishFallbackOnlyDefault;
  }

  Future<bool> _loadTinyfishFallbackOnlyPolicyFromServer() async {
    try {
      final uri = Uri.parse(_tinyfishArticleFetchUrl).replace(
        queryParameters: {'policy': '1'},
      );
      final response = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(_tinyfishPolicyTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
        if (decoded is Map) {
          final fallbackOnly = decoded['tinyfish_fallback_only'] == true ||
              decoded['fallback_only'] == true ||
              decoded['mode']?.toString().toLowerCase() == 'fallback_only';
          _sessionTinyfishFallbackOnlyPolicy = fallbackOnly;
          unawaited(AppLogger.log(
            'News Tinyfish: policy ricevuta dal server e mantenuta in '
            'memoria per questa sessione fallbackOnly=$fallbackOnly',
          ));
          return fallbackOnly;
        }

        unawaited(AppLogger.log(
          'News Tinyfish: risposta policy non valida, uso default sicuro '
          'fallbackOnly=$_tinyfishFallbackOnlyDefault',
        ));
      } else {
        unawaited(AppLogger.log(
          'News Tinyfish: risposta policy HTTP ${response.statusCode}, uso '
          'default sicuro fallbackOnly=$_tinyfishFallbackOnlyDefault',
        ));
      }
    } catch (e) {
      unawaited(AppLogger.log(
        'News Tinyfish: policy non disponibile, uso default sicuro '
        'fallbackOnly=$_tinyfishFallbackOnlyDefault error=$e',
      ));
    }

    _sessionTinyfishFallbackOnlyPolicy = _tinyfishFallbackOnlyDefault;
    unawaited(AppLogger.log(
      'News Tinyfish: default sicuro mantenuto in memoria per questa '
      'sessione fallbackOnly=$_tinyfishFallbackOnlyDefault',
    ));
    return _tinyfishFallbackOnlyDefault;
  }

  @visibleForTesting
  static void resetTinyfishFallbackOnlyPolicyForTests() {
    _sessionTinyfishFallbackOnlyPolicy = null;
    _sessionTinyfishPolicyFuture = null;
  }

  Future<NewsArticleContent> _fetchArticleContentTinyfishFirst(
    NewsArticle article, {
    required NewsLanguage language,
    required String resolvedUrl,
  }) async {
    if (_isGoogleNewsArticleUrl(resolvedUrl)) {
      unawaited(AppLogger.log(
        'News Tinyfish: URL Google News non risolto, provo Tinyfish '
        'url=$resolvedUrl',
      ));
      final tinyfishGoogleNewsResult =
          await _tryFetchTinyfishArticleContent(resolvedUrl);
      final tinyfishGoogleNewsContent = tinyfishGoogleNewsResult.content;
      if (tinyfishGoogleNewsContent != null &&
          tinyfishGoogleNewsContent.text.trim().length >= 100) {
        unawaited(AppLogger.log(
          'News Tinyfish: testo Google News accettato '
          'length=${tinyfishGoogleNewsContent.text.trim().length} '
          'url=${tinyfishGoogleNewsContent.url}',
        ));
        return tinyfishGoogleNewsContent;
      }
      if (tinyfishGoogleNewsResult.disabled) {
        unawaited(AppLogger.log(
          'News Tinyfish: disabilitato su Google News non risolto, '
          'uso riassunto RSS url=$resolvedUrl',
        ));
        return NewsArticleContent(text: article.summary, url: article.link);
      }
      unawaited(AppLogger.log(
        'News Tinyfish: URL Google News non risolto, uso riassunto RSS '
        'url=$resolvedUrl',
      ));
      return NewsArticleContent(text: article.summary, url: article.link);
    }
    final tinyfishResult = await _tryFetchTinyfishArticleContent(resolvedUrl);
    final tinyfishContent = tinyfishResult.content;
    if (tinyfishContent != null && tinyfishContent.text.trim().length >= 100) {
      unawaited(AppLogger.log(
        'News Tinyfish: testo accettato length=${tinyfishContent.text.trim().length} '
        'url=${tinyfishContent.url}',
      ));
      return tinyfishContent;
    }

    return _fetchArticleContentWithoutTinyfish(
      article,
      language: language,
      resolvedUrl: resolvedUrl,
    );
  }

  Future<NewsArticleContent> _fetchArticleContentLocalBeforeWebView(
    NewsArticle article, {
    required NewsLanguage language,
    required String resolvedUrl,
  }) async {
    unawaited(AppLogger.log(
      'News Tinyfish: modalità fallback-only attiva, eseguo solo il reader '
      'locale prima della WebView '
      'url=$resolvedUrl',
    ));

    if (_isGoogleNewsArticleUrl(resolvedUrl)) {
      unawaited(AppLogger.log(
        'News Tinyfish: URL Google News non risolto in fallback-only, '
        'reader locale non utile; Tinyfish verrà valutato soltanto dopo la '
        'WebView url=$resolvedUrl',
      ));
      return NewsArticleContent(text: article.summary, url: article.link);
    }

    try {
      final localContent = await _fetchArticleContentWithoutTinyfish(
        article,
        language: language,
        resolvedUrl: resolvedUrl,
      );
      final localLength = localContent.text.trim().length;
      unawaited(AppLogger.log(
        'News Tinyfish: reader locale completato in fallback-only '
        'length=$localLength url=$resolvedUrl',
      ));
      return localContent;
    } catch (e) {
      unawaited(AppLogger.log(
        'News Tinyfish: reader locale fallito in fallback-only, '
        'resta la WebView; Tinyfish verrà valutato dopo url=$resolvedUrl '
        'error=$e',
      ));
    }

    return NewsArticleContent(text: article.summary, url: article.link);
  }

  /// Ultimo tentativo per la modalità fallback-only.
  ///
  /// La schermata notizie richiama questo metodo solo dopo che il reader HTTP
  /// e l'estrazione della WebView non hanno prodotto un articolo valido. In
  /// modalità Tinyfish-first restituisce null, perché Tinyfish è già stato
  /// provato da [fetchArticleContent].
  Future<NewsArticleContent?> fetchArticleContentTinyfishFallback(
    NewsArticle article, {
    String? preferredUrl,
  }) async {
    final fallbackOnly = _tinyfishFallbackOnlyPolicyForCurrentSession();
    if (!fallbackOnly) {
      unawaited(AppLogger.log(
        'News Tinyfish: fallback dopo WebView ignorato perché la modalità '
        'corrente è Tinyfish-first',
      ));
      return null;
    }

    var targetUrl = preferredUrl?.trim() ?? '';
    if (targetUrl.isEmpty || !_isHttpUrl(targetUrl)) {
      targetUrl = await _resolveArticleUrl(article.link);
    }
    if (targetUrl.isEmpty) targetUrl = article.link;

    unawaited(AppLogger.log(
      'News Tinyfish: reader HTTP e WebView insufficienti, avvio ultimo '
      'fallback url=$targetUrl',
    ));
    final tinyfishResult = await _tryFetchTinyfishArticleContent(
      targetUrl,
      fallbackAttempt: true,
    );
    final tinyfishContent = tinyfishResult.content;
    if (tinyfishContent != null && tinyfishContent.text.trim().length >= 100) {
      unawaited(AppLogger.log(
        'News Tinyfish: ultimo fallback accettato '
        'length=${tinyfishContent.text.trim().length} '
        'url=${tinyfishContent.url}',
      ));
      return tinyfishContent;
    }

    unawaited(AppLogger.log(
      'News Tinyfish: ultimo fallback senza testo valido url=$targetUrl',
    ));
    return null;
  }

  Future<NewsArticleContent> _fetchArticleContentWithoutTinyfish(
    NewsArticle article, {
    required NewsLanguage language,
    required String resolvedUrl,
  }) async {
    unawaited(AppLogger.log(
      'News reader HTML: estrazione senza Tinyfish url=$resolvedUrl',
    ));
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
    unawaited(AppLogger.log(
      'News reader HTML: risposta HTTP code=${response.statusCode} '
      'profile=${fetch.profile.name} url=$resolvedUrl',
    ));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Articolo non raggiungibile: ${response.statusCode}');
    }
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (_isGoogleConsentPage(html) || _isGoogleFullCoveragePage(html)) {
      return NewsArticleContent(text: article.summary, url: article.link);
    }
    var text = _extractArticleText(html, language: language);
    unawaited(AppLogger.log(
      'News reader HTML: estrazione iniziale length=${text.trim().length} '
      'profile=${fetch.profile.name} url=$resolvedUrl',
    ));
    final resolvedUri = Uri.parse(resolvedUrl);
    final ampUri = _ampArticleUri(resolvedUri);
    if (fetch.profile != _BrowserFetchProfile.iphone &&
        _isWeakArticleText(
          text,
          article.summary,
          includeTruncated: ampUri != null,
        )) {
      unawaited(AppLogger.log(
        'News reader HTML: testo debole, provo profilo iPhone url=$resolvedUrl',
      ));
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
        unawaited(AppLogger.log(
          'News reader HTML: profilo iPhone length=${iphoneText.trim().length} '
          'previousLength=${text.trim().length} url=$resolvedUrl',
        ));
        if (iphoneText.trim().length > text.trim().length) {
          text = iphoneText;
          unawaited(AppLogger.log(
            'News reader HTML: profilo iPhone accettato url=$resolvedUrl',
          ));
        }
      }
    }
    if (ampUri != null &&
        _isWeakArticleText(
          text,
          article.summary,
          includeTruncated: true,
        )) {
      unawaited(AppLogger.log(
        'News reader HTML: testo ancora debole, provo AMP url=$ampUri',
      ));
      final ampFetch = await _browserGetWithFallback(ampUri);
      final ampResponse = ampFetch.response;
      if (ampResponse.statusCode >= 200 && ampResponse.statusCode < 300) {
        final ampHtml = utf8.decode(
          ampResponse.bodyBytes,
          allowMalformed: true,
        );
        final ampText = _extractArticleText(ampHtml, language: language);
        unawaited(AppLogger.log(
          'News reader HTML: AMP length=${ampText.trim().length} '
          'previousLength=${text.trim().length} url=$ampUri',
        ));
        if (ampText.trim().length > text.trim().length) {
          text = ampText;
          unawaited(AppLogger.log(
            'News reader HTML: AMP accettato url=$ampUri',
          ));
        }
      }
    }
    final finalText = text.isEmpty ? article.summary : text;
    unawaited(AppLogger.log(
      'News reader HTML: risultato finale length=${finalText.trim().length} '
      'usedSummary=${text.isEmpty} url=$resolvedUrl',
    ));
    return NewsArticleContent(
      text: finalText,
      url: resolvedUrl,
    );
  }

  Future<_TinyfishArticleFetchResult> _tryFetchTinyfishArticleContent(
    String articleUrl, {
    bool fallbackAttempt = false,
  }) async {
    try {
      unawaited(AppLogger.log(
        'News Tinyfish: tentativo url=$articleUrl fallbackAttempt=$fallbackAttempt',
      ));
      final uri = Uri.parse(_tinyfishArticleFetchUrl).replace(
        queryParameters: {
          'url': articleUrl,
          if (fallbackAttempt) 'fallback': '1',
        },
      );
      final response = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(_tinyfishArticleTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final disabled = _isTinyfishDisabledResponse(response);
        unawaited(AppLogger.log(
          'News Tinyfish: HTTP ${response.statusCode}, fallback reader '
          'disabled=$disabled url=$articleUrl',
        ));
        debugPrint(
          'Sonarpad news Tinyfish: HTTP ${response.statusCode}, fallback reader',
        );
        return _TinyfishArticleFetchResult(disabled: disabled);
      }

      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! Map || decoded['ok'] != true) {
        unawaited(AppLogger.log(
          'News Tinyfish: risposta non valida, fallback reader url=$articleUrl',
        ));
        return const _TinyfishArticleFetchResult();
      }

      final markdown = (decoded['markdown'] ?? '').toString().trim();
      final cacheHit = decoded['cache_hit'];
      final tinyfishEnabled = decoded['tinyfish_enabled'];
      final fallbackOnly = decoded['tinyfish_fallback_only'];
      unawaited(AppLogger.log(
        'News Tinyfish: risposta ok cache_hit=$cacheHit '
        'tinyfish_enabled=$tinyfishEnabled fallbackOnly=$fallbackOnly '
        'markdownLength=${markdown.length} url=$articleUrl',
      ));
      if (markdown.isEmpty) return const _TinyfishArticleFetchResult();

      final text = _plainTextFromMarkdown(markdown);
      if (text.trim().isEmpty) {
        unawaited(AppLogger.log(
          'News Tinyfish: markdown vuoto dopo conversione, fallback reader '
          'url=$articleUrl',
        ));
        return const _TinyfishArticleFetchResult();
      }

      final finalUrl = (decoded['final_url'] ?? decoded['url'] ?? articleUrl)
          .toString()
          .trim();
      return _TinyfishArticleFetchResult(
        content: NewsArticleContent(
          text: text,
          url: finalUrl.isEmpty ? articleUrl : finalUrl,
        ),
      );
    } catch (e) {
      unawaited(AppLogger.log(
        'News Tinyfish: errore, fallback reader url=$articleUrl error=$e',
      ));
      debugPrint('Sonarpad news Tinyfish: fetch fallito, fallback reader: $e');
      return const _TinyfishArticleFetchResult();
    }
  }

  bool _isTinyfishDisabledResponse(http.Response response) {
    final header = response.headers['x-sonarpad-tinyfish']?.toLowerCase();
    final policyHeader =
        response.headers['x-sonarpad-tinyfish-policy']?.toLowerCase();
    if (header == 'disabled') return true;
    if (policyHeader == 'fallback_only') return true;
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final lowerBody = body.toLowerCase();
    return response.statusCode == 503 &&
        (lowerBody.contains('tinyfish disabilitato') ||
            lowerBody.contains('fallback-only') ||
            lowerBody.contains('modalita fallback'));
  }

  String _plainTextFromMarkdown(String markdown) {
    var text = markdown
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '')
        .replaceAll(RegExp(r'^\s{0,3}[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s{0,3}\d+[.)]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'[*_`~]{1,3}'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');

    text = HtmlReaderService.cleanText(text)
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .join('\n\n');
    return text.trim();
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
        final guid = _text(item, 'guid');
        final description = _cleanRssDescription(_rssDescription(item));
        final source = item.findElements('source').isNotEmpty
            ? item.findElements('source').first.innerText.trim()
            : rssSource.name;
        final pubDateRaw = _text(item, 'pubDate');
        return NewsArticle(
          id: _stableArticleId(
            rssSource,
            externalId: guid,
            link: link,
            fallback: '$title|$pubDateRaw|$index',
          ),
          title: _cleanGoogleTitle(title),
          link: link,
          summary: description,
          source: _cleanFeedText(source),
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
      final externalId = _text(entry, 'id');
      return NewsArticle(
        id: _stableArticleId(
          rssSource,
          externalId: externalId,
          link: link,
          fallback: '$title|$publishedRaw|$updatedRaw|$index',
        ),
        title: _cleanGoogleTitle(title),
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

      final text = _cleanFeedText(link.text);
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
        id: _stableArticleId(
          rssSource,
          link: fullUrl,
          fallback: '$text|$index',
        ),
        title: text,
        link: fullUrl,
        summary: '',
        source: rssSource.name,
        publishedAt: DateTime.now(),
      ));
      if (articles.length >= 30) break;
    }
    return articles;
  }

  String _stableArticleId(
    NewsRssSource source, {
    String externalId = '',
    String link = '',
    required String fallback,
  }) {
    final identity = externalId.trim().isNotEmpty
        ? externalId.trim()
        : (link.trim().isNotEmpty ? link.trim() : fallback);
    return '${source.name}|$identity';
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
    final cleaned = _cleanFeedText(title);
    final idx = cleaned.lastIndexOf(' - ');
    if (idx > 0) return cleaned.substring(0, idx).trim();
    return cleaned.trim();
  }

  String _cleanHtml(String value) {
    return _cleanFeedText(value);
  }

  String _cleanFeedText(String value) {
    if (value.trim().isEmpty) return '';
    final parsedText = html_parser.parse(value).body?.text ?? value;
    return HtmlReaderService.cleanText(parsedText)
        .replaceAll(RegExp(r'\s+'), ' ')
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

  bool _isHttpUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
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
