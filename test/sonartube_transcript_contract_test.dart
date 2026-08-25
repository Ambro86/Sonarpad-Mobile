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
    expect(screen, isNot(contains('Localizations.localeOf(context).languageCode')));
  });

  test('SonarTube transcript keeps the clean screen while using the shared accessible renderer', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(screen, contains('class _SonarTubeTranscriptScreen'));
    expect(screen, contains("ValueKey('sonartube_transcript_back')"));
    expect(screen, contains('l10n.sonarTubeTranscript'));
    expect(screen, contains('l10n.sonarTubeNoTranscript'));
    expect(screen, contains("ValueKey('sonartube_transcript_text')"));
    final start = screen.indexOf('class _SonarTubeTranscriptScreenState');
    final end = screen.indexOf('class _SonarTubeCommentsScreen', start);
    final transcriptScreen = screen.substring(start, end);
    expect(transcriptScreen, contains('useSharedAccessibleViewModel'));
    expect(transcriptScreen, contains('UniversalAccessibleList('));
  });

  test('PHP transcript resolver has modern panel fallback', () {
    final php = File('server/youtube_resolve.php').readAsStringSync();

    expect(php, contains('YT_TRANSCRIPT_URL'));
    expect(php, contains('youtube_transcript_from_panel'));
    expect(php, contains('getTranscriptEndpoint'));
    expect(php, contains('http_post_json_web'));
    expect(php, contains("'transcript_source' => 'youtube_panel'"));
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
      ]) {
        expect(source, contains('"$key"'), reason: '${file.path}: $key');
      }
    }
  });
}
