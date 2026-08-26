import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cinema trailers use the SonarTube resolver and Sonarpad player', () {
    final cinema = File('lib/screens/cinema_detail_screen.dart').readAsStringSync();
    final sonarTube = File('lib/services/sonartube_service.dart').readAsStringSync();

    expect(sonarTube, contains('Future<SonarTubeResolvedMedia> resolveUrl('));
    expect(cinema, contains('_sonarTubeService.resolveUrl('));
    expect(cinema, contains('PodcastEpisodePlayerScreen('));
    expect(cinema, contains('startWithVideoThenRestorePreference: true'));
    expect(cinema, contains('refreshEpisode: _resolveTrailerEpisode'));
    expect(cinema, isNot(contains("import 'trailer_screen.dart';")));
    expect(cinema, isNot(contains('TrailerScreen(')));
  });


  test('cinema trailer player keeps Back first in VoiceOver order', () {
    final cinema = File('lib/screens/cinema_detail_screen.dart').readAsStringSync();
    final player = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    expect(cinema, contains("RouteSettings(name: '/cinema/trailer')"));
    expect(cinema, contains('PodcastEpisodePlayerScreen('));
    expect(player, contains("ValueKey('podcast_player_back')"));
    expect(player, contains('excludeHeaderSemantics: true'));
    expect(player, contains("id: 'now_playing_title'"));
    expect(
      player,
      contains(
        "title: ExcludeSemantics(\n          child: Text(l10n.nowPlayingTitle(_episode.title)),",
      ),
    );
  });
}
