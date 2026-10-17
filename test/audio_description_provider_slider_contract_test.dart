import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File(
    'lib/screens/create_ai_audiodescription_screen.dart',
  ).readAsStringSync().replaceAll('\r\n', '\n');

  test(
    'Gemini versus Sonarpad AI uses the same discrete accessible slider as speed',
    () {
      final start = screen.indexOf("id: 'provider',");
      final end = screen.indexOf("if (_provider == 'gemini')", start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final selector = screen.substring(start, end);
      expect(selector, contains("kind: 'slider'"));
      expect(selector, contains('accessibilityButtonTrait: false'));
      expect(selector, contains('sliderValue: providerIndex.toDouble()'));
      expect(selector, contains('sliderMin: 0'));
      expect(selector, contains('sliderMax: 1'));
      expect(selector, contains('sliderStep: 1'));
      expect(selector, contains('sliderIncreasedValueLabel'));
      expect(selector, contains('sliderDecreasedValueLabel'));
      expect(
        selector,
        contains('AccessibleOption(value: 0, label: providerLabels[0])'),
      );
      expect(
        selector,
        contains('AccessibleOption(value: 1, label: providerLabels[1])'),
      );
      expect(selector, isNot(contains("kind: 'picker'")));
    },
  );

  test(
    'provider flick updates state immediately and retains saved selection',
    () {
      final start = screen.indexOf("if (id == 'provider') {");
      final end = screen.indexOf("} else if (id == 'mp3_bitrate')", start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final handler = screen.substring(start, end);
      expect(handler, contains('value.round().clamp(0, 1)'));
      expect(handler, contains('setState(() => _provider = newProvider)'));
      expect(
        handler,
        contains('AiAudioDescriptionPreferences.saveProvider(newProvider)'),
      );
      expect(handler, contains('_refreshSonarpadBalance()'));
    },
  );

  test(
    'provider controls and radio catalog remain in the consolidated 0.5.1 notes',
    () {
      final changes =
          jsonDecode(File('assets/changelog.json').readAsStringSync()) as List;
      final current = changes.cast<Map<String, dynamic>>().singleWhere(
        (entry) => entry['version'] == '0.5.1',
      );
      expect(current['version'], '0.5.1');
      const languages = [
        'it',
        'en',
        'fr',
        'es',
        'pt',
        'pt_BR',
        'de',
        'pl',
        'cs',
        'uk',
        'ro',
        'zh_CN',
        'tr',
      ];
      for (final language in languages) {
        final items = (current[language] as List).cast<String>();
        expect(items, isNotEmpty);
        expect(items.join(" "), contains("Gemini"));
        expect(items.join(" "), contains("Sonarpad AI"));
        expect(items.where((item) => item.contains('**')), isEmpty);
        expect(items.last, isNot(contains('Radio Browser')));
        expect(items.last, isNot(contains('Radio-Browser')));
        expect(items.last, isNot(contains('RadioBOSS')));
        expect(items.length, (current['it'] as List).length, reason: language);
      }
      final radio = File('lib/services/radio_service.dart').readAsStringSync();
      expect(radio, contains('all.api.radio-browser.info'));
      expect(radio, contains('_fetchRadioBrowserStationsPage'));
    },
  );
}
