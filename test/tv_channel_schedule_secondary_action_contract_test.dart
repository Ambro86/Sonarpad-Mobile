import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TV channel rows expose the same schedule recording label as player', () {
    final tvScreen = File('lib/screens/tv_screen.dart').readAsStringSync();
    final favorites =
        File('lib/screens/favorite_tvs_screen.dart').readAsStringSync();
    final player =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(tvScreen, contains("id: 'schedule_recording'"));
    expect(tvScreen, contains('l10n.radioScheduleDialogTitle'));
    expect(favorites, contains("id: 'schedule_recording'"));
    expect(favorites, contains('l10n.radioScheduleDialogTitle'));
    expect(player, contains('l10n.radioScheduleDialogTitle'));
  });

  test('TV schedule secondary action uses global recording service', () {
    final action = File('lib/widgets/tv_recording_schedule_action.dart')
        .readAsStringSync();

    expect(action, contains('GlobalRecordingService.instance'));
    expect(action, contains('recordingService.schedule('));
    expect(action, contains('tvRecordingTargetForChannel(channel)'));
    expect(action, contains('radioScheduledRecordingRange('));
  });

  test('TV recording target identity is stable across stream URL refreshes', () {
    final action = File('lib/widgets/tv_recording_schedule_action.dart')
        .readAsStringSync();
    final player =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(action, contains("return 'tv:tvg:\$tvgId';"));
    expect(action, contains("return 'tv:resolver:\$resolver:\$resolverId';"));
    expect(action, contains("return 'tv:name:"));
    expect(player, contains('tvRecordingTargetForChannel('));
    expect(player, isNot(contains("'tv:\${widget.tvChannel!.url}|")));
  });
}
