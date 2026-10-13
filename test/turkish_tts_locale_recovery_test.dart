import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final catalogLanguage in ['tr', 'tr-TR']) {
    final voices = [
      const TtsVoiceOption(
        languageCode: 'it-IT', voice: 'it-IT-IsabellaNeural', label: 'Isabella'),
      TtsVoiceOption(
        languageCode: catalogLanguage, voice: 'tr-TR-EmelNeural', label: 'Emel'),
    ];
    final languages = AppSettingsService.languagesForVoices(voices);
    for (final savedLanguage in ['tr', 'tr-TR', 'tr_TR']) {
      test('$savedLanguage recovers Turkish from the $catalogLanguage catalog '
          'when a saved voice has disappeared', () {
        final resolved = AppSettingsService.normalizedTtsLanguageCodeFor(
          languages, voices, savedLanguage, 'tr-TR-RemovedVoiceNeural',
        );
        expect(resolved, catalogLanguage);
        expect(AppSettingsService.defaultVoiceForLanguageFrom(voices, resolved),
            'tr-TR-EmelNeural');
      });
    }
    test('Italian selection remains unchanged with the $catalogLanguage catalog', () {
      expect(AppSettingsService.normalizedTtsLanguageCodeFor(
        languages, voices, 'it-IT', 'it-IT-IsabellaNeural',
      ), 'it-IT');
    });
  }

  test('Locale recovery does not rewrite saved language or voice preferences',
      () async {
    SharedPreferences.setMockInitialValues({
      'sonarpad_tts_language': 'tr_TR',
      'sonarpad_tts_voice': 'tr-TR-RemovedVoiceNeural',
    });
    final settings = AppSettingsService();
    final language = await settings.loadTtsLanguage();
    final voice = await settings.loadTtsVoice();
    final voices = AppSettingsService.ttsVoices;
    expect(AppSettingsService.normalizedTtsLanguageCodeFor(
      AppSettingsService.languagesForVoices(voices), voices, language, voice,
    ), 'tr');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sonarpad_tts_language'), 'tr_TR');
    expect(prefs.getString('sonarpad_tts_voice'), 'tr-TR-RemovedVoiceNeural');
  });
}
