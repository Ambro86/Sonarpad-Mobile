import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_project_library.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';

class _Library extends DocumentLibraryService {
  _Library(this.root, this.items);
  final Directory root;
  final List<DocumentItem> items;
  final resolved = <String>[];
  bool loaded = false;
  @override
  Future<void> load() async {
    loaded = true;
  }

  @override
  List<DocumentItem> get documents => items;
  @override
  Future<String> resolveFilePath(DocumentItem doc) async {
    resolved.add(doc.id);
    return '${root.path}/${doc.id}.json';
  }
}

DocumentItem _doc(String id, {String? parent, bool protected = false}) =>
    DocumentItem(
      id: id,
      name: '$id.json',
      path: '/old-ios-container/$id.json',
      extension: 'json',
      addedAt: DateTime(2026),
      parentId: parent,
      passwordSalt: protected ? 'salt' : null,
      passwordHash: protected ? 'hash' : null,
    );

void main() {
  test('recognizes both project formats and rejects other JSON or missing files', () async {
    final root = await Directory.systemTemp.createTemp('ad-recognition-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/project.json');
    for (final marker in ['format', 'schema']) {
      await file.writeAsString('{"$marker":"sonarpad-audio-description-project"}');
      expect(await isAudioDescriptionProjectFile(file.path), isTrue);
    }
    for (final contents in ['{}', '[]', 'null', '{"format":"other"}', 'broken']) {
      await file.writeAsString(contents);
      expect(await isAudioDescriptionProjectFile(file.path), isFalse);
    }
    await file.delete();
    expect(await isAudioDescriptionProjectFile(file.path), isFalse);
  });

  test(
    'finds saved and renamed projects in all folders using current resolved paths',
    () async {
      final root = await Directory.systemTemp.createTemp('ad-library-');
      addTearDown(() => root.delete(recursive: true));
      await File('${root.path}/renamed.json').writeAsString(
        '{"format":"sonarpad-audio-description-project","version":1}',
      );
      await File('${root.path}/legacy.json').writeAsString(
        '{"schema":"sonarpad-audio-description-project","schema_version":1}',
      );
      await File('${root.path}/unrelated.json').writeAsString('{"other":true}');
      await File('${root.path}/broken.json').writeAsString('not json');
      final library = _Library(root, [
        _doc('renamed', parent: 'folder'),
        _doc('legacy'),
        _doc('unrelated'),
        _doc('broken'),
        _doc('missing'),
      ]);
      final projects = await loadAudioDescriptionProjects(library);
      expect(library.loaded, isTrue);
      expect(
        projects.map((doc) => doc.id),
        unorderedEquals(['renamed', 'legacy']),
      );
      expect(library.resolved, containsAll(['renamed', 'legacy']));
      expect(
        projects.firstWhere((doc) => doc.id == 'renamed').parentId,
        'folder',
      );
    },
  );

  test(
    'protected JSON remains selectable without inspecting protected contents',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ad-library-protected-',
      );
      addTearDown(() => root.delete(recursive: true));
      await File('${root.path}/private.json').writeAsBytes([0xff, 0xfe]);
      final library = _Library(root, [_doc('private', protected: true)]);
      final projects = await loadAudioDescriptionProjects(library);
      expect(projects.single.isPasswordProtected, isTrue);
    },
  );
}
