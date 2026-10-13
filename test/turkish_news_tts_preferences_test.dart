import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';

const _edgeLanguageKey = 'sonarpad_tts_language';
const _edgeVoiceKey = 'sonarpad_tts_voice';
const _systemLanguageKey = 'sonarpad_system_tts_language';
const _systemVoiceKey = 'sonarpad_system_tts_voice';

Map<String, Object?> _storedValues(SharedPreferences prefs) => {
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final appLanguage in ['it', 'en', 'tr']) {
    test('Turkish article fallback leaves $appLanguage app defaults unchanged',
        () async {
      final settings = AppSettingsService();
      await settings.saveAppLanguage(appLanguage);
      final prefs = await SharedPreferences.getInstance();
      final storedBeforeReading = _storedValues(prefs);

      expect(
        await settings.loadTtsVoice(fallbackLanguageCode: 'tr-TR'),
        'tr-TR-EmelNeural',
      );
      expect(
        await settings.loadSystemTtsLanguage(fallbackLanguageCode: 'tr-TR'),
        'tr-TR',
      );

      final reloaded = AppSettingsService();
      final defaultVoice = appLanguage == 'tr'
          ? 'tr-TR-EmelNeural'
          : 'it-IT-IsabellaNeural';
      final defaultSystemLanguage = appLanguage == 'tr' ? 'tr-TR' : 'it-IT';
      expect(await reloaded.loadTtsVoice(), defaultVoice);
      expect(
        await reloaded.loadTtsVoice(fallbackLanguageCode: null),
        defaultVoice,
      );
      expect(await reloaded.loadSystemTtsLanguage(), defaultSystemLanguage);
      expect(
        await reloaded.loadSystemTtsLanguage(fallbackLanguageCode: null),
        defaultSystemLanguage,
      );
      expect(
        await reloaded.loadTtsLanguage(),
        appLanguage == 'tr' ? 'tr-TR' : 'it',
      );
      expect(await reloaded.loadSystemTtsVoice(), isNull);
      expect(await reloaded.loadAppLanguage(), appLanguage);
      expect(_storedValues(prefs), storedBeforeReading);
    });

    test('saved TTS choices survive Turkish articles with $appLanguage UI',
        () async {
      final settings = AppSettingsService();
      await settings.saveAppLanguage(appLanguage);
      await settings.saveTtsSettings(
        languageCode: 'fr-FR',
        voice: 'saved-edge-voice',
      );
      await settings.saveSystemTtsLanguage('en-GB');
      await settings.saveSystemTtsVoice('saved-system-voice');
      final prefs = await SharedPreferences.getInstance();
      final storedBeforeReading = _storedValues(prefs);

      final reloaded = AppSettingsService();
      expect(await reloaded.loadTtsLanguage(), 'fr-FR');
      expect(
        await reloaded.loadTtsVoice(fallbackLanguageCode: 'tr-TR'),
        'saved-edge-voice',
      );
      expect(
        await reloaded.loadSystemTtsLanguage(fallbackLanguageCode: 'tr-TR'),
        'en-GB',
      );
      expect(await reloaded.loadSystemTtsVoice(), 'saved-system-voice');
      expect(_storedValues(prefs), storedBeforeReading);

      // Restore the absence of TTS preferences without resetting the app locale.
      await prefs.remove(_edgeLanguageKey);
      await prefs.remove(_edgeVoiceKey);
      await reloaded.saveSystemTtsVoice(null);
      await prefs.remove(_systemLanguageKey);
      final restored = AppSettingsService();
      expect(
        await restored.loadTtsVoice(fallbackLanguageCode: 'tr-TR'),
        'tr-TR-EmelNeural',
      );
      expect(
        await restored.loadSystemTtsLanguage(fallbackLanguageCode: 'tr-TR'),
        'tr-TR',
      );
      expect(await restored.loadSystemTtsVoice(), isNull);
      expect(await restored.loadAppLanguage(), appLanguage);
    });
  }

  const edgeCases = [
    (
      name: 'a saved language without a voice',
      values: <String, Object>{_edgeLanguageKey: 'fr-FR'},
      language: 'fr-FR',
      voice: 'fr-FR-DeniseNeural',
    ),
    (
      name: 'a saved voice without a language',
      values: <String, Object>{_edgeVoiceKey: 'saved-edge-voice'},
      language: 'it',
      voice: 'saved-edge-voice',
    ),
    (
      name: 'an empty saved language',
      values: <String, Object>{_edgeLanguageKey: ''},
      language: '',
      voice: 'it-IT-IsabellaNeural',
    ),
    (
      name: 'a whitespace saved language',
      values: <String, Object>{_edgeLanguageKey: ' '},
      language: ' ',
      voice: 'it-IT-IsabellaNeural',
    ),
    (
      name: 'an empty saved voice',
      values: <String, Object>{_edgeVoiceKey: ''},
      language: 'it',
      voice: '',
    ),
    (
      name: 'a whitespace saved voice',
      values: <String, Object>{_edgeVoiceKey: ' '},
      language: 'it',
      voice: ' ',
    ),
  ];
  for (final scenario in edgeCases) {
    test('Turkish Edge fallback preserves ${scenario.name}', () async {
      SharedPreferences.setMockInitialValues(scenario.values);
      final settings = AppSettingsService();
      await settings.saveAppLanguage('it');

      expect(await settings.loadTtsLanguage(), scenario.language);
      expect(await settings.loadTtsVoice(), scenario.voice);
      expect(
        await settings.loadTtsVoice(fallbackLanguageCode: 'tr-TR'),
        scenario.voice,
      );
      // Edge choices do not suppress the independent system fallback.
      expect(
        await settings.loadSystemTtsLanguage(fallbackLanguageCode: 'tr-TR'),
        'tr-TR',
      );
    });
  }

  const systemCases = [
    (
      name: 'a saved language without a voice',
      values: <String, Object>{_systemLanguageKey: 'en-GB'},
      language: 'en-GB',
      voice: null,
    ),
    (
      name: 'a saved voice without a language',
      values: <String, Object>{_systemVoiceKey: 'saved-system-voice'},
      language: 'it-IT',
      voice: 'saved-system-voice',
    ),
    (
      name: 'an empty saved language',
      values: <String, Object>{_systemLanguageKey: ''},
      language: '',
      voice: null,
    ),
    (
      name: 'a whitespace saved language',
      values: <String, Object>{_systemLanguageKey: ' '},
      language: ' ',
      voice: null,
    ),
    (
      name: 'an empty saved voice',
      values: <String, Object>{_systemVoiceKey: ''},
      language: 'it-IT',
      voice: '',
    ),
    (
      name: 'a whitespace saved voice',
      values: <String, Object>{_systemVoiceKey: ' '},
      language: 'it-IT',
      voice: ' ',
    ),
  ];
  for (final scenario in systemCases) {
    test('Turkish system fallback preserves ${scenario.name}', () async {
      SharedPreferences.setMockInitialValues(scenario.values);
      final settings = AppSettingsService();
      await settings.saveAppLanguage('en');

      expect(await settings.loadSystemTtsLanguage(), scenario.language);
      expect(
        await settings.loadSystemTtsLanguage(fallbackLanguageCode: 'tr-TR'),
        scenario.language,
      );
      expect(await settings.loadSystemTtsVoice(), scenario.voice);
      // System choices do not suppress the independent Edge fallback.
      expect(
        await settings.loadTtsVoice(fallbackLanguageCode: 'tr-TR'),
        'tr-TR-EmelNeural',
      );
    });
  }

  test('removing a system voice re-enables fallback only without a language',
      () async {
    final settings = AppSettingsService();
    await settings.saveAppLanguage('en');
    await settings.saveSystemTtsVoice('saved-system-voice');
    expect(
      await settings.loadSystemTtsLanguage(fallbackLanguageCode: 'tr-TR'),
      'it-IT',
    );
    await settings.saveSystemTtsVoice(null);
    expect(
      await AppSettingsService()
          .loadSystemTtsLanguage(fallbackLanguageCode: 'tr-TR'),
      'tr-TR',
    );

    await settings.saveSystemTtsLanguage('fr-FR');
    await settings.saveSystemTtsVoice('another-system-voice');
    await settings.saveSystemTtsVoice(null);
    final reloaded = AppSettingsService();
    expect(
      await reloaded.loadSystemTtsLanguage(fallbackLanguageCode: 'tr-TR'),
      'fr-FR',
    );
    expect(await reloaded.loadSystemTtsVoice(), isNull);
  });

  test('engine, speed and pitch preferences do not suppress Turkish fallback',
      () async {
    final settings = AppSettingsService();
    await settings.saveAppLanguage('en');
    await settings.saveTtsSpeed(1.2);
    await settings.saveTtsPitch(0.8);
    for (final engine in ['edge', 'system']) {
      await settings.saveTtsEngine(engine);
      final reloaded = AppSettingsService();
      expect(
        await reloaded.loadTtsVoice(fallbackLanguageCode: 'tr-TR'),
        'tr-TR-EmelNeural',
      );
      expect(
        await reloaded.loadSystemTtsLanguage(fallbackLanguageCode: 'tr-TR'),
        'tr-TR',
      );
      expect(await reloaded.loadTtsEngine(), engine);
      expect(await reloaded.loadTtsSpeed(), 1.2);
      expect(await reloaded.loadTtsPitch(), 0.8);
    }
  });
}
