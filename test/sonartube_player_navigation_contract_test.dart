import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel and playlist videos pass their visible queue to the player', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('final navigationItems = _isCollection'));
    expect(
      source,
      contains('.where((candidate) => candidate.kind == SonarTubeItemKind.video)'),
    );
    expect(source, contains('var navigationIndex = navigationItems.indexWhere('));
    expect(source, contains('final targetItem = navigationItems[targetIndex];'));
    expect(source, contains('final resolved = await _resolveEpisode(targetItem);'));
    expect(source, contains('navigationIndex = targetIndex;'));
  });

  test('previous and next availability follows the current queue index', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('() => navigationIndex > 0'));
    expect(
      source,
      contains('() => navigationIndex + 1 < navigationItems.length'),
    );
    expect(source, contains('navigateEpisode: navigationIndex >= 0 ? navigateEpisode : null'));
  });

  test('single SonarTube videos do not expose queue navigation', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains("? _items"));
    expect(source, contains(": const <SonarTubeItem>[];"));
    expect(source, contains('previousEpisodeLabel: navigationIndex >= 0'));
    expect(source, contains('nextEpisodeLabel: navigationIndex >= 0'));
  });

  test('player switches adjacent episodes in place and rebuilds actions', () {
    final source = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _navigateAdjacentEpisode(int direction) async'));
    expect(source, contains('_refreshedEpisode = replacement;'));
    expect(source, contains("id: 'previous_episode'"));
    expect(source, contains("id: 'next_episode'"));
    expect(source, contains('if (_canNavigatePrevious)'));
    expect(source, contains('if (_canNavigateNext)'));
  });

  test('every locale contains localized SonarTube previous and next labels', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(file.path));

    for (final file in arbFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        contains('"sonarTubePreviousTrack"'),
        reason: file.path,
      );
      expect(
        source,
        contains('"sonarTubeNextTrack"'),
        reason: file.path,
      );
    }
  });
}
