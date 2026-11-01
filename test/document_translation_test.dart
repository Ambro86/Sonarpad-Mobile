import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/screens/document_translation_screen.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:sonarpad_mobile_starter/services/news_translation_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

class TranslationPaths extends PathProviderPlatform {
  TranslationPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory work;
  late PathProviderPlatform previous;
  late DocumentLibraryService library;
  late DocumentItem source;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    work = await Directory.systemTemp.createTemp('sonarpad-translation-');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TranslationPaths(work.path);
    library = DocumentLibraryService();
    final folder = await library.createFolder('Books');
    await library.add(folder);
    source = await library.createTextDocument(
      name: 'Book.txt',
      content: 'Original text.',
      parentId: folder.id,
    );
    await library.add(source);
  });
  tearDown(() async {
    PathProviderPlatform.instance = previous;
    await work.delete(recursive: true);
  });

  test(
    'new translations preserve source and folder, avoid collisions and persist partial warning',
    () async {
      Future<DocumentItem> save(bool partial) => saveDocumentTranslation(
        library: library,
        source: source,
        result: NewsTranslation(
          title: '',
          text: 'Testo tradotto.',
          isPartial: partial,
        ),
        suffix: 'tradotto',
        partialNotice: 'Traduzione parziale',
      );
      final first = await save(false);
      final second = await save(true);
      expect(first.name, 'Book_tradotto.txt');
      expect(second.path, isNot(first.path));
      expect(first.parentId, source.parentId);
      expect(second.parentId, source.parentId);
      expect(
        await File(await library.resolveFilePath(source)).readAsString(),
        'Original text.',
      );
      expect(
        await File(await library.resolveFilePath(second)).readAsString(),
        'Traduzione parziale\n\nTesto tradotto.',
      );
      final reloaded = DocumentLibraryService();
      await reloaded.load();
      expect(reloaded.documents.any((d) => d.id == second.id), isTrue);
    },
  );

  test('empty result creates no document', () async {
    final before = library.documents.length;
    await expectLater(
      saveDocumentTranslation(
        library: library,
        source: source,
        result: const NewsTranslation(title: '', text: ''),
        suffix: 'translated',
        partialNotice: 'Partial',
      ),
      throwsStateError,
    );
    expect(library.documents.length, before);
  });

  Future<void> screen(
    WidgetTester tester,
    NewsTranslationService Function() factory,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DocumentTranslationScreen(
          document: source,
          library: library,
          loadText: () async => '${'a' * 1500}. Second sentence.',
          createTranslator: factory,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'accessible language slider, progress, cancellation and no late save',
    (tester) async {
      final pending = Completer<http.Response>();
      await screen(
        tester,
        () => NewsTranslationService(client: MockClient((_) => pending.future)),
      );
      final list = tester.widget<UniversalAccessibleList>(
        find.byType(UniversalAccessibleList),
      );
      final slider = list.sections
          .expand((s) => s.rows)
          .singleWhere((r) => r.id == 'translation_language');
      expect(slider.kind, 'slider');
      expect(slider.valueLabel, 'Italiano');
      slider.onValueChanged!('1');
      await tester.pump();
      await tester.tap(find.text('Avvia traduzione'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pump();
      pending.complete(http.Response(jsonEncode(['Translation', null]), 200));
      await tester.pumpAndSettle();
      expect(find.text('Avvia traduzione'), findsOneWidget);
      expect(
        library.documents.where((d) => d.name.contains('tradotto')),
        isEmpty,
      );
    },
  );

  test('documents expose the same translate action visually and to VoiceOver', () {
    final code = File('lib/screens/documents_screen.dart').readAsStringSync();
    expect(
      code,
      contains(
        "AccessibleCustomAction(id: 'translate', label: l10n.translateDocument)",
      ),
    );
    expect(
      code,
      contains(
        "AccessibleVisualAction(id: 'translate', label: l10n.translateDocument",
      ),
    );
    expect(
      code,
      contains('CustomSemanticsAction(label: l10n.translateDocument)'),
    );
    expect(code, contains('ExcludeSemantics(child: IconButton('));
    expect(code, contains('!await _authorizeDocumentOpen(doc)'));
  });
}
