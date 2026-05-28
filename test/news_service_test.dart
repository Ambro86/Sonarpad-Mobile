import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/italian_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';

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
  });
}
