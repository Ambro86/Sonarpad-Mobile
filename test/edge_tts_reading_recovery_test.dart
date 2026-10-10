import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_retry.dart';

void main() {
  test('RustNotepad filter rejects separators and keeps Unicode text', () {
    for (final text in ['', '  ', '|', '...?!', '— | •', '😀']) {
      expect(EdgeTtsRetry.isTextUsable(text), isFalse, reason: text);
    }
    for (final text in [
      'ciao.',
      '8:26',
      'è',
      '中文',
      'العربية',
      'Русский',
      '１２',
    ]) {
      expect(EdgeTtsRetry.isTextUsable(text), isTrue, reason: text);
    }
  });

  test('RustNotepad retry delays grow and remain capped', () {
    for (final message in [
      '403 Forbidden',
      'HTTP status code: 403',
      'connection reset',
      'os error 10054',
      'timeout',
    ]) {
      expect(
        EdgeTtsRetry.readingRetryDelay(message, 1),
        const Duration(milliseconds: 250),
      );
      expect(
        EdgeTtsRetry.readingRetryDelay(message, 2),
        const Duration(milliseconds: 500),
      );
      expect(
        EdgeTtsRetry.readingRetryDelay(message, 500),
        const Duration(seconds: 2),
      );
    }
    expect(
      EdgeTtsRetry.readingRetryDelay('audio vuoto', 1),
      const Duration(milliseconds: 400),
    );
    expect(
      EdgeTtsRetry.readingRetryDelay('audio vuoto', 500),
      const Duration(seconds: 2),
    );
  });

  testWidgets('reading survives 50 failures, preserving chunk order', (
    tester,
  ) async {
    final requests = <String>[];
    final queue = <String>[];
    var attempts = 0;
    var finished = false;
    final reading = () async {
      for (final text in [
        'prima frase',
        '|',
        'seconda frase',
        'ultima frase',
      ]) {
        if (!EdgeTtsRetry.isTextUsable(text)) continue;
        final file = await EdgeTtsRetry.run(
          retryUntilCancelled: true,
          generate: () async {
            requests.add(text);
            if (text == 'seconda frase' && ++attempts <= 50) {
              throw Exception(
                attempts.isEven
                    ? 'Edge TTS error: WebSocketException: HTTP status code: 403'
                    : 'Edge TTS ha restituito audio vuoto',
              );
            }
            return File('$text.mp3');
          },
          isActive: () => true,
        );
        queue.add(file!.path);
      }
      finished = true;
    }();
    await tester.pump();
    for (var i = 0; i < 51; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await reading;
    expect(finished, isTrue);
    expect(attempts, 51);
    expect(requests.where((text) => text == 'prima frase'), hasLength(1));
    expect(requests, isNot(contains('|')));
    expect(queue, ['prima frase.mp3', 'seconda frase.mp3', 'ultima frase.mp3']);
  });

  testWidgets('Stop cancels unlimited retries during backoff', (tester) async {
    var active = true;
    var attempts = 0;
    var finished = false;
    final reading =
        EdgeTtsRetry.run(
          retryUntilCancelled: true,
          generate: () async {
            attempts++;
            throw TimeoutException('timeout');
          },
          isActive: () => active,
        ).then((result) {
          expectSync(result, isNull);
          finished = true;
        });
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    expect(attempts, greaterThan(6));
    active = false;
    final stoppedAt = attempts;
    await tester.pump(const Duration(milliseconds: 100));
    expect(finished, isTrue);
    await tester.pump(const Duration(seconds: 10));
    expect(attempts, stoppedAt);
    await reading;
  });

  test('a late file from an old session is not queued', () async {
    var token = 1;
    final response = Completer<File>();
    final reading = EdgeTtsRetry.run(
      retryUntilCancelled: true,
      generate: () => response.future,
      isActive: () => token == 1,
    );
    token++;
    response.complete(File('old.mp3'));
    expect(await reading, isNull);
  });

  test(
    'unlimited retries still propagate permanent errors and cancellation',
    () async {
      for (final error in [
        StateError('voce non selezionata'),
        StateError('AUDIO_DESCRIPTION_CANCELLED'),
      ]) {
        var attempts = 0;
        await expectLater(
          EdgeTtsRetry.run(
            retryUntilCancelled: true,
            generate: () async {
              attempts++;
              throw error;
            },
            isActive: () => true,
          ),
          throwsA(same(error)),
        );
        expect(attempts, 1);
      }
    },
  );
}
