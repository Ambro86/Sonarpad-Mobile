import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
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
  testWidgets('voice sliders and unsaved exits on iOS and Android', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final homeExit in [false, true]) {
        final temp = Directory.systemTemp.createTempSync(
          'sonarpad_voice_settings_',
        );
        final originalPaths = PathProviderPlatform.instance;
        final originalAudio = JustAudioPlatform.instance;
        rootBundle.clear();
        debugDefaultTargetPlatformOverride = platform;
        PathProviderPlatform.instance = _Paths(temp.path);
        JustAudioPlatform.instance = PlayerTestAudioPlatform();
        configureAccessibleRendererRuntime(useFlutterOnIos: true);
        SharedPreferences.setMockInitialValues({
          'ad_mobile_gemini_api_key': 'test-key',
        });
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => call.method == 'setActive' ? true : null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => call.method == 'getVoices'
              ? [
                  {'name': 'System A', 'locale': 'it-IT'},
                  {'name': 'System B', 'locale': 'it-IT'},
                  {'name': 'English', 'locale': 'en-US'},
                ]
              : 1,
        );
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          PathProviderPlatform.instance = originalPaths;
          JustAudioPlatform.instance = originalAudio;
          configureAccessibleRendererRuntime(useFlutterOnIos: false);
        });
        final semantics = tester.ensureSemantics();

        final nav = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: nav,
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: Text('Home')),
          ),
        );
        Future<void> open() async {
          nav.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          );
          for (var i = 0; i < 100; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 20));
            if (find.byType(UniversalAccessibleList).evaluate().isNotEmpty) {
              break;
            }
          }
          await tester.pumpAndSettle();
        }

        AccessibleListRow row(String id) => tester
            .widget<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList),
            )
            .sections
            .expand((s) => s.rows)
            .singleWhere((r) => r.id == id);
        UniversalAccessibleList currentList() => tester.widget<UniversalAccessibleList>(
          find.byType(UniversalAccessibleList),
        );
        void expectIncrementalUpdate(UniversalAccessibleList before) {
          final after = currentList();
          expect(after.sections.length, before.sections.length);
          for (var section = 0; section < before.sections.length; section++) {
            final oldRows = before.sections[section].rows;
            final newRows = after.sections[section].rows;
            final oldIds = oldRows.map((r) => r.id).toSet();
            final newIds = newRows.map((r) => r.id).toSet();
            for (final id in {...oldIds.difference(newIds), ...newIds.difference(oldIds)}) {
              expect(after.transientRowIds, contains(id),
                reason: '$id must change without reloading the focused native cell');
            }
            expect(oldRows.where((r) => newIds.contains(r.id)).map((r) => '${r.id}:${r.kind}'),
              newRows.where((r) => oldIds.contains(r.id)).map((r) => '${r.id}:${r.kind}'));
          }
        }
        Future<void> choose(String id, double index) async {
          final before = currentList();
          final pitch = row('tts_pitch').sliderValue;
          final speed = row('tts_speed').sliderValue;
          final r = row(id);
          expect(r.kind, 'slider');
          expect(r.accessibilityButtonTrait, false);
          await r.onValueChanged!(index);
          await tester.pumpAndSettle();
          expectIncrementalUpdate(before);
          expect(row('tts_pitch').sliderValue, pitch);
          expect(row('tts_speed').sliderValue, speed);
        }

        await open();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SettingsScreen)),
        );
        final initialTheme = row('theme');
        final initialTemperature = row('temperature_unit');
        for (final theme in [1.0, 2.0, 0.0]) {
          await choose('theme', theme);
          expect(row('temperature_unit').value, initialTemperature.value);
          expect(row('tts_engine').value, 'edge');
        }
        for (final unit in [1.0, 0.0, 1.0]) {
          await choose('temperature_unit', unit);
          expect(row('theme').value, 'system');
          expect(row('tts_engine').value, 'edge');
        }
        await choose('theme', initialTheme.sliderValue);
        await choose('temperature_unit', initialTemperature.sliderValue);
        final initialAppLanguage = row('app_language');
        await choose('app_language', 0);
        expect(row('seek_step').kind, 'slider');
        final seek = row('seek_step');
        await currentList().onEvent!(const AccessibleListEvent(type: 'slider', id: 'seek_step', value: 4.0));
        await tester.pumpAndSettle();
        expect(row('seek_step').valueLabel, startsWith('5 '));
        await currentList().onEvent!(AccessibleListEvent(type: 'slider', id: 'seek_step', value: seek.sliderValue));
        await tester.pumpAndSettle();
        await choose('app_language', 3);
        expect(row('app_language').value, 'es');
        expect(row('tts_engine').value, 'edge');
        await choose('app_language', initialAppLanguage.sliderValue);
        final edgeLanguage = row('edge_language').value;
        final edgeVoice = row('edge_voice').value;
        final engineFinder = find.bySemanticsLabel(l10n.settingsReadingEngine);
        final engineNode = tester.getSemantics(engineFinder);
        final engineNodeId = engineNode.id;
        final beforeEngine = currentList();
        engineNode.owner!.performAction(engineNodeId, SemanticsAction.increase);
        await tester.pumpAndSettle();
        expectIncrementalUpdate(beforeEngine);
        expect(row('tts_engine').value, 'system');
        expect(tester.getSemantics(engineFinder).id, engineNodeId);
        await choose('system_voice', 1);
        expect(row('system_language').value, 'it-IT');
        expect(row('tts_engine').value, 'system');
        final savedSystemVoice = row('system_voice').value;
        await choose('tts_engine', 2);
        expect(row('tts_engine').value, 'gemini');
        expect(tester.getSemantics(engineFinder).id, engineNodeId);
        final geminiVoice = row('gemini_voice').value;
        for (final index in [0.0, 1.0, 0.0, 2.0, 0.0]) {
          await choose('app_language', index);
          expect(row('gemini_voice').value, geminiVoice);
          expect(row('tts_engine').value, 'gemini');
        }
        await choose('gemini_language', 1);
        expect(row('gemini_voice').value, geminiVoice);
        final chosenLanguage = row('gemini_language').value;
        await choose('gemini_voice', 1);
        expect(row('gemini_language').value, chosenLanguage);
        expect(row('tts_engine').value, 'gemini');
        final chosenVoice = row('gemini_voice').value;
        await choose('tts_engine', 0);
        expect(row('edge_language').value, edgeLanguage);
        expect(row('edge_voice').value, edgeVoice);
        await choose('tts_engine', 1);
        expect(row('system_voice').value, savedSystemVoice);
        await choose('tts_engine', 2);
        expect(row('gemini_voice').value, chosenVoice);
        expect(row('gemini_language').value, chosenLanguage);
        expect(await AppSettingsService().loadTtsEngine(), 'edge');
        Future<void> leave() async {
          if (homeExit) {
            final back = tester.widget<SonarpadBackSemantics>(
              find.byType(SonarpadBackSemantics),
            );
            back.onGoHome!();
          } else {
            await tester.tap(find.byType(BackButton));
          }
          await tester.pumpAndSettle();
        }

        await leave();
        expect(find.text(l10n.settingsUnsavedTitle), findsOneWidget);
        await tester.tap(find.text(l10n.annulla));
        await tester.pumpAndSettle();
        expect(row('tts_engine').value, 'gemini');
        expect(await AppSettingsService().loadTtsEngine(), 'edge');
        await leave();
        await tester.runAsync(() async {
          await tester.tap(find.text(l10n.saveSettings).last);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        for (
          var i = 0;
          i < 250 && find.byType(SettingsScreen).evaluate().isNotEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsNothing);
        expect(await AppSettingsService().loadTtsEngine(), 'gemini');
        expect(await AppSettingsService().loadGeminiTtsVoice(), chosenVoice);
        expect(
          await AppSettingsService().loadGeminiTtsLanguage(),
          chosenLanguage,
        );
        await open();
        expect(row('tts_engine').value, 'gemini');
        await choose('tts_engine', 0);
        await leave();
        await tester.tap(find.text(l10n.settingsExitWithoutSaving));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsNothing);
        expect(await AppSettingsService().loadTtsEngine(), 'gemini');
        debugDefaultTargetPlatformOverride = null;
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }
  });
}
