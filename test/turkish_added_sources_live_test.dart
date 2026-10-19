import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/turkish_news_sources.dart';

void main() {
  for (final host in [
    'www.edebiyathaber.net',
    'mebpersonel.com',
    'yasadikca.com',
  ]) {
    test(
      'Turkish source $host loads real articles through NewsService',
      () async {
        final source = turkishNewsSources.singleWhere(
          (s) => s.uri.host == host,
        );
        final network = http.Client();
        addTearDown(network.close);
        final service = NewsService(
          client: MockClient((request) async {
            expect(
              request.url.host,
              host,
              reason:
                  'The publisher feed must work without a Google News fallback',
            );
            return network.get(request.url, headers: request.headers);
          }),
        );
        final articles = await service.fetchSourceNews(
          source,
          language: NewsLanguage.turkish,
        );
        expect(articles.length, greaterThanOrEqualTo(5));
        for (final article in articles) {
          expect(article.title.trim(), isNotEmpty);
          expect(
            Uri.parse(article.link).host.replaceFirst('www.', ''),
            host.replaceFirst('www.', ''),
          );
        }
      },
      skip: !const bool.fromEnvironment('RUN_LIVE_TURKISH_ADDITIONS'),
    );
  }
}
