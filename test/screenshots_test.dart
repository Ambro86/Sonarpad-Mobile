import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/main.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/screens/news_screen.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_screen.dart';
import 'package:sonarpad_mobile_starter/screens/radio_screen.dart';
import 'package:sonarpad_mobile_starter/screens/route_screen.dart';
import 'package:sonarpad_mobile_starter/screens/settings_screen.dart';
import 'package:sonarpad_mobile_starter/screens/wikipedia_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getVoices':
            return <Map<String, String>>[
              <String, String>{'name': 'Luca (test)', 'locale': 'it-IT'},
              <String, String>{'name': 'Alice (test)', 'locale': 'it-IT'},
            ];
          case 'getLanguages':
            return <String>['it-IT', 'en-US'];
          case 'getDefaultVoice':
            return <String, String>{
              'name': 'Luca (test)',
              'locale': 'it-IT',
            };
          case 'isLanguageAvailable':
          case 'setLanguage':
          case 'setVoice':
          case 'setSpeechRate':
          case 'setPitch':
          case 'setVolume':
          case 'stop':
          case 'speak':
            return 1;
        }
        return null;
      },
    );

    await loadAppFonts();
  });

  testGoldens('Generazione Screenshot Singoli', (tester) async {
    final demoDocuments = await _prepareDemoDocuments();

    SharedPreferences.setMockInitialValues(<String, Object>{
      // Forza la lingua italiana nel set screenshot App Store italiano.
      'sonarpad_app_language': 'it',

      // Evita che il dialog del changelog copra la Home durante gli screenshot.
      'sonarpad_last_seen_changelog_version': '0.3.1',

      // Mantiene stabile il layout della Home.
      'sonarpad_home_grouping_enabled': true,

      // Impostazioni coerenti e già compilate.
      'settings_tv_code': '',
      'settings_secret_code': '',
      'sonarpad_tts_engine': 'edge',
      'sonarpad_tts_language': 'it',
      'sonarpad_tts_voice': 'it-IT-ElsaNeural',
      'sonarpad_tts_speed': 1.0,
      'sonarpad_tts_pitch': 1.0,

      // Libreria documenti popolata, così lo screenshot Documenti non resta vuoto.
      'document_library_v1': jsonEncode(demoDocuments),
    });

    const delegates = [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ];

    Widget buildScreen(Widget child) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        theme: sonarpadTheme(),
        home: child,
      );
    }

    Future<void> waitForScreenReady() async {
      // Prima lasciamo partire initState, future e caricamenti asincroni.
      await tester.pump();
      for (var i = 0; i < 40; i += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Poi proviamo a stabilizzare la UI. Se resta un'animazione infinita,
      // non blocchiamo il test: facciamo comunque qualche pump finale.
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 8),
        );
      } catch (_) {
        for (var i = 0; i < 10; i += 1) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    }

    final screens = <String, Widget>{
      '01_home_screen': const SonarpadApp(),
      '02_settings_screen': buildScreen(const SettingsScreen()),
      '03_documents_screen': buildScreen(const DocumentsScreen()),
      '04_wikipedia_screen': buildScreen(const WikipediaScreen()),
      '05_news_screen': buildScreen(const NewsScreen()),
      '06_podcast_screen': buildScreen(const PodcastScreen()),
      '07_radio_screen': buildScreen(const RadioScreen()),
      '08_route_screen': buildScreen(const RouteScreen()),
    };

    for (final entry in screens.entries) {
      await tester.pumpWidgetBuilder(
        entry.value,
        surfaceSize: const Size(414, 896),
        wrapper: (child) => child,
      );
      await waitForScreenReady();
      await _failIfScreenIsStillLoading(tester, entry.key);
      await screenMatchesGolden(
        tester,
        entry.key,
        customPump: (tester) => waitForScreenReady(),
      );
    }
  });
}

Future<List<Map<String, Object?>>> _prepareDemoDocuments() async {
  final appDir = await getApplicationDocumentsDirectory();
  final docsDir = Directory('${appDir.path}/Documenti');
  await docsDir.create(recursive: true);

  final demoDate = DateTime(2026, 6, 19, 10, 30);

  final exampleDoc = File('${docsDir.path}/Esempio Sonarpad.txt');
  await exampleDoc.writeAsString(
    'Questo è un documento dimostrativo di Sonarpad.\n\n'
    'La lettura può essere interrotta e ripresa dal paragrafo corretto.\n\n'
    'È possibile cercare nel documento ed esportare in DOCX, EPUB, MP3 o M4B.',
  );

  final routeDoc = File('${docsDir.path}/Dettagli navigazione demo.txt');
  await routeDoc.writeAsString(
    'Avanti dritto per 80 metri.\n\n'
    'Svolta a destra in via Roma.\n\n'
    'Continua per 200 metri fino alla destinazione.',
  );

  return <Map<String, Object?>>[
    <String, Object?>{
      'id': 'screenshot_doc_1',
      'name': 'Esempio Sonarpad.txt',
      'path': 'Documenti/Esempio Sonarpad.txt',
      'extension': 'txt',
      'addedAt': demoDate.toIso8601String(),
      'bookmarkIndex': 0,
      'isTemporary': false,
      'isFolder': false,
    },
    <String, Object?>{
      'id': 'screenshot_doc_2',
      'name': 'Dettagli navigazione demo.txt',
      'path': 'Documenti/Dettagli navigazione demo.txt',
      'extension': 'txt',
      'addedAt': demoDate.toIso8601String(),
      'bookmarkIndex': 0,
      'isTemporary': false,
      'isFolder': false,
    },
  ];
}

Future<void> _failIfScreenIsStillLoading(WidgetTester tester, String name) async {
  if (name != '02_settings_screen' && name != '03_documents_screen') return;

  final progressIndicators = find.byType(CircularProgressIndicator);
  if (progressIndicators.evaluate().isNotEmpty) {
    fail(
      '$name è ancora in caricamento. '
      'Gli screenshot App Store non devono mostrare solo una rotellina.',
    );
  }
}
