import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';

void main() {
  const feed = '''<rss version="2.0"><channel>
<item><title>National</title><link>https://news.google.com/rss/articles/a</link><source url="https://www.repubblica.it">la Repubblica</source></item>
<item><title>Bologna</title><link>https://news.google.com/rss/articles/b</link><source url="https://bologna.repubblica.it">Bologna</source></item>
<item><title>Local</title><link>https://news.google.com/rss/articles/c</link><source url="https://PALERMO.REPUBBLICA.IT">Palermo</source></item>
<item><title>Direct</title><link>https://repubblica.it/story</link></item>
<item><title>Name only</title><link>https://news.google.com/rss/articles/d</link><source>la Repubblica</source></item>
<item><title>Domain only</title><link>https://news.google.com/rss/articles/e</link><source>bologna.repubblica.it</source></item>
<item><title>La Repubblica mentioned by another paper</title><link>https://news.google.com/rss/articles/f</link><source url="https://example.org">Another paper</source></item>
<item><title>Similar domain</title><link>https://notrepubblica.it/story</link><source url="https://repubblica.it.example.org">Other</source></item>
<item><title>No source</title><link>https://news.google.com/rss/articles/g</link></item>
</channel></rss>''';

  Future<List<String>> titles(String url) async {
    var requests = 0;
    final service = NewsService(
      client: MockClient((request) async {
        requests++;
        expect(request.url.toString(), url);
        return http.Response(feed, 200);
      }),
    );
    final articles = await service.fetchSourceNews(
      NewsRssSource(name: 'Test', uri: Uri.parse(url), isCustom: true),
      language: NewsLanguage.italian,
    );
    expect(requests, 1); // No per-article redirects/network requests.
    return articles.map((article) => article.title).toList();
  }

  test(
    'Google News excludes publisher and local editions before listing',
    () async {
      final result = await titles('https://news.google.com/rss?hl=it');
      expect(
        result,
        unorderedEquals([
          'La Repubblica mentioned by another paper',
          'Similar domain',
          'No source',
        ]),
      );
    },
  );
  test('Google News search uses the same exclusion', () async {
    expect(
      await titles('https://news.google.com/rss/search?q=Bologna'),
      hasLength(3),
    );
  });
  test('other RSS sources keep the publisher exclusion', () async {
    expect(await titles('https://example.org/feed.xml'), hasLength(3));
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NewsService.resetNewsSourceFallbacksForTests();
  });

  test(
    'community sources keep the exclusion after storage and cloud refresh',
    () async {
      final service = NewsService(
        client: MockClient(
          (request) async => http.Response(
            request.url.path.endsWith('get_community_news_sources.php')
                ? jsonEncode({
                    'items': [
                      {
                        'name': 'Repubblica',
                        'url':
                            'https://www.repubblica.it/rss/homepage/rss2.0.xml',
                        'language': 'it',
                      },
                    ],
                  })
                : feed,
            200,
          ),
        ),
      );
      final communitySource = (await service.fetchCommunityNewsSources(
        NewsLanguage.italian,
      )).single;
      await service.addCustomSource(
        NewsLanguage.italian,
        communitySource.name,
        communitySource.uri.toString(),
      );
      var source = (await service.getCustomSources(
        NewsLanguage.italian,
      )).single;
      expect(source.name, 'Repubblica');
      expect(
        NewsRssSource.fromJson(
          source.copyWith(name: 'Il mio giornale').toJson(),
        ).toJson(),
        isNot(contains('allowRepubblica')),
      );
      expect(
        await service.fetchSourceNews(source, language: NewsLanguage.italian),
        hasLength(3),
      );
      final cloud = await service.exportCloudCollections();
      await service.replaceCloudCollections(cloud);
      source = (await service.getCustomSources(NewsLanguage.italian)).single;
      expect(source.uri, communitySource.uri);
      expect(
        await service.fetchSourceNews(source, language: NewsLanguage.italian),
        hasLength(3),
      );
      expect(await titles('https://news.google.com/rss?hl=it'), hasLength(3));
    },
  );

  test(
    'legacy community permission cannot leak into aggregated news',
    () async {
      SharedPreferences.setMockInitialValues({
        'news_custom_sources_italian': [
          jsonEncode({
            'name': 'Repubblica',
            'uri': 'https://www.repubblica.it/rss/homepage/rss2.0.xml',
            'isCustom': true,
            'allowRepubblica': true,
          }),
        ],
      });
      final service = NewsService(
        client: MockClient((_) async => http.Response(feed, 200)),
      );
      final source = (await service.getCustomSources(
        NewsLanguage.italian,
      )).single;
      expect(source.name, 'Repubblica');
      expect(source.toJson(), isNot(contains('allowRepubblica')));
      expect(
        await service.fetchSourceNews(source, language: NewsLanguage.italian),
        hasLength(3),
      );
      final articles = await service.fetchTopNews(NewsLanguage.italian);
      expect(articles, isNotEmpty);
      expect(
        articles.map((article) => article.title),
        everyElement(
          isIn([
            'La Repubblica mentioned by another paper',
            'Similar domain',
            'No source',
          ]),
        ),
      );
    },
  );

  test('all manually added sources keep the publisher exclusion', () async {
    final service = NewsService(
      client: MockClient((_) async => http.Response(feed, 200)),
    );
    await service.addCustomSource(
      NewsLanguage.italian,
      'Manuale',
      'https://www.repubblica.it/feed.xml',
    );
    await service.addCustomSource(
      NewsLanguage.italian,
      'Altro',
      'https://example.org/feed.xml',
    );
    await service.addCustomSource(
      NewsLanguage.italian,
      'Google',
      'https://news.google.com/rss?hl=it',
    );
    for (final source in await service.getCustomSources(NewsLanguage.italian)) {
      expect(
        await service.fetchSourceNews(source, language: NewsLanguage.italian),
        hasLength(3),
      );
    }
    expect(
      NewsRssSource.fromJson({
        'name': 'Vecchia',
        'uri': 'https://repubblica.it/rss',
      }).toJson(),
      isNot(contains('allowRepubblica')),
    );
  });

  test('source-specific Google fallback also excludes Repubblica', () async {
    final requested = <Uri>[];
    final service = NewsService(
      client: MockClient((request) async {
        requested.add(request.url);
        return http.Response(
          request.url.host == 'news.google.com'
              ? feed
              : '<rss><channel/></rss>',
          200,
        );
      }),
    );
    await service.addCustomSource(
      NewsLanguage.italian,
      'Repubblica',
      'https://www.repubblica.it/rss/homepage/rss2.0.xml',
    );
    final source = (await service.getCustomSources(
      NewsLanguage.italian,
    )).single;
    expect(
      await service.fetchSourceNews(source, language: NewsLanguage.italian),
      hasLength(3),
    );
    expect(requested.last.host, 'news.google.com');
    expect(requested.last.queryParameters['q'], 'site:repubblica.it');
    expect(
      await service.fetchSourceNews(
        NewsRssSource(
          name: 'Google',
          uri: Uri.parse('https://news.google.com/rss'),
        ),
        language: NewsLanguage.italian,
      ),
      hasLength(3),
    );
  });
}
