import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/audio_description_project_editor_screen.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_mix_preview_controller.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';
import 'package:sonarpad_mobile_starter/utils/app_logger.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
// The public platform interface is supplied by the path_provider dependency.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'audio_description_project_editor_test.dart' show sampleProject;

class _Paths extends PathProviderPlatform {
  _Paths(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '${root.path}/documents';

  @override
  Future<String?> getApplicationSupportPath() async => '${root.path}/support';

  @override
  Future<String?> getTemporaryPath() async => '${root.path}/temporary';

  @override
  Future<String?> getApplicationCachePath() async => '${root.path}/cache';
}

class _PreviewCall {
  _PreviewCall(this.project, this.text, this.source);

  final AudioDescriptionEditableProject project;
  final String text;
  final String? source;
}

class _PreviewService extends AiAudioDescriptionService {
  _PreviewService(this.path);

  final String path;
  final calls = <_PreviewCall>[];
  Object? failure;

  @override
  Future<AudioDescriptionMixPreview> previewProjectMix({
    required AudioDescriptionEditableProject project,
    required String text,
    String? sourcePathOverride,
  }) async {
    calls.add(_PreviewCall(project, text, sourcePathOverride));
    final error = failure;
    if (error != null) throw error;
    return AudioDescriptionMixPreview(
      path: path,
      durationSec: 10,
      sourceStartSec: 30,
      narrationStartSec: 2,
      narrationDurationSec: 2,
    );
  }

  @override
  Future<void> cancelPreview() async {}

  @override
  Future<void> cleanupMixPreviewCache() async {}
}

class _PreviewAudio implements AudioPlayerService {
  final files = <File>[];
  Completer<void>? _playback;
  Completer<void>? stopGate;
  int stopCalls = 0;

  @override
  Future<void> playVoicePreview(
    File file, {
    AudioSessionType sessionType = AudioSessionType.speech,
  }) {
    expect(sessionType, AudioSessionType.playback);
    files.add(file);
    _playback = Completer<void>();
    return _playback!.future;
  }

  @override
  Future<void> stop() async {
    ++stopCalls;
    await stopGate?.future;
    final playback = _playback;
    if (playback != null && !playback.isCompleted) playback.complete();
  }

