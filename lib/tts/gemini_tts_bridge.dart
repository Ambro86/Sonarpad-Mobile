import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/ai_audiodescription_service.dart'
    show AiAudioDescriptionPreferences;

/// Uses the provider and credential selected in Create AI audio description.
class GeminiTtsBridge {
  GeminiTtsBridge({
    Uri? endpoint,
    Uri? sonarpadBase,
    this.retryDelay = const Duration(seconds: 5),
  }) : sonarpadBase =
           sonarpadBase ?? Uri.parse('https://sonarpad.com/sonarpad-ai/v1/'),
       endpoint =
           endpoint ??
           Uri.https(
             'generativelanguage.googleapis.com',
             '/v1beta/models/gemini-3.8-flash-tts:generateContent',
           );

  static const apiKeyPreference = 'ad_mobile_gemini_api_key';
  static const languagePreference = 'sonarpad_gemini_tts_language';
  static const languageInstructions = <String, String>{
    'it': 'Utilizza esclusivamente un timbro e una pronuncia italiani.',
    'en': 'Use exclusively an American English vocal timbre and pronunciation.',
    'fr': 'Utilise exclusivement un timbre et une prononciation français.',
    'es':
        'Utiliza exclusivamente un timbre y una pronunciación del español de España.',
    'pt':
        'Utiliza exclusivamente um timbre e uma pronúncia do português europeu.',
    'pt_BR':
        'Utilize exclusivamente um timbre e uma pronúncia do português brasileiro.',
    'cs': 'Používej výhradně české zabarvení hlasu a českou výslovnost.',
    'pl': 'Używaj wyłącznie polskiej barwy głosu i polskiej wymowy.',
    'de':
        'Verwende ausschließlich eine deutsche Stimmfärbung und deutsche Aussprache.',
    'uk':
        'Використовуй виключно український тембр голосу та українську вимову.',
    'zh_CN': '仅使用标准普通话的音色和发音。',
    'nl':
        'Gebruik uitsluitend een Nederlandse stemklank en Nederlandse uitspraak.',
    'ro': 'Folosește exclusiv un timbru și o pronunție românești.',
    'tr': 'Yalnızca Türkçe ses tınısı ve Türkçe telaffuz kullan.',
  };

