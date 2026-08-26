import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('document Edge TTS retries only the current chunk with fixed delays', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();
    final start = source.indexOf(
      "const edgeRetryDelays = <Duration>[",
    );
    final end = source.indexOf(
      'if (mounted && _speaking) {',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final edgeGeneration = source.substring(start, end);

    for (final seconds in <int>[2, 4, 6, 8, 10]) {
      expect(
        edgeGeneration,
        contains('Duration(seconds: $seconds)'),
        reason: 'Edge document reading must keep the requested retry schedule.',
      );
    }
    expect(
      edgeGeneration,
      contains('if (attempt >= edgeRetryDelays.length) rethrow;'),
      reason: 'Five retry delays must mean the normal attempt plus five retries.',
    );
    expect(
      edgeGeneration,
      contains("file = await _tts.speakToFile("),
      reason: 'Retries must wrap only the existing Edge chunk generation call.',
    );
    expect(
      edgeGeneration,
      contains('readingToken != _readingToken'),
      reason: 'Stopping or restarting reading must still cancel retry generation.',
    );
  });

  test('Edge retry hardening does not alter player buffering or pause callback', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();

    expect(source, contains('const initialBufferChunks = 2;'));
    expect(
      source,
      contains('await _audio.playFileStreamSequentially('),
    );
    expect(
      source,
      contains('initialBufferCount: initialBufferChunks,'),
    );
    expect(source, contains('isPaused: () => _ttsPaused,'));
  });
}
