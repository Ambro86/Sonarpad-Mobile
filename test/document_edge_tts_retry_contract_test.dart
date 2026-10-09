import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_retry.dart';

void main() {
  test('document Edge TTS retries only the current chunk with fixed delays', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();
    final start = source.indexOf('const edgeRetryDelays = <Duration>[');
    final end = source.indexOf('if (mounted && _speaking) {', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final edgeGeneration = source.substring(start, end);

    for (final seconds in <int>[2, 4, 6, 8, 10]) {
      expect(
        edgeGeneration,
        contains('Duration(seconds: $seconds)'),
        reason: 'The document reader must keep its existing retry schedule.',
      );
    }
    expect(
      edgeGeneration,
      contains('final file = await EdgeTtsRetry.run('),
      reason: 'Retry logic is now in the shared EdgeTtsRetry helper.',
    );
    expect(
      edgeGeneration,
      contains('generate: () => _tts.speakToFile('),
      reason: 'Only the current chunk is synthesized again.',
    );
    expect(
      edgeGeneration,
      contains('retryDelays: edgeRetryDelays,'),
      reason: 'Keep the document-specific 2, 4, 6, 8 and 10 second delays.',
    );
    expect(
      edgeGeneration,
      contains('for (var i = startIndex; i < _chunks.length; i++)'),
      reason: 'Continue to iterate over chunks in order.',
    );
    expect(
      edgeGeneration,
      contains('if (file == null) break;'),
      reason: 'A cancelled session must not enqueue later chunks.',
    );
    expect(
      edgeGeneration,
      contains('controller.add(file);'),
      reason: 'Add a synthesized chunk only after its successful generation.',
    );
    expect(
      edgeGeneration,
      contains('readingToken == _readingToken'),
      reason: 'Stopping or restarting reading must invalidate old retries.',
    );
  });

  test('five retry delays mean one attempt plus five retries', () async {
    var attempts = 0;
    final result = await EdgeTtsRetry.run(
      generate: () async {
        attempts++;
        if (attempts <= 5) {
          throw Exception('Edge TTS ha restituito audio vuoto');
        }
        return File('chunk_6.mp3');
      },
      isActive: () => true,
      retryDelays: List<Duration>.filled(5, Duration.zero),
    );

    expect(attempts, 6);
    expect(result?.path, 'chunk_6.mp3');
  });

  test('Edge TTS stops after the fifth retry if synthesis still fails', () async {
    var attempts = 0;
    await expectLater(
      EdgeTtsRetry.run(
        generate: () async {
          attempts++;
          throw Exception('Edge TTS ha restituito audio vuoto');
        },
        isActive: () => true,
        retryDelays: List<Duration>.filled(5, Duration.zero),
      ),
      throwsA(isA<Exception>()),
    );

    expect(attempts, 6);
  });

  test('Edge retry hardening does not alter player buffering or pause callback', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();

    expect(source, contains('const initialBufferChunks = 2;'));
    expect(source, contains('await _audio.playFileStreamSequentially('));
    expect(source, contains('initialBufferCount: initialBufferChunks,'));
    expect(source, contains('isPaused: () => _ttsPaused,'));
  });
}
