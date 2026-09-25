import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../tts/edge_tts_bridge.dart';
import '../utils/app_logger.dart';
import 'app_cache_service.dart';
import 'app_settings_service.dart';
import 'audio_description_fallbacks.dart';
import 'pyannote_mobile_service.dart';
import 'voice_dictionary_service.dart';

class AiAudioDescriptionSettings {
  const AiAudioDescriptionSettings({
    required this.provider,
    required this.geminiApiKey,
    required this.sonarpadCode,
    required this.geminiModel,
    required this.languageCode,
    required this.verbosity,
    required this.allowExtendedPauses,
    required this.recognizeCharacters,
    required this.recognizeScreenText,
    required this.keepCharacterCatalog,
    required this.characterCatalogName,
    required this.saveProject,
    required this.ttsEngine,
    required this.edgeLanguage,
    required this.edgeVoice,
    required this.systemLanguage,
    required this.systemVoice,
  });

  final String provider;
  final String geminiApiKey;
  final String sonarpadCode;
  final String geminiModel;
  final String languageCode;
  final String verbosity;
  final bool allowExtendedPauses;
  final bool recognizeCharacters;
  final bool recognizeScreenText;
  final bool keepCharacterCatalog;
  final String? characterCatalogName;
  final bool saveProject;
  final String ttsEngine;
  final String edgeLanguage;
  final String edgeVoice;
  final String systemLanguage;
  final String? systemVoice;

  AiAudioDescriptionSettings copyWith({String? verbosity, String? geminiModel}) =>
      AiAudioDescriptionSettings(
        provider: provider,
        geminiApiKey: geminiApiKey,
        sonarpadCode: sonarpadCode,
        geminiModel: geminiModel ?? this.geminiModel,
        languageCode: languageCode,
        verbosity: verbosity ?? this.verbosity,
        allowExtendedPauses: allowExtendedPauses,
        recognizeCharacters: recognizeCharacters,
        recognizeScreenText: recognizeScreenText,
        keepCharacterCatalog: keepCharacterCatalog,
        characterCatalogName: characterCatalogName,
        saveProject: saveProject,
        ttsEngine: ttsEngine,
        edgeLanguage: edgeLanguage,
        edgeVoice: edgeVoice,
        systemLanguage: systemLanguage,
        systemVoice: systemVoice,
      );
}

class AiAudioDescriptionProgress {
  const AiAudioDescriptionProgress(this.stage, this.value, {this.detail});
  final String stage;
  final double value;
  final String? detail;
}

class AiAudioDescriptionResult {
  const AiAudioDescriptionResult({
    required this.mp3Path,
    this.projectPath,
    required this.generatedDescriptions,
    required this.insertedDescriptions,
    required this.excludedDescriptions,
    this.characterCatalogWarning,
  });

  final String mp3Path;
  final String? projectPath;
  final int generatedDescriptions;
  final int insertedDescriptions;
  final int excludedDescriptions;
  final String? characterCatalogWarning;

  List<String> get outputPaths => [
        mp3Path,
        ?projectPath,
      ];
}


class AudioDescriptionProjectInterval {
  const AudioDescriptionProjectInterval({required this.startSec, required this.endSec});
  final double startSec;
  final double endSec;

  Map<String, Object?> toJson() => <String, Object?>{
        'start_sec': startSec,
        'end_sec': endSec,
      };
}

class AudioDescriptionProjectItem {
  const AudioDescriptionProjectItem({
    required this.id,
    required this.text,
    required this.originalText,
    required this.renderedText,
    required this.modified,
    required this.geminiStartSec,
    required this.visualEvidenceTimeSec,
    required this.sourceStartSec,
    required this.outputStartSec,
    required this.outputEndSec,
    required this.ttsDurationSec,
    required this.extendedPause,
    required this.extendedPauseDurationSec,
    required this.duckStartSec,
    required this.duckEndSec,
  });

  final int id;
  final String text;
  final String originalText;
  final String renderedText;
  final bool modified;
  final double geminiStartSec;
  final double? visualEvidenceTimeSec;
  final double sourceStartSec;
  final double outputStartSec;
  final double outputEndSec;
  final double ttsDurationSec;
  final bool extendedPause;
  final double extendedPauseDurationSec;
  final double? duckStartSec;
  final double? duckEndSec;

  AudioDescriptionProjectItem copyWith({
    String? text,
    String? renderedText,
    bool? modified,
    double? outputStartSec,
    double? outputEndSec,
    double? ttsDurationSec,
    double? extendedPauseDurationSec,
    double? duckStartSec,
    double? duckEndSec,
    bool clearDuck = false,
  }) =>
      AudioDescriptionProjectItem(
        id: id,
        text: text ?? this.text,
        originalText: originalText,
        renderedText: renderedText ?? this.renderedText,
        modified: modified ?? this.modified,
        geminiStartSec: geminiStartSec,
        visualEvidenceTimeSec: visualEvidenceTimeSec,
        sourceStartSec: sourceStartSec,
        outputStartSec: outputStartSec ?? this.outputStartSec,
        outputEndSec: outputEndSec ?? this.outputEndSec,
        ttsDurationSec: ttsDurationSec ?? this.ttsDurationSec,
        extendedPause: extendedPause,
        extendedPauseDurationSec:
            extendedPauseDurationSec ?? this.extendedPauseDurationSec,
        duckStartSec: clearDuck ? null : (duckStartSec ?? this.duckStartSec),
        duckEndSec: clearDuck ? null : (duckEndSec ?? this.duckEndSec),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'text': text,
        'original_text': originalText,
        'rendered_text': renderedText,
        'modified': modified,
        'gemini_start_sec': geminiStartSec,
        if (visualEvidenceTimeSec != null)
          'visual_evidence_time_sec': visualEvidenceTimeSec,
        'source_start_sec': sourceStartSec,
        'output_start_sec': outputStartSec,
        'output_end_sec': outputEndSec,
        'tts_duration_sec': ttsDurationSec,
        'extended_pause': extendedPause,
        'extended_pause_duration_sec': extendedPauseDurationSec,
        'duck_start_sec': duckStartSec,
        'duck_end_sec': duckEndSec,
      };
}

class AudioDescriptionEditableProject {
  const AudioDescriptionEditableProject({
    required this.projectPath,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.sourcePath,
    required this.outputMp3Path,
    required this.sourceDurationSec,
    required this.outputDurationSec,
    required this.languageCode,
    required this.verbosity,
    required this.allowExtendedPauses,
    required this.recognizeCharacters,
    required this.recognizeScreenText,
    required this.geminiModel,
    required this.ttsEngine,
    required this.ttsVoice,
    required this.edgeLanguage,
    required this.systemLanguage,
    required this.systemVoice,
    required this.ttsSpeed,
    required this.ttsPitch,
    required this.bitrateKbps,
    required this.duckingDb,
    required this.fadeMs,
    required this.protectedIntervals,
    required this.descriptions,
    required this.excludedDescriptions,
  });

  final String projectPath;
  final String createdAtUtc;
  final String updatedAtUtc;
  final String sourcePath;
  final String outputMp3Path;
  final double sourceDurationSec;
  final double outputDurationSec;
  final String languageCode;
  final String verbosity;
  final bool allowExtendedPauses;
  final bool recognizeCharacters;
  final bool recognizeScreenText;
  final String geminiModel;
  final String ttsEngine;
  final String ttsVoice;
  final String edgeLanguage;
  final String systemLanguage;
  final String? systemVoice;
  final double ttsSpeed;
  final double ttsPitch;
  final int bitrateKbps;
  final double duckingDb;
  final int fadeMs;
  final List<AudioDescriptionProjectInterval> protectedIntervals;
  final List<AudioDescriptionProjectItem> descriptions;
  final List<Map<String, Object?>> excludedDescriptions;

  AudioDescriptionEditableProject copyWith({
    String? projectPath,
    String? updatedAtUtc,
    String? sourcePath,
    String? outputMp3Path,
    double? outputDurationSec,
    String? ttsEngine,
    String? ttsVoice,
    String? edgeLanguage,
    String? systemLanguage,
    String? systemVoice,
    bool clearSystemVoice = false,
    double? ttsSpeed,
    double? ttsPitch,
    List<AudioDescriptionProjectItem>? descriptions,
    List<Map<String, Object?>>? excludedDescriptions,
  }) =>
      AudioDescriptionEditableProject(
        projectPath: projectPath ?? this.projectPath,
        createdAtUtc: createdAtUtc,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
        sourcePath: sourcePath ?? this.sourcePath,
        outputMp3Path: outputMp3Path ?? this.outputMp3Path,
        sourceDurationSec: sourceDurationSec,
        outputDurationSec: outputDurationSec ?? this.outputDurationSec,
        languageCode: languageCode,
        verbosity: verbosity,
        allowExtendedPauses: allowExtendedPauses,
        recognizeCharacters: recognizeCharacters,
        recognizeScreenText: recognizeScreenText,
        geminiModel: geminiModel,
        ttsEngine: ttsEngine ?? this.ttsEngine,
        ttsVoice: ttsVoice ?? this.ttsVoice,
        edgeLanguage: edgeLanguage ?? this.edgeLanguage,
        systemLanguage: systemLanguage ?? this.systemLanguage,
        systemVoice:
            clearSystemVoice ? null : (systemVoice ?? this.systemVoice),
        ttsSpeed: ttsSpeed ?? this.ttsSpeed,
        ttsPitch: ttsPitch ?? this.ttsPitch,
        bitrateKbps: bitrateKbps,
        duckingDb: duckingDb,
        fadeMs: fadeMs,
        protectedIntervals: protectedIntervals,
        descriptions: descriptions ?? this.descriptions,
        excludedDescriptions: excludedDescriptions ?? this.excludedDescriptions,
      );

  String get windowsLanguageCode {
    final value = languageCode.replaceAll('_', '-');
    if (value.toLowerCase() == 'pt-br') return 'pt-BR';
    if (value.toLowerCase().startsWith('zh')) return 'zh';
    return value.split('-').first.toLowerCase();
  }

  Map<String, Object?> toJson() {
    final windowsEngine = switch (ttsEngine) {
      'system' => 'edge',
      'edge' => 'edge',
      _ => ttsEngine,
    };
    final windowsVoice = ttsEngine == 'system' ? '' : ttsVoice;
    return <String, Object?>{
      'format': 'sonarpad-audio-description-project',
      'version': 1,
      'created_at_utc': createdAtUtc,
      'updated_at_utc': updatedAtUtc,
      'source_path': sourcePath,
      'output_mp3_path': outputMp3Path,
      'output_is_video': false,
      'audio_stream_index': null,
      'source_duration_sec': sourceDurationSec,
      'output_duration_sec': outputDurationSec,
      'language': windowsLanguageCode,
      'language_code': windowsLanguageCode,
      'verbosity': verbosity,
      'allow_extended_pauses': allowExtendedPauses,
      'recognize_characters': recognizeCharacters,
      'recognize_screen_text': recognizeScreenText,
      'gemini_model': geminiModel,
      'tts_engine': windowsEngine,
      'tts_voice': windowsVoice,
      'tts_rate': 0,
      'tts_pitch': 0,
      'tts_volume': 100,
      'dictionary': const <Object?>[],
      'bitrate_kbps': bitrateKbps,
      'ducking_db': duckingDb,
      'fade_ms': fadeMs,
      'protected_intervals': protectedIntervals.map((e) => e.toJson()).toList(),
      'descriptions': descriptions.map((e) => e.toJson()).toList(),
      'excluded_descriptions': excludedDescriptions,
      // Mobile-only metadata. Serde on Windows ignores unknown fields, while
      // keeping system voices fully reconstructable on iOS/Android.
      'mobile_tts_engine': ttsEngine,
      'mobile_tts_voice': ttsVoice,
      'mobile_edge_language': edgeLanguage,
      'mobile_system_language': systemLanguage,
      'mobile_system_voice': systemVoice,
      'mobile_tts_speed': ttsSpeed,
      'mobile_tts_pitch': ttsPitch,
    };
  }
}

class AudioDescriptionProjectPreview {
  const AudioDescriptionProjectPreview({
    required this.path,
    required this.durationSec,
    required this.availableSec,
  });
  final String path;
  final double durationSec;
  final double? availableSec;
}

class AudioDescriptionProjectExportResult {
  const AudioDescriptionProjectExportResult({
    required this.mp3Path,
    required this.projectPath,
    required this.project,
  });
  final String mp3Path;
  final String projectPath;
  final AudioDescriptionEditableProject project;
  List<String> get outputPaths => <String>[mp3Path, projectPath];
}

class AudioDescriptionProjectTooLongException implements Exception {
  const AudioDescriptionProjectTooLongException({
    required this.index,
    required this.availableSec,
    required this.actualSec,
  });
  final int index;
  final double availableSec;
  final double actualSec;

  @override
  String toString() =>
      'AUDIO_DESCRIPTION_PROJECT_TOO_LONG index=$index actual=$actualSec available=$availableSec';
}

class AiAudioDescriptionPreferences {
  AiAudioDescriptionPreferences._();

  static const _providerKey = 'ad_mobile_provider';
  static const _apiKeyKey = 'ad_mobile_gemini_api_key';
  static const _modelKey = 'ad_mobile_gemini_model';
  static const _languageKey = 'ad_mobile_language';
  static const _verbosityKey = 'ad_mobile_verbosity';
  static const _extendedKey = 'ad_mobile_extended';
  static const _charactersKey = 'ad_mobile_characters';
  static const _screenTextKey = 'ad_mobile_screen_text';
  static const _keepCatalogKey = 'ad_mobile_keep_character_catalog';
  static const _catalogNameKey = 'ad_mobile_character_catalog_name';
  static const _projectKey = 'ad_mobile_project';
  static const _ttsEngineKey = 'ad_mobile_tts_engine';
  static const _edgeLanguageKey = 'ad_mobile_edge_language';
  static const _edgeVoiceKey = 'ad_mobile_edge_voice';
  static const _systemLanguageKey = 'ad_mobile_system_language';
  static const _systemVoiceKey = 'ad_mobile_system_voice';
  static const _tokenKey = 'ad_mobile_sonarpad_token';
  static const _deviceIdKey = 'ad_mobile_sonarpad_device_id';

  static Future<Map<String, Object?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return <String, Object?>{
      'provider': prefs.getString(_providerKey) ?? 'gemini',
      'apiKey': prefs.getString(_apiKeyKey) ?? '',
      'model': prefs.getString(_modelKey) ?? 'gemini-3.5-flash-lite',
      'language': prefs.getString(_languageKey) ?? 'it',
      'verbosity': prefs.getString(_verbosityKey) ?? 'detailed',
      'extended': prefs.getBool(_extendedKey) ?? true,
      'characters': prefs.getBool(_charactersKey) ?? true,
      'screenText': prefs.getBool(_screenTextKey) ?? false,
      'keepCatalog': prefs.getBool(_keepCatalogKey) ?? false,
      'catalogName': prefs.getString(_catalogNameKey),
      'project': prefs.getBool(_projectKey) ?? false,
      'ttsEngine': prefs.getString(_ttsEngineKey),
      'edgeLanguage': prefs.getString(_edgeLanguageKey),
      'edgeVoice': prefs.getString(_edgeVoiceKey),
      'systemLanguage': prefs.getString(_systemLanguageKey),
      'systemVoice': prefs.getString(_systemVoiceKey),
    };
  }

  static Future<void> save(AiAudioDescriptionSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, settings.provider);
    if (settings.geminiApiKey.trim().isNotEmpty) {
      await prefs.setString(_apiKeyKey, settings.geminiApiKey.trim());
    }
    await prefs.setString(_modelKey, settings.geminiModel.trim());
    await prefs.setString(_languageKey, settings.languageCode);
    await prefs.setString(_verbosityKey, settings.verbosity);
    await prefs.setBool(_extendedKey, settings.allowExtendedPauses);
    await prefs.setBool(_charactersKey, settings.recognizeCharacters);
    await prefs.setBool(_screenTextKey, settings.recognizeScreenText);
    await prefs.setBool(
      _keepCatalogKey,
      settings.recognizeCharacters && settings.keepCharacterCatalog,
    );
    if (settings.characterCatalogName == null ||
        settings.characterCatalogName!.trim().isEmpty) {
      await prefs.remove(_catalogNameKey);
    } else {
      await prefs.setString(_catalogNameKey, settings.characterCatalogName!.trim());
    }
    await prefs.setBool(_projectKey, settings.saveProject);
    await prefs.setString(_ttsEngineKey, settings.ttsEngine);
    await prefs.setString(_edgeLanguageKey, settings.edgeLanguage);
    await prefs.setString(_edgeVoiceKey, settings.edgeVoice);
    await prefs.setString(_systemLanguageKey, settings.systemLanguage);
    if (settings.systemVoice == null || settings.systemVoice!.trim().isEmpty) {
      await prefs.remove(_systemVoiceKey);
    } else {
      await prefs.setString(_systemVoiceKey, settings.systemVoice!);
    }
  }

  static Future<String?> loadSonarpadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_tokenKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> saveGeminiModel(String value) async {
    final model = AudioDescriptionFallbacks.normalizeGeminiModelId(value);
    if (model.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model);
  }

  static Future<void> saveSonarpadToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, value);
  }

  static Future<void> clearSonarpadToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var value = prefs.getString(_deviceIdKey)?.trim() ?? '';
    if (value.isEmpty) {
      value = const Uuid().v4();
      await prefs.setString(_deviceIdKey, value);
    }
    return value;
  }
}


enum AiAudioDescriptionWaitDecision { continueWaiting, stop }

enum AiAudioDescriptionQuotaAction { switchModel, continueWaiting, stop }

class AiAudioDescriptionQuotaDecision {
  const AiAudioDescriptionQuotaDecision(this.action, {this.model});
  final AiAudioDescriptionQuotaAction action;
  final String? model;
}

typedef AiAudioDescriptionHighDemandCallback = Future<AiAudioDescriptionWaitDecision> Function();
typedef AiAudioDescriptionQuotaCallback = Future<AiAudioDescriptionQuotaDecision> Function(
  String currentModel,
  Set<String> exhaustedModels,
);
typedef AiAudioDescriptionBriefRetryCallback = Future<bool> Function();
typedef AiAudioDescriptionOverlapConsentCallback = Future<bool> Function();
typedef AiAudioDescriptionResumeCallback = Future<bool> Function(String checkpointPath);

class AiAudioDescriptionService {
  AiAudioDescriptionService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _sonarpadAiBase = 'https://sonarpad.com/sonarpad-ai/v1';
  static const _geminiBase = 'https://generativelanguage.googleapis.com/v1beta';
  static const _geminiUploadBase =
      'https://generativelanguage.googleapis.com/upload/v1beta';
  static const _visualChunkSeconds = 180.0;
  // -12 dB, same ducking level used by Sonarpad Windows.
  static const _duckVolume = 0.251188643150958;
  static const _extendedTailPadding = 0.12;

  final http.Client _http;
  final Set<String> _validatedGeminiModels = <String>{};
  bool _cancelRequested = false;

  void cancel() {
    _cancelRequested = true;
    unawaited(FFmpegKit.cancel());
  }

  void dispose() {
    _http.close();
  }

