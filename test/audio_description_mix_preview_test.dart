import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
// The fixture emulates the native plugin; application code uses its public API.
// ignore: implementation_imports
import 'package:ffmpeg_kit_flutter_new/src/ffmpeg_kit_factory.dart';
// ignore: depend_on_referenced_packages
import 'package:ffmpeg_kit_flutter_platform_interface/ffmpeg_kit_flutter_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';

const _phrase = 'Prova audiodescrizione con ducking.';
const _settings = AiAudioDescriptionSettings(
  provider: 'gemini',
  geminiApiKey: '',
  sonarpadCode: '',
  geminiModel: 'gemini-3.5-flash-lite',
  languageCode: 'it',
  verbosity: 'standard',
  allowExtendedPauses: false,
  recognizeCharacters: false,
  recognizeScreenText: false,
  keepCharacterCatalog: false,
  characterCatalogName: null,
  saveProject: true,
  ttsEngine: 'system',
  edgeLanguage: 'it-IT',
  edgeVoice: 'it-IT-IsabellaNeural',
  systemLanguage: 'it-IT',
  systemVoice: 'Test Italian voice',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = _CommandLineFfmpegKit();
  FFmpegKitPlatform.instance = native;
  bool available;
  try {
    available =
        Process.runSync('ffmpeg', ['-version']).exitCode == 0 &&
        Process.runSync('ffprobe', ['-version']).exitCode == 0;
  } catch (_) {
    available = false;
  }
  final skip = available ? false : 'Requires FFmpeg and FFprobe executables';
  late Directory root;
  late File narration;
  late AiAudioDescriptionService service;
  final ttsCalls = <MethodCall>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sonarpad-mix-preview-');
    SharedPreferences.setMockInitialValues({
      'sonarpad_tts_speed': 1.4,
      'sonarpad_tts_pitch': 0.9,
    });
    native.reset();
    ttsCalls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => root.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.arthenica.com/ffmpeg_kit_event'),
      (_) async => null,
    );
    narration = File('${root.path}/voice.wav');
    if (available) {
      await _ffmpeg([
        '-f',
        'lavfi',
        '-i',
        'aevalsrc=0.1*sin(2*PI*1100*t)|0.1*sin(2*PI*1100*t):s=48000:d=2',
        '-c:a',
        'pcm_f32le',
        narration.path,
      ]);
    }
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      call,
    ) async {
      ttsCalls.add(call);
      if (call.method == 'synthesizeToFile') {
        final args = call.arguments as Map;
        await narration.copy(args['fileName'] as String);
      }
      return 1;
    });
    service = AiAudioDescriptionService();
  });

  tearDown(() async {
    native.releaseBlockedCompletion();
    await service.cleanupMixPreviewCache();
    service.dispose();
    await native.drain();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('multiple real audio tracks: chosen track reaches preview and project export', () async {
    final source = await _twoTrackVideo(root);
    final tracks = await service.sourceAudioTracks(source.path);
    expect(tracks.map((track) => track.index), [1, 2]);
    expect(tracks[0].label, contains('ita'));
    expect(tracks[1].label, contains('eng'));
    for (final track in tracks) {
      final preview = await service.previewMix(sourcePath: source.path,
        settings: _settings.copyWith(audioStreamIndex: track.index), text: _phrase);
      final samples = await _samples(preview.path);
      final wanted = track.index == 1 ? 440 : 880;
      final unwanted = track.index == 1 ? 880 : 440;
      expect(_tone(samples, wanted, 0.8), greaterThan(0.05));
      expect(_tone(samples, unwanted, 0.8), lessThan(0.002));
      final original = _project(root, source.path, sourceDuration: 16, cue: 2);
      final data = original.toJson()..['audio_stream_index'] = track.index;
      await File(original.projectPath).writeAsString(jsonEncode(data));
      final project = await service.loadEditableProject(original.projectPath);
      final result = await service.reexportEditableProject(project: project);
      final exported = await _samples(result.mp3Path);
      expect(_tone(exported, wanted, 0.8), greaterThan(0.05));
      expect(_tone(exported, unwanted, 0.8), lessThan(0.002));
      final reloaded = await service.loadEditableProject(original.projectPath);
      expect(reloaded.audioStreamIndex, track.index);
    }
    expect(native.sourceExtractions, hasLength(2), reason: 'Changing track invalidates the preview cache');
  }, skip: skip);

  test('missing selected audio track fails rather than using another language', () async {
    final source = await _twoTrackVideo(root);
    await expectLater(service.previewMix(sourcePath: source.path,
        settings: _settings.copyWith(audioStreamIndex: 99), text: _phrase),
      throwsA(predicate((error) => '$error'.contains('AUDIO_TRACK_MISSING'))));
    expect(native.sourceExtractions, isEmpty);
  }, skip: skip);

  for (final segment in [0, 1]) {
  test('reanalyzes only saved segment $segment through real preparation synthesis and merge', () async {
    final offset = segment * 180.0;
    final source = await _twoTrackVideo(root, duration: offset + 16);
    SharedPreferences.setMockInitialValues({'ad_mobile_gemini_api_key': 'test-only-not-a-key'});
    final original = _project(root, source.path, sourceDuration: offset + 16, cue: 2);
    final data = original.toJson()
      ..['audio_stream_index'] = 2
      ..['protected_intervals'] = [
        {'start_sec': 0, 'end_sec': 2},
        if (offset > 0) {'start_sec': 5, 'end_sec': offset + 2},
        {'start_sec': offset + 5, 'end_sec': offset + 8}, {'start_sec': offset + 12, 'end_sec': offset + 16},
      ];
    await File(original.projectPath).writeAsString(jsonEncode(data));
    final saved = await service.loadEditableProject(original.projectPath);
    var generationCalls = 0;
    final analyzer = AiAudioDescriptionService(httpClient: MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'supportedGenerationMethods': ['generateContent']}), 200);
      }
      generationCalls++;
      return http.Response(jsonEncode({'candidates': [{'finishReason': 'STOP', 'content': {'parts': [{'text': jsonEncode({
        'audio_descriptions': [
          {'start_time_mmss': '00:02.000', 'end_time_mmss': '00:04.000', 'visual_evidence_time_seconds': 2.5, 'description_text': 'La ragazza apre la porta.'},
          {'start_time_mmss': '00:08.000', 'end_time_mmss': '00:10.000', 'visual_evidence_time_seconds': 8.5, 'description_text': 'Il ragazzo chiude la finestra.'},
        ],
      })}]}}]}), 200);
    }));
    addTearDown(analyzer.dispose);
    final result = await analyzer.reanalyzeProjectSegment(project: saved, segmentIndex: segment, onProgress: (_) {});
    expect(generationCalls, greaterThan(0));
    expect(result.descriptions, hasLength(segment == 0 ? 2 : 3));
    expect(result.descriptions.first.sourceStartSec, 2);
    expect(result.descriptions[segment].text, 'La ragazza apre la porta.');
    expect(result.descriptions.last.sourceStartSec, offset + 8);
    if (segment == 1) expect(result.descriptions.first.toJson(), saved.descriptions.first.toJson());
    expect(result.audioStreamIndex, 2);
    final visual = native.commands.where((args) => args.contains('mpeg4')).toList();
    expect(visual, hasLength(1));
    expect(visual.single, contains('0:2'));
    expect(visual.single[visual.single.indexOf('-ss') + 1], offset.toStringAsFixed(3));
    expect(visual.single[visual.single.indexOf('-t') + 1], '16.000');
    expect(native.commands.any((args) => args.last.endsWith('analysis.wav')), isFalse);
    final restored = await service.loadEditableProject(original.projectPath);
    expect(restored.descriptions, hasLength(segment == 0 ? 2 : 3));
    final exported = await service.reexportEditableProject(project: restored);
    expect(await File(exported.mp3Path).length(), greaterThan(0));
  }, skip: skip);

  }

  test('reanalyzing with unavailable credentials preserves original project bytes', () async {
    final source = await _twoTrackVideo(root);
    final project = _project(root, source.path, sourceDuration: 16, cue: 2);
    await service.saveEditableProject(project);
    final before = await File(project.projectPath).readAsBytes();
    await expectLater(service.reanalyzeProjectSegment(project: project, segmentIndex: 0, onProgress: (_) {}),
        throwsA(predicate((error) => '$error'.contains('API_KEY_REQUIRED'))));
    expect(await File(project.projectPath).readAsBytes(), before);
  }, skip: skip);

  test('saved native speed reaches preview and export, then resets for next cue', () async {
    final source = await _video(root, 'native-speed', duration: 16);
    final first = _project(root, source.path, sourceDuration: 16, cue: 2);
    final second = _project(root, source.path, sourceDuration: 16, cue: 8);
    final data = first.toJson();
    final entries = data['descriptions'] as List;
    (entries.first as Map)['mobile_tts_speed_override'] = 1.1;
    final next = Map<String, Object?>.from(second.descriptions.first.toJson());
    next['id'] = 2;
    entries.add(next);
    await File(first.projectPath).writeAsString(jsonEncode(data));
    final project = await service.loadEditableProject(first.projectPath);
    await service.previewProjectDescription(project: project, index: 0, text: _phrase);
    expect(ttsCalls.where((c) => c.method == 'setSpeechRate').single.arguments, 0.55);
    ttsCalls.clear();
    final exported = await service.reexportEditableProject(project: project);
    expect(ttsCalls.where((c) => c.method == 'setSpeechRate').map((c) => c.arguments),
        [0.5, 0.55, 0.5]);
    expect(await File(exported.mp3Path).length(), greaterThan(0));
    final restored = await service.loadEditableProject(first.projectPath);
    expect(restored.descriptions.first.ttsSpeedOverride, 1.1);
    expect(restored.descriptions.last.ttsSpeedOverride, isNull);
  }, skip: skip);

  test('real preview and reexport share film gain, narration level and ducking', () async {
    final source = await _video(root, 'film', duration: 36);
    final filmReference = await _encodedTone(root, 440, 0.2, 192);
    final voiceReference = await _encodedTone(root, 1100, 0.1, 192);
    AudioDescriptionMixPreview? preview;
    final filmLevels = <List<double>>[];
    final voiceLevels = <double>[];
    for (final volume in [1.0, 0.5, 0.0, 2.0]) {
      preview = await service.previewMix(
        sourcePath: source.path,
        settings: _settings.copyWith(sourceVolume: volume),
        text: _phrase,
      );
      final samples = await _samples(preview.path);
      filmLevels.add([
        _tone(samples, 440, 0.8),
        _tone(samples, 440, 2.8),
        _tone(samples, 440, 5.5),
      ]);
      voiceLevels.add(_tone(samples, 1100, 2.8));
      expect(preview.sourceStartSec, closeTo(12, 0.01));
      expect(preview.narrationStartSec, 2);
      expect(preview.narrationDurationSec, closeTo(2, 0.001));
      expect(preview.durationSec, 10);
    }
    expect(filmLevels[0][0], closeTo(filmReference, 0.002));
    expect(filmLevels[0][1], closeTo(filmReference * 0.251188643150958, 0.002));
    expect(filmLevels[0][2], closeTo(filmReference, 0.002));
    for (var index = 0; index < 3; index++) {
      expect(filmLevels[1][index], closeTo(filmLevels[0][index] / 2, 0.002));
      expect(filmLevels[2][index], closeTo(0, 0.002));
      expect(filmLevels[3][index], closeTo(filmLevels[0][index] * 2, 0.002));
    }
    for (final level in voiceLevels) {
      expect(level, closeTo(voiceReference, 0.002));
    }
    expect(
      ttsCalls.where((call) => call.method == 'synthesizeToFile'),
      hasLength(1),
    );
    expect(native.sourceExtractions, hasLength(1));
    expect(
      ttsCalls.where((call) => call.method == 'setSpeechRate').single.arguments,
      0.7,
    );
    expect(
      ttsCalls.where((call) => call.method == 'setPitch').single.arguments,
      0.9,
    );
    expect(
      ttsCalls.where((call) => call.method == 'setVolume').single.arguments,
      1.0,
    );
    expect(
      ttsCalls.where((call) => call.method == 'setVoice').single.arguments,
      {'name': 'Test Italian voice', 'locale': 'it-IT'},
    );

    // Rebuild a real project through the public export API, without AI/network.
    // The narration sits at the corresponding absolute point in the film.
    final exporter = AiAudioDescriptionService();
    addTearDown(exporter.dispose);
    final exported = await exporter.reexportEditableProject(
      project: _project(
        root,
        source.path,
        sourceDuration: 36,
        cue: 14,
      ).copyWith(sourceVolume: 2.0, ttsSpeed: 1.4, ttsPitch: 0.9),
    );
    final fullSamples = await _samples(exported.mp3Path);
    for (final (index, second) in [0.8, 2.8, 5.5].indexed) {
      expect(
        _tone(fullSamples, 440, second + 12),
        closeTo(filmLevels[3][index], 0.002),
      );
    }
    expect(_tone(fullSamples, 1100, 14.8), closeTo(voiceLevels[3], 0.002));

    // Probe the actual selected encoder, while reusing the complete sample.
    final lowBitrate = await service.previewMix(
      sourcePath: source.path,
      settings: _settings.copyWith(bitrateKbps: 64, sourceVolume: 0.5),
      text: _phrase,
    );
    final information = await _probe(lowBitrate.path);
    expect((information['streams'] as List).single['bit_rate'], '64000');
    expect(native.sourceExtractions, hasLength(1));
    expect(
      ttsCalls.where((call) => call.method == 'synthesizeToFile'),
      hasLength(2),
      reason: 'One cached preview voice and one independent export voice',
    );

    // The captured graph is the production envelope, not a representative test curve.
    final graph = native
        .finalMixes
        .first[native.finalMixes.first.indexOf('-filter_complex') + 1];
    expect(graph, contains('cos('));
    expect(graph, contains('normalize=0'));
    expect(graph, contains('alimiter=limit=0.97:level=false'));
    expect(graph, isNot(contains('loudnorm')));
  }, skip: skip);

  test('project candidate voice, timing, moved source and JSON output choices are honored', () async {
    final source = await _video(root, 'moved_film', duration: 36);
    final candidate =
        _project(
          root,
          '/missing/original.mkv',
          sourceDuration: 36,
          cue: 18,
        ).copyWith(
          ttsVoice: 'Pending French voice',
          systemVoice: 'Pending French voice',
          systemLanguage: 'fr-FR',
          ttsSpeed: 1.2,
          ttsPitch: 1.1,
          sourceVolume: 1.35,
          bitrateKbps: 96,
        );
    final sample = await service.previewProjectMix(
      project: candidate,
      sourcePathOverride: source.path,
      text: 'Essai d’audiodescription.',
    );
    expect(sample.sourceStartSec, closeTo(16, 0.01));
    expect(
      ttsCalls.where((call) => call.method == 'setVoice').single.arguments,
      {'name': 'Pending French voice', 'locale': 'fr-FR'},
    );
    expect(
      ttsCalls.where((call) => call.method == 'setSpeechRate').single.arguments,
      0.6,
    );
    expect(
      ttsCalls.where((call) => call.method == 'setPitch').single.arguments,
      1.1,
    );
    final samples = await _samples(sample.path);
    final filmReference = await _encodedTone(root, 440, 0.2, 96);
    final voiceReference = await _encodedTone(root, 1100, 0.1, 96);
    expect(_tone(samples, 440, 0.8), closeTo(filmReference * 1.35, 0.002));
    expect(_tone(samples, 1100, 2.8), closeTo(voiceReference, 0.002));
    await service.saveEditableProject(candidate);
    final loaded = await service.loadEditableProject(candidate.projectPath);
    expect(loaded.sourceVolume, 1.35);
    expect(loaded.bitrateKbps, 96);
    expect(loaded.systemVoice, 'Pending French voice');
    expect(loaded.ttsSpeed, 1.2);

    final oldDirectory = File(sample.path).parent;
    await service.previewProjectMix(
      project: candidate.copyWith(
        systemVoice: 'Another voice',
        ttsVoice: 'Another voice',
      ),
      sourcePathOverride: source.path,
      text: 'Essai d’audiodescription.',
    );
    expect(await oldDirectory.exists(), isFalse);
    expect(
      ttsCalls.where((call) => call.method == 'synthesizeToFile'),
      hasLength(2),
    );
    expect(native.sourceExtractions, hasLength(2));
    final introductoryCue = await service.previewProjectMix(
      project: _project(root, source.path, sourceDuration: 36, cue: 0),
      text: _phrase,
    );
    expect(
      introductoryCue.sourceStartSec,
      closeTo(12, 0.01),
      reason: 'An initial-only description must not select the opening',
    );
  }, skip: skip);

  test(
    'short films and films without audio retain the whole preview phrase',
    () async {
      final filmReference = await _encodedTone(root, 440, 0.2, 192);
      final voiceReference = await _encodedTone(root, 1100, 0.1, 192);
      for (final hasAudio in [true, false]) {
        final source = await _video(
          root,
          'short_$hasAudio',
          duration: 0.5,
          hasAudio: hasAudio,
        );
        final sample = await service.previewMix(
          sourcePath: source.path,
          settings: _settings.copyWith(sourceVolume: 0.2),
          text: _phrase,
        );
        expect(sample.sourceStartSec, 0);
        expect(sample.durationSec, 10);
        final samples = await _samples(sample.path);
        expect(samples.length / 48000, closeTo(10, 0.06));
        expect(
          _tone(samples, 440, 0.15),
          closeTo(hasAudio ? filmReference * 0.2 : 0, 0.002),
        );
        expect(_tone(samples, 1100, 2.8), closeTo(voiceReference, 0.002));
        expect(_tone(samples, 440, 5.5), closeTo(0, 0.002));
      }
    },
    skip: skip,
  );

  test('preview cancellation targets only its render, drains it and reuses complete cache', () async {
    final source = await _video(root, 'film', duration: 36);
    native.blockNext((args) => args.contains('-filter_complex'));
    final pending = service.previewMix(
      sourcePath: source.path,
      settings: _settings,
      text: _phrase,
    );
    final rejected = expectLater(
      pending,
      throwsA(predicate((e) => '$e'.contains('CANCELLED'))),
    );
    final previewSession = await native.blockedSession.future.timeout(
      const Duration(seconds: 10),
    );
    await expectLater(
      service.previewMix(
        sourcePath: source.path,
        settings: _settings,
        text: _phrase,
      ),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('BUSY')),
      ),
    );
    final otherCompleted = Completer<void>();
    final unrelated = await FFmpegKit.executeWithArgumentsAsync([
      '-y',
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'anullsrc=r=48000:cl=stereo',
      '-t',
      '0.2',
      '-c:a',
      'pcm_s16le',
      '${root.path}/other.wav',
    ], (_) => otherCompleted.complete());
    var drained = false;
    final cancellation = service.cancelPreview().then((_) => drained = true);
    await native.cancellationObserved.future.timeout(
      const Duration(seconds: 5),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      drained,
      isFalse,
      reason: 'Waits for native completion before a replacement',
    );
    expect(native.globalCancellations, 0);
    expect(native.cancelledSessions, [previewSession]);
    expect(native.cancelledSessions, isNot(contains(unrelated.getSessionId())));
    native.releaseBlockedCompletion();
    await cancellation;
    await rejected;
    await otherCompleted.future.timeout(const Duration(seconds: 5));
    expect(await File('${root.path}/other.wav').exists(), isTrue);
    final replacement = await service.previewMix(
      sourcePath: source.path,
      settings: _settings.copyWith(sourceVolume: 0.25),
      text: _phrase,
    );
    expect(
      ttsCalls.where((call) => call.method == 'synthesizeToFile'),
      hasLength(1),
    );
    expect(native.sourceExtractions, hasLength(1));
    final directory = File(replacement.path).parent;
    await service.cleanupMixPreviewCache();
    expect(await directory.exists(), isFalse);
  }, skip: skip);

  test(
    'cancelling an incomplete source excerpt discards the partial cache',
    () async {
      final source = await _video(root, 'film', duration: 36);
      native.blockNext((args) => p.basename(args.last) == 'source.wav');
      final pending = service.previewMix(
        sourcePath: source.path,
        settings: _settings,
        text: _phrase,
      );
      final rejected = expectLater(
        pending,
        throwsA(predicate((e) => '$e'.contains('CANCELLED'))),
      );
      await native.blockedSession.future.timeout(const Duration(seconds: 10));
      final cancellation = service.cancelPreview();
      await native.cancellationObserved.future.timeout(
        const Duration(seconds: 5),
      );
      native.releaseBlockedCompletion();
      await cancellation;
      await rejected;
      final cacheRoot = Directory('${root.path}/audio_description_mix_preview');
      expect(await cacheRoot.list().toList(), isEmpty);
      await service.previewMix(
        sourcePath: source.path,
        settings: _settings,
        text: _phrase,
      );
      expect(
        ttsCalls.where((call) => call.method == 'synthesizeToFile'),
        hasLength(2),
      );
      expect(native.globalCancellations, 0);
    },
    skip: skip,
  );
}

