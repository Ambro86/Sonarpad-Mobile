import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _between(String source, String start, String? end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'Missing $start');
  if (end == null) return source.substring(startIndex);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, greaterThan(startIndex), reason: 'Missing $end after $start');
  return source.substring(startIndex, endIndex);
}

void main() {
  test('every scrollable SonarTube route keeps an accessible Back in the fixed AppBar', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    final rootAndCollections = _between(
      source,
      'class _SonarTubeScreenState',
      'class _SonarTubeTranscriptScreen',
    );
    expect(
      rootAndCollections,
      contains("key: const ValueKey('sonartube_search_results_back')"),
    );
    expect(
      rootAndCollections,
      contains("key: const ValueKey('sonartube_collection_back')"),
    );
    expect(rootAndCollections, contains('leading: BackButton('));

    final transcript = _between(
      source,
      'class _SonarTubeTranscriptScreenState',
      'class _SonarTubeCommentsScreen',
    );
    final comments = _between(
      source,
      'class _SonarTubeCommentsScreenState',
      'class _SonarTubeRecentVideosScreen',
    );
    final recent = _between(
      source,
      'class _SonarTubeRecentVideosScreenState',
      'class _SonarTubeFavoritesScreen',
    );
    final favorites = _between(
      source,
      'class _SonarTubeFavoritesScreenState',
      null,
    );

    for (final screen in [transcript, comments, recent, favorites]) {
      expect(screen, contains('leading: BackButton('));
      expect(screen, isNot(contains('persistentTopAction:')));
      expect(screen, isNot(contains("id: 'persistent_back'")));
    }

    expect(source, isNot(contains('UniversalPersistentNavigationButton(')));
    expect(source, isNot(contains('persistentTopAction:')));
    expect(source, contains("ValueKey('sonartube_transcript_back')"));
    expect(source, contains("ValueKey('sonartube_comments_back')"));
    expect(source, contains("ValueKey('sonartube_recent_videos_back')"));
    expect(source, contains("ValueKey('sonartube_favorites_back')"));
  });

  test('SonarTube media player exposes AppBar Back before native player controls', () {
    final player = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    expect(player, contains("ValueKey('podcast_player_back')"));
    expect(player, contains('leading: BackButton('));
    expect(player, contains('excludeHeaderSemantics: true'));
    expect(
      player,
      contains(
        "title: ExcludeSemantics(\n          child: Text(l10n.nowPlayingTitle(_episode.title)),",
      ),
    );
    expect(player, contains("id: 'now_playing_title'"));
    expect(
      player,
      contains('title: l10n.nowPlayingTitle(_episode.title)'),
    );
    final appBarStart = player.indexOf('appBar: AppBar(');
    final bodyStart = player.indexOf('body:', appBarStart);
    final appBar = player.substring(appBarStart, bodyStart);
    expect(
      appBar.indexOf('leading: BackButton('),
      lessThan(appBar.indexOf('title: ExcludeSemantics(')),
    );
    expect(player, isNot(contains('UniversalPersistentNavigationButton(')));
    expect(player, isNot(contains('persistentTopAction:')));
    expect(player, isNot(contains("id: 'persistent_back'")));
  });

  test('shared renderer still supports persistent route actions when a screen needs one', () {
    final adapter = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();

    expect(adapter, contains('final AccessibleListRow? persistentTopAction;'));
    expect(
      adapter,
      contains("'persistentTopAction': widget.persistentTopAction!.toMap()"),
    );
    expect(adapter, contains('persistentTopAction.id == id'));
  });

  test('UIKit can still place a persistent action before a scrolling table', () {
    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(native, contains('SonarpadPersistentAccessibilityActionElement'));
    expect(native, contains('map["persistentTopAction"]'));
    expect(
      native,
      contains('rootView.accessibilityElements = [element, tableView]'),
    );
    expect(native, contains('arguments: ["type": "activate", "id": row.id]'));
  });
}
