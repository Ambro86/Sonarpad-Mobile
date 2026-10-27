import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/google_news_feed.dart';

void main() {
  const cases = [
    (
      'BR:pt-419',
      'NATION',
      'CAAqJQgKIh9DQkFTRVFvSUwyMHZNREUxWm5JU0JYQjBMVUpTS0FBUAE',
    ),
    (
      'BR:pt-419',
      'TECHNOLOGY',
      'CAAqLAgKIiZDQkFTRmdvSkwyMHZNR1ptZHpWbUVnVndkQzFDVWhvQ1FsSW9BQVAB',
    ),
    ('CZ:cs', 'NATION', 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNREZ0YW5FU0FtTnpLQUFQAQ'),
    (
      'CZ:cs',
      'TECHNOLOGY',
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSmpjeG9DUTFvb0FBUAE',
    ),
    ('US:en', 'NATION', 'CAAqIggKIhxDQkFTRHdvSkwyMHZNRGxqTjNjd0VnSmxiaWdBUAE'),
    ('FR:fr', 'NATION', 'CAAqIggKIhxDQkFTRHdvSkwyMHZNR1k0YkRsakVnSm1jaWdBUAE'),
    (
      'FR:fr',
      'TECHNOLOGY',
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSm1jaG9DUmxJb0FBUAE',
    ),
    ('DE:de', 'NATION', 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRE0wTldnU0FtUmxLQUFQAQ'),
    (
      'DE:de',
      'TECHNOLOGY',
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSmtaUm9DUkVVb0FBUAE',
    ),
    ('IT:it', 'NATION', 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRE55YW1vU0FtbDBLQUFQAQ'),
    (
      'IT:it',
      'TECHNOLOGY',
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSnBkQm9DU1ZRb0FBUAE',
    ),
    ('PL:pl', 'NATION', 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRFZ4YUhjU0FuQnNLQUFQAQ'),
    (
      'PL:pl',
      'TECHNOLOGY',
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSndiQm9DVUV3b0FBUAE',
    ),
    (
      'PT:pt-150',
      'NATION',
      'CAAqJQgKIh9DQkFTRVFvSUwyMHZNRFZ5TkhjU0JYQjBMVkJVS0FBUAE',
    ),
    (
      'PT:pt-150',
      'TECHNOLOGY',
      'CAAqLAgKIiZDQkFTRmdvSkwyMHZNR1ptZHpWbUVnVndkQzFRVkJvQ1VGUW9BQVAB',
    ),
    ('RO:ro', 'NATION', 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRFpqTVhrU0FuSnZLQUFQAQ'),
    (
      'CN:zh-Hans',
      'NATION',
      'CAAqJggKIiBDQkFTRWdvSkwyMHZNR1F3TlhjekVnVjZhQzFEVGlnQVAB',
    ),
    ('ES:es', 'NATION', 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRFp0YTJvU0FtVnpLQUFQAQ'),
    (
      'ES:es',
      'TECHNOLOGY',
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSmxjeG9DUlZNb0FBUAE',
    ),
    ('TR:tr', 'NATION', 'CAAqIggKIhxDQkFTRHdvSkwyMHZNREY2Ym1OZkVnSjBjaWdBUAE'),
    (
      'TR:tr',
      'TECHNOLOGY',
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSjBjaG9DVkZJb0FBUAE',
    ),
    ('UA:uk', 'NATION', 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRGQwTWpFU0FuVnJLQUFQAQ'),
    (
      'UA:uk',
      'TECHNOLOGY',
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSjFheG9DVlVFb0FBUAE',
    ),
  ];
  test('verified category editions preserve locale and unknown parameters', () {
    for (final (edition, topic, id) in cases) {
      for (final prefix in [
        '/news/rss/headlines/section/topic/',
        '/rss/headlines/section/topic/',
      ]) {
        final input = Uri.parse(
          'https://news.google.com$prefix$topic?ceid=$edition&hl=it&gl=IT&extra=keep%20me',
        );
        final output = normalizeGoogleNewsCategoryUri(input);
        expect(output.path, '/rss/topics/$id');
        expect(output.query, input.query);
        expect(normalizeGoogleNewsCategoryUri(output), output);
      }
    }
  });
  test('unrelated categories, editions and publishers stay unchanged', () {
    for (final url in [
      'https://news.google.com/rss/headlines/section/topic/TECHNOLOGY?ceid=US:en',
      'https://news.google.com/rss/headlines/section/topic/TECHNOLOGY?ceid=RO:ro',
      'https://news.google.com/rss/headlines/section/topic/NATION?ceid=XX:xx',
      'https://news.google.com/rss/headlines/section/topic/WORLD?ceid=IT:it',
      'https://news.google.com/rss/search?q=Roma&ceid=IT:it',
      'https://example.com/rss/headlines/section/topic/NATION?ceid=IT:it',
    ]) {
      final uri = Uri.parse(url);
      expect(normalizeGoogleNewsCategoryUri(uri), uri);
    }
  });
  test(
    'saved legacy source is normalized before the actual HTTP request',
    () async {
      final (_, _, id) = cases.firstWhere(
        (row) => row.$1 == 'IT:it' && row.$2 == 'TECHNOLOGY',
      );
      var requests = 0;
      final service = NewsService(
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/rss/topics/$id');
          expect(request.url.queryParameters['ceid'], 'IT:it');
          return http.Response(
            '<rss version="2.0"><channel><item><title>Science</title><link>https://example.org/story</link></item></channel></rss>',
            200,
          );
        }),
      );
      final result = await service.fetchSourceNews(
        NewsRssSource(
          name: 'Saved',
          uri: Uri.parse(
            'https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=it&gl=IT&ceid=IT:it',
          ),
          isCustom: true,
        ),
        language: NewsLanguage.italian,
      );
      expect(requests, 1);
      expect(result.single.title, 'Science');
    },
  );
}
