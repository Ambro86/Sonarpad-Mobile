import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';

const landiniUrl =
    'https://www.repubblica.it/politica/2026/10/17/news/sciopero_generale_20_novembre_2026_cgil_landini-425655032/';
const unrelatedUrl =
    'https://www.repubblica.it/venerdi/2026/10/18/news/shaun_the_sheep_aardman_halloween_tempistiche_realizzazione_film-425652638/?ref=drrt-2';

void main() {
  test(
    'a related article URL is not mistaken for the selected article',
    () async {
      final service = NewsService(
        client: MockClient(
          (_) async => http.Response('''
      <div data-n-a-id="shaun-id" data-n-au="$unrelatedUrl"></div>
      <div data-n-a-id="landini-id" data-n-au="$landiniUrl"></div>
    ''', 200),
        ),
      );
      expect(
        await service.resolveArticleUrlForSharing(
          'https://news.google.com/rss/articles/landini-id',
        ),
        landiniUrl,
      );
    },
  );

  test(
    'a page containing only other article IDs keeps the original link',
    () async {
      const original = 'https://news.google.com/rss/articles/landini-id';
      final service = NewsService(
        client: MockClient(
          (_) async => http.Response('''
      <div data-n-a-id="shaun-id" data-n-au="$unrelatedUrl"></div>
    ''', 200),
        ),
      );
      expect(await service.resolveArticleUrlForSharing(original), original);
    },
  );

  for (final path in ['rss/articles', 'articles', 'read']) {
    test(
      'Google News $path resolves the requested article with one JSON encoding',
      () async {
        final googleUrl = 'https://news.google.com/$path/landini-id?oc=5';
        var postCount = 0;
        final service = NewsService(
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                '<script>var label="Full coverage";</script><div data-n-a-id="landini-id" data-n-a-ts="1792304002" data-n-a-sg="signature"></div>',
                200,
              );
            }
            postCount++;
            final form = Uri.splitQueryString(request.body);
            final batch = jsonDecode(form['f.req']!) as List;
            final rpc = batch.single.single as List;
            expect(rpc[0], 'Fbv4je');
            final payload = jsonDecode(rpc[1] as String);
            expect(
              payload,
              isA<List>(),
              reason: 'A second JSON string makes Google return a null result.',
            );
            expect(payload[0], 'garturlreq');
            expect(payload[2], 'landini-id');
            expect(payload[3], 1792304002);
            expect(payload[4], 'signature');
            return http.Response(
              ")]}'\n\n${jsonEncode([
                [
                  'wrb.fr',
                  'Fbv4je',
                  jsonEncode(['garturlres', landiniUrl, 1, '${landiniUrl}amp/']),
                  null,
                ],
              ])}",
              200,
            );
          }),
        );
        final resolved = await service.resolveArticleUrlForSharing(googleUrl);
        expect(resolved, landiniUrl);
        expect(resolved, isNot(unrelatedUrl));
        expect(postCount, 1);
      },
    );
  }

  test('failed decoding retains the original Google article link', () async {
    const original = 'https://news.google.com/rss/articles/landini-id';
    final service = NewsService(
      client: MockClient(
        (request) async => http.Response(
          request.method == 'GET'
              ? '<div data-n-a-ts="1" data-n-a-sg="signature"></div>'
              : ")]}'\n[[\"wrb.fr\",\"Fbv4je\",null,null,null,[3],\"\"]]",
          200,
        ),
      ),
    );
    expect(await service.resolveArticleUrlForSharing(original), original);
  });
}
