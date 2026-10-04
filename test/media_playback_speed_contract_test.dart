import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final player = File('lib/screens/podcast_episode_player_screen.dart').readAsStringSync();
  final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

  test('speed toggle belongs to general settings in both renderers and the save flow', () {
    expect(settings, contains("id: 'media_speed_control'"));
    expect(settings, contains("ValueKey('settings-media-speed-control')"));
    expect(settings, contains('isMediaSpeedControlEnabled()'));
    expect(settings, contains('await _settings.setMediaSpeedControlEnabled(_mediaSpeedControl);'));
    expect(settings, contains('_mediaSpeedControl != _savedMediaSpeedControl'));
    expect(settings, contains('_savedMediaSpeedControl = _mediaSpeedControl;'));
    final sonarSettings = File('lib/screens/sonartube_player_actions_settings_screen.dart').readAsStringSync();
    expect(sonarSettings, isNot(contains('media_speed_control')));
  });

  test('shared and fullscreen controls open an accessible picker and return focus', () {
    expect(player, contains("id: 'playback_speed'"));
    expect(player, contains("event.id == 'playback_speed'"));
    expect(player, contains('LetterJumpOptionPickerScreen<double>'));
    expect(player, contains('selectedBuilder: (rate) => rate == _playbackSpeed'));
    expect(player, contains("focusToReturn('playback_speed')"));
    expect(player, contains('_speedPickerOpen'));
    expect(RegExp(r'_buildPlaybackSpeedButton\(l10n\)').allMatches(player).length, 2);
  });

  test('speed uses explicit live state and is restored on each playback request', () {
    expect(player, contains('_mediaSpeedControlEnabled && !_episode.isLive'));
    expect(player, contains('enabled && !_episode.isLive'));
    expect(player, contains('await _loadPlaybackSpeedPreference();'));
    expect(player, contains('await _applyPreferredPlaybackSpeed();'));
    expect(player, contains('startVideo: shouldPlay'));
    expect(player, contains('setRate: video.setPlaybackSpeed'));
    expect(player, contains('setRate: _audio.setPlaybackSpeed'));
    expect(player, contains('await _audio.seek(position);'));
    expect(player, contains('_resumeVideoAtSelectedSpeed(controller)'));
    expect(player, contains('_lastConfirmedVideoSpeed'));
    expect(player, contains('_changingPlaybackSpeed'));
    final sonar = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    expect(sonar, contains('isLive: item.isLive || media.isLive'));
    expect(sonar, contains('speedCategory: MediaPlaybackSpeedCategory.sonartube'));
  });

  test('all locales include new labels with the same placeholder contract', () {
    final files = Directory('lib/l10n').listSync().whereType<File>().where((f) => f.path.endsWith('.arb'));
    for (final file in files) {
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in ['settingsMediaSpeedControl', 'settingsMediaSpeedControlHint', 'mediaPlaybackSpeed', 'mediaPlaybackSpeedNormal', 'mediaPlaybackSpeedUnavailable', 'mediaPlaybackSpeedRecoveryFailed', 'mediaPlaybackSpeedChanged']) {
        expect(arb[key], isA<String>(), reason: '${file.path}: $key');
      }
      expect((arb['@mediaPlaybackSpeedChanged'] as Map)['placeholders'], {'speed': {'type': 'String'}});
    }
  });
}
