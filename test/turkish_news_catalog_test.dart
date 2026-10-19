import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NewsService.resetNewsSourceFallbacksForTests();
    NewsService.resetTinyfishFallbackOnlyPolicyForTests();
  });

  test('Turkish catalog exposes thirteen publishers and localized Google topics', () {
    final sources = NewsLanguage.turkish.rssSources;
    expect(sources.map((source) => source.name), [
      'Google News',
      'Anadolu Ajansı',
      'TRT Haber',
      'NTV',
      'Habertürk',
      'Hürriyet',
      'Cumhuriyet',
      'Sözcü',
      'Sabah',
      'BirGün',
      'Ensonhaber',
      'Edebiyat Haber – Kitaplar Arasında',
      'Meb Personel',
      'Yaşadıkça',
    ]);
    expect(sources.map((source) => source.uri).toSet(), hasLength(14));
    expect(sources.every((source) => !source.isCustom), isTrue);
    expect(sources.every((source) => source.uri.scheme == 'https'), isTrue);
    expect(
      sources.where((source) => source.uri.host == 'news.google.com'),
      hasLength(1),
    );

    final google = sources.first;
    final categories = google.categories!;
    expect(categories, hasLength(8));
    expect(categories.where((category) => category.isLocal), hasLength(1));
    final topics = categories.where((category) => !category.isLocal).toList();
    expect(
      topics.map((category) => category.uri.pathSegments.last).toSet(),
      {
        'NATION',
        'WORLD',
        'BUSINESS',
        'TECHNOLOGY',
        'ENTERTAINMENT',
        'SPORTS',
        'HEALTH',
      },
    );
    for (final uri in [google.uri, ...topics.map((category) => category.uri)]) {
      expect(uri.queryParameters['hl'], 'tr');
      expect(uri.queryParameters['gl'], 'TR');
      expect(uri.queryParameters['ceid'], 'TR:tr');
    }

    for (final locale in ['tr', 'it', 'en']) {
      final l10n = lookupSupportedAppLocalizations(locale);
      final labels = {
        NewsRssCategoryLabel.myCity: l10n.newsCategoryMyCity,
        NewsRssCategoryLabel.turkey: l10n.radioCountryOptionTr,
        NewsRssCategoryLabel.world: l10n.newsCategoryWorld,
        NewsRssCategoryLabel.business: l10n.newsCategoryBusiness,
        NewsRssCategoryLabel.technology: l10n.newsCategoryTechnology,
        NewsRssCategoryLabel.entertainment: l10n.newsCategoryEntertainment,
        NewsRssCategoryLabel.sports: l10n.newsCategorySports,
        NewsRssCategoryLabel.health: l10n.newsCategoryHealth,
      };
      expect(NewsLanguage.turkish.label(l10n), l10n.radioLanguageTr);
      for (final category in sources.expand(
        (source) => source.categories ?? const <NewsRssCategory>[],
      )) {
        expect(category.label, isNotNull);
        expect(category.displayName(l10n), labels[category.label]);
      }
    }
  });

  test('NTV Atom entries retain Turkish text, links, dates and newest order',
      () async {
    final atom = await File('test/fixtures/ntv_atom.xml').readAsString();
    final source = NewsLanguage.turkish.rssSources.firstWhere(
      (source) => source.name == 'NTV',
    );
    final requests = <http.Request>[];
    final service = NewsService(client: MockClient((request) async {
      requests.add(request);
      expect(request.url, source.uri);
      return http.Response.bytes(
        utf8.encode(atom),
        200,
        headers: {'content-type': 'application/xml; charset=utf-8'},
      );
    }));

    final articles = await service.fetchSourceNews(
      source,
      language: NewsLanguage.turkish,
    );

    expect(requests, hasLength(1));
    expect(
      requests.single.headers.entries
          .firstWhere((entry) => entry.key.toLowerCase() == 'accept-language')
          .value,
      startsWith('tr-TR,tr;'),
    );
    expect(articles.map((article) => article.title), [
      "Ankara'da bilim ve kültür günü",
      "İstanbul'da kütüphane buluşması",
    ]);
    expect(articles.map((article) => article.link), [
      'https://example.org/ntv/newer',
      'https://example.org/ntv/older',
    ]);
    expect(articles.map((article) => article.id), [
      'NTV|urn:sonarpad:ntv-fixture:newer',
      'NTV|urn:sonarpad:ntv-fixture:older',
    ]);
    expect(articles.first.publishedAt, DateTime.utc(2026, 10, 13, 9, 15));
    expect(articles.last.publishedAt, DateTime.utc(2026, 10, 12, 7));
    expect(articles.first.summary, "Ankara'da açık ders. Programı indir");
    expect(articles.last.summary, 'Öğrenciler kitap & dergi seçiyor.');
    expect(articles.every((article) => article.source == 'NTV'), isTrue);
    expect(articles.every((article) => !article.allowInternalMediaLinks), isTrue);
    expect(articles.every((article) => article.mediaLinks.isEmpty), isTrue);
  });

  test('new publishers append without changing saved order or hidden sources',
      () async {
    final customJson = jsonEncode({
      'name': 'Saved Turkish source',
      'uri': 'https://example.org/saved-feed',
      'isCustom': true,
    });
    const savedOrder = ['source:Saved Turkish source', 'source:Google News'];
    SharedPreferences.setMockInitialValues({
      'news_sources_order_turkish': savedOrder,
      'news_sources_hidden_turkish': ['Google News'],
      'news_custom_sources_turkish': [customJson],
      'news_sources_hidden_english': ['BBC News'],
    });
    final service = NewsService(client: MockClient((request) async {
      fail('Reading the source catalog must not fetch ${request.url}.');
    }));

    final sources = await service.getOrderedSources(NewsLanguage.turkish);
    expect(sources, hasLength(14));
    expect(sources.first.name, 'Saved Turkish source');
    expect(sources.first.isCustom, isTrue);
    expect(sources.first.uri.toString(), 'https://example.org/saved-feed');
    expect(sources.any((source) => source.name == 'Google News'), isFalse);
    expect(
      sources.skip(1).map((source) => source.name),
      NewsLanguage.turkish.rssSources
          .where((source) => source.name != 'Google News')
          .map((source) => source.name),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('news_sources_order_turkish'), savedOrder);
    expect(prefs.getStringList('news_sources_hidden_turkish'), ['Google News']);
    expect(prefs.getStringList('news_custom_sources_turkish'), [customJson]);
    expect(prefs.getStringList('news_sources_hidden_english'), ['BBC News']);
  });
}
