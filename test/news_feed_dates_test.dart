import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('RSS offsets represent the actual instant across midnight', () {
    expect(
      HttpDate.parse('Mon, 19 Oct 2026 20:09:00 +0300'),
      DateTime.utc(2026, 10, 19, 17, 9),
    );
    expect(
      HttpDate.parse('Tue, 20 Oct 2026 02:30:00 +0300'),
      DateTime.utc(2026, 10, 19, 23, 30),
    );
    expect(
      HttpDate.parse('Mon, 19 Oct 2026 20:09:00 -0430'),
      DateTime.utc(2026, 10, 20, 0, 39),
    );
    expect(
      HttpDate.parse('Mon, 19 Oct 2026 20:09:00 GMT'),
      DateTime.utc(2026, 10, 19, 20, 9),
    );
    expect(
      HttpDate.parse('Mon, 19 Oct 2026 20:09:00 EST'),
      DateTime.utc(2026, 10, 20, 1, 9),
    );
    expect(
      HttpDate.parse('Sal, 20 Eki 2026 02:30:00 +03:00'),
      DateTime.utc(2026, 10, 19, 23, 30),
    );
    expect(
      () => HttpDate.parse('Mon, 32 Oct 2026 20:09:00 +0300'),
      throwsFormatException,
    );
    expect(
      () => HttpDate.parse('Mon, 19 Oct 2026 20:09:00 UNKNOWN'),
      throwsFormatException,
    );
  });
  test('HTML articles never acquire refresh time as publication time', () async {
    final service = NewsService(
      client: MockClient(
        (_) async => http.Response(
          '<html><body><a href="/article">A sufficiently long article title without a publication date</a></body></html>',
          200,
        ),
      ),
    );
    final source = NewsRssSource(
      name: 'Example',
      uri: Uri.parse('https://example.org'),
    );
    final first = await service.fetchSourceNews(source);
    final second = await service.fetchSourceNews(source);
    expect(first, hasLength(1));
    expect(first.single.publishedAt, isNull);
    expect(second.single.publishedAt, isNull);
    expect(first.single.id, second.single.id);
  });
  test('saved obsolete feeds and website URLs use the verified feeds', () async {
    final targets = {
      'https://www.turkiyegazetesi.com.tr/rss/son-dakika-haberleri':
          'https://www.turkiyegazetesi.com.tr/rss',
      'https://www.tgrthaber.com/rss/son-dakika':
          'https://www.tgrthaber.com/rss/manset',
      'https://www.aa.com.tr/tr':
          'https://www.aa.com.tr/tr/rss/default?cat=guncel',
    };
    for (final entry in targets.entries) {
      final requested = <Uri>[];
      final service = NewsService(
        client: MockClient((request) async {
          requested.add(request.url);
          return http.Response(
            '<rss><channel><item><title>Recent</title><link>https://example.org/a</link><pubDate>Tue, 20 Oct 2026 02:30:00 +0300</pubDate></item></channel></rss>',
            200,
          );
        }),
      );
      final articles = await service.fetchSourceNews(
        NewsRssSource(name: 'Example', uri: Uri.parse(entry.key)),
      );
      expect(requested, [Uri.parse(entry.value)]);
      expect(articles.single.publishedAt, DateTime.utc(2026, 10, 19, 23, 30));
    }
  });
}
