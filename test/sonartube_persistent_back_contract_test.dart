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
  test('every scrollable SonarTube route keeps Back outside the native list', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    final rootAndCollections = _between(
      source,
      'class _SonarTubeScreenState',
      'class _SonarTubeTranscriptScreen',
    );
    expect(rootAndCollections, contains('persistentTopAction: _isCollection'));
    expect(
      rootAndCollections,
      contains("key: const ValueKey('sonartube_search_results_back')"),
    );

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
      expect(screen, contains('persistentTopAction: AccessibleListRow('));
      expect(screen, contains("id: 'persistent_back'"));
      expect(screen, contains('onActivate: () => Navigator.pop(context)'));
      expect(screen, contains('UniversalPersistentNavigationButton('));
    }

    expect(
      RegExp(r"id: 'persistent_back'").allMatches(source).length,
      greaterThanOrEqualTo(6),
    );
    expect(source, contains("ValueKey('sonartube_transcript_back')"));
    expect(source, contains("ValueKey('sonartube_comments_back')"));
    expect(source, contains("ValueKey('sonartube_recent_videos_back')"));
    expect(source, contains("ValueKey('sonartube_favorites_back')"));
  });

  test('SonarTube player keeps Back paired with the shared native controls', () {
    final player = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    expect(player, contains("ValueKey('podcast_player_back')"));
    expect(player, contains('UniversalPersistentNavigationButton('));
    expect(player, contains('persistentTopAction: AccessibleListRow('));
    expect(player, contains("id: 'persistent_back'"));
  });

  test('shared renderer serializes the persistent route action to UIKit', () {
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

  test('UIKit places persistent Back before the scrolling table', () {
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
