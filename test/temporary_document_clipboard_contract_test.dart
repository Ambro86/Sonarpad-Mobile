import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/document_reader_screen.dart').readAsStringSync();

  test('temporary documents expose copy to clipboard next to save in library', () {
    expect(source, contains('tooltip: l10n.copyToClipboard'));
    expect(source, contains('tooltip: l10n.saveInLibrary'));
    expect(source, contains('Clipboard.setData(ClipboardData(text: _documentText))'));
    expect(source, contains('if (!_currentDoc.isTemporary || _documentText.isEmpty) return;'));
  });

  test('copy confirmation is localized in every ARB locale', () {
    for (final file in Directory('lib/l10n').listSync().whereType<File>()) {
      if (!file.path.endsWith('.arb')) continue;
      final text = file.readAsStringSync();
      expect(text, contains('"copyToClipboard"'), reason: file.path);
      expect(text, contains('"textCopiedToClipboard"'), reason: file.path);
    }
  });
}
