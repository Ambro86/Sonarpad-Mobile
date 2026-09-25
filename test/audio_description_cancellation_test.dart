import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/create_ai_audiodescription_screen.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'package:sonarpad_mobile_starter/services/pyannote_mobile_service.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_bridge.dart';

class _PendingClient extends http.BaseClient {
  final response = Completer<http.StreamedResponse>();
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      response.future;
  @override
  void close() {
    closed = true;
    if (!response.isCompleted) {
      response.completeError(http.ClientException('closed'));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cancel closes an in-flight HTTP request', () async {
    final client = _PendingClient();
    final service = AiAudioDescriptionService(httpClient: client);
    final result = service.fetchGeminiModels('test-key');
    final expectation = expectLater(
      result,
      throwsA(isA<http.ClientException>()),
    );
    service.cancel();
    await expectation;
    expect(client.closed, isTrue);
    service.dispose();
  });

  test('cancelled Edge synthesis never starts another request', () async {
    final bridge = EdgeTtsBridge()..cancel();
    await expectLater(
      bridge.speakToFile(text: 'test'),
      throwsA(isA<StateError>()),
    );
  });

  test('Pyannote honors cancellation before loading the model', () async {
    final cancelled = StateError('cancelled');
    await expectLater(
      PyannoteMobileService.instance.analyzeCanonicalWav(
        'unused.wav',
        checkCancelled: () => throw cancelled,
      ),
      throwsA(same(cancelled)),
    );
  });

  for (final locale in ['it', 'en']) {
    testWidgets('cancellation requires explicit Yes in $locale', (
      tester,
    ) async {
      bool? decision;
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return TextButton(
                onPressed: () async {
                  decision = await showAudioDescriptionCancelConfirmation(
                    context,
                  );
                },
                child: const Text('start'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.audioDescriptionCancelConfirmation),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.no));
      await tester.pumpAndSettle();
      expect(decision, isFalse);
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.yes));
      await tester.pumpAndSettle();
      expect(decision, isTrue);
    });
  }
}
