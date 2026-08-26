import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SonarTube player actions default to previous and next only', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsService();

    final actions = await settings.loadSonarTubePlayerActions();

    expect(
      actions,
      {
        AppSettingsService.sonarTubePlayerActionPrevious,
        AppSettingsService.sonarTubePlayerActionNext,
      },
    );
  });

  test('an explicitly empty SonarTube player action selection stays empty', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsService();

    await settings.saveSonarTubePlayerActions(<String>{});

    expect(await settings.loadSonarTubePlayerActions(), isEmpty);
  });

  test('settings opens a shared accessible SonarTube player action selector', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final selector = File(
      'lib/screens/sonartube_player_actions_settings_screen.dart',
    ).readAsStringSync();

    expect(settings, contains("id: 'sonartube_player_actions'"));
    expect(settings, contains('l10n.settingsSonarTubePlayerActions'));
    expect(settings, contains("name: '/settings/sonartube-player-actions'"));
    expect(selector, contains('UniversalAccessibleList('));
    expect(selector, contains("kind: 'toggle'"));
    expect(selector, contains('CheckboxListTile('));
  });

  test('selector reuses the existing SonarTube action names', () {
    final selector = File(
      'lib/screens/sonartube_player_actions_settings_screen.dart',
    ).readAsStringSync();

    expect(selector, contains('l10n.sonarTubePreviousTrack'));
    expect(selector, contains('l10n.sonarTubeNextTrack'));
    expect(selector, contains('l10n.sonarTubeShareVideo'));
    expect(selector, contains('l10n.sonarTubeAddFavorite'));
    expect(selector, contains('l10n.sonarTubeGoToChannel'));
    expect(selector, contains('l10n.sonarTubeViewComments'));
    expect(selector, contains('l10n.sonarTubeTranscribeVideo'));
  });

  test('SonarTube passes only selected actions to the shared player', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('loadSonarTubePlayerActions()'));
    expect(source, contains('showPreviousEpisodeAction: playerActions.contains('));
    expect(source, contains('showNextEpisodeAction: playerActions.contains('));
    expect(source, contains('extraActions: extraPlayerActions'));
    expect(source, contains("id: 'view_comments'"));
    expect(source, contains("id: 'transcribe_video'"));
    expect(source, contains('pauseBeforeOpen: true'));
  });

  test('player pauses before actions that open another surface', () {
    final source = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'Future<void> _runExtraAction(PodcastPlayerExtraAction action) async',
    );
    final end = source.indexOf(
      'Future<void> _navigateAdjacentEpisode',
      start,
    );
    final method = source.substring(start, end);

    expect(method, contains('if (action.pauseBeforeOpen)'));
    expect(method, contains('await _pause();'));
    expect(method, contains('await action.onPressed();'));
    expect(method.indexOf('await _pause();'), lessThan(method.indexOf('await action.onPressed();')));
  });

  test('every locale contains the SonarTube player customization title', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'));

    for (final file in arbFiles) {
      expect(
        file.readAsStringSync(),
        contains('"settingsSonarTubePlayerActions"'),
        reason: file.path,
      );
    }
  });
}
