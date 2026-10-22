import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/create_ai_audiodescription_screen.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_mix_preview_controller.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';
import 'package:sonarpad_mobile_starter/utils/app_logger.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
// The public platform interface is supplied by the path_provider dependency.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);

  final Directory root;
  Completer<void>? cacheRequested;
  Completer<String?>? cacheResponse;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '${root.path}/documents';

  @override
  Future<String?> getApplicationSupportPath() async => '${root.path}/support';

  @override
  Future<String?> getTemporaryPath() async => '${root.path}/temporary';

  @override
  Future<String?> getApplicationCachePath() {
    final requested = cacheRequested;
    if (requested != null && !requested.isCompleted) requested.complete();
    return cacheResponse?.future ?? Future.value('${root.path}/cache');
  }
}

class _NoMixPreview extends AudioDescriptionMixPreviewController {
  @override
  void schedule(AudioDescriptionMixPreviewRenderer render) {}

  @override
  void playNow(AudioDescriptionMixPreviewRenderer render) {}

  @override
  Future<void> stop() async {}
}

class _PreviewService extends Fake implements AiAudioDescriptionService {
  final settings = <AiAudioDescriptionSettings>[];
  final sources = <String>[];
  final phrases = <String>[];
  int cancellations = 0;
  int cleanups = 0;

  @override
  Future<AudioDescriptionMixPreview> previewMix({
    required String sourcePath,
    required AiAudioDescriptionSettings settings,
    required String text,
    double? ttsSpeed,
    double? ttsPitch,
    double? preferredSourceTimeSec,
  }) async {
    this.settings.add(settings);
    sources.add(sourcePath);
    phrases.add(text);
    // Creation leaves these unset so the real service loads global voice
    // speed and pitch using the same path as the final generation.
    expect(ttsSpeed, isNull);
    expect(ttsPitch, isNull);
    return const AudioDescriptionMixPreview(
      path: '/rendered-mix.mp3',
      durationSec: 10,
      sourceStartSec: 20,
      narrationStartSec: 2,
      narrationDurationSec: 3,
    );
  }

  @override
  Future<void> cancelPreview() async => cancellations++;

  @override
  Future<void> cleanupMixPreviewCache() async => cleanups++;

  @override
  void dispose() {}
}

class _PreviewAudio extends Fake implements AudioPlayerService {
  final sessions = <AudioSessionType>[];
  bool autoStart = true;
  void Function()? pendingStart;
  Completer<void>? playing;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> playVoicePreview(
    File file, {
    AudioSessionType sessionType = AudioSessionType.speech,
    void Function()? onPlaybackStarted,
  }) {
    sessions.add(sessionType);
    playing = Completer<void>();
    pendingStart = onPlaybackStarted;
    if (autoStart) pendingStart?.call();
    return playing!.future;
  }

  @override
  Future<void> pauseVoicePreview() async => pauseCalls++;

  @override
  Future<void> resumeVoicePreview() async => resumeCalls++;

  @override
  Future<void> stop() async {
    stopCalls++;
    final active = playing;
    if (active != null && !active.isCompleted) active.complete();
  }

  @override
  Future<void> dispose() => stop();
}

class _HeldStopPreview extends _NoMixPreview {
  Completer<void>? stopGate;
  int stops = 0;

  @override
  Future<void> stop() async {
    stops++;
    await stopGate?.future;
  }
}

const _formKey = ValueKey('audio_description_settings');
const _runningKey = ValueKey('audio_description_running');

Finder _control(String id) => find.byKey(ValueKey('accessible_row_$id'));

SemanticsNode _previewSemantics(WidgetTester tester) {
  // The keyed row wraps a ListTile. Its outer Semantics can be an annotation
  // node without tap; InkWell exposes the actual action in a descendant.
  // Find that node inside this row, never an unrelated button or its parent.
  final tapTarget = find.descendant(
    of: _control('mix_preview'),
    matching: find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.onTap != null,
      description: 'preview tap semantics',
    ),
  );
  expect(tapTarget, findsOneWidget,
      reason: 'The single preview button must expose one tap target.');
  return tester.getSemantics(tapTarget);
}

UniversalAccessibleList _form(WidgetTester tester) =>
    tester.widget<UniversalAccessibleList>(find.byKey(_formKey));

AccessibleListRow _row(WidgetTester tester, String id) =>
    _form(tester).sections
        .expand((section) => section.rows)
        .singleWhere((row) => row.id == id);

