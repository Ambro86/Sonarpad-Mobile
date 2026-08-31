import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edited EPUB keeps index from original archive and maps current chunks',
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
    expect(
      source,
      isNot(contains("ext == 'epub' &&\n          !usesEditedText")),
      reason: 'Editing paragraphs must not disable the EPUB index on reopen.',
    );
    expect(source, contains('_epubIndexSourcePath = originalPath;'));
    expect(
      source,
      contains(
        'extractEpubTableOfContentsInBackground(\n'
        '        path: sourcePath,\n'
        '        chunks: _chunks,',
      ),
      reason:
          'Index destinations must be mapped against the current edited chunks.',
    );
  });

  test('EPUB index cache changes when edited text changes', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();

    expect(source, contains('static const int _epubIndexCacheVersion = 2;'));
    expect(
      source,
      contains(
        "'documentTextFingerprint': _stableCacheKey(_documentText)",
      ),
    );
    expect(
      source,
      contains(
        "decoded['documentTextFingerprint'] !=\n"
        '          _stableCacheKey(_documentText)',
      ),
    );
    expect(
      source,
      contains(
        '_documentText.length.toString(),\n'
        '        _stableCacheKey(_documentText),',
      ),
      reason: 'Same-length edits must not reuse a stale EPUB index cache file.',
    );
  });

  test('editing invalidates already mapped EPUB index positions', () {
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
  });
}
