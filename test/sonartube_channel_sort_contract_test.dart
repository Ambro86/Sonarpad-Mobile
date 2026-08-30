import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel video sorting stays server-side and accessible', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final service = File('lib/services/sonartube_service.dart').readAsStringSync();
    final resolver = File('server/youtube_resolve.php').readAsStringSync();

    expect(screen, contains("id: 'channel_sort'"));
    expect(screen, contains("ValueKey('sonartube_channel_sort')"));
    expect(screen, contains('sonarTubeSortNewest'));
    expect(screen, contains('sonarTubeSortOldest'));
    expect(screen, contains('sonarTubeSortPopular'));
    expect(screen, contains('channelSort: _channelSort'));
    expect(screen, contains("focusTo('channel_sort'"));

    expect(
      service,
      contains('enum SonarTubeChannelSort { newest, oldest, popular }'),
    );
    expect(service, contains('_extractChannelSortParams(data)'));
    expect(service, contains("payload['continuation'] = continuation"));
    expect(service, contains('channel_sort_unavailable'));
    expect(screen, isNot(contains('_items.sort(')));
    expect(screen, isNot(contains('_items.reversed')));

    expect(resolver, contains('yt_channel_sort_params_from_response'));
    expect(resolver, contains(r"$browseSort"));
    expect(resolver, contains("['newest', 'oldest', 'popular']"));
  });
}
