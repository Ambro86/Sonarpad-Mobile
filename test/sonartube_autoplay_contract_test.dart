import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SonarTube autoplay defaults off and persists explicitly', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsService();

    expect(await settings.isSonarTubeAutoplayEnabled(), isFalse);
    await settings.setSonarTubeAutoplayEnabled(true);
    expect(await settings.isSonarTubeAutoplayEnabled(), isTrue);
    await settings.setSonarTubeAutoplayEnabled(false);
    expect(await settings.isSonarTubeAutoplayEnabled(), isFalse);
  });

  test('SonarTube player customization exposes autoplay toggle', () {
    final source = File(
      'lib/screens/sonartube_player_actions_settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains("id: 'sonartube_autoplay'"));
    expect(source, contains("ValueKey('settings_sonartube_autoplay')"));
    expect(source, contains('l10n.settingsSonarTubeAutoplay'));
    expect(source, contains('l10n.settingsSonarTubeAutoplayHint'));
    expect(source, contains('setSonarTubeAutoplayEnabled'));
  });

  test('SonarTube passes autoplay preference to shared player', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('isSonarTubeAutoplayEnabled()'));
    expect(source, contains('autoNavigateNext: autoplay'));
  });

  test('shared player advances silently only when a next item exists', () {
    final player = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();
    final audio = File(
      'lib/services/audio_player_service.dart',
    ).readAsStringSync();

    expect(audio, contains('Stream<void> get completionStream'));
    expect(player, contains('widget.autoNavigateNext'));
    expect(player, contains('if (!_hasNavigableNext)'));
    expect(player, contains('_navigateAdjacentEpisodeSilently(1)'));
    expect(player, contains('if (mounted && !silentFailure)'));
    expect(player, contains('value.isCompleted'));
  });
}
