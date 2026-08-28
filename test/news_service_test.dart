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
      NewsService.resetNewsSourceFallbacksForTests();
    });

    test('riconosce come insufficiente il testo composto solo dal titolo', () {
      const title = 'Un titolo molto lungo: con spazi e punteggiatura!';

      expect(
        NewsService.isArticleTextOnlyTitle(title, title),
        isTrue,
      );
      expect(
        NewsService.isArticleTextOnlyTitle('$title\n\n$title', title),
        isTrue,
      );
      expect(
        NewsService.isArticleTextOnlyTitle(
          '$title\n\nQuesto è il primo paragrafo dell articolo.',
          title,
        ),
        isFalse,
      );
      expect(
        NewsService.isArticleTextOnlyTitle(
          'Un testo breve ma diverso dal titolo.',
          title,
        ),
        isFalse,
      );
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

    test('uses Google News directly for Il Giornale', () {
      final ilGiornale = italianNewsSources.firstWhere(
        (source) => source.name == 'Il Giornale',
      );

      expect(
        ilGiornale.uri.toString(),
        'https://news.google.com/rss/search?q=site%3Ailgiornale.it&hl=it&gl=IT&ceid=IT:it',
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

    test('returns every article from a single RSS source', () async {
      final items = List.generate(
        75,
        (index) => '''
    <item>
      <guid>article-$index</guid>
      <title>Notizia $index</title>
      <link>https://example.com/news/$index</link>
      <pubDate>Thu, 28 May 2026 08:30:00 GMT</pubDate>
    </item>''',
      ).join();
      final service = NewsService(
        client: MockClient(
          (_) async => http.Response(
            '<rss version="2.0"><channel>$items</channel></rss>',
            200,
          ),
        ),
      );

      final articles = await service.fetchSourceNews(
        NewsRssSource(
          name: 'Feed lungo',
          uri: Uri.parse('https://example.com/feed.xml'),
        ),
      );

      expect(articles, hasLength(75));
    });

    test('keeps RSS article ids stable when the feed order changes', () async {
      var reversed = false;
      String item(String guid, String title) => '''
    <item>
      <guid>$guid</guid>
      <title>$title</title>
      <link>https://example.com/$guid</link>
    </item>''';
      final service = NewsService(
        client: MockClient((_) async {
          var entries = [
            item('guid-a', 'Notizia A'),
            item('guid-b', 'Notizia B')
          ];
          if (reversed) entries = entries.reversed.toList();
          return http.Response(
            '<rss version="2.0"><channel>${entries.join()}</channel></rss>',
            200,
          );
        }),
      );
      final source = NewsRssSource(
        name: 'Feed stabile',
        uri: Uri.parse('https://example.com/feed.xml'),
      );

      final first = await service.fetchSourceNews(source);
      reversed = true;
      final second = await service.fetchSourceNews(source);

      final firstIdsByTitle = {
        for (final article in first) article.title: article.id
      };
      final secondIdsByTitle = {
        for (final article in second) article.title: article.id
      };
      expect(secondIdsByTitle, firstIdsByTitle);
      expect(firstIdsByTitle['Notizia A'], 'Feed stabile|guid-a');
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

    test('parses RSS content encoded fallback used by Vox-style feeds',
        () async {
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

    test('falls back to localized Google News on RSS 404 and remembers it for the session', () async {
      var primaryRequests = 0;
      var googleRequests = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'news.google.com') {
          googleRequests++;
          expect(request.url.queryParameters['q'], 'site:testata.it');
          expect(request.url.queryParameters['hl'], 'it');
          expect(request.url.queryParameters['gl'], 'IT');
          expect(request.url.queryParameters['ceid'], 'IT:it');
          return http.Response(
            '''
<rss version="2.0"><channel><item>
<title>Articolo di fallback</title>
<link>https://www.testata.it/articolo</link>
<pubDate>Thu, 28 May 2026 08:30:00 GMT</pubDate>
</item></channel></rss>
''',
            200,
          );
        }
        primaryRequests++;
        return http.Response('not found', 404);
      });
      final service = NewsService(client: client);
      final source = NewsRssSource(
        name: 'Testata',
        uri: Uri.parse('https://www.testata.it/rss.xml'),
      );

      final first = await service.fetchSourceNews(
        source,
        language: NewsLanguage.italian,
      );
      // La memoria è statica e quindi vale anche se la schermata ricrea il
      // NewsService durante la stessa sessione dell'app.
      final secondService = NewsService(client: client);
      final second = await secondService.fetchSourceNews(
        source,
        language: NewsLanguage.italian,
      );

      expect(first.single.title, 'Articolo di fallback');
      expect(second.single.title, 'Articolo di fallback');
      expect(primaryRequests, 1);
      expect(googleRequests, 2);
    });

    test('falls back to Google News when the primary feed contains no articles', () async {
      final requested = <Uri>[];
      final service = NewsService(
        client: MockClient((request) async {
          requested.add(request.url);
          if (request.url.host == 'news.google.com') {
            return http.Response(
              '<rss version="2.0"><channel><item><title>Fallback</title>'
              '<link>https://example.fr/story</link></item></channel></rss>',
              200,
            );
          }
          return http.Response('<rss version="2.0"><channel></channel></rss>', 200);
        }),
      );

      final articles = await service.fetchSourceNews(
        NewsRssSource(
          name: 'Journal Exemple',
          uri: Uri.parse('https://www.example.fr/rss.xml'),
        ),
        language: NewsLanguage.french,
      );

      expect(articles.single.title, 'Fallback');
      expect(requested, hasLength(2));
      expect(requested.last.queryParameters['hl'], 'fr');
      expect(requested.last.queryParameters['gl'], 'FR');
      expect(requested.last.queryParameters['ceid'], 'FR:fr');
    });

    test('uses German Google News locale for German source fallback', () async {
      final requested = <Uri>[];
      final service = NewsService(
        client: MockClient((request) async {
          requested.add(request.url);
          if (request.url.host == 'news.google.com') {
            return http.Response(
              '<rss version="2.0"><channel><item><title>Ersatzartikel</title>'
              '<link>https://beispiel.de/artikel</link></item></channel></rss>',
              200,
            );
          }
          return http.Response('kaputt', 500);
        }),
      );

      final articles = await service.fetchSourceNews(
        NewsRssSource(
          name: 'Beispiel Zeitung',
          uri: Uri.parse('https://www.beispiel.de/rss.xml'),
        ),
        language: NewsLanguage.german,
      );

      expect(articles.single.title, 'Ersatzartikel');
      final fallback = requested.last;
      expect(fallback.queryParameters['q'], 'site:beispiel.de');
      expect(fallback.queryParameters['hl'], 'de');
      expect(fallback.queryParameters['gl'], 'DE');
      expect(fallback.queryParameters['ceid'], 'DE:de');
    });

    test('every built-in non-Google feed can build a localized Google News fallback', () async {
      for (final language in NewsLanguage.values) {
        for (final source in language.rssSources) {
          if (source.uri.host == 'news.google.com' || source.isFolder) continue;
          NewsService.resetNewsSourceFallbacksForTests();
          final requested = <Uri>[];
          final service = NewsService(
            client: MockClient((request) async {
              requested.add(request.url);
              if (request.url.host == 'news.google.com') {
                return http.Response(
                  '<rss version="2.0"><channel><item><title>Fallback</title>'
                  '<link>https://example.com/story</link></item></channel></rss>',
                  200,
                );
              }
              return http.Response('primary failed', 503);
            }),
          );

          final articles = await service.fetchSourceNews(
            source,
            language: language,
          );

          expect(articles, isNotEmpty, reason: source.name);
          expect(requested, hasLength(2), reason: source.name);
          expect(requested.last.host, 'news.google.com', reason: source.name);
          expect(
            requested.last.queryParameters['hl'],
            language.code,
            reason: source.name,
          );
        }
      }
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

    test(
        'in fallback-only non chiama Tinyfish prima che la WebView venga provata',
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
                'tinyfish_fallback_only': true,
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(request.url.host, 'example.com');
          return http.Response(
            '''
<!doctype html>
<html>
  <body>
    <article>
      <p>Testo recuperato direttamente dal reader locale senza coinvolgere Tinyfish prima della WebView.</p>
      <p>Un secondo paragrafo rende il contenuto abbastanza lungo da essere utilizzabile nella schermata notizie.</p>
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
          id: '3',
          title: 'Reader prima della WebView',
          link: 'https://example.com/reader-first',
          summary: 'Riassunto RSS',
          source: 'Test',
          publishedAt: null,
        ),
        language: NewsLanguage.italian,
      );

      expect(requested.map((uri) => uri.host), [
        'sonarpad.com',
        'example.com',
      ]);
      expect(
        requested.where((uri) =>
            uri.host == 'sonarpad.com' &&
            uri.queryParameters.containsKey('url')),
        isEmpty,
      );
      expect(content.text, contains('reader locale'));
    });

    test(
        'reader locale rispetta il charset ISO-8859-1 degli articoli HTML',
        () async {
      final service = NewsService(
        client: MockClient((request) async {
          if (request.url.host == 'sonarpad.com' &&
              request.url.queryParameters['policy'] == '1') {
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'ok': true,
                'tinyfish_fallback_only': true,
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }

          const html = '''
<!doctype html>
<html>
  <head><meta charset="ISO-8859-1"><title>Adobe</title></head>
  <body>
    <article>
      <p>La modalità si attiva da un interruttore e si può nascondere senza perdere le impostazioni già scelte.</p>
      <p>Dentro, il ritocco passa dai prompt e dalle annotazioni disegnate sull'immagine, così l'utente può lavorare più rapidamente.</p>
    </article>
  </body>
</html>
''';
          return http.Response.bytes(
            latin1.encode(html),
            200,
            headers: {'content-type': 'text/html; charset=ISO-8859-1'},
          );
        }),
      );

      await service.loadTinyfishFallbackOnlyPolicyForSession();
      final content = await service.fetchArticleContent(
        const NewsArticle(
          id: 'charset-article',
          title: 'Adobe',
          link: 'https://www.fotografidigitali.it/news/example.html',
          summary: 'Riassunto RSS',
          source: 'Fotografi Digitali',
          publishedAt: null,
        ),
        language: NewsLanguage.italian,
      );

      expect(content.text, contains('modalità'));
      expect(content.text, contains('si può nascondere'));
      expect(content.text, contains('già scelte'));
      expect(content.text, isNot(contains('�')));
    });

    test(
        'reader locale usa il meta charset Windows-1252 quando manca nel Content-Type',
        () async {
      final service = NewsService(
        client: MockClient((request) async {
          if (request.url.host == 'sonarpad.com' &&
              request.url.queryParameters['policy'] == '1') {
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'ok': true,
                'tinyfish_fallback_only': true,
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }

          final asciiPrefix = ascii.encode('''
<!doctype html><html><head><meta charset="windows-1252"></head><body><article><p>''');
          final body = <int>[
            ...asciiPrefix,
            ...latin1.encode(
              'La modalità opzionale può essere nascosta. Un secondo periodo abbastanza lungo mantiene valido il contenuto del reader.',
            ),
            0x93,
            ...latin1.encode('Prompt e annotazioni'),
            0x94,
            ...ascii.encode('</p></article></body></html>'),
          ];
          return http.Response.bytes(
            body,
            200,
            headers: {'content-type': 'text/html'},
          );
        }),
      );

      await service.loadTinyfishFallbackOnlyPolicyForSession();
      final content = await service.fetchArticleContent(
        const NewsArticle(
          id: 'meta-charset-article',
          title: 'Adobe',
          link: 'https://www.fotografidigitali.it/news/example-meta.html',
          summary: 'Riassunto RSS',
          source: 'Fotografi Digitali',
          publishedAt: null,
        ),
        language: NewsLanguage.italian,
      );

      expect(content.text, contains('modalità opzionale'));
      expect(content.text, contains('può essere nascosta'));
      expect(content.text, contains('“Prompt e annotazioni”'));
      expect(content.text, isNot(contains('�')));
    });

    test('esegue Tinyfish con fallback=1 solo su richiesta dopo la WebView',
        () async {
      final requested = <Uri>[];
      final service = NewsService(
        client: MockClient((request) async {
          requested.add(request.url);
          if (request.url.queryParameters['policy'] == '1') {
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'ok': true,
                'tinyfish_fallback_only': true,
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(request.url.host, 'sonarpad.com');
          expect(request.url.queryParameters['fallback'], '1');
          expect(
            request.url.queryParameters['url'],
            'https://example.com/final-story',
          );
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'ok': true,
              'url': 'https://example.com/final-story',
              'final_url': 'https://example.com/final-story',
              'format': 'markdown',
              'markdown': '''
# Articolo recuperato

Questo contenuto viene restituito da Tinyfish soltanto dopo il fallimento del reader HTTP e dei tentativi eseguiti nella WebView.

Il secondo paragrafo conferma che il testo è abbastanza lungo da essere accettato come ultimo fallback.
''',
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await service.loadTinyfishFallbackOnlyPolicyForSession();
      final content = await service.fetchArticleContentTinyfishFallback(
        const NewsArticle(
          id: '4',
          title: 'Articolo recuperato',
          link: 'https://news.google.com/rss/articles/example',
          summary: 'Riassunto RSS',
          source: 'Test',
          publishedAt: null,
        ),
        preferredUrl: 'https://example.com/final-story',
      );

      expect(requested, hasLength(2));
      expect(content, isNotNull);
      expect(content!.text, contains('ultimo fallback'));
    });

    test('non ripete Tinyfish dopo la WebView in modalità Tinyfish-first',
        () async {
      final requested = <Uri>[];
      final service = NewsService(
        client: MockClient((request) async {
          requested.add(request.url);
          expect(request.url.queryParameters['policy'], '1');
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'ok': true,
              'tinyfish_fallback_only': false,
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await service.loadTinyfishFallbackOnlyPolicyForSession();
      final content = await service.fetchArticleContentTinyfishFallback(
        const NewsArticle(
          id: '5',
          title: 'Nessun doppio tentativo',
          link: 'https://example.com/story',
          summary: 'Riassunto RSS',
          source: 'Test',
          publishedAt: null,
        ),
        preferredUrl: 'https://example.com/story',
      );

      expect(content, isNull);
      expect(requested, hasLength(1));
    });
  });
}
