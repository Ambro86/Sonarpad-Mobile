import 'package:shared_preferences/shared_preferences.dart';

class TtsVoiceLanguage {
  final String code;
  final String label;

  const TtsVoiceLanguage(this.code, this.label);
}

class TtsVoiceOption {
  final String languageCode;
  final String voice;
  final String label;

  const TtsVoiceOption({
    required this.languageCode,
    required this.voice,
    required this.label,
  });
}

class AppSettingsService {
  static const _ttsLanguageKey = 'sonarpad_tts_language';
  static const _ttsVoiceKey = 'sonarpad_tts_voice';
  static const _tvSecretCodeKey = 'tvSecretCode';

  static const ttsLanguages = [
    TtsVoiceLanguage('it', 'Italiano'),
    TtsVoiceLanguage('en', 'English'),
    TtsVoiceLanguage('es', 'Spagnolo'),
    TtsVoiceLanguage('fr', 'Francese'),
    TtsVoiceLanguage('de', 'Tedesco'),
  ];

  static const ttsVoices = [
    TtsVoiceOption(
      languageCode: 'it',
      voice: 'it-IT-ElsaNeural',
      label: 'Elsa',
    ),
    TtsVoiceOption(
      languageCode: 'it',
      voice: 'it-IT-IsabellaNeural',
      label: 'Isabella',
    ),
    TtsVoiceOption(
      languageCode: 'it',
      voice: 'it-IT-DiegoNeural',
      label: 'Diego',
    ),
    TtsVoiceOption(
      languageCode: 'en',
      voice: 'en-US-JennyNeural',
      label: 'Jenny',
    ),
    TtsVoiceOption(
      languageCode: 'en',
      voice: 'en-US-GuyNeural',
      label: 'Guy',
    ),
    TtsVoiceOption(
      languageCode: 'en',
      voice: 'en-GB-SoniaNeural',
      label: 'Sonia',
    ),
    TtsVoiceOption(
      languageCode: 'es',
      voice: 'es-ES-ElviraNeural',
      label: 'Elvira',
    ),
    TtsVoiceOption(
      languageCode: 'es',
      voice: 'es-ES-AlvaroNeural',
      label: 'Alvaro',
    ),
    TtsVoiceOption(
      languageCode: 'fr',
      voice: 'fr-FR-DeniseNeural',
      label: 'Denise',
    ),
    TtsVoiceOption(
      languageCode: 'fr',
      voice: 'fr-FR-HenriNeural',
      label: 'Henri',
    ),
    TtsVoiceOption(
      languageCode: 'de',
      voice: 'de-DE-KatjaNeural',
      label: 'Katja',
    ),
    TtsVoiceOption(
      languageCode: 'de',
      voice: 'de-DE-ConradNeural',
      label: 'Conrad',
    ),
  ];

  Future<String> loadTtsLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ttsLanguageKey) ?? 'it';
  }

  Future<String> loadTtsVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString(_ttsLanguageKey) ?? 'it';
    return prefs.getString(_ttsVoiceKey) ?? defaultVoiceForLanguage(language);
  }

  Future<String> getTvSecretCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tvSecretCodeKey) ?? '';
  }

  Future<void> setTvSecretCode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tvSecretCodeKey, value);
  }

  Future<void> saveTtsSettings({
    required String languageCode,
    required String voice,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ttsLanguageKey, languageCode);
    await prefs.setString(_ttsVoiceKey, voice);
  }

  static List<TtsVoiceOption> voicesForLanguage(String languageCode) =>
      ttsVoices.where((voice) => voice.languageCode == languageCode).toList();

  static String defaultVoiceForLanguage(String languageCode) =>
      voicesForLanguage(languageCode).firstOrNull?.voice ?? 'it-IT-IsabellaNeural';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
