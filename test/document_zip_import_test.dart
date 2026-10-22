import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/screens/document_reader_screen.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:sonarpad_mobile_starter/services/document_folder_export_service.dart';

class ZipPaths extends PathProviderPlatform {
  ZipPaths(this.root);
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
    work = await Directory.systemTemp.createTemp('sonarpad-zip-test-');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = ZipPaths(work.path);
    service = DocumentLibraryService();
  });
  tearDown(() async {
    PathProviderPlatform.instance = original;
    await work.delete(recursive: true);
  });
  Future<File> zip(List<ArchiveFile> files) async {
    final archive = Archive();
    for (final file in files) { archive.addFile(file); }
    return File('${work.path}/Books.zip').writeAsBytes(ZipEncoder().encode(archive)!);
  }

  test('exported folder opens with audio, video, Unicode and empty subfolders', () async {
    final media = await File('${work.path}/source').writeAsBytes([0, 255, 4]);
    final output = '${work.path}/Books.zip';
    await DocumentFolderExportService.writeZip(output, [
      (name: 'Books', source: null),
      (name: 'Books/Empty', source: null),
      (name: 'Books/Sub/Città.mp3', source: media.path),
      (name: 'Books/Film.mp4', source: media.path),
      (name: 'Books/project.json', source: media.path),
    ]);
    final saved = await service.importFile(File(output));
    await service.add(saved);
    final folder = await service.openZip(saved);
    expect(folder.parentId, saved.id);
    final children = service.documents.where((d) => d.parentId == folder.id).toList();
    expect(children.map((d) => d.name), containsAll(['Empty', 'Sub', 'Film.mp4', 'project.json']));
    expect(children.any((d) => d.name == 'Books'), isFalse);
    final audio = service.documents.singleWhere((d) => d.name == 'Città.mp3');
    final sub = children.singleWhere((d) => d.name == 'Sub');
    expect(audio.parentId, sub.id);
    expect(await File(await service.resolveFilePath(audio)).readAsBytes(), [0, 255, 4]);
    final count = service.documents.length;
    final reloaded = DocumentLibraryService();
    expect((await reloaded.openZip(saved)).id, folder.id);
    expect(reloaded.documents.length, count);
    expect(await File(await reloaded.resolveFilePath(saved)).exists(), isTrue);
    await reloaded.remove(saved.id);
    expect(reloaded.documents, isEmpty);
  });

  test('external archives preserve nested duplicate names and all media', () async {
    final archive = await zip([
      ArchiveFile('a/song.mp3', 1, [1]),
      ArchiveFile('b/song.mp3', 1, [2]),
      ArchiveFile('clip.mp4', 1, [3]),
      ArchiveFile('notes.txt', 1, [4]),
      ArchiveFile('empty/', 0, <int>[])..isFile = false,
    ]);
    final folder = await service.importZip(archive);
    final songs = service.documents.where((d) => d.name == 'song.mp3').toList();
    expect(songs, hasLength(2));
    expect(songs[0].parentId, isNot(songs[1].parentId));
    expect(await File(await service.resolveFilePath(songs[0])).readAsBytes(), [1]);
    expect(await File(await service.resolveFilePath(songs[1])).readAsBytes(), [2]);
    expect(service.documents.where((d) => d.parentId == folder.id).length, 5);
  });

  for (final path in ['../escape.txt', '/escape.txt', r'C:\escape.txt', r'a\..\escape.txt']) {
    test('reject unsafe archive path $path without creating a folder', () async {
      final archive = await zip([ArchiveFile(path, 1, [1])]);
      await expectLater(service.importZip(archive), throwsFormatException);
      await service.load();
      expect(service.documents, isEmpty);
    });
  }
  test('corrupt ZIP cannot create a phantom folder', () async {
    final file = await File('${work.path}/bad.zip').writeAsString('not a zip');
    await expectLater(service.importZip(file), throwsA(anything));
    expect(service.documents, isEmpty);
  });
  testWidgets('opening a saved ZIP navigates to Documents, never the reader', (tester) async {
    late String id;
    await tester.runAsync(() async {
      final archive = await zip([ArchiveFile('notes.txt', 4, [116, 101, 115, 116])]);
      final saved = await service.importFile(archive);
      await service.add(saved);
      id = saved.id;
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DocumentsScreen(),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    final list = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
    unawaited(Future<void>.value(list.onEvent!(AccessibleListEvent(type: 'activate', id: id))));
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 30));
      if (tester.widgetList<DocumentsScreen>(find.byType(DocumentsScreen)).any((s) => s.folderId != null) && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    expect(find.byType(DocumentReaderScreen), findsNothing);
    expect(tester.widget<DocumentsScreen>(find.byType(DocumentsScreen)).folderId, isNotNull);
    final contents = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
    expect(contents.sections.expand((s) => s.rows).any((r) => r.title.contains('notes')), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

}
