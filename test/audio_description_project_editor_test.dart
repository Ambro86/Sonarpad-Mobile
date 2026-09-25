import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';

AudioDescriptionEditableProject sampleProject(String path) =>
    AudioDescriptionEditableProject(
      projectPath: path,
      createdAtUtc: '2026-09-25T00:00:00Z',
      updatedAtUtc: '2026-09-25T00:00:00Z',
      sourcePath: '/missing/movie.mp4',
      outputMp3Path: '/missing/movie_audiodescritto.mp3',
      sourceDurationSec: 100,
      outputDurationSec: 100,
      languageCode: 'it',
      verbosity: 'detailed',
      allowExtendedPauses: true,
      recognizeCharacters: true,
      recognizeScreenText: true,
      geminiModel: 'gemini-3.5-flash-lite',
      ttsEngine: 'edge',
      ttsVoice: 'it-IT-IsabellaNeural',
      edgeLanguage: 'it-IT',
      systemLanguage: 'it-IT',
      systemVoice: null,
      ttsSpeed: 1,
      ttsPitch: 1,
      bitrateKbps: 192,
      duckingDb: -12,
      fadeMs: 150,
      protectedIntervals: const [
        AudioDescriptionProjectInterval(startSec: 10, endSec: 20),
        AudioDescriptionProjectInterval(startSec: 30, endSec: 40),
      ],
      descriptions: const [
        AudioDescriptionProjectItem(
          id: 1,
          text: 'Prima descrizione',
          originalText: 'Prima descrizione',
          renderedText: 'Prima descrizione',
          modified: false,
          geminiStartSec: 4,
          visualEvidenceTimeSec: 4,
          sourceStartSec: 2,
          outputStartSec: 2,
          outputEndSec: 4,
          ttsDurationSec: 2,
          extendedPause: false,
          extendedPauseDurationSec: 0,
          duckStartSec: 1.8,
          duckEndSec: 4.2,
        ),
        AudioDescriptionProjectItem(
          id: 2,
          text: 'Seconda descrizione',
          originalText: 'Seconda descrizione',
          renderedText: 'Seconda descrizione',
          modified: false,
          geminiStartSec: 24,
          visualEvidenceTimeSec: 24,
          sourceStartSec: 22,
          outputStartSec: 22,
          outputEndSec: 24,
          ttsDurationSec: 2,
          extendedPause: false,
          extendedPauseDurationSec: 0,
          duckStartSec: 21.8,
          duckEndSec: 24.2,
        ),
      ],
      excludedDescriptions: const [],
    );

