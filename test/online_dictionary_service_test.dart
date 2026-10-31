import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/online_dictionary_service.dart';

DictionaryEntry parse(
  String text, [
  String language = 'it',
  bool limited = false,
]) => WiktionaryParser.parse(
  text,
  word: 'test',
  language: language,
  limited: limited,
);

void main() {
  // Same 60 real entries and coverage as Windows' wiktionary.rs fixture test.
  final root = Directory('test/fixtures/wiktionary');
  final entries = File('${root.path}/index.csv')
      .readAsLinesSync()
      .skip(1)
      .where((line) => line.isNotEmpty)
      .map((line) => line.split(','))
      .toList();
  test(
    'all 60 Windows fixtures are present',
    () => expect(entries, hasLength(60)),
  );
  for (final entry in entries) {
    test(
      'Windows fixture ${entry[0]} ${entry[1]} produces clean definitions',
      () {
        final result = parse(
          File('${root.path}/${entry[2]}').readAsStringSync(),
          entry[0],
        );
        expect(result.definitions, isNotEmpty);
        for (final definition in result.definitions) {
          expect(
            definition,
            isNot(matches(r'\{\{|\}\}|\[\[|\]\]|<ref|File:|<!--')),
          );
          expect(
            definition,
            isNot(
              matches(r'^(?:w|m|f|n|sg|pl|it|en|es)(?:\s+(?:m|f|n|sg|pl))*$'),
            ),
          );
          expect(definition.runes.length, lessThanOrEqualTo(500));
        }
      },
    );
  }
  test('Italian grammar header, actual subpoints and synonyms', () {
    final entry = parse('''# {{Pn|w}} ''f sing''
#* [[edificio]] usato come [[abitazione]]
#** ''Questo è un esempio, non una definizione.''
#* dimora di una [[persona]]
{{-sin-}}
* [[abitazione]], [[dimora]]
{{-ant-}}
* niente''');
    expect(entry.definitions, [
      'edificio usato come abitazione',
      'dimora di una persona',
    ]);
    expect(entry.synonyms, ['abitazione, dimora']);
  });
  test('German numbered definitions, separate blocks and synonyms', () {
    final entry = parse('''{{Abkürzungen}}
:[1] not a definition
{{Bedeutungen}}
:[1] [[Gebäude]] zum [[Wohnen]]
:[2] eine [[Familie]]
{{Synonyme}}
:[1] [[Wohnhaus]], [[Wohngebäude]]
{{Bedeutungen}}:[3] weiteres [[Haus]]
{{Beispiele}}
:[1] not a definition''', 'de');
    expect(entry.definitions, [
      'Gebäude zum Wohnen',
      'eine Familie',
      'weiteres Haus',
    ]);
    expect(entry.synonyms, ['Wohnhaus, Wohngebäude']);
  });
  test(
    'German nested templates keep piped links intact (Windows regression)',
    () {
      expect(
        parse(
          '''{{Bedeutungen}}
:[1] {{K|ft=in den [[bergmännisch]]en [[Ausdruck|Ausdrücken]] „zu Tage“, „über Tage“ und „unter Tage“}} die [[Erdoberfläche]]''',
          'de',
        ).definitions,
        [
          'in den bergmännischen Ausdrücken „zu Tage“, „über Tage“ und „unter Tage“ die Erdoberfläche',
        ],
      );
    },
  );
  test('Spanish numbered senses, inline templates and reference blocks', () {
    expect(
      parse(
        ''';1: {{impropia|Expresión de [[saludo]] utilizada entre dos personas}}.
;2: Una [[casa]]<ref name="x">{{cita|Libro}} texto</ref> grande<ref name="x"/>.
;3: aguar.
;4: salva Pág. 775''',
        'es',
      ).definitions,
      ['Expresión de saludo utilizada entre dos personas.', 'Una casa grande.'],
    );
  });
  test('Windows noise regressions', () {
    final cases = {
      'it it Una definizione i': 'Una definizione',
      'Q235544The definition Q235544a': 'The definition',
      'Una definizione E82D14': 'Una definizione',
      'Una origine.2012-9-05': 'Una origine',
      'm f Una definizione': 'Una definizione',
      'ing-form': '',
      'inflection of': '',
      'it': '',
      'w f sg': '',
    };
    for (final e in cases.entries) {
      expect(WiktionaryParser.normalize(e.key), e.value, reason: e.key);
    }
  });
  test('formatting strips image captions, comments, HTML and external URLs', () {
    expect(
      WiktionaryParser.clean(
        "Una [[casa]] [[File:Casa.jpg|thumb|[[casa]] grande]] <!--nota--> <b>bella</b> &amp; [https://example.org una fonte]",
      ),
      'Una casa bella & una fonte',
    );
  });
  test('large entries bounded without cutting Unicode in half', () {
    final entry = parse(
      List.generate(10, (i) => '# ${'😀' * 510} definizione $i').join('\n'),
      'it',
      true,
    );
    expect(entry.definitions, hasLength(5));
    expect(entry.definitions.first.runes.length, 500);
    expect(entry.synonyms, isEmpty);
  });
  test('Spanish infinitive removed only in context', () {
    expect(
      parse('# amar\n# Sentir afecto por otra persona.', 'es').definitions,
      ['Sentir afecto por otra persona.'],
    );
    expect(parse('# amar', 'es').definitions, ['amar']);
  });
  test('malformed templates and links terminate without leaking templates', () {
    expect(WiktionaryParser.clean('Voce {{broken'), 'Voce');
    expect(WiktionaryParser.clean('Voce [[broken'), 'Voce [[broken');
  });
  test(
    'API uses encoded terms, canonical title, section one and Unicode',
    () async {
      final requests = <Uri>[];
      final service = OnlineDictionaryService(
        client: MockClient((request) async {
          requests.add(request.url);
          final data = requests.length == 1
              ? {
                  'query': {
                    'pages': [
                      {'title': 'città', 'length': 500},
                    ],
                  },
                }
              : {
                  'parse': {'wikitext': '# Una [[città]] italiana.'},
                };
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);
      final entry = await service.lookup(' Città & mondo ', language: 'it');
      expect(requests.first.queryParameters['titles'], 'Città & mondo');
      expect(requests.last.queryParameters['page'], 'città');
      expect(requests.last.queryParameters['section'], '1');
      expect(entry.definitions, ['Una città italiana.']);
      expect(entry.source.host, 'it.wiktionary.org');
    },
  );
  test(
    'missing word, HTTP failure and malformed data remain distinguishable',
    () async {
      for (final data in [
        ('{"query":{"pages":[{"missing":true}]}}', 200, 'not_found'),
        ('unavailable', 503, 'http_503'),
        ('{"error":{"code":"missingtitle"}}', 200, 'not_found'),
      ]) {
        final service = OnlineDictionaryService(
          client: MockClient((_) async => http.Response(data.$1, data.$2)),
        );
        await expectLater(
          service.lookup('casa'),
          throwsA(
            isA<DictionaryRequestException>().having(
              (e) => e.code,
              'code',
              data.$3,
            ),
          ),
        );
        service.close();
      }
    },
  );
  test('invalid language never makes a request', () async {
    final service = OnlineDictionaryService(
      client: MockClient((_) async => throw StateError('must not call')),
    );
    await expectLater(
      service.lookup('casa', language: 'it.evil.com'),
      throwsA(isA<DictionaryRequestException>()),
    );
    service.close();
  });
  test(
    'live Wiktionary: Italian, English, Spanish, German and French',
    () async {
      final service = OnlineDictionaryService();
      addTearDown(service.close);
      for (final sample in [
        ('it', 'casa'),
        ('en', 'house'),
        ('es', 'agua'),
        ('de', 'Haus'),
        ('fr', 'maison'),
      ]) {
        final result = await service.lookup(sample.$2, language: sample.$1);
        expect(
          result.definitions,
          isNotEmpty,
          reason: '${sample.$1}/${sample.$2}',
        );
        for (final line in result.definitions) {
          expect(line, isNot(matches(r'\{\{|\[\[|<ref')));
        }
        // Only public dictionary output, useful for reviewing real formatting.
        // ignore: avoid_print
        print('${sample.$1}/${sample.$2}: ${result.definitions.first}');
      }
    },
    skip: !const bool.fromEnvironment('DICTIONARY_LIVE'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
