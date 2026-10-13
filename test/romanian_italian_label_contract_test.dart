import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/l10n/localized_dynamic_labels.dart';

void main() {
  test('Romanian language is labelled Romena in Italian UI', () {
    final italian = lookupSupportedAppLocalizations('it');
    for (final code in ['ro', 'ro-RO', 'ro_RO', 'RO']) {
      expect(italian.languageLabel(code), 'Romena', reason: code);
      expect(italian.radioLanguageLabel(code), 'Romena', reason: code);
    }
    expect(italian.radioCommunityLanguageLabel('romanian'), 'Romena');
    expect(italian.radioLanguageRo, 'Romena');
  });

  test('Romanian labels use the ARB for each interface language', () {
    const expected = {
      'ro': 'Română',
      'en': 'Romanian',
      'tr': 'Rumence',
    };
    for (final entry in expected.entries) {
      final strings = lookupSupportedAppLocalizations(entry.key);
      expect(strings.languageLabel('ro'), entry.value, reason: entry.key);
      expect(strings.radioCommunityLanguageLabel('romanian'), entry.value,
          reason: entry.key);
    }
  });
}
