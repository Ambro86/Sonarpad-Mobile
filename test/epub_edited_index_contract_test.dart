import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edited EPUB keeps canonical index from original archive and remaps it',
      () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();

    expect(source, contains("if (ext == 'epub') {"));
    expect(
      source,
      contains(
        'originalPath = await documentLibrary.resolveFilePath(_currentDoc);',
      ),
      reason: 'Edited EPUB text still needs the untouched archive for NCX/nav.',
    );
    expect(source, contains('_epubIndexSourcePath = originalPath;'));
    expect(source, contains('_loadRemappedEditedEpubIndex(sourcePath)'));
    expect(
      source,
      contains('remapEpubIndexToEditedChunks('),
      reason:
          'Edited EPUB destinations must be remapped from canonical original chunk positions.',
    );
    expect(
      source,
      contains('chunks: originalChunks,'),
      reason:
          'The canonical TOC must be extracted against original EPUB chunks, not edited chunks.',
    );
  });

  test('EPUB index caches distinguish normal and canonical original mappings', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();

    expect(source, contains('static const int _epubIndexCacheVersion = 3;'));
    expect(
      source,
      contains('static const int _canonicalEpubIndexCacheVersion = 1;'),
    );
    expect(
      source,
      contains("'documentTextFingerprint': _stableCacheKey(_documentText)"),
    );
    expect(source, contains("return File('\${cacheDir.path}/canonical_\$cacheKey.json');"));
  });

  test('editing invalidates already remapped EPUB index positions', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();
    final deleteStart =
        source.indexOf('Future<void> _deleteSelectedParagraphs() async');
    final editStart =
        source.indexOf('Future<void> _editParagraph(int index) async');
    final toggleStart =
        source.indexOf('Future<void> _togglePlayPause()', editStart);

    expect(deleteStart, greaterThanOrEqualTo(0));
    expect(editStart, greaterThan(deleteStart));
    expect(toggleStart, greaterThan(editStart));

    final deleteMethod = source.substring(deleteStart, editStart);
    final editMethod = source.substring(editStart, toggleStart);
    const invalidation =
        '_documentIndex = const <DocumentTableOfContentsEntry>[];';
    expect(deleteMethod, contains(invalidation));
    expect(editMethod, contains(invalidation));
    expect(deleteMethod, contains('_usingEditedText = true;'));
    expect(editMethod, contains('_usingEditedText = true;'));
  });

  test('edited EPUB remapping never searches a TOC title globally', () {
    final remapper =
        File('lib/utils/epub_index_remapper.dart').readAsStringSync();

    expect(remapper, contains('monotona'));
    expect(remapper, contains('_remapBetweenAnchors('));
    expect(remapper, isNot(contains('indexOf(entry.title')));
    expect(remapper, isNot(contains('contains(entry.title')));
  });
}