void main() {
  group('Windows-compatible project format', () {
    test('serializes format/version and Windows field names', () {
      final map = sampleProject('x.sonarpad-ad.json').toJson();
      expect(map['format'], 'sonarpad-audio-description-project');
      expect(map['version'], 1);
      expect(map['source_path'], '/missing/movie.mp4');
      expect(map['output_mp3_path'], '/missing/movie_audiodescritto.mp3');
      expect(map['protected_intervals'], isA<List>());
      expect(map['descriptions'], isA<List>());
      expect(map['tts_engine'], 'edge');
    });

    test('system voice remains loadable by Windows through compatibility metadata', () {
      final project = sampleProject('x').copyWith(
        ttsEngine: 'system',
        ttsVoice: 'Samantha',
        systemLanguage: 'it-IT',
        systemVoice: 'Samantha',
      );
      final map = project.toJson();
      expect(map['tts_engine'], 'edge');
      expect(map['tts_voice'], '');
      expect(map['mobile_tts_engine'], 'system');
      expect(map['mobile_system_voice'], 'Samantha');
    });


    test('unsupported Windows engine is preserved until the user changes voice', () {
      final base = sampleProject('x');
      final sapi = AudioDescriptionEditableProject(
        projectPath: base.projectPath,
        createdAtUtc: base.createdAtUtc,
        updatedAtUtc: base.updatedAtUtc,
        sourcePath: base.sourcePath,
        outputMp3Path: base.outputMp3Path,
        sourceDurationSec: base.sourceDurationSec,
        outputDurationSec: base.outputDurationSec,
        languageCode: base.languageCode,
        verbosity: base.verbosity,
        allowExtendedPauses: base.allowExtendedPauses,
        recognizeCharacters: base.recognizeCharacters,
        recognizeScreenText: base.recognizeScreenText,
        geminiModel: base.geminiModel,
        ttsEngine: 'sapi5',
        ttsVoice: 'Microsoft Elsa',
        edgeLanguage: base.edgeLanguage,
        systemLanguage: base.systemLanguage,
        systemVoice: null,
        ttsSpeed: base.ttsSpeed,
        ttsPitch: base.ttsPitch,
        bitrateKbps: base.bitrateKbps,
        duckingDb: base.duckingDb,
        fadeMs: base.fadeMs,
        protectedIntervals: base.protectedIntervals,
        descriptions: base.descriptions,
        excludedDescriptions: base.excludedDescriptions,
      );
      expect(sapi.toJson()['tts_engine'], 'sapi5');
      expect(sapi.toJson()['tts_voice'], 'Microsoft Elsa');
    });

    test('pt_BR and zh_CN serialize to Windows language enum values', () {
      expect(sampleProject('x').copyWith().windowsLanguageCode, 'it');
      final pt = AudioDescriptionEditableProject(
        projectPath: 'x', createdAtUtc: '', updatedAtUtc: '', sourcePath: '',
        outputMp3Path: '', sourceDurationSec: 1, outputDurationSec: 1,
        languageCode: 'pt_BR', verbosity: 'standard', allowExtendedPauses: true,
        recognizeCharacters: true, recognizeScreenText: true, geminiModel: '',
        ttsEngine: 'edge', ttsVoice: '', edgeLanguage: 'pt-BR',
        systemLanguage: 'pt-BR', systemVoice: null, ttsSpeed: 1, ttsPitch: 1,
        bitrateKbps: 192, duckingDb: -12, fadeMs: 150,
        protectedIntervals: const [], descriptions: sampleProject('x').descriptions,
        excludedDescriptions: const [],
      );
      expect(pt.windowsLanguageCode, 'pt-BR');
      final zh = AudioDescriptionEditableProject(
        projectPath: 'x', createdAtUtc: '', updatedAtUtc: '', sourcePath: '',
        outputMp3Path: '', sourceDurationSec: 1, outputDurationSec: 1,
        languageCode: 'zh_CN', verbosity: 'standard', allowExtendedPauses: true,
        recognizeCharacters: true, recognizeScreenText: true, geminiModel: '',
        ttsEngine: 'edge', ttsVoice: '', edgeLanguage: 'zh-CN',
        systemLanguage: 'zh-CN', systemVoice: null, ttsSpeed: 1, ttsPitch: 1,
        bitrateKbps: 192, duckingDb: -12, fadeMs: 150,
        protectedIntervals: const [], descriptions: sampleProject('x').descriptions,
        excludedDescriptions: const [],
      );
      expect(zh.windowsLanguageCode, 'zh');
    });
  });

  group('Project loader and edit safety', () {
    test('loads Windows v1 project', () async {
      final dir = await Directory.systemTemp.createTemp('sonarpad-project-test-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/project.sonarpad-ad.json';
      await File(path).writeAsString(jsonEncode(sampleProject(path).toJson()));
      final service = AiAudioDescriptionService();
      addTearDown(service.dispose);
      final loaded = await service.loadEditableProject(path);
      expect(loaded.descriptions.length, 2);
      expect(loaded.protectedIntervals.length, 2);
      expect(loaded.ttsVoice, 'it-IT-IsabellaNeural');
    });

    test('loads legacy mobile project and upgrades it in memory', () async {
      final dir = await Directory.systemTemp.createTemp('sonarpad-legacy-project-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/legacy.sonarpad-ad.json';
      await File(path).writeAsString(jsonEncode({
        'schema': 'sonarpad-audio-description-project',
        'schema_version': 1,
        'created_at': '2026-09-24T00:00:00Z',
        'source_file': 'movie.mp4',
        'language': 'it',
        'verbosity': 'detailed',
        'allow_extended_pauses': true,
        'recognize_characters': true,
        'recognize_screen_text': true,
        'gemini_model': 'gemini-3.5-flash-lite',
        'tts_engine': 'edge',
        'tts_voice': 'it-IT-IsabellaNeural',
        'pyannote': {
          'protected_intervals': [[10.0, 20.0]]
        },
        'descriptions': [
          {
            'slot_id': 'S1',
            'slot_start_sec': 0.0,
            'slot_end_sec': 10.0,
            'evidence_time_sec': 3.0,
            'description_text': 'Una porta si apre.',
            'included': true,
            'tts_duration_sec': 1.5,
            'original_start_sec': 2.0,
            'output_start_sec': 2.0,
            'output_end_sec': 3.5,
            'extended_pause_sec': 0.0,
          }
        ],
        'excluded_descriptions': [],
      }));
      final service = AiAudioDescriptionService();
      addTearDown(service.dispose);
      final loaded = await service.loadEditableProject(path);
      expect(loaded.descriptions.single.text, 'Una porta si apre.');
      expect(loaded.protectedIntervals.single.startSec, 10);
      expect(loaded.toJson()['format'], 'sonarpad-audio-description-project');
    });

    test('available duration is limited by saved Pyannote gap and next description', () {
      final service = AiAudioDescriptionService();
      addTearDown(service.dispose);
      final project = sampleProject('x');
      expect(service.audioDescriptionProjectAvailableDuration(project, 0), closeTo(8, 0.001));
      expect(service.audioDescriptionProjectAvailableDuration(project, 1), closeTo(8, 0.001));
    });

    test('deleting the last description is refused', () async {
      final dir = await Directory.systemTemp.createTemp('sonarpad-delete-project-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/project.sonarpad-ad.json';
      final one = sampleProject(path).copyWith(
        descriptions: [sampleProject(path).descriptions.first],
      );
      await File(path).writeAsString(jsonEncode(one.toJson()));
      final service = AiAudioDescriptionService();
      addTearDown(service.dispose);
      await expectLater(
        service.deleteProjectDescription(project: one, index: 0),
        throwsA(isA<StateError>()),
      );
    });
  });
}
