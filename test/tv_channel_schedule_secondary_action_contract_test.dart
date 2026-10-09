import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/screens/tv_channel_screen.dart';
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


  test(
    'all TV schedule hour fields show time without repeating the selected day',
    () {
      final action = File(
        'lib/widgets/tv_recording_schedule_action.dart',
      ).readAsStringSync();

      expect(action, contains('String _formatScheduledTime(DateTime value)'));
      expect(action, contains("return '\$hour:\$minute';"));
      expect(
        action,
        contains(
          'String scheduleFieldValue(DateTime value) =>\n'
          '                _formatScheduledTime(value);',
        ),
      );
      expect(
        action,
        isNot(
          contains(
            'String scheduleFieldValue(DateTime value) => program == null',
          ),
        ),
      );
      expect(action, contains('radioScheduleStartTimeValue(\n                                  scheduleFieldValue(start),'));
      expect(action, contains('radioScheduleEndTimeValue(\n                                  scheduleFieldValue(end),'));
    },
  );
  test('past TV programs cannot expose schedule recording actions', () {
    final now = DateTime(2026, 10, 7, 2, 30);
    final past = TvProgram(
      title: 'Programma già terminato',
      hour: '01:00',
      startTime: DateTime(2026, 10, 7, 1).millisecondsSinceEpoch ~/ 1000,
      endTime: DateTime(2026, 10, 7, 2).millisecondsSinceEpoch ~/ 1000,
    );
    final current = TvProgram(
      title: 'Programma in onda',
      hour: '02:00',
      startTime: DateTime(2026, 10, 7, 2).millisecondsSinceEpoch ~/ 1000,
      endTime: DateTime(2026, 10, 7, 3).millisecondsSinceEpoch ~/ 1000,
    );
    final future = TvProgram(
      title: 'Programma futuro',
      hour: '03:00',
      startTime: DateTime(2026, 10, 7, 3).millisecondsSinceEpoch ~/ 1000,
      endTime: DateTime(2026, 10, 7, 4).millisecondsSinceEpoch ~/ 1000,
    );

    expect(tvProgramHasEnded(past, now), isTrue);
    expect(tvProgramHasEnded(current, now), isFalse);
    expect(tvProgramHasEnded(future, now), isFalse);
  });

  test('unknown TV program end time is not guessed as already ended', () {
    final program = TvProgram(
      title: 'Orario incompleto',
      hour: '01:00',
      startTime: DateTime(2026, 10, 7, 1).millisecondsSinceEpoch ~/ 1000,
      endTime: 0,
    );

    expect(tvProgramHasEnded(program, DateTime(2026, 10, 7, 5)), isFalse);
  });

  test('TV guide hides schedule recording from ended program rows', () {
    final channel = File(
      'lib/screens/tv_channel_screen.dart',
    ).readAsStringSync();

    expect(channel, contains('final canScheduleRecording ='));
    expect(channel, contains('if (canScheduleRecording)'));
    expect(
      channel,
      contains('_canScheduleProgramRecording(_guide[index])'),
    );
    expect(channel, contains('_scheduleProgramEndRefresh();'));
    expect(channel, contains('_programEndRefreshTimer?.cancel();'));
  });

  test('past TV guide rows retain an iOS VoiceOver activation action', () {
    final source = File('lib/screens/tv_channel_screen.dart').readAsStringSync();

    // The rotor keeps one action for ended programmes, but never schedules
    // a recording there. Normal row activation and the Flutter fallback both
    // continue to open programme details.
    expect(source, contains("if (Platform.isIOS && !canScheduleRecording)"));
    expect(source, contains("id: 'open_program_details'"));
    expect(source, contains("event.action == 'open_program_details'"));
    expect(source, contains('_showProgramDetails(_guide[index]);'));
    expect(source, contains('onTap: () => _showProgramDetails(program)'));
    expect(source, contains('label: _tvGuideActivateLabel(context)'));
    expect(source, contains('if (canScheduleRecording)'));
    expect(source, contains("event.action == 'schedule_recording'"));
    expect(source, contains('Localizations.localeOf(context).languageCode'));
    expect(source, contains("? 'Attiva'"));
  });

}
