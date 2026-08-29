import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';

void main() {
  test('multilingual Edge filter uses the technical voice id, not its label', () {
    const multilingual = TtsVoiceOption(
      languageCode: 'en-US',
      voice: 'en-US-AvaMultilingualNeural',
      label: 'Ava',
    );
    const misleadingLabel = TtsVoiceOption(
      languageCode: 'it-IT',
      voice: 'it-IT-IsabellaNeural',
      label: 'Multilingual',
    );

    expect(AppSettingsService.isMultilingualEdgeVoice(multilingual), isTrue);
    expect(AppSettingsService.isMultilingualEdgeVoice(misleadingLabel), isFalse);
    expect(
      AppSettingsService.multilingualEdgeVoicesFrom(
        const [multilingual, misleadingLabel],
      ),
      const [multilingual],
    );
  });

  test('Edge catalog exposes real multilingual voices to the filter', () {
    final decoded = jsonDecode(
      File('assets/data/edge_voices.json').readAsStringSync(),
    ) as List<dynamic>;
    final ids = decoded
        .whereType<Map<String, dynamic>>()
        .map((entry) => entry['ShortName']?.toString() ?? '')
        .where((id) => id.toLowerCase().contains('multilingual'))
        .toList();

    expect(ids, isNotEmpty);
    expect(ids, everyElement(endsWith('Neural')));
  });

  test('Settings exposes multilingual voices as a separate menu', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(source, contains("id: 'edge_multilingual_voices'"));
    expect(
      source,
      contains("const RouteSettings(name: '/settings/edge-multilingual-voices')"),
    );
    expect(source, contains("kind: 'button'"));
    expect(
      source,
      contains('l10n.settingsShowOnlyMultilingualEdgeVoices'),
    );
    expect(
      source,
      contains('AppSettingsService.multilingualEdgeVoicesFrom(_edgeVoices)'),
    );
    expect(source, contains('_openMultilingualEdgeVoicePicker'));
    expect(source, contains('_languageCode = result.languageCode;'));

    final multilingualPickerStart = source.indexOf(
      'Future<void> _openMultilingualEdgeVoicePicker()',
    );
    final ordinaryVoicePickerStart = source.indexOf(
      'Future<void> _openEdgeVoicePicker()',
    );
    expect(multilingualPickerStart, greaterThanOrEqualTo(0));
    expect(ordinaryVoicePickerStart, greaterThan(multilingualPickerStart));
    final multilingualPickerSource = source.substring(
      multilingualPickerStart,
      ordinaryVoicePickerStart,
    );
    expect(multilingualPickerSource, contains('enableLetterPicker: false'));

    // The ordinary Edge language/voice controls remain language-scoped and are
    // not filtered by the multilingual menu.
    expect(
      source,
      contains(
        'AppSettingsService.voicesForLanguageFrom(_edgeVoices, _languageCode)',
      ),
    );
    expect(source, isNot(contains('_showOnlyMultilingualEdgeVoices')));
    expect(source, isNot(contains("id: 'edge_multilingual_only'")));

    final engineIndex = source.indexOf("id: 'tts_engine'");
    final multilingualIndex = source.indexOf("id: 'edge_multilingual_voices'");
    final languageIndex = source.indexOf("id: 'edge_language'");
    expect(engineIndex, greaterThanOrEqualTo(0));
    expect(multilingualIndex, greaterThan(engineIndex));
    expect(languageIndex, greaterThan(multilingualIndex));
  });

  test('multilingual menu label exists in every ARB locale', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'));

    for (final file in arbFiles) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(
        json['settingsShowOnlyMultilingualEdgeVoices'],
        isA<String>().having((value) => value.trim(), 'text', isNotEmpty),
        reason: file.path,
      );
    }
  });
}
