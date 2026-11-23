import 'dart:io';

import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/document_text_extractor.dart';

void main() {
  test(
    'container lookup prefers the standard path and rejects ambiguous variants',
    () {
      final archive = Archive();
      ArchiveFile add(String name) {
        final file = ArchiveFile(name, 1, [0]);
        archive.addFile(file);
        return file;
      }

      final lower = add('meta-inf/container.xml');
      expect(RootFilePathReader.findContainerFile(archive), same(lower));
      add('META-INF/CONTAINER.XML');
      expect(RootFilePathReader.findContainerFile(archive), isNull);
      final standard = add('META-INF/container.xml');
      expect(RootFilePathReader.findContainerFile(archive), same(standard));
    },
  );

  final sampleDir = Platform.environment['SONARPAD_EPUB_TEST_DIR'];
  for (final path in [
    'third_party/epubx/test/res/alicesAdventuresUnderGround.epub',
    if (sampleDir != null)
      ...Directory(sampleDir).listSync().whereType<File>().map((f) => f.path),
  ]) {
    test(
      'reads text and contents from ${File(path).uri.pathSegments.last}',
      () async {
        final extractor = DocumentTextExtractor();
        final result = await extractor.extract(path: path, extension: 'epub');
        expect(result.error, isNull);
        expect(result.text.length, greaterThan(1000));
        final index = await extractor.extractEpubTableOfContents(
          path: path,
          chunks: result.text.split('\n\n'),
        );
        expect(index, isNotEmpty);
      },
    );
  }
}
