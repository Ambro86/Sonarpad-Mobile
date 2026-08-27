import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube preserves and announces channel subscriber counts', () {
    final service =
        File('lib/services/sonartube_service.dart').readAsStringSync();
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final favorites = File('lib/services/sonartube_favorites_service.dart')
        .readAsStringSync();
    final resolverFile = File('server/youtube_resolve.php');

    expect(service, contains('this.subscribers,'));
    expect(service, contains('final String? subscribers;'));
    expect(
      service,
      contains(
        "subscribers: _nullableYoutubeText(channel['subscriberCountText'])",
      ),
    );
    expect(service, contains("subscribers: _string(raw['subscribers'])"));

    expect(
      screen,
      contains('item.kind == SonarTubeItemKind.channel &&'),
    );
    expect(screen, contains('item.subscribers!'));
    expect(screen, contains("? '\$type · \${item.subscribers}'"));

    expect(favorites, contains('subscribers: item.subscribers'));
    expect(favorites, contains("'subscribers': item.subscribers"));
    expect(favorites, contains("subscribers: raw['subscribers']?.toString()"));

    if (resolverFile.existsSync()) {
      final resolver = resolverFile.readAsStringSync();
      expect(
        resolver,
        contains(
          "'subscribers' => yt_text(\$c['subscriberCountText'] ?? null) ?: null",
        ),
      );
      expect(resolver, isNot(contains("\$c['videoCountText']")));
    }
  });
}
