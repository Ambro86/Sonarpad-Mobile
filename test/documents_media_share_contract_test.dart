import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local audio and video expose native share in both accessible renderers', () {
    final source = File('lib/screens/documents_screen.dart').readAsStringSync();

    expect(source, contains('Future<void> _shareLocalMediaDocument('));
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
    expect(source, contains("'mp4'"));
    expect(source, contains("'mov'"));
    expect(source, contains("'mkv'"));
  });

  test('local media opens in Sonarpad player and video starts with video enabled', () {
    final source = File('lib/screens/documents_screen.dart').readAsStringSync();

    expect(source, contains('if (_isLocalMediaDocument(doc))'));
    expect(source, contains('final isVideo = _isLocalVideoDocument(doc);'));
    expect(source, contains('PodcastEpisodePlayerScreen('));
    expect(source, contains('isVideoSupported: isVideo'));
    expect(source, contains('startWithVideo: isVideo'));
    expect(source, contains("name: '/documents/media_player'"));
  });

  test('local media is not offered the text-document export action', () {
    final source = File('lib/screens/documents_screen.dart').readAsStringSync();
    expect(
      source,
      contains('if (!_isRemoteAudioDocument(doc) && !_isLocalMediaDocument(doc))'),
    );
    expect(source, contains('_localMediaDocumentExtensions'));
    expect(source, contains('.contains(doc.extension.toLowerCase())'));
  });
}
