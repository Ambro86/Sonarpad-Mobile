import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/wikipedia_service.dart';

Future<WikipediaArticle> importHtml(String html) => WikipediaService(
  client: MockClient(
    (_) async => http.Response(
      jsonEncode({
        'parse': {'title': 'Example', 'text': html},
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
).importArticle(1);

void main() {
  for (final layout in ['legacy', 'wrapped', 'parsoid', 'fragment']) {
    test('preserves section boundaries and nested sections: $layout', () async {
      const intro = '<p>Introduction.</p>';
      const biography = '<h2>Biography</h2><p>Life story.</p>';
      const thought = '<h2>Thought</h2><p>Ideas.</p>';
      const detail = '<h3>Details</h3><p>Specific ideas.</p>';
      const works = '<h2>Works</h2><ul><li>First book.</li></ul>';
      final html = switch (layout) {
        'parsoid' =>
          '<div class="mw-parser-output">'
              '<section data-mw-section-id="0">$intro</section>'
              '<section data-mw-section-id="1">$biography</section>'
              '<section data-mw-section-id="2">$thought'
              '<section data-mw-section-id="3">$detail</section></section>'
              '<section data-mw-section-id="4">$works</section></div>',
        'wrapped' =>
          '<div class="mw-parser-output"><div>$intro'
              '<div class="mw-heading mw-heading2"><h2>Biography</h2>'
              '<span class="mw-editsection">edit</span></div>'
              '<p>Life story.</p>$thought$detail$works</div></div>',
        'fragment' => '$intro$biography$thought$detail$works',
        _ =>
          '<div class="mw-parser-output">$intro$biography$thought$detail$works</div>',
      };
      final article = await importHtml(html);
      expect(article.sections.map((s) => s.title), [
        'Biography',
        'Thought',
        'Details',
        'Works',
      ]);
      expect(article.sections.map((s) => s.level), [2, 2, 3, 2]);
      expect(article.sections[0].text, contains('Life story.'));
      expect(article.sections[0].text, isNot(contains('Ideas.')));
      expect(article.sections[1].text, contains('Specific ideas.'));
      expect(article.sections[1].text, isNot(contains('First book.')));
      expect(article.text, contains('Introduction.'));
      expect(article.text, isNot(contains('edit')));
    });
  }

  test('keeps unsectioned content while discarding template noise', () async {
    final article = await importHtml(
      '<div class="mw-parser-output">'
      '<section><p>A <b>complete</b> introduction.</p>'
      '<div class="navbox"><h2>Navigation</h2>Noise</div>'
      '<table><tr><td>Table noise</td></tr></table>'
      '<p>Last paragraph.</p></section></div>',
    );
    expect(article.sections, isEmpty);
    expect(article.text, contains('A complete introduction.'));
    expect(article.text, contains('Last paragraph.'));
    expect(article.text, isNot(contains('noise')));
    expect(article.text, isNot(contains('Navigation')));
  });

  const fixture = String.fromEnvironment('WIKIPEDIA_LIVE_FIXTURE');
  if (fixture.isNotEmpty) {
    test(
      'imports sections from the real Augusto Del Noce API response',
      () async {
        final raw = File(fixture).readAsStringSync();
        final article = await WikipediaService(
          client: MockClient(
            (_) async => http.Response(
              raw,
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ).importArticle(393319);
        expect(article.title, 'Augusto Del Noce');
        expect(
          article.sections.map((s) => s.title),
          containsAll(['Biografia', 'Il pensiero', 'Opere']),
        );
        expect(
          article.sections.firstWhere((s) => s.title == 'Biografia').text,
          isNot(contains('== Opere ==')),
        );
        printOnFailure(
          'Real API response: ${article.sections.length} sections: '
          '${article.sections.map((s) => s.title).join(', ')}',
        );
      },
    );
  }
}
