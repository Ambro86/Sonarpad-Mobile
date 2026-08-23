import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const languageKeys = <String>[
    'radioLanguageIt',
    'radioLanguageEn',
    'radioLanguageEs',
    'radioLanguagePt',
    'radioLanguageFr',
    'radioLanguageDe',
    'radioLanguageUk',
    'radioLanguageLt',
    'radioLanguageSv',
    'radioLanguageVi',
    'radioLanguageCs',
    'radioLanguagePl',
    'radioLanguageSr',
    'radioLanguageRu',
    'radioLanguageZh',
    'radioLanguageHi',
  ];

  test('Wikipedia language names are localized through AppLocalizations', () {
    final source = File('lib/screens/wikipedia_screen.dart').readAsStringSync();

    expect(source, contains("import '../l10n/localized_dynamic_labels.dart';"));
    expect(source, contains('l10n.languageLabel(code)'));
    expect(source, isNot(contains("('en', 'English')")));
    expect(source, isNot(contains("('fr', 'Français')")));
    expect(source, isNot(contains("('de', 'Deutsch')")));
  });

  test('Gutenberg language names use the same localized helper', () {
    final source = File('lib/screens/gutenberg_screen.dart').readAsStringSync();

    expect(source, contains("import '../l10n/localized_dynamic_labels.dart';"));
    expect(source, contains('l10n.languageLabel(code)'));
    expect(source, isNot(contains("('en', 'English')")));
    expect(source, isNot(contains("('fr', 'Français')")));
    expect(source, isNot(contains("('de', 'Deutsch')")));
  });

  test('TTS language picker localizes known language codes too', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(source, contains("import '../l10n/localized_dynamic_labels.dart';"));
    expect(source, contains('_localizedEdgeLanguageLabel'));
    expect(source, contains('l10n.languageLabel(language.code)'));
    expect(
      source,
      matches(
        RegExp(
          r'labelBuilder:\s*\(language\)\s*=>\s*'
          r'_localizedEdgeLanguageLabel\(language,\s*l10n\)',
        ),
      ),
    );
  });

  test('all app locales provide every language name used by Wikipedia', () {
    const arbFiles = <String>[
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
      'app_uk.arb',
      'app_zh_CN.arb',
    ];

    for (final file in arbFiles) {
      final data = jsonDecode(File('lib/l10n/$file').readAsStringSync())
          as Map<String, dynamic>;
      for (final key in languageKeys) {
        expect(
          data[key]?.toString().trim(),
          isNotEmpty,
          reason: '$file must localize $key',
        );
      }
    }
  });
}
