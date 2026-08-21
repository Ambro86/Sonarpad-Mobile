import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

ProcessResult _runPython(List<String> args) {
  Object? lastError;
  for (final executable in const ['python', 'python3', 'py']) {
    try {
      return Process.runSync(executable, args, workingDirectory: Directory.current.path);
    } catch (error) {
      lastError = error;
    }
  }
  throw StateError('Python is required for localization contract tools: $lastError');
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _arbKeys(String path) => _readJson(path)
    .keys
    .where((key) => !key.startsWith('@'))
    .toSet();

Set<String> _placeholderKeys(Object? metadata) {
  if (metadata is! Map<String, dynamic>) return <String>{};
  final placeholders = metadata['placeholders'];
  if (placeholders is! Map<String, dynamic>) return <String>{};
  return placeholders.keys.toSet();
}

void main() {
  test('all ARB locales expose exactly the same message keys', () {
    const files = [
      'app_it.arb',
      'app_en.arb',
      'app_es.arb',
      'app_fr.arb',
      'app_de.arb',
      'app_pl.arb',
      'app_cs.arb',
      'app_pt.arb',
      'app_pt_BR.arb',
      'app_zh.arb',
      'app_zh_CN.arb',
    ];
    final templatePath = 'lib/l10n/${files.first}';
    final templateArb = _readJson(templatePath);
    final template = _arbKeys(templatePath);
    expect(template.length, 1020);
    for (final file in files.skip(1)) {
      final path = 'lib/l10n/$file';
      final arb = _readJson(path);
      expect(_arbKeys(path), template, reason: file);
      for (final key in template) {
        final templatePlaceholders = _placeholderKeys(templateArb['@$key']);
        final localePlaceholders = _placeholderKeys(arb['@$key']);
        expect(localePlaceholders, templatePlaceholders,
            reason: '$file placeholder metadata for $key');
      }
    }
  });

  test('calendar translation files are complete for every locale', () {
    const files = [
      'it.json',
      'en.json',
      'es.json',
      'fr.json',
      'de.json',
      'pl.json',
      'cs.json',
      'pt_PT.json',
      'pt_BR.json',
      'zh_CN.json',
    ];
    for (final file in files) {
      final data = _readJson('assets/calendar/$file');
      final saints = data['saints'] as Map<String, dynamic>;
      final quotes = data['quotes'] as List<dynamic>;
      final holidays = data['holidays'] as Map<String, dynamic>;
      expect(saints.length, 365, reason: '$file saints');
      expect(quotes.length, 128, reason: '$file quotes');
      expect(saints.values.every((value) => value is String && value.trim().isNotEmpty), isTrue,
          reason: '$file saints must be non-empty');
      expect(quotes.every((value) => value is String && value.trim().isNotEmpty), isTrue,
          reason: '$file quotes must be non-empty');
      expect(holidays.values.every((value) => value is String && value.trim().isNotEmpty), isTrue,
          reason: '$file holidays must be non-empty');
    }
  });

  test('generated calendar data is synchronized with JSON sources', () {
    final generated = File(
      'lib/services/calendar/calendar_localization_data.g.dart',
    );
    final before = generated.readAsStringSync();
    final result = _runPython(['tool/generate_calendar_localizations.py']);
    expect(result.exitCode, 0,
        reason: '${result.stdout}\n${result.stderr}');
    final after = generated.readAsStringSync();
    expect(after, before,
        reason: 'Run python tool/generate_calendar_localizations.py and commit the generated file.');
  });

  test('calendar service contains no embedded saints, quotes or holiday translations', () {
    final service =
        File('lib/services/calendar/calendar_service.dart').readAsStringSync();
    final legacySaints = File('lib/services/calendar/saints_data.dart');
    expect(legacySaints.existsSync(), isTrue);
    final legacyText = legacySaints.readAsStringSync();
    expect(legacyText, contains('Compatibility tombstone'));
    expect(legacyText, isNot(contains('Map<String, String>')));
    expect(legacyText, isNot(contains('List<String>')));
    expect(legacyText.length, lessThan(1000));
    expect(service, isNot(contains('final quotesIt = [')));
    expect(service, isNot(contains('final quotesZhCn = [')));
    expect(service, contains('kCalendarSaintsByLocale'));
    expect(service, contains('kCalendarQuotesByLocale'));
    expect(service, contains('kCalendarHolidaysByLocale'));
  });

  test('language and country display names come from ARB', () {
    const arbFiles = [
      'app_it.arb',
      'app_en.arb',
      'app_es.arb',
      'app_fr.arb',
      'app_de.arb',
      'app_pl.arb',
      'app_cs.arb',
      'app_pt.arb',
      'app_pt_BR.arb',
      'app_zh.arb',
      'app_zh_CN.arb',
    ];
    for (final file in arbFiles) {
      final arb = _readJson('lib/l10n/$file');
      expect(arb['simplifiedChineseLanguageName'], isNotEmpty, reason: file);
      expect(arb['chinaCountryName'], isNotEmpty, reason: file);
      expect(arb['technicalErrorGeneric'], isNotEmpty, reason: file);
    }
    final dynamicLabels =
        File('lib/l10n/localized_dynamic_labels.dart').readAsStringSync();
    expect(dynamicLabels, isNot(contains("'it' => 'Cinese semplificato'")));
    expect(dynamicLabels, isNot(contains("'zh' => '中国'")));
  });

  test('no new hard-coded shared UI strings are introduced', () {
    final result = _runPython(['tool/check_user_facing_strings.py']);
    expect(result.exitCode, 0,
        reason: '${result.stdout}\n${result.stderr}');
  });

  test('legacy per-language technical error translator is removed', () {
    final labels =
        File('lib/l10n/localized_dynamic_labels.dart').readAsStringSync();
    expect(labels, isNot(contains('localizeTechnicalError')));
    expect(labels, isNot(contains('_localizeChineseTechnicalError')));
    expect(labels, isNot(contains('_isPortugueseLocale')));

    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(source, isNot(contains('localizeTechnicalError')),
          reason: file.path);
    }
  });

}