  @override
  Future<void> dispose() => stop();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected audio call: ${invocation.memberName}');
}

const _editorKey = ValueKey('audio_description_project_editor');

Finder _control(String id) => find.byKey(ValueKey('accessible_row_$id'));

UniversalAccessibleList _editor(WidgetTester tester) =>
    tester.widget<UniversalAccessibleList>(find.byKey(_editorKey));

AccessibleListRow _row(WidgetTester tester, String id) =>
    _editor(tester).sections
        .expand((section) => section.rows)
        .singleWhere((row) => row.id == id);

Future<Map<String, dynamic>> _readProject(String path) async =>
    jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

Future<void> _waitUntil(WidgetTester tester, bool Function() ready) async {
  await tester.runAsync(() async {
    final elapsed = Stopwatch()..start();
    while (!ready()) {
      if (elapsed.elapsed > const Duration(seconds: 5)) {
        throw StateError('Timed out waiting for the editor');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await tester.pump();
    }
  });
  await tester.pump();
}

Future<void> _event(
  WidgetTester tester,
  String type,
  String id, [
  Object? value,
]) async {
  await tester.runAsync(() async {
    await _editor(tester)
        .onEvent!(AccessibleListEvent(type: type, id: id, value: value));
  });
  await tester.pump();
}

Future<void> _adjust(
  WidgetTester tester,
  String path,
  String id,
  SemanticsAction action,
  String field,
  Object expected,
) async {
  await tester.runAsync(() async {
    final node = tester.getSemantics(_control(id));
    node.owner!.performAction(node.id, action);
    final elapsed = Stopwatch()..start();
    while (true) {
      try {
        if ((await _readProject(path))[field] == expected) break;
      } on FileSystemException {
        // saveEditableProject replaces its temporary file atomically.
      }
      if (elapsed.elapsed > const Duration(seconds: 5)) {
        throw StateError('Timed out saving $field = $expected');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late PathProviderPlatform originalPaths;
  late _PreviewService previewService;
  late _PreviewAudio previewAudio;
  late List<AudioDescriptionMixPreviewController> controllers;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp('sonarpad_editor_audio_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temporary);
    previewService = _PreviewService('${temporary.path}/preview.mp3');
    previewAudio = _PreviewAudio();
    controllers = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      call,
    ) async {
      return switch (call.method) {
        'getVoices' => [
          {'name': 'Voce di prova', 'locale': 'it-IT'},
        ],
        'stop' => 1,
        _ => throw StateError('Unexpected TTS call: ${call.method}'),
      };
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (_) async => null,
    );
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
  });

  tearDown(() async {
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      null,
    );
    PathProviderPlatform.instance = originalPaths;
    previewService.dispose();
    await temporary.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, String path) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AudioDescriptionProjectEditorScreen(
            initialProjectPath: path,
            mixPreviewControllerFactory: () {
              final controller = AudioDescriptionMixPreviewController(
                serviceFactory: () => previewService,
                audioFactory: () => previewAudio,
                adjustmentDelay: const Duration(milliseconds: 30),
              );
              controllers.add(controller);
              return controller;
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    });
    await _waitUntil(tester, () {
      if (find.byKey(_editorKey).evaluate().isEmpty) return false;
      return _editor(tester).sections
          .expand((section) => section.rows)
          .any((row) => row.id == 'mp3_bitrate' && row.enabled);
    });
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future.wait(controllers.map((controller) => controller.close()));
      await Future<void>.delayed(Duration.zero);
      await AppLogger.readLogs();
    });
    await tester.pumpAndSettle();
  }

  Future<void> exercise(
    WidgetTester tester,
    AudioDescriptionEditableProject project,
    Future<void> Function() body,
  ) async {
    final requests = <Uri>[];
    File(project.projectPath).writeAsStringSync(jsonEncode(project.toJson()));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(650, 2300);
    try {
      await http.runWithClient(
        () async {
          await mount(tester, project.projectPath);
          await body();
        },
        () => MockClient((request) async {
          requests.add(request.url);
          return http.Response('No network is used by this test', 503);
        }),
      );
      expect(requests, isEmpty);
    } finally {
      await unmount(tester);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  }

  testWidgets(
    'editor sliders keep semantic nodes and pending text and voice while saving audio',
    (tester) async {
      final path = '${temporary.path}/project.sonarpad-ad.json';
      await exercise(tester, sampleProject(path), () async {
        final textField = find.descendant(
          of: _control('description_text'),
          matching: find.byType(TextField),
        );
        await tester.enterText(textField, 'Bozza non ancora applicata');
        final textFocus = tester.widget<TextField>(textField).focusNode;
        await _event(tester, 'picker', 'tts_engine', 'system');
        await _event(tester, 'picker', 'system_voice', 'Voce di prova');

        final bitrateId = tester.getSemantics(_control('mp3_bitrate')).id;
        final volumeId = tester.getSemantics(_control('source_volume')).id;
        for (final id in ['mp3_bitrate', 'source_volume']) {
          final data = tester.getSemantics(_control(id)).getSemanticsData();
          expect(data.flagsCollection.isSlider, isTrue);
          expect(data.hasAction(SemanticsAction.increase), isTrue);
          expect(data.hasAction(SemanticsAction.decrease), isTrue);
        }
        expect(_row(tester, 'mp3_bitrate').valueLabel, '192 kbps (Normale)');
        expect(_row(tester, 'source_volume').valueLabel, '1,0 (Normale)');
        for (final (action, bitrate) in [
          (SemanticsAction.decrease, 128),
          (SemanticsAction.decrease, 96),
          (SemanticsAction.decrease, 64),
          (SemanticsAction.decrease, 64),
          (SemanticsAction.increase, 96),
          (SemanticsAction.increase, 128),
          (SemanticsAction.increase, 192),
          (SemanticsAction.increase, 256),
          (SemanticsAction.increase, 256),
        ]) {
          await _adjust(
            tester,
            path,
            'mp3_bitrate',
            action,
            'bitrate_kbps',
            bitrate,
          );
          final node = tester.getSemantics(_control('mp3_bitrate'));
          expect(node.id, bitrateId);
          expect(
            node.getSemanticsData().value,
            '$bitrate kbps${bitrate == 192 ? ' (Normale)' : ''}',
          );
        }
        for (final volume in [0.95, 0.9, 0.85]) {
          await _adjust(
            tester,
            path,
            'source_volume',
            SemanticsAction.decrease,
            'source_volume',
            volume,
          );
          expect(tester.getSemantics(_control('source_volume')).id, volumeId);
        }
        await _event(tester, 'slider', 'source_volume', 20);
        for (final (volume, label) in [(1.05, '1,05'), (1.1, '1,1')]) {
          await _adjust(
            tester,
            path,
            'source_volume',
            SemanticsAction.increase,
            'source_volume',
            volume,
          );
          final node = tester.getSemantics(_control('source_volume'));
          expect(node.id, volumeId);
          expect(node.getSemanticsData().value, label);
          expect(textFocus?.hasFocus, isTrue);
        }
        await _event(tester, 'slider', 'source_volume', 39);
        for (final (action, volume, label) in [
          (SemanticsAction.increase, 2.0, '2,0'),
          (SemanticsAction.increase, 2.0, '2,0'),
          (SemanticsAction.decrease, 1.95, '1,95'),
        ]) {
          await _adjust(
            tester,
            path,
            'source_volume',
            action,
            'source_volume',
            volume,
          );
          final node = tester.getSemantics(_control('source_volume'));
          expect(node.id, volumeId);
          expect(node.getSemanticsData().value, label);
          expect(textFocus?.hasFocus, isTrue);
        }
        await _event(tester, 'slider', 'source_volume', 35);
        expect(textFocus?.hasFocus, isTrue);
        expect(
          _row(tester, 'description_text').value,
          'Bozza non ancora applicata',
        );
        expect(_row(tester, 'tts_engine').value, 'system');
        expect(_row(tester, 'system_voice').value, 'Voce di prova');
        final json = await tester.runAsync(() => _readProject(path));
        expect(json!['bitrate_kbps'], 256);
        expect(json['source_volume'], 1.75);
        expect(json['mobile_tts_engine'], 'edge');
        expect(json['descriptions'][0]['text'], 'Prima descrizione');

        expect(_row(tester, 'mp3_bitrate').options.map((item) => item.label), [
          '64 kbps',
          '96 kbps',
          '128 kbps',
          '192 kbps (Normale)',
          '256 kbps',
        ]);
        final volumeRow = _row(tester, 'source_volume');
        expect(volumeRow.sliderMax, 40);
        expect(volumeRow.options, hasLength(41));
        expect((volumeRow.toMap()['options'] as List)[35], {
          'value': 35,
          'label': '1,75',
        });
        expect(volumeRow.options[19].label, '0,95');
        expect(volumeRow.options[20].label, '1,0 (Normale)');
        expect(volumeRow.options[40].label, '2,0');
        expect(
          volumeRow.options.where(
            (option) => option.label.contains('(Normale)'),
          ),
          hasLength(1),
        );
        expect(volumeRow.value, '1,75');
        expect(volumeRow.sliderIncreasedValueLabel, '1,8');
        expect(volumeRow.sliderDecreasedValueLabel, '1,7');

        await _event(tester, 'activate', 'reexport');
        expect(_row(tester, 'status').subtitle, contains('Applica prima'));
        expect(previewService.calls, isEmpty);
        await unmount(tester);
        await mount(tester, path);
        expect(_row(tester, 'mp3_bitrate').valueLabel, '256 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '1,75');
        expect(_row(tester, 'description_text').value, 'Prima descrizione');
      });
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'rapid and clamped audio writes stay ordered through deletion and navigation',
    (tester) async {
      final path = '${temporary.path}/project.sonarpad-ad.json';
      final project = sampleProject(path)
          .copyWith(bitrateKbps: 96, sourceVolume: 1.25);
      await exercise(tester, project, () async {
        for (final value in [null, 'bad', double.nan, double.infinity]) {
          await _event(tester, 'slider', 'mp3_bitrate', value);
          await _event(tester, 'slider', 'source_volume', value);
        }
        expect(_row(tester, 'mp3_bitrate').valueLabel, '96 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '1,25');
        for (final id in ['mp3_bitrate', 'source_volume']) {
          await _event(tester, 'slider', id, -1e300);
        }
        expect(_row(tester, 'mp3_bitrate').valueLabel, '64 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '0,0');
        for (final id in ['mp3_bitrate', 'source_volume']) {
          await _event(tester, 'slider', id, 1e300);
        }
        expect(_row(tester, 'mp3_bitrate').valueLabel, '256 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '2,0');
        await _event(tester, 'slider', 'mp3_bitrate', '2.4');
        await _event(tester, 'slider', 'source_volume', '27.4');
        expect(_row(tester, 'mp3_bitrate').valueLabel, '128 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '1,35');

        final handler = _editor(tester).onEvent!;
        late List<Future<void>> writes;
        late Future<void> deletion;
        await tester.runAsync(() async {
          writes = [
            for (final value in [25, 27, 32, 33])
              Future<void>.sync(
                () => handler(
                  AccessibleListEvent(
                    type: 'slider',
                    id: 'source_volume',
                    value: value,
                  ),
                ),
              ),
            Future<void>.sync(
              () => handler(
                const AccessibleListEvent(
                  type: 'slider',
                  id: 'mp3_bitrate',
                  value: 4,
                ),
              ),
            ),
          ];
          deletion = Future<void>.sync(
            () => handler(
              const AccessibleListEvent(type: 'activate', id: 'delete'),
            ),
          );
        });
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Elimina descrizione'),
          ),
        );
        await tester.runAsync(() => Future.wait([...writes, deletion]));
        await tester.pumpAndSettle();
        final deleted = await tester.runAsync(() => _readProject(path));
        expect(deleted!['descriptions'], hasLength(1));
        expect(deleted['descriptions'][0]['text'], 'Seconda descrizione');
        expect(deleted['bitrate_kbps'], 256);
        expect(deleted['source_volume'], 1.65);

        // Leave immediately after enqueuing new settings. Their captured
        // snapshots must finish writing even after this editor is disposed.
        await tester.runAsync(() async {
          final pending = [
            for (final value in [24, 29, 35])
              Future<void>.sync(
                () => handler(
                  AccessibleListEvent(
                    type: 'slider',
                    id: 'source_volume',
                    value: value,
                  ),
                ),
              ),
            Future<void>.sync(
              () => handler(
                const AccessibleListEvent(
                  type: 'slider',
                  id: 'mp3_bitrate',
                  value: 1,
                ),
              ),
            ),
          ];
          await tester.pumpWidget(const SizedBox());
          await Future.wait(pending);
        });
        final saved = await tester.runAsync(() => _readProject(path));
        expect(saved!['source_volume'], 1.75);
        expect(saved['bitrate_kbps'], 96);
        expect(saved['descriptions'], hasLength(1));
        expect(saved['descriptions'][0]['text'], 'Seconda descrizione');
        expect(File('$path.tmp').existsSync(), isFalse);
      });
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'automatic and manual mix previews use the pending voice without moving focus',
    (tester) async {
      final path = '${temporary.path}/project.sonarpad-ad.json';
      final source = File('${temporary.path}/movie.mp4')..writeAsBytesSync([0]);
      final project = sampleProject(path)
          .copyWith(sourcePath: source.path, ttsSpeed: 0.8, ttsPitch: 1.1);
      await exercise(tester, project, () async {
        final textField = find.descendant(
          of: _control('description_text'),
          matching: find.byType(TextField),
        );
        await tester.enterText(textField, 'Testo in lavorazione');
        final textFocus = tester.widget<TextField>(textField).focusNode;
        await _event(tester, 'picker', 'tts_engine', 'system');
        await _event(tester, 'picker', 'system_voice', 'Voce di prova');
        final volumeId = tester.getSemantics(_control('source_volume')).id;
        final playId = tester.getSemantics(_control('mix_preview')).id;
        final stopId = tester.getSemantics(_control('mix_preview_stop')).id;
        await _event(tester, 'slider', 'mp3_bitrate', 1);

        final handler = _editor(tester).onEvent!;
        await tester.runAsync(
          () => Future.wait([
            for (final value in [32, 28, 27])
              Future<void>.sync(
                () => handler(
                  AccessibleListEvent(
                    type: 'slider',
                    id: 'source_volume',
                    value: value,
                  ),
                ),
              ),
          ]),
        );
        await _waitUntil(tester, () => previewAudio.files.length == 1);
        expect(previewService.calls, hasLength(1));
        final call = previewService.calls.single;
        expect(call.project.sourceVolume, 1.35);
        expect(call.project.bitrateKbps, 96);
        expect(call.project.ttsEngine, 'system');
        expect(call.project.ttsVoice, 'Voce di prova');
        expect(call.project.systemVoice, 'Voce di prova');
        expect(call.project.ttsSpeed, 0.8);
        expect(call.project.ttsPitch, 1.1);
        expect(call.source, source.path);
        expect(call.text, 'Prova audiodescrizione con ducking.');
        expect(controllers.single.isPlaying, isTrue);
        expect(_row(tester, 'mix_preview_stop').enabled, isTrue);
        expect(tester.getSemantics(_control('source_volume')).id, volumeId);
        expect(tester.getSemantics(_control('mix_preview')).id, playId);
        expect(tester.getSemantics(_control('mix_preview_stop')).id, stopId);
        expect(textFocus?.hasFocus, isTrue);
        expect(_row(tester, 'description_text').value, 'Testo in lavorazione');
        final saved = await tester.runAsync(() => _readProject(path));
        expect(saved!['mobile_tts_engine'], 'edge');
        expect(saved['descriptions'][0]['text'], 'Prima descrizione');
        expect(saved['source_volume'], 1.35);
        expect(saved['bitrate_kbps'], 96);

        await _event(tester, 'picker', 'tts_engine', 'edge');
        await _event(tester, 'picker', 'edge_voice', 'it-IT-DiegoNeural');
        await _waitUntil(tester, () => !controllers.single.isActive);
        expect(_row(tester, 'mix_preview_stop').enabled, isFalse);
        await _event(tester, 'slider', 'source_volume', 32);
        await _event(tester, 'activate', 'mix_preview_stop');
        final playsBeforeReplay = previewAudio.files.length;
        await _event(tester, 'activate', 'mix_preview');
        await _waitUntil(
          tester,
          () => previewAudio.files.length == playsBeforeReplay + 1,
        );
        expect(previewService.calls.last.project.sourceVolume, 1.6);
        expect(previewService.calls.last.project.ttsVoice, 'it-IT-DiegoNeural');
        expect(previewService.calls.last.project.systemVoice, isNull);
        await _event(tester, 'activate', 'mix_preview_stop');
        expect(controllers.single.isActive, isFalse);
        expect(_row(tester, 'mix_preview_stop').enabled, isFalse);

        // Automatic preview errors stay inline, with no modal or focus jump.
        previewService.failure = StateError(
          'Preview unavailable in this fixture',
        );
        await _event(tester, 'slider', 'source_volume', 6);
        await _waitUntil(tester, () => controllers.single.error != null);
        expect(find.byType(AlertDialog), findsNothing);
        expect(_row(tester, 'mix_preview').value, isNotNull);
        expect(tester.getSemantics(_control('source_volume')).id, volumeId);
        expect(tester.getSemantics(_control('mix_preview')).id, playId);
        expect(textFocus?.hasFocus, isTrue);
        expect(_row(tester, 'description_text').value, 'Testo in lavorazione');
      });
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'Cancel during preview drain prevents a queued text synthesis from starting',
    (tester) async {
      final path = '${temporary.path}/project.sonarpad-ad.json';
      final source = File('${temporary.path}/movie.mp4')..writeAsBytesSync([0]);
      final project = sampleProject(path).copyWith(sourcePath: source.path);
      await exercise(tester, project, () async {
        await _event(tester, 'slider', 'source_volume', 9);
        await _waitUntil(tester, () => previewAudio.files.length == 1);
        await _event(
          tester,
          'textChanged',
          'description_text',
          'Una nuova bozza',
        );

        final handler = _editor(tester).onEvent!;
        final previousStops = previewAudio.stopCalls;
        late Future<void> apply;
        await tester.runAsync(() async {
          previewAudio.stopGate = Completer<void>();
          apply = Future<void>.sync(
            () => handler(
              const AccessibleListEvent(type: 'activate', id: 'apply'),
            ),
          );
        });
        try {
          await _waitUntil(
            tester,
            () => previewAudio.stopCalls > previousStops,
          );
          expect(_row(tester, 'mp3_bitrate').enabled, isFalse);
          await _event(tester, 'activate', 'cancel');
        } finally {
          await tester.runAsync(() async {
            previewAudio.stopGate!.complete();
            await apply;
          });
        }
        await tester.pumpAndSettle();
        expect(_row(tester, 'mp3_bitrate').enabled, isTrue);
        expect(_row(tester, 'status').subtitle, 'Annulla');
        expect(_row(tester, 'description_text').value, 'Una nuova bozza');
        expect(
          _editor(tester).sections
              .expand((section) => section.rows)
              .where((row) => row.id == 'technical_error'),
          isEmpty,
        );
        final saved = await tester.runAsync(() => _readProject(path));
        expect(saved!['source_volume'], 0.45);
        expect(saved['descriptions'][0]['text'], 'Prima descrizione');
        expect(previewService.calls, hasLength(1));
      });
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
