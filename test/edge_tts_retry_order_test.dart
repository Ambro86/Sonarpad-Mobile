import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_retry.dart';

void main() {
  test('un retry non fa ricominciare i blocchi precedenti', () async {
    final requested = <int>[];
    final queue = <String>[];
    final chunks = [1, 2, 3];

    for (final index in chunks) {
      final file = await EdgeTtsRetry.run(
        generate: () async {
          requested.add(index);
          // Simula un guasto Edge sul secondo blocco gia' preceduto
          // da un blocco riprodotto; solo il secondo viene ripetuto.
          if (index == 2 && requested.where((i) => i == 2).length == 1) {
            throw Exception('Edge TTS ha restituito audio vuoto');
          }
          return File('audio_chunk_$index.mp3');
        },
        isActive: () => true,
        retryDelays: const [Duration.zero],
      );
      if (file != null) queue.add(file.path);
    }

    expect(requested, [1, 2, 2, 3]);
    expect(queue, [
      'audio_chunk_1.mp3',
      'audio_chunk_2.mp3',
      'audio_chunk_3.mp3',
    ]);
  });

  test('uno Stop non accoda nuovi blocchi dopo l interruzione', () async {
    var active = true;
    final queue = <String>[];
    final requested = <int>[];
    for (var index = 1; index <= 3; index++) {
      final file = await EdgeTtsRetry.run(
        generate: () async {
          requested.add(index);
          if (index == 2) throw Exception('Edge TTS ha restituito audio vuoto');
          return File('audio_chunk_$index.mp3');
        },
        isActive: () => active,
        onRetry: (_, __, ___) { active = false; },
        retryDelays: const [Duration.zero],
      );
      if (file == null) break;
      queue.add(file.path);
    }
    expect(requested, [1, 2]);
    expect(queue, ['audio_chunk_1.mp3']);
  });
}
