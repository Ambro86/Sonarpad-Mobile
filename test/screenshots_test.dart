import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/main.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/screens/home_screen.dart';
import 'package:sonarpad_mobile_starter/screens/news_screen.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_screen.dart';
import 'package:sonarpad_mobile_starter/screens/radio_screen.dart';
import 'package:sonarpad_mobile_starter/screens/route_screen.dart';
import 'package:sonarpad_mobile_starter/screens/settings_screen.dart';
import 'package:sonarpad_mobile_starter/screens/wikipedia_screen.dart';

Directory? _baseDir;
late String _tempPath;
late String _docsPath;
late String _supportPath;
late String _cachePath;
late String _downloadsPath;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    _installPluginMocks();
  });

  setUp(() {
    _resetScreenshotPreferences();
  });

  tearDown(() async {
    // Dispose the current screen so subscriptions/timers from one screenshot
    // cannot keep the next test alive. This is important for GitHub Actions.
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget screen, {
    bool mustNotShowSpinner = false,
  }) async {
    debugPrint('SCREENSHOT_START $name');
    await tester.pumpWidgetBuilder(
      _wrapScreen(screen),
      surfaceSize: const Size(414, 896),
      wrapper: (child) => child,
    );

    await _pumpFixed(tester, const Duration(seconds: 3));

    if (mustNotShowSpinner) {
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: '$name è ancora in caricamento: screenshot non valido.',
      );
    }

    await screenMatchesGolden(
      tester,
      name,
      customPump: (tester) async {
        await _pumpFixed(tester, const Duration(milliseconds: 500));
      },
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    debugPrint('SCREENSHOT_DONE $name');
  }

  testGoldens('01_home_screen', (tester) async {
    await capture(tester, '01_home_screen', const HomeScreen());
  });

  testGoldens('02_settings_screen', (tester) async {
    await capture(
      tester,
      '02_settings_screen',
      const SettingsScreen(),
      mustNotShowSpinner: true,
    );
  });

  testGoldens('03_documents_screen', (tester) async {
    await capture(
      tester,
      '03_documents_screen',
      const DocumentsScreen(),
      mustNotShowSpinner: true,
    );
  });

  testGoldens('04_wikipedia_screen', (tester) async {
    await capture(tester, '04_wikipedia_screen', const WikipediaScreen());
  });

  testGoldens('05_news_screen', (tester) async {
    await capture(tester, '05_news_screen', const NewsScreen());
  });

  testGoldens('06_podcast_screen', (tester) async {
    await capture(tester, '06_podcast_screen', const PodcastScreen());
  });

  testGoldens('07_radio_screen', (tester) async {
    await capture(tester, '07_radio_screen', const RadioScreen());
  });

  testGoldens('08_route_screen', (tester) async {
    await capture(tester, '08_route_screen', const RouteScreen());
  });
}

Widget _wrapScreen(Widget child) {
  const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('it'),
    theme: sonarpadTheme(),
    home: child,
  );
}

