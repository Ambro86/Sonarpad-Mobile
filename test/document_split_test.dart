import 'dart:io';
import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/screens/document_split_screen.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalPaths = PathProviderPlatform.instance;
  late Directory work;
  late DocumentLibraryService library;
  late DocumentItem source;
  const text = 'A👨‍👩‍👧‍👦B\nC🇮🇹D';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    work = await Directory.systemTemp.createTemp('document-split-');
    PathProviderPlatform.instance = _Paths(work.path);
    library = DocumentLibraryService();
    final folder = await library.createFolder('Books');
    source = await library.createTextDocument(
      name: 'Notes.txt',
      content: text,
      parentId: folder.id,
    );
    await library.add(source);
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await work.delete(recursive: true);
  });

  for (final viaButton in [false, true]) {
    testWidgets('closed document opens split via ${viaButton ? "button" : "custom action"}', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DocumentsScreen(folderId: source.parentId),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pumpAndSettle();
      final list = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
      final row = list.sections.expand((s) => s.rows).singleWhere((r) => r.id == source.id);
      expect(row.actions.singleWhere((a) => a.id == 'split_document').label, 'Dividi documento');
      expect(row.visualActions.singleWhere((a) => a.id == 'split_document').label, 'Dividi documento');
      await tester.runAsync(() async {
        if (viaButton) {
          final button = find.byTooltip('Dividi documento');
          expect(find.ancestor(of: button, matching: find.byType(ExcludeSemantics)), findsWidgets);
          await tester.ensureVisible(button);
          await tester.tap(button);
        } else {
          unawaited(Future<void>.value(list.onEvent!(AccessibleListEvent(
            type: 'customAction', id: source.id, action: 'split_document'))));
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(tester.widget<DocumentSplitScreen>(find.byType(DocumentSplitScreen)).text, text);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  Future<List<String>> readParts() async {
    final reopened = DocumentLibraryService();
    await reopened.load();
    final docs = reopened.documents.where(
      (d) => d.parentId == source.parentId && d.id != source.id,
    );
    expect(
      await File(await reopened.resolveFilePath(source)).readAsString(),
      text,
    );
    return Future.wait(
      docs.map(
        (d) async => File(await reopened.resolveFilePath(d)).readAsString(),
      ),
    );
  }

  for (final entry in [
    (true, 3, [3, 2, 2]),
    (false, 3, [3, 3, 1]),
    (true, 1, [7]),
    (false, 10000, [7]),
  ]) {
    test(
      'save to Documents and reopen: byParts=${entry.$1}, value=${entry.$2}',
      () async {
        await library.saveSplitDocument(
          source,
          text,
          byParts: entry.$1,
          value: entry.$2,
        );
        final parts = await readParts();
        expect(parts.map((s) => s.characters.length), entry.$3);
        expect(parts.join(), text);
      },
    );
  }
  test(
    'invalid counts create no files; repeated splits preserve earlier files',
    () async {
      for (final n in [0, -1, 8]) {
        await expectLater(
          library.saveSplitDocument(source, text, byParts: true, value: n),
          throwsArgumentError,
        );
      }
      expect(await readParts(), isEmpty);
      for (var i = 0; i < 2; i++) {
        await library.saveSplitDocument(source, text, byParts: true, value: 2);
      }
      expect((await readParts()).join(), text + text);
    },
  );

  testWidgets(
    'accessible adjustments stay independent and a custom split saves files',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<int>(
                  builder: (_) =>
                      DocumentSplitScreen(document: source, text: text),
                ),
              ),
              child: const Text('Apri'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      int node(String label) =>
          tester.getSemantics(find.bySemanticsLabel(label)).id;
      Future<void> adjust(String label, SemanticsAction action) async {
        final id = node(label);
        tester.semantics.performAction(find.semantics.byLabel(label), action);
        await tester.pumpAndSettle();
        expect(node(label), id);
      }

      const mode = 'Metodo di divisione';
      const parts = 'Numero di parti';
      const chars = 'Caratteri per parte';
      await adjust(parts, SemanticsAction.increase);
      expect(tester.getSemantics(find.bySemanticsLabel(parts)).value, '3');
      await adjust(mode, SemanticsAction.increase);
      for (var i = 0; i < 7; i++) {
        await adjust(chars, SemanticsAction.increase);
      }
      await tester.enterText(find.byType(TextField), '3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await adjust(mode, SemanticsAction.decrease);
      expect(tester.getSemantics(find.bySemanticsLabel(parts)).value, '3');
      for (var i = 3; i <= 10; i++) {
        await adjust(parts, SemanticsAction.increase);
      }
      await tester.enterText(find.byType(TextField), '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await adjust(mode, SemanticsAction.increase);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '3',
      );
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ListTile, 'Dividi documento'));
        for (var i = 0; i < 100 && (await readParts()).length != 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(await readParts(), ['A👨‍👩‍👧‍👦B', '\nC🇮🇹', 'D']);
      });
      await tester.pumpAndSettle();
      expect(find.text('Apri'), findsOneWidget);
    },
  );
}
