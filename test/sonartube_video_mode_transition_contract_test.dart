import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube stops the old engine before changing video mode', () {
    final player = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    expect(player, contains('final resumePosition ='));
    expect(player, contains('_audio.position;'));
    expect(player, contains('final wasPlaying ='));
    expect(player, contains('await _audio.stop();'));
    expect(player, contains('await previousVideoController.pause();'));
    expect(player, contains('await previousVideoController.dispose();'));
    expect(player, contains('resumePosition: resumePosition,'));
    expect(player, contains('shouldPlay: wasPlaying,'));
    expect(player, contains('video transition restored position='));
    expect(player, contains('audio transition restored position='));
  });

  test('SonarTube keeps video-first bootstrap for the saved audio-only mode', () {
    final player = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    expect(player, contains('startWithVideoThenRestorePreference'));
    expect(player, contains('_restoreVideoOffAfterBootstrap'));
    expect(
      player,
      contains(
        'SonarTube bootstrap completed; restoring audio-only preference',
      ),
    );
    expect(player, contains('_toggleVideo(false);'));
  });

  test('YouTube fullscreen gives video_player a real surface size', () {
    final player = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    expect(player, contains('Widget _buildVideoPlayerFullscreenSurface('));
    expect(player, contains('child: LayoutBuilder('));
    expect(player, contains('child: OverflowBox('));
    expect(player, contains('minWidth: width,'));
    expect(player, contains('maxHeight: height,'));
    expect(player, contains('width: width,'));
    expect(player, contains('height: height,'));
    expect(
      player,
      isNot(contains('width: aspect >= 1 ? aspect : 1')),
    );
  });

  test('YouTube fullscreen adapts vertical and horizontal source videos', () {
    final player = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();

    expect(player, contains('final isPortraitVideo = safeAspect < 1;'));
    expect(
      player,
      contains('if (isPortraitVideo && height > maxHeight) {'),
    );
    expect(
      player,
      contains("else if (!isPortraitVideo && height < maxHeight) {"),
    );
    expect(player, contains("isPortraitVideo ? 'contain' : 'cover'"));
  });
}
