import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';
import 'package:sonarpad_mobile_starter/widgets/tv_recording_schedule_action.dart';

void main() {
  test(
    'TV channel rows expose the same schedule recording label as player',
    () {
      final tvScreen = File('lib/screens/tv_screen.dart').readAsStringSync();
      final favorites = File(
        'lib/screens/favorite_tvs_screen.dart',
      ).readAsStringSync();
      final player = File(
        'lib/screens/radio_player_screen.dart',
      ).readAsStringSync();

      expect(tvScreen, contains("id: 'schedule_recording'"));
      expect(tvScreen, contains('l10n.radioScheduleDialogTitle'));
      expect(favorites, contains("id: 'schedule_recording'"));
      expect(favorites, contains('l10n.radioScheduleDialogTitle'));
      expect(player, contains('l10n.radioScheduleDialogTitle'));
    },
  );

  test('TV schedule secondary action uses global recording service', () {
    final action = File(
      'lib/widgets/tv_recording_schedule_action.dart',
    ).readAsStringSync();

    expect(action, contains('GlobalRecordingService.instance'));
    expect(action, contains('recordingService.schedule('));
    expect(action, contains('tvRecordingTargetForChannel(channel)'));
    expect(action, contains('radioScheduledRecordingRange('));
  });

  test(
    'TV program rows expose recording as secondary and visual-only action',
    () {
      final channel = File(
        'lib/screens/tv_channel_screen.dart',
      ).readAsStringSync();

      expect(channel, contains("id: 'schedule_recording'"));
      expect(channel, contains("icon: 'record'"));
      expect(channel, contains('customSemanticsActions:'));
      expect(channel, contains('child: ExcludeSemantics('));
      expect(channel, contains('program: program'));
    },
  );

  test('TV program recording range adds ten minutes at both ends', () {
    final programStart = DateTime(2026, 8, 26, 16, 29);
    final programEnd = DateTime(2026, 8, 26, 17, 17);
    final program = TvProgram(
      title: 'La casa nella prateria',
      hour: '16:29',
      startTime: programStart.millisecondsSinceEpoch ~/ 1000,
      endTime: programEnd.millisecondsSinceEpoch ~/ 1000,
    );

    expect(tvProgramRecordingStart(program), DateTime(2026, 8, 26, 16, 19));
    expect(tvProgramRecordingEnd(program), DateTime(2026, 8, 26, 17, 27));
  });

  test('TV recording day choices run from today through five days ahead', () {
    final today = DateTime(2026, 8, 26, 18, 30);
    final choices = tvRecordingDayChoices(today);

    expect(choices, hasLength(6));
    expect(choices.first, DateTime(2026, 8, 26));
    expect(choices[1], DateTime(2026, 8, 27));
    expect(choices[2], DateTime(2026, 8, 28));
    expect(choices.last, DateTime(2026, 8, 31));
    expect(formatTvRecordingDayLabel(choices.first, today), 'Oggi');
    expect(formatTvRecordingDayLabel(choices[1], today), 'Domani');
    expect(formatTvRecordingDayLabel(choices[2], today), 'Dopodomani');
  });

  test(
    'TV recording target identity is stable across stream URL refreshes',
    () {
      final action = File(
        'lib/widgets/tv_recording_schedule_action.dart',
      ).readAsStringSync();
      final player = File(
        'lib/screens/radio_player_screen.dart',
      ).readAsStringSync();

      expect(action, contains("return 'tv:tvg:\$tvgId';"));
      expect(action, contains("return 'tv:resolver:\$resolver:\$resolverId';"));
      expect(action, contains("return 'tv:name:"));
      expect(player, contains('tvRecordingTargetForChannel('));
      expect(player, isNot(contains("'tv:\${widget.tvChannel!.url}|")));
    },
  );
}
