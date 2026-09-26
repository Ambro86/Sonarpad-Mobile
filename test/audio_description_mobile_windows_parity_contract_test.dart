import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File('lib/screens/create_ai_audiodescription_screen.dart')
      .readAsStringSync();
  final service = File('lib/services/ai_audiodescription_service.dart')
      .readAsStringSync();
  final destination = File('lib/services/media_export_destination_service.dart')
      .readAsStringSync();
  final documents = File('lib/screens/documents_screen.dart').readAsStringSync();
  final recordings =
      File('lib/screens/tv_recordings_screen.dart').readAsStringSync();
  final projectEditor =
      File('lib/screens/audio_description_project_editor_screen.dart')
          .readAsStringSync();

  test('Windows-parity AI options have the requested defaults', () {
    expect(screen, contains('bool _extendedPauses = false;'));
    expect(screen, contains('bool _recognizeScreenText = true;'));
    expect(screen, contains('bool _createVideoOutput = false;'));
    expect(screen, contains("id: 'extended'"));
    expect(screen, contains("id: 'create_video_output'"));
    expect(screen, contains("id: 'screen_text'"));
  });

  test('evidence remains cognitive metadata and is not mandatory for parsing', () {
    expect(service, contains('visual_evidence_time_seconds'));
    expect(service, isNot(contains('if (evidenceValue == null) continue;')));
    expect(service, contains('evidenceTime: diagnosticEvidence'));
    expect(service, contains('final double? evidenceTime;'));
  });

  test('video output is wired and excludes extended-pause timeline changes', () {
    expect(service, contains('_muxAudioDescriptionIntoVideo'));
    expect(screen, contains('enabled: !_running && !_createVideoOutput'));
    expect(screen, contains('allowExtendedPauses: _extendedPauses && !_createVideoOutput'));
  });

  test('audiodescriptions and projects save under Audiodescriptions', () {
    expect(destination, contains("displayName: 'Audiodescriptions'"));
    expect(destination, contains('saveInSonarpadAudiodescriptions'));
    expect(screen, contains('saveInSonarpadAudiodescriptions'));
    expect(projectEditor, contains('saveInSonarpadAudiodescriptions'));
  });

  test('character catalogs are saved and loaded from Audiodescriptions/Catalogs', () {
    expect(destination, contains("displayName: 'Catalogs'"));
    expect(destination, contains('ensureAudiodescriptionCatalogsFolder'));
    expect(service, contains("p.join(documents.path, 'Audiodescriptions', 'Catalogs')"));
    expect(service, contains('_syncCatalogsFromSonarpadDocuments'));
    expect(screen, contains("id: 'load_character_catalog'"));
    expect(screen, contains("id: 'keep_character_catalog'"));
  });

  test('saved catalog identity stays authoritative', () {
    expect(service, contains('authoritative'));
    final fallbacks = File('lib/services/audio_description_fallbacks.dart')
        .readAsStringSync();
    expect(fallbacks, contains('mergeCharacterCatalog'));
    expect(fallbacks, contains('0.65'));
  });

  test('document removal returns accessibility focus to first remaining row', () {
    expect(documents, contains('final targetId = remaining.first.id;'));
    expect(documents, contains('focusToReturnAfterStructureChange(targetId)'));
  });

  test('TV recordings expose AI creation as secondary action and hidden visual action', () {
    expect(recordings, contains("id: 'ai_audiodescription'"));
    expect(recordings, contains('audioDescriptionCreateWithAi'));
    expect(recordings, contains('ExcludeSemantics('));
    expect(recordings, contains('Icons.auto_awesome'));
  });

  test('prompt explicitly avoids narrating events already obvious from sound', () {
    expect(service, contains('DO NOT REDUNDANTLY DESCRIBE AUDIBLE EVENTS'));
    expect(service, contains('_soundAlreadyObviousRule'));
  });

  test('new UI strings exist in every ARB locale', () {
    const keys = <String>[
      'audioDescriptionCreateVideoOutput',
      'audioDescriptionLoadCharacterCatalog',
      'audioDescriptionImportCharacterCatalog',
      'audioDescriptionCharacterCatalogLoaded',
      'audioDescriptionCreateWithAi',
    ];
    for (final file in Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))) {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in keys) {
        expect(data[key]?.toString().trim(), isNotEmpty,
            reason: '${file.path}: $key');
      }
    }
  });
}
