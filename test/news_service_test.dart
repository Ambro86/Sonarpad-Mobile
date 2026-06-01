import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/english_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/french_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/italian_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/spanish_news_sources.dart';

void main() {
  group('NewsService', () {
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
        'https://news.google.com/rss/search?q=site%3Ainternazionale.it&hl=it&gl=IT&ceid=IT:it',
      );
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
  });
}
