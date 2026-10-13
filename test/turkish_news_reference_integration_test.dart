import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/services/gutendex_service.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';
import 'package:sonarpad_mobile_starter/services/wikipedia_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NewsService.resetNewsSourceFallbacksForTests();
    NewsService.resetTinyfishFallbackOnlyPolicyForTests();
  });

  test('Turkish news edition exposes localized categories and Turkish feeds', () {
    final l10n = lookupSupportedAppLocalizations('tr-TR');
    final language = NewsLanguage.turkish;
    final source = language.rssSources.singleWhere(
      (source) => source.name == 'Google News',
    );

    expect(language.code, 'tr');
    expect(language.communityKey, 'turkish');
    expect(language.label(l10n), l10n.radioLanguageTr);
    expect(source.name, 'Google News');
    final categories = source.categories!;
    expect(categories.where((category) => category.isLocal), hasLength(1));
    expect(
      categories.firstWhere((category) => category.isLocal).displayName(l10n),
      l10n.newsCategoryMyCity,
    );
    for (final uri in [
      source.uri,
      ...categories.where((category) => !category.isLocal).map((c) => c.uri),
    ]) {
      expect(uri.host, 'news.google.com');
      expect(uri.queryParameters['hl'], 'tr');
      expect(uri.queryParameters['gl'], 'TR');
      expect(uri.queryParameters['ceid'], 'TR:tr');
    }
    expect(
      categories.firstWhere((c) => c.label == NewsRssCategoryLabel.world)
          .displayName(l10n),
      l10n.newsCategoryWorld,
    );
  });

  test('Turkish custom searches keep existing language preferences intact', () async {
    final savedEnglishSource = jsonEncode({
      'name': 'Saved source',
      'uri': 'https://example.org/feed',
      'isCustom': true,
    });
    SharedPreferences.setMockInitialValues({
      'news_custom_sources_english': [savedEnglishSource],
      'news_sources_hidden_english': ['Hidden source'],
    });
    final service = NewsService(client: MockClient((request) async {
      fail('Adding a named search source should not fetch ${request.url}.');
    }));

    await service.addCustomSource(NewsLanguage.turkish, 'Search', 'science news');
    final source = (await service.getCustomSources(NewsLanguage.turkish)).single;
    expect(source.uri.queryParameters['q'], 'science news');
    expect(source.uri.queryParameters['hl'], 'tr');
    expect(source.uri.queryParameters['gl'], 'TR');
    expect(source.uri.queryParameters['ceid'], 'TR:tr');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('news_custom_sources_english'), [savedEnglishSource]);
    expect(prefs.getStringList('news_sources_hidden_english'), ['Hidden source']);
    expect(
      (await service.getCustomSources(NewsLanguage.english)).single.name,
      'Saved source',
    );
  });

  test('Turkish RSS fallback keeps the edition and request language', () async {
    final requests = <http.Request>[];
    final service = NewsService(client: MockClient((request) async {
      requests.add(request);
      if (request.url.host == 'news.google.com') {
        return http.Response(
          '<rss version="2.0"><channel><item><title>Article</title>'
          '<link>https://example.org/article</link></item></channel></rss>',
          200,
        );
      }
      return http.Response('Unavailable', 503);
    }));

    final articles = await service.fetchSourceNews(
      NewsRssSource(name: 'Example', uri: Uri.parse('https://example.org/feed')),
      language: NewsLanguage.turkish,
    );

    expect(articles.single.title, 'Article');
    final fallback = requests.last;
    expect(fallback.url.queryParameters['q'], 'site:example.org');
    expect(fallback.url.queryParameters['hl'], 'tr');
    expect(fallback.url.queryParameters['gl'], 'TR');
    expect(fallback.url.queryParameters['ceid'], 'TR:tr');
    expect(
      fallback.headers.entries
          .firstWhere((entry) => entry.key.toLowerCase() == 'accept-language')
          .value,
      startsWith('tr-TR,tr;'),
    );
  });

  test('Wikipedia search and import use the selected Turkish edition', () async {
    final requests = <Uri>[];
    final service = WikipediaService(client: MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        jsonEncode(request.url.queryParameters['action'] == 'query'
            ? {
                'query': {
                  'search': [
                    {'pageid': 42, 'title': 'Reference article'},
                  ],
                },
              }
            : {
                'parse': {
                  'title': 'Reference article',
                  'text': '<div class="mw-parser-output"><p>Body.</p></div>',
                },
              }),
        200,
      );
    }));

    final result = (await service.search('reference', lang: 'tr')).single;
    final article = await service.importArticle(result.pageId, lang: 'tr');
    expect(requests, hasLength(2));
    expect(requests.every((uri) => uri.host == 'tr.wikipedia.org'), isTrue);
    expect(article.url, 'https://tr.wikipedia.org/wiki/Reference_article');
    expect(article.text, 'Body.');
  });

  test('Wikipedia HTTP failures can be rendered in the app language', () async {
    final l10n = lookupSupportedAppLocalizations('tr_TR');
    final service = WikipediaService(
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );
    await expectLater(
      service.importArticle(42, lang: 'en'),
      throwsA(
        isA<WikipediaRequestException>()
            .having((error) => error.statusCode, 'HTTP status', 503)
            .having((error) => error.languageCode, 'content language', 'en')
            .having(
              (error) => error.localizedMessage(l10n),
              'app-language message',
              l10n.wikipediaImportHttpError(503),
            ),
      ),
    );
  });

  test('Gutenberg passes Turkish through and localizes absent metadata', () async {
    final l10n = lookupSupportedAppLocalizations('tr');
    late Uri requested;
    final service = GutendexService(client: MockClient((request) async {
      requested = request.url;
      return http.Response(jsonEncode({
        'count': 1,
        'results': [
          {'id': 42, 'languages': ['tr'], 'authors': []},
        ],
      }), 200);
    }));

    final page = await service.searchBooks('reference', language: 'tr');
    expect(requested.host, 'sonarpad.com');
    expect(requested.path, '/api/gutenberg/search.php');
    expect(requested.queryParameters['lang'], 'tr');
    expect(page.books.single.languages, ['tr']);
    expect(page.books.single.titleLabel(l10n), l10n.gutenbergUntitledBook);
    expect(page.books.single.authorLabel(l10n), l10n.gutenbergUnknownAuthor);
  });

  test('Gutenberg HTTP failures retain the status and localize for Turkish', () async {
    final l10n = lookupSupportedAppLocalizations('tr');
    final service = GutendexService(
      client: MockClient((_) async => http.Response('Unavailable', 502)),
    );
    await expectLater(
      service.searchBooks('reference', language: 'tr'),
      throwsA(
        isA<GutendexException>()
            .having((error) => error.statusCode, 'HTTP status', 502)
            .having(
              (error) => error.localizedMessage(l10n),
              'app-language message',
              l10n.gutenbergSearchHttpError(502),
            ),
      ),
    );
  });
}
