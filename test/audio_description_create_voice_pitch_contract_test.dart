import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';

import 'audio_description_project_editor_test.dart' show sampleProject;

const _base = AiAudioDescriptionSettings(
  provider: 'gemini',
  geminiApiKey: '',
  sonarpadCode: '',
  geminiModel: 'gemini-3.5-flash-lite',
  languageCode: 'it',
  verbosity: 'standard',
  allowExtendedPauses: false,
  allowNonverbalVocals: false,
  recognizeCharacters: true,
  recognizeScreenText: true,
  keepCharacterCatalog: false,
  characterCatalogName: null,
  saveProject: true,
  ttsEngine: 'edge',
  edgeLanguage: 'it-IT',
  edgeVoice: 'it-IT-IsabellaNeural',
  systemLanguage: 'it-IT',
  systemVoice: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy callers without a per-creation pitch keep global behavior', () async {
    expect(_base.ttsPitch, isNull);
    final saved = await AiAudioDescriptionPreferences.load();
    expect(saved['voicePitch'], isNull);
    final copied = _base.copyWith(verbosity: 'short');
    expect(copied.ttsPitch, isNull);
    expect(copied.allowNonverbalVocals, isFalse);
  });

  test('pitch survives slider-like updates and full creation preferences save', () async {
    await AiAudioDescriptionPreferences.saveCreationVoicePitch(1.7);
    expect((await AiAudioDescriptionPreferences.load())['voicePitch'], 1.7);
    final selected = _base.copyWith(ttsPitch: 0.8);
    final retry = selected.copyWith(verbosity: 'short');
    expect(retry.ttsPitch, 0.8);
    expect(retry.allowNonverbalVocals, isFalse);
    await AiAudioDescriptionPreferences.save(retry);
    expect((await AiAudioDescriptionPreferences.load())['voicePitch'], 0.8);
    await AiAudioDescriptionPreferences.saveCreationVoicePitch(2.4);
    expect((await AiAudioDescriptionPreferences.load())['voicePitch'], 2.0);
    await AiAudioDescriptionPreferences.saveCreationVoicePitch(0.1);
    expect((await AiAudioDescriptionPreferences.load())['voicePitch'], 0.5);
  });

  test('saved projects preserve pitch independently of subsequent UI changes', () async {
    final dir = await Directory.systemTemp.createTemp('sonarpad-pitch-project-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/pitch.sonarpad-ad.json';
    final service = AiAudioDescriptionService();
    addTearDown(service.dispose);
    final original = sampleProject(path).copyWith(ttsPitch: 1.6);
    await service.saveEditableProject(original);
    final raw = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    expect(raw['mobile_tts_pitch'], 1.6);
    final restored = await service.loadEditableProject(path);
    expect(restored.ttsPitch, 1.6);
    await AiAudioDescriptionPreferences.saveCreationVoicePitch(0.5);
    expect((await service.loadEditableProject(path)).ttsPitch, 1.6);
  });
}
