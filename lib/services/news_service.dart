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
    articles.sort((a, b) {
      final aDate = a.publishedAt;
      final bDate = b.publishedAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return articles.take(40).toList();
  }

  Future<List<NewsArticle>> fetchSourceNews(NewsRssSource source) async {
    final articles = await _fetchRssSource(source);
    return articles.take(40).toList();
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
      final description = _cleanHtml(_text(item, 'description'));
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

  DateTime? _parseRssDate(String value) {
    // Esempio: Fri, 15 May 2026 02:40:00 GMT
    try {
      return HttpDate.parse(value);
    } catch (_) {
      return null;
    }
  }
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
