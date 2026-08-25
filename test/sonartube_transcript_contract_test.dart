import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every SonarTube video exposes the transcribe secondary action', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final service = File('lib/services/sonartube_service.dart').readAsStringSync();

    expect(screen, contains('l10n.sonarTubeTranscribeVideo'));
    expect(screen, contains("id: 'transcribe_video'"));
    expect(screen, contains('Future<void> _openTranscript'));
    expect(service, contains("'transcribe': '1'"));
    expect(service, contains('Future<SonarTubeTranscript> transcribe'));
    expect(service, contains("String languageCode = 'auto'"));
    expect(service, contains("'timestamps': '1'"));
    expect(service, contains('for (var attempt = 0; attempt < 2; attempt++)'));
    expect(screen, isNot(contains('Localizations.localeOf(context).languageCode')));
  });

  test('SonarTube transcript keeps the clean screen while using the shared accessible renderer', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(screen, contains('class _SonarTubeTranscriptScreen'));
    expect(screen, contains("ValueKey('sonartube_transcript_back')"));
    expect(screen, contains('l10n.sonarTubeTranscript'));
    expect(screen, contains('l10n.sonarTubeNoTranscript'));
    expect(screen, contains("ValueKey('sonartube_transcript_text')"));
    expect(screen, contains("ValueKey('sonartube_transcript_copy')"));
    expect(screen, contains("ValueKey('sonartube_transcript_save')"));
    expect(screen, contains("ValueKey('sonartube_transcript_saved_ok')"));
    expect(screen, contains(r"id: 'transcript_paragraph_$index'"));
    expect(screen, contains("transcript.paragraphs.join('\\n\\n')"));
    expect(screen, contains('DocumentLibraryService()'));
    expect(screen, contains('await library.add(document)'));
    expect(screen, contains('l10n.sonarTubeTranscriptSavedInDocuments'));
    expect(screen, contains('child: Text(l10n.ok)'));
    final start = screen.indexOf('class _SonarTubeTranscriptScreenState');
    final end = screen.indexOf('class _SonarTubeCommentsScreen', start);
    final transcriptScreen = screen.substring(start, end);
    expect(transcriptScreen, contains('useSharedAccessibleViewModel'));
    expect(transcriptScreen, contains('UniversalAccessibleList('));
  });

  test('all locales contain SonarTube transcript labels', () {
    for (final file in Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))) {
      final source = file.readAsStringSync();
      for (final key in const [
        'sonarTubeTranscribeVideo',
        'sonarTubeTranscript',
        'sonarTubeNoTranscript',
        'sonarTubeCopyTranscript',
        'sonarTubeTranscriptCopied',
        'sonarTubeTranscriptSavedInDocuments',
      ]) {
        expect(source, contains('"$key"'), reason: '${file.path}: $key');
      }
    }
  });
}
