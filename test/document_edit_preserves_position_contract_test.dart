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

  test('paragraph editing disarms bookmark focus and restores the edited paragraph', () {
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
    expect(
      editMethod,
      contains('_initialBookmarkFocusIndex = -1;'),
      reason: 'Opening/applying the editor must never re-arm the saved bookmark as initial focus.',
    );
    expect(
      editMethod,
      contains('_focusedChunkIndex = index;'),
      reason: 'The paragraph being edited must become the authoritative document position.',
    );
    expect(
      editMethod,
      contains('await _accessibleDocumentListController.focusToReturn('),
      reason: 'After Apply the edited paragraph must be restored explicitly instead of relying on a stale VoiceOver cell.',
    );
  });

  test('paragraph editing refreshes the UIKit row before restoring focus', () {
    final source =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _editParagraph(int index) async');
    final end = source.indexOf('Future<void> _togglePlayPause()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final editMethod = source.substring(start, end);

    expect(
      editMethod,
      contains('await WidgetsBinding.instance.endOfFrame;'),
      reason: 'UIKit must first receive the rebuilt paragraph model.',
    );
    expect(
      editMethod,
      contains("final refreshedParagraphId = 'paragraph_\$restoredFocusIndex';"),
      reason: 'The refresh must target the edited paragraph after any chunk-count change.',
    );
    expect(
      editMethod,
      contains('_accessibleDocumentListController.refreshAccessibilityRow('),
      reason: 'The UIKit row must receive the new label before focus is restored.',
    );
    expect(
      editMethod.indexOf('_accessibleDocumentListController.refreshAccessibilityRow('),
      lessThan(editMethod.indexOf('_accessibleDocumentListController.focusToReturn(')),
      reason: 'Refresh the label first, then move VoiceOver to that live row.',
    );

    final nativeSource =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();
    expect(
      nativeSource,
      contains('self.debugTag == "document" &&'),
      reason: 'The rare recovery must be scoped to the Document renderer.',
    );
    expect(
      nativeSource,
      contains('mode == "returnFocus" &&'),
      reason: 'The stronger recovery must only run for an explicit editor return.',
    );
    expect(
      nativeSource,
      contains('id.hasPrefix("paragraph_")'),
      reason: 'Only document paragraph rows may use this recovery.',
    );
    expect(
      nativeSource,
      contains('ONE_SHOT_FOCUS_FALLBACK'),
      reason: 'If VoiceOver ignores the first post there must be exactly one stronger fallback.',
    );
  });
}
