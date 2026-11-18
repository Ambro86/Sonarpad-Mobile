import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/tts/gemini_tts_bridge.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';

Uint8List wav() {
  final bytes = Uint8List(1004);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 24000, Endian.little);
  data.setUint32(28, 48000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, 960, Endian.little);
  data.setInt16(44, 2000, Endian.little);
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'Credentials follow the selected AD provider without fallback',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ad_mobile_sonarpad_access_code', 'sp_test');
      expect(await GeminiTtsBridge.hasCredentials(), isFalse);
      await prefs.setString('ad_mobile_provider', 'sonarpad');
      expect(await GeminiTtsBridge.hasCredentials(), isTrue);
      await prefs.remove('ad_mobile_sonarpad_access_code');
      await prefs.setString(GeminiTtsBridge.apiKeyPreference, 'personal_test');
      expect(await GeminiTtsBridge.hasCredentials(), isFalse);
    },
  );
  test('Sonarpad renews session and keeps the paid retry key', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var activations = 0;
    var generations = 0;
    final keys = <String?>[];
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(request.headers.value('x-goog-api-key'), isNull);
      if (request.uri.path == '/activate') {
        activations++;
        expect(body['code'], 'sp_mock');
        expect(body['device_id'], 'device_mock');
        request.response.write(
          jsonEncode({'session_token': 'sst_$activations'}),
        );
      } else {
        keys.add(request.headers.value('x-idempotency-key'));
        expect(body['generationConfig']['responseModalities'], ['AUDIO']);
        expect(
          request.headers.value('authorization'),
          'Bearer sst_$activations',
        );
        generations++;
        if (generations == 1) {
          request.response.statusCode = 401;
          request.response.write('{"error":"invalid_session"}');
        } else if (generations == 2) {
          request.response.statusCode = 503;
          request.response.write('{"error":"generation_in_progress"}');
        } else {
          request.response.write(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'inlineData': {'data': base64Encode(wav())},
                      },
                    ],
                  },
                },
              ],
            }),
          );
        }
      }
      await request.response.close();
    });
    final bridge = GeminiTtsBridge(
      sonarpadBase: Uri.parse('http://127.0.0.1:${server.port}/'),
      retryDelay: Duration.zero,
    );
    expect(
      await bridge.synthesize(
        text: 'Ciao',
        voice: 'Kore',
        apiKey: '',
        sonarpadCode: 'sp_mock',
        deviceId: 'device_mock',
      ),
      wav(),
    );
    expect(activations, 2);
    expect(generations, 3);
    expect(keys.toSet().length, 1);
    expect(keys.first, startsWith('speech-'));
  });
  for (final status in [402, 409, 200]) {
    test(
      'Paid TTS stops on credit, lost audio or invalid success: $status',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var generations = 0;
        server.listen((request) async {
          await request.drain<void>();
          if (request.uri.path == '/activate') {
            request.response.write('{"session_token":"sst_mock"}');
          } else {
            generations++;
            request.response.statusCode = status;
            request.response.write(
              status == 402
                  ? '{"error":"insufficient_credit"}'
                  : status == 409
                  ? '{"error":"speech_audio_not_retained"}'
                  : '{"candidates":[]}',
            );
          }
          await request.response.close();
        });
        final bridge = GeminiTtsBridge(
          sonarpadBase: Uri.parse('http://127.0.0.1:${server.port}/'),
          retryDelay: Duration.zero,
        );
        await expectLater(
          bridge.synthesize(
            text: 'Test',
            voice: 'Kore',
            apiKey: '',
            sonarpadCode: 'sp_mock',
            deviceId: 'device_mock',
          ),
          throwsA(
            isA<GeminiTtsException>().having(
              (e) => e.retryable,
              'retryable',
              false,
            ),
          ),
        );
        expect(generations, 1);
      },
    );
  }
  test('Eight paid requests share one activation', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var activations = 0;
    var active = 0;
    var peak = 0;
    final keys = <String?>{};
    server.listen((request) async {
      await request.drain<void>();
      if (request.uri.path == '/activate') {
        activations++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        request.response.write('{"session_token":"sst_parallel"}');
      } else {
        keys.add(request.headers.value('x-idempotency-key'));
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        request.response.write(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'inlineData': {'data': base64Encode(wav())},
                    },
                  ],
                },
              },
            ],
          }),
        );
        active--;
      }
      await request.response.close();
    });
    final base = Uri.parse('http://127.0.0.1:${server.port}/');
    final results = await Future.wait(
      List.generate(
        12,
        (i) => GeminiTtsBridge(sonarpadBase: base).synthesize(
          text: 'Test $i',
          voice: 'Kore',
          apiKey: '',
          sonarpadCode: 'sp_parallel',
          deviceId: 'device_mock',
        ),
      ),
    );
    expect(results.length, 12);
    expect(activations, 1);
    expect(peak, 8);
    expect(keys.length, 12);
  });
  test('Gemini selection preserves Edge and system preferences', () async {
    final settings = AppSettingsService();
    await settings.saveTtsSettings(
      languageCode: 'it',
      voice: 'it-IT-IsabellaNeural',
    );
    await settings.saveSystemTtsVoice('local-voice');
    await settings.saveGeminiTtsVoice('Leda');
    await settings.saveTtsEngine('gemini');
    expect(await settings.loadTtsVoice(), 'Leda');
    expect(await settings.loadEdgeTtsVoice(), 'it-IT-IsabellaNeural');
    expect(await settings.loadSystemTtsVoice(), 'local-voice');
    await settings.saveTtsEngine('edge');
    expect(await settings.loadTtsVoice(), 'it-IT-IsabellaNeural');
    expect(await settings.loadGeminiTtsVoice(), 'Leda');
  });
  test(
    'Language instructions cover app languages without changing the transcript',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final code = locale.languageCode == 'zh' ? 'zh_CN' : locale.toString();
        expect(GeminiTtsBridge.languageInstructions.containsKey(code), isTrue);
      }
      for (final language in GeminiTtsBridge.languageInstructions.keys) {
        final body = GeminiTtsBridge.requestBody(
          'Harry Potter e la pietra filosofale',
          'Leda',
          1,
          1,
          language: language,
        );
        expect(
          body['contents'][0]['parts'][0]['text'],
          'Harry Potter e la pietra filosofale',
        );
        expect(
          body['contents'][0]['parts'][0]['speech_metadata']['style'],
          GeminiTtsBridge.languageInstructions[language],
        );
        expect(
          body['generationConfig']['speechConfig'].containsKey('languageCode'),
          isFalse,
        );
      }
      final italian = GeminiTtsBridge.requestBody(
        'viziosa',
        'Leda',
        1.15,
        1,
        language: 'it',
      );
      expect(
        italian['contents'][0]['parts'][0]['speech_metadata']['style'],
        startsWith(
          'Utilizza esclusivamente un timbro e una pronuncia italiani.',
        ),
      );
      expect(
        italian['contents'][0]['parts'][0]['speech_metadata']['style'],
        contains('115 percent'),
      );
    },
  );
  test(
    'Gemini language is saved independently of application and Edge languages',
    () async {
      final settings = AppSettingsService();
      await settings.saveAppLanguage('fr');
      await settings.saveTtsSettings(
        languageCode: 'en',
        voice: 'en-US-JennyNeural',
      );
      await settings.saveGeminiTtsLanguage('it');
      expect(await AppSettingsService().loadGeminiTtsLanguage(), 'it');
      expect(await settings.loadAppLanguage(), 'fr');
      expect(await settings.loadTtsLanguage(), 'en');
      expect(await settings.loadEdgeTtsVoice(), 'en-US-JennyNeural');
      await settings.saveGeminiTtsLanguage('');
      expect(await settings.loadGeminiTtsLanguage(), '');
    },
  );
  test(
    'Uses the existing AD credential and keeps style out of transcript',
    () async {
      expect(await GeminiTtsBridge.hasCredentials(), isFalse);
      await (await SharedPreferences.getInstance()).setString(
        'ad_mobile_gemini_api_key',
        'test-key',
      );
      expect(await GeminiTtsBridge.hasCredentials(), isTrue);
      final plain = GeminiTtsBridge.requestBody('Ciao', 'Leda', 1, 1);
      expect(plain['contents'][0]['parts'][0], {'text': 'Ciao'});
      final tuned = GeminiTtsBridge.requestBody('Ciao', 'Leda', 1.15, 1);
      expect(tuned['contents'][0]['parts'][0]['text'], 'Ciao');
      expect(
        tuned['contents'][0]['parts'][0]['speech_metadata']['style'],
        contains('115 percent'),
      );
      expect(GeminiTtsBridge.voices.toSet().length, 30);
    },
  );
  test(
    'Retries temporary failure with the same text and returns unchanged WAV',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var attempts = 0;
      final bodies = <String>[];
      server.listen((request) async {
        expect(request.uri.query, isEmpty);
        expect(request.headers.value('x-goog-api-key'), 'test-key');
        bodies.add(await utf8.decoder.bind(request).join());
        if (++attempts == 1) {
          request.response.statusCode = 503;
        } else {
          request.response.write(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'inlineData': {
                          'data': base64Encode(wav()),
                          'mimeType': 'audio/wav',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
          );
        }
        await request.response.close();
      });
      final logs = <String>[];
      final bridge = GeminiTtsBridge(
        logger: (line) async {
          logs.add(line);
        },
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/tts'),
        retryDelay: Duration.zero,
      );
      final bytes = await bridge.synthesize(
        text: 'Ciao',
        voice: 'Kore',
        apiKey: 'test-key',
      );
      expect(bytes, orderedEquals(wav()));
      expect(attempts, 2);
      expect(bodies[0], bodies[1]);
      await Future<void>.delayed(Duration.zero);
      final diagnostic = logs.join('\n');
      expect(diagnostic, contains('provider=gemini'));
      expect(diagnostic, contains('reading_response http=503'));
      expect(diagnostic, contains('code=http_503 retryable=true'));
      expect(diagnostic, contains('retry_scheduled'));
      expect(diagnostic, contains('success audio_bytes='));
      expect(diagnostic, isNot(contains('test-key')));
      expect(diagnostic, isNot(contains('Ciao')));
      expect(diagnostic, isNot(contains(base64Encode(wav()))));
    },
  );
  test('Authentication errors are permanent and sanitized', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var attempts = 0;
    server.listen((request) async {
      attempts++;
      await request.drain<void>();
      request.response.statusCode = 403;
      request.response.write('secret server content');
      await request.response.close();
    });
    final bridge = GeminiTtsBridge(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/tts'),
      retryDelay: Duration.zero,
    );
    await expectLater(
      bridge.synthesize(text: 'Ciao', voice: 'Kore', apiKey: 'test-key'),
      throwsA(
        isA<GeminiTtsException>().having(
          (e) => e.toString(),
          'safe error',
          'Gemini TTS: http_403',
        ),
      ),
    );
    expect(attempts, 1);
  });
  test('Invalid responses retry beyond three attempts and recover', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var attempts = 0;
    server.listen((request) async {
      attempts++;
      await request.drain<void>();
      request.response.write(
        jsonEncode(
          attempts < 8
              ? {
                  'promptFeedback': {'blockReason': 'SAFETY'},
                }
              : {
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {
                            'inlineData': {'data': base64Encode(wav())},
                          },
                        ],
                      },
                    },
                  ],
                },
        ),
      );
      await request.response.close();
    });
    final bridge = GeminiTtsBridge(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/tts'),
      retryDelay: Duration.zero,
    );
    expect(
      await bridge.synthesize(text: 'Ciao', voice: 'Kore', apiKey: 'test-key'),
      wav(),
    );
    expect(attempts, 8);
  });
  test(
    'Concurrent instances share eight slots and preserve ordered results',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var active = 0;
      var peak = 0;
      server.listen((request) async {
        active++;
        if (active > peak) peak = active;
        final data = jsonDecode(await utf8.decoder.bind(request).join());
        final index = int.parse(
          data['contents'][0]['parts'][0]['text'] as String,
        );
        await Future<void>.delayed(
          Duration(milliseconds: 100 + (8 - index % 8) * 5),
        );
        final audio = wav();
        ByteData.sublistView(audio).setInt16(44, index + 1, Endian.little);
        request.response.write(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'inlineData': {'data': base64Encode(audio)},
                    },
                  ],
                },
              },
            ],
          }),
        );
        active--;
        await request.response.close();
      });
      final results = await Future.wait([
        for (var i = 0; i < 24; i++)
          GeminiTtsBridge(
            endpoint: Uri.parse('http://127.0.0.1:${server.port}/tts'),
          ).synthesize(text: '$i', voice: 'Kore', apiKey: 'test-key'),
      ]);
      expect(peak, 8);
      for (var i = 0; i < results.length; i++) {
        expect(
          ByteData.sublistView(results[i]).getInt16(44, Endian.little),
          i + 1,
        );
      }
    },
  );
  test(
    'Cancel stops active and queued requests and releases all slots',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final full = Completer<void>();
      var requests = 0;
      var resume = false;
      server.listen((request) async {
        await request.drain<void>();
        if (resume) {
          request.response.write(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'inlineData': {'data': base64Encode(wav())},
                      },
                    ],
                  },
                },
              ],
            }),
          );
          await request.response.close();
        } else if (++requests == 8) {
          full.complete();
        }
      });
      final endpoint = Uri.parse('http://127.0.0.1:${server.port}/tts');
      final bridge = GeminiTtsBridge(endpoint: endpoint);
      final futures = [
        for (var i = 0; i < 12; i++)
          bridge
              .synthesize(text: '$i', voice: 'Kore', apiKey: 'test-key')
              .then<Object>((value) => value, onError: (Object error) => error),
      ];
      await full.future.timeout(const Duration(seconds: 5));
      bridge.cancel();
      final results = await Future.wait(
        futures,
      ).timeout(const Duration(seconds: 2));
      expect(results.every((result) => result is StateError), isTrue);
      expect(requests, 8);
      resume = true;
      expect(
        await GeminiTtsBridge(
          endpoint: endpoint,
        ).synthesize(text: 'Ciao', voice: 'Kore', apiKey: 'test-key'),
        wav(),
      );
    },
  );
  test('Cancel interrupts an in-flight request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = Completer<void>();
    server.listen((request) {
      received.complete();
    });
    final bridge = GeminiTtsBridge(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/tts'),
    );
    final result = bridge.synthesize(
      text: 'Ciao',
      voice: 'Kore',
      apiKey: 'test-key',
    );
    final check = expectLater(result, throwsA(isA<StateError>()));
    await received.future;
    bridge.cancel();
    await check.timeout(const Duration(seconds: 2));
  });
}
