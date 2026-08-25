import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local imported audio exposes native share in both accessible renderers', () {
    final source = File('lib/screens/documents_screen.dart').readAsStringSync();

    // Audio now shares the same local-media path used by video files.
    expect(source, contains('Future<void> _shareLocalMediaDocument('));
    expect(source, contains('if (!_isLocalMediaDocument(doc)) return;'));
    expect(source, contains('SharePlus.instance.share('));
    expect(source, contains('files: [XFile(file.path)]'));
    expect(
      source,
      contains("AccessibleCustomAction(id: 'share', label: l10n.share)"),
    );
    expect(
      source,
      contains("case 'share': await _shareLocalMediaDocument(doc);"),
    );
    expect(source, contains('canShare: _isLocalMediaDocument(doc)'));
    expect(source, contains('CustomSemanticsAction(label: l10n.share): onShare'));
    expect(source, contains("'mp3'"));
  });

  test('local audio is not offered the text-document export action', () {
    final source = File('lib/screens/documents_screen.dart').readAsStringSync();

    expect(
      source,
      contains('if (!_isRemoteAudioDocument(doc) && !_isLocalMediaDocument(doc))'),
    );
    expect(source, contains('_localMediaDocumentExtensions'));
    expect(source, contains('.contains(doc.extension.toLowerCase())'));
  });
}
