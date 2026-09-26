import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI audio description screen accepts a preselected source path', () {
    final screen = File(
      'lib/screens/create_ai_audiodescription_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('this.initialSourcePath'));
    expect(screen, contains('final String? initialSourcePath;'));
    expect(screen, contains('widget.initialSourcePath?.trim()'));
  });

  test('online source is persisted in Sonarpad Documents before AI screen', () {
    final service = File(
      'lib/services/online_ai_audiodescription_source_service.dart',
    ).readAsStringSync();
    final action = File(
      'lib/widgets/online_ai_audiodescription_action.dart',
    ).readAsStringSync();

    expect(service, contains('importSonarTubeVideo'));
    expect(service, contains('importRemoteVideo'));
    expect(service, contains('_library.importFile('));
    expect(service, contains('_library.add(document)'));
    expect(service, contains('_library.resolveFilePath(document)'));
    expect(action, contains('CreateAiAudiodescriptionScreen('));
    expect(action, contains('initialSourcePath: sourcePath'));
    expect(action, contains('includeSourceVideoWithProjectOutput: true'));
    expect(screen, contains('includeSourceVideoWithProjectOutput'));
    expect(screen, contains('_completedOutputPaths'));
    expect(screen, contains('result.projectPath != null'));
    expect(screen, contains('_alreadyInSonarpadDocuments'));
  });

  test('SonarTube AI audio description is gated by code and Italian UI', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(screen, contains('RecordingFeatureAccess.isUnlocked()'));
    expect(screen, contains("l10n.localeName == 'it'"));
    expect(screen, contains("id: 'create_ai_audiodescription'"));
    expect(screen, contains('createAiAudiodescriptionFromSonarTube('));
  });

  test('RaiPlay and LA7 Play expose AI audio description only when unlocked', () {
    final rai = File('lib/screens/raiplay_screen.dart').readAsStringSync();
    final la7 = File('lib/screens/la7_play_screen.dart').readAsStringSync();

    for (final source in [rai, la7]) {
      expect(source, contains("language == 'it'"));
      expect(source, contains('RecordingFeatureAccess.isCodeValid(code)'));
      expect(source, contains("id: 'create_ai_audiodescription'"));
      expect(source, contains('createAiAudiodescriptionFromRemoteVideo('));
    }
  });

  test('0.5.0 changelog exposes online AI action only in Italian extras', () {
    final decoded = jsonDecode(
      File('assets/changelog.json').readAsStringSync(),
    ) as List;
    final current = decoded.cast<Map<String, dynamic>>().firstWhere(
      (entry) => entry['version'] == '0.5.0',
    );
    final extras = (current['it_extra'] as List).cast<String>();

    expect(
      extras.any(
        (entry) =>
            entry.contains('Crea audiodescrizione con IA') &&
            entry.contains('SonarTube') &&
            entry.contains('RaiPlay') &&
            entry.contains('LA7 Play'),
      ),
      isTrue,
    );
    for (final language in const [
      'en',
      'fr',
      'es',
      'pt',
      'pt_BR',
      'pl',
      'cs',
      'de',
      'zh_CN',
      'uk',
    ]) {
      final changes = (current[language] as List).cast<String>();
      expect(
        changes.any(
          (entry) =>
              entry.contains('SonarTube') &&
              entry.contains('RaiPlay') &&
              entry.contains('LA7 Play'),
        ),
        isFalse,
      );
    }
  });
}
