import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sonarpad_mobile_starter/services/aifa_pdf_parser.dart';
import 'package:sonarpad_mobile_starter/services/aifa_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test(
      'Buscopan formulations extract matching posologia from real AIFA PDFs',
      () async {
    final confezioni = await _searchConfezioni('buscopan');

    final cases = [
      _ExpectedCase(
        label: 'compressa',
        matchesPackage: (name) =>
            name.contains('compressa') || name.contains('compresse'),
        expectedInPosologia: const ['compresse rivestite'],
        forbiddenInPosologia: const ['1 fiala', 'soluzione iniettabile'],
      ),
      _ExpectedCase(
        label: 'supposta',
        matchesPackage: (name) =>
            name.contains('supposta') || name.contains('supposte'),
        expectedInPosologia: const ['supposte', '1 supposta'],
        forbiddenInPosologia: const ['1 fiala', 'soluzione iniettabile'],
      ),
      _ExpectedCase(
        label: 'iniettabile',
        matchesPackage: (name) => name.contains('iniettabile'),
        expectedInPosologia: const ['1 fiala', 'iniezione'],
        forbiddenInPosologia: const ['compresse rivestite', '1 supposta'],
      ),
    ];

    for (final testCase in cases) {
      final conf = _findConfezione(confezioni, 'buscopan', testCase);
      final posologia = await _extractRealPosologia(conf, testCase.label);
      final normalized = posologia.toLowerCase();

      for (final expected in testCase.expectedInPosologia) {
        expect(
          normalized,
          contains(expected),
          reason: 'La posologia estratta non sembra appartenere a '
              '"${testCase.label}".',
        );
      }
      for (final forbidden in testCase.forbiddenInPosologia) {
        expect(
          normalized,
          isNot(contains(forbidden)),
          reason: 'La posologia estratta per "${testCase.label}" sembra '
              'appartenere a un altra formulazione.',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
      'Aspirina formulations extract matching posologia from real AIFA PDFs',
      () async {
    await _checkGenericDrugFormulations(
      query: 'aspirina',
      aliases: const ['aspirina'],
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('Extra drugs extract matching posologia from real AIFA PDFs', () async {
    await _checkGenericDrugFormulations(
      query: 'maalox',
      aliases: const ['malox', 'maalox'],
    );
    await _checkGenericDrugFormulations(
      query: 'paroxetina',
      aliases: const ['paroxetina'],
    );
    await _checkGenericDrugFormulations(
      query: 'vivin c',
      aliases: const ['vivin c', 'vivinc'],
    );
    await _checkGenericDrugFormulations(
      query: 'tachipirina',
      aliases: const ['tachipirina'],
    );
    await _checkGenericDrugFormulations(
      query: 'oki',
      aliases: const ['oki'],
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<List<AifaConfezione>> _searchConfezioni(String query) async {
  final service = AifaService();
  final results = await service.searchDrugs(query).timeout(
        const Duration(seconds: 30),
      );

  return [
    for (final drug in results)
      for (final confezione in drug.confezioni) confezione,
  ];
}

AifaConfezione _findConfezione(
  List<AifaConfezione> confezioni,
  String drugName,
  _ExpectedCase testCase,
) {
  for (final confezione in confezioni) {
    final name = confezione.name.toLowerCase();
    if (name.contains(drugName) && testCase.matchesPackage(name)) {
      return confezione;
    }
  }

  fail(
    'La ricerca AIFA per $drugName non ha restituito confezioni per '
    '"${testCase.label}". Confezioni trovate:\n${_formatConfezioni(confezioni)}',
  );
}

Future<String> _extractRealPosologia(
  AifaConfezione conf,
  String label,
) async {
  final url =
      'https://api.aifa.gov.it/aifa-bdf-eif-be/1.0.0/organizzazione/'
      '${conf.codiceSis}/farmaci/${conf.aic6}/stampati?ts=FI';

  stdout.writeln('Confezione selezionata ($label): ${conf.name}');
  stdout.writeln('URL FI: $url');

  final response = await http.get(
    Uri.parse(url),
    headers: {'User-Agent': 'SonarpadMobile/1.0'},
  ).timeout(const Duration(seconds: 30));

  expect(response.statusCode, 200, reason: response.body);

  final document = PdfDocument(inputBytes: response.bodyBytes);
  final String text;
  try {
    text = PdfTextExtractor(document).extractText();
  } finally {
    document.dispose();
  }

  expect(text.trim(), isNotEmpty, reason: 'PDF AIFA senza testo estraibile.');

  final posologia = AifaPdfParser.extractSectionTextForTest(
    text,
    AifaSectionType.posologia,
    conf.name,
  );

  stdout.writeln('--- POSOLOGIA $label, primi 1200 caratteri ---');
  stdout.writeln(
    posologia.length <= 1200 ? posologia : posologia.substring(0, 1200),
  );

  return posologia;
}

Future<void> _checkGenericDrugFormulations({
  required String query,
  required List<String> aliases,
}) async {
  final confezioni = await _searchConfezioni(query);
  final matchingConfezioni = confezioni.where((conf) {
    final name = conf.name.toLowerCase();
    return aliases.any(name.contains);
  }).toList();

  expect(
    matchingConfezioni,
    isNotEmpty,
    reason: 'La ricerca AIFA per $query non ha restituito confezioni '
        'compatibili con $aliases. Confezioni trovate:\n'
        '${_formatConfezioni(confezioni)}',
  );

  final selectedByForm = <String, AifaConfezione>{};
  for (final conf in matchingConfezioni) {
    final formTokens = _formTokensFromName(conf.name);
    final key = formTokens.isEmpty ? conf.name.toLowerCase() : formTokens.join('|');
    selectedByForm.putIfAbsent(key, () => conf);
  }

  for (final conf in selectedByForm.values) {
    final formTokens = _formTokensFromName(conf.name);
    stdout.writeln('Forme rilevate per ${conf.name}: $formTokens');

    final posologia = await _extractRealPosologia(conf, conf.name);
    final normalized = posologia.toLowerCase();

    if (formTokens.isNotEmpty) {
      expect(
        formTokens.any((token) => _formTokenMatchesText(token, normalized)),
        isTrue,
        reason: 'La posologia estratta per "${conf.name}" non contiene '
            'nessuna forma rilevata dalla confezione $formTokens.',
      );
    }

  }
}

List<String> _formTokensFromName(String name) {
  final normalized = name.toLowerCase();
  final tokens = <String>[];
  for (final token in _knownFormTokens) {
    if (normalized.contains(token)) {
      tokens.add(token);
    }
  }
  return tokens;
}

bool _formTokenMatchesText(String token, String text) {
  final alternatives = _formTokenAlternatives[token] ?? [token];
  return alternatives.any(text.contains);
}

String _formatConfezioni(List<AifaConfezione> confezioni) {
  return const JsonEncoder.withIndent('  ').convert(
    confezioni
        .map((c) => {
              'name': c.name,
              'codiceSis': c.codiceSis,
              'aic6': c.aic6,
            })
        .toList(),
  );
}

class _ExpectedCase {
  final String label;
  final bool Function(String name) matchesPackage;
  final List<String> expectedInPosologia;
  final List<String> forbiddenInPosologia;

  const _ExpectedCase({
    required this.label,
    required this.matchesPackage,
    required this.expectedInPosologia,
    required this.forbiddenInPosologia,
  });
}

const _knownFormTokens = <String>[
  'capsula',
  'capsule',
  'compressa',
  'compresse',
  'crema',
  'effervescente',
  'effervescenti',
  'gel',
  'gocce',
  'granulato',
  'iniettabile',
  'iniettabili',
  'masticabile',
  'masticabili',
  'orale',
  'polvere',
  'rivestita',
  'rivestite',
  'soluzione',
  'sospensione',
  'supposta',
  'supposte',
];

const _formTokenAlternatives = <String, List<String>>{
  'capsula': ['capsula', 'capsule'],
  'capsule': ['capsula', 'capsule'],
  'compressa': ['compressa', 'compresse'],
  'compresse': ['compressa', 'compresse'],
  'effervescente': ['effervescente', 'effervescenti'],
  'effervescenti': ['effervescente', 'effervescenti'],
  'granulato': ['granulato', 'bustina', 'bustine'],
  'iniettabile': ['iniettabile', 'iniettabili', 'iniezione'],
  'iniettabili': ['iniettabile', 'iniettabili', 'iniezione'],
  'masticabile': ['masticabile', 'masticabili', 'masticare'],
  'masticabili': ['masticabile', 'masticabili', 'masticare'],
  'orale': [
    'orale',
    'bustina',
    'bustine',
    'bocca',
    'spray',
    'spruzzi',
    'spruzzo',
  ],
  'polvere': ['polvere', 'bustina', 'bustine'],
  'rivestita': ['rivestita', 'rivestite'],
  'rivestite': ['rivestita', 'rivestite'],
  'soluzione': [
    'soluzione',
    'bustina',
    'bustine',
    'infusione',
    'sacca',
    'somministrato',
  ],
  'sospensione': ['sospensione', 'cucchiaino', 'cucchiaini'],
  'supposta': ['supposta', 'supposte'],
  'supposte': ['supposta', 'supposte'],
};