  static const voices = <String>[
    'Zephyr',
    'Puck',
    'Charon',
    'Kore',
    'Fenrir',
    'Leda',
    'Orus',
    'Aoede',
    'Callirrhoe',
    'Autonoe',
    'Enceladus',
    'Iapetus',
    'Umbriel',
    'Algieba',
    'Despina',
    'Erinome',
    'Algenib',
    'Rasalgethi',
    'Laomedeia',
    'Achernar',
    'Alnilam',
    'Schedar',
    'Gacrux',
    'Pulcherrima',
    'Achird',
    'Zubenelgenubi',
    'Vindemiatrix',
    'Sadachbia',
    'Sadaltager',
    'Sulafat',
  ];
  final Uri endpoint;
  final Uri sonarpadBase;
  static final _sessions = <String, Future<String>>{};
  static Future<String>? _deviceId;
  final Duration retryDelay;
  static const maxParallelRequests = 8;
  static int _activeRequests = 0;
  final _clients = <HttpClient>{};
  final _cancelled = Completer<void>();
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
    for (final client in _clients) {
      client.close(force: true);
    }
  }

  void _check() {
    if (_cancelled.isCompleted) throw StateError('AUDIO_DESCRIPTION_CANCELLED');
  }

  static Future<bool> hasCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('ad_mobile_provider') == 'sonarpad'
        ? 'ad_mobile_sonarpad_access_code'
        : apiKeyPreference;
    return prefs.getString(key)?.trim().isNotEmpty == true;
  }

  static Map<String, dynamic> requestBody(
    String text,
    String voice,
    double speed,
    double pitch, {
    String language = '',
  }) {
    final part = <String, dynamic>{'text': text};
    var style = languageInstructions[language] ?? '';
    if (speed != 1 || pitch != 1) {
      if (style.isEmpty) style = 'Read in the original language.';
      style +=
          ' Speaking speed: ${(speed.clamp(0.5, 2.0) * 100).round()} percent of normal. Pitch: ${((pitch.clamp(0.5, 2.0) - 1) * 12).round()} semitones relative to normal.';
    }
    if (style.isNotEmpty) part['speech_metadata'] = {'style': style};
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [part],
        },
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {'voice': voice},
        },
      },
    };
  }

  Future<File> speakToFile({
    required String text,
    required String voice,
    double? speed,
    double? pitch,
    String? language,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bytes = await synthesize(
      text: text,
      voice: voice,
      apiKey: prefs.getString(apiKeyPreference) ?? '',
      sonarpadCode: prefs.getString('ad_mobile_provider') == 'sonarpad'
          ? prefs.getString('ad_mobile_sonarpad_access_code') ?? ''
          : null,
      deviceId: prefs.getString('ad_mobile_provider') == 'sonarpad'
          ? await (_deviceId ??= AiAudioDescriptionPreferences.deviceId())
          : '',
      language: language ?? prefs.getString(languagePreference) ?? '',
      speed: speed ?? prefs.getDouble('sonarpad_tts_speed') ?? 1,
      pitch: pitch ?? prefs.getDouble('sonarpad_tts_pitch') ?? 1,
    );
    _check();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sonarpad_gemini_${const Uuid().v4()}.wav');
    await file.writeAsBytes(bytes);
    if (_cancelled.isCompleted) {
      await file.delete();
      _check();
    }
    return file;
  }

  Future<Uint8List> synthesize({
    required String text,
    required String voice,
    required String apiKey,
    String? sonarpadCode,
    String deviceId = '',
    double speed = 1,
    double pitch = 1,
    String language = '',
  }) async {
    final paid = sonarpadCode != null;
    if (paid ? sonarpadCode.trim().isEmpty : apiKey.trim().isEmpty) {
      throw GeminiTtsException(
        paid ? 'missing_sonarpad_code' : 'missing_api_key',
      );
    }
    final requestKey = 'speech-${const Uuid().v4()}';
    var refreshed = false;
    if (!voices.contains(voice)) throw GeminiTtsException('unknown_voice');
    while (true) {
      _check();
      while (_activeRequests >= maxParallelRequests) {
        await Future.any<void>([
          Future<void>.delayed(const Duration(milliseconds: 25)),
          _cancelled.future,
        ]);
        _check();
      }
      _activeRequests++;
      final client = HttpClient();
      _clients.add(client);
      try {
        return await Future.any<Uint8List>([
          _request(
            client,
            text,
            voice,
            apiKey,
            speed,
            pitch,
            language,
            sonarpadCode: sonarpadCode,
            deviceId: deviceId,
            requestKey: requestKey,
            refreshSession: () {
              if (refreshed) return false;
              refreshed = true;
              return true;
            },
          ).timeout(const Duration(minutes: 8)),
          _cancelled.future.then<Uint8List>(
            (_) => throw StateError('AUDIO_DESCRIPTION_CANCELLED'),
          ),
        ]);
      } on GeminiTtsException catch (error) {
        if (!error.retryable) rethrow;
      } on TimeoutException {
        _check();
      } on SocketException {
        _check();
      } on HttpException {
        _check();
      } finally {
        client.close(force: true);
        _clients.remove(client);
        _activeRequests--;
      }
      await Future.any<void>([
        Future<void>.delayed(retryDelay),
        _cancelled.future,
      ]);
      _check();
    }
  }

  Future<Uint8List> _request(
    HttpClient client,
    String text,
    String voice,
    String key,
    double speed,
    double pitch,
    String language, {
    String? sonarpadCode,
    String deviceId = '',
    String requestKey = '',
    required bool Function() refreshSession,
  }) async {
    final paid = sonarpadCode != null;
    final sessionKey = '$sonarpadBase|$sonarpadCode|$deviceId';
    Future<String>? session;
    String? token;
    if (paid) {
      session = _sessions.putIfAbsent(
        sessionKey,
        () => _activate(client, sonarpadCode.trim(), deviceId),
      );
      try {
        token = await session;
      } catch (_) {
        if (identical(_sessions[sessionKey], session)) {
          _sessions.remove(sessionKey);
        }
        rethrow;
      }
    }
    _check();
    final request = await client.postUrl(
      paid ? sonarpadBase.resolve('generate') : endpoint,
    );
    if (paid) {
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('X-Idempotency-Key', requestKey);
    } else {
      request.headers.set('x-goog-api-key', key.trim());
    }
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(requestBody(text, voice, speed, pitch, language: language)),
    );
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    if (paid && response.statusCode == 401 && refreshSession()) {
      if (identical(_sessions[sessionKey], session)) {
        _sessions.remove(sessionKey);
      }
      throw GeminiTtsException('session_expired', retryable: true);
    }
    if (paid && response.statusCode != 200) {
      throw _sonarpadError(response.statusCode, raw);
    }
    if (response.statusCode != 200) {
      final exhausted = raw.contains('PREPAID_CREDITS_DEPLETED');
      throw GeminiTtsException(
        exhausted ? 'credits_depleted' : 'http_${response.statusCode}',
        retryable:
            !exhausted &&
            [408, 429, 500, 502, 503, 504].contains(response.statusCode),
      );
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final candidates = data['candidates'] as List? ?? [];
      final candidate = candidates.isEmpty
          ? <String, dynamic>{}
          : candidates.first as Map;
      final finish = candidate['finishReason'];
      if ((data['promptFeedback']?['blockReason'] ?? '')
              .toString()
              .isNotEmpty ||
          [
            'SAFETY',
            'PROHIBITED_CONTENT',
            'RECITATION',
            'MALFORMED_RESPONSE',
          ].contains(finish)) {
        throw GeminiTtsException(
          'blocked_or_malformed',
          retryable: !paid,
          bounded: true,
        );
      }
      if (finish == 'MAX_TOKENS') {
        throw GeminiTtsException('truncated', retryable: !paid);
      }
      for (final part in candidate['content']?['parts'] ?? []) {
        final encoded = part['inlineData']?['data'];
        if (encoded is! String) continue;
        final wav = base64Decode(encoded);
        if (_audibleWav(wav)) return wav;
      }
      throw GeminiTtsException('empty_audio', retryable: !paid);
    } on FormatException {
      throw GeminiTtsException('malformed', retryable: !paid, bounded: true);
    } on TypeError {
      throw GeminiTtsException('malformed', retryable: !paid, bounded: true);
    }
  }

  Future<String> _activate(
    HttpClient client,
    String code,
    String deviceId,
  ) async {
    final request = await client.postUrl(sonarpadBase.resolve('activate'));
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'code': code,
        'device_id': deviceId,
        'device_name': '${Platform.operatingSystem} Sonarpad Mobile',
      }),
    );
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw _sonarpadError(response.statusCode, raw);
    }
    try {
      final token = (jsonDecode(raw) as Map)['session_token'];
      if (token is String && token.startsWith('sst_')) return token;
    } catch (_) {
      // Do not expose activation responses or credentials.
    }
    throw GeminiTtsException('invalid_session_response');
  }

  static GeminiTtsException _sonarpadError(int status, String raw) {
    var code = 'http_$status';
    try {
      final value = (jsonDecode(raw) as Map)['error'];
      if (const {
        'insufficient_credit',
        'provider_spend_cap_reached',
        'global_provider_spend_cap_reached',
        'device_limit_reached',
        'invalid_session',
        'invalid_access_code',
        'billing_reconciliation_required',
        'speech_audio_not_retained',
        'generation_in_progress',
        'maintenance',
      }.contains(value)) {
        code = value as String;
      }
    } catch (_) {
      // Only allowlisted error names are exposed.
    }
    return GeminiTtsException(
      'sonarpad_$code',
      retryable: [408, 429, 500, 502, 503, 504].contains(status),
    );
  }

  static bool _audibleWav(Uint8List wav) {
    if (wav.length < 44 ||
        ascii.decode(wav.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(wav.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      return false;
    }
    final data = ByteData.sublistView(wav);
    var pcm16 = false;
    for (var pos = 12; pos + 8 <= wav.length;) {
      final id = ascii.decode(wav.sublist(pos, pos + 4), allowInvalid: true);
      final length = data.getUint32(pos + 4, Endian.little);
      final start = pos + 8;
      if (start + length > wav.length) return false;
      if (id == 'fmt ' && length >= 16) {
        pcm16 =
            data.getUint16(start, Endian.little) == 1 &&
            data.getUint16(start + 14, Endian.little) == 16;
      }
      if (id == 'data' && pcm16) {
        for (var i = start; i + 1 < start + length; i += 2) {
          if (data.getInt16(i, Endian.little) != 0) return true;
        }
      }
      pos = start + length + length % 2;
    }
    return false;
  }
}

/// Sanitized: never includes the API key, server payload or spoken text.
class GeminiTtsException implements Exception {
  GeminiTtsException(this.code, {this.retryable = false, this.bounded = false});
  final String code;
  final bool retryable;
  final bool bounded;
  @override
  String toString() => 'Gemini TTS: $code';
}
