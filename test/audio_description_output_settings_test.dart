import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_mix.dart';

import 'audio_description_project_editor_test.dart' show sampleProject;

const _settings = AiAudioDescriptionSettings(
  provider: 'gemini',
  geminiApiKey: '',
  sonarpadCode: '',
  geminiModel: 'gemini-3.5-flash-lite',
  languageCode: 'it',
  verbosity: 'detailed',
  allowExtendedPauses: true,
  recognizeCharacters: true,
  recognizeScreenText: true,
  keepCharacterCatalog: true,
  characterCatalogName: 'Personaggi',
  saveProject: true,
  createVideoOutput: true,
  ttsEngine: 'edge',
  edgeLanguage: 'it-IT',
  edgeVoice: 'it-IT-IsabellaNeural',
  systemLanguage: 'it-IT',
  systemVoice: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'existing settings and preferences retain 192 kbps and full source level',
    () async {
      expect(_settings.bitrateKbps, 192);
      expect(_settings.sourceVolume, 1);
      final preferences = await AiAudioDescriptionPreferences.load();
      expect(preferences['bitrateKbps'], 192);
      expect(preferences['sourceVolume'], 1);
    },
  );

  test(
    'output choices survive preference reload and unrelated settings copies',
    () async {
      for (final bitrate in audioDescriptionMp3Bitrates) {
        final selected = _settings.copyWith(
          bitrateKbps: bitrate,
          sourceVolume: 1.35,
        );
        final briefRetry = selected.copyWith(verbosity: 'short');
        expect(briefRetry.bitrateKbps, bitrate);
        expect(briefRetry.sourceVolume, 1.35);
        expect(briefRetry.recognizeCharacters, isTrue);
        expect(briefRetry.recognizeScreenText, isTrue);
        expect(briefRetry.allowExtendedPauses, isTrue);
        expect(briefRetry.createVideoOutput, isTrue);
        expect(briefRetry.edgeVoice, _settings.edgeVoice);
        await AiAudioDescriptionPreferences.save(briefRetry);
        final restored = await AiAudioDescriptionPreferences.load();
        expect(restored['bitrateKbps'], bitrate);
        expect(restored['sourceVolume'], 1.35);
        expect(restored['verbosity'], 'short');
        expect(restored['keepCatalog'], isTrue);
        expect(restored['catalogName'], 'Personaggi');
      }
    },
  );

  test(
    'settings and corrupt stored values share safe output normalization',
    () async {
      final invalid = _settings.copyWith(
        bitrateKbps: 0,
        sourceVolume: double.nan,
      );
      expect(invalid.bitrateKbps, 192);
      expect(invalid.sourceVolume, 1);
      expect(_settings.copyWith(sourceVolume: -0.5).sourceVolume, 0);
      expect(_settings.copyWith(sourceVolume: 1.5).sourceVolume, 1.5);
      expect(_settings.copyWith(sourceVolume: 2).sourceVolume, 2);
      expect(_settings.copyWith(sourceVolume: 3).sourceVolume, 2);
      expect(_settings.copyWith(sourceVolume: double.infinity).sourceVolume, 1);
      SharedPreferences.setMockInitialValues({
        'ad_mobile_bitrate_kbps': 'invalid',
        'ad_mobile_source_volume': 'NaN',
      });
      final restored = await AiAudioDescriptionPreferences.load();
      expect(restored['bitrateKbps'], 192);
      expect(restored['sourceVolume'], 1);
      await AiAudioDescriptionPreferences.save(invalid);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('ad_mobile_bitrate_kbps'), 192);
      expect(preferences.getDouble('ad_mobile_source_volume'), 1);
    },
  );

  test(
    'project save reload and voice edits preserve both output choices',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'sonarpad-output-options-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/project.sonarpad-ad.json';
      final service = AiAudioDescriptionService();
      addTearDown(service.dispose);
      final selected = sampleProject(path)
          .copyWith(bitrateKbps: 96, sourceVolume: 1.4);
      await service.saveEditableProject(selected);
      final saved =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      expect(saved['bitrate_kbps'], 96);
      expect(saved['source_volume'], 1.4);
      final loaded = await service.loadEditableProject(path);
      final voiceEdit = loaded.copyWith(
        ttsVoice: 'it-IT-DiegoNeural',
        ttsPitch: 0.9,
      );
      await service.saveEditableProject(voiceEdit);
      final reloaded = await service.loadEditableProject(path);
      expect(reloaded.bitrateKbps, 96);
      expect(reloaded.sourceVolume, 1.4);
      expect(reloaded.ttsVoice, 'it-IT-DiegoNeural');
      expect(reloaded.ttsPitch, 0.9);
      expect(
        reloaded.descriptions.map((item) => item.toJson()),
        selected.descriptions.map((item) => item.toJson()),
      );
      expect(reloaded.duckingDb, selected.duckingDb);
      expect(reloaded.fadeMs, selected.fadeMs);
    },
  );

  test(
    'old and malformed project output fields fall back without changing cues',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'sonarpad-legacy-output-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/old.sonarpad-ad.json';
      final service = AiAudioDescriptionService();
      addTearDown(service.dispose);
      final original = sampleProject(path);
      for (final fields in <Map<String, Object?>>[
        {},
        {'bitrate_kbps': 'unexpected', 'source_volume': 'NaN'},
        {'bitrate_kbps': 999, 'source_volume': null},
      ]) {
        final payload = original.toJson()
          ..remove('bitrate_kbps')
          ..remove('source_volume')
          ..addAll(fields);
        await File(path).writeAsString(jsonEncode(payload));
        final loaded = await service.loadEditableProject(path);
        expect(loaded.bitrateKbps, 192);
        expect(loaded.sourceVolume, 1);
        expect(loaded.descriptions.length, original.descriptions.length);
        expect(
          loaded.protectedIntervals.map((item) => item.toJson()),
          original.protectedIntervals.map((item) => item.toJson()),
        );
      }
    },
  );
}
