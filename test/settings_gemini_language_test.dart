import 'package:sonarpad_mobile_starter/tts/gemini_tts_bridge.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'sonartube_audio_track_player_test.dart' show PlayerTestAudioPlatform;
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/settings_screen.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  testWidgets('Gemini language is independent and saved from voice options', (tester) async {
    final temp = Directory.systemTemp.createTempSync('sonarpad_settings_test_');
    final original = PathProviderPlatform.instance;
    final originalAudio = JustAudioPlatform.instance;
    JustAudioPlatform.instance = PlayerTestAudioPlatform();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (call) async => call.method == 'setActive' ? true : null);
    PathProviderPlatform.instance = _Paths(temp.path);
    SharedPreferences.setMockInitialValues({'sonarpad_tts_engine': 'gemini', 'sonarpad_gemini_tts_voice': 'Leda', 'ad_mobile_gemini_api_key': 'test-key'});
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'), (call) async => call.method == 'getVoices' ? [] : 1);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Text('Home'))));
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(UniversalAccessibleList).evaluate().isNotEmpty) break;
    }
    UniversalAccessibleList form() => tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
    AccessibleListRow row(String id) => form().sections.expand((section) => section.rows).singleWhere((row) => row.id == id);
    expect(row('gemini_language').options, hasLength(15));
    expect(row('gemini_language').options.first.label, 'Detect automatically');
    expect(row('gemini_language').kind, 'slider');
    expect(row('gemini_language').options.any((option) => option.label.contains('Brazil')), isTrue);
    final voice = row('gemini_voice').value;
    await row('gemini_language').onValueChanged!(
      (GeminiTtsBridge.languageInstructions.keys.toList().indexOf('it') + 1).toDouble());
    await tester.pumpAndSettle();
    expect(row('gemini_voice').value, voice);
    expect(row('gemini_language').valueLabel, 'Italian');
    await row('tts_engine').onValueChanged!(0.0);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await row('tts_engine').onValueChanged!(2.0);
    });
    await tester.pumpAndSettle();
    expect(row('gemini_language').value, 'it');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(await AppSettingsService().loadGeminiTtsLanguage(), '');
    final l10n = AppLocalizations.of(tester.element(find.byType(SettingsScreen)));
    await tester.tap(find.text(l10n.annulla));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text(l10n.saveSettings).last);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    for (var i = 0; i < 250 && find.byType(SettingsScreen).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(await AppSettingsService().loadGeminiTtsLanguage(), 'it');
    expect(await AppSettingsService().loadGeminiTtsVoice(), 'Leda');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    PathProviderPlatform.instance = original;
    JustAudioPlatform.instance = originalAudio;
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
  });
}
