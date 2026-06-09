import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  final String? languageLabel;

  const TtsVoiceOption({
    required this.languageCode,
    required this.voice,
    required this.label,
    this.languageLabel,
  });
}

class AppSettingsService {
  static const _supportedAppLanguages = {'it', 'en', 'es', 'fr'};
  static const _ttsLanguageKey = 'sonarpad_tts_language';
  static const _ttsVoiceKey = 'sonarpad_tts_voice';
  static const _tvSecretCodeKey = 'tvSecretCode';
  static const _bdciechiUsernameKey = 'bdciechiUsername';
  static const _bdciechiPasswordKey = 'bdciechiPassword';
  static const _weatherCityKey = 'sonarpad_weather_city';

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
    final savedLanguage = prefs.getString('sonarpad_app_language');
    if (savedLanguage != null) return savedLanguage;

    for (final locale in PlatformDispatcher.instance.locales) {
      final deviceLanguage = locale.languageCode;
      if (_supportedAppLanguages.contains(deviceLanguage)) {
        return deviceLanguage;
      }
    }
    return 'en';
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

  Future<String> getWeatherCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_weatherCityKey) ?? '';
  }

  Future<void> setWeatherCity(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weatherCityKey, value);
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

  static Future<List<TtsVoiceOption>> loadEdgeVoices() async {
    try {
      final raw = await rootBundle.loadString('assets/data/edge_voices.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        debugPrint('Catalogo voci Edge non valido: formato inatteso.');
        return ttsVoices;
      }

      final voices = <TtsVoiceOption>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final shortName = item['ShortName']?.toString() ?? '';
        final locale = item['Locale']?.toString() ?? '';
        final friendlyName = item['FriendlyName']?.toString() ?? '';
        if (shortName.isEmpty || locale.isEmpty) continue;

        voices.add(
          TtsVoiceOption(
            languageCode: locale,
            voice: shortName,
            label: _edgeVoiceLabel(shortName, locale),
            languageLabel: _edgeLanguageLabel(locale, friendlyName),
          ),
        );
      }
      if (voices.isEmpty) {
        debugPrint('Catalogo voci Edge vuoto: uso le voci predefinite.');
        return ttsVoices;
      }
      return voices;
    } catch (error) {
      debugPrint('Errore caricamento catalogo voci Edge: $error');
      return ttsVoices;
    }
  }

  static List<TtsVoiceLanguage> languagesForVoices(
    List<TtsVoiceOption> voices,
  ) {
    final languages = <TtsVoiceLanguage>[];
    final seen = <String>{};
    for (final voice in voices) {
      if (!seen.add(voice.languageCode)) continue;
      languages.add(
        TtsVoiceLanguage(
          voice.languageCode,
          voice.languageLabel ?? voice.languageCode,
        ),
      );
    }
    return languages;
  }

  static List<TtsVoiceOption> voicesForLanguage(String languageCode) =>
      voicesForLanguageFrom(ttsVoices, languageCode);

  static List<TtsVoiceOption> voicesForLanguageFrom(
    List<TtsVoiceOption> voices,
    String languageCode,
  ) {
    final exactMatches =
        voices.where((voice) => voice.languageCode == languageCode).toList();
    if (exactMatches.isNotEmpty) return exactMatches;

    final baseLanguage = languageCode.split('-').first;
    return voices
        .where((voice) => voice.languageCode.split('-').first == baseLanguage)
        .toList();
  }

  static String defaultVoiceForLanguage(String languageCode) =>
      defaultVoiceForLanguageFrom(ttsVoices, languageCode);

  static String defaultVoiceForLanguageFrom(
    List<TtsVoiceOption> voices,
    String languageCode,
  ) {
    final preferredVoice = _preferredEdgeVoice(languageCode);
    final availableVoices = voicesForLanguageFrom(voices, languageCode);
    if (availableVoices.any((voice) => voice.voice == preferredVoice)) {
      return preferredVoice;
    }
    return availableVoices.firstOrNull?.voice ?? 'it-IT-IsabellaNeural';
  }

  static String normalizedTtsLanguageCodeFor(
    List<TtsVoiceLanguage> languages,
    List<TtsVoiceOption> voices,
    String languageCode,
    String voice,
  ) {
    if (languages.any((language) => language.code == languageCode)) {
      return languageCode;
    }

    final voiceLanguage = voices
        .where((option) => option.voice == voice)
        .firstOrNull
        ?.languageCode;
    if (voiceLanguage != null) return voiceLanguage;

    final baseLanguage = languageCode.split('-').first;
    return languages
            .where(
              (language) => language.code.split('-').first == baseLanguage,
            )
            .firstOrNull
            ?.code ??
        'it-IT';
  }

  static String _preferredEdgeVoice(String languageCode) {
    return switch (languageCode) {
      'it' || 'it-IT' => 'it-IT-IsabellaNeural',
      'en' || 'en-US' => 'en-US-JennyNeural',
      'es' || 'es-ES' => 'es-ES-ElviraNeural',
      'fr' || 'fr-FR' => 'fr-FR-DeniseNeural',
      'de' || 'de-DE' => 'de-DE-KatjaNeural',
      _ => '',
    };
  }

  static String _edgeVoiceLabel(String shortName, String locale) {
    var name = shortName;
    final localePrefix = '$locale-';
    if (name.startsWith(localePrefix)) {
      name = name.substring(localePrefix.length);
    }
    if (name.endsWith('Neural')) {
      name = name.substring(0, name.length - 'Neural'.length);
    }
    name = name.replaceAll('Multilingual', ' Multilingual');
    return '$name ($locale)';
  }

  static String _edgeLanguageLabel(String locale, String friendlyName) {
    final separatorIndex = friendlyName.lastIndexOf(' - ');
    if (separatorIndex == -1) return locale;

    final label = friendlyName.substring(separatorIndex + 3).trim();
    return label.isEmpty ? locale : '$label ($locale)';
  }

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

  // --- Media Volume ---

  static const _mediaVolumeKey = 'sonarpad_media_volume';

  Future<double> loadMediaVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_mediaVolumeKey) ?? 1.0;
  }

  Future<void> saveMediaVolume(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_mediaVolumeKey, value);
  }

  // --- Video ---

  static const _videoEnabledKey = 'sonarpad_video_enabled';

  Future<bool> isVideoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_videoEnabledKey) ?? false;
  }

  Future<void> setVideoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_videoEnabledKey, value);
  }
  // --- Grouping Home ---

  static const _homeGroupingEnabledKey = 'sonarpad_home_grouping_enabled';

  Future<bool> isHomeGroupingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_homeGroupingEnabledKey) ?? true;
  }

  Future<void> setHomeGroupingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeGroupingEnabledKey, value);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
