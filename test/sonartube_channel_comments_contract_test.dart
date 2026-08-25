import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube videos expose channel and comments secondary actions', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final service = File('lib/services/sonartube_service.dart').readAsStringSync();

    expect(screen, contains('l10n.sonarTubeGoToChannel'));
    expect(screen, contains('l10n.sonarTubeViewComments'));
    expect(screen, contains("id: 'go_channel'"));
    expect(screen, contains("id: 'view_comments'"));
    expect(service, contains('final String? channelId;'));
    expect(service, contains("'comments': '1'"));
    expect(service, contains('Future<SonarTubeItem> channelForVideo'));
  });

  test('SonarTube comments keep the clean screen while using the shared accessible renderer', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(screen, contains('class _SonarTubeCommentsScreen'));
    expect(screen, contains("ValueKey('sonartube_comments_back')"));
    expect(screen, contains('l10n.sonarTubeComments'));
    expect(screen, contains('l10n.sonarTubeNoComments'));
    expect(screen, contains('l10n.sonarTubeLoadMoreComments'));
    final start = screen.indexOf('class _SonarTubeCommentsScreenState');
    final end = screen.indexOf('class _SonarTubeFavoritesScreen', start);
    final commentsScreen = screen.substring(start, end);
    expect(commentsScreen, contains('useSharedAccessibleViewModel'));
    expect(commentsScreen, contains('UniversalAccessibleList('));
  });

  test('all locales contain SonarTube channel and comments labels', () {
    for (final file in Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))) {
      final source = file.readAsStringSync();
      for (final key in const [
        'sonarTubeGoToChannel',
        'sonarTubeViewComments',
        'sonarTubeComments',
        'sonarTubeNoComments',
        'sonarTubeLoadMoreComments',
      ]) {
        expect(source, contains('"$key"'), reason: '${file.path}: $key');
      }
    }
  });
}
