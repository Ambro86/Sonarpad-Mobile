import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube preserves channel handle and real subscriber count', () {
    final service =
        File('lib/services/sonartube_service.dart').readAsStringSync();
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final favorites = File('lib/services/sonartube_favorites_service.dart')
        .readAsStringSync();
    final resolverFile = File('server/youtube_resolve.php');

    expect(service, contains('this.subscribers,'));
    expect(service, contains('this.handle,'));
    expect(service, contains('final String? subscribers;'));
    expect(service, contains('final String? handle;'));
    expect(service, contains('subscriberTextIsHandle'));
    expect(
      service,
      contains("_nullableYoutubeText(channel['videoCountText'])"),
    );
    expect(service, contains('handle: handle'));
    expect(service, contains('subscribers: subscribers'));
    expect(service, contains("handle: _string(raw['handle'])"));
    expect(service, contains("subscribers: _string(raw['subscribers'])"));

    expect(screen, contains('item.handle!'));
    expect(screen, contains('item.subscribers!'));

    expect(favorites, contains('handle: item.handle'));
    expect(favorites, contains('subscribers: item.subscribers'));
    expect(favorites, contains("'handle': item.handle"));
    expect(favorites, contains("'subscribers': item.subscribers"));
    expect(favorites, contains("handle: raw['handle']?.toString()"));
    expect(favorites, contains("subscribers: raw['subscribers']?.toString()"));

    if (resolverFile.existsSync()) {
      final resolver = resolverFile.readAsStringSync();
      expect(resolver, contains("'handle' => \$displayHandle"));
      expect(resolver, contains('\$subscriberTextIsHandle'));
      expect(resolver, contains("\$c['videoCountText']"));
      expect(resolver, contains("'subscribers' => \$subscriberCount"));
    }
  });
}
