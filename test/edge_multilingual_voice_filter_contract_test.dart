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

  test('Settings exposes the transient multilingual filter in both renderers', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(
      source,
      contains('bool _showOnlyMultilingualEdgeVoices = false;'),
    );
    expect(source, contains("id: 'edge_multilingual_only'"));
    expect(source, contains("kind: 'toggle'"));
    expect(source, contains('SwitchListTile('));
    expect(
      source,
      contains('l10n.settingsShowOnlyMultilingualEdgeVoices'),
    );
    expect(
      source,
      contains('AppSettingsService.multilingualEdgeVoicesFrom(_edgeVoices)'),
    );
    expect(source, contains('if (_showOnlyMultilingualEdgeVoices) {'));
    expect(source, contains('_languageCode = result.languageCode;'));

    // The checkbox is a display filter only: it is intentionally absent from
    // the persistent settings service and from unsaved-change bookkeeping.
    final service =
        File('lib/services/app_settings_service.dart').readAsStringSync();
    expect(service, isNot(contains('showOnlyMultilingualEdgeVoicesKey')));
    expect(service, isNot(contains('saveShowOnlyMultilingual')));
  });

  test('multilingual filter label exists in every ARB locale', () {
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