  Future<List<String>> fetchGeminiModels(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) throw StateError('GEMINI_API_KEY_REQUIRED');
    final uri = Uri.parse('$_geminiBase/models').replace(
      queryParameters: <String, String>{'key': key},
    );
    final response = await _http.get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Gemini models HTTP ${response.statusCode}: ${_short(response.body)}',
      );
    }
    final decoded = jsonDecode(response.body);
    final models = <String>[];
    if (decoded is Map && decoded['models'] is List) {
      for (final raw in decoded['models'] as List) {
        if (raw is! Map) continue;
        final methods = raw['supportedGenerationMethods'];
        if (methods is List && !methods.map((e) => '$e').contains('generateContent')) {
          continue;
        }
        final name = AudioDescriptionFallbacks.normalizeGeminiModelId(
          raw['name']?.toString() ?? '',
        );
        final lower = name.toLowerCase();
        if (name.isNotEmpty &&
            AudioDescriptionFallbacks.modelSupportsGenerateContent(raw) &&
            lower.contains('gemini') &&
            !lower.contains('embedding')) {
          models.add(name);
        }
      }
    }
    models.sort();
    return models.toSet().toList();
  }

  Future<String> activateSonarpadAi(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) throw StateError('SONARPAD_AI_CODE_REQUIRED');
    final response = await _http
        .post(
          Uri.parse('$_sonarpadAiBase/activate'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'Sonarpad-Mobile-AI/1',
          },
          body: jsonEncode(<String, Object?>{
            'code': trimmed,
            'device_id': await AiAudioDescriptionPreferences.deviceId(),
            'device_name': '${Platform.operatingSystem} Sonarpad Mobile',
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Sonarpad AI HTTP ${response.statusCode}: ${_short(response.body)}',
      );
    }
    final decoded = jsonDecode(response.body);
    final token = _findString(decoded, const ['session_token', 'token']);
    if (token == null || token.isEmpty) {
      throw StateError('SONARPAD_AI_TOKEN_MISSING');
    }
    await AiAudioDescriptionPreferences.saveSonarpadToken(token);
    return token;
  }

  Future<Directory> _characterCatalogDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Audiodescriptions', 'Catalogs'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  String _catalogFileStem(String name) {
    var value = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .trim();
    value = value.replaceAll(RegExp(r'[. ]+$'), '').trim();
    if (value.isEmpty) value = 'characters';
    if (value.length > 120) value = value.substring(0, 120);
    return value;
  }

  Future<List<String>> listCharacterCatalogs() async {
    final directory = await _characterCatalogDirectory();
    final catalogs = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || p.extension(entity.path).toLowerCase() != '.json') {
        continue;
      }
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is Map &&
            decoded['format']?.toString() == 'sonarpad-character-catalog' &&
            (decoded['version'] is num) &&
            (decoded['version'] as num).toInt() > 0) {
          final name = decoded['name']?.toString().trim() ?? '';
          catalogs.add(name.isEmpty ? p.basenameWithoutExtension(entity.path) : name);
        }
      } catch (_) {
        // Ignore invalid files; they must not break the creation screen.
      }
    }
    catalogs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return catalogs.toSet().toList();
  }

  Future<List<Map<String, Object?>>> loadCharacterCatalog(String name) async {
    final directory = await _characterCatalogDirectory();
    final file = File(p.join(directory.path, '${_catalogFileStem(name)}.json'));
    if (!await file.exists()) return <Map<String, Object?>>[];
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map ||
        decoded['format']?.toString() != 'sonarpad-character-catalog' ||
        decoded['characters'] is! List) {
      throw const FormatException('Unsupported Sonarpad character catalog');
    }
    return _normalizeCatalogCharacters(decoded['characters'] as List);
  }

  Future<void> saveCharacterCatalog(
    String name,
    List<Map<String, Object?>> characters,
  ) async {
    final directory = await _characterCatalogDirectory();
    final file = File(p.join(directory.path, '${_catalogFileStem(name)}.json'));
    String? createdAt;
    List<Map<String, Object?>> established = <Map<String, Object?>>[];
    if (await file.exists()) {
      try {
        final old = jsonDecode(await file.readAsString());
        if (old is Map) {
          createdAt = old['created_at_utc']?.toString();
          if (old['characters'] is List) {
            established = _normalizeCatalogCharacters(old['characters'] as List);
          }
        }
      } catch (_) {}
    }
    final merged = _mergeCatalogForPersistence(established, characters);
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'format': 'sonarpad-character-catalog',
      'version': 1,
      'name': name.trim(),
      'created_at_utc': createdAt?.trim().isNotEmpty == true ? createdAt : now,
      'updated_at_utc': now,
      'characters': merged,
    };
    final temporary = File('${file.path}.new');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    await AppLogger.log(
      'Audio description mobile: character catalog saved '
      'name="${name.trim()}" entries=${merged.length}',
    );
  }

  List<Map<String, Object?>> _normalizeCatalogCharacters(List<dynamic> input) {
    final byKey = <String, Map<String, Object?>>{};
    for (final raw in input) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString().trim() ?? '';
      final name = raw['name']?.toString().trim() ?? '';
      final description = raw['description']?.toString().trim() ?? '';
      if (name.isEmpty || description.isEmpty) continue;
      final normalized = <String, Object?>{
        'id': id.isEmpty ? _safeCharacterId(name) : id,
        'name': name.replaceAll(RegExp(r'\s+'), ' '),
        'description': description.replaceAll(RegExp(r'\s+'), ' '),
      };
      final key = normalized['name'].toString().toLowerCase();
      final previous = byKey[key];
      if (previous == null ||
          normalized['description'].toString().length >
              previous['description'].toString().length) {
        byKey[key] = normalized;
      }
    }
    return byKey.values.take(96).toList();
  }

  List<Map<String, Object?>> _mergeCatalogForPersistence(
    List<Map<String, Object?>> established,
    List<Map<String, Object?>> incoming,
  ) {
    return AudioDescriptionFallbacks.mergeCharacterCatalog(
      _normalizeCatalogCharacters(established),
      _normalizeCatalogCharacters(incoming),
      maxCharacters: 96,
    );
  }

  String _safeCharacterId(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  Future<AiAudioDescriptionResult> create({
    required String sourcePath,
    required AiAudioDescriptionSettings settings,
    required void Function(AiAudioDescriptionProgress progress) onProgress,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
    AiAudioDescriptionBriefRetryCallback? onBriefRetry,
    AiAudioDescriptionOverlapConsentCallback? onOverlapConsent,
    AiAudioDescriptionResumeCallback? onResumeCheckpoint,
  }) async {
    _cancelRequested = false;
    final source = File(sourcePath);
    if (!await source.exists()) throw StateError('AUDIO_DESCRIPTION_SOURCE_MISSING');
    await AiAudioDescriptionPreferences.save(settings);

    final operationDir = await _createOperationDirectory();
    final canonicalWav = p.join(operationDir.path, 'analysis.wav');
    final ttsDir = Directory(p.join(operationDir.path, 'tts'));
    final chunksDir = Directory(p.join(operationDir.path, 'visual_chunks'));
    await ttsDir.create(recursive: true);
    await chunksDir.create(recursive: true);

    bool? oldWakelock;
    try {
      oldWakelock = await WakelockPlus.enabled;
      await WakelockPlus.enable();
      await AppLogger.log(
        'Audio description mobile: wakelock enabled previous=$oldWakelock',
      );
    } catch (error, stackTrace) {
      oldWakelock = null;
      await AppLogger.log(
        'Audio description mobile: wakelock enable failed error=$error\n$stackTrace',
      );
    }

    try {
      _emit(onProgress, 'preparing', 0.01);
      final probe = await _probe(sourcePath);
      _checkCancel();
      await _prepareCanonicalWav(
        sourcePath: sourcePath,
        outputPath: canonicalWav,
        durationSec: probe.durationSec,
        hasAudio: probe.hasAudio,
      );

      _emit(onProgress, 'pyannote', 0.06);
      final pyannote = await PyannoteMobileService.instance.analyzeCanonicalWav(
        canonicalWav,
        paddingSec: PyannoteMobileService.defaultPaddingSec,
        onProgress: (value) {
          _emit(onProgress, 'pyannote', 0.06 + value * 0.16);
        },
      );
      _checkCancel();

      final slots = _safeSlots(pyannote.durationSec, pyannote.protectedIntervals);
      await AppLogger.log(
        'Audio description mobile: pyannote complete duration=${pyannote.durationSec.toStringAsFixed(3)} '
        'protected=${pyannote.protectedIntervals.length} slots=${slots.length}',
      );

      final token = settings.provider == 'sonarpad'
          ? await _ensureSonarpadToken(settings.sonarpadCode)
          : null;
      final chunkCount = math.max(
        1,
        (pyannote.durationSec / _visualChunkSeconds).ceil(),
      );
      final descriptions = <_GeneratedDescription>[];
      final glossary = settings.recognizeCharacters &&
              settings.keepCharacterCatalog &&
              settings.characterCatalogName != null
          ? await loadCharacterCatalog(settings.characterCatalogName!)
          : <Map<String, Object?>>[];
      var activeGeminiModel = AudioDescriptionFallbacks.normalizeGeminiModelId(
        settings.geminiModel,
      );
      var startChunk = 0;

      final checkpoint = await _loadCheckpoint(
        sourcePath: sourcePath,
        durationSec: pyannote.durationSec,
        chunkCount: chunkCount,
      );
      if (checkpoint != null) {
        final resume = onResumeCheckpoint == null
            ? true
            : await onResumeCheckpoint(checkpoint.path);
        if (resume) {
          startChunk = checkpoint.completedChunks.clamp(0, chunkCount);
          descriptions.addAll(checkpoint.descriptions);
          _mergeGlossary(glossary, checkpoint.glossary);
          if (checkpoint.model.trim().isNotEmpty && settings.provider == 'gemini') {
            activeGeminiModel = AudioDescriptionFallbacks.normalizeGeminiModelId(
              checkpoint.model,
            );
          }
          await AppLogger.log(
            'Audio description mobile: resumed checkpoint chunks=$startChunk/$chunkCount '
            'descriptions=${descriptions.length}',
          );
        } else {
          await _deleteCheckpoint(sourcePath);
        }
      }

      if (glossary.isNotEmpty) {
        await AppLogger.log(
          'Audio description mobile: loaded/merged character catalog '
          'name="${settings.characterCatalogName}" entries=${glossary.length}',
        );
      }

      for (var chunkIndex = startChunk; chunkIndex < chunkCount; chunkIndex++) {
        _checkCancel();
        final chunkStart = chunkIndex * _visualChunkSeconds;
        final chunkEnd = math.min(
          pyannote.durationSec,
          chunkStart + _visualChunkSeconds,
        );
        final chunkSlots = slots.where((slot) {
          final midpoint = (slot.start + slot.end) / 2.0;
          return midpoint >= chunkStart && midpoint < chunkEnd;
        }).toList();

        if (chunkSlots.isNotEmpty) {
          _emit(
            onProgress,
            'preparing_chunk',
            0.23 + (chunkIndex / chunkCount) * 0.30,
            detail: '${chunkIndex + 1}/$chunkCount',
          );
          _emit(
            onProgress,
            'gemini',
            0.25 + (chunkIndex / chunkCount) * 0.34,
            detail: '${chunkIndex + 1}/$chunkCount',
          );
          final processed = await _processChunkWithFallbacks(
            sourcePath: sourcePath,
            chunksDir: chunksDir,
            chunkIndex: chunkIndex,
            chunkStart: chunkStart,
            chunkEnd: chunkEnd,
            hasAudio: probe.hasAudio,
            settings: settings,
            sonarpadToken: token,
            activeGeminiModel: activeGeminiModel,
            chunkSlots: chunkSlots,
            glossary: glossary,
            onHighDemand: onHighDemand,
            onQuota: onQuota,
          );
          if (settings.provider == 'gemini' &&
              processed.model.trim().isNotEmpty &&
              processed.model != activeGeminiModel) {
            activeGeminiModel = processed.model;
            await AiAudioDescriptionPreferences.saveGeminiModel(activeGeminiModel);
          } else {
            activeGeminiModel = processed.model;
          }
          descriptions.addAll(processed.parsed.descriptions);
          if (settings.recognizeCharacters) {
            _mergeGlossary(glossary, processed.parsed.glossary);
          }
          await AppLogger.log(
            'Audio description mobile: chunk ${chunkIndex + 1}/$chunkCount '
            'parsed=${processed.parsed.descriptions.length} glossary=${glossary.length} '
            'model=$activeGeminiModel',
          );
        }

        // Checkpoint only after the chunk is fully accepted. Cancellation or
        // later failures therefore resume from the last known-good boundary.
        await _saveCheckpoint(
          sourcePath: sourcePath,
          durationSec: pyannote.durationSec,
          chunkCount: chunkCount,
          completedChunks: chunkIndex + 1,
          geminiModel: activeGeminiModel,
          descriptions: descriptions,
          glossary: glossary,
        );
      }

      _checkCancel();
      var normalized = _dedupeDescriptions(descriptions);
      if (normalized.isEmpty) {
        throw StateError('AUDIO_DESCRIPTION_NO_DESCRIPTIONS');
      }

      _emit(onProgress, 'tts', 0.61);
      var placementSettings = settings;
      var placements = await _synthesizeAndPlace(
        settings: placementSettings,
        descriptions: normalized,
        slots: slots,
        ttsDir: ttsDir,
        mediaDurationSec: pyannote.durationSec,
        onProgress: onProgress,
      );
      _checkCancel();

      var inserted = placements.where((item) => item.included).toList();
      var excluded = placements.where((item) => !item.included).toList();
      var safeSpaceExhausted = AudioDescriptionFallbacks.shouldEscalateNoSafeSpace(
        excluded.map((item) => item.reason),
      );
      var mayOfferOverlap = settings.verbosity == 'short' && safeSpaceExhausted;

      // Windows parity: when the normal analysis generated usable visual
      // descriptions but none fit safely, offer one isolated Brief retry
      // BEFORE ever asking permission to narrate over dialogue. Declining the
      // Brief retry ends safely; it must not silently escalate to overlap.
      if (inserted.isEmpty &&
          safeSpaceExhausted &&
          settings.verbosity != 'short' &&
          onBriefRetry != null) {
        final retryBrief = await onBriefRetry();
        _checkCancel();
        if (retryBrief) {
          _emit(onProgress, 'brief_retry', 0.55);
          final briefSettings = settings.copyWith(verbosity: 'short');
          final brief = await _runBriefVisualRetry(
            sourcePath: sourcePath,
            probe: probe,
            settings: briefSettings,
            slots: slots,
            chunksDir: chunksDir,
            sonarpadToken: token,
            initialGeminiModel: activeGeminiModel,
            initialGlossary: glossary,
            onProgress: onProgress,
            onHighDemand: onHighDemand,
            onQuota: onQuota,
          );
          normalized = brief.descriptions;
          activeGeminiModel = brief.model;
          if (settings.provider == 'gemini' && activeGeminiModel.isNotEmpty) {
            await AiAudioDescriptionPreferences.saveGeminiModel(activeGeminiModel);
          }
          if (settings.recognizeCharacters) {
            glossary
              ..clear()
              ..addAll(brief.glossary);
          }
          if (normalized.isNotEmpty) {
            placementSettings = briefSettings;
            placements = await _synthesizeAndPlace(
              settings: placementSettings,
              descriptions: normalized,
              slots: slots,
              ttsDir: ttsDir,
              mediaDurationSec: pyannote.durationSec,
              onProgress: onProgress,
            );
            inserted = placements.where((item) => item.included).toList();
            excluded = placements.where((item) => !item.included).toList();
            safeSpaceExhausted =
                AudioDescriptionFallbacks.shouldEscalateNoSafeSpace(
              excluded.map((item) => item.reason),
            );
            mayOfferOverlap = inserted.isEmpty && safeSpaceExhausted;
          } else {
            mayOfferOverlap = false;
          }
          await AppLogger.log(
            'Audio description mobile: isolated Brief retry completed '
            'generated=${normalized.length} inserted=${inserted.length}',
          );
        } else {
          await AppLogger.log(
            'Audio description mobile: isolated Brief retry declined; '
            'dialogue-overlap fallback will not be offered',
          );
          mayOfferOverlap = false;
        }
      }

      if (inserted.isEmpty && mayOfferOverlap && onOverlapConsent != null) {
        final consent = await onOverlapConsent();
        _checkCancel();
        if (consent) {
          placements = await _synthesizeAndPlace(
            settings: placementSettings,
            descriptions: normalized,
            slots: slots,
            ttsDir: ttsDir,
            mediaDurationSec: pyannote.durationSec,
            onProgress: onProgress,
            allowDialogueOverlap: true,
          );
          inserted = placements.where((item) => item.included).toList();
          excluded = placements.where((item) => !item.included).toList();
          await AppLogger.log(
            'Audio description mobile: explicit dialogue-overlap fallback '
            'accepted inserted=${inserted.length}',
          );
        }
      }
      if (inserted.isEmpty) {
        final unexpectedPlacementFailure = excluded.any(
          (item) => item.reason != 'no_safe_space_after_exact_tts' &&
              item.reason != 'dialogue_overlap_shift_exceeded',
        );
        if (unexpectedPlacementFailure) {
          throw StateError('AUDIO_DESCRIPTION_TTS_OR_PLACEMENT_FAILED');
        }
        throw StateError('AUDIO_DESCRIPTION_NO_FITTING_DESCRIPTIONS');
      }

      _emit(onProgress, 'mixing', 0.88);
      final cleanBase = _safeBaseName(p.basenameWithoutExtension(sourcePath));
      final outputPath = p.join(operationDir.path, '${cleanBase}_audiodescritto.mp3');
      await _renderFinalMp3(
        sourcePath: sourcePath,
        outputPath: outputPath,
        sourceDurationSec: probe.durationSec,
        hasAudio: probe.hasAudio,
        placements: inserted,
      );
      final output = File(outputPath);
      if (!await output.exists() || await output.length() < 1024) {
        throw StateError('AUDIO_DESCRIPTION_OUTPUT_INVALID');
      }

      String? characterCatalogWarning;
      if (settings.recognizeCharacters &&
          settings.keepCharacterCatalog &&
          settings.characterCatalogName != null &&
          settings.characterCatalogName!.trim().isNotEmpty) {
        try {
          await saveCharacterCatalog(settings.characterCatalogName!, glossary);
        } catch (error, stackTrace) {
          characterCatalogWarning = error.toString();
          await AppLogger.log(
            'Audio description mobile: character catalog save warning '
            'name="${settings.characterCatalogName}" error=$error\n$stackTrace',
          );
        }
      }

      String? projectPath;
      if (settings.saveProject) {
        projectPath = p.join(
          operationDir.path,
          '${cleanBase}_audiodescritto.sonarpad-ad.json',
        );
        await _writeProject(
          projectPath: projectPath,
          sourcePath: sourcePath,
          outputMp3Path: outputPath,
          settings: placementSettings,
          effectiveGeminiModel: activeGeminiModel,
          pyannote: pyannote,
          glossary: glossary,
          placements: placements,
        );
      }

      try {
        if (await File(canonicalWav).exists()) await File(canonicalWav).delete();
        if (await ttsDir.exists()) await ttsDir.delete(recursive: true);
        if (await chunksDir.exists()) await chunksDir.delete(recursive: true);
      } catch (_) {}

      await _deleteCheckpoint(sourcePath);
      _emit(onProgress, 'completed', 1.0);
      return AiAudioDescriptionResult(
        mp3Path: outputPath,
        projectPath: projectPath,
        generatedDescriptions: normalized.length,
        insertedDescriptions: inserted.length,
        excludedDescriptions: excluded.length,
        characterCatalogWarning: characterCatalogWarning,
      );
    } catch (error, stackTrace) {
      await AppLogger.log('Audio description mobile: FAILED $error\n$stackTrace');
      try {
        if (await operationDir.exists()) await operationDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    } finally {
      if (oldWakelock != null) {
        try {
          if (oldWakelock) {
            await WakelockPlus.enable();
          } else {
            await WakelockPlus.disable();
          }
          await AppLogger.log(
            'Audio description mobile: wakelock restored enabled=$oldWakelock',
          );
        } catch (error, stackTrace) {
          await AppLogger.log(
            'Audio description mobile: wakelock restore failed error=$error\n$stackTrace',
          );
        }
      }
    }
  }

  Future<_ProbeInfo> _probe(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final code = await session.getReturnCode();
    final info = session.getMediaInformation();
    if (!ReturnCode.isSuccess(code) || info == null) {
      throw StateError('AUDIO_DESCRIPTION_PROBE_FAILED');
    }
    final measuredDuration = double.tryParse(info.getDuration() ?? '') ?? 0.0;
    final formatStart = double.tryParse(info.getStartTime() ?? '') ?? 0.0;
    final duration = AudioDescriptionFallbacks.normalizeSourceDuration(
      path: path,
      measuredDurationSec: measuredDuration,
      formatStartSec: formatStart,
      chunkSeconds: _visualChunkSeconds,
    );
    if (duration <= 0) throw StateError('AUDIO_DESCRIPTION_DURATION_INVALID');
    if ((duration - measuredDuration).abs() > 0.001) {
      await AppLogger.log(
        'Audio description mobile: normalized Matroska/WebM duration '
        'measured=$measuredDuration start=$formatStart local=$duration',
      );
    }
    final hasAudio = info.getStreams().any((stream) => stream.getType() == 'audio');
    final hasVideo = info.getStreams().any((stream) => stream.getType() == 'video');
    if (!hasVideo) throw StateError('AUDIO_DESCRIPTION_VIDEO_REQUIRED');
    return _ProbeInfo(durationSec: duration, hasAudio: hasAudio);
  }

  Future<void> _prepareCanonicalWav({
    required String sourcePath,
    required String outputPath,
    required double durationSec,
    required bool hasAudio,
  }) async {
    final args = hasAudio
        ? <String>[
            '-y', '-hide_banner', '-loglevel', 'error', '-i', sourcePath,
            '-vn', '-map_metadata', '-1', '-ac', '1', '-ar', '16000',
            '-c:a', 'pcm_s16le', '-f', 'wav', outputPath,
          ]
        : <String>[
            '-y', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi',
            '-i', 'anullsrc=r=16000:cl=mono', '-t', durationSec.toStringAsFixed(3),
            '-c:a', 'pcm_s16le', '-f', 'wav', outputPath,
          ];
    await _runFfmpeg(args, 'canonical wav');
  }

  Future<void> _prepareVisualChunk({
    required String sourcePath,
    required String outputPath,
    required double startSec,
    required double durationSec,
    required bool hasAudio,
    AdMediaFallbackStage stage = AdMediaFallbackStage.normal,
  }) async {
    final isCompact = stage == AdMediaFallbackStage.compact;
    final isCompatibility = stage == AdMediaFallbackStage.compatibility;
    final includeAudio = hasAudio && !isCompatibility;
    final scale = isCompatibility ? 'scale=480:-2,fps=3' :
        isCompact ? 'scale=480:-2,fps=4' : 'scale=640:-2,fps=5';
    final videoBitrate = isCompatibility ? '170k' : isCompact ? '210k' : '300k';
    final maxrate = isCompatibility ? '210k' : isCompact ? '250k' : '360k';
    final bufsize = isCompatibility ? '420k' : isCompact ? '500k' : '720k';

    List<String> command({required bool audio}) => <String>[
      '-y', '-hide_banner', '-loglevel', 'error',
      // Same intent as the native Windows packet-timestamp repair: generate
      // timestamps when AVI/MKV inputs are missing them and discard corrupt
      // packets instead of poisoning the whole chunk.
      '-fflags', '+genpts+discardcorrupt',
      '-ss', startSec.toStringAsFixed(3), '-i', sourcePath,
      '-t', durationSec.toStringAsFixed(3),
      '-map', '0:v:0',
      if (audio) ...['-map', '0:a:0?'],
      '-vf', scale,
      '-c:v', 'mpeg4', '-b:v', videoBitrate,
      '-maxrate', maxrate, '-bufsize', bufsize,
      if (audio) ...['-c:a', 'aac', '-b:a', isCompact ? '48k' : '64k'] else ...['-an'],
      '-avoid_negative_ts', 'make_zero',
      if (!outputPath.toLowerCase().endsWith('.mkv')) ...['-movflags', '+faststart'],
      outputPath,
    ];

    try {
      await _runFfmpeg(command(audio: includeAudio), 'visual chunk ${stage.name}');
    } catch (error) {
      // Windows retries chunk muxing without audio when the visual stream is
      // valid but the source audio header/timestamps break the temporary mux.
      if (!includeAudio) {
        throw _AdProviderException(
          AdFailureKind.fileProcessingFailed,
          'Prepared Gemini video failed: $error',
        );
      }
      await AppLogger.log(
        'Audio description mobile: visual chunk mux with audio failed; '
        'retrying video-only stage=${stage.name} error=$error',
      );
      try {
        if (await File(outputPath).exists()) await File(outputPath).delete();
      } catch (_) {}
      try {
        await _runFfmpeg(
          command(audio: false),
          'visual chunk ${stage.name} video only',
        );
      } catch (videoOnlyError) {
        throw _AdProviderException(
          AdFailureKind.fileProcessingFailed,
          'Prepared Gemini video-only fallback failed: $videoOnlyError',
        );
      }
    }

    final file = File(outputPath);
    if (!await file.exists() || await file.length() <= 0) {
      throw _AdProviderException(
        AdFailureKind.fileProcessingFailed,
        'Prepared Gemini chunk is missing or empty',
      );
    }
    final size = await file.length();
    final limit = stage == AdMediaFallbackStage.normal
        ? AudioDescriptionFallbacks.preferredPreparedChunkBytes
        : AudioDescriptionFallbacks.compatibilityPreparedChunkBytes;
    if (size > limit && stage != AdMediaFallbackStage.compatibility) {
      throw _AdProviderException(
        AdFailureKind.fileProcessingFailed,
        'Prepared Gemini chunk exceeds target size: $size > $limit',
      );
    }
  }

  List<_SafeSlot> _safeSlots(double duration, List<PyannoteInterval> protected) {
    final sorted = List<PyannoteInterval>.of(protected)
      ..sort((a, b) => a.start.compareTo(b.start));
    final result = <_SafeSlot>[];
    var cursor = 0.0;
    var baseIndex = 1;

    void appendGap(double start, double end) {
      final fallbackSlots = AudioDescriptionFallbacks.splitSafeInterval(
        start: start,
        end: end,
        baseIndex: baseIndex,
      );
      if (fallbackSlots.isEmpty) return;
      for (final slot in fallbackSlots) {
        result.add(_SafeSlot(
          id: slot.id,
          start: slot.start,
          end: slot.end,
          mandatory: slot.mandatory,
          maxWords: slot.maxWords,
        ));
      }
      baseIndex++;
    }

    for (final interval in sorted) {
      final start = interval.start.clamp(0.0, duration).toDouble();
      final end = interval.end.clamp(0.0, duration).toDouble();
      if (start > cursor) appendGap(cursor, start);
      if (end > cursor) cursor = end;
    }
    if (duration > cursor) appendGap(cursor, duration);
    return result;
  }

  Future<File> _checkpointFile(String sourcePath) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Sonarpad', 'AudioDescription', 'Checkpoints'),
    );
    await directory.create(recursive: true);
    final source = File(sourcePath);
    final size = await source.length();
    final key = base64Url
        .encode(utf8.encode('${p.basename(sourcePath)}|$size'))
        .replaceAll('=', '');
    final safe = key.length > 80 ? key.substring(0, 80) : key;
    return File(p.join(directory.path, '$safe.partial.json'));
  }

  Future<_AdCheckpoint?> _loadCheckpoint({
    required String sourcePath,
    required double durationSec,
    required int chunkCount,
  }) async {
    final file = await _checkpointFile(sourcePath);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['schema'] != 'sonarpad-mobile-ad-checkpoint-v1') {
        return null;
      }
      final savedDuration = _asDouble(decoded['duration_sec']) ?? -1;
      final savedChunkCount = (decoded['chunk_count'] as num?)?.toInt() ?? -1;
      if (!AudioDescriptionFallbacks.checkpointCompatible(
        savedDurationSec: savedDuration,
        currentDurationSec: durationSec,
        savedChunkCount: savedChunkCount,
        currentChunkCount: chunkCount,
      )) {
        await AppLogger.log(
          'Audio description mobile: checkpoint ignored because media/chunk layout changed',
        );
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      final descriptions = <_GeneratedDescription>[];
      final rawDescriptions = decoded['descriptions'];
      if (rawDescriptions is List) {
        for (final item in rawDescriptions) {
          if (item is! Map) continue;
          final parsed = _GeneratedDescription.fromCheckpoint(item);
          if (parsed != null) descriptions.add(parsed);
        }
      }
      final glossary = <Map<String, Object?>>[];
      final rawGlossary = decoded['glossary'];
      if (rawGlossary is List) {
        for (final item in rawGlossary) {
          if (item is Map) glossary.add(Map<String, Object?>.from(item));
        }
      }
      return _AdCheckpoint(
        path: file.path,
        completedChunks: (decoded['completed_chunks'] as num?)?.toInt() ?? 0,
        model: decoded['gemini_model']?.toString() ?? '',
        descriptions: descriptions,
        glossary: glossary,
      );
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description mobile: invalid checkpoint ignored error=$error\n$stackTrace',
      );
      return null;
    }
  }

  Future<void> _saveCheckpoint({
    required String sourcePath,
    required double durationSec,
    required int chunkCount,
    required int completedChunks,
    required String geminiModel,
    required List<_GeneratedDescription> descriptions,
    required List<Map<String, Object?>> glossary,
  }) async {
    final file = await _checkpointFile(sourcePath);
    final temp = File('${file.path}.new');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schema': 'sonarpad-mobile-ad-checkpoint-v1',
        'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
        'source_file': p.basename(sourcePath),
        'duration_sec': durationSec,
        'chunk_count': chunkCount,
        'completed_chunks': completedChunks,
        'gemini_model': geminiModel,
        'descriptions': descriptions.map((e) => e.toCheckpoint()).toList(),
        'glossary': glossary,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<void> _deleteCheckpoint(String sourcePath) async {
    try {
      final file = await _checkpointFile(sourcePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  String _buildPrompt({
    required AiAudioDescriptionSettings settings,
    required double chunkStart,
    required double chunkEnd,
    required List<_SafeSlot> slots,
    required List<Map<String, Object?>> glossary,
  }) {
    final language = _languageName(settings.languageCode);
    final verbosity = switch (settings.verbosity) {
      'short' => 'Brief: keep descriptions extremely brief (1-3 words maximum). Only describe the most critical visual elements essential for understanding the scene.',
      'standard' => 'Standard: provide balanced descriptions (3-6 words). Focus on important visual information without overwhelming detail.',
      _ => 'Detailed: provide rich descriptions (6-12 words). Include important visual context, emotions, scene details and atmospheric elements while remaining speakable.',
    };
    final slotJson = jsonEncode(slots.map((slot) => slot.toJson()).toList());
    final glossaryJson = settings.recognizeCharacters ? jsonEncode(glossary) : '[]';
    return '''
You generate professional audio descriptions for blind users.
Analyze ONLY the attached video chunk, which represents the original movie timeline from ${chunkStart.toStringAsFixed(3)}s to ${chunkEnd.toStringAsFixed(3)}s.

CRITICAL SAFETY RULES:
1. Never place narration over dialogue. You may use ONLY the safe slots listed below.
2. Each description MUST reference exactly one slot_id and remain inside that slot's start/end time.
3. mandatory=true slots have priority. Cover them when there is meaningful visual information. Optional slots may be left empty.
4. Do not describe spoken dialogue or repeat audible information.
5. evidence_time_sec MUST be a real moment inside the attached video where the described visual event can be seen. It must use the ORIGINAL MOVIE absolute timeline.
6. Do not invent events, names, emotions or objects that are not visually supported.
7. Keep wording short enough to fit the safe slot. Do not merge unrelated events.
8. Output language: $language.
9. Detail level: $verbosity
10. ${settings.recognizeCharacters ? 'Use the existing character glossary when the visual identity is clear. You may add newly identified characters, but avoid guessing.' : 'Do not identify characters by name. Use generic natural references such as the man, the woman, the child, or pronouns.'}
11. ${settings.recognizeScreenText ? 'Read narratively important on-screen text when it is visibly legible and the soundtrack does not already provide it. Prioritize time jumps, dates, locations, title cards, letters/messages and meaningful signs. Never read decorative text, persistent watermarks, routine credits or subtitles that merely repeat dialogue. The narration must still fit entirely inside an authorized safe slot.' : 'Do not add narration merely to read on-screen text.'}

Existing character glossary:
$glossaryJson

Safe slots on the ORIGINAL MOVIE timeline:
$slotJson

Return ONLY valid JSON, without markdown or commentary, exactly in this form:
{
  "character_glossary": [
    {"id":"character-id","name":"Name or null","description":"stable visual description"}
  ],
  "audio_descriptions": [
    {
      "slot_id":"S0001",
      "start_time_sec":12.3,
      "end_time_sec":15.0,
      "evidence_time_sec":13.2,
      "description_text":"...",
      "mandatory":true
    }
  ]
}
If there is nothing useful to describe, return an empty audio_descriptions array.
''';
  }

  Future<_BriefVisualRetryResult> _runBriefVisualRetry({
    required String sourcePath,
    required _ProbeInfo probe,
    required AiAudioDescriptionSettings settings,
    required List<_SafeSlot> slots,
    required Directory chunksDir,
    required String? sonarpadToken,
    required String initialGeminiModel,
    required List<Map<String, Object?>> initialGlossary,
    required void Function(AiAudioDescriptionProgress progress) onProgress,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
  }) async {
    final descriptions = <_GeneratedDescription>[];
    final glossary = initialGlossary
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    var model = AudioDescriptionFallbacks.normalizeGeminiModelId(
      initialGeminiModel,
    );
    final chunkCount = math.max(
      1,
      (probe.durationSec / _visualChunkSeconds).ceil(),
    );
    for (var chunkIndex = 0; chunkIndex < chunkCount; chunkIndex++) {
      _checkCancel();
      final chunkStart = chunkIndex * _visualChunkSeconds;
      final chunkEnd = math.min(
        probe.durationSec,
        chunkStart + _visualChunkSeconds,
      );
      final chunkSlots = slots.where((slot) {
        final midpoint = (slot.start + slot.end) / 2.0;
        return midpoint >= chunkStart && midpoint < chunkEnd;
      }).toList();
      if (chunkSlots.isEmpty) continue;
      _emit(
        onProgress,
        'brief_retry',
        0.55 + (chunkIndex / chunkCount) * 0.25,
        detail: '${chunkIndex + 1}/$chunkCount',
      );
      final processed = await _processChunkWithFallbacks(
        sourcePath: sourcePath,
        chunksDir: chunksDir,
        chunkIndex: chunkIndex,
        chunkStart: chunkStart,
        chunkEnd: chunkEnd,
        hasAudio: probe.hasAudio,
        settings: settings,
        sonarpadToken: sonarpadToken,
        activeGeminiModel: model,
        chunkSlots: chunkSlots,
        glossary: glossary,
        onHighDemand: onHighDemand,
        onQuota: onQuota,
      );
      model = AudioDescriptionFallbacks.normalizeGeminiModelId(
        processed.model,
      );
      descriptions.addAll(processed.parsed.descriptions);
      if (settings.recognizeCharacters) {
        _mergeGlossary(glossary, processed.parsed.glossary);
      }
    }
    return _BriefVisualRetryResult(
      descriptions: _dedupeDescriptions(descriptions),
      glossary: glossary,
      model: model,
    );
  }

  Future<_ChunkProcessResult> _processChunkWithFallbacks({
    required String sourcePath,
    required Directory chunksDir,
    required int chunkIndex,
    required double chunkStart,
    required double chunkEnd,
    required bool hasAudio,
    required AiAudioDescriptionSettings settings,
    required String? sonarpadToken,
    required String activeGeminiModel,
    required List<_SafeSlot> chunkSlots,
    required List<Map<String, Object?>> glossary,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
  }) async {
    var stage = AdMediaFallbackStage.normal;
    _AdProviderException? lastMediaError;
    while (stage != AdMediaFallbackStage.none) {
      _checkCancel();
      final extension = stage == AdMediaFallbackStage.compact ? 'mkv' : 'mp4';
      final chunkPath = p.join(
        chunksDir.path,
        'chunk_${chunkIndex.toString().padLeft(4, '0')}_${stage.name}.$extension',
      );
      try {
        await _prepareVisualChunk(
          sourcePath: sourcePath,
          outputPath: chunkPath,
          startSec: chunkStart,
          durationSec: chunkEnd - chunkStart,
          hasAudio: hasAudio,
          stage: stage,
        );
        final prompt = _buildPrompt(
          settings: settings,
          chunkStart: chunkStart,
          chunkEnd: chunkEnd,
          slots: chunkSlots,
          glossary: glossary,
        );
        final generated = await _generatePreparedChunk(
          chunkPath: chunkPath,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: activeGeminiModel,
          prompt: prompt,
          idempotencyKey: 'ad-${const Uuid().v4()}-$chunkIndex-${stage.name}',
          onHighDemand: onHighDemand,
          onQuota: onQuota,
        );
        var parsed = await _parseWithOptionalJsonRepair(
          generated: generated,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: generated.model,
          chunkStart: chunkStart,
          chunkEnd: chunkEnd,
          slots: chunkSlots,
          onHighDemand: onHighDemand,
          onQuota: onQuota,
        );
        parsed = await _recoverCoverage(
          parsed: parsed,
          chunkPath: chunkPath,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: generated.model,
          chunkStart: chunkStart,
          chunkEnd: chunkEnd,
          chunkSlots: chunkSlots,
          glossary: <Map<String, Object?>>[...glossary, ...parsed.glossary],
          chunkIndex: chunkIndex,
          onHighDemand: onHighDemand,
          onQuota: onQuota,
        );
        parsed = await _correctGeneratedLanguageBestEffort(
          parsed,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: generated.model,
          onHighDemand: onHighDemand,
          onQuota: onQuota,
        );
        return _ChunkProcessResult(parsed: parsed, model: generated.model);
      } on _AdProviderException catch (error) {
        if (error.kind == AdFailureKind.prohibitedContent) {
          await AppLogger.log(
            'Audio description mobile: chunk ${chunkIndex + 1} remains '
            'PROHIBITED_CONTENT; activating 60-second fallback',
          );
          return _blockedChunkMinuteFallback(
            sourcePath: sourcePath,
            chunksDir: chunksDir,
            parentChunkIndex: chunkIndex,
            chunkStart: chunkStart,
            chunkEnd: chunkEnd,
            hasAudio: hasAudio,
            settings: settings,
            sonarpadToken: sonarpadToken,
            activeGeminiModel: activeGeminiModel,
            chunkSlots: chunkSlots,
            glossary: glossary,
            onHighDemand: onHighDemand,
            onQuota: onQuota,
          );
        }
        if (!_isMediaCompatibilityFailure(error)) rethrow;
        lastMediaError = error;
        final next = AudioDescriptionFallbacks.nextMediaStage(
          current: stage,
          failure: error.kind,
        );
        if (next == AdMediaFallbackStage.none) rethrow;
        await AppLogger.log(
          'Audio description mobile: media compatibility fallback '
          '${stage.name} -> ${next.name} after ${error.kind.name}',
        );
        stage = next;
      } finally {
        try {
          if (await File(chunkPath).exists()) await File(chunkPath).delete();
        } catch (_) {}
      }
    }
    throw lastMediaError ?? StateError('AUDIO_DESCRIPTION_MEDIA_FALLBACK_EXHAUSTED');
  }

  bool _isMediaCompatibilityFailure(_AdProviderException error) {
    if (error.kind == AdFailureKind.fileProcessingFailed ||
        error.kind == AdFailureKind.fileVerificationFailed) {
      return true;
    }
    if (error.kind != AdFailureKind.invalidArgument) return false;
    return AudioDescriptionFallbacks.isMediaCompatibilityInvalidArgument(
      error.message,
    );
  }

  Future<_AiGenerationResult> _generatePreparedChunk({
    required String chunkPath,
    required AiAudioDescriptionSettings settings,
    required String? sonarpadToken,
    required String activeGeminiModel,
    required String prompt,
    required String idempotencyKey,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
    int prohibitedAttempts = AudioDescriptionFallbacks.prohibitedContentMaxAttempts,
  }) {
    if (settings.provider == 'sonarpad') {
      if (sonarpadToken == null) throw StateError('SONARPAD_AI_TOKEN_REQUIRED');
      return _generateViaSonarpadAi(
        chunkPath: chunkPath,
        token: sonarpadToken,
        sonarpadCode: settings.sonarpadCode,
        prompt: prompt,
        idempotencyKey: idempotencyKey,
        onHighDemand: onHighDemand,
        prohibitedAttempts: prohibitedAttempts,
      );
    }
    return _generateViaGemini(
      chunkPath: chunkPath,
      apiKey: settings.geminiApiKey,
      model: activeGeminiModel,
      prompt: prompt,
      onHighDemand: onHighDemand,
      onQuota: onQuota,
      prohibitedAttempts: prohibitedAttempts,
    );
  }

  Future<_ParsedGemini> _parseWithOptionalJsonRepair({
    required _AiGenerationResult generated,
    required AiAudioDescriptionSettings settings,
    required String? sonarpadToken,
    required String activeGeminiModel,
    required double chunkStart,
    required double chunkEnd,
    required List<_SafeSlot> slots,
    double? blockedParentChunkStart,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
  }) async {
    _ParsedGemini? initial;
    try {
      initial = _parseGeminiJson(
        generated.text,
        chunkStart: chunkStart,
        chunkEnd: chunkEnd,
        slots: slots,
        blockedParentChunkStart: blockedParentChunkStart,
      );
    } catch (_) {
      initial = null;
    }
    final shouldRepair = AudioDescriptionFallbacks.shouldAttemptJsonRepair(
      parseOk: initial?.parseOk ?? false,
      salvaged: initial?.salvaged ?? false,
      parsedDescriptionCount: initial?.descriptions.length ?? 0,
      rawText: generated.text,
      finishReason: _finishReason(generated.rawResponse),
    );
    if (!shouldRepair) return initial!;

    await AppLogger.log(
      'Audio description mobile: invalid/truncated Gemini JSON; performing one format-repair request',
    );
    try {
      final repairedText = await _repairJsonText(
        broken: AudioDescriptionFallbacks.brokenJsonForRepair(generated.text),
        settings: settings,
        sonarpadToken: sonarpadToken,
        model: activeGeminiModel,
        onHighDemand: onHighDemand,
        onQuota: onQuota,
      );
      final repaired = _parseGeminiJson(
        repairedText,
        chunkStart: chunkStart,
        chunkEnd: chunkEnd,
        slots: slots,
        blockedParentChunkStart: blockedParentChunkStart,
      );
      if (initial == null || repaired.descriptions.length >= initial.descriptions.length) {
        return repaired;
      }
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description mobile: JSON repair failed; preserving salvage error=$error\n$stackTrace',
      );
    }
    if (initial != null) return initial;
    throw const FormatException('Gemini JSON repair failed and no salvage exists');
  }

  String _finishReason(Object? decoded) {
    String? walk(Object? value) {
      if (value is Map) {
        for (final key in const ['finishReason', 'finish_reason']) {
          final raw = value[key];
          if (raw != null && '$raw'.trim().isNotEmpty) return '$raw'.trim();
        }
        for (final child in value.values) {
          final found = walk(child);
          if (found != null) return found;
        }
      } else if (value is List) {
        for (final child in value) {
          final found = walk(child);
          if (found != null) return found;
        }
      }
      return null;
    }
    return walk(decoded) ?? '';
  }

  Future<String> _repairJsonText({
    required String broken,
    required AiAudioDescriptionSettings settings,
    required String? sonarpadToken,
    required String model,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
  }) {
    final prompt = 'Repair the following broken/truncated JSON response. '
        'Return ONLY one valid JSON object with the same semantic data and exactly '
        'the top-level keys "character_glossary" and "audio_descriptions". '
        'Do not invent new descriptions, timestamps, characters or visual facts. '
        'Preserve every recoverable field.\n\nBROKEN JSON:\n$broken';
    return _generateTextOnly(
      settings: settings,
      sonarpadToken: sonarpadToken,
      model: model,
      prompt: prompt,
      idempotencyKey: 'ad-repair-${const Uuid().v4()}',
      onHighDemand: onHighDemand,
      onQuota: onQuota,
    );
  }

  Future<String> _generateTextOnly({
    required AiAudioDescriptionSettings settings,
    required String? sonarpadToken,
    required String model,
    required String prompt,
    required String idempotencyKey,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
    bool allowSessionReactivation = true,
  }) async {
    if (settings.provider == 'sonarpad') {
      var token = await AiAudioDescriptionPreferences.loadSonarpadToken() ?? sonarpadToken;
      if (token == null || token.isEmpty) {
        token = await _ensureSonarpadToken(settings.sonarpadCode);
      }
      final response = await _postJsonWithRetry(
        Uri.parse('$_sonarpadAiBase/generate'),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Idempotency-Key': idempotencyKey,
          'User-Agent': 'Sonarpad-Mobile-AI/1',
        },
        body: <String, Object?>{
          'contents': <Object?>[
            <String, Object?>{
              'role': 'user',
              'parts': <Object?>[<String, Object?>{'text': prompt}],
            },
          ],
          'generationConfig': <String, Object?>{
            'temperature': 0.0,
            'responseMimeType': 'application/json',
          },
        },
        timeout: const Duration(minutes: 12),
        label: 'Sonarpad AI JSON/language repair',
        onHighDemand: onHighDemand,
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (!allowSessionReactivation || settings.sonarpadCode.trim().isEmpty) {
          throw _AdProviderException(
            AdFailureKind.permissionDenied,
            'SONARPAD_AI_SESSION_EXPIRED',
            statusCode: response.statusCode,
          );
        }
        await AiAudioDescriptionPreferences.clearSonarpadToken();
        token = await activateSonarpadAi(settings.sonarpadCode);
        return _generateTextOnly(
          settings: settings,
          sonarpadToken: token,
          model: model,
          prompt: prompt,
          idempotencyKey: idempotencyKey,
          onHighDemand: onHighDemand,
          onQuota: onQuota,
          allowSessionReactivation: false,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _AdProviderException(
          AudioDescriptionFallbacks.classifyHttp(
            statusCode: response.statusCode,
            body: response.body,
          ),
          'Sonarpad AI text generation HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return _extractCandidateText(jsonDecode(response.body));
    }

    var activeModel = await _validateGeminiModel(
      apiKey: settings.geminiApiKey.trim(),
      model: model,
      onHighDemand: onHighDemand,
    );
    final exhausted = <String>{};
    while (true) {
      final response = await _postJsonWithRetry(
        Uri.parse(
          '$_geminiBase/models/${Uri.encodeComponent(activeModel)}:generateContent',
        ).replace(queryParameters: <String, String>{'key': settings.geminiApiKey.trim()}),
        headers: const {'Content-Type': 'application/json'},
        body: <String, Object?>{
          'contents': <Object?>[
            <String, Object?>{
              'role': 'user',
              'parts': <Object?>[<String, Object?>{'text': prompt}],
            },
          ],
          'generationConfig': <String, Object?>{
            'temperature': 0.0,
            'responseMimeType': 'application/json',
          },
        },
        timeout: const Duration(minutes: 10),
        label: 'Gemini JSON/language repair',
        onHighDemand: onHighDemand,
      );
      final failure = AudioDescriptionFallbacks.classifyHttp(
        statusCode: response.statusCode,
        body: response.body,
      );
      if (failure == AdFailureKind.quotaExhausted && onQuota != null) {
        exhausted.add(activeModel);
        final decision = await onQuota(activeModel, Set<String>.unmodifiable(exhausted));
        if (decision.action == AiAudioDescriptionQuotaAction.stop) {
          throw const _AudioDescriptionCancelled();
        }
        if (decision.action == AiAudioDescriptionQuotaAction.switchModel &&
            decision.model != null) {
          final replacement = AudioDescriptionFallbacks.normalizeGeminiModelId(
            decision.model!,
          );
          if (replacement.isNotEmpty &&
              replacement != activeModel &&
              !exhausted.contains(replacement)) {
            activeModel = await _validateGeminiModel(
              apiKey: settings.geminiApiKey.trim(),
              model: replacement,
              onHighDemand: onHighDemand,
            );
            continue;
          }
        }
        await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _AdProviderException(
          failure,
          'Gemini text generation HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return _extractCandidateText(jsonDecode(response.body));
    }
  }

  Future<_ParsedGemini> _recoverCoverage({
    required _ParsedGemini parsed,
    required String chunkPath,
    required AiAudioDescriptionSettings settings,
    required String? sonarpadToken,
    required String activeGeminiModel,
    required double chunkStart,
    required double chunkEnd,
    required List<_SafeSlot> chunkSlots,
    required List<Map<String, Object?>> glossary,
    required int chunkIndex,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
  }) async {
    var current = parsed;
    for (var pass = 1; pass <= 3; pass++) {
      final mandatory = chunkSlots.where((slot) {
        if (!slot.mandatory) return false;
        return !current.descriptions.any((description) {
          final midpoint = (description.requestedStart + description.requestedEnd) / 2.0;
          return midpoint >= slot.start && midpoint <= slot.end;
        });
      }).toList();
      if (mandatory.isEmpty) break;
      try {
        final recoveryPrompt = '${_buildPrompt(
              settings: settings,
              chunkStart: chunkStart,
              chunkEnd: chunkEnd,
              slots: mandatory,
              glossary: glossary,
            )}\nRECOVERY PASS $pass/3: return descriptions ONLY for missing mandatory '
            'slot IDs ${mandatory.map((e) => e.id).join(', ')}. Do not repeat covered slots.';
        final generated = await _generatePreparedChunk(
          chunkPath: chunkPath,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: activeGeminiModel,
          prompt: recoveryPrompt,
          idempotencyKey: 'ad-recovery-${const Uuid().v4()}-$chunkIndex-$pass',
          onHighDemand: onHighDemand,
          onQuota: onQuota,
        );
        final recovered = await _parseWithOptionalJsonRepair(
          generated: generated,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: generated.model,
          chunkStart: chunkStart,
          chunkEnd: chunkEnd,
          slots: mandatory,
          onHighDemand: onHighDemand,
          onQuota: onQuota,
        );
        final allowed = mandatory.map((e) => e.id).toSet();
        current = _ParsedGemini(
          descriptions: <_GeneratedDescription>[
            ...current.descriptions,
            ...recovered.descriptions.where((e) => allowed.contains(e.slotId)),
          ],
          glossary: <Map<String, Object?>>[...current.glossary, ...recovered.glossary],
        );
      } catch (error, stackTrace) {
        await AppLogger.log(
          'Audio description mobile: mandatory recovery pass $pass failed; '
          'keeping existing descriptions error=$error\n$stackTrace',
        );
        break;
      }
    }

    final largeGaps = AudioDescriptionFallbacks.findLargeCoverageGaps(
      chunkStart: chunkStart,
      chunkEnd: chunkEnd,
      descriptions: current.descriptions
          .map((e) => AdTimeRange(e.requestedStart, e.requestedEnd)),
    );
    final recoverySlots = chunkSlots.where((slot) {
      final midpoint = (slot.start + slot.end) / 2.0;
      return largeGaps.any((gap) => midpoint >= gap.start && midpoint <= gap.end);
    }).toList();
    if (largeGaps.isNotEmpty && recoverySlots.isNotEmpty) {
      try {
        final generated = await _generatePreparedChunk(
          chunkPath: chunkPath,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: activeGeminiModel,
          prompt: '${_buildPrompt(
                settings: settings,
                chunkStart: chunkStart,
                chunkEnd: chunkEnd,
                slots: recoverySlots,
                glossary: glossary,
              )}\nCOVERAGE RECOVERY: inspect only the listed long uncovered ranges. '
              'Add narration only for meaningful visual information; never invent filler.',
          idempotencyKey: 'ad-gap-${const Uuid().v4()}-$chunkIndex',
          onHighDemand: onHighDemand,
          onQuota: onQuota,
        );
        final recovered = await _parseWithOptionalJsonRepair(
          generated: generated,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: generated.model,
          chunkStart: chunkStart,
          chunkEnd: chunkEnd,
          slots: recoverySlots,
          onHighDemand: onHighDemand,
          onQuota: onQuota,
        );
        current = _ParsedGemini(
          descriptions: <_GeneratedDescription>[...current.descriptions, ...recovered.descriptions],
          glossary: <Map<String, Object?>>[...current.glossary, ...recovered.glossary],
        );
      } catch (error, stackTrace) {
        await AppLogger.log(
          'Audio description mobile: long-gap recovery failed; keeping existing descriptions '
          'error=$error\n$stackTrace',
        );
      }
    }
    return current;
  }

  Future<_ChunkProcessResult> _blockedChunkMinuteFallback({
    required String sourcePath,
    required Directory chunksDir,
    required int parentChunkIndex,
    required double chunkStart,
    required double chunkEnd,
    required bool hasAudio,
    required AiAudioDescriptionSettings settings,
    required String? sonarpadToken,
    required String activeGeminiModel,
    required List<_SafeSlot> chunkSlots,
    required List<Map<String, Object?>> glossary,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
  }) async {
    final allDescriptions = <_GeneratedDescription>[];
    final allGlossary = <Map<String, Object?>>[];
    var model = activeGeminiModel;
    final minutes = AudioDescriptionFallbacks.blockedMinuteRanges(chunkStart, chunkEnd);
    for (var minuteIndex = 0; minuteIndex < minutes.length; minuteIndex++) {
      _checkCancel();
      final minute = minutes[minuteIndex];
      final minuteSlots = chunkSlots.where((slot) {
        final midpoint = (slot.start + slot.end) / 2.0;
        return midpoint >= minute.start && midpoint < minute.end;
      }).toList();
      if (minuteSlots.isEmpty) continue;
      final path = p.join(
        chunksDir.path,
        'blocked_${parentChunkIndex.toString().padLeft(4, '0')}_${minuteIndex.toString().padLeft(2, '0')}.mp4',
      );
      try {
        await _prepareVisualChunk(
          sourcePath: sourcePath,
          outputPath: path,
          startSec: minute.start,
          durationSec: minute.duration,
          hasAudio: hasAudio,
        );
        final generated = await _generatePreparedChunk(
          chunkPath: path,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: model,
          prompt: _buildPrompt(
            settings: settings,
            chunkStart: minute.start,
            chunkEnd: minute.end,
            slots: minuteSlots,
            glossary: <Map<String, Object?>>[...glossary, ...allGlossary],
          ),
          idempotencyKey: 'ad-minute-${const Uuid().v4()}-$parentChunkIndex-$minuteIndex',
          onHighDemand: onHighDemand,
          onQuota: onQuota,
          prohibitedAttempts: 1,
        );
        model = generated.model;
        final parsed = await _parseWithOptionalJsonRepair(
          generated: generated,
          settings: settings,
          sonarpadToken: sonarpadToken,
          activeGeminiModel: model,
          chunkStart: minute.start,
          chunkEnd: minute.end,
          slots: minuteSlots,
          blockedParentChunkStart: chunkStart,
          onHighDemand: onHighDemand,
          onQuota: onQuota,
        );
        allDescriptions.addAll(parsed.descriptions);
        allGlossary.addAll(parsed.glossary);
      } on _AdProviderException catch (error) {
        if (error.kind == AdFailureKind.prohibitedContent) {
          await AppLogger.log(
            'Audio description mobile: blocked minute ${minuteIndex + 1}/${minutes.length} '
            'still prohibited; preserving original audio for '
            '${minute.start.toStringAsFixed(3)}-${minute.end.toStringAsFixed(3)}',
          );
          continue;
        }
        rethrow;
      } finally {
        try {
          if (await File(path).exists()) await File(path).delete();
        } catch (_) {}
      }
    }
    return _ChunkProcessResult(
      parsed: _ParsedGemini(descriptions: allDescriptions, glossary: allGlossary),
      model: model,
    );
  }

  Future<_ParsedGemini> _correctGeneratedLanguageBestEffort(
    _ParsedGemini parsed, {
    required AiAudioDescriptionSettings settings,
    required String? sonarpadToken,
    required String activeGeminiModel,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
  }) async {
    final wrongDescriptions = <int, _GeneratedDescription>{};
    final wrongGlossary = <int, Map<String, Object?>>{};

    Future<bool> wrongLanguage(String text) async {
      try {
        final detection = await _detectLanguage(text, settings.languageCode);
        if (detection == null) return false;
        final confidence = detection.confidence;
        return !AudioDescriptionFallbacks.languagesMatch(
              detection.language,
              settings.languageCode,
            ) &&
            (confidence == null || confidence >= 0.75);
      } catch (error) {
        await AppLogger.log(
          'Audio description mobile: language detection unavailable; '
          'keeping original text error=$error',
        );
        return false;
      }
    }

    for (var i = 0; i < parsed.descriptions.length; i++) {
      final item = parsed.descriptions[i];
      if (await wrongLanguage(item.text)) wrongDescriptions[i] = item;
    }
    if (settings.recognizeCharacters) {
      for (var i = 0; i < parsed.glossary.length; i++) {
        final item = parsed.glossary[i];
        final description = item['description']?.toString().trim() ?? '';
        if (description.isNotEmpty && await wrongLanguage(description)) {
          wrongGlossary[i] = item;
        }
      }
    }
    if (wrongDescriptions.isEmpty && wrongGlossary.isEmpty) return parsed;

    try {
      final descriptionPayload = wrongDescriptions.entries
          .map((entry) => <String, Object?>{
                'index': entry.key,
                'text': entry.value.text,
              })
          .toList();
      final glossaryPayload = wrongGlossary.entries
          .map((entry) => <String, Object?>{
                'index': entry.key,
                'id': entry.value['id'],
                'name': entry.value['name'],
                'description': entry.value['description'],
              })
          .toList();
      final correction = await _generateTextOnly(
        settings: settings,
        sonarpadToken: sonarpadToken,
        model: activeGeminiModel,
        prompt: 'Translate ONLY the supplied audio-description text fields into '
            '${_languageName(settings.languageCode)}. Preserve every index exactly. '
            'For glossary items preserve id and name byte-for-byte and translate ONLY '
            'description. Do not change meaning, timing or add facts. Return JSON only '
            'with keys "descriptions" and "glossary". INPUT: '
            '${jsonEncode(<String, Object?>{
              'descriptions': descriptionPayload,
              'glossary': glossaryPayload,
            })}',
        idempotencyKey: 'ad-language-${const Uuid().v4()}',
        onHighDemand: onHighDemand,
        onQuota: onQuota,
      );
      Object? root;
      try {
        root = jsonDecode(AudioDescriptionFallbacks.stripJsonFences(correction));
      } catch (_) {
        final object = AudioDescriptionFallbacks.extractJsonObject(correction);
        if (object != null) {
          try {
            root = jsonDecode(object);
          } catch (_) {}
        }
      }
      if (root is! Map) return parsed;

      final updatedDescriptions = List<_GeneratedDescription>.of(parsed.descriptions);
      final rawDescriptions = root['descriptions'];
      if (rawDescriptions is List) {
        for (final raw in rawDescriptions) {
          if (raw is! Map || raw['index'] is! num) continue;
          final index = (raw['index'] as num).toInt();
          final text = raw['text']?.toString().trim() ?? '';
          if (text.isEmpty || !wrongDescriptions.containsKey(index) ||
              index < 0 || index >= updatedDescriptions.length) {
            continue;
          }
          updatedDescriptions[index] =
              updatedDescriptions[index].copyWith(text: text);
        }
      }

      final updatedGlossary = parsed.glossary
          .map((item) => Map<String, Object?>.from(item))
          .toList();
      final rawGlossary = root['glossary'];
      if (rawGlossary is List) {
        for (final raw in rawGlossary) {
          if (raw is! Map || raw['index'] is! num) continue;
          final index = (raw['index'] as num).toInt();
          final description = raw['description']?.toString().trim() ?? '';
          if (description.isEmpty || !wrongGlossary.containsKey(index) ||
              index < 0 || index >= updatedGlossary.length) {
            continue;
          }
          // Never let a language-correction request rename or re-identify a
          // character established by the catalog.
          updatedGlossary[index]['description'] = description;
        }
      }
      return _ParsedGemini(
        descriptions: updatedDescriptions,
        glossary: updatedGlossary,
      );
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description mobile: language correction failed; '
        'keeping original descriptions/glossary error=$error\n$stackTrace',
      );
      return parsed;
    }
  }

  Future<AdLanguageDetection?> _detectLanguage(String text, String targetLanguage) async {
    if (!AudioDescriptionFallbacks.sampleHasEnoughLetters(text)) return null;
    const translateKey = 'AIzaSyDLEeFI5OtFBwYBIoK_jj5m32rZK5CkCXA';
    final sample = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final bounded = sample.length <= 1500 ? sample : sample.substring(0, 1500);
    final target = AudioDescriptionFallbacks.normalizeLanguageCode(targetLanguage);
    final uri = Uri.parse('https://translate-pa.googleapis.com/v1/translate').replace(
      queryParameters: <String, String>{
        'params.client': 'gtx',
        'query.source_language': 'auto',
        'query.target_language': target.isEmpty ? 'en' : target,
        'query.display_language': target.isEmpty ? 'en' : target,
        'query.text': bounded,
        'key': translateKey,
        'data_types': 'TRANSLATION',
      },
    );
    final detectionUri = Uri.parse(
      '${uri.toString()}&data_types=SENTENCE_SPLITS',
    );
    final response = await _http.get(
      detectionUri,
      headers: const <String, String>{
        'Content-Type': 'application/json+protobuf',
        'User-Agent': 'Mozilla/5.0',
      },
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return AudioDescriptionFallbacks.parseGoogleLanguageDetection(jsonDecode(response.body));
  }

  _ParsedGemini _parseGeminiJson(
    String raw, {
    required double chunkStart,
    required double chunkEnd,
    required List<_SafeSlot> slots,
    double? blockedParentChunkStart,
  }) {
    final recovery = AudioDescriptionFallbacks.parseOrSalvageUnifiedJson(raw);
    final decoded = recovery.data;
    if (decoded == null) {
      throw const FormatException('Gemini JSON could not be parsed or salvaged');
    }

    final slotById = <String, _SafeSlot>{for (final slot in slots) slot.id: slot};
    final descriptions = <_GeneratedDescription>[];
    final rawDescriptions = decoded['audio_descriptions'];
    if (rawDescriptions is List) {
      for (final item in rawDescriptions) {
        if (item is! Map) continue;
        final slotId = item['slot_id']?.toString().trim() ?? '';
        final slot = slotById[slotId];
        if (slot == null) continue;
        final description = (item['description_text'] ?? item['description'])
                ?.toString()
                .trim() ??
            '';
        if (description.isEmpty) continue;
        final fallbackSlot = AdFallbackSlot(
          id: slot.id,
          start: slot.start,
          end: slot.end,
          mandatory: slot.mandatory,
          partitionIndex: 1,
          partitionCount: 1,
        );
        final startValue =
            item['start_time_sec'] ?? item['start_time_mmss'] ?? item['start'];
        final endValue =
            item['end_time_sec'] ?? item['end_time_mmss'] ?? item['end'];
        final evidenceValue = item['evidence_time_sec'] ??
            item['visual_evidence_time_seconds'] ??
            item['visual_evidence_time_sec'];
        final times = blockedParentChunkStart == null
            ? AudioDescriptionFallbacks.normalizeTimes(
                startValue: startValue,
                endValue: endValue,
                evidenceValue: evidenceValue,
                chunkStart: chunkStart,
                chunkEnd: chunkEnd,
                slot: fallbackSlot,
              )
            : AudioDescriptionFallbacks.normalizeBlockedMinuteTimes(
                startValue: startValue,
                endValue: endValue,
                evidenceValue: evidenceValue,
                minuteStart: chunkStart,
                minuteEnd: chunkEnd,
                parentChunkStart: blockedParentChunkStart,
                slot: fallbackSlot,
              );
        if (times == null) continue;
        descriptions.add(_GeneratedDescription(
          slotId: slot.id,
          slotStart: slot.start,
          slotEnd: slot.end,
          requestedStart: times.start,
          requestedEnd: times.end,
          evidenceTime: times.evidence,
          text: description,
          mandatory: slot.mandatory || item['mandatory'] == true,
        ));
      }
    }

    final glossary = <Map<String, Object?>>[];
    final rawGlossary = decoded['character_glossary'];
    if (rawGlossary is List) {
      for (final item in rawGlossary) {
        if (item is! Map) continue;
        final description = item['description']?.toString().trim() ?? '';
        final name = item['name']?.toString().trim() ?? '';
        if (description.isEmpty || name.isEmpty) continue;
        glossary.add(<String, Object?>{
          'id': item['id']?.toString().trim().isNotEmpty == true
              ? item['id'].toString().trim()
              : _safeCharacterId(name),
          'name': name,
          'description': description,
        });
      }
    }
    return _ParsedGemini(
      descriptions: descriptions,
      glossary: glossary,
      parseOk: recovery.parseOk,
      salvaged: recovery.salvaged,
    );
  }

  void _mergeGlossary(
    List<Map<String, Object?>> current,
    List<Map<String, Object?>> incoming,
  ) {
    final merged = AudioDescriptionFallbacks.mergeCharacterCatalog(
      current,
      incoming,
      maxCharacters: 96,
    );
    current
      ..clear()
      ..addAll(merged);
  }

  List<_GeneratedDescription> _dedupeDescriptions(List<_GeneratedDescription> input) {
    final bySlot = <String, _GeneratedDescription>{};
    for (final item in input) {
      final previous = bySlot[item.slotId];
      if (previous == null ||
          (item.mandatory && !previous.mandatory) ||
          item.text.length > previous.text.length) {
        bySlot[item.slotId] = item;
      }
    }
    final result = bySlot.values.toList()
      ..sort((a, b) => a.slotStart.compareTo(b.slotStart));
    return result;
  }

  Future<List<_Placement>> _synthesizeAndPlace({
    required AiAudioDescriptionSettings settings,
    required List<_GeneratedDescription> descriptions,
    required List<_SafeSlot> slots,
    required Directory ttsDir,
    required double mediaDurationSec,
    required void Function(AiAudioDescriptionProgress progress) onProgress,
    bool allowDialogueOverlap = false,
  }) async {
    final result = <_Placement>[];
    final ordered = List<_GeneratedDescription>.of(descriptions)
      ..sort((a, b) {
        if (allowDialogueOverlap) {
          return a.requestedStart.compareTo(b.requestedStart);
        }
        if (a.mandatory != b.mandatory) return a.mandatory ? -1 : 1;
        return a.slotStart.compareTo(b.slotStart);
      });

    final fallbackSlots = slots
        .map((slot) => AdFallbackSlot(
              id: slot.id,
              start: slot.start,
              end: slot.end,
              mandatory: slot.mandatory,
              partitionIndex: 1,
              partitionCount: 1,
            ))
        .toList();
    final occupiedSlots = <String>{};
    var overlapCursor = 0.0;
    final flutterTts = FlutterTts();
    final appSettings = AppSettingsService();
    final voiceDictionary = VoiceDictionaryService();
    final dictionaryEntries = await voiceDictionary.loadEntries();
    final speed = await appSettings.loadTtsSpeed();
    final pitch = await appSettings.loadTtsPitch();
    if (settings.ttsEngine == 'system') {
      await flutterTts.awaitSpeakCompletion(true);
      await flutterTts.setSpeechRate(speed * 0.5);
      await flutterTts.setPitch(pitch);
      await flutterTts.setVolume(1.0);
      if (settings.systemVoice != null && settings.systemVoice!.trim().isNotEmpty) {
        await flutterTts.setVoice(<String, String>{
          'name': settings.systemVoice!,
          'locale': settings.systemLanguage,
        });
      } else {
        await flutterTts.setLanguage(settings.systemLanguage);
      }
    }

    for (var i = 0; i < ordered.length; i++) {
      _checkCancel();
      final item = ordered[i];
      _emit(
        onProgress,
        'tts',
        0.62 + (i / math.max(1, ordered.length)) * 0.22,
        detail: '${i + 1}/${ordered.length}',
      );
      final ext = settings.ttsEngine == 'system' && Platform.isIOS
          ? 'caf'
          : settings.ttsEngine == 'system'
              ? 'wav'
              : 'mp3';
      final target = File(
        p.join(ttsDir.path, 'tts_${i.toString().padLeft(4, '0')}.$ext'),
      );
      final spokenText = AudioDescriptionFallbacks.normalizePronunciationText(
        voiceDictionary.applyToText(item.text, dictionaryEntries),
      );
      try {
        await _synthesizeTtsWithFallback(
          settings: settings,
          flutterTts: flutterTts,
          text: spokenText,
          target: target,
          speed: speed,
          pitch: pitch,
        );
        final duration = await _audioDuration(target.path);
        if (duration <= 0) throw StateError('TTS_DURATION_INVALID');

        if (allowDialogueOverlap) {
          final start = AudioDescriptionFallbacks.dialogueOverlapStart(
            visualStartSec: item.requestedStart,
            requiredDurationSec: duration,
            mediaDurationSec: mediaDurationSec,
            cursorSec: overlapCursor,
          );
          if (start != null) {
            result.add(_Placement.included(
              description: item,
              ttsPath: target.path,
              ttsDuration: duration,
              originalStart: start,
              extraPause: 0.0,
            ));
            overlapCursor = start + math.max(duration, 0.001);
            continue;
          }
          result.add(_Placement.excluded(item, 'dialogue_overlap_shift_exceeded'));
          try {
            await target.delete();
          } catch (_) {}
          continue;
        }

        final selected = AudioDescriptionFallbacks.chooseNearbySlot(
          slots: fallbackSlots,
          occupied: occupiedSlots,
          preferredSlotId: item.slotId,
          visualTime: item.evidenceTime,
          requiredDuration: duration,
        );
        if (selected != null) {
          final latest = selected.end - duration;
          final start = item.evidenceTime.clamp(selected.start, latest).toDouble();
          result.add(_Placement.included(
            description: item,
            ttsPath: target.path,
            ttsDuration: duration,
            originalStart: start,
            extraPause: 0.0,
          ));
          occupiedSlots.add(selected.id);
          continue;
        }

        if (settings.allowExtendedPauses) {
          final anchors = fallbackSlots
              .where((slot) => !occupiedSlots.contains(slot.id))
              .where((slot) => slot.duration >= 1.0 && slot.duration < 3.0)
              .where((slot) => AudioDescriptionFallbacks.extendedAnchorHasFollowingScene(
                    anchorEndSec: slot.end,
                    mediaDurationSec: mediaDurationSec,
                  ))
              .toList()
            ..sort((a, b) {
              final da = (((a.start + a.end) / 2) - item.evidenceTime).abs();
              final db = (((b.start + b.end) / 2) - item.evidenceTime).abs();
              return da.compareTo(db);
            });
          AdFallbackSlot? anchor;
          for (final candidate in anchors) {
            final center = (candidate.start + candidate.end) / 2.0;
            if ((center - item.evidenceTime).abs() <=
                AudioDescriptionFallbacks.maxPlacementShiftSeconds) {
              anchor = candidate;
              break;
            }
          }
          if (anchor != null) {
            final extra = duration - anchor.duration + _extendedTailPadding;
            result.add(_Placement.included(
              description: item,
              ttsPath: target.path,
              ttsDuration: duration,
              originalStart: anchor.start,
              extraPause: math.max(0.0, extra),
            ));
            occupiedSlots.add(anchor.id);
            continue;
          }
        }

        result.add(_Placement.excluded(item, 'no_safe_space_after_exact_tts'));
        try {
          await target.delete();
        } catch (_) {}
      } catch (error) {
        if (AudioDescriptionFallbacks.isPermanentTtsError(error.toString())) {
          rethrow;
        }
        await AppLogger.log(
          'Audio description mobile: TTS failed slot=${item.slotId} error=$error',
        );
        result.add(_Placement.excluded(item, 'tts_error'));
      }
    }
    return result;
  }

  Future<void> _synthesizeTtsWithFallback({
    required AiAudioDescriptionSettings settings,
    required FlutterTts flutterTts,
    required String text,
    required File target,
    required double speed,
    required double pitch,
  }) async {
    while (true) {
      _checkCancel();
      try {
        if (await target.exists()) await target.delete();
        if (settings.ttsEngine == 'system') {
          await _synthesizeSystem(flutterTts, text, target);
        } else {
          final edge = await EdgeTtsBridge().speakToFile(
            text: text,
            voice: settings.edgeVoice,
            speed: speed,
            pitch: pitch,
          );
          await edge.copy(target.path);
          try {
            await edge.delete();
          } catch (_) {}
          await _trimEdgeTrailingSilenceBestEffort(target.path);
        }
        if (!await target.exists() || await target.length() <= 512) {
          throw StateError('TTS_EMPTY_OUTPUT');
        }
        if (!await _ttsFileHasAudibleSignal(target.path)) {
          throw StateError('TTS_SILENT_OUTPUT');
        }
        if (await _audioDuration(target.path) <= 0) {
          throw StateError('TTS_DURATION_INVALID');
        }
        return;
      } catch (error) {
        if (AudioDescriptionFallbacks.isPermanentTtsError(error.toString())) {
          rethrow;
        }
        await AppLogger.log(
          'Audio description mobile: retryable TTS/empty-output failure; '
          'retrying in ${AudioDescriptionFallbacks.transientRetryDelaySeconds}s '
          'error=$error',
        );
        await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
      }
    }
  }

  Future<void> _trimEdgeTrailingSilenceBestEffort(String path) async {
    try {
      final duration = await _audioDuration(path);
      if (duration < 0.100) return;
      final volumeSession = await FFmpegKit.executeWithArguments(<String>[
        '-hide_banner', '-nostats', '-i', path,
        '-af', 'volumedetect', '-f', 'null', '-',
      ]);
      final volumeLogs = await volumeSession.getAllLogsAsString() ?? '';
      final meanMatch = RegExp(
        r'mean_volume:\s*(-?\d+(?:\.\d+)?)\s*dB',
        caseSensitive: false,
      ).firstMatch(volumeLogs);
      final meanDb = double.tryParse(meanMatch?.group(1) ?? '') ?? -20.0;
      final thresholdDb = math.max(-55.0, meanDb - 35.0);
      final silenceSession = await FFmpegKit.executeWithArguments(<String>[
        '-hide_banner', '-nostats', '-i', path,
        '-af', 'silencedetect=noise=${thresholdDb.toStringAsFixed(2)}dB:d=0.06',
        '-f', 'null', '-',
      ]);
      final logs = await silenceSession.getAllLogsAsString() ?? '';
      final starts = RegExp(r'silence_start:\s*([0-9]+(?:\.[0-9]+)?)')
          .allMatches(logs)
          .map((m) => double.tryParse(m.group(1) ?? ''))
          .whereType<double>()
          .toList();
      if (starts.isEmpty) return;
      final ends = RegExp(r'silence_end:\s*([0-9]+(?:\.[0-9]+)?)')
          .allMatches(logs)
          .map((m) => double.tryParse(m.group(1) ?? ''))
          .whereType<double>()
          .toList();
      final silenceStart = starts.last;
      var silenceEnd = ends.isNotEmpty ? ends.last : duration;
      if (silenceEnd < silenceStart || silenceStart > (ends.isNotEmpty ? ends.last : duration)) {
        silenceEnd = duration;
      }
      // If the last detected end belongs to an earlier silence, the final
      // silence continues to EOF.
      if (ends.isEmpty || starts.length > ends.length || silenceEnd < silenceStart) {
        silenceEnd = duration;
      }
      final trimEnd = AudioDescriptionFallbacks.edgeTrailingTrimEnd(
        durationSec: duration,
        silenceStartSec: silenceStart,
        silenceEndSec: silenceEnd,
      );
      if (trimEnd == null) return;
      final temporary = '$path.edge-trim.mp3';
      final session = await FFmpegKit.executeWithArguments(<String>[
        '-y', '-hide_banner', '-loglevel', 'error', '-i', path,
        '-af', 'atrim=end=${trimEnd.toStringAsFixed(6)},asetpts=PTS-STARTPTS',
        '-vn', '-c:a', 'libmp3lame', '-b:a', '192k', temporary,
      ]);
      final code = await session.getReturnCode();
      final trimmed = File(temporary);
      if (ReturnCode.isSuccess(code) && await trimmed.exists() && await trimmed.length() > 512) {
        await File(path).delete();
        await trimmed.rename(path);
        await AppLogger.log(
          'Audio description mobile: Edge trailing silence trimmed '
          'duration=${duration.toStringAsFixed(3)} -> ${trimEnd.toStringAsFixed(3)}',
        );
      } else if (await trimmed.exists()) {
        await trimmed.delete();
      }
    } catch (error) {
      await AppLogger.log(
        'Audio description mobile: Edge trailing-silence cleanup skipped error=$error',
      );
    }
  }

  Future<bool> _ttsFileHasAudibleSignal(String path) async {
    final session = await FFmpegKit.executeWithArguments(<String>[
      '-hide_banner', '-nostats', '-i', path,
      '-af', 'volumedetect', '-f', 'null', '-',
    ]);
    final logs = await session.getAllLogsAsString() ?? '';
    return AudioDescriptionFallbacks.ttsLogHasAudibleSignal(logs);
  }

  Future<void> _synthesizeSystem(FlutterTts tts, String text, File output) async {
    if (await output.exists()) await output.delete();
    final completer = Completer<void>();
    Object? ttsError;
    tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    tts.setErrorHandler((message) {
      ttsError = message;
      if (!completer.isCompleted) completer.complete();
    });
    await tts.synthesizeToFile(text, output.path, true);
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    var previous = -1;
    var stable = 0;
    while (DateTime.now().isBefore(deadline)) {
      _checkCancel();
      if (ttsError != null) throw StateError('$ttsError');
      if (await output.exists()) {
        final length = await output.length();
        if (length > 512 && length == previous) {
          stable++;
          if (stable >= 2) return;
        } else {
          stable = 0;
        }
        previous = length;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw TimeoutException('SYSTEM_TTS_TIMEOUT');
  }

  Future<double> _audioDuration(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final code = await session.getReturnCode();
    final info = session.getMediaInformation();
    if (!ReturnCode.isSuccess(code) || info == null) return 0.0;
    return double.tryParse(info.getDuration() ?? '') ?? 0.0;
  }

  Future<void> _renderFinalMp3({
    required String sourcePath,
    required String outputPath,
    required double sourceDurationSec,
    required bool hasAudio,
    required List<_Placement> placements,
  }) async {
    final included = placements.where((p) => p.included).toList()
      ..sort((a, b) => a.originalStart.compareTo(b.originalStart));
    final extensions = included.where((p) => p.extraPause > 0).toList();

    final args = <String>['-y', '-hide_banner', '-loglevel', 'error', '-i', sourcePath];
    for (final placement in included) {
      args.addAll(<String>['-i', placement.ttsPath!]);
    }

    final filter = StringBuffer();
    if (extensions.isEmpty) {
      if (hasAudio) {
        filter.write('[0:a]aresample=48000,aformat=channel_layouts=stereo[base0];');
      } else {
        filter.write('anullsrc=r=48000:cl=stereo,atrim=duration=${sourceDurationSec.toStringAsFixed(6)}[base0];');
      }
    } else {
      final labels = <String>[];
      var previous = 0.0;
      var part = 0;
      for (final placement in extensions) {
        final point = placement.description.slotEnd.clamp(previous, sourceDurationSec).toDouble();
        if (point > previous + 0.0001) {
          final label = 'seg$part';
          if (hasAudio) {
            filter.write('[0:a]atrim=start=${previous.toStringAsFixed(6)}:end=${point.toStringAsFixed(6)},asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=stereo[$label];');
          } else {
            filter.write('anullsrc=r=48000:cl=stereo,atrim=duration=${(point - previous).toStringAsFixed(6)}[$label];');
          }
          labels.add('[$label]');
          part++;
        }
        final padLabel = 'pad$part';
        filter.write('anullsrc=r=48000:cl=stereo,atrim=duration=${placement.extraPause.toStringAsFixed(6)}[$padLabel];');
        labels.add('[$padLabel]');
        part++;
        previous = point;
      }
      if (sourceDurationSec > previous + 0.0001) {
        final label = 'seg$part';
        if (hasAudio) {
          filter.write('[0:a]atrim=start=${previous.toStringAsFixed(6)}:end=${sourceDurationSec.toStringAsFixed(6)},asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=stereo[$label];');
        } else {
          filter.write('anullsrc=r=48000:cl=stereo,atrim=duration=${(sourceDurationSec - previous).toStringAsFixed(6)}[$label];');
        }
        labels.add('[$label]');
      }
      filter.write('${labels.join()}concat=n=${labels.length}:v=0:a=1[base0];');
    }

    var duckIndex = 0;
    final ttsLabels = <String>[];
    for (var i = 0; i < included.length; i++) {
      final placement = included[i];
      final priorExtras = extensions
          .where((ext) => ext.description.slotEnd <= placement.originalStart + 0.000001)
          .fold<double>(0.0, (value, ext) => value + ext.extraPause);
      placement.finalStart = placement.originalStart + priorExtras;
      placement.finalEnd = placement.finalStart + placement.ttsDuration;
      final previousLabel = duckIndex == 0 ? 'base0' : 'duck${duckIndex - 1}';
      final currentLabel = 'duck$duckIndex';
      filter.write('[$previousLabel]volume=enable=\'between(t,${placement.finalStart.toStringAsFixed(6)},${placement.finalEnd.toStringAsFixed(6)})\':volume=$_duckVolume[$currentLabel];');
      duckIndex++;

      final delay = math.max(0, (placement.finalStart * 1000).round());
      final ttsLabel = 'tts$i';
      filter.write('[${i + 1}:a]aresample=48000,aformat=channel_layouts=stereo,adelay=$delay|$delay[$ttsLabel];');
      ttsLabels.add('[$ttsLabel]');
    }
    final duckedBase = duckIndex == 0 ? '[base0]' : '[duck${duckIndex - 1}]';
    filter.write('$duckedBase${ttsLabels.join()}amix=inputs=${ttsLabels.length + 1}:duration=longest:dropout_transition=0,alimiter=limit=0.97[outa]');

    args.addAll(<String>[
      '-filter_complex', filter.toString(),
      '-map', '[outa]', '-vn', '-c:a', 'libmp3lame', '-b:a', '192k',
      '-id3v2_version', '3', outputPath,
    ]);
    await _runFfmpeg(args, 'final mix');
  }

  Future<void> _writeProject({
    required String projectPath,
    required String sourcePath,
    required String outputMp3Path,
    required AiAudioDescriptionSettings settings,
    required String effectiveGeminiModel,
    required PyannoteMobileResult pyannote,
    required List<Map<String, Object?>> glossary,
    required List<_Placement> placements,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final appSettings = AppSettingsService();
    final speed = await appSettings.loadTtsSpeed();
    final pitch = await appSettings.loadTtsPitch();
    final inserted = placements.where((item) => item.included).toList()
      ..sort((a, b) => a.originalStart.compareTo(b.originalStart));
    final descriptions = <AudioDescriptionProjectItem>[];
    for (var index = 0; index < inserted.length; index++) {
      final placement = inserted[index];
      final item = placement.description;
      descriptions.add(AudioDescriptionProjectItem(
        id: index,
        text: item.text,
        originalText: item.text,
        renderedText: item.text,
        modified: false,
        geminiStartSec: item.requestedStart,
        visualEvidenceTimeSec: item.evidenceTime,
        sourceStartSec: placement.originalStart,
        outputStartSec: placement.finalStart,
        outputEndSec: placement.finalEnd,
        ttsDurationSec: placement.ttsDuration,
        extendedPause: placement.extraPause > 0.0001,
        extendedPauseDurationSec: placement.extraPause,
        duckStartSec: placement.extraPause > 0.0001
            ? null
            : math.max(0.0, placement.finalStart - 0.15),
        duckEndSec:
            placement.extraPause > 0.0001 ? null : placement.finalEnd + 0.15,
      ));
    }
    final excluded = <Map<String, Object?>>[];
    var excludedId = descriptions.length;
    for (final placement in placements.where((item) => !item.included)) {
      excluded.add(<String, Object?>{
        'id': excludedId++,
        'text': placement.description.text,
        'gemini_start_sec': placement.description.requestedStart,
        'tts_duration_sec': placement.ttsDuration,
        'reason': placement.reason ?? 'excluded',
      });
    }
    final intervals = pyannote.protectedIntervals
        .map((item) => AudioDescriptionProjectInterval(
              startSec: item.start,
              endSec: item.end,
            ))
        .toList();
    final language = settings.languageCode == 'pt_BR'
        ? 'pt_BR'
        : settings.languageCode == 'zh_CN'
            ? 'zh_CN'
            : settings.languageCode;
    final voice = settings.ttsEngine == 'edge'
        ? settings.edgeVoice
        : (settings.systemVoice ?? '');
    final project = AudioDescriptionEditableProject(
      projectPath: projectPath,
      createdAtUtc: now,
      updatedAtUtc: now,
      sourcePath: sourcePath,
      outputMp3Path: outputMp3Path,
      sourceDurationSec: pyannote.durationSec,
      outputDurationSec: pyannote.durationSec + inserted.fold<double>(
        0.0,
        (value, placement) => value + placement.extraPause,
      ),
      languageCode: language,
      verbosity: settings.verbosity,
      allowExtendedPauses: settings.allowExtendedPauses,
      recognizeCharacters: settings.recognizeCharacters,
      recognizeScreenText: settings.recognizeScreenText,
      geminiModel:
          settings.provider == 'gemini' ? effectiveGeminiModel : 'server-managed',
      ttsEngine: settings.ttsEngine,
      ttsVoice: voice,
      edgeLanguage: settings.edgeLanguage,
      systemLanguage: settings.systemLanguage,
      systemVoice: settings.systemVoice,
      ttsSpeed: speed,
      ttsPitch: pitch,
      bitrateKbps: 192,
      duckingDb: -12.0,
      fadeMs: 150,
      protectedIntervals: intervals,
      descriptions: descriptions,
      excludedDescriptions: excluded,
    );
    final payload = project.toJson();
    payload['character_glossary'] = glossary;
    payload['provider'] = settings.provider;
    payload['keep_character_catalog'] =
        settings.recognizeCharacters && settings.keepCharacterCatalog;
    payload['character_catalog_name'] = settings.characterCatalogName;
    payload['pyannote'] = <String, Object?>{
      'model_sha256': pyannote.modelSha256,
      'runtime_version': pyannote.runtimeVersion,
      'window_sec': PyannoteMobileService.windowSec,
      'step_sec': PyannoteMobileService.stepSec,
      'batch_size': PyannoteMobileService.batchSize,
      'padding_sec': PyannoteMobileService.defaultPaddingSec,
    };
    await File(projectPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<AudioDescriptionEditableProject> loadEditableProject(String projectPath) async {
    final file = File(projectPath);
    if (!await file.exists()) {
      throw FileSystemException('Audio description project not found', projectPath);
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('AUDIO_DESCRIPTION_PROJECT_INVALID_JSON');
    }
    final map = Map<String, Object?>.from(decoded);
    final isWindows = map['format'] == 'sonarpad-audio-description-project';
    final isLegacyMobile = map['schema'] == 'sonarpad-audio-description-project';
    if (!isWindows && !isLegacyMobile) {
      throw const FormatException('AUDIO_DESCRIPTION_PROJECT_UNSUPPORTED');
    }
    final version = (map[isWindows ? 'version' : 'schema_version'] as num?)?.toInt() ?? 0;
    if (version != 1) {
      throw const FormatException('AUDIO_DESCRIPTION_PROJECT_UNSUPPORTED_VERSION');
    }

    double number(Object? value, [double fallback = 0]) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
    bool boolean(Object? value, [bool fallback = false]) =>
        value is bool ? value : fallback;
    String string(Object? value, [String fallback = '']) {
      final result = value?.toString() ?? '';
      return result.isEmpty ? fallback : result;
    }

    List<AudioDescriptionProjectInterval> parseIntervals(Object? raw) {
      if (raw is! List) return const <AudioDescriptionProjectInterval>[];
      final result = <AudioDescriptionProjectInterval>[];
      for (final item in raw) {
        if (item is List && item.length >= 2) {
          final start = number(item[0], double.nan);
          final end = number(item[1], double.nan);
          if (start.isFinite && end.isFinite && end > start) {
            result.add(AudioDescriptionProjectInterval(startSec: start, endSec: end));
          }
        } else if (item is Map) {
          final start = number(item['start_sec'], double.nan);
          final end = number(item['end_sec'], double.nan);
          if (start.isFinite && end.isFinite && end > start) {
            result.add(AudioDescriptionProjectInterval(startSec: start, endSec: end));
          }
        }
      }
      result.sort((a, b) => a.startSec.compareTo(b.startSec));
      return result;
    }

    final rawDescriptions = map['descriptions'];
    final descriptions = <AudioDescriptionProjectItem>[];
    if (rawDescriptions is List) {
      for (var index = 0; index < rawDescriptions.length; index++) {
        final raw = rawDescriptions[index];
        if (raw is! Map) continue;
        final item = Map<String, Object?>.from(raw);
        final text = string(item[isWindows ? 'text' : 'description_text']).trim();
        if (text.isEmpty) continue;
        final sourceStart = number(
          item[isWindows ? 'source_start_sec' : 'original_start_sec'],
          number(item['slot_start_sec']),
        );
        final ttsDuration = number(item['tts_duration_sec']);
        final outputStart = number(item['output_start_sec'], sourceStart);
        final outputEnd = number(item['output_end_sec'], outputStart + ttsDuration);
        final extendedAmount = number(
          item[isWindows ? 'extended_pause_duration_sec' : 'extended_pause_sec'],
        );
        final extended = isWindows
            ? boolean(item['extended_pause'])
            : extendedAmount > 0.0001;
        descriptions.add(AudioDescriptionProjectItem(
          id: (item['id'] as num?)?.toInt() ?? index,
          text: text,
          originalText: string(item['original_text'], text),
          renderedText: string(item['rendered_text'], text),
          modified: boolean(item['modified'], false),
          geminiStartSec: number(
            item['gemini_start_sec'],
            number(item['evidence_time_sec'], sourceStart),
          ),
          visualEvidenceTimeSec: item['visual_evidence_time_sec'] == null &&
                  item['evidence_time_sec'] == null
              ? null
              : number(item['visual_evidence_time_sec'] ?? item['evidence_time_sec']),
          sourceStartSec: sourceStart,
          outputStartSec: outputStart,
          outputEndSec: outputEnd,
          ttsDurationSec: ttsDuration > 0 ? ttsDuration : math.max(0.001, outputEnd - outputStart),
          extendedPause: extended,
          extendedPauseDurationSec: extendedAmount,
          duckStartSec: item['duck_start_sec'] == null ? null : number(item['duck_start_sec']),
          duckEndSec: item['duck_end_sec'] == null ? null : number(item['duck_end_sec']),
        ));
      }
    }
    if (descriptions.isEmpty) {
      throw const FormatException('AUDIO_DESCRIPTION_PROJECT_NO_DESCRIPTIONS');
    }
    descriptions.sort((a, b) => a.sourceStartSec.compareTo(b.sourceStartSec));

    final rawExcluded = map['excluded_descriptions'];
    final excluded = <Map<String, Object?>>[];
    if (rawExcluded is List) {
      for (final item in rawExcluded) {
        if (item is Map) excluded.add(Map<String, Object?>.from(item));
      }
    }

    final pyannote = map['pyannote'];
    final protected = parseIntervals(
      isWindows
          ? map['protected_intervals']
          : (pyannote is Map ? pyannote['protected_intervals'] : null),
    );
    var sourceDuration = number(map['source_duration_sec']);
    if (sourceDuration <= 0) {
      for (final interval in protected) {
        sourceDuration = math.max(sourceDuration, interval.endSec);
      }
      for (final item in descriptions) {
        sourceDuration = math.max(sourceDuration, item.sourceStartSec + item.ttsDurationSec);
      }
    }
    var outputDuration = number(map['output_duration_sec']);
    if (outputDuration <= 0) {
      outputDuration = sourceDuration + descriptions
          .where((item) => item.extendedPause)
          .fold<double>(0, (value, item) => value + item.extendedPauseDurationSec);
    }

    final projectDirectory = p.dirname(projectPath);
    final legacySourceName = string(map['source_file']);
    var sourcePath = string(map['source_path'], legacySourceName);
    if (sourcePath.isNotEmpty && !p.isAbsolute(sourcePath)) {
      final candidate = p.join(projectDirectory, sourcePath);
      if (await File(candidate).exists()) sourcePath = candidate;
    }
    var outputPath = string(map['output_mp3_path']);
    if (outputPath.isEmpty) {
      final base = p.basename(projectPath).replaceFirst(RegExp(r'\.sonarpad-ad\.json$', caseSensitive: false), '');
      outputPath = p.join(projectDirectory, '$base.mp3');
    }

    final rawLanguage = string(map['language_code'], string(map['language'], 'it'));
    final language = switch (rawLanguage.replaceAll('-', '_').toLowerCase()) {
      'pt_br' => 'pt_BR',
      'zh' || 'zh_cn' => 'zh_CN',
      _ => rawLanguage.replaceAll('-', '_'),
    };
    final mobileEngine = string(map['mobile_tts_engine']);
    final windowsEngine = string(map['tts_engine'], 'edge');
    final engine = mobileEngine.isNotEmpty ? mobileEngine : windowsEngine;
    final mobileVoice = string(map['mobile_tts_voice']);
    final windowsVoice = string(map['tts_voice']);
    final ttsVoice = mobileVoice.isNotEmpty ? mobileVoice : windowsVoice;
    final defaultLocale = _defaultLocaleForProjectLanguage(language);

    return AudioDescriptionEditableProject(
      projectPath: projectPath,
      createdAtUtc: string(
        map['created_at_utc'],
        string(map['created_at'], DateTime.now().toUtc().toIso8601String()),
      ),
      updatedAtUtc: string(
        map['updated_at_utc'],
        DateTime.now().toUtc().toIso8601String(),
      ),
      sourcePath: sourcePath,
      outputMp3Path: outputPath,
      sourceDurationSec: sourceDuration,
      outputDurationSec: outputDuration,
      languageCode: language,
      verbosity: string(map['verbosity'], 'detailed'),
      allowExtendedPauses: boolean(map['allow_extended_pauses'], true),
      recognizeCharacters: boolean(map['recognize_characters'], true),
      recognizeScreenText: boolean(map['recognize_screen_text'], true),
      geminiModel: string(map['gemini_model'], 'gemini-3.5-flash-lite'),
      ttsEngine: engine,
      ttsVoice: ttsVoice,
      edgeLanguage: string(map['mobile_edge_language'], defaultLocale),
      systemLanguage: string(map['mobile_system_language'], defaultLocale),
      systemVoice: map['mobile_system_voice']?.toString(),
      ttsSpeed: number(map['mobile_tts_speed'], 1.0),
      ttsPitch: number(map['mobile_tts_pitch'], 1.0),
      bitrateKbps: (map['bitrate_kbps'] as num?)?.toInt() ?? 192,
      duckingDb: number(map['ducking_db'], -12.0),
      fadeMs: (map['fade_ms'] as num?)?.toInt() ?? 150,
      protectedIntervals: protected,
      descriptions: descriptions,
      excludedDescriptions: excluded,
    );
  }

  String _defaultLocaleForProjectLanguage(String languageCode) {
    final code = languageCode.replaceAll('_', '-').toLowerCase();
    if (code == 'pt-br') return 'pt-BR';
    if (code.startsWith('en')) return 'en-US';
    if (code.startsWith('de')) return 'de-DE';
    if (code.startsWith('es')) return 'es-ES';
    if (code.startsWith('fr')) return 'fr-FR';
    if (code.startsWith('pt')) return 'pt-PT';
    if (code.startsWith('pl')) return 'pl-PL';
    if (code.startsWith('cs')) return 'cs-CZ';
    if (code.startsWith('uk')) return 'uk-UA';
    if (code.startsWith('zh')) return 'zh-CN';
    return 'it-IT';
  }

  Future<void> saveEditableProject(AudioDescriptionEditableProject project) async {
    final file = File(project.projectPath);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(project.toJson()),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  double? audioDescriptionProjectAvailableDuration(
    AudioDescriptionEditableProject project,
    int index,
  ) {
    final current = project.descriptions[index];
    if (current.extendedPause) return null;
    final intervals = List<AudioDescriptionProjectInterval>.of(project.protectedIntervals)
      ..sort((a, b) => a.startSec.compareTo(b.startSec));
    final free = <AudioDescriptionProjectInterval>[];
    var cursor = 0.0;
    for (final interval in intervals) {
      final start = interval.startSec.clamp(0.0, project.sourceDurationSec).toDouble();
      final end = interval.endSec.clamp(0.0, project.sourceDurationSec).toDouble();
      if (start > cursor + 0.0001) {
        free.add(AudioDescriptionProjectInterval(startSec: cursor, endSec: start));
      }
      if (end > cursor) cursor = end;
    }
    if (project.sourceDurationSec > cursor + 0.0001) {
      free.add(AudioDescriptionProjectInterval(startSec: cursor, endSec: project.sourceDurationSec));
    }
    final start = current.sourceStartSec;
    AudioDescriptionProjectInterval? gap;
    for (final candidate in free) {
      if (start + 0.001 >= candidate.startSec && start <= candidate.endSec + 0.001) {
        gap = candidate;
        break;
      }
    }
    if (gap == null) return 0.0;
    double end = gap.endSec;
    for (var i = 0; i < project.descriptions.length; i++) {
      if (i == index) continue;
      final other = project.descriptions[i].sourceStartSec;
      if (other > start + 0.001) end = math.min(end, other);
    }
    return math.max(0.0, end - start);
  }

  AiAudioDescriptionSettings _projectTtsSettings(
    AudioDescriptionEditableProject project,
  ) =>
      AiAudioDescriptionSettings(
        provider: 'gemini',
        geminiApiKey: '',
        sonarpadCode: '',
        geminiModel: project.geminiModel,
        languageCode: project.languageCode,
        verbosity: project.verbosity,
        allowExtendedPauses: project.allowExtendedPauses,
        recognizeCharacters: project.recognizeCharacters,
        recognizeScreenText: project.recognizeScreenText,
        keepCharacterCatalog: false,
        characterCatalogName: null,
        saveProject: true,
        ttsEngine: project.ttsEngine,
        edgeLanguage: project.edgeLanguage,
        edgeVoice: project.ttsVoice,
        systemLanguage: project.systemLanguage,
        systemVoice: project.systemVoice,
      );

  Future<AudioDescriptionProjectPreview> previewProjectDescription({
    required AudioDescriptionEditableProject project,
    required int index,
    required String text,
    bool resetCancellation = true,
  }) async {
    if (resetCancellation) _cancelRequested = false;
    final normalized = text.trim();
    if (normalized.isEmpty) throw StateError('AUDIO_DESCRIPTION_PROJECT_EMPTY_TEXT');
    if (index < 0 || index >= project.descriptions.length) {
      throw RangeError.index(index, project.descriptions);
    }
    if (project.ttsEngine != 'edge' && project.ttsEngine != 'system') {
      throw StateError('AUDIO_DESCRIPTION_PROJECT_UNSUPPORTED_TTS_ENGINE');
    }
    final dir = Directory(p.join(
      (await getTemporaryDirectory()).path,
      'sonarpad_ad_project_preview',
    ));
    await dir.create(recursive: true);
    final extension = project.ttsEngine == 'system' && Platform.isIOS
        ? 'caf'
        : project.ttsEngine == 'system'
            ? 'wav'
            : 'mp3';
    final target = File(p.join(dir.path, 'preview_$index.$extension'));
    final flutterTts = FlutterTts();
    try {
      if (project.ttsEngine == 'system') {
        await flutterTts.awaitSpeakCompletion(true);
        await flutterTts.setSpeechRate(project.ttsSpeed * 0.5);
        await flutterTts.setPitch(project.ttsPitch);
        await flutterTts.setVolume(1.0);
        if (project.systemVoice != null && project.systemVoice!.trim().isNotEmpty) {
          await flutterTts.setVoice(<String, String>{
            'name': project.systemVoice!,
            'locale': project.systemLanguage,
          });
        } else {
          await flutterTts.setLanguage(project.systemLanguage);
        }
      }
      final dictionary = await VoiceDictionaryService().loadEntries();
      final spoken = AudioDescriptionFallbacks.normalizePronunciationText(
        VoiceDictionaryService().applyToText(normalized, dictionary),
      );
      await _synthesizeTtsWithFallback(
        settings: _projectTtsSettings(project),
        flutterTts: flutterTts,
        text: spoken,
        target: target,
        speed: project.ttsSpeed,
        pitch: project.ttsPitch,
      );
      final duration = await _audioDuration(target.path);
      final available = audioDescriptionProjectAvailableDuration(project, index);
      if (available != null && duration > available + 0.010) {
        throw AudioDescriptionProjectTooLongException(
          index: index,
          availableSec: available,
          actualSec: duration,
        );
      }
      return AudioDescriptionProjectPreview(
        path: target.path,
        durationSec: duration,
        availableSec: available,
      );
    } finally {
      await flutterTts.stop();
    }
  }

  Future<AudioDescriptionEditableProject> applyProjectDescriptionEdit({
    required AudioDescriptionEditableProject project,
    required int index,
    required String text,
  }) async {
    await previewProjectDescription(
      project: project,
      index: index,
      text: text,
    );
    final normalized = text.trim();
    final current = project.descriptions[index];
    final updatedItems = List<AudioDescriptionProjectItem>.of(project.descriptions);
    updatedItems[index] = current.copyWith(
      text: normalized,
      renderedText: normalized,
      modified: normalized != current.originalText,
    );
    final updated = project.copyWith(
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      descriptions: updatedItems,
    );
    await saveEditableProject(updated);
    return updated;
  }

  Future<AudioDescriptionEditableProject> deleteProjectDescription({
    required AudioDescriptionEditableProject project,
    required int index,
  }) async {
    if (project.descriptions.length <= 1) {
      throw StateError('AUDIO_DESCRIPTION_PROJECT_DELETE_LAST');
    }
    final items = List<AudioDescriptionProjectItem>.of(project.descriptions)
      ..removeAt(index);
    final updated = project.copyWith(
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      descriptions: items,
    );
    await saveEditableProject(updated);
    return updated;
  }

  Future<AudioDescriptionEditableProject> changeProjectVoice({
    required AudioDescriptionEditableProject project,
    required String ttsEngine,
    required String edgeLanguage,
    required String edgeVoice,
    required String systemLanguage,
    required String? systemVoice,
    required double speed,
    required double pitch,
    void Function(double progress)? onProgress,
  }) async {
    _cancelRequested = false;
    final voice = ttsEngine == 'edge' ? edgeVoice : (systemVoice ?? '');
    final candidate = project.copyWith(
      ttsEngine: ttsEngine,
      ttsVoice: voice,
      edgeLanguage: edgeLanguage,
      systemLanguage: systemLanguage,
      systemVoice: systemVoice,
      clearSystemVoice: ttsEngine != 'system' || systemVoice == null,
      ttsSpeed: speed,
      ttsPitch: pitch,
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
    for (var i = 0; i < candidate.descriptions.length; i++) {
      _checkCancel();
      await previewProjectDescription(
        project: candidate,
        index: i,
        text: candidate.descriptions[i].text,
        resetCancellation: false,
      );
      onProgress?.call((i + 1) / candidate.descriptions.length);
    }
    await saveEditableProject(candidate);
    return candidate;
  }

  Future<AudioDescriptionProjectExportResult> reexportEditableProject({
    required AudioDescriptionEditableProject project,
    String? sourcePathOverride,
    void Function(AiAudioDescriptionProgress progress)? onProgress,
  }) async {
    _cancelRequested = false;
    final sourcePath = (sourcePathOverride?.trim().isNotEmpty ?? false)
        ? sourcePathOverride!.trim()
        : project.sourcePath;
    if (sourcePath.isEmpty || !await File(sourcePath).exists()) {
      throw StateError('AUDIO_DESCRIPTION_PROJECT_SOURCE_REQUIRED');
    }
    if (project.ttsEngine != 'edge' && project.ttsEngine != 'system') {
      throw StateError('AUDIO_DESCRIPTION_PROJECT_UNSUPPORTED_TTS_ENGINE');
    }
    final probe = await _probe(sourcePath);
    if (project.sourceDurationSec > 0) {
      final tolerance = math.max(2.0, project.sourceDurationSec * 0.002);
      if ((probe.durationSec - project.sourceDurationSec).abs() > tolerance) {
        throw StateError('AUDIO_DESCRIPTION_PROJECT_SOURCE_MISMATCH');
      }
    }
    final root = await AppCacheService.directory('audio_description_project_export');
    final dir = Directory(p.join(root.path, const Uuid().v4()));
    final ttsDir = Directory(p.join(dir.path, 'tts'));
    await ttsDir.create(recursive: true);
    final flutterTts = FlutterTts();
    if (project.ttsEngine == 'system') {
      await flutterTts.awaitSpeakCompletion(true);
      await flutterTts.setSpeechRate(project.ttsSpeed * 0.5);
      await flutterTts.setPitch(project.ttsPitch);
      await flutterTts.setVolume(1.0);
      if (project.systemVoice != null && project.systemVoice!.trim().isNotEmpty) {
        await flutterTts.setVoice(<String, String>{
          'name': project.systemVoice!,
          'locale': project.systemLanguage,
        });
      } else {
        await flutterTts.setLanguage(project.systemLanguage);
      }
    }
    final placements = <_Placement>[];
    final updatedItems = <AudioDescriptionProjectItem>[];
    try {
      final dictionary = await VoiceDictionaryService().loadEntries();
      for (var i = 0; i < project.descriptions.length; i++) {
        _checkCancel();
        onProgress?.call(AiAudioDescriptionProgress(
          'project_tts',
          0.05 + (i / math.max(1, project.descriptions.length)) * 0.60,
          detail: '${i + 1}/${project.descriptions.length}',
        ));
        final item = project.descriptions[i];
        final ext = project.ttsEngine == 'system' && Platform.isIOS
            ? 'caf'
            : project.ttsEngine == 'system'
                ? 'wav'
                : 'mp3';
        final target = File(p.join(ttsDir.path, 'project_${i.toString().padLeft(4, '0')}.$ext'));
        final spoken = AudioDescriptionFallbacks.normalizePronunciationText(
          VoiceDictionaryService().applyToText(item.text, dictionary),
        );
        await _synthesizeTtsWithFallback(
          settings: _projectTtsSettings(project),
          flutterTts: flutterTts,
          text: spoken,
          target: target,
          speed: project.ttsSpeed,
          pitch: project.ttsPitch,
        );
        final duration = await _audioDuration(target.path);
        final available = audioDescriptionProjectAvailableDuration(project, i);
        if (available != null && duration > available + 0.010) {
          throw AudioDescriptionProjectTooLongException(
            index: i,
            availableSec: available,
            actualSec: duration,
          );
        }
        final generated = _GeneratedDescription(
          slotId: 'PROJECT_${item.id}',
          slotStart: item.sourceStartSec,
          slotEnd: item.sourceStartSec,
          requestedStart: item.geminiStartSec,
          requestedEnd: item.geminiStartSec,
          evidenceTime: item.visualEvidenceTimeSec ?? item.geminiStartSec,
          text: item.text,
          mandatory: false,
        );
        placements.add(_Placement.included(
          description: generated,
          ttsPath: target.path,
          ttsDuration: duration,
          originalStart: item.sourceStartSec,
          extraPause: item.extendedPause ? duration : 0.0,
        ));
        updatedItems.add(item.copyWith(ttsDurationSec: duration));
      }

      onProgress?.call(const AiAudioDescriptionProgress('project_export', 0.70));
      final base = _safeBaseName(
        p.basename(project.outputMp3Path).replaceFirst(RegExp(r'\.mp3$', caseSensitive: false), ''),
      );
      final mp3Path = p.join(dir.path, '${base.isEmpty ? 'audiodescritto' : base}_modificato.mp3');
      await _renderFinalMp3(
        sourcePath: sourcePath,
        outputPath: mp3Path,
        sourceDurationSec: probe.durationSec,
        hasAudio: probe.hasAudio,
        placements: placements,
      );
      if (!await File(mp3Path).exists() || await File(mp3Path).length() <= 0) {
        throw StateError('AUDIO_DESCRIPTION_PROJECT_EXPORT_INVALID');
      }

      var offset = 0.0;
      final finalItems = <AudioDescriptionProjectItem>[];
      for (var i = 0; i < updatedItems.length; i++) {
        final item = updatedItems[i];
        final duration = placements[i].ttsDuration;
        final outputStart = item.sourceStartSec + offset;
        final outputEnd = outputStart + duration;
        finalItems.add(item.copyWith(
          outputStartSec: outputStart,
          outputEndSec: outputEnd,
          ttsDurationSec: duration,
          extendedPauseDurationSec: item.extendedPause ? duration : 0.0,
          duckStartSec: item.extendedPause ? null : math.max(0.0, outputStart - 0.15),
          duckEndSec: item.extendedPause ? null : outputEnd + 0.15,
          clearDuck: item.extendedPause,
        ));
        if (item.extendedPause) offset += duration;
      }
      final outputDuration = probe.durationSec + offset;
      final projectPath = p.join(dir.path, '${base.isEmpty ? 'audiodescritto' : base}_modificato.sonarpad-ad.json');
      final updatedProject = project.copyWith(
        projectPath: projectPath,
        sourcePath: sourcePath,
        outputMp3Path: mp3Path,
        outputDurationSec: outputDuration,
        updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
        descriptions: finalItems,
      );
      await saveEditableProject(updatedProject);
      onProgress?.call(const AiAudioDescriptionProgress('completed', 1.0));
      return AudioDescriptionProjectExportResult(
        mp3Path: mp3Path,
        projectPath: projectPath,
        project: updatedProject,
      );
    } finally {
      await flutterTts.stop();
    }
  }

  Future<String> exportEditableProjectSubtitle({
    required AudioDescriptionEditableProject project,
    required String format,
  }) async {
    final normalized = format.toLowerCase();
    if (normalized != 'srt' && normalized != 'vtt') {
      throw ArgumentError.value(format, 'format');
    }
    String timestamp(double seconds, String separator) {
      final totalMs = math.max(0, (seconds * 1000).round());
      final hours = totalMs ~/ 3600000;
      final minutes = (totalMs % 3600000) ~/ 60000;
      final secs = (totalMs % 60000) ~/ 1000;
      final millis = totalMs % 1000;
      String two(int value) => value.toString().padLeft(2, '0');
      return '${two(hours)}:${two(minutes)}:${two(secs)}$separator${millis.toString().padLeft(3, '0')}';
    }
    final buffer = StringBuffer();
    if (normalized == 'vtt') buffer.write('WEBVTT\r\n\r\n');
    var cue = 1;
    for (final item in project.descriptions) {
      final text = item.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
      if (text.isEmpty) continue;
      final start = math.max(0.0, item.outputStartSec);
      final end = math.max(start + 0.001, item.outputEndSec);
      if (normalized == 'srt') buffer.write('$cue\r\n');
      buffer.write('${timestamp(start, normalized == 'srt' ? ',' : '.')} --> ${timestamp(end, normalized == 'srt' ? ',' : '.')}\r\n');
      buffer.write('${text.replaceAll('\n', '\r\n')}\r\n\r\n');
      cue++;
    }
    final dir = Directory(p.join(
      (await getTemporaryDirectory()).path,
      'sonarpad_ad_project_subtitles',
    ));
    await dir.create(recursive: true);
    final base = p.basename(project.projectPath).replaceFirst(RegExp(r'\.sonarpad-ad\.json$', caseSensitive: false), '');
    final path = p.join(dir.path, '${base.isEmpty ? 'audiodescrizione' : base}.$normalized');
    await File(path).writeAsString(buffer.toString(), flush: true);
    return path;
  }

  Future<String> _ensureSonarpadToken(String code) async {
    final existing = await AiAudioDescriptionPreferences.loadSonarpadToken();
    if (existing != null) return existing;
    return activateSonarpadAi(code);
  }

  Future<_AiGenerationResult> _generateViaGemini({
    required String chunkPath,
    required String apiKey,
    required String model,
    required String prompt,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    AiAudioDescriptionQuotaCallback? onQuota,
    int prohibitedAttempts = AudioDescriptionFallbacks.prohibitedContentMaxAttempts,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) throw StateError('GEMINI_API_KEY_REQUIRED');
    final file = File(chunkPath);
    final bytes = await file.length();
    var activeModel = await _validateGeminiModel(
      apiKey: key,
      model: model,
      onHighDemand: onHighDemand,
    );
    final exhausted = <String>{};
    final preferInline = AudioDescriptionFallbacks.shouldUseInlineVideo(bytes);

    Future<_AiGenerationResult> runWithParts(List<Object?> parts) async {
      var prohibitedCount = 0;
      var malformedCount = 0;
      while (true) {
        _checkCancel();
        final uri = Uri.parse(
          '$_geminiBase/models/${Uri.encodeComponent(activeModel)}:generateContent',
        ).replace(queryParameters: <String, String>{'key': key});
        final response = await _postJsonWithRetry(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: <String, Object?>{
            'contents': <Object?>[
              <String, Object?>{'role': 'user', 'parts': parts},
            ],
            'generationConfig': <String, Object?>{
              'temperature': 0.2,
              'responseMimeType': 'application/json',
            },
          },
          timeout: const Duration(minutes: 10),
          label: 'Gemini generate',
          onHighDemand: onHighDemand,
        );
        final failure = AudioDescriptionFallbacks.classifyHttp(
          statusCode: response.statusCode,
          body: response.body,
        );
        if (failure == AdFailureKind.quotaExhausted) {
          exhausted.add(activeModel);
          if (onQuota == null) {
            throw _AdProviderException(
              AdFailureKind.quotaExhausted,
              'Gemini quota exhausted for $activeModel',
              statusCode: response.statusCode,
            );
          }
          final decision = await onQuota(activeModel, Set<String>.unmodifiable(exhausted));
          _checkCancel();
          if (decision.action == AiAudioDescriptionQuotaAction.stop) {
            throw const _AudioDescriptionCancelled();
          }
          if (decision.action == AiAudioDescriptionQuotaAction.switchModel) {
            final replacement = AudioDescriptionFallbacks.normalizeGeminiModelId(
              decision.model ?? '',
            );
            if (replacement.isEmpty ||
                replacement == activeModel ||
                exhausted.contains(replacement)) {
              throw _AdProviderException(
                AdFailureKind.quotaExhausted,
                'No usable replacement Gemini model selected',
                statusCode: response.statusCode,
              );
            }
            activeModel = await _validateGeminiModel(
              apiKey: key,
              model: replacement,
              onHighDemand: onHighDemand,
            );
            continue;
          }
          await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw _AdProviderException(
            failure,
            'Gemini HTTP ${response.statusCode}: ${_short(response.body)}',
            statusCode: response.statusCode,
          );
        }
        final decoded = jsonDecode(response.body);
        if (AudioDescriptionFallbacks.isProhibitedContent(decoded)) {
          prohibitedCount++;
          if (prohibitedCount >= prohibitedAttempts) {
            throw _AdProviderException(
              AdFailureKind.prohibitedContent,
              'Gemini PROHIBITED_CONTENT persisted after $prohibitedCount attempt(s)',
            );
          }
          await AppLogger.log(
            'Audio description mobile: PROHIBITED_CONTENT retry '
            '$prohibitedCount/$prohibitedAttempts',
          );
          await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
          continue;
        }
        if (AudioDescriptionFallbacks.isMalformedResponse(decoded)) {
          malformedCount++;
          if (malformedCount >= AudioDescriptionFallbacks.malformedResponseMaxAttempts) {
            throw _AdProviderException(
              AdFailureKind.malformedResponse,
              'Gemini MALFORMED_RESPONSE persisted after $malformedCount attempt(s)',
            );
          }
          await AppLogger.log(
            'Audio description mobile: MALFORMED_RESPONSE retry '
            '$malformedCount/${AudioDescriptionFallbacks.malformedResponseMaxAttempts}',
          );
          await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
          continue;
        }
        return _AiGenerationResult(
          text: _extractCandidateText(decoded),
          model: activeModel,
          rawResponse: decoded,
        );
      }
    }

    Future<List<Object?>> inlineParts() async {
      final data = base64Encode(await file.readAsBytes());
      return <Object?>[
        <String, Object?>{'text': prompt},
        <String, Object?>{
          'inlineData': <String, Object?>{
            'mimeType': AudioDescriptionFallbacks.mimeTypeForPath(chunkPath),
            'data': data,
          },
        },
      ];
    }

    if (preferInline) {
      try {
        return await runWithParts(await inlineParts());
      } on _AdProviderException catch (error) {
        if (error.kind != AdFailureKind.invalidArgument &&
            error.kind != AdFailureKind.fileProcessingFailed &&
            error.kind != AdFailureKind.permissionDenied) {
          rethrow;
        }
        await AppLogger.log(
          'Audio description mobile: inline Gemini path failed; '
          'falling back to Files API kind=${error.kind.name}',
        );
      }
    }

    _GeminiUpload? upload;
    try {
      try {
        upload = await _uploadGeminiFileWithProcessingFallback(chunkPath, key);
      } on _AdProviderException catch (error) {
        if (error.kind == AdFailureKind.fileProcessingFailed &&
            AudioDescriptionFallbacks.canFallbackToInlineVideo(bytes)) {
          await AppLogger.log(
            'Audio description mobile: Files API processing failed; '
            'retrying same prepared chunk inline',
          );
          return await runWithParts(await inlineParts());
        }
        rethrow;
      }
      try {
        return await runWithParts(<Object?>[
          <String, Object?>{'text': prompt},
          <String, Object?>{
            'fileData': <String, Object?>{
              'mimeType': AudioDescriptionFallbacks.mimeTypeForPath(chunkPath),
              'fileUri': upload.uri,
            },
          },
        ]);
      } on _AdProviderException catch (error) {
        if (error.kind == AdFailureKind.permissionDenied &&
            AudioDescriptionFallbacks.canFallbackToInlineVideo(bytes)) {
          await AppLogger.log(
            'Audio description mobile: Files API generation permission denied; '
            'retrying same prepared chunk inline',
          );
          return await runWithParts(await inlineParts());
        }
        rethrow;
      }
    } finally {
      if (upload != null) await _deleteGeminiFile(upload.name, key);
    }
  }

  Future<_GeminiUpload> _uploadGeminiFileWithProcessingFallback(
    String path,
    String apiKey,
  ) async {
    var processingFailures = 0;
    while (true) {
      try {
        return await _uploadGeminiFile(path, apiKey);
      } on _GeminiFileProcessingException catch (error) {
        processingFailures++;
        final maxReuploads = AudioDescriptionFallbacks.maxFileProcessingReuploads(
          providerCode: error.providerCode,
        );
        if (processingFailures > maxReuploads) {
          throw _AdProviderException(
            AdFailureKind.fileProcessingFailed,
            error.toString(),
            providerCode: error.providerCode,
          );
        }
        await AppLogger.log(
          'Audio description mobile: Gemini file processing failed '
          'code=${error.providerCode ?? 'unknown'}; reupload '
          '$processingFailures/$maxReuploads',
        );
        await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
      }
    }
  }

  Future<_GeminiUpload> _uploadGeminiFile(String path, String apiKey) async {
    final file = File(path);
    final length = await file.length();
    final mime = AudioDescriptionFallbacks.mimeTypeForPath(path);
    final start = await _http.post(
      Uri.parse('$_geminiUploadBase/files').replace(
        queryParameters: <String, String>{'key': apiKey},
      ),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': '$length',
        'X-Goog-Upload-Header-Content-Type': mime,
      },
      body: jsonEncode(<String, Object?>{
        'file': <String, Object?>{'display_name': p.basename(path)},
      }),
    ).timeout(const Duration(seconds: 60));
    final startFailure = AudioDescriptionFallbacks.classifyHttp(
      statusCode: start.statusCode,
      body: start.body,
    );
    if (start.statusCode < 200 || start.statusCode >= 300) {
      throw _AdProviderException(
        startFailure,
        'Gemini upload start HTTP ${start.statusCode}: ${_short(start.body)}',
        statusCode: start.statusCode,
      );
    }
    final uploadUrl = start.headers['x-goog-upload-url'];
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw StateError('GEMINI_UPLOAD_URL_MISSING');
    }
    final uploaded = await _streamFileUpload(uploadUrl, file, mimeType: mime);
    if (uploaded.statusCode < 200 || uploaded.statusCode >= 300) {
      final failure = AudioDescriptionFallbacks.classifyHttp(
        statusCode: uploaded.statusCode,
        body: uploaded.body,
      );
      throw _AdProviderException(
        failure,
        'Gemini direct upload HTTP ${uploaded.statusCode}: ${_short(uploaded.body)}',
        statusCode: uploaded.statusCode,
      );
    }
    var decoded = jsonDecode(uploaded.body);
    final name = _findString(decoded, const ['name']) ?? '';
    var uri = _findString(decoded, const ['uri', 'fileUri', 'file_uri']) ?? '';
    if (name.isEmpty) throw StateError('GEMINI_FILE_NAME_MISSING');

    var active = _findString(decoded, const ['state'])?.toUpperCase() == 'ACTIVE';
    String? processingCode;
    for (var i = 0; i < 90 && (!active || uri.isEmpty); i++) {
      await _cancelableDelay(2);
      final status = await _http.get(
        Uri.parse('$_geminiBase/$name').replace(
          queryParameters: <String, String>{'key': apiKey},
        ),
      ).timeout(const Duration(seconds: 30));
      if (status.statusCode < 200 || status.statusCode >= 300) {
        final kind = AudioDescriptionFallbacks.classifyHttp(
          statusCode: status.statusCode,
          body: status.body,
        );
        if (kind == AdFailureKind.transient || kind == AdFailureKind.highDemand) {
          continue;
        }
        throw _AdProviderException(
          kind,
          'Gemini file status HTTP ${status.statusCode}: ${_short(status.body)}',
          statusCode: status.statusCode,
        );
      }
      decoded = jsonDecode(status.body);
      final latestState = _findString(decoded, const ['state'])?.toUpperCase();
      processingCode = _findString(decoded, const ['code', 'errorCode', 'error_code']);
      uri = _findString(decoded, const ['uri', 'fileUri', 'file_uri']) ?? uri;
      if (latestState == 'FAILED') {
        await _deleteGeminiFile(name, apiKey);
        throw _GeminiFileProcessingException(providerCode: processingCode);
      }
      if (latestState != null &&
          latestState.isNotEmpty &&
          latestState != 'PROCESSING' &&
          latestState != 'ACTIVE') {
        await _deleteGeminiFile(name, apiKey);
        throw _GeminiFileProcessingException(
          providerCode: processingCode,
          state: latestState,
        );
      }
      active = latestState == 'ACTIVE';
    }
    if (!active || uri.isEmpty) {
      await _deleteGeminiFile(name, apiKey);
      throw _GeminiFileProcessingException(
        providerCode: processingCode,
        state: 'TIMEOUT',
      );
    }
    return _GeminiUpload(name: name, uri: uri);
  }

  Future<void> _deleteGeminiFile(String name, String apiKey) async {
    if (name.isEmpty) return;
    try {
      await _http.delete(
        Uri.parse('$_geminiBase/$name').replace(
          queryParameters: <String, String>{'key': apiKey},
        ),
      ).timeout(const Duration(seconds: 30));
    } catch (_) {}
  }

  Future<_AiGenerationResult> _generateViaSonarpadAi({
    required String chunkPath,
    required String token,
    required String sonarpadCode,
    required String prompt,
    required String idempotencyKey,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    int prohibitedAttempts = AudioDescriptionFallbacks.prohibitedContentMaxAttempts,
    bool allowSessionReactivation = true,
  }) async {
    final file = File(chunkPath);
    final length = await file.length();
    var activeToken =
        await AiAudioDescriptionPreferences.loadSonarpadToken() ?? token;
    final mime = AudioDescriptionFallbacks.mimeTypeForPath(chunkPath);

    Future<_AiGenerationResult> attempt() async {
      Map<String, String> headers() => <String, String>{
        'Authorization': 'Bearer $activeToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Sonarpad-Mobile-AI/1',
      };
      final start = await _postJsonWithRetry(
        Uri.parse('$_sonarpadAiBase/upload/start'),
        headers: headers(),
        body: <String, Object?>{
          'mime_type': mime,
          'bytes': length,
          'display_name': p.basename(chunkPath),
        },
        timeout: const Duration(seconds: 60),
        label: 'Sonarpad AI upload/start',
        onHighDemand: onHighDemand,
      );
      if (start.statusCode == 401 || start.statusCode == 403) {
        throw _AdProviderException(
          AdFailureKind.permissionDenied,
          'SONARPAD_AI_SESSION_EXPIRED',
          statusCode: start.statusCode,
        );
      }
      final startFailure = AudioDescriptionFallbacks.classifyHttp(
        statusCode: start.statusCode,
        body: start.body,
      );
      if (start.statusCode < 200 || start.statusCode >= 300) {
        throw _AdProviderException(
          startFailure,
          'Sonarpad AI upload/start HTTP ${start.statusCode}: ${_short(start.body)}',
          statusCode: start.statusCode,
        );
      }
      final startJson = jsonDecode(start.body);
      final uploadUrl = _findString(startJson, const ['upload_url', 'uploadUrl']);
      final uploadId = _findString(startJson, const ['upload_id', 'uploadId']);
      if (uploadUrl == null || uploadId == null) {
        throw StateError('SONARPAD_AI_UPLOAD_START_INVALID');
      }

      final uploaded = await _streamFileUpload(uploadUrl, file, mimeType: mime);
      if (uploaded.statusCode < 200 || uploaded.statusCode >= 300) {
        throw _AdProviderException(
          AudioDescriptionFallbacks.classifyHttp(
            statusCode: uploaded.statusCode,
            body: uploaded.body,
          ),
          'Google direct upload HTTP ${uploaded.statusCode}: ${_short(uploaded.body)}',
          statusCode: uploaded.statusCode,
        );
      }
      final uploadedJson = jsonDecode(uploaded.body);
      final fileName = _findString(uploadedJson, const ['name']);
      final uploadedUri = _findString(uploadedJson, const ['uri', 'fileUri', 'file_uri']);
      if (fileName == null) throw StateError('SONARPAD_AI_GOOGLE_FILE_NAME_MISSING');

      final complete = await _postJsonWithRetry(
        Uri.parse('$_sonarpadAiBase/upload/complete'),
        headers: headers(),
        body: <String, Object?>{
          'upload_id': uploadId,
          'file_name': fileName,
        },
        timeout: const Duration(minutes: 3),
        label: 'Sonarpad AI upload/complete',
        onHighDemand: onHighDemand,
        boundFileVerificationFailures: true,
      );
      if (complete.statusCode == 401 || complete.statusCode == 403) {
        throw _AdProviderException(
          AdFailureKind.permissionDenied,
          'SONARPAD_AI_SESSION_EXPIRED',
          statusCode: complete.statusCode,
        );
      }
      if (complete.statusCode < 200 || complete.statusCode >= 300) {
        final kind = AudioDescriptionFallbacks.classifyHttp(
          statusCode: complete.statusCode,
          body: complete.body,
        );
        throw _AdProviderException(
          kind,
          'Sonarpad AI upload/complete HTTP ${complete.statusCode}: ${_short(complete.body)}',
          statusCode: complete.statusCode,
        );
      }
      final completeJson = jsonDecode(complete.body);
      final fileUri = _findString(
            completeJson,
            const ['file_uri', 'fileUri', 'uri'],
          ) ??
          uploadedUri;
      if (fileUri == null || fileUri.isEmpty) {
        throw StateError('SONARPAD_AI_FILE_URI_MISSING');
      }

      var prohibitedCount = 0;
      var malformedCount = 0;
      try {
        while (true) {
          final generate = await _postJsonWithRetry(
            Uri.parse('$_sonarpadAiBase/generate'),
            headers: <String, String>{
              ...headers(),
              'X-Idempotency-Key': idempotencyKey,
            },
            body: <String, Object?>{
              'contents': <Object?>[
                <String, Object?>{
                  'role': 'user',
                  'parts': <Object?>[
                    <String, Object?>{'text': prompt},
                    <String, Object?>{
                      'fileData': <String, Object?>{
                        'mimeType': mime,
                        'fileUri': fileUri,
                      },
                    },
                  ],
                },
              ],
              'generationConfig': <String, Object?>{
                'temperature': 0.2,
                'responseMimeType': 'application/json',
              },
            },
            timeout: const Duration(minutes: 12),
            label: 'Sonarpad AI generate',
            onHighDemand: onHighDemand,
          );
          if (generate.statusCode == 401 || generate.statusCode == 403) {
            throw _AdProviderException(
              AdFailureKind.permissionDenied,
              'SONARPAD_AI_SESSION_EXPIRED',
              statusCode: generate.statusCode,
            );
          }
          if (generate.statusCode < 200 || generate.statusCode >= 300) {
            throw _AdProviderException(
              AudioDescriptionFallbacks.classifyHttp(
                statusCode: generate.statusCode,
                body: generate.body,
              ),
              'Sonarpad AI generate HTTP ${generate.statusCode}: ${_short(generate.body)}',
              statusCode: generate.statusCode,
            );
          }
          final decoded = jsonDecode(generate.body);
          if (AudioDescriptionFallbacks.isProhibitedContent(decoded)) {
            prohibitedCount++;
            if (prohibitedCount >= prohibitedAttempts) {
              throw _AdProviderException(
                AdFailureKind.prohibitedContent,
                'Sonarpad AI PROHIBITED_CONTENT persisted',
              );
            }
            await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
            continue;
          }
          if (AudioDescriptionFallbacks.isMalformedResponse(decoded)) {
            malformedCount++;
            if (malformedCount >= AudioDescriptionFallbacks.malformedResponseMaxAttempts) {
              throw _AdProviderException(
                AdFailureKind.malformedResponse,
                'Sonarpad AI MALFORMED_RESPONSE persisted',
              );
            }
            await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
            continue;
          }
          return _AiGenerationResult(
            text: _extractCandidateText(decoded),
            model: 'server-managed',
            rawResponse: decoded,
          );
        }
      } finally {
        try {
          await _http.post(
            Uri.parse('$_sonarpadAiBase/upload/delete'),
            headers: headers(),
            body: jsonEncode(<String, Object?>{'upload_id': uploadId}),
          ).timeout(const Duration(seconds: 45));
        } catch (_) {}
      }
    }

    try {
      return await attempt();
    } on _AdProviderException catch (error) {
      if (allowSessionReactivation &&
          error.kind == AdFailureKind.permissionDenied &&
          error.message.contains('SONARPAD_AI_SESSION_EXPIRED') &&
          sonarpadCode.trim().isNotEmpty) {
        await AiAudioDescriptionPreferences.clearSonarpadToken();
        activeToken = await activateSonarpadAi(sonarpadCode);
        return _generateViaSonarpadAi(
          chunkPath: chunkPath,
          token: activeToken,
          sonarpadCode: sonarpadCode,
          prompt: prompt,
          idempotencyKey: idempotencyKey,
          onHighDemand: onHighDemand,
          prohibitedAttempts: prohibitedAttempts,
          allowSessionReactivation: false,
        );
      }
      rethrow;
    }
  }

  Future<String> _validateGeminiModel({
    required String apiKey,
    required String model,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
  }) async {
    final normalized = AudioDescriptionFallbacks.normalizeGeminiModelId(model);
    if (normalized.isEmpty) throw StateError('GEMINI_MODEL_REQUIRED');
    if (_validatedGeminiModels.contains(normalized)) return normalized;
    final response = await _getWithRetry(
      Uri.parse('$_geminiBase/models/${Uri.encodeComponent(normalized)}')
          .replace(queryParameters: <String, String>{'key': apiKey}),
      headers: const <String, String>{'Accept': 'application/json'},
      timeout: const Duration(seconds: 45),
      label: 'Gemini model validation',
      onHighDemand: onHighDemand,
    );
    final failure = AudioDescriptionFallbacks.classifyHttp(
      statusCode: response.statusCode,
      body: response.body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _AdProviderException(
        failure,
        'Gemini model validation HTTP ${response.statusCode}: ${_short(response.body)}',
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (!AudioDescriptionFallbacks.modelSupportsGenerateContent(decoded)) {
      throw _AdProviderException(
        AdFailureKind.invalidArgument,
        'Gemini model $normalized does not support generateContent',
      );
    }
    _validatedGeminiModels.add(normalized);
    return normalized;
  }

  Future<http.Response> _getWithRetry(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
    required String label,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
  }) async {
    var highDemandFailures = 0;
    var highDemandDecisionTaken = false;
    while (true) {
      _checkCancel();
      try {
        final response = await _http.get(uri, headers: headers).timeout(timeout);
        final failure = AudioDescriptionFallbacks.classifyHttp(
          statusCode: response.statusCode,
          body: response.body,
        );
        if (failure == AdFailureKind.highDemand) {
          highDemandFailures++;
          if (!highDemandDecisionTaken &&
              AudioDescriptionFallbacks.shouldPromptAfterHighDemand(highDemandFailures)) {
            highDemandDecisionTaken = true;
            if (onHighDemand != null &&
                await onHighDemand() == AiAudioDescriptionWaitDecision.stop) {
              throw const _AudioDescriptionCancelled();
            }
          }
          await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
          continue;
        }
        if (failure == AdFailureKind.transient) {
          await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
          continue;
        }
        return response;
      } on _AudioDescriptionCancelled {
        rethrow;
      } on TimeoutException catch (error) {
        await AppLogger.log('Audio description mobile: $label timeout $error');
        await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
      } on SocketException catch (error) {
        if (!AudioDescriptionFallbacks.isRetryableExceptionText(error.toString())) rethrow;
        await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
      } on http.ClientException catch (error) {
        if (!AudioDescriptionFallbacks.isRetryableExceptionText(error.toString())) rethrow;
        await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
      }
    }
  }

  Future<http.Response> _postJsonWithRetry(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required Duration timeout,
    required String label,
    AiAudioDescriptionHighDemandCallback? onHighDemand,
    bool boundFileVerificationFailures = false,
  }) async {
    var highDemandFailures = 0;
    var highDemandDecisionTaken = false;
    var verificationFailures = 0;
    while (true) {
      _checkCancel();
      try {
        final response = await _http
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(timeout);
        final failure = AudioDescriptionFallbacks.classifyHttp(
          statusCode: response.statusCode,
          body: response.body,
        );
        if (failure == AdFailureKind.fileVerificationFailed &&
            boundFileVerificationFailures) {
          verificationFailures++;
          if (verificationFailures >=
              AudioDescriptionFallbacks.sonarpadVerificationMaxAttempts) {
            return response;
          }
          await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
          continue;
        }
        if (failure == AdFailureKind.highDemand) {
          highDemandFailures++;
          if (!highDemandDecisionTaken &&
              AudioDescriptionFallbacks.shouldPromptAfterHighDemand(
                highDemandFailures,
              )) {
            highDemandDecisionTaken = true;
            if (onHighDemand != null) {
              final decision = await onHighDemand();
              if (decision == AiAudioDescriptionWaitDecision.stop) {
                throw const _AudioDescriptionCancelled();
              }
            }
          }
          await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
          continue;
        }
        if (failure == AdFailureKind.transient) {
          await AppLogger.log(
            'Audio description mobile: $label temporary HTTP '
            '${response.statusCode}; retrying in '
            '${AudioDescriptionFallbacks.transientRetryDelaySeconds}s',
          );
          await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
          continue;
        }
        return response;
      } on _AudioDescriptionCancelled {
        rethrow;
      } on TimeoutException catch (error) {
        await AppLogger.log('Audio description mobile: $label timeout $error');
        await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
      } on SocketException catch (error) {
        if (!AudioDescriptionFallbacks.isRetryableExceptionText(error.toString())) rethrow;
        await AppLogger.log('Audio description mobile: $label network retry $error');
        await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
      } on http.ClientException catch (error) {
        if (!AudioDescriptionFallbacks.isRetryableExceptionText(error.toString())) rethrow;
        await AppLogger.log('Audio description mobile: $label client retry $error');
        await _cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds);
      }
    }
  }

  Future<void> _cancelableDelay(int seconds) async {
    for (var second = 0; second < seconds; second++) {
      _checkCancel();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<http.Response> _streamFileUpload(
    String uploadUrl,
    File file, {
    String mimeType = 'video/mp4',
  }) async {
    final request = http.StreamedRequest('POST', Uri.parse(uploadUrl));
    request.headers['Content-Type'] = mimeType;
    request.headers['Content-Length'] = '${await file.length()}';
    request.headers['X-Goog-Upload-Offset'] = '0';
    request.headers['X-Goog-Upload-Command'] = 'upload, finalize';
    request.headers['User-Agent'] = 'Sonarpad-Mobile-AI/1';
    await request.sink.addStream(file.openRead());
    await request.sink.close();
    final streamed = await _http.send(request).timeout(const Duration(minutes: 8));
    return http.Response.fromStream(streamed);
  }

  String _extractCandidateText(Object? decoded) {
    if (decoded is Map) {
      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final candidate = candidates.first;
        if (candidate is Map) {
          final content = candidate['content'];
          if (content is Map && content['parts'] is List) {
            final texts = <String>[];
            for (final part in content['parts'] as List) {
              if (part is Map && part['text'] != null) texts.add('${part['text']}');
            }
            if (texts.isNotEmpty) return texts.join('\n');
          }
        }
      }
      for (final key in const ['response', 'provider_response', 'gemini_response', 'data']) {
        if (decoded.containsKey(key)) {
          try {
            return _extractCandidateText(decoded[key]);
          } catch (_) {}
        }
      }
      final text = _findString(decoded, const ['text', 'output_text']);
      if (text != null && text.isNotEmpty) return text;
    }
    throw StateError('GEMINI_RESPONSE_TEXT_MISSING');
  }

  String? _findString(Object? value, List<String> keys) {
    if (value is Map) {
      for (final key in keys) {
        final direct = value[key];
        if (direct is String && direct.trim().isNotEmpty) return direct.trim();
      }
      for (final child in value.values) {
        final found = _findString(child, keys);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findString(child, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _runFfmpeg(List<String> args, String label) async {
    _checkCancel();
    await AppLogger.log('Audio description mobile FFmpeg: $label start');
    final session = await FFmpegKit.executeWithArguments(args);
    final code = await session.getReturnCode();
    _checkCancel();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString() ?? '';
      throw StateError('FFMPEG_${label.toUpperCase().replaceAll(' ', '_')}_FAILED: ${_short(logs)}');
    }
  }

  Future<Directory> _createOperationDirectory() async {
    final base = await AppCacheService.directory(AppCacheService.mediaExportsFolder);
    final dir = Directory(p.join(
      base.path,
      'audio_description_${DateTime.now().microsecondsSinceEpoch}',
    ));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<void> cleanupResult(AiAudioDescriptionResult result) async {
    final parent = File(result.mp3Path).parent;
    try {
      if (await parent.exists()) await parent.delete(recursive: true);
    } catch (_) {}
  }

  void _checkCancel() {
    if (_cancelRequested) throw const _AudioDescriptionCancelled();
  }

  void _emit(
    void Function(AiAudioDescriptionProgress progress) callback,
    String stage,
    double value, {
    String? detail,
  }) {
    callback(
      AiAudioDescriptionProgress(
        stage,
        value.clamp(0.0, 1.0).toDouble(),
        detail: detail,
      ),
    );
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _languageName(String code) => switch (code) {
        'it' => 'Italian',
        'en' => 'English',
        'es' => 'Spanish',
        'fr' => 'French',
        'pt' => 'Portuguese (Portugal)',
        'pt_BR' => 'Portuguese (Brazil)',
        'pl' => 'Polish',
        'cs' => 'Czech',
        'de' => 'German',
        'zh_CN' || 'zh' => 'Simplified Chinese',
        'uk' => 'Ukrainian',
        _ => code,
      };

  String _safeBaseName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
    return cleaned.isEmpty ? 'video' : cleaned;
  }

  String _short(String value) {
    final flat = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= 600 ? flat : '${flat.substring(0, 600)}…';
  }
}

class _ProbeInfo {
  const _ProbeInfo({required this.durationSec, required this.hasAudio});
  final double durationSec;
  final bool hasAudio;
}

class _SafeSlot {
  const _SafeSlot({
    required this.id,
    required this.start,
    required this.end,
    required this.mandatory,
    required this.maxWords,
  });
  final String id;
  final double start;
  final double end;
  final bool mandatory;
  final int maxWords;

  Map<String, Object?> toJson() => <String, Object?>{
        'slot_id': id,
        'start_time_sec': double.parse(start.toStringAsFixed(3)),
        'end_time_sec': double.parse(end.toStringAsFixed(3)),
        'duration_sec': double.parse((end - start).toStringAsFixed(3)),
        'mandatory': mandatory,
        'max_words': maxWords,
      };
}

class _GeneratedDescription {
  const _GeneratedDescription({
    required this.slotId,
    required this.slotStart,
    required this.slotEnd,
    required this.requestedStart,
    required this.requestedEnd,
    required this.evidenceTime,
    required this.text,
    required this.mandatory,
  });

  final String slotId;
  final double slotStart;
  final double slotEnd;
  final double requestedStart;
  final double requestedEnd;
  final double evidenceTime;
  final String text;
  final bool mandatory;

  Map<String, Object?> toCheckpoint() => <String, Object?>{
        'slot_id': slotId,
        'slot_start': slotStart,
        'slot_end': slotEnd,
        'requested_start': requestedStart,
        'requested_end': requestedEnd,
        'evidence_time': evidenceTime,
        'text': text,
        'mandatory': mandatory,
      };

  static _GeneratedDescription? fromCheckpoint(Map<dynamic, dynamic> item) {
    double? number(Object? value) => value is num
        ? value.toDouble()
        : double.tryParse('${value ?? ''}');
    final slotId = '${item['slot_id'] ?? ''}'.trim();
    final text = '${item['text'] ?? ''}'.trim();
    final slotStart = number(item['slot_start']);
    final slotEnd = number(item['slot_end']);
    final requestedStart = number(item['requested_start']);
    final requestedEnd = number(item['requested_end']);
    final evidence = number(item['evidence_time']);
    if (slotId.isEmpty || text.isEmpty || slotStart == null || slotEnd == null ||
        requestedStart == null || requestedEnd == null || evidence == null) {
      return null;
    }
    return _GeneratedDescription(
      slotId: slotId,
      slotStart: slotStart,
      slotEnd: slotEnd,
      requestedStart: requestedStart,
      requestedEnd: requestedEnd,
      evidenceTime: evidence,
      text: text,
      mandatory: item['mandatory'] == true,
    );
  }

  _GeneratedDescription copyWith({String? text}) => _GeneratedDescription(
        slotId: slotId,
        slotStart: slotStart,
        slotEnd: slotEnd,
        requestedStart: requestedStart,
        requestedEnd: requestedEnd,
        evidenceTime: evidenceTime,
        text: text ?? this.text,
        mandatory: mandatory,
      );
}

class _Placement {
  _Placement.included({
    required this.description,
    required this.ttsPath,
    required this.ttsDuration,
    required this.originalStart,
    required this.extraPause,
  })  : included = true,
        reason = null,
        finalStart = 0,
        finalEnd = 0;

  _Placement.excluded(this.description, this.reason)
      : included = false,
        ttsPath = null,
        ttsDuration = 0,
        originalStart = description.slotStart,
        extraPause = 0,
        finalStart = 0,
        finalEnd = 0;

  final _GeneratedDescription description;
  final bool included;
  final String? reason;
  final String? ttsPath;
  final double ttsDuration;
  final double originalStart;
  final double extraPause;
  double finalStart;
  double finalEnd;

  Map<String, Object?> toJson() => <String, Object?>{
        'slot_id': description.slotId,
        'slot_start_sec': description.slotStart,
        'slot_end_sec': description.slotEnd,
        'evidence_time_sec': description.evidenceTime,
        'description_text': description.text,
        'mandatory': description.mandatory,
        'included': included,
        'excluded_reason': reason,
        'tts_duration_sec': ttsDuration,
        'original_start_sec': originalStart,
        'output_start_sec': included ? finalStart : null,
        'output_end_sec': included ? finalEnd : null,
        'extended_pause_sec': extraPause,
      };
}

class _ParsedGemini {
  const _ParsedGemini({
    required this.descriptions,
    required this.glossary,
    this.parseOk = true,
    this.salvaged = false,
  });
  final List<_GeneratedDescription> descriptions;
  final List<Map<String, Object?>> glossary;
  final bool parseOk;
  final bool salvaged;
}

class _AiGenerationResult {
  const _AiGenerationResult({
    required this.text,
    required this.model,
    required this.rawResponse,
  });
  final String text;
  final String model;
  final Object? rawResponse;
}

class _BriefVisualRetryResult {
  const _BriefVisualRetryResult({
    required this.descriptions,
    required this.glossary,
    required this.model,
  });
  final List<_GeneratedDescription> descriptions;
  final List<Map<String, Object?>> glossary;
  final String model;
}

class _ChunkProcessResult {
  const _ChunkProcessResult({required this.parsed, required this.model});
  final _ParsedGemini parsed;
  final String model;
}

class _AdCheckpoint {
  const _AdCheckpoint({
    required this.path,
    required this.completedChunks,
    required this.model,
    required this.descriptions,
    required this.glossary,
  });
  final String path;
  final int completedChunks;
  final String model;
  final List<_GeneratedDescription> descriptions;
  final List<Map<String, Object?>> glossary;
}

class _AdProviderException implements Exception {
  const _AdProviderException(
    this.kind,
    this.message, {
    this.statusCode,
    this.providerCode,
  });
  final AdFailureKind kind;
  final String message;
  final int? statusCode;
  final String? providerCode;

  @override
  String toString() => 'AD_PROVIDER_${kind.name.toUpperCase()}: $message';
}

class _GeminiFileProcessingException implements Exception {
  const _GeminiFileProcessingException({this.providerCode, this.state = 'FAILED'});
  final String? providerCode;
  final String state;

  @override
  String toString() =>
      'GEMINI_FILE_PROCESSING_FAILED state=$state code=${providerCode ?? 'unknown'}';
}

class _GeminiUpload {
  const _GeminiUpload({required this.name, required this.uri});
  final String name;
  final String uri;
}

class _AudioDescriptionCancelled implements Exception {
  const _AudioDescriptionCancelled();
  @override
  String toString() => 'AUDIO_DESCRIPTION_CANCELLED';
}
