import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/models/news_article.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/english_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/french_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/italian_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/spanish_news_sources.dart';

void main() {
  group('NewsService', () {
    setUp(() {
      NewsService.resetTinyfishFallbackOnlyPolicyForTests();
    });

    test('uses Corriere restyle 2025 feed as default source', () {
      final corriere = italianNewsSources.firstWhere(
        (source) => source.name == 'Corriere della Sera',
      );

      expect(
        corriere.uri.toString(),
        'https://xml2.corriereobjects.it/feed-hp/homepage-restyle-2025.xml',
      );
    });

    test('uses Affaritaliani WordPress feed', () {
      final affaritaliani = italianNewsSources.firstWhere(
        (source) => source.name == 'Affaritaliani',
      );

      expect(
        affaritaliani.uri.toString(),
        'https://www.affaritaliani.it/feed',
      );
    });

    test('keeps DDay RSS feed enabled', () {
      final dday = italianNewsSources.firstWhere(
        (source) => source.name == 'DDay',
      );

      expect(dday.uri.toString(), 'https://www.dday.it/rss');
    });

    test('uses Tom Hardware official feed URL', () {
      final tomsHardware = italianNewsSources.firstWhere(
        (source) => source.name == 'Tom\'s Hardware Italia',
      );

      expect(tomsHardware.uri.toString(), 'https://www.tomshw.it/feed');
    });

    test('uses Il Foglio current latest news feed', () {
      final ilFoglio = italianNewsSources.firstWhere(
        (source) => source.name == 'Il Foglio',
      );

      expect(
        ilFoglio.uri.toString(),
        'https://naxos.ilfoglio.it/api/v5/rss/stories/latest',
      );
    });

    test('uses Google News fallback for Il Post and Internazionale', () {
      final ilPost = italianNewsSources.firstWhere(
        (source) => source.name == 'Il Post',
      );
      final internazionale = italianNewsSources.firstWhere(
        (source) => source.name == 'Internazionale',
      );

      expect(
        ilPost.uri.toString(),
        'https://news.google.com/rss/search?q=site%3Ailpost.it&hl=it&gl=IT&ceid=IT:it',
      );
      expect(
        internazionale.uri.toString(),
        'https://news.google.com/rss/search?q=site%3Ainternazionale.it%20-inurl%3Aultime-notizie-reuters&hl=it&gl=IT&ceid=IT:it',
      );
    });

    test('keeps additional Italian news feeds enabled', () {
      final avvenire = italianNewsSources.firstWhere(
        (source) => source.name == 'Avvenire',
      );
      final ilManifesto = italianNewsSources.firstWhere(
        (source) => source.name == 'Il Manifesto',
      );
      final micromega = italianNewsSources.firstWhere(
        (source) => source.name == 'Micromega',
      );
      final espresso = italianNewsSources.firstWhere(
        (source) => source.name == 'L\'Espresso',
      );
      final ilDomani = italianNewsSources.firstWhere(
        (source) => source.name == 'Il Domani',
      );
      final iphoneItalia = italianNewsSources.firstWhere(
        (source) => source.name == 'iPhone Italia',
      );

      expect(
        avvenire.uri.toString(),
        'https://news.google.com/rss/search?q=site%3Aavvenire.it&hl=it&gl=IT&ceid=IT:it',
      );
      expect(ilManifesto.uri.toString(), 'https://ilmanifesto.it/feed');
      expect(micromega.uri.toString(), 'https://www.micromega.net/feed/');
      expect(espresso.uri.toString(), 'https://lespresso.it/feed');
      expect(ilDomani.uri.toString(), 'https://www.editorialedomani.it/rss');
      expect(iphoneItalia.uri.toString(), 'https://www.iphoneitalia.com/feed');
    });

    test('uses The Atlantic canonical all articles feed', () {
      final theAtlantic = englishNewsSources.firstWhere(
        (source) => source.name == 'The Atlantic – All Articles',
      );

      expect(
        theAtlantic.uri.toString(),
        'https://www.theatlantic.com/feed/all',
      );
    });

    test('keeps Vox latest stories feed URL', () {
      final vox = englishNewsSources.firstWhere(
        (source) => source.name == 'Vox – Latest Stories',
      );

      expect(vox.uri.toString(), 'https://www.vox.com/rss/index.xml');
    });

    test('keeps The Verge all stories feed URL', () {
      final theVerge = englishNewsSources.firstWhere(
        (source) => source.name == 'The Verge – All Stories',
      );

      expect(theVerge.uri.toString(), 'https://www.theverge.com/rss/index.xml');
    });

    test('keeps Product Hunt daily feed URL', () {
      final productHunt = englishNewsSources.firstWhere(
        (source) => source.name == 'Product Hunt – Daily Feed',
      );

      expect(productHunt.uri.toString(), 'https://www.producthunt.com/feed');
    });

    test('uses Liberation latest RSS feed', () {
      final liberation = frenchNewsSources.firstWhere(
        (source) => source.name == 'Libération',
      );

      expect(
        liberation.uri.toString(),
        'http://rss.liberation.fr/rss/latest/',
      );
    });

    test('uses Les Echos current economy feed', () {
      final lesEchos = frenchNewsSources.firstWhere(
        (source) => source.name == 'Les Échos',
      );

      expect(
        lesEchos.uri.toString(),
        'https://services.lesechos.fr/rss/les-echos-economie.xml',
      );
    });

    test('uses 20 Minutes current front page feed', () {
      final twentyMinutes = frenchNewsSources.firstWhere(
        (source) => source.name == '20 Minutes',
      );

      expect(
        twentyMinutes.uri.toString(),
        'https://www.20minutes.fr/feeds/rss-une.xml',
      );
    });

    test('uses Google News fallback for L Equipe', () {
      final lequipe = frenchNewsSources.firstWhere(
        (source) => source.name == 'L\'Équipe',
      );

      expect(
        lequipe.uri.toString(),
        'https://news.google.com/rss/search?q=site%3Alequipe.fr&hl=fr&gl=FR&ceid=FR:fr',
      );
    });

    test('uses Google News fallback for Eurosport France', () {
      final eurosport = frenchNewsSources.firstWhere(
        (source) => source.name == 'Eurosport',
      );

      expect(
        eurosport.uri.toString(),
        'https://news.google.com/rss/search?q=site%3Aeurosport.fr&hl=fr&gl=FR&ceid=FR:fr',
      );
    });

    test('keeps El Confidencial official feeds', () {
      final espana = spanishNewsSources.firstWhere(
        (source) => source.name == 'El Confidencial – España',
      );
      final mundo = spanishNewsSources.firstWhere(
        (source) => source.name == 'El Confidencial – Mundo',
      );

      expect(espana.uri.toString(), 'https://rss.elconfidencial.com/espana/');
      expect(mundo.uri.toString(), 'https://rss.elconfidencial.com/mundo/');
    });

    test('normalizes old Corriere home feed to the updated endpoint', () async {
      Uri? requestedUri;
      final service = NewsService(
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Corriere.it</title>
    <item>
      <title>Notizia aggiornata</title>
      <link>https://www.corriere.it/notizia.html</link>
      <description>Descrizione</description>
      <pubDate>Thu, 28 May 2026 08:30:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''',
            200,
          );
        }),
      );

      final articles = await service.fetchSourceNews(
        NewsRssSource(
          name: 'Corriere della Sera',
          uri:
              Uri.parse('https://xml2.corriereobjects.it/feed-hp/homepage.xml'),
        ),
      );

      expect(
        requestedUri.toString(),
        'https://xml2.corriereobjects.it/feed-hp/homepage-restyle-2025.xml',
      );
      expect(articles.single.title, 'Notizia aggiornata');
    });

    test('parses Atom feeds such as Reddit RSS', () async {
      final service = NewsService(
        client: MockClient((request) async {
          return http.Response(
            '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>reddit.com: /r/worldnews</title>
  <entry>
    <title>World news title</title>
    <link href="https://www.reddit.com/r/worldnews/comments/example/story/" />
    <content type="html">&lt;p&gt;Story summary&lt;/p&gt;</content>
    <updated>2026-06-01T10:00:00+00:00</updated>
  </entry>
</feed>
''',
            200,
          );
        }),
      );

      final articles = await service.fetchSourceNews(
        NewsRssSource(
          name: 'Reddit – World News',
          uri: Uri.parse('https://www.reddit.com/r/worldnews/.rss'),
        ),
      );

      expect(articles.single.title, 'World news title');
      expect(
        articles.single.link,
        'https://www.reddit.com/r/worldnews/comments/example/story/',
      );
      expect(articles.single.summary, 'Story summary');
    });

    test('parses RSS content encoded fallback used by Vox-style feeds', () async {
      final service = NewsService(
        client: MockClient((request) async {
          return http.Response(
            '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <item>
      <title>Vox story</title>
      <link>https://www.vox.com/example</link>
      <content:encoded>&lt;p&gt;Vox encoded summary&lt;/p&gt;</content:encoded>
      <pubDate>Mon, 01 Jun 2026 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''',
            200,
          );
        }),
      );

      final articles = await service.fetchSourceNews(
        NewsRssSource(
          name: 'Vox – Latest Stories',
          uri: Uri.parse('https://www.vox.com/rss/index.xml'),
        ),
      );

      expect(articles.single.title, 'Vox story');
      expect(articles.single.summary, 'Vox encoded summary');
    });

    test('uses Tinyfish markdown before the existing article reader', () async {
      final requested = <Uri>[];
      final service = NewsService(
        client: MockClient((request) async {
          requested.add(request.url);
          expect(request.url.host, 'sonarpad.com');
          if (request.url.queryParameters['policy'] == '1') {
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'ok': true,
                'tinyfish_fallback_only': false,
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'ok': true,
              'url': 'https://example.com/story',
              'final_url': 'https://example.com/story',
              'format': 'markdown',
              'markdown': '''
# Titolo articolo

Questo è il primo paragrafo letto da Tinyfish, abbastanza lungo per essere accettato dal reader delle notizie senza passare al vecchio estrattore HTML.

Questo è il secondo paragrafo con un [link utile](https://example.com) e testo pulito.
''',
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await service.loadTinyfishFallbackOnlyPolicyForSession();

      final content = await service.fetchArticleContent(
        const NewsArticle(
          id: '1',
          title: 'Titolo articolo',
          link: 'https://example.com/story',
          summary: 'Riassunto RSS',
          source: 'Test',
          publishedAt: null,
        ),
        language: NewsLanguage.italian,
      );

      expect(
        requested.map((uri) => uri.queryParameters['policy'] == '1'),
        [true, false],
      );
      expect(content.text, contains('Titolo articolo'));
      expect(content.text, contains('link utile'));
      expect(content.text, isNot(contains('](https://example.com)')));
    });

    test('falls back to the existing article reader when Tinyfish fails',
        () async {
      final requested = <Uri>[];
      final service = NewsService(
        client: MockClient((request) async {
          requested.add(request.url);
          if (request.url.host == 'sonarpad.com' &&
              request.url.queryParameters['policy'] == '1') {
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'ok': true,
                'tinyfish_fallback_only': false,
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.host == 'sonarpad.com') {
            return http.Response('{"ok":false}', 502);
          }
          return http.Response(
            '''
<!doctype html>
<html>
  <head><title>Fallback</title></head>
  <body>
    <article>
      <p>Questo paragrafo arriva dal reader HTML esistente e deve restare disponibile quando Tinyfish non risponde correttamente.</p>
      <p>Secondo paragrafo abbastanza lungo per verificare che il comportamento precedente non venga rimosso.</p>
    </article>
  </body>
</html>
''',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );

      await service.loadTinyfishFallbackOnlyPolicyForSession();

      final content = await service.fetchArticleContent(
        const NewsArticle(
          id: '2',
          title: 'Fallback',
          link: 'https://example.com/fallback',
          summary: 'Riassunto RSS',
          source: 'Test',
          publishedAt: null,
        ),
        language: NewsLanguage.italian,
      );

      expect(
        requested.map((uri) => uri.queryParameters['policy'] == '1'),
        [true, false, false],
      );
      expect(requested.map((uri) => uri.host), [
        'sonarpad.com',
        'sonarpad.com',
        'example.com',
      ]);
      expect(content.text, contains('reader HTML esistente'));
    });
  });
}
