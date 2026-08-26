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

  test('paragraph editing refreshes the focused UIKit row after the new text is built', () {
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
      contains("final refreshedParagraphId = 'paragraph_\$index';"),
      reason: 'The refresh must target the paragraph that was edited.',
    );
    expect(
      editMethod,
      contains('_accessibleDocumentListController.refreshAccessibilityRow('),
      reason: 'The already-focused UIKit cell must have its VoiceOver label refreshed in place.',
    );
    expect(
      editMethod,
      isNot(contains('focusToReturn(refreshedParagraphId')),
      reason: 'Refreshing the label must not move accessibility focus.',
    );
    expect(
      editMethod,
      isNot(contains('_focusChunk(index)')),
      reason: 'The fix must preserve the current paragraph rather than force a new focus jump.',
    );
    final nativeSource =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();
    expect(
      nativeSource,
      contains('private func refreshAccessibilityRow(id: String)'),
      reason: 'The UIKit bridge must support an in-place row metadata refresh.',
    );
    expect(
      nativeSource,
      contains('UIAccessibility.post(notification: .layoutChanged, argument: cell)'),
      reason: 'VoiceOver must be told to re-read the already-focused updated cell.',
    );
  });

}
