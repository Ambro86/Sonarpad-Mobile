import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media open guard acquires synchronously and releases by owner key', () {
    final source = File('lib/utils/media_open_guard.dart').readAsStringSync();

    expect(source, contains('bool tryAcquire(String key)'));
    expect(source, contains('if (_activeKey != null) return false;'));
    expect(source, contains('_activeKey = key;'));
    expect(source, contains('void release(String key)'));
    expect(source, contains('if (_activeKey == key)'));
  });

  test('async media entry points reject overlapping opens before resolver work', () {
    final expectations = <String, List<String>>{
      'lib/screens/podcast_episodes_screen.dart': [
        'source=podcast',
        '_mediaOpenGuard.tryAcquire(itemKey)',
        'markEpisodeAsPlayed',
        "RouteSettings(name: '/podcasts/player')",
      ],
      'lib/screens/tv_screen.dart': [
        'source=tv-live',
        '_mediaOpenGuard.tryAcquire(itemKey)',
        'resolveStreamUrl(channel)',
        "RouteSettings(name: '/tv/channel/player')",
      ],
      'lib/screens/tv_channel_screen.dart': [
        'source=tv-channel',
        '_mediaOpenGuard.tryAcquire(itemKey)',
        'resolveStreamUrl(widget.channel)',
        "RouteSettings(name: '/tv/channel/player')",
      ],
      'lib/screens/raiplay_screen.dart': [
        'source=raiplay',
        '_mediaOpenGuard.tryAcquire(itemKey)',
        'resolvePlaybackUrls(mediaUrl)',
        "RouteSettings(name: '/raiplay/player')",
      ],
      'lib/screens/la7_play_screen.dart': [
        'source=la7play',
        '_mediaOpenGuard.tryAcquire(itemKey)',
        'resolveVod(item.target)',
        "RouteSettings(name: '/la7play/player')",
      ],
      'lib/screens/raiplaysound_screen.dart': [
        'source=raiplaysound',
        '_mediaOpenGuard.tryAcquire(itemKey)',
        'getTvSecretCode()',
        "RouteSettings(name: '/raiplaysound/player')",
      ],
    };

    for (final entry in expectations.entries) {
      final source = File(entry.key).readAsStringSync();
      for (final marker in entry.value) {
        expect(source, contains(marker), reason: '${entry.key} missing $marker');
      }
      expect(
        source,
        contains('_mediaOpenGuard.release(itemKey);'),
        reason: '${entry.key} must release the guard',
      );
      expect(
        source,
        contains('MEDIA_OPEN_GUARD duplicate ignored'),
        reason: '${entry.key} must log rejected duplicate activation',
      );
    }
  });

  test('ordinary radio lists remain unchanged by the media guard', () {
    for (final path in [
      'lib/screens/radio_screen.dart',
      'lib/screens/favorite_radios_screen.dart',
      'lib/screens/recent_radios_screen.dart',
      'lib/screens/radio_search_results_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('MediaOpenGuard')), reason: path);
      expect(source, isNot(contains('MEDIA_OPEN_GUARD')), reason: path);
    }
  });
}
