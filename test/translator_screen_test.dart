import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/translator_screen.dart';
import 'package:sonarpad_mobile_starter/services/news_translation_service.dart';
import 'package:sonarpad_mobile_starter/services/home_customization_service.dart';
import 'package:sonarpad_mobile_starter/utils/home_item_catalog.dart';
import 'package:sonarpad_mobile_starter/services/cloud_file_picker_service.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'package:sonarpad_mobile_starter/widgets/document_password_dialog.dart';

class TranslationTestLibrary extends DocumentLibraryService {
  @override
  Future<void> load() async {}
  @override
  List<DocumentItem> get documents => [
    for (final ext in ['txt', 'mp3', 'zip'])
      DocumentItem(
        id: ext,
        name: 'Example.$ext',
        path: 'unused',
        extension: ext,
        addedAt: DateTime(2026),
      ),
    DocumentItem(
      id: 'protected',
      name: 'Protected.txt',
      path: 'unused',
      extension: 'txt',
      addedAt: DateTime(2026),
      passwordSalt: 'salt',
      passwordHash: 'hash',
    ),
  ];
}

Widget app(Widget home) => MaterialApp(
  locale: const Locale('it'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
);

void main() {
  testWidgets('result updates stable rows for both complete and partial text', (
    tester,
  ) async {
    for (final partial in [false, true]) {
      await tester.pumpWidget(
        app(
          TranslatorResultScreen(
            key: ValueKey(partial),
            original: 'Original text.',
            translation: NewsTranslation(
              title: '',
              text: 'Testo tradotto.',
              isPartial: partial,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final resultFinder = find.byType(UniversalAccessibleList);
      final state = tester.state(resultFinder);
      List<AccessibleListRow> rows() => tester
          .widget<UniversalAccessibleList>(resultFinder)
          .sections
          .expand((s) => s.rows)
          .toList();
      final structure = rows().map((r) => '${r.id}:${r.kind}').toList();
      expect(find.text('Risultato della traduzione'), findsOneWidget);
      expect(
        rows().where((r) => r.title.contains('Risultato della traduzione')),
        isEmpty,
      );
      for (final value in ['1', '0', '1', '0']) {
        await Future<void>.sync(() => rows().first.onValueChanged!(value));
        await tester.pump();
        expect(tester.state(resultFinder), same(state));
        expect(rows().map((r) => '${r.id}:${r.kind}'), structure);
        expect(rows().first.value, value);
        expect(
          rows()[1].title,
          contains(value == '0' ? 'Testo tradotto.' : 'Original text.'),
        );
        expect(
          rows()[1].title.contains('Traduzione parziale:'),
          partial && value == '0',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'library picker filters non-text files and asks for protected document password',
    (tester) async {
      await tester.pumpWidget(
        app(TranslationDocumentPickerScreen(library: TranslationTestLibrary())),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<UniversalAccessibleList>(
        find.byType(UniversalAccessibleList),
      );
      final rows = list.sections.expand((s) => s.rows).toList();
      expect(rows.map((r) => r.id), containsAll(['txt', 'protected']));
      expect(rows.map((r) => r.id), isNot(contains('mp3')));
      expect(rows.map((r) => r.id), isNot(contains('zip')));
      unawaited(
        Future<void>.sync(
          rows.singleWhere((r) => r.id == 'protected').onActivate!,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DocumentPasswordDialog), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.byType(TranslationDocumentPickerScreen), findsOneWidget);
    },
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('translator is available internationally in both home modes', () {
    expect(HomeItemIds.defaultFlatOrder, contains(HomeItemIds.translator));
    expect(HomeItemIds.readingOrder, contains(HomeItemIds.translator));
    expect(
      availableHomeItemIds(
        isItalian: false,
        isTvCodeValid: false,
        isRaiPlayValid: false,
        isRaiPlaySoundCodeValid: false,
      ),
      contains(HomeItemIds.translator),
    );
  });
  testWidgets(
    'full flow sends chosen languages and shows ONLY result controls',
    (tester) async {
      final seen = <Uri>[];
      await tester.pumpWidget(
        app(
          TranslatorScreen(
            createTranslator: () => NewsTranslationService(
              client: MockClient((request) async {
                seen.add(request.url);
                return http.Response(jsonEncode(['Ciao mondo.', null]), 200);
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final source = tester
          .widgetList<TranslationChoiceSlider>(
            find.byType(TranslationChoiceSlider),
          )
          .first;
      expect(source.value, 0);
      source.onChanged(2); // English, after Auto and Italian.
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Hello world.');
      await tester.ensureVisible(find.text('Avvia traduzione'));
      await tester.tap(find.text('Avvia traduzione'));
      await tester.pumpAndSettle();
      expect(seen.single.queryParameters['query.source_language'], 'en');
      expect(seen.single.queryParameters['query.target_language'], 'it');
      expect(find.byType(TranslatorResultScreen), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Scegli file'), findsNothing);
      expect(find.text('Avvia traduzione'), findsNothing);
      expect(find.byType(TranslationChoiceSlider), findsOneWidget);
      expect(find.text('Ciao mondo.'), findsOneWidget);
      final toggle = tester.widget<TranslationChoiceSlider>(
        find.byType(TranslationChoiceSlider),
      );
      expect(toggle.value, 0);
      toggle.onChanged(1);
      await tester.pump();
      expect(find.text('Hello world.'), findsOneWidget);
      expect(find.text('Ciao mondo.'), findsNothing);
      await tester.tap(find.text('Salva traduzione'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Salva in Sonarpad'), findsOneWidget);
      expect(find.text('Condividi'), findsNWidgets(2));
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('separate progress screen cancels and ignores late completion', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await tester.pumpWidget(
      app(
        TranslatorScreen(
          createTranslator: () =>
              NewsTranslationService(client: MockClient((_) => pending.future)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello.');
    await tester.ensureVisible(find.text('Avvia traduzione'));
    await tester.tap(find.text('Avvia traduzione'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TranslatorProgressScreen), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Annulla'));
    pending.complete(http.Response(jsonEncode(['Ciao.', null]), 200));
    await tester.pumpAndSettle();
    expect(find.byType(TranslatorResultScreen), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
    'partial errors open the result instead of discarding translated text',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        app(
          TranslatorScreen(
            createTranslator: () => NewsTranslationService(
              client: MockClient(
                (_) async => ++calls == 1
                    ? http.Response(jsonEncode(['Prima parte.', null]), 200)
                    : http.Response('', 503),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        '${'a' * 1500}. Second sentence.',
      );
      await tester.ensureVisible(find.text('Avvia traduzione'));
      await tester.tap(find.text('Avvia traduzione'));
      await tester.pumpAndSettle();
      expect(find.byType(TranslatorResultScreen), findsOneWidget);
      expect(find.text('Prima parte.'), findsOneWidget);
      expect(find.textContaining('Traduzione parziale:'), findsOneWidget);
    },
  );

  test(
    'file import reuses the existing cloud picker and password-aware extractor',
    () {
      final source = File(
        'lib/screens/translator_screen.dart',
      ).readAsStringSync();
      expect(source, contains('CloudFilePicker.pickFiles('));
      expect(source, contains('DocumentPasswordDialog('));
      expect(source, contains('DocumentTextExtractor()'));
    },
  );

  testWidgets(
    'choosing a real text file loads its complete contents in the input',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'translator-input-',
      );
      final file = File('${directory.path}/Article.txt')
        ..writeAsStringSync('First paragraph.\nSecond paragraph.');
      CloudFilePicker.debugUseNativePicker = true;
      const commands = MethodChannel('sonarpad/cloud_file_picker');
      const events = MethodChannel('sonarpad/cloud_file_picker_progress');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(
        commands,
        (_) async => [
          {'path': file.path, 'name': 'Article.txt', 'size': 34},
        ],
      );
      addTearDown(() async {
        CloudFilePicker.debugUseNativePicker = null;
        messenger.setMockMethodCallHandler(commands, null);
        messenger.setMockMethodCallHandler(events, null);
        await directory.delete(recursive: true);
      });
      await tester.pumpWidget(app(const TranslatorScreen()));
      await tester.pumpAndSettle();
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Scegli file'),
      );
      late Future<void> opening;
      await tester.runAsync(() async {
        opening = (button.onPressed! as dynamic)() as Future<void>;
      });
      await tester.pumpAndSettle();
      expect(find.text('Documenti · Sonarpad'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Sfoglia…'));
        await opening;
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'First paragraph.\nSecond paragraph.',
      );
      expect(find.text('Article.txt'), findsOneWidget);
    },
  );
}
