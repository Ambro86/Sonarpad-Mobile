import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube and SonarMusic queue the next track on lock screen', () {
    final player = File('lib/screens/podcast_episode_player_screen.dart').readAsStringSync();
    final audio = File('lib/services/audio_player_service.dart').readAsStringSync();
    expect(player, contains('state == AppLifecycleState.paused'));
    expect(player, contains('_prepareNativeQueuedNext()'));
    expect(player, contains('_nativeQueueIndexSubscription = _audio.currentIndexStream.listen'));
    expect(player, contains('final committed = await widget.navigateEpisode?.call(1)'));
    expect(player, contains('_isVideoEnabled || _videoController != null'));
    expect(audio, contains('Future<int?> queueNextUrl('));
    expect(audio, contains('await _player.addAudioSource('));
    expect(audio, contains('MediaItem(id: mediaId'));
  });
  test('SonarTube and SonarMusic pre-resolve without advancing cursor', () {
    final music = File('lib/screens/sonarmusic_screen.dart').readAsStringSync();
    final tube = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    expect(music, contains('previewNextEpisode: queue.length > 1'));
    expect(tube, contains('previewNextEpisode: navigationIndex >= 0'));
    expect(music, contains('prefetchedEpisode = _episode(queue[target])'));
    expect(tube, contains('prefetchedEpisode = _resolveEpisode(navigationItems[target])'));
  });
}
