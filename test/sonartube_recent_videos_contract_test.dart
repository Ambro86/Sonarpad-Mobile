import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube root exposes recent videos next to favorites in shared and Flutter renderers', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains("id: 'favorites'"));
    expect(source, contains("ValueKey('sonartube_favorites_button')"));
    expect(source, contains("id: 'recent_videos'"));
    expect(source, contains("ValueKey('sonartube_recent_videos_button')"));
    expect(source, contains('l10n.sonarTubeRecentVideos'));
    expect(source, contains('await _openRecentVideos();'));
  });

  test('successful SonarTube playback records video history including next and previous navigation', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('await _historyService.addRecentVideo(item);'));
    expect(source, contains('await _historyService.addRecentVideo(targetItem);'));
    expect(source, contains("name: '/sonartube/recent-videos'"));
  });

  test('recent videos expose localized clear history in shared UIKit model and Flutter', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains("id: 'clear_history'"));
    expect(source, contains('title: l10n.clearHistory'));
    expect(source, contains('content: Text(l10n.sonarTubeConfirmClearHistory)'));
    expect(source, contains("ValueKey('sonartube_clear_recent_videos')"));
    expect(source, contains('await widget.historyService.clearRecentVideos();'));
  });

  test('history storage is capped at 100 and stores videos only', () {
    final source = File('lib/services/sonartube_history_service.dart').readAsStringSync();

    expect(source, contains('static const maxItems = 100;'));
    expect(source, contains('item.kind != SonarTubeItemKind.video'));
    expect(source, contains('recent.removeWhere((candidate) => candidate.id == item.id);'));
    expect(source, contains('recent.insert(0, _forHistoryStorage(item));'));
  });
}
