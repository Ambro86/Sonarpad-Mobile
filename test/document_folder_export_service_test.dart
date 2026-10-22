import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/services/document_folder_export_service.dart';

DocumentItem item(
  String id,
  String name, {
  String? parent,
  bool folder = false,
  String extension = 'txt',
  String path = '',
}) => DocumentItem(
  id: id,
  name: name,
  path: path,
  extension: folder ? 'folder' : extension,
  addedAt: DateTime(2026),
  isFolder: folder,
  parentId: parent,
);

void main() {
  test(
    'ZIP round trip keeps Unicode names, nested files, empty folders and bytes',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'sonarpad-folder-test-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final text = File('${dir.path}/internal-storage-id');
      await text.writeAsString('Caffè e musica 🎵');
      final media = File('${dir.path}/technical-media-id');
      await media.writeAsBytes([0, 1, 255, 17]);
      final root = item('root', 'I miei libri', folder: true);
      final docs = [
        root,
        item('sub', 'Viaggi', folder: true, parent: 'root'),
        item('empty', 'Vuota', folder: true, parent: 'sub'),
        item('text', 'Città.txt', parent: 'sub', path: text.path),
        item(
          'media',
          'Musica.mp3',
          extension: 'mp3',
          parent: 'root',
          path: media.path,
        ),
        item('outside', 'Fuori.txt', path: '${dir.path}/missing'),
      ];
      final plan = DocumentFolderExportService.plan(root, docs);
      final zip = File('${dir.path}/export.zip');
      await DocumentFolderExportService.writeZip(
        zip.path,
        plan
            .map(
              (e) => (
                name: e.archivePath,
                source: e.document.isFolder ? null : e.document.path,
              ),
            )
            .toList(),
      );
      final archive = ZipDecoder().decodeBytes(
        await zip.readAsBytes(),
        verify: true,
      );
      expect(
        archive.files.map((f) => f.name),
        containsAll([
          'I miei libri/',
          'I miei libri/Viaggi/',
          'I miei libri/Viaggi/Vuota/',
          'I miei libri/Viaggi/Città.txt',
          'I miei libri/Musica.mp3',
        ]),
      );
      expect(
        archive.files.any(
          (f) =>
              f.name.contains('Fuori') || f.name.contains('internal-storage'),
        ),
        isFalse,
      );
      expect(archive.findFile('I miei libri/Musica.mp3')!.content, [
        0,
        1,
        255,
        17,
      ]);
      expect(
        archive.findFile('I miei libri/Viaggi/Città.txt')!.content,
        await text.readAsBytes(),
      );
      expect(archive.findFile('I miei libri/Viaggi/Vuota/')!.isFile, isFalse);
    },
  );
  test('duplicate visible names do not overwrite files', () {
    final root = item('r', 'Root', folder: true);
    final plan = DocumentFolderExportService.plan(root, [
      item('a', 'Libro.txt', parent: 'r'),
      item('b', 'libro.txt', parent: 'r'),
      item('c', 'Libro (2).txt', parent: 'r'),
    ]);
    expect(
      plan.map((e) => e.archivePath.toLowerCase()).toSet().length,
      plan.length,
    );
  });
  test('unsafe names cannot escape the ZIP root', () {
    final root = item('r', '..', folder: true);
    final plan = DocumentFolderExportService.plan(root, [
      item('a', '../outside.txt', parent: 'r'),
    ]);
    expect(plan.every((e) => !e.archivePath.split('/').contains('..')), isTrue);
    expect(plan.last.archivePath, '_/.._outside.txt');
  });
  test('cyclic folder graph fails rather than recursing forever', () {
    final root = item('r', 'Root', folder: true, parent: 'c');
    expect(
      () => DocumentFolderExportService.plan(root, [
        root,
        item('c', 'Child', folder: true, parent: 'r'),
      ]),
      throwsA(FolderExportFailure.cyclicLibraryTree),
    );
  });
  test(
    'missing file fails instead of silently creating an incomplete export',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'sonarpad-folder-missing-',
      );
      addTearDown(() => dir.delete(recursive: true));
      await expectLater(
        DocumentFolderExportService.writeZip('${dir.path}/export.zip', [
          (name: 'Missing.txt', source: '${dir.path}/missing'),
        ]),
        throwsA(isA<FileSystemException>()),
      );
    },
  );
  test('export plan includes protected children for authorization', () {
    final root = item('r', 'Root', folder: true);
    final protected = item(
      'secret',
      'Private.txt',
      parent: 'r',
    ).copyWith(passwordSalt: 'salt', passwordHash: 'hash');
    final plan = DocumentFolderExportService.plan(root, [protected]);
    expect(
      plan.where((e) => e.document.isPasswordProtected).single.document.id,
      'secret',
    );
  });
}
