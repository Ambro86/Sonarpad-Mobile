import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Edge voice labels do not expose technical locale or voice IDs', () {
    final service =
        File('lib/services/app_settings_service.dart').readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(service, contains('return name.trim();'));
    expect(service, isNot(contains("return '\$name (\$locale)';")));
    expect(settings, contains('labelBuilder: (voice) => voice.label'));
    expect(settings, contains('label: e.label'));
    expect(settings, contains('valueLabel: _selectedEdgeVoiceLabel'));
    expect(settings, contains('name = name.substring(separatorIndex + 1);'));
    expect(settings, isNot(contains("'\${e.label} (\${e.voice})'")));
    expect(
      settings,
      isNot(contains("'\${_selectedEdgeVoice!.label} (\${_selectedEdgeVoice!.voice})'")),
    );
  });

  test('Edge language labels use localized country names instead of locale codes', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(settings, contains("import '../utils/country_name_helper.dart';"));
    expect(settings, contains('localizedCountryDisplayName('));
    expect(settings, contains('localeName: l10n.localeName'));
    expect(settings, contains("return '\$localizedLanguage (\$country)';"));
    expect(settings, isNot(contains("return '\$localized (\${language.code})';")));
  });
}
