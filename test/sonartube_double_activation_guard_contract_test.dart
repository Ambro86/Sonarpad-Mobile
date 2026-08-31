import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube claims an item open before awaiting resolver work', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    final openItemStart = source.indexOf(
      'Future<void> _openItem(SonarTubeItem item) async',
    );
    final claim = source.indexOf('_openingItemKey = itemKey;', openItemStart);
    final resolve = source.indexOf(
      'final episode = await _resolveEpisode(item);',
      openItemStart,
    );
    final navigator = source.indexOf(
      "settings: const RouteSettings(name: '/sonartube/player')",
      openItemStart,
    );

    expect(openItemStart, greaterThanOrEqualTo(0));
    expect(claim, greaterThan(openItemStart));
    expect(resolve, greaterThan(claim));
    expect(navigator, greaterThan(resolve));
    expect(
      source,
      contains(
        'SonarTube: duplicate open ignored active=$_openingItemKey requested=$itemKey',
      ),
    );
  });

  test('SonarTube disables item activation while an open is in flight', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('bool get _itemOpenInProgress => _openingItemKey != null;'));
    expect(source, contains('enabled: !_itemOpenInProgress'));
    expect(
      source,
      contains('onTap: !_itemOpenInProgress ? () => _openItem(item) : null'),
    );
  });

  test('favorites and recent videos also reject duplicate activation', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('bool _openingFavoriteItem = false;'));
    expect(source, contains('if (_openingFavoriteItem)'));
    expect(
      source,
      contains('SonarTube favorites: duplicate open ignored id=${item.id}'),
    );
    expect(source, contains('enabled: !_openingFavoriteItem'));

    expect(source, contains('bool _openingRecentVideo = false;'));
    expect(source, contains('if (_openingRecentVideo)'));
    expect(
      source,
      contains('SonarTube recent: duplicate open ignored id=${item.id}'),
    );
    expect(source, contains('enabled: !_openingRecentVideo'));
  });
}
