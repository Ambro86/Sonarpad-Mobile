import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'Missing $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, greaterThan(startIndex), reason: 'Missing $end after $start');
  return source.substring(startIndex, endIndex);
}

void main() {
  test('SonarTube collections expose fixed Back before the channel or playlist title', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    final shared = _between(
      source,
      'Widget _buildSharedAccessibleSonarTube',
      'Widget _buildSearchResultsAccessible',
    );
    final build = _between(
      source,
      '@override\n  Widget build(BuildContext context)',
      'class _SonarTubeTranscriptScreen',
    );

    expect(build, contains("key: const ValueKey('sonartube_collection_back')"));
    expect(build, contains('leading: _isCollection'));
    expect(
      build,
      contains(
        'excludeHeaderSemantics: _isCollection && useSharedAccessibleViewModel',
      ),
    );
    expect(
      build,
      contains(
        'title: _isCollection && useSharedAccessibleViewModel\n'
        '            ? ExcludeSemantics(',
      ),
    );

    expect(shared, contains("id: 'collection_title'"));
    expect(shared, contains('title: widget.collection!.title'));
    expect(
      shared,
      contains("key: const ValueKey('sonartube_collection_content_title')"),
    );

    final titleIndex = shared.indexOf("id: 'collection_title'");
    final favoriteIndex = shared.indexOf("id: 'channel_favorite'");
    final firstVideoIndex = shared.indexOf("id: 'item_\$i'");
    expect(titleIndex, greaterThanOrEqualTo(0));
    expect(favoriteIndex, greaterThan(titleIndex));
    expect(firstVideoIndex, greaterThan(favoriteIndex));

    expect(build, isNot(contains('UniversalPersistentNavigationButton(')));
    expect(build, isNot(contains('persistentTopAction:')));
  });
}
