import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/main.dart';
import 'package:sonarpad_mobile_starter/screens/home_screen.dart';
import 'package:sonarpad_mobile_starter/screens/settings_screen.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/screens/wikipedia_screen.dart';
import 'package:sonarpad_mobile_starter/screens/news_screen.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_screen.dart';
import 'package:sonarpad_mobile_starter/screens/radio_screen.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('Generazione Screenshot App', (tester) async {
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

    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(devices: [
        Device.iphone11, // Generiamo solo per iPhone 11 (utile per store)
      ])
      ..addScenario(
        widget: const SonarpadApp(), 
        name: '01_Home',
      )
      ..addScenario(
        widget: MaterialApp(
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: const Scaffold(body: SettingsScreen()),
        ),
        name: '02_Settings',
      )
      ..addScenario(
        widget: MaterialApp(
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: const Scaffold(body: DocumentsScreen()),
        ),
        name: '03_Documents',
      )
      ..addScenario(
        widget: MaterialApp(
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: const Scaffold(body: WikipediaScreen()),
        ),
        name: '04_Wikipedia',
      )
      ..addScenario(
        widget: MaterialApp(
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: const Scaffold(body: NewsScreen()),
        ),
        name: '05_News',
      )
      ..addScenario(
        widget: MaterialApp(
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: const Scaffold(body: PodcastScreen()),
        ),
        name: '06_Podcast',
      )
      ..addScenario(
        widget: MaterialApp(
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: const Scaffold(body: RadioScreen()),
        ),
        name: '07_Radio',
      );

    await tester.pumpDeviceBuilder(builder);
    await tester.pump(const Duration(milliseconds: 500));

    await screenMatchesGolden(tester, 'app_screenshots');
  });
}
