import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared media player exposes volume exactly once as an adjustable row', () {
    final player = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    expect(player, contains("id: 'accessible_volume'"));
    expect(player, contains("title: l10n.adjustVolume"));
    expect(player, contains("kind: 'slider'"));
    expect(player, isNot(contains('nativeSliderAccessibilityElement: true')));
    expect(
      player,
      contains("event.id == 'accessible_volume' && event.type == 'slider'"),
    );
  });

  test('cinema trailers use the shared media player', () {
    final cinema = File(
      'lib/screens/cinema_detail_screen.dart',
    ).readAsStringSync();

    expect(cinema, contains('PodcastEpisodePlayerScreen('));
    expect(cinema, contains('isVideoSupported: true'));
  });
}
