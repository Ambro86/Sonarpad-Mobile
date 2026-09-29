import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/home_customization_service.dart';
import 'package:sonarpad_mobile_starter/services/treccani_service.dart';
import 'package:sonarpad_mobile_starter/utils/home_item_catalog.dart';

void main() {
  test('Treccani is exposed only to the Italian home catalog', () {
    final italian = availableHomeItemIds(
      isItalian: true,
      isTvCodeValid: false,
      isRaiPlayValid: false,
      isRaiPlaySoundCodeValid: false,
    );
    final nonItalian = availableHomeItemIds(
      isItalian: false,
      isTvCodeValid: false,
      isRaiPlayValid: false,
      isRaiPlaySoundCodeValid: false,
    );
    expect(italian, contains(HomeItemIds.treccani));
    expect(nonItalian, isNot(contains(HomeItemIds.treccani)));
  });

  test('mobile route keeps the Italian-only Treccani guard', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains("'/treccani': (context) =>"));
    expect(main, contains('italianOnlyRoute(context, const TreccaniScreen())'));
  });

  test('Treccani search keeps only encyclopedia results', () {
    const html = '''
      <html><body><script type="application/json">
      {"props":{"pageProps":{"data":{"matches":[
        {"title":"Enciclopedia","url":"/enciclopedia/enciclopedia/","section":"enciclopedia","description":"Enciclopedia on line"},
        {"title":"Enciclopedia","url":"/vocabolario/enciclopedia/","section":"vocabolario","description":"Vocabolario"}
      ]}}}}
      </script></body></html>
    ''';
    final results = TreccaniService.parseSearchHtml(html);
    expect(results, hasLength(1));
    expect(results.single.title, 'Enciclopedia');
    expect(results.single.url, contains('/enciclopedia/enciclopedia/'));
  });

  test('Treccani parser keeps sections and skips the index', () {
    const html = '''
      <html><body><main>
        <h1>Enciclopedia</h1>
        <p>Enciclopedia on line</p>
        <div><p>Indice</p><ul><li>Storia</li><li>Opere</li></ul></div>
        <p>Introduzione dell'articolo.</p>
        <h2>Storia</h2><p>Testo della storia.</p>
        <h3>Origini</h3><p>Testo delle origini.</p>
        <h2>Opere</h2><p>Testo delle opere.</p>
        <footer><p>© Istituto della Enciclopedia Italiana - Riproduzione riservata</p></footer>
      </main></body></html>
    ''';
    final article = TreccaniService.parseArticleHtml(
      html,
      url: 'https://www.treccani.it/enciclopedia/enciclopedia/',
    );
    expect(article.text, contains('== Storia =='));
    expect(article.text, contains('=== Origini ==='));
    expect(article.text, isNot(contains('- Storia')));
    expect(article.sections, hasLength(3));
    expect(article.sections.first.text, contains('=== Origini ==='));
  });

  test('Treccani parser selects article body from a later container', () {
    const html = '''
      <html><body>
        <main>
          <h1>Chimica</h1>
          <h5>Enciclopedia on line</h5>
          <p>Indice</p>
          <ul><li>1 Storia</li><li>2 Le origini</li></ul>
          <p>TAG</p>
          <p>Risonanza magnetica nucleare</p>
        </main>
        <article>
          <div><p>Scienza che studia le proprietà, la composizione e il modo di reagire delle sostanze naturali e artificiali.</p></div>
          <div><h2>Storia</h2><p>La nascita della chimica si fa risalire alla seconda metà del diciottesimo secolo, quando si svilupparono le sue basi sperimentali.</p></div>
          <div><h2>Le origini</h2><p>Le prime conoscenze chimiche furono legate allo sviluppo delle capacità tecniche dei popoli antichi.</p></div>
        </article>
      </body></html>
    ''';
    final article = TreccaniService.parseArticleHtml(
      html,
      url: 'https://www.treccani.it/enciclopedia/chimica/',
    );
    expect(article.text, contains('Scienza che studia le proprietà'));
    expect(article.text, contains('La nascita della chimica'));
    expect(article.text, isNot(contains('Risonanza magnetica nucleare')));
    expect(article.sections, hasLength(2));
  });

  test('Treccani parser recognizes legacy smallcaps headings', () {
    const html = '''
      <html><body>
        <h1>Autorita</h1>
        <h6>di Augusto Del Noce</h6>
        <h5>Enciclopedia del Novecento (1975)</h5>
        <div><p><style>.css-author{font-weight:400}</style>di <em>Augusto Del Noce</em></p></div>
        <div><p><span class="tc-smallcaps">sommario</span>: 1. Eclissi dell'idea di autorità. 2. Autorità e potere. □ Bibliografia.</p></div>
        <div><p>1. <span class="tc-smallcaps">Eclissi dell'idea di autorità</span></p></div>
        <div><p>Primo paragrafo sostanziale dedicato all'eclissi dell'autorità nel mondo contemporaneo e alle sue conseguenze.</p></div>
        <div><p>2. <span class="tc-smallcaps">Autorità e potere</span></p></div>
        <div><p>Secondo paragrafo sostanziale che distingue attentamente il concetto di autorità da quello differente di potere.</p></div>
        <div><p><span class="tc-smallcaps">bibliografia</span></p></div>
        <div><p>AA. VV., Coscienza, legge, autorità, Brescia 1970.</p></div>
      </body></html>
    ''';
    final article = TreccaniService.parseArticleHtml(
      html,
      url: 'https://www.treccani.it/enciclopedia/autorita/',
    );
    expect(article.text, isNot(contains('.css-author')));
    expect(article.text, contains("== 1. Eclissi dell'idea di autorità =="));
    expect(article.text, contains('== 2. Autorità e potere =='));
    expect(article.text, contains('== Bibliografia =='));
    expect(
      article.sections.map((section) => section.title),
      [
        "1. Eclissi dell'idea di autorità",
        '2. Autorità e potere',
        'Bibliografia',
      ],
    );
  });
}
