import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/models/news_article.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';

void main() {
  test('RSS HTML description keeps supported media links', () async {
    const rss = r'''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"><channel><title>Test</title><item>
<title>Articolo</title>
<link>https://example.com/post/1</link>
<guid>1</guid>
<description>&lt;p&gt;Testo&lt;/p&gt;
&lt;a href="https://example.com/media/guida.pdf"&gt;Leggi la guida PDF&lt;/a&gt;
&lt;a href="https://example.com/media/guida.mp3"&gt;Ascolta la guida&lt;/a&gt;
&lt;a href="https://youtu.be/AZ18tWja3TU"&gt;Guarda il tutorial&lt;/a&gt;
&lt;a href="https://example.com/altro"&gt;Link normale&lt;/a&gt;
</description>
</item></channel></rss>''';
    final service = NewsService(
      client: MockClient((_) async => http.Response(rss, 200)),
    );
    final articles = await service.fetchSourceNews(
      NewsRssSource(
        name: 'Test',
        uri: Uri.parse('https://example.com/feed'),
        isCustom: true,
      ),
      language: NewsLanguage.italian,
    );

    expect(articles, hasLength(1));
    expect(articles.single.allowInternalMediaLinks, isTrue);
    final links = articles.single.mediaLinks;
    expect(links, hasLength(3));
    expect(links.map((link) => link.kind), [
      NewsArticleMediaKind.pdf,
      NewsArticleMediaKind.audio,
      NewsArticleMediaKind.youtube,
    ]);
    expect(links[0].label, 'Leggi la guida PDF');
    expect(links[1].label, 'Ascolta la guida');
    expect(links[2].label, 'Guarda il tutorial');
  });

  test('built-in and Google News sources never expose internal media buttons',
      () async {
    const rss = r'''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"><channel><title>Test</title><item>
<title>Articolo</title>
<link>https://example.com/post/1</link>
<guid>1</guid>
<description>&lt;a href="https://youtu.be/AZ18tWja3TU"&gt;Video&lt;/a&gt;
&lt;a href="https://example.com/file.mp3"&gt;Audio&lt;/a&gt;</description>
</item></channel></rss>''';
    final service = NewsService(
      client: MockClient((_) async => http.Response(rss, 200)),
    );

    final builtIn = await service.fetchSourceNews(
      NewsRssSource(name: 'Test', uri: Uri.parse('https://example.com/feed')),
      language: NewsLanguage.italian,
    );
    final googleNews = await service.fetchSourceNews(
      NewsRssSource(
        name: 'Google News',
        uri: Uri.parse('https://news.google.com/rss?hl=it&gl=IT&ceid=IT:it'),
      ),
      language: NewsLanguage.italian,
    );

    for (final article in [...builtIn, ...googleNews]) {
      expect(article.allowInternalMediaLinks, isFalse);
      expect(article.mediaLinks, isEmpty);
    }
  });

  test('media link classifier supports YouTube shorts and common audio', () {
    expect(
      NewsArticleMediaLink.tryParse('https://youtube.com/shorts/NCptDDj-EiI')
          ?.kind,
      NewsArticleMediaKind.youtube,
    );
    expect(
      NewsArticleMediaLink.tryParse('https://example.com/a/file.m4a?x=1')?.kind,
      NewsArticleMediaKind.audio,
    );
    expect(
      NewsArticleMediaLink.tryParse('https://example.com/file.pdf?download=1')
          ?.kind,
      NewsArticleMediaKind.pdf,
    );
  });
}
