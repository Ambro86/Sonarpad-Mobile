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


  test('recent videos expose per-video delete as secondary action and sighted-only button', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final history = File(
      'lib/services/sonartube_history_service.dart',
    ).readAsStringSync();

    expect(screen, contains("id: 'delete_video'"));
    expect(screen, contains('label: l10n.sonarTubeDeleteRecentVideo'));
    expect(screen, contains("icon: 'remove'"));
    expect(screen, contains('customSemanticsActions:'));
    expect(screen, contains('trailing: ExcludeSemantics('));
    expect(
      screen,
      contains("ValueKey('sonartube_delete_recent_video_\${item.id}')"),
    );
    expect(screen, contains('await _deleteRecentVideo(item);'));
    expect(history, contains('Future<void> removeRecentVideo(String videoId)'));
  });

  test('every locale contains the recent-video delete label', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList();

    expect(arbFiles, isNotEmpty);
    for (final file in arbFiles) {
      expect(
        file.readAsStringSync(),
        contains('"sonarTubeDeleteRecentVideo"'),
        reason: file.path,
      );
    }
  });
}