AudioDescriptionEditableProject _project(
  Directory root,
  String sourcePath, {
  required double sourceDuration,
  required double cue,
}) => AudioDescriptionEditableProject(
  projectPath: '${root.path}/project.sonarpad-ad.json',
  createdAtUtc: '2026-10-01T00:00:00Z',
  updatedAtUtc: '2026-10-01T00:00:00Z',
  sourcePath: sourcePath,
  outputMp3Path: '${root.path}/described.mp3',
  sourceDurationSec: sourceDuration,
  outputDurationSec: sourceDuration,
  languageCode: 'it',
  verbosity: 'standard',
  allowExtendedPauses: false,
  recognizeCharacters: false,
  recognizeScreenText: false,
  geminiModel: 'gemini-3.5-flash-lite',
  ttsEngine: 'system',
  ttsVoice: 'Test Italian voice',
  edgeLanguage: 'it-IT',
  systemLanguage: 'it-IT',
  systemVoice: 'Test Italian voice',
  ttsSpeed: 1,
  ttsPitch: 1,
  duckingDb: -12,
  fadeMs: 150,
  protectedIntervals: const [],
  excludedDescriptions: const [],
  descriptions: [
    AudioDescriptionProjectItem(
      id: 1,
      text: _phrase,
      originalText: _phrase,
      renderedText: _phrase,
      modified: false,
      geminiStartSec: cue,
      visualEvidenceTimeSec: cue,
      sourceStartSec: cue,
      outputStartSec: cue,
      outputEndSec: cue + 2,
      ttsDurationSec: 2,
      extendedPause: false,
      extendedPauseDurationSec: 0,
      duckStartSec: cue,
      duckEndSec: cue + 2,
    ),
  ],
);

