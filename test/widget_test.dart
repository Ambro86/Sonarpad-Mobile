// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarpad_mobile_starter/main.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/settings_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getVoices' ||
          methodCall.method == 'getLanguages') {
        return [];
      }
      return 1;
    });
  });

  testWidgets('Home screen shows localized actions',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'sonarpad_app_language': 'it',
      'sonarpad_home_grouping_enabled': true,
    });
    await tester.pumpWidget(const SonarpadApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Documenti', skipOffstage: false), findsOneWidget);
    expect(find.text('Radio', skipOffstage: false), findsOneWidget);
    expect(find.text('Calendario', skipOffstage: false), findsOneWidget);
    expect(find.text('Notizie', skipOffstage: false), findsOneWidget);
    expect(find.text('Podcast', skipOffstage: false), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Impostazioni'), 200);
    expect(find.text('Impostazioni'), findsOneWidget);
  });

  testWidgets('Settings code field follows selected app language',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'sonarpad_app_language': 'it',
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sonarpad code for extra features'), findsOneWidget);
    expect(find.text('Paste code'), findsOneWidget);
    expect(find.text('Request code from author'), findsOneWidget);
  });
}
