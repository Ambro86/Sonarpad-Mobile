import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/models/news_article.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';

void main() {
  group('article reader diagnostics', () {
    String log(Map<String, Object?> body, {int status = 200}) =>
        NewsService.articleReaderResponseLog(
          http.Response(jsonEncode(body), status),
          'https://example.org/story',
        );

    test('identifies Python and cache without claiming Tinyfish', () {
      final result = log({
        'ok': true,
        'provider': 'curl_impersonate',
        'tinyfish_used': false,
        'cache_hit': true,
        'extraction_method': 'dom',
        'browser_profile': 'chrome',
        'text_length': 1234,
      });
      expect(result, contains('motore=Python (curl_cffi/BeautifulSoup)'));
      expect(result, contains('cache_hit=true'));
      expect(result, contains('tinyfish_used=false'));
      expect(result, contains('metodo=dom'));
      expect(result, contains('caratteri=1234'));
    });
    test('identifies Tinyfish fallback and failed attempts', () {
      expect(
        log({'ok': true, 'provider': 'tinyfish', 'tinyfish_used': true}),
        contains('motore=Tinyfish'),
      );
      final failure = log({
        'ok': false,
        'provider': 'curl_impersonate',
        'tinyfish_used': true,
      }, status: 503);
      expect(failure, contains('tinyfish_used=true'));
      expect(failure, contains('proseguo con i fallback dell app'));
    });
    test('legacy response does not invent the provider or leak body', () {
      final result = log({
        'ok': true,
        'markdown': 'PRIVATE ARTICLE BODY',
        'diagnostics': 'PRIVATE DIAGNOSTICS',
      });
      expect(result, contains('motore=non comunicato'));
      expect(result, isNot(contains('PRIVATE')));
    });
    test('handles HTML errors and provider headers', () {
      final result = NewsService.articleReaderResponseLog(
        http.Response(
          '<html>PRIVATE ERROR</html>',
          503,
          headers: {
            'x-sonarpad-provider': 'tinyfish',
            'x-sonarpad-cache': 'HIT',
          },
        ),
        'https://example.org/story',
      );
      expect(result, contains('motore=Tinyfish'));
      expect(result, contains('cache_hit=HIT'));
      expect(result, isNot(contains('PRIVATE')));
    });
  });
  setUp(() {
    NewsService.resetTinyfishFallbackOnlyPolicyForTests();
    NewsService.resetNewsSourceFallbacksForTests();
  });
  for (final atom in [false, true]) {
    for (final link in ['//example.org/news/story', '/news/story', 'story']) {
      test('${atom ? 'Atom' : 'RSS'} resolves article link $link', () async {
        final xml = atom
            ? '<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Story</title><link href="$link"/><id>stable-id</id></entry></feed>'
            : '<rss><channel><item><title>Story</title><link>$link</link><guid>stable-id</guid></item></channel></rss>';
        final service = NewsService(
          client: MockClient((_) async => http.Response(xml, 200)),
        );
        final articles = await service.fetchSourceNews(
          NewsRssSource(
            name: 'Fixture',
            uri: Uri.parse('https://example.org/feed/rss.xml'),
          ),
        );
        expect(
          articles.single.link,
          Uri.parse(
            'https://example.org/feed/rss.xml',
          ).resolve(link).toString(),
        );
        expect(articles.single.id, 'Fixture|stable-id');
      });
    }
  }
  test('legacy euro in feed titles is readable', () async {
    final service = NewsService(
      client: MockClient(
        (_) async => http.Response(
          '<rss><channel><item><title>Offerta 280\u0080</title><link>https://example.org/story</link></item></channel></rss>',
          200,
          headers: {'content-type': 'application/xml; charset=utf-8'},
        ),
      ),
    );
    final articles = await service.fetchSourceNews(
      NewsRssSource(name: 'Fixture', uri: Uri.parse('https://example.org/rss')),
    );
    expect(articles.single.title, 'Offerta 280€');
  });

  test('Python plain text retains all Unicode and literal punctuation',
      () async {
    const content =
        'Il confronto è 3 < 5 e 8 > 4. Il parametro si chiama valore_medio, costa ~20 euro e usa * per moltiplicare.\n\n'
        'Leggi anche è una locuzione citata nel testo, che non deve tagliare il resto dell’articolo.\n\n'
        'Ultimo paragrafo completo: più informazioni, città, perché e un simbolo 📰.';
    final service = NewsService(
      client: MockClient((request) async {
        if (request.url.queryParameters['policy'] == '1') {
          return http.Response(
            jsonEncode({'ok': true, 'tinyfish_fallback_only': false}),
            200,
          );
        }
        expect(request.url.host, 'sonarpad.com');
        expect(request.url.queryParameters['url'], 'https://example.org/story');
        return http.Response(
          jsonEncode({
            'ok': true,
            'format': 'text',
            'markdown': content,
            'final_url': 'https://example.org/story',
            'text_length': content.runes.length,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await service.loadTinyfishFallbackOnlyPolicyForSession();
    final result = await service.fetchArticleContent(
      const NewsArticle(
        id: '1',
        title: 'Test',
        link: 'https://example.org/story',
        summary: 'Short summary',
        source: 'Fixture',
        publishedAt: null,
      ),
      language: NewsLanguage.italian,
    );
    expect(result.text, content);
  });
  test('legacy Markdown backend remains supported', () async {
    final body =
        'Un testo con informazioni utili e dettagli approfonditi. ' * 5;
    final service = NewsService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.queryParameters.containsKey('policy')
                ? {'ok': true, 'tinyfish_fallback_only': false}
                : {
                    'ok': true,
                    'format': 'markdown',
                    'markdown': '## Titolo\n\n**$body**',
                  },
          ),
          200,
        ),
      ),
    );
    await service.loadTinyfishFallbackOnlyPolicyForSession();
    final result = await service.fetchArticleContent(
      const NewsArticle(
        id: '1',
        title: 'Test',
        link: 'https://example.org/story',
        summary: '',
        source: 'Fixture',
        publishedAt: null,
      ),
      language: NewsLanguage.italian,
    );
    expect(result.text, contains(body.trim()));
    expect(result.text, isNot(contains('**')));
  });
}