Future<void> _ffmpeg(List<String> args) async {
  final result = await Process.run('ffmpeg', ['-y', '-v', 'error', ...args]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

Future<File> _twoTrackVideo(Directory root, {double duration = 16}) async {
  final file = File('${root.path}/two-tracks.mkv');
  await _ffmpeg([
    '-f', 'lavfi', '-i', 'color=c=black:s=32x32:r=1:d=$duration',
    '-f', 'lavfi', '-i', 'aevalsrc=0.2*sin(2*PI*440*t):s=48000:d=$duration',
    '-f', 'lavfi', '-i', 'aevalsrc=0.2*sin(2*PI*880*t):s=48000:d=$duration',
    '-map', '0:v', '-map', '1:a', '-map', '2:a',
    '-metadata:s:a:0', 'language=ita', '-metadata:s:a:1', 'language=eng',
    '-c:v', 'ffv1', '-c:a', 'pcm_f32le', file.path,
  ]);
  return file;
}

Future<File> _video(
  Directory root,
  String name, {
  required double duration,
  bool hasAudio = true,
}) async {
  final file = File('${root.path}/$name.mkv');
  final initialSilence = duration > 10 ? '*gte(t\\,10)' : '';
  await _ffmpeg([
    '-f',
    'lavfi',
    '-i',
    'color=c=black:s=16x16:r=1:d=$duration',
    if (hasAudio) ...[
      '-f',
      'lavfi',
      '-i',
      'aevalsrc=0.2*sin(2*PI*440*t)$initialSilence|0.2*sin(2*PI*440*t)$initialSilence:s=48000:d=$duration',
      '-map',
      '0:v',
      '-map',
      '1:a',
      '-c:a',
      'pcm_f32le',
    ],
    '-t',
    '$duration',
    '-c:v',
    'ffv1',
    file.path,
  ]);
  return file;
}

Future<Map<String, dynamic>> _probe(String path) async {
  final result = await Process.run('ffprobe', [
    '-v',
    'error',
    '-show_streams',
    '-show_format',
    '-of',
    'json',
    path,
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}

Future<Float32List> _samples(String path) async {
  final result = await Process.run('ffmpeg', [
    '-v',
    'error',
    '-i',
    path,
    '-vn',
    '-af',
    'pan=mono|c0=c0',
    '-ac',
    '1',
    '-ar',
    '48000',
    '-f',
    'f32le',
    'pipe:1',
  ], stdoutEncoding: null);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  final bytes = Uint8List.fromList(result.stdout as List<int>);
  return bytes.buffer.asFloat32List();
}

// LAME applies its own bitrate-dependent encoding scale. Measure the same
// encoder on each known signal, without a mixer, before comparing amplitudes.
Future<double> _encodedTone(
  Directory root,
  int frequency,
  double amplitude,
  int bitrate,
) async {
  final file = File('${root.path}/reference_${frequency}_$bitrate.mp3');
  await _ffmpeg([
    '-f',
    'lavfi',
    '-i',
    'aevalsrc=$amplitude*sin(2*PI*$frequency*t)|$amplitude*sin(2*PI*$frequency*t):s=48000:d=1',
    '-c:a',
    'libmp3lame',
    '-b:a',
    '${bitrate}k',
    file.path,
  ]);
  return _tone(await _samples(file.path), frequency, 0.5);
}

double _tone(Float32List samples, int frequency, double second) {
  final start = (second * 48000).round();
  const count = 4800;
  var sine = 0.0;
  var cosine = 0.0;
  for (var index = start; index < start + count; index++) {
    final angle = 2 * math.pi * frequency * index / 48000;
    sine += samples[index] * math.sin(angle);
    cosine += samples[index] * math.cos(angle);
  }
  return 2 * math.sqrt(sine * sine + cosine * cosine) / count;
}

/// Runs production plugin commands unchanged in desktop FFmpeg/FFprobe.
/// Only native speech synthesis is replaced by a known, non-normalized signal.
class _CommandLineFfmpegKit extends FFmpegKitPlatform {
  int _nextId = 1;
  final Map<int, _NativeSession> _sessions = {};
  final List<List<String>> commands = [];
  final List<int> cancelledSessions = [];
  int globalCancellations = 0;
  bool Function(List<String>)? _block;
  Completer<int> blockedSession = Completer<int>();
  Completer<void> cancellationObserved = Completer<void>();
  Completer<void>? _blockedCompletion;
  final List<Future<void>> _running = [];

  Iterable<List<String>> get sourceExtractions =>
      commands.where((args) => p.basename(args.last) == 'source.wav');
  Iterable<List<String>> get finalMixes =>
      commands.where((args) => args.contains('-filter_complex'));

  void reset() {
    commands.clear();
    cancelledSessions.clear();
    globalCancellations = 0;
    _block = null;
    _blockedCompletion = null;
    blockedSession = Completer<int>();
    cancellationObserved = Completer<void>();
  }

  void blockNext(bool Function(List<String>) matches) {
    _block = matches;
    _blockedCompletion = Completer<void>();
  }

  void releaseBlockedCompletion() {
    if (_blockedCompletion?.isCompleted == false) {
      _blockedCompletion!.complete();
    }
  }

  Future<void> drain() async => Future.wait(_running);

  Map<String, Object?> _create(List<String> args, int type) {
    final session = _NativeSession(_nextId++, args, type);
    _sessions[session.id] = session;
    return session.map;
  }

  Future<void> _execute(int id, {required bool asynchronous}) async {
    final session = _sessions[id]!;
    final blocked = _block?.call(session.args) == true;
    if (blocked) _block = null;
    commands.add(session.args);
    session.process = await Process.start('ffmpeg', [
      if (blocked) '-re',
      ...session.args,
    ]);
    final stdoutFuture = session.process!.stdout.drain<void>();
    final stderrFuture = session.process!.stderr.transform(utf8.decoder).join();
    if (blocked) blockedSession.complete(id);
    Future<void> finish() async {
      session.code = await session.process!.exitCode;
      await stdoutFuture;
      session.logs = await stderrFuture;
      if (blocked) await _blockedCompletion!.future;
      if (asynchronous) {
        FFmpegKitFactory.getFFmpegSessionCompleteCallback(id)
            ?.call(FFmpegKitFactory.mapToSession(session.map) as FFmpegSession);
      }
    }

    final completed = finish();
    _running.add(completed);
    if (!asynchronous) await completed;
  }

  @override
  Future<Map<dynamic, dynamic>?> abstractSessionCreateFFmpegSession(
    List<String> args,
  ) async => _create(args, 1);
  @override
  Future<Map<dynamic, dynamic>?> abstractSessionCreateMediaInformationSession(
    List<String> args,
  ) async => _create(args, 3);
  @override
  Future<void> ffmpegKitConfigAsyncFFmpegExecute(int? sessionId) =>
      _execute(sessionId!, asynchronous: true);
  @override
  Future<void> ffmpegKitConfigFFmpegExecute(int? sessionId) =>
      _execute(sessionId!, asynchronous: false);
  @override
  Future<void> ffmpegKitConfigGetMediaInformationExecute(
    int? sessionId,
    int? waitTimeout,
  ) async {
    final session = _sessions[sessionId]!;
    final result = await Process.run('ffprobe', session.args);
    session.code = result.exitCode;
    session.logs = '${result.stderr}';
    if (result.exitCode == 0) {
      session.information =
          jsonDecode(result.stdout as String) as Map<String, dynamic>;
    }
  }

  @override
  Future<Map<dynamic, dynamic>?> mediaInformationSessionGetMediaInformation(
    int? sessionId,
  ) async => _sessions[sessionId]!.information;
  @override
  Future<int?> abstractSessionGetReturnCode(int? sessionId) async =>
      _sessions[sessionId]!.code;
  @override
  Future<String?> abstractSessionGetAllLogsAsString(
    int? sessionId,
    int? waitTimeout,
  ) async => _sessions[sessionId]!.logs;
  @override
  Future<void> ffmpegKitCancelSession(int sessionId) async {
    cancelledSessions.add(sessionId);
    _sessions[sessionId]?.process?.kill(ProcessSignal.sigterm);
    if (!cancellationObserved.isCompleted) cancellationObserved.complete();
  }

  @override
  Future<void> ffmpegKitCancel() async {
    globalCancellations++;
    for (final session in _sessions.values) {
      session.process?.kill(ProcessSignal.sigterm);
    }
  }

  @override
  Future<int?> ffmpegKitFlutterInitializerGetLogLevel() async => 16;
  @override
  Future<void> ffmpegKitConfigSetLogLevel(int level) async {}
  @override
  Future<String?> ffmpegKitConfigGetPlatform() async => 'test';
  @override
  Future<String> archDetectGetArch() async => 'command-line';
  @override
  Future<String?> getPackageName() async => 'ffmpeg';
  @override
  Future<List<dynamic>?> getExternalLibraries() async => ['lame'];
  @override
  Future<void> ffmpegKitConfigEnableRedirection() async {}
  @override
  Future<bool?> ffmpegKitConfigIsLTSBuild() async => false;
}

class _NativeSession {
  _NativeSession(this.id, this.args, this.type);
  final int id;
  final List<String> args;
  final int type;
  Process? process;
  int code = 0;
  String logs = '';
  Map<String, dynamic>? information;
  Map<String, Object?> get map => {
    'sessionId': id,
    'createTime': 0,
    'startTime': 0,
    'command': args.join(' '),
    'type': type,
  };
}
