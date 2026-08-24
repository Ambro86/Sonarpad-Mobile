import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';

DocumentItem _folder() => DocumentItem(
      id: 'folder_test',
      name: 'Cartella test',
      path: '',
      extension: 'folder',
      addedAt: DateTime(2026, 8, 24),
      isFolder: true,
    );

DocumentItem _document({String? parentId}) => DocumentItem(
      id: 'document_test',
      name: 'Documento test',
      path: 'saved:librivox:test',
      // Librivox è un elemento di libreria virtuale: consente di verificare la
      // persistenza senza dipendere da path_provider nel test.
      extension: 'librivox',
      addedAt: DateTime(2026, 8, 24),
      parentId: parentId,
    );

void main() {
  group('Document folder persistence', () {
    test('a stale metadata update cannot move a document back to root',
        () async {
      SharedPreferences.setMockInitialValues({});

      final firstScreen = DocumentLibraryService();
      final folder = _folder();
      await firstScreen.add(folder);
      await firstScreen.add(_document(parentId: folder.id));

      // Simula una route rimasta con un DocumentItem vecchio, precedente allo
      // spostamento/importazione nella cartella.
      final staleScreen = DocumentLibraryService();
      await staleScreen.update(_document(parentId: null));

      final afterRestart = DocumentLibraryService();
      await afterRestart.load();
      final document =
          afterRestart.documents.firstWhere((item) => item.id == 'document_test');
      expect(document.parentId, folder.id);
    });

    test('explicit move to root remains persistent', () async {
      SharedPreferences.setMockInitialValues({});

      final service = DocumentLibraryService();
      final folder = _folder();
      await service.add(folder);
      await service.add(_document(parentId: folder.id));

      await service.moveToFolder('document_test', null);

      final afterRestart = DocumentLibraryService();
      await afterRestart.load();
      final document =
          afterRestart.documents.firstWhere((item) => item.id == 'document_test');
      expect(document.parentId, isNull);
    });

    test('a stale reorder cannot delete documents added by another screen',
        () async {
      SharedPreferences.setMockInitialValues({});

      final rootScreen = DocumentLibraryService();
      final folder = _folder();
      await rootScreen.add(folder);
      final staleOrder = List<DocumentItem>.from(rootScreen.documents);

      final folderScreen = DocumentLibraryService();
      await folderScreen.add(_document(parentId: folder.id));

      await rootScreen.saveAll(staleOrder);

      final afterRestart = DocumentLibraryService();
      await afterRestart.load();
      expect(
        afterRestart.documents.map((item) => item.id),
        containsAll(<String>['folder_test', 'document_test']),
      );
      expect(
        afterRestart.documents
            .firstWhere((item) => item.id == 'document_test')
            .parentId,
        folder.id,
      );
    });
  });
}
