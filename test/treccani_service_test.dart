import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/treccani_service.dart';

void main() {
  // Remaining offline scenarios from Windows src/treccani.rs.
  test('short entry without sections', () {
    final article = TreccaniService.parseArticleHtml('''
      <main><h1>Query</h1><p>Enciclopedia della Matematica</p>
      <p>Query in informatica, istruzione che permette l'accesso ai dati.</p>
      <p>Un secondo paragrafo.</p></main>
    ''', url: 'https://www.treccani.it/enciclopedia/query/');
    expect(article.text, contains('Query in informatica'));
    expect(article.text, contains('Un secondo paragrafo.'));
    expect(article.sections, isEmpty);
  });

  test('document fallback reads body in plain divs', () {
    final article = TreccaniService.parseArticleHtml('''
      <main><h1>Chimica</h1><p>Enciclopedia on line</p>
      <p>Indice</p><ul><li>1 Storia</li><li>2 Le origini</li></ul>
      <p>TAG</p><ul><li>Risonanza magnetica nucleare</li>
      <li>Rivoluzione industriale</li></ul><p>Lemmi correlati</p></main>
      <div class="paywall term-paragraph0"><p>Scienza che studia le proprietà,
      la composizione, l’identificazione, la preparazione e il modo di reagire
      delle sostanze naturali e artificiali.</p></div>
      <div class="paywall term-paragraph1"><h2>Storia</h2><p>La nascita della
      chimica si fa in genere risalire alla seconda metà del diciottesimo secolo,
      quando si svilupparono le basi sperimentali e teoriche della scienza moderna.</p></div>
      <div class="paywall term-paragraph2"><h2>Le origini</h2><p>Le prime conoscenze
      chimiche nacquero insieme alle capacità tecniche dei popoli antichi e alla
      lavorazione dei metalli, del vetro e dei coloranti.</p></div>
    ''', url: 'https://www.treccani.it/enciclopedia/chimica/');
    expect(article.text, contains('Scienza che studia le proprietà'));
    expect(article.text, contains('La nascita della chimica'));
    expect(article.text, isNot(contains('Risonanza magnetica nucleare')));
    expect(article.text, isNot(contains('Rivoluzione industriale')));
    expect(article.sections, hasLength(2));
  });

  test('search falls back to article links and rejects invalid URLs', () {
    final results = TreccaniService.parseSearchHtml('''
      <main><a href="https://example.com/enciclopedia/test/">External</a>
      <a href="/enciclopedia/ricerca/test/">Search</a>
      <a href="/enciclopedia/filosofia/">Filosofia</a>
      <a href="/vocabolario/filosofia/">Filosofia nel vocabolario</a></main>
    ''');
    expect(results, hasLength(1));
    expect(results.single.title, 'Filosofia');
  });

  test(
    'search to Autorita load preserves URL case and legacy sections',
    () async {
      const path = '/enciclopedia/autorita_(Enciclopedia-del-Novecento)';
      final requested = <Uri>[];
      final client = MockClient((request) async {
        requested.add(request.url);
        if (request.url.path.contains('/ricerca/')) {
          return http.Response('''<script type="application/json">
          {"matches":[{"title":"Autorita","url":"$path","section":"enciclopedia"}]}
        </script>''', 200);
        }
        return http.Response.bytes(
          utf8.encode('''
        <h1>Autorità</h1><h6>di Augusto Del Noce</h6>
        <h5>Enciclopedia del Novecento (1975)</h5>
        <p>1. <span class="tc-smallcaps">Autorità e potere</span></p>
        <p>Testo dell’autorità, con caratteri accentati.</p>
        <p><span class="tc-smallcaps">bibliografia</span></p><p>Fonti.</p>
      '''),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final service = TreccaniService(client: client);
      final results = await service.search('del noce');
      final article = await service.loadArticle(results.single);
      expect(requested.first.path, '/enciclopedia/ricerca/del%20noce/');
      expect(requested.last.path, path);
      expect(article.title, 'Autorità');
      expect(article.text, contains('Testo dell’autorità'));
      expect(article.sections.map((s) => s.title), [
        '1. Autorità e potere',
        'Bibliografia',
      ]);
    },
  );

  test('HTTP errors retain status for diagnostics', () async {
    final client = MockClient((_) async => http.Response('', 503));
    addTearDown(client.close);
    final service = TreccaniService(client: client);
    const result = TreccaniSearchResult(
      title: 'Autorita',
      url: '/enciclopedia/autorita/',
      description: '',
    );
    final matcher = isA<TreccaniServiceException>()
        .having((e) => e.type, 'type', TreccaniErrorType.http)
        .having((e) => e.statusCode, 'status', 503)
        .having((e) => e.toString(), 'diagnostic', contains('HTTP 503'));
    await expectLater(service.search('del noce'), throwsA(matcher));
    await expectLater(service.loadArticle(result), throwsA(matcher));
  });

  test('invalid article URL is rejected before any request', () async {
    final client = MockClient(
      (_) async => throw StateError('Unexpected request'),
    );
    addTearDown(client.close);
    final service = TreccaniService(client: client);
    for (final url in [
      'https://example.com/enciclopedia/test/',
      '/enciclopedia/ricerca/test/',
    ]) {
      await expectLater(
        service.loadArticle(
          TreccaniSearchResult(title: 'Test', url: url, description: ''),
        ),
        throwsA(
          isA<TreccaniServiceException>().having(
            (e) => e.type,
            'type',
            TreccaniErrorType.invalidUrl,
          ),
        ),
      );
    }
  });
}
