import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:sonarpad_mobile_starter/services/rar_document_archive.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/screens/document_reader_screen.dart';

class RarPaths extends PathProviderPlatform {
  RarPaths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory work;
  late DocumentLibraryService service;
  late PathProviderPlatform original;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    work = await Directory.systemTemp.createTemp('sonarpad-rar-test-');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = RarPaths(work.path);
    service = DocumentLibraryService();
  });
  tearDown(() async {
    PathProviderPlatform.instance = original;
    await work.delete(recursive: true);
  });
  File fixture(String name) => File('test/fixtures/rar/$name').absolute;

  for (final format in ['rar4', 'rar5', 'solid']) {
    test('$format imports nested documents, Unicode, media and empty folders', () async {
      final root = await service.importRar(fixture('$format.rar'), folderName: 'Books');
      final children = service.documents.where((d) => d.parentId == root.id);
      expect(children.map((d) => d.name), containsAll(['notes.txt', 'Sub', 'Empty']));
      expect(service.documents.where((d) => d.name == 'notes.txt'), hasLength(2));
      final audio = service.documents.singleWhere((d) => d.name == 'Città.mp3');
      expect(await File(await service.resolveFilePath(audio)).readAsBytes(), [0, 255, 4, 1]);
      final text = children.singleWhere((d) => d.name == 'notes.txt');
      expect(await File(await service.resolveFilePath(text)).readAsString(),
        'Sonarpad RAR test: caffè e città.');
    });
  }
  test('password errors leave no documents; correct password extracts', () async {
    for (final password in [null, 'wrong']) {
      await expectLater(service.importRar(fixture('password.rar'), password: password),
        throwsA(predicate<Object>(RarDocumentArchive.needsPassword)));
      expect(service.documents, isEmpty);
    }
    await service.importRar(fixture('password.rar'), password: 'test-password');
    expect(service.documents.any((d) => d.name == 'notes.txt'), isTrue);
  });
  test('saved RAR reuses extracted folder after reload and retains original', () async {
    final saved = await service.importFile(fixture('rar5.rar'));
    await service.add(saved);
    final folder = await service.openRar(saved);
    final count = service.documents.length;
    final reloaded = DocumentLibraryService();
    expect((await reloaded.openRar(saved)).id, folder.id);
    expect(reloaded.documents, hasLength(count));
    expect(await File(await reloaded.resolveFilePath(saved)).exists(), isTrue);
  });
  test('corrupt RAR does not create a phantom folder', () async {
    final bad = await File('${work.path}/bad.rar').writeAsString('not an archive');
    await expectLater(service.importRar(bad), throwsA(anything));
    expect(service.documents, isEmpty);
  });

  test('RAR traversal path is rejected before extracting any files', () async {
    await expectLater(service.importRar(fixture('unsafe.rar')), throwsFormatException);
    expect(service.documents, isEmpty);
    expect(await work.list().toList(), isEmpty);
  });

  testWidgets('shared RAR opens its document folder, never the text reader', (tester) async {
    await tester.runAsync(() async {
      final saved = await service.importFile(fixture('rar5.rar'));
      await service.add(saved);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DocumentsScreen(initialArchive: saved),
      ));
    });
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 30));
      if (tester.widgetList<DocumentsScreen>(find.byType(DocumentsScreen))
          .any((screen) => screen.folderId != null)) {
        break;
      }
    }
    await tester.pumpAndSettle();
    expect(find.byType(DocumentReaderScreen), findsNothing);
    expect(tester.widget<DocumentsScreen>(find.byType(DocumentsScreen)).folderId, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
