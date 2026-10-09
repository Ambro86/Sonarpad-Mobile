import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_retry.dart';

void main() {
  test('riprova solo il blocco fallito dopo audio vuoto e conserva il risultato',
      () async {
    var attempts = 0;
    final retries = <int>[];
    final result = await EdgeTtsRetry.run(
      generate: () async {
        attempts++;
        if (attempts < 3) {
          throw Exception('Edge TTS ha restituito audio vuoto');
        }
        return File('blocco-recuperato.mp3');
      },
      isActive: () => true,
      onRetry: (retry, _, __) => retries.add(retry),
      retryDelays: const [Duration.zero, Duration.zero],
    );

    expect(attempts, 3);
    expect(retries, [1, 2]);
    expect(result?.path, 'blocco-recuperato.mp3');
  });

  test('non riprova gli errori non temporanei', () async {
    var attempts = 0;
    await expectLater(
      EdgeTtsRetry.run(
        generate: () async {
          attempts++;
          throw StateError('voce non selezionata');
        },
        isActive: () => true,
        retryDelays: const [Duration.zero],
      ),
      throwsStateError,
    );
    expect(attempts, 1);
  });

  test('Stop annulla i tentativi durante la pausa', () async {
    var active = true;
    var attempts = 0;
    final result = await EdgeTtsRetry.run(
      generate: () async {
        attempts++;
        throw TimeoutException('WebSocket non risponde');
      },
      isActive: () => active,
      onRetry: (retry, delay, error) { active = false; },
      retryDelays: const [Duration(milliseconds: 400)],
    );
    expect(result, isNull);
    expect(attempts, 1);
  });

  test('audio vuoto e timeout sono recuperabili, annullamento no', () {
    expect(EdgeTtsRetry.isTransient(Exception('audio vuoto')), isTrue);
    expect(EdgeTtsRetry.isTransient(TimeoutException('timeout')), isTrue);
    expect(EdgeTtsRetry.isTransient(Exception('403 Forbidden')), isTrue);
    expect(EdgeTtsRetry.isTransient(Exception('503 Service Unavailable')), isTrue);
    expect(EdgeTtsRetry.isTransient(StateError('AUDIO_DESCRIPTION_CANCELLED')),
        isFalse);
  });
}