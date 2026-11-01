import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/news_webview_screen.dart';
import 'package:sonarpad_mobile_starter/services/news_translation_service.dart';

http.Response translation(String text) => http.Response(
  jsonEncode([
    null,
    [
      [text],
    ],
    null,
  ]),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('sentence chunks preserve text, long sentences, Unicode and URLs', () {
    final text =
        'A decimal 3.14 and https://example.com/path.\n'
        '"Another sentence!" Next: ${'è' * 1600}? Last sentence';
    final chunks = NewsTranslationService.splitSentences(text, maxChars: 30);
    expect(chunks.join(), text);
    expect(chunks.first, contains('https://example.com/path.'));
    expect(chunks.any((c) => c.contains('è' * 1600)), isTrue);
    for (final c in chunks.take(chunks.length - 1)) {
      expect(RegExp(r'''[.:?!]["']?$''').hasMatch(c), isTrue);
    }
    expect(
      NewsTranslationService.splitSentences('no punctuation', maxChars: 2),
      ['no punctuation'],
    );
    expect(NewsTranslationService.splitSentences(''), ['']);
  });

  test(
    'translates title and every block, keeps whitespace and selects UI language',
    () async {
      final requests = <String>[];
      final service = NewsTranslationService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['query.source_language'], 'auto');
          expect(request.url.queryParameters['query.target_language'], 'fr');
          expect(request.url.queryParametersAll['data_types'], [
            'TRANSLATION',
            'SENTENCE_SPLITS',
          ]);
          final text = request.url.queryParameters['query.text']!;
          requests.add(text);
          return translation('Traduit ${requests.length}');
        }),
      );
      addTearDown(service.close);
      final text = '${'a' * 1499}.\n\nSecond sentence.  ';
      final progress = <int>[];
      final result = await service.translateArticle(
        title: 'Title',
        text: text,
        targetLanguage: 'fr-FR',
        onProgress: (done, total) {
          expect(total, 3);
          progress.add(done);
        },
      );
      expect(requests, ['Title', '${'a' * 1499}.', '\n\nSecond sentence.  ']);
      expect(result.title, 'Traduit 1');
      expect(result.text, 'Traduit 2\n\nTraduit 3  ');
      expect(result.isPartial, isFalse);
      expect(progress, [0, 1, 2, 3]);
    },
  );

  test(
    'failure of a later block preserves a clearly marked partial article',
    () async {
      var calls = 0;
      final service = NewsTranslationService(
        client: MockClient((request) async {
          calls++;
          return calls == 3
              ? http.Response('unavailable', 503)
              : translation('testo');
        }),
      );
      addTearDown(service.close);
      final progress = <int>[];
      final result = await service.translateArticle(
        title: 'Title',
        text: '${'a' * 1500}. Last.',
        targetLanguage: 'it',
        onProgress: (done, total) => progress.add(done),
      );
      expect(calls, 3);
      expect(result.isPartial, isTrue);
      expect(result.title, 'testo');
      expect(result.text, 'testo');
      expect(progress, [0, 1, 2]);
    },
  );

  test(
    'first request failure still reports error rather than an empty translation',
    () async {
      final service = NewsTranslationService(
        client: MockClient((_) async => http.Response('', 503)),
      );
      addTearDown(service.close);
      await expectLater(
        service.translateArticle(
          title: 'Title',
          text: 'Body.',
          targetLanguage: 'it',
        ),
        throwsStateError,
      );
    },
  );

  test(
    'timeout after the title retains it and marks partial even with empty body',
    () async {
      var calls = 0;
      final service = NewsTranslationService(
        client: MockClient((_) async {
          if (++calls == 1) return translation('Titolo');
          throw TimeoutException('test');
        }),
      );
      addTearDown(service.close);
      final result = await service.translateArticle(
        title: 'Title',
        text: 'Body.',
        targetLanguage: 'it',
      );
      expect(result.isPartial, isTrue);
      expect(result.title, 'Titolo');
      expect(result.text, isEmpty);
    },
  );

  testWidgets(
    'translation progress has a determinate accessible bar and working cancel',
    (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: NewsTranslationProgressView(
              progress: 0.5,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
      expect(bar.semanticsValue, '50%');
      await tester.tap(find.text('Annulla'));
      expect(cancelled, isTrue);
    },
  );

  testWidgets(
    'partial article warning remains visible even when only title succeeded',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: NewsArticleReaderView(
                title: 'Titolo',
                text: '',
                mediaLinks: const [],
                onOpenMediaLink: (_) async {},
                notice: AppLocalizations.of(context).newsTranslationPartial,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Traduzione parziale:'), findsOneWidget);
    },
  );

  test(
    'cancel does not dispatch more requests or return late results',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final service = NewsTranslationService(
        client: MockClient((request) {
          calls++;
          return pending.future;
        }),
      );
      final result = service.translateArticle(
        title: 'Title',
        text: 'Article.',
        targetLanguage: 'it',
      );
      final check = expectLater(result, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      service.close();
      pending.complete(translation('Titolo'));
      await check;
      expect(calls, 1);
    },
  );

  test('validates Google responses without omitting malformed segments', () {
    expect(NewsTranslationService.parseTranslation(['Ciao', null]), 'Ciao');
    expect(
      NewsTranslationService.parseTranslation([
        null,
        [
          ['Ciao '],
          ['mondo'],
        ],
      ]),
      'Ciao mondo',
    );
    for (final value in [
      null,
      [],
      [null, []],
      [
        null,
        [
          ['valid'],
          [4],
        ],
      ],
    ]) {
      expect(
        () => NewsTranslationService.parseTranslation(value),
        throwsFormatException,
      );
    }
  });

  for (final locale in [
    const Locale('it'),
    const Locale('fr'),
    const Locale('en'),
  ]) {
    testWidgets('reader keeps translation controls out of the article: $locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: NewsArticleReaderView(
                title: 'Article title',
                text: 'Article paragraph.',
                mediaLinks: const [],
                onOpenMediaLink: (_) async {},

              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = {
        'it': 'Traduci in italiano',
        'fr': 'Traduire en français',
        'en': 'Translate into English',
      }[locale.languageCode]!;
      expect(find.text(label), findsNothing);
      expect(find.text('Article paragraph.'), findsOneWidget);
    });
  }
}
