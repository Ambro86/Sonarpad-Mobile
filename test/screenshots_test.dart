import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/main.dart';
import 'package:sonarpad_mobile_starter/screens/settings_screen.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/screens/wikipedia_screen.dart';
import 'package:sonarpad_mobile_starter/screens/news_screen.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_screen.dart';
import 'package:sonarpad_mobile_starter/screens/radio_screen.dart';
import 'package:sonarpad_mobile_starter/screens/route_screen.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('Generazione Screenshot Singoli', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings_tv_code': '',
      'settings_secret_code': '',
    });

    const delegates = [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ];

    Widget buildScreen(Widget child) {
      return MaterialApp(
        localizationsDelegates: delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        home: Scaffold(body: child),
      );
    }

    final screens = {
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
      final builder = DeviceBuilder()
        ..overrideDevicesForAllScenarios(devices: [Device.iphone11])
        ..addScenario(widget: entry.value, name: entry.key);

      await tester.pumpDeviceBuilder(builder);
      await tester.pump(const Duration(milliseconds: 500));
      await screenMatchesGolden(
        tester,
        entry.key,
        customPump: (tester) => tester.pump(const Duration(milliseconds: 500)),
      );
    }
  });
}
