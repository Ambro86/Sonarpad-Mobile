import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_recorder_screen.dart';
import 'package:sonarpad_mobile_starter/services/podcast_recorder_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

import 'podcast_recorder_service_test.dart' show FakeMicrophone, FakeMixer;

Widget app(Widget child) => MaterialApp(
  locale: const Locale('it'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
List<AccessibleListRow> rows(WidgetTester tester) => tester
    .widgetList<UniversalAccessibleList>(find.byType(UniversalAccessibleList))
    .last
    .sections
    .expand((s) => s.rows)
    .toList();
AccessibleListRow row(WidgetTester tester, String id) =>
    rows(tester).firstWhere((r) => r.id == id);

void main() {
  late Directory root;
  late FakeMicrophone microphone;
  late PodcastRecorderService service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('recorder-ui-');
    microphone = FakeMicrophone();
    service = PodcastRecorderService(
      microphone: microphone,
      mixer: FakeMixer(),
      directory: () async => root,
      keepAwake: (_) async {},
    );
  });
  tearDown(() async {
    await service.close();
    await root.delete(recursive: true);
  });
  Future<void> load(WidgetTester tester) async {
    await tester.pumpWidget(app(PodcastRecorderScreen(service: service)));
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      if (!rows(tester).any((r) => r.id == 'loading')) break;
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'accessible setup has name, microphone slider and optional music',
    (tester) async {
      await load(tester);
      expect(row(tester, 'name').kind, 'textField');
      expect(row(tester, 'microphone').kind, 'slider');
      expect(row(tester, 'microphone').sliderValue, 1);
      expect(row(tester, 'music').title, contains('facoltativa'));
      expect(row(tester, 'intro').title, contains('al termine'));
      expect(rows(tester).any((r) => r.id == 'music-volume'), false);
      expect(row(tester, 'record').finishEditingOnActivate, true);
      expect(row(tester, 'intro-jingle').title, contains('facoltativa'));
      expect(row(tester, 'outro-jingle').title, contains('facoltativa'));
      expect(rows(tester).any((r) => r.id == 'remove-intro'), false);
      await tester.runAsync(service.close);
    },
  );
  testWidgets(
    'recording screen only exposes status, duration and capture controls',
    (tester) async {
      await load(tester);
      await tester.runAsync(() async {
        await row(tester, 'record').onActivate!();
      });
      await tester.pumpAndSettle();
      expect(rows(tester).map((r) => r.id), [
        'status',
        'elapsed',
        'pause',
        'stop',
      ]);
      await row(tester, 'pause').onActivate!();
      await tester.pumpAndSettle();
      expect(row(tester, 'pause').title, 'Riprendi registrazione');
      await row(tester, 'pause').onActivate!();
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await row(tester, 'stop').onActivate!();
      });
      await tester.pumpAndSettle();
      expect(
        rows(tester).map((r) => r.id),
        containsAll(['preview', 'save', 'share', 'discard']),
      );
      expect(rows(tester).any((r) => r.id == 'record'), false);
      await tester.runAsync(service.close);
    },
  );
  testWidgets('permission denied is visible and recording is not started', (
    tester,
  ) async {
    microphone.allowed = false;
    await load(tester);
    await tester.runAsync(() async {
      await row(tester, 'record').onActivate!();
    });
    await tester.pumpAndSettle();
    expect(row(tester, 'error').title, contains('microfono'));
    expect(microphone.starts, 0);
    await tester.runAsync(service.close);
  });
  testWidgets('switching apps pauses capture instead of silently continuing', (
    tester,
  ) async {
    await load(tester);
    await tester.runAsync(() async {
      await row(tester, 'record').onActivate!();
    });
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(service.state, PodcastCaptureState.paused);
    expect(microphone.pauses, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.state, PodcastCaptureState.paused);
    await tester.runAsync(service.close);
  });
  testWidgets('discard requires confirmation and No preserves recording', (
    tester,
  ) async {
    await load(tester);
    await tester.runAsync(() async {
      await row(tester, 'record').onActivate!();
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await row(tester, 'stop').onActivate!();
    });
    await tester.pumpAndSettle();
    final action = row(tester, 'discard').onActivate!();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await action;
    expect(service.state, PodcastCaptureState.ready);
    await tester.runAsync(service.close);
  });
  test('native microphone permission is declared on both mobile platforms', () {
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains('NSMicrophoneUsageDescription'),
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android.permission.RECORD_AUDIO'),
    );
    expect(
      File('lib/main.dart').readAsStringSync(),
      contains("'/podcast-recorder'"),
    );
  });
}
