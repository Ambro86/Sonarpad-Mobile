import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'audio_description_project_editor_test.dart' show sampleProject;

AudioDescriptionProjectItem cue(double start, {double duration = 2, String text = 'Nuova', double? speed, bool extended = false}) => AudioDescriptionProjectItem(
  id: 0, text: text, originalText: text, renderedText: text, modified: false,
  geminiStartSec: start, visualEvidenceTimeSec: start, sourceStartSec: start,
  outputStartSec: start, outputEndSec: start + duration, ttsDurationSec: duration,
  ttsSpeedOverride: speed, extendedPause: extended, extendedPauseDurationSec: extended ? 2 : 0,
  duckStartSec: null, duckEndSec: null,
);

void main() {
  final service = AiAudioDescriptionService();
  tearDownAll(service.dispose);
  final project = sampleProject('unused.json');
  AudioDescriptionEditableProject merge(List<AudioDescriptionProjectItem> fresh, {double start = 0, double end = 30, AudioDescriptionEditableProject? saved}) =>
      service.mergeReanalyzedSegment(project: saved ?? project, fresh: fresh, startSec: start, endSec: end);

  test('updates matching texts while retaining identity and saved timing', () {
    final result = merge([cue(3, duration: 3, speed: 1.1)]);
    final item = result.descriptions.first;
    expect(item.id, 1);
    expect(item.sourceStartSec, 2);
    expect(item.outputStartSec, 2);
    expect(item.outputEndSec, 4);
    expect(item.geminiStartSec, 4);
    expect(item.visualEvidenceTimeSec, 4);
    expect(item.originalText, 'Prima descrizione');
    expect(item.text, 'Nuova');
    expect(item.modified, isTrue);
    expect(item.ttsDurationSec, 3);
    expect(item.ttsSpeedOverride, 1.1);
    expect(result.descriptions.last.toJson(), project.descriptions.last.toJson());
  });
  test('too long matched text leaves saved text and speed intact', () {
    final result = merge([cue(2, duration: 9)]);
    expect(result.descriptions.map((e) => e.toJson()), project.descriptions.map((e) => e.toJson()));
  });
  test('unmatched saved descriptions are not removed', () {
    expect(merge([]).descriptions.map((e) => e.toJson()), project.descriptions.map((e) => e.toJson()));
  });
  test('new descriptions only use unoccupied saved gaps', () {
    final result = merge([cue(2), cue(7), cue(14), cue(22)]);
    expect(result.descriptions.map((e) => e.sourceStartSec), [2, 7, 22]);
    expect(result.descriptions[1].id, 3);
  });
  test('new descriptions cannot overlap an existing cue or another new cue', () {
    final result = merge([cue(2), cue(3), cue(7), cue(8), cue(22)]);
    expect(result.descriptions.map((e) => e.sourceStartSec), [2, 7, 22]);
  });
  test('new description crossing dialogue is rejected', () {
    final result = merge([cue(2), cue(9, duration: 2), cue(22)]);
    expect(result.descriptions, hasLength(2));
  });
  test('new description crossing segment end is rejected', () {
    final result = merge([cue(2), cue(22), cue(29, duration: 2)]);
    expect(result.descriptions, hasLength(2));
  });
  test('descriptions outside selected segment are untouched', () {
    final result = merge([cue(2), cue(22)], start: 20);
    expect(result.descriptions.first.toJson(), project.descriptions.first.toJson());
    expect(result.descriptions.last.text, 'Nuova');
  });
  test('a previously empty segment can receive new descriptions', () {
    final result = merge([cue(55), cue(65)], start: 40, end: 80);
    expect(result.descriptions.map((e) => e.sourceStartSec), [2, 22, 55, 65]);
  });
  test('IDs remain unique even when excluded entries have greater IDs', () {
    final result = merge([cue(2), cue(7)], saved: project.copyWith(excludedDescriptions: [{'id': 99}]));
    expect(result.descriptions[1].id, 100);
  });
  test('invalid candidates cannot corrupt the project', () {
    final result = merge([cue(double.nan), cue(5, duration: double.infinity), cue(5, duration: -1), cue(5, text: '')]);
    expect(result.descriptions.map((e) => e.toJson()), project.descriptions.map((e) => e.toJson()));
  });
  test('fresh extended pauses are not inserted into saved timeline', () {
    final result = merge([cue(2), cue(7, extended: true), cue(22)]);
    expect(result.descriptions, hasLength(2));
  });
  test('insertion accounts for earlier extended pauses in output timeline', () {
    final first = cue(2, extended: true);
    final saved = project.copyWith(descriptions: [first]);
    final result = merge([cue(60, speed: 1.15)], start: 40, end: 80, saved: saved);
    expect(result.descriptions.last.sourceStartSec, 60);
    expect(result.descriptions.last.outputStartSec, 62);
    expect(result.descriptions.last.outputEndSec, 64);
    expect(result.descriptions.last.ttsSpeedOverride, 1.15);
  });
  test('segment enumeration includes empty segments and bounds the last one', () async {
    final directory = await Directory.systemTemp.createTemp('ad-segments-');
    try {
      final file = File('${directory.path}/project.json');
      final data = project.toJson()..['source_duration_sec'] = 410;
      await file.writeAsString(jsonEncode(data));
      final loaded = await service.loadEditableProject(file.path);
      expect(AiAudioDescriptionService.projectSegmentCount(loaded), 3);
      expect(AiAudioDescriptionService.projectSegmentRange(loaded, 0), (0.0, 180.0));
      expect(AiAudioDescriptionService.projectSegmentRange(loaded, 2), (360.0, 410.0));
      expect(() => AiAudioDescriptionService.projectSegmentRange(loaded, 3), throwsRangeError);
    } finally { await directory.delete(recursive: true); }
  });
  test('selected absolute track and glossary survive loading editing and saving', () async {
    final directory = await Directory.systemTemp.createTemp('ad-tracks-');
    try {
      final file = File('${directory.path}/project.json');
      final data = project.toJson()..['audio_stream_index'] = 3..['character_glossary'] = [{'name': 'Anna'}];
      await file.writeAsString(jsonEncode(data));
      final loaded = await service.loadEditableProject(file.path);
      expect(loaded.audioStreamIndex, 3);
      await service.saveEditableProject(loaded.copyWith(sourceVolume: 0.7));
      final restored = await service.loadEditableProject(file.path);
      expect(restored.audioStreamIndex, 3);
      expect(restored.characterGlossary, [{'name': 'Anna'}]);
    } finally { await directory.delete(recursive: true); }
  });
  test('track names identify language and title without confusing absolute index', () {
    final track = AiAudioDescriptionService.sourceAudioTrackFromProperties({
      'index': 4, 'codec_name': 'aac', 'tags': {'language': 'ita', 'title': 'Italiano'},
      'disposition': {'default': 1},
    });
    expect(track.index, 4);
    expect(track.label, contains('ita'));
    expect(track.label, contains('Italiano'));
    expect(track.isDefault, isTrue);
  });
}
