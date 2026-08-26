import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('document bookmark focus is consumed after the initial accessibility focus', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();

    expect(
      source,
      contains('if (_initialBookmarkFocusIndex >= 0)'),
      reason: 'The saved bookmark must only drive the first focus when a document is opened.',
    );
    expect(
      source,
      contains('_initialBookmarkFocusIndex = -1;'),
      reason: 'After the bookmark row receives focus, later model rebuilds must not reuse it.',
    );
    expect(
      source,
      contains('_syncDocumentPositionFromAccessibilityFocus(index);\n          if (_speaking) return;'),
      reason: 'Activating a paragraph must record/consume the current focus before opening the editor.',
    );
  });

  test('paragraph editing updates in place without explicitly jumping to the bookmark', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _editParagraph(int index) async');
    final end = source.indexOf('Future<void> _togglePlayPause()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final editMethod = source.substring(start, end);

    expect(editMethod, isNot(contains('_bookmarkIndex.clamp')));
    expect(editMethod, isNot(contains('_focusChunk(_bookmarkIndex')));
    expect(editMethod, isNot(contains('_scrollToChunk(_bookmarkIndex')));
  });
}
