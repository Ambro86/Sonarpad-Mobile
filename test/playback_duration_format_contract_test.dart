import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player uses hour-aware visual and spoken playback durations', () {
    final labels = File('lib/l10n/localized_dynamic_labels.dart').readAsStringSync();
    final player = File('lib/screens/podcast_episode_player_screen.dart').readAsStringSync();

    expect(labels, contains('String formatPlaybackClock(Duration duration)'));
    expect(
      labels,
      contains(r"return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';"),
    );
    expect(labels, contains('String formatPlaybackSpokenDuration(Duration duration)'));
    expect(labels, contains("_playbackDurationUnit('hour', hours)"));
    expect(labels, contains("_playbackDurationUnit('minute', minutes)"));
    expect(labels, contains("_playbackDurationUnit('second', seconds)"));
    expect(labels, contains('mediaCutterDurationAnd'));

    expect(player, contains('l10n.formatPlaybackClock(position)'));
    expect(player, contains('l10n.formatPlaybackSpokenDuration(position)'));
    expect(player, contains('l10n.formatPlaybackSpokenDuration(_duration)'));
    expect(player, contains('l10n.formatPlaybackSpokenDuration(duration)'));
    expect(player, isNot(contains('final mins = d.inMinutes;')));
  });
}