Future<void> _waitForWidget(WidgetTester tester, Finder finder) async {
  // Catalog files and the idle audio controller use real asynchronous I/O.
  // Keep that bootstrap outside FakeAsync; gestures still use normal pumping.
  await tester.runAsync(() async {
    final elapsed = Stopwatch()..start();
    while (finder.evaluate().isEmpty) {
      if (elapsed.elapsed > const Duration(seconds: 5)) {
        throw StateError('Timed out waiting for $finder');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await tester.pump();
    }
  });
}

Future<void> _waitUntil(WidgetTester tester, bool Function() done) async {
  await tester.runAsync(() async {
    final elapsed = Stopwatch()..start();
    while (!done()) {
      if (elapsed.elapsed > const Duration(seconds: 5)) {
        throw StateError('Timed out waiting for preview');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
      // Async callbacks can schedule the debounce in the test's FakeAsync
      // zone. Advance that clock as well as allowing real file I/O to finish.
      await tester.pump(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
}

Future<void> _mountScreen(
  WidgetTester tester, {
  String? sourcePath,
  AudioDescriptionMixPreviewController Function()? previewFactory,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CreateAiAudiodescriptionScreen(
          initialSourcePath: sourcePath,
          mixPreviewControllerFactory: previewFactory ?? _NoMixPreview.new,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
  });
  await _waitForWidget(tester, find.byKey(_formKey));
  await tester.pumpAndSettle();
  expect(
    _form(tester).sections
        .expand((section) => section.rows)
        .where((row) => row.id == 'technical_error'),
    isEmpty,
  );
}

Future<void> _unmountScreen(WidgetTester tester) async {
  await tester.runAsync(() async {
    int count(String logs, String message) =>
        message.allMatches(logs).length;
    const disposed = 'Sonarpad audio: dispose complete';
    final disposalsBefore = count(await AppLogger.readLogs(), disposed);
    await tester.pumpWidget(const SizedBox());
    // dispose() and provider changes launch background work. A single log
    // flush only waits for the current queue, not writes enqueued afterwards.
    final elapsed = Stopwatch()..start();
    while (true) {
      final logs = await AppLogger.readLogs();
      final balanceStarts = count(logs, 'UI balance refresh start ');
      final balanceEnds = count(logs, 'UI balance refresh success ') +
          count(logs, 'UI balance refresh exception ');
      if (count(logs, disposed) > disposalsBefore &&
          balanceStarts == balanceEnds) {
        break;
      }
      if (elapsed.elapsed > const Duration(seconds: 5)) {
        throw StateError('Timed out waiting for audio and balance cleanup');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await tester.pump(const Duration(milliseconds: 20));
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _exerciseScreen(
  WidgetTester tester,
  Future<void> Function() body, {
  String? sourcePath,
  AudioDescriptionMixPreviewController Function()? previewFactory,
}) async {
  final requests = <Uri>[];
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(600, 2100);
  try {
    await http.runWithClient(
      () async {
        await _mountScreen(
          tester,
          sourcePath: sourcePath,
          previewFactory: previewFactory,
        );
        await body();
      },
      () => MockClient((request) async {
        requests.add(request.url);
        return http.Response('No network is used by this test', 503);
      }),
    );
    expect(requests, isEmpty);
  } finally {
    await _unmountScreen(tester);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

Future<void> _sliderEvent(WidgetTester tester, String id, Object? value) async {
  await tester.runAsync(() async {
    await _form(tester)
        .onEvent!(AccessibleListEvent(type: 'slider', id: id, value: value));
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late _Paths paths;
  late PathProviderPlatform originalPaths;
  late bool ttsAwaitsCompletion;
  late List<String> ttsCalls;
  late List<double> ttsPitches;
  Completer<int>? cancelledSpeak;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ttsAwaitsCompletion = true;
    ttsCalls = [];
    ttsPitches = [];
    cancelledSpeak = null;
    temporary = await Directory.systemTemp.createTemp(
      'sonarpad_audio_sliders_',
    );
    originalPaths = PathProviderPlatform.instance;
    paths = _Paths(temporary);
    PathProviderPlatform.instance = paths;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      call,
    ) async {
      ttsCalls.add(call.method);
      if (call.method == 'setPitch') {
        ttsPitches.add((call.arguments as num).toDouble());
      }
      if (call.method == 'awaitSpeakCompletion') {
        ttsAwaitsCompletion = call.arguments == true;
        return 1;
      }
      if (call.method == 'speak') {
        if (ttsAwaitsCompletion) {
          // Match iOS: cancelling speech does not complete an awaited speak.
          cancelledSpeak = Completer<int>();
          return cancelledSpeak!.future;
        }
        return 1;
      }
      return switch (call.method) {
        'getVoices' => [
          {'name': 'Voce di prova', 'locale': 'it-IT'},
        ],
        'stop' => 1,
        'setSpeechRate' || 'setPitch' || 'setVoice' || 'setLanguage' => 1,
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
    final pending = cancelledSpeak;
    if (pending != null && !pending.isCompleted) pending.complete(0);
    // Unmounting and the final pump can enqueue more audio disposal logs.
    // Drain those writes while the test's path provider is still installed;
    // Windows cannot delete the temporary directory with an open log file.
    await AppLogger.readLogs();
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
    await temporary.delete(recursive: true);
  });

  testWidgets(
    'credential paste replaces 44 with 39 characters and preserves special characters',
    (tester) async {
      var clipboard = '';
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await http.runWithClient(() async {
        await _mountScreen(tester);
        for (final provider in [0, 1]) {
          await _sliderEvent(tester, 'provider', provider);
          final id = provider == 0 ? 'api_key' : 'sonarpad_code';
          var revision = _row(tester, id).textRevision;
          for (final value in ['A' * 44, 'B' * 39, r'TEST!#@|+%&=?/\']) {
            // Plain clipboard content, including the final literal backslash.
            clipboard = '  $value' + String.fromCharCodes([13, 10]);
            await tester.runAsync(() async { await _form(tester).onEvent!(
                const AccessibleListEvent(type: 'activate', id: 'paste_ai_credential')); });
            await tester.pump();
            final row = _row(tester, id);
            expect(row.value, value);
            expect(row.textRevision, ++revision);
            expect(row.toMap()['textRevision'], revision);
            final field = tester.widget<TextField>(find.descendant(
                of: _control(id), matching: find.byType(TextField)));
            expect(field.controller!.text, value);
            expect(field.controller!.selection.baseOffset, value.length);
          }
        }
      }, () => MockClient((_) async => http.Response('{}', 503)));
      await _unmountScreen(tester);
    },
    variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );

  testWidgets(
    'a fresh form without a selected file has no resumable preview action',
    (tester) async {
      await _exerciseScreen(tester, () async {
        expect(_row(tester, 'choose_video').value, isNull);
        expect(_control('mix_preview'), findsNothing);
        expect(_control('mix_preview_status'), findsNothing);
        await tester.runAsync(() async {
          await _form(tester).onEvent!(const AccessibleListEvent(
            type: 'activate', id: 'mix_preview',
          ));
        });
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);
        expect(_control('mix_preview'), findsNothing);
        expect(_row(tester, 'choose_video').value, isNull);
        expect(tester.takeException(), isNull);
      });
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'audio sliders announce exact values and keep their nodes and form text',
    (tester) async {
      await _exerciseScreen(tester, () async {
        final apiField = find.descendant(
          of: _control('api_key'),
          matching: find.byType(TextField),
        );
        await tester.enterText(apiField, 'fixture-key-kept-in-form');
        final inputFocus = tester.widget<TextField>(apiField).focusNode;
        expect(inputFocus?.hasFocus, isTrue);

        final bitrate = _control('mp3_bitrate');
        final volume = _control('source_volume');
        final bitrateNodeId = tester.getSemantics(bitrate).id;
        final volumeNodeId = tester.getSemantics(volume).id;
        final bitrateData = tester.getSemantics(bitrate).getSemanticsData();
        expect(bitrateData.value, '192 kbps (Normale)');
        expect(bitrateData.flagsCollection.isSlider, isTrue);
        expect(bitrateData.hasAction(SemanticsAction.increase), isTrue);
        expect(bitrateData.hasAction(SemanticsAction.decrease), isTrue);
        expect(
          tester.getSemantics(volume).getSemanticsData().value,
          '1,0 (Normale)',
        );

        final steps = <(SemanticsAction, String)>[
          (SemanticsAction.decrease, '128 kbps'),
          (SemanticsAction.decrease, '96 kbps'),
          (SemanticsAction.decrease, '64 kbps'),
          (SemanticsAction.decrease, '64 kbps'),
          (SemanticsAction.increase, '96 kbps'),
          (SemanticsAction.increase, '128 kbps'),
          (SemanticsAction.increase, '192 kbps (Normale)'),
          (SemanticsAction.increase, '256 kbps'),
          (SemanticsAction.increase, '256 kbps'),
        ];
        for (final (action, expected) in steps) {
          final node = tester.getSemantics(bitrate);
          node.owner!.performAction(node.id, action);
          await tester.pump();
          final updated = tester.getSemantics(bitrate);
          expect(updated.id, bitrateNodeId);
          expect(updated.getSemanticsData().value, expected);
        }
        for (final expected in ['0,95', '0,9', '0,85']) {
          final node = tester.getSemantics(volume);
          node.owner!.performAction(node.id, SemanticsAction.decrease);
          await tester.pump();
          final updated = tester.getSemantics(volume);
          expect(updated.id, volumeNodeId);
          expect(updated.getSemanticsData().value, expected);
          expect(updated.getSemanticsData().flagsCollection.isSlider, isTrue);
        }
        await _sliderEvent(tester, 'source_volume', 20);
        for (final expected in ['1,05', '1,1']) {
          final node = tester.getSemantics(volume);
          node.owner!.performAction(node.id, SemanticsAction.increase);
          await tester.pump();
          expect(tester.getSemantics(volume).id, volumeNodeId);
          expect(
            tester.getSemantics(volume).getSemanticsData().value,
            expected,
          );
          expect(inputFocus?.hasFocus, isTrue);
        }
        await _sliderEvent(tester, 'source_volume', 39);
        for (final (action, expected) in [
          (SemanticsAction.increase, '2,0'),
          (SemanticsAction.increase, '2,0'),
          (SemanticsAction.decrease, '1,95'),
        ]) {
          final node = tester.getSemantics(volume);
          node.owner!.performAction(node.id, action);
          await tester.pump();
          expect(tester.getSemantics(volume).id, volumeNodeId);
          expect(
            tester.getSemantics(volume).getSemanticsData().value,
            expected,
          );
          expect(inputFocus?.hasFocus, isTrue);
        }
        await _sliderEvent(tester, 'source_volume', 35);
        expect(inputFocus?.hasFocus, isTrue);
        expect(
          tester.widget<TextField>(apiField).controller!.text,
          'fixture-key-kept-in-form',
        );
        expect(_row(tester, 'api_key').value, 'fixture-key-kept-in-form');

        // UIKit receives all exact labels, so repeated native gestures do not
        // need to infer intermediate labels from decimal formatting.
        final bitrateRow = _row(tester, 'mp3_bitrate');
        expect(bitrateRow.options.map((option) => option.label), [
          '64 kbps',
          '96 kbps',
          '128 kbps',
          '192 kbps (Normale)',
          '256 kbps',
        ]);
        final volumeRow = _row(tester, 'source_volume');
        expect(volumeRow.sliderMax, 40);
        expect(volumeRow.options, hasLength(41));
        expect(volumeRow.options[19].label, '0,95');
        expect(volumeRow.options[20].label, '1,0 (Normale)');
        expect(volumeRow.options[40].label, '2,0');
        expect(
          volumeRow.options.where(
            (option) => option.label.contains('(Normale)'),
          ),
          hasLength(1),
        );
        expect(volumeRow.sliderIncreasedValueLabel, '1,8');
        expect(volumeRow.sliderDecreasedValueLabel, '1,7');
        expect((volumeRow.toMap()['options'] as List)[35], {
          'value': 35,
          'label': '1,75',
        });
        expect(bitrateRow.enabled && volumeRow.enabled, isTrue);
      });
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'slider events clamp safely and selections reach creation and reload',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ad_mobile_bitrate_kbps': 96,
        'ad_mobile_source_volume': 1.25,
        'ad_mobile_gemini_api_key': 'fixture-key',
        'ad_mobile_language': 'en',
      });
      final source = File('${temporary.path}/movie.mp4')..writeAsBytesSync([0]);
      final blockedCache = File('${temporary.path}/cache_is_a_file')
        ..writeAsStringSync('This file cannot be used as a cache directory.');
      await _exerciseScreen(tester, () async {
        expect(_row(tester, 'mp3_bitrate').valueLabel, '96 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '1,25');
        for (final invalid in [
          null,
          'invalid',
          double.nan,
          double.infinity,
          double.negativeInfinity,
        ]) {
          await _sliderEvent(tester, 'mp3_bitrate', invalid);
          await _sliderEvent(tester, 'source_volume', invalid);
        }
        expect(_row(tester, 'mp3_bitrate').valueLabel, '96 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '1,25');
        for (final id in ['mp3_bitrate', 'source_volume']) {
          await _sliderEvent(tester, id, -1e300);
        }
        expect(_row(tester, 'mp3_bitrate').valueLabel, '64 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '0,0');
        for (final id in ['mp3_bitrate', 'source_volume']) {
          await _sliderEvent(tester, id, 1e300);
        }
        expect(_row(tester, 'mp3_bitrate').valueLabel, '256 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '2,0');
        await _sliderEvent(tester, 'mp3_bitrate', '2.4');
        await _sliderEvent(tester, 'source_volume', '27.4');
        expect(_row(tester, 'mp3_bitrate').valueLabel, '128 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '1,35');

        final handler = _form(tester).onEvent!;
        await Future.wait([
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
        ]);
        await tester.pump();
        expect(_row(tester, 'source_volume').valueLabel, '1,65');
        expect(_row(tester, 'mp3_bitrate').valueLabel, '256 kbps');
        expect(_row(tester, 'api_key').value, 'fixture-key');
        expect(_row(tester, 'language').value, 'en');

        // Exercise the real create/settings path. Hold its cache lookup after
        // preferences are saved, then fail at local directory creation before
        // probing media, synthesizing speech, or making any AI request.
        await tester.runAsync(() async {
          paths.cacheRequested = Completer<void>();
          paths.cacheResponse = Completer<String?>();
          await handler(
            const AccessibleListEvent(type: 'activate', id: 'create'),
          );
          await paths.cacheRequested!.future.timeout(
            const Duration(seconds: 5),
          );
        });
        await tester.pump();
        expect(find.byKey(_runningKey), findsOneWidget);
        expect(find.byKey(_formKey), findsNothing);
        await handler(
          const AccessibleListEvent(
            type: 'slider',
            id: 'mp3_bitrate',
            value: 0,
          ),
        );
        await handler(
          const AccessibleListEvent(
            type: 'slider',
            id: 'source_volume',
            value: 0,
          ),
        );
        final saved = await AiAudioDescriptionPreferences.load();
        expect(saved['bitrateKbps'], 256);
        expect(saved['sourceVolume'], 1.65);
        expect(saved['apiKey'], 'fixture-key');
        expect(saved['language'], 'en');

        paths.cacheResponse!.complete(blockedCache.path);
        await _waitForWidget(tester, find.byKey(_formKey));
        await tester.pumpAndSettle();
        expect(_row(tester, 'mp3_bitrate').valueLabel, '256 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '1,65');
        final errorRow = _row(tester, 'technical_error');
        await tester.scrollUntilVisible(
          _control('technical_error'),
          600,
          scrollable: find
              .descendant(
                of: find.byKey(_formKey),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        for (final text in [errorRow.title, errorRow.subtitle!]) {
          final errorText = find.descendant(
            of: _control('technical_error'),
            matching: find.text(text),
          );
          expect(
            tester.getSemantics(errorText).getSemanticsData().label,
            contains(text),
          );
        }

        await _unmountScreen(tester);
        await _mountScreen(tester, sourcePath: source.path);
        expect(_row(tester, 'mp3_bitrate').valueLabel, '256 kbps');
        expect(_row(tester, 'source_volume').valueLabel, '1,65');
        expect(_row(tester, 'api_key').value, 'fixture-key');
        expect(_row(tester, 'language').value, 'en');
      }, sourcePath: source.path);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'pitch changes stay silent until Test voice and volume still previews the film',
    (tester) async {
      final service = _PreviewService();
      final audio = _PreviewAudio();
      final source = File('${temporary.path}/pitch-film.mp4')
        ..writeAsBytesSync([0]);
      Future<void> passDebounce() async {
        await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 60),
        ));
        await tester.pump(const Duration(milliseconds: 60));
      }

      await _exerciseScreen(tester, () async {
        await tester.runAsync(() async {
          await _form(tester).onEvent!(const AccessibleListEvent(
            type: 'picker', id: 'tts_engine', value: 'system',
          ));
        });
        await tester.pump();
        for (final pitch in [0.8, 1.2, 1.7]) {
          await _sliderEvent(tester, 'creation_voice_pitch', pitch);
          await passDebounce();
          expect(service.settings, isEmpty);
          expect(audio.sessions, isEmpty);
          expect(ttsCalls.where((call) => call == 'speak'), isEmpty);
        }
        expect((await AiAudioDescriptionPreferences.load())['voicePitch'], 1.7);
        await tester.runAsync(() async {
          await _form(tester).onEvent!(const AccessibleListEvent(
            type: 'activate', id: 'test_voice',
          ));
        });
        await tester.pump();
        expect(ttsPitches.last, 1.7);
        expect(ttsCalls.where((call) => call == 'speak'), hasLength(1));
        expect(audio.sessions, isEmpty);

        await _sliderEvent(tester, 'source_volume', 30);
        await _waitUntil(tester, () => audio.sessions.length == 1);
        expect(service.settings.single.ttsPitch, 1.7);
        expect(service.settings.single.sourceVolume, 1.5);
        await _sliderEvent(tester, 'creation_voice_pitch', 0.9);
        await passDebounce();
        expect(audio.sessions, hasLength(1));
        expect(service.settings, hasLength(1));
      }, sourcePath: source.path, previewFactory: () =>
          AudioDescriptionMixPreviewController(
            serviceFactory: () => service,
            audioFactory: () => audio,
            adjustmentDelay: const Duration(milliseconds: 30),
          ));
    },
    variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );

  testWidgets(
    'preview controls stay hidden until playback and retain focus during pause/resume',
    (tester) async {
      final service = _PreviewService();
      final audio = _PreviewAudio()..autoStart = false;
      late AudioDescriptionMixPreviewController preview;
      final source = File('${temporary.path}/preview-film.mp4')
        ..writeAsBytesSync([0]);
      await _exerciseScreen(
        tester,
        () async {
          final apiField = find.descendant(
            of: _control('api_key'),
            matching: find.byType(TextField),
          );
          await tester.enterText(apiField, 'kept-during-preview');
          final focus = tester.widget<TextField>(apiField).focusNode;
          for (final (id, value) in [
            ('tts_engine', 'system'),
            ('system_voice', 'Voce di prova'),
          ]) {
            await tester.runAsync(() async {
              await _form(tester).onEvent!(
                AccessibleListEvent(type: 'picker', id: id, value: value),
              );
              await Future<void>.delayed(Duration.zero);
            });
            await tester.pump();
          }
          // File synthesis can leave awaitSpeakCompletion enabled globally.
          // Live Test voice must reset it before the next Stop/volume change.
          expect(ttsAwaitsCompletion, isTrue);
          await tester.runAsync(() async {
            await Future<void>.sync(
              () => _form(tester).onEvent!(
                const AccessibleListEvent(type: 'activate', id: 'test_voice'),
              ),
            ).timeout(const Duration(seconds: 5));
          });
          await tester.pump();
          expect(ttsAwaitsCompletion, isFalse);
          expect(ttsCalls, contains('speak'));
          expect(cancelledSpeak, isNull);
          await _sliderEvent(tester, 'mp3_bitrate', 4);
          final volume = _control('source_volume');
          final nodeId = tester.getSemantics(volume).id;
          int? previewNodeId;
          final rowIds = _form(tester).sections
              .expand((section) => section.rows)
              .where((row) => !row.id.startsWith('mix_preview'))
              .map((row) => row.id)
              .toList();
          void expectStableForm() {
            expect(
              _form(tester).sections
                  .expand((section) => section.rows)
                  .where((row) => !row.id.startsWith('mix_preview'))
                  .map((row) => row.id)
                  .toList(),
              rowIds,
            );
            expect(tester.getSemantics(volume).id, nodeId);
            expect(focus?.hasFocus, isTrue);
          }
          void expectNoPreviewButton() {
            expect(_control('mix_preview'), findsNothing);
            expect(_control('mix_preview_stop'), findsNothing);
            expect(_form(tester).sections
                .expand((section) => section.rows)
                .where((row) => row.id == 'mix_preview'), isEmpty);
            previewNodeId = null;
            expectStableForm();
          }
          void expectPreviewButton(String title) {
            expectStableForm();
            expect(_control('mix_preview'), findsOneWidget);
            expect(_control('mix_preview_stop'), findsNothing);
            expect(_row(tester, 'mix_preview').title, title);
            expect(_row(tester, 'mix_preview').enabled, isTrue);
            expect(_row(tester, 'mix_preview').accessibilityButtonTrait, isTrue);
            final node = _previewSemantics(tester);
            previewNodeId ??= node.id;
            expect(node.id, previewNodeId);
            expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
            expect(node.getSemanticsData().label, contains(title));
          }

          Future<void> togglePreview() async {
            await tester.runAsync(() async {
              await _form(tester).onEvent!(
                const AccessibleListEvent(type: 'activate', id: 'mix_preview'),
              );
            });
            await tester.pump();
          }

          expectNoPreviewButton();
          // A queued/stale activation must not open a picker or start audio.
          await togglePreview();
          expect(service.settings, isEmpty);
          expect(audio.sessions, isEmpty);
          await _sliderEvent(tester, 'source_volume', 30);
          await _sliderEvent(tester, 'source_volume', 27);
          expect(
            _row(tester, 'mix_preview_status').title,
            'Preparazione della prova audio',
          );
          expectNoPreviewButton();
          expect(_row(tester, 'mix_preview_status').accessibilityButtonTrait, isFalse);
          expect(service.settings, isEmpty);
          await _waitUntil(tester, () => audio.sessions.length == 1);
          // Rendered bytes and a loading player do not expose Resume/Pause.
          expect(preview.canPauseOrResume, isFalse);
          expectNoPreviewButton();
          await togglePreview();
          expect(audio.pauseCalls, 0);
          expect(audio.resumeCalls, 0);
          audio.pendingStart!();
          audio.autoStart = true;
          await tester.pump();
          expect(preview.canPauseOrResume, isTrue);
          final selected = service.settings.single;
          expect(selected.sourceVolume, 1.35);
          expect(selected.bitrateKbps, 256);
          expect(selected.ttsEngine, 'system');
          expect(selected.systemVoice, 'Voce di prova');
          expect(service.sources, [source.path]);
          expect(service.phrases, ['Prova audiodescrizione con ducking.']);
          expect(audio.sessions, [AudioSessionType.playback]);
          expectPreviewButton('Pausa');
          expect(_row(tester, 'api_key').value, 'kept-during-preview');
          expectStableForm();

          // Pause keeps the current playback future open; Resume must not
          // synthesize, load another file, or stop the existing sample.
          final firstPlayback = audio.playing!;
          final stopsBeforePause = audio.stopCalls;
          await togglePreview();
          expect(preview.isPaused, isTrue);
          expect(preview.isPlaying, isFalse);
          expect(preview.isActive, isTrue);
          expect(audio.pauseCalls, 1);
          expect(firstPlayback.isCompleted, isFalse);
          expectPreviewButton('Riprendi');
          await togglePreview();
          expect(preview.isPlaying, isTrue);
          expect(preview.isPaused, isFalse);
          expect(audio.resumeCalls, 1);
          expect(audio.stopCalls, stopsBeforePause);
          expect(audio.playing, same(firstPlayback));
          expect(firstPlayback.isCompleted, isFalse);
          expect(audio.sessions, hasLength(1));
          expect(service.settings, hasLength(1));
          expectPreviewButton('Pausa');

          // Adjust while playing: the earlier sample stops and only the new
          // snapshot can be heard after the accessibility gesture settles.
          await _sliderEvent(tester, 'source_volume', 32);
          expectNoPreviewButton();
          await _waitUntil(tester, () => audio.sessions.length == 2);
          expect(service.settings.last.sourceVolume, 1.6);
          expect(firstPlayback.isCompleted, isTrue);
          expectPreviewButton('Pausa');

          // A new slider value also restarts automatically from a paused mix.
          final pausedPlayback = audio.playing!;
          await togglePreview();
          expect(preview.isPaused, isTrue);
          expectPreviewButton('Riprendi');
          await _sliderEvent(tester, 'source_volume', 34);
          expectNoPreviewButton();
          await _waitUntil(tester, () => audio.sessions.length == 3);
          expect(pausedPlayback.isCompleted, isTrue);
          expect(service.settings.last.sourceVolume, 1.7);
          expect(preview.isPlaying, isTrue);
          expect(audio.resumeCalls, 1);
          expectPreviewButton('Pausa');

          // EOF hides the button instead of offering a non-resumable sample.
          audio.playing!.complete();
          await _waitUntil(tester, () => !preview.isActive);
          expectNoPreviewButton();
          await togglePreview();
          expect(audio.sessions, hasLength(3));
          expect(service.settings, hasLength(3));

          // Another slider change still starts a new preview automatically.
          await _sliderEvent(tester, 'source_volume', 35);
          expectNoPreviewButton();
          await _waitUntil(tester, () => audio.sessions.length == 4);
          expect(service.settings.last.sourceVolume, 1.75);
          expect(service.settings.last.bitrateKbps, 256);
          expectPreviewButton('Pausa');

          // While preparing, a stale activation is harmless. Changing voice
          // cancels pending synthesis through the existing Stop path.
          await _sliderEvent(tester, 'source_volume', 36);
          expect(preview.isPreparing, isTrue);
          expectNoPreviewButton();
          await togglePreview();
          expect(preview.isPreparing, isTrue);
          await tester.runAsync(() async {
            await _form(tester).onEvent!(const AccessibleListEvent(
              type: 'picker', id: 'system_voice', value: '',
            ));
            await Future<void>.delayed(Duration.zero);
          });
          await tester.pump();
          expect(preview.isActive, isFalse);
          expect(preview.isPaused, isFalse);
          expect(audio.playing!.isCompleted, isTrue);
          expectNoPreviewButton();
          await tester.runAsync(
            () => Future<void>.delayed(
              preview.adjustmentDelay + const Duration(milliseconds: 20),
            ),
          );
          await tester.pump();
          expect(audio.sessions, hasLength(4));
          expect(service.settings, hasLength(4));
          expectNoPreviewButton();
        },
        sourcePath: source.path,
        previewFactory: () => preview = AudioDescriptionMixPreviewController(
          serviceFactory: () => service,
          audioFactory: () => audio,
        ),
      );
      expect(service.cleanups, 1);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'cancel while stopping a preview prevents creation from starting later',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ad_mobile_gemini_api_key': 'fixture-key',
      });
      final preview = _HeldStopPreview();
      final source = File('${temporary.path}/cancel-film.mp4')
        ..writeAsBytesSync([0]);
      await _exerciseScreen(
        tester,
        () async {
          await tester.runAsync(() async {
            preview.stopGate = Completer<void>();
            paths.cacheRequested = Completer<void>();
            await _form(tester).onEvent!(
              const AccessibleListEvent(type: 'activate', id: 'create'),
            );
          });
          await tester.pump();
          expect(find.byKey(_runningKey), findsOneWidget);
          final running = tester.widget<UniversalAccessibleList>(
            find.byKey(_runningKey),
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byKey(_runningKey)),
          );
          unawaited(
            Future<void>.sync(
              () => running.onEvent!(
                const AccessibleListEvent(type: 'activate', id: 'cancel'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, l10n.yes));
          await tester.pumpAndSettle();
          expect(preview.stops, greaterThanOrEqualTo(2));
          expect(paths.cacheRequested!.isCompleted, isFalse);
          preview.stopGate!.complete();
          await _waitForWidget(tester, find.byKey(_formKey));
          await tester.pumpAndSettle();
          expect(paths.cacheRequested!.isCompleted, isFalse);
          expect(_row(tester, 'status').value, l10n.audioDescriptionCancelled);
          final saved = await AiAudioDescriptionPreferences.load();
          expect(saved['bitrateKbps'], 192);
          expect(saved['sourceVolume'], 1.0);
        },
        sourcePath: source.path,
        previewFactory: () => preview,
      );
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
  testWidgets(
    'provider is a two-position accessible slider and rapid flicks preserve the selection',
    (tester) async {
      await http.runWithClient(
        () async {
          await _mountScreen(tester);
          final initial = _row(tester, 'provider');
          expect(initial.kind, 'slider');
          expect(initial.accessibilityButtonTrait, isFalse);
          expect(initial.sliderValue, 0);
          expect(initial.sliderMin, 0);
          expect(initial.sliderMax, 1);
          expect(initial.sliderStep, 1);
          expect(initial.options.map((option) => option.value), [0, 1]);
          final node = _control('provider');
          expect(node, findsOneWidget);

          await _sliderEvent(tester, 'provider', 1);
          expect(_row(tester, 'provider').sliderValue, 1);
          expect(_row(tester, 'sonarpad_code').kind, 'textField');
          await _sliderEvent(tester, 'provider', 0);
          expect(_row(tester, 'provider').sliderValue, 0);
          expect(_row(tester, 'api_key').kind, 'textField');
          await _sliderEvent(tester, 'provider', 1);
          await _sliderEvent(tester, 'provider', 0);
          expect(_row(tester, 'provider').sliderValue, 0);
          expect(_control('provider'), findsOneWidget);
          final preference = await AiAudioDescriptionPreferences.load();
          expect(preference['provider'], 'gemini');
        },
        () => MockClient((_) async => http.Response('{}', 503)),
      );
      await _unmountScreen(tester);
    },
    variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );

}