Future<void> _pumpFixed(WidgetTester tester, Duration duration) async {
  final ticks = (duration.inMilliseconds / 100).ceil().clamp(1, 200);
  for (var i = 0; i < ticks; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _installPluginMocks() {
  _baseDir ??= Directory.systemTemp.createTempSync('sonarpad_screenshots_');

  String ensureDirectory(String name) {
    final directory = Directory('${_baseDir!.path}/$name');
    directory.createSync(recursive: true);
    return directory.path;
  }

  _tempPath = ensureDirectory('temp');
  _docsPath = ensureDirectory('documents');
  _supportPath = ensureDirectory('support');
  _cachePath = ensureDirectory('cache');
  _downloadsPath = ensureDirectory('downloads');
  _createDemoDocuments();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
    switch (methodCall.method) {
      case 'getTemporaryDirectory':
        return _tempPath;
      case 'getApplicationDocumentsDirectory':
        return _docsPath;
      case 'getApplicationSupportDirectory':
        return _supportPath;
      case 'getApplicationCacheDirectory':
        return _cachePath;
      case 'getLibraryDirectory':
        return _supportPath;
      case 'getDownloadsDirectory':
        return _downloadsPath;
      case 'getExternalStorageDirectory':
        return _docsPath;
      case 'getExternalCacheDirectories':
        return <String>[_cachePath];
      case 'getExternalStorageDirectories':
        return <String>[_docsPath];
    }
    return null;
  });

  const packageInfoChannel = MethodChannel('dev.fluttercommunity.plus/package_info');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(packageInfoChannel, (methodCall) async {
    if (methodCall.method == 'getAll') {
      return <String, dynamic>{
        'appName': 'Sonarpad',
        'packageName': 'com.ambro86.sonarpad',
        'version': '0.3.1',
        'buildNumber': '5',
        'buildSignature': '',
        'installerStore': null,
      };
    }
    return null;
  });

  const wakelockChannel = MethodChannel('wakelock_plus');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(wakelockChannel, (methodCall) async {
    switch (methodCall.method) {
      case 'toggle':
      case 'enable':
      case 'disable':
        return null;
      case 'isEnabled':
        return false;
    }
    return null;
  });

  const flutterTtsChannel = MethodChannel('flutter_tts');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(flutterTtsChannel, (methodCall) async {
    switch (methodCall.method) {
      case 'getLanguages':
        return <String>['it-IT', 'en-US'];
      case 'getVoices':
        return <Map<String, String>>[
          <String, String>{'name': 'Luca (test)', 'locale': 'it-IT'},
          <String, String>{'name': 'Alice (test)', 'locale': 'it-IT'},
        ];
      case 'getDefaultVoice':
        return <String, String>{'name': 'Luca (test)', 'locale': 'it-IT'};
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
  });
}

void _createDemoDocuments() {
  final sonarpadDocsDir = Directory('$_docsPath/Documenti');
  sonarpadDocsDir.createSync(recursive: true);

  File('${sonarpadDocsDir.path}/Esempio Sonarpad.txt').writeAsStringSync(
    'Questo è un documento dimostrativo di Sonarpad.\n\n'
    'La lettura può essere interrotta e ripresa dal paragrafo corretto.\n\n'
    'È possibile cercare nel documento ed esportare in vari formati.',
  );

  File('${sonarpadDocsDir.path}/Dettagli navigazione demo.txt').writeAsStringSync(
    'Avanti dritto per 80 metri.\n\n'
    'Svolta a destra in via Roma.\n\n'
    'Continua per 200 metri fino alla destinazione.',
  );
}

void _resetScreenshotPreferences() {
  final now = DateTime(2026, 6, 19, 10, 30).toIso8601String();
  final radioDirectoryCache = jsonEncode({
    'savedAt': now,
    'items': [
      {'name': 'italian', 'stationcount': 1200},
      {'name': 'english', 'stationcount': 1000},
      {'name': 'french', 'stationcount': 800},
      {'name': 'spanish', 'stationcount': 700},
    ],
  });
  final countryDirectoryCache = jsonEncode({
    'savedAt': now,
    'items': [
      {'name': 'it', 'stationcount': 1000},
      {'name': 'us', 'stationcount': 900},
      {'name': 'fr', 'stationcount': 700},
      {'name': 'es', 'stationcount': 650},
    ],
  });

  final demoDocuments = <Map<String, Object?>>[
    <String, Object?>{
      'id': 'screenshot_doc_1',
      'name': 'Esempio Sonarpad.txt',
      'path': 'Documenti/Esempio Sonarpad.txt',
      'extension': 'txt',
      'addedAt': now,
      'bookmarkIndex': 0,
      'isTemporary': false,
      'isFolder': false,
    },
    <String, Object?>{
      'id': 'screenshot_doc_2',
      'name': 'Dettagli navigazione demo.txt',
      'path': 'Documenti/Dettagli navigazione demo.txt',
      'extension': 'txt',
      'addedAt': now,
      'bookmarkIndex': 0,
      'isTemporary': false,
      'isFolder': false,
    },
  ];

  SharedPreferences.setMockInitialValues(<String, Object>{
    'sonarpad_app_language': 'it',
    'sonarpad_last_seen_changelog_version': '0.3.1',
    'sonarpad_home_grouping_enabled': true,
    'settings_tv_code': '',
    'settings_secret_code': '',
    'document_library_v1': jsonEncode(demoDocuments),
    'sonarpad_radio_directory_languages': radioDirectoryCache,
    'sonarpad_radio_directory_countries': countryDirectoryCache,
  });
}
