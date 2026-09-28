import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared player keeps position immediately after volume for VoiceOver', () {
    final source = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    final start = source.indexOf(
      'Widget _buildSharedAccessiblePlayerBody(AppLocalizations l10n, bool canSeek)',
    );
    final end = source.indexOf('\n  @override\n  Widget build(BuildContext context)', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final shared = source.substring(start, end);
    final volume = shared.indexOf("id: 'accessible_volume'");
    final position = shared.indexOf("id: 'accessible_position'");
    final previous = shared.indexOf("id: 'previous_episode'");
    final next = shared.indexOf("id: 'next_episode'");
    final extras = shared.indexOf('for (final action in widget.extraActions)');

    expect(volume, greaterThanOrEqualTo(0));
    expect(position, greaterThan(volume));
    expect(previous, greaterThan(position));
    expect(next, greaterThan(position));
    expect(extras, greaterThan(position));

    expect(shared, contains('title: l10n.playbackPosition'));
    expect(shared, contains("event.id == 'accessible_position'"));
    expect(
      RegExp(r'nativeSliderAccessibilityElement: true')
          .allMatches(shared)
          .length,
      greaterThanOrEqualTo(2),
    );

    // The shared/native accessibility renderer must not append a separate
    // Flutter position slider after the native list: that was what caused
    // VoiceOver to traverse all SonarTube actions before reaching Position.
    expect(shared, isNot(contains('_VideoPositionControl(')));
    expect(shared, isNot(contains('_PodcastPositionControl(')));
  });
}
