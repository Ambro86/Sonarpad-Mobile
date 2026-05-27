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
  static const _bdciechiUsernameKey = 'bdciechiUsername';
  static const _bdciechiPasswordKey = 'bdciechiPassword';

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
      voice: 'it-IT-IsabellaNeural',
      label: 'Isabella',
    ),
    TtsVoiceOption(
      languageCode: 'it',
      voice: 'it-IT-ElsaNeural',
      label: 'Elsa',
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

  Future<String> loadAppLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sonarpad_app_language') ?? 'it';
  }

  Future<void> saveAppLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sonarpad_app_language', languageCode);
  }

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

  Future<String> getBdCiechiUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bdciechiUsernameKey) ?? '';
  }

  Future<void> setBdCiechiUsername(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bdciechiUsernameKey, value);
  }

  Future<String> getBdCiechiPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bdciechiPasswordKey) ?? '';
  }

  Future<void> setBdCiechiPassword(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bdciechiPasswordKey, value);
  }

  static const _ttsSpeedKey = 'sonarpad_tts_speed';
  static const _ttsPitchKey = 'sonarpad_tts_pitch';

  Future<double> loadTtsSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_ttsSpeedKey) ?? 1.0;
  }

  Future<void> saveTtsSpeed(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ttsSpeedKey, value);
  }

  Future<double> loadTtsPitch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_ttsPitchKey) ?? 1.0;
  }

  Future<void> saveTtsPitch(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ttsPitchKey, value);
  }

  Future<void> saveTtsSettings({
    required String languageCode,
    required String voice,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ttsLanguageKey, languageCode);
    await prefs.setString(_ttsVoiceKey, voice);
  }

  static const _ttsEngineKey = 'sonarpad_tts_engine';
  static const _systemTtsLanguageKey = 'sonarpad_system_tts_language';
  static const _systemTtsVoiceKey = 'sonarpad_system_tts_voice';

  Future<String> loadTtsEngine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ttsEngineKey) ?? 'edge';
  }

  Future<void> saveTtsEngine(String engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ttsEngineKey, engine);
  }

  Future<String> loadSystemTtsLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_systemTtsLanguageKey) ?? 'it-IT';
  }

  Future<void> saveSystemTtsLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_systemTtsLanguageKey, language);
  }

  Future<String?> loadSystemTtsVoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_systemTtsVoiceKey);
  }

  Future<void> saveSystemTtsVoice(String? voice) async {
    final prefs = await SharedPreferences.getInstance();
    if (voice == null) {
      await prefs.remove(_systemTtsVoiceKey);
    } else {
      await prefs.setString(_systemTtsVoiceKey, voice);
    }
  }

  static List<TtsVoiceOption> voicesForLanguage(String languageCode) =>
      ttsVoices.where((voice) => voice.languageCode == languageCode).toList();

  static String defaultVoiceForLanguage(String languageCode) =>
      voicesForLanguage(languageCode).firstOrNull?.voice ?? 'it-IT-IsabellaNeural';

  // --- Segnalibro Automatico Media ---
  
  static const _autoBookmarkKey = 'sonarpad_auto_bookmark';

  Future<bool> isAutoBookmarkEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBookmarkKey) ?? true;
  }

  Future<void> setAutoBookmarkEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBookmarkKey, value);
  }

  Future<int?> getMediaBookmark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('bookmark_$id');
  }

  Future<void> saveMediaBookmark(String id, int positionInSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    if (positionInSeconds <= 0) {
      await prefs.remove('bookmark_$id');
    } else {
      await prefs.setInt('bookmark_$id', positionInSeconds);
    }
  }

  Future<void> removeMediaBookmark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bookmark_$id');
  }

  // --- Slider di Riproduzione ---
  
  static const _seekSliderStepKey = 'sonarpad_seek_slider_step';

  Future<int> loadSeekSliderStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_seekSliderStepKey) ?? 60;
  }

  Future<void> saveSeekSliderStep(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seekSliderStepKey, value);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
