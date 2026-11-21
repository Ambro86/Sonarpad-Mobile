import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/document_text_extractor.dart';

void main() {
  test(
    'binary Word reads compressed cells and Unicode within the main story',
    () async {
      final result = await DocumentTextExtractor().extract(
        extension: 'doc',
        path: 'test/fixtures/word_mixed_cells.doc',
      );
      expect(result.error, isNull);
      expect(result.text, 'Cafè\n123\n東京\n');
    },
  );
  test('Word XML content still opens with either extension', () async {
    final dir = await Directory.systemTemp.createTemp('word-xml-');
    addTearDown(() => dir.delete(recursive: true));
    final xml = utf8.encode(
      '<w:document xmlns:w="word"><w:p><w:r><w:t>First cell</w:t></w:r></w:p></w:document>',
    );
    final archive = Archive()
      ..addFile(ArchiveFile('word/document.xml', xml.length, xml));
    final bytes = ZipEncoder().encode(archive)!;
    for (final ext in ['doc', 'docx']) {
      final file = await File('${dir.path}/example.$ext').writeAsBytes(bytes);
      final result = await DocumentTextExtractor().extract(
        path: file.path,
        extension: ext,
      );
      expect(result.text, 'First cell');
    }
  });
}
