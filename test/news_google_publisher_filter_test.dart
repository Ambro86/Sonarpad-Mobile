import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  test('non-Google RSS sources remain unchanged', () async {
    expect(await titles('https://example.org/feed.xml'), hasLength(9));
  });
}
