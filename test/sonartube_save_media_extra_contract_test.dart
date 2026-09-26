import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube save media is gated by extra code and Italian UI', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(screen, contains('RecordingFeatureAccess.isUnlocked()'));
    expect(screen, contains("l10n.localeName == 'it'"));
    expect(screen, contains("id: 'save_media'"));
    expect(screen, contains('saveSonarTubeMediaWithDestination('));
  });

  test('SonarTube save media reuses the generated-media destination flow', () {
    final dialog = File(
      'lib/widgets/sonartube_save_media_dialog.dart',
    ).readAsStringSync();

    expect(dialog, contains('l10n.mediaProcessingCompleted'));
    expect(dialog, contains('l10n.saveInSonarpadDocuments'));
    expect(dialog, contains('l10n.share'));
    expect(dialog, contains('MediaExportDestinationService'));
  });

  test('0.5.0 changelog exposes save media only in Italian extras', () {
    final decoded = jsonDecode(File('assets/changelog.json').readAsStringSync()) as List;
    final current = decoded.cast<Map<String, dynamic>>().firstWhere(
      (entry) => entry['version'] == '0.5.0',
    );
    final extras = (current['it_extra'] as List).cast<String>();

    expect(extras.any((entry) => entry.contains('Salva media')), isTrue);
    for (final language in const ['en', 'fr', 'es', 'pt', 'pt_BR', 'pl', 'cs', 'de', 'zh_CN', 'uk']) {
      final changes = (current[language] as List).cast<String>();
      expect(changes.any((entry) => entry.contains('Salva media')), isFalse);
    }
  });
}
