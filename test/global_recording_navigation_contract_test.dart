import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('radio and TV scheduled recordings are owned by a session service', () {
    final service =
        File('lib/services/global_recording_service.dart').readAsStringSync();
    final player =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(service, contains('static final GlobalRecordingService instance'));
    expect(service, contains('Timer? _scheduledStartTimer'));
    expect(service, contains('Timer? _scheduledStopTimer'));
    expect(service, contains('Future<void> _startScheduledRecording()'));
    expect(service, contains('Future<void> _stopScheduledRecording()'));
    expect(service, contains('RadioRecordingService('));
    expect(service, contains('loadChannelsWithCache(secretCode)'));
    expect(service, contains('isSameFavoriteChannel(channel, scheduledChannel)'));
    expect(service, contains('AppSettingsService().getTvSecretCode()'));
    expect(service, contains('result.fromCache'));

    expect(player, contains('GlobalRecordingService.instance'));
    expect(player, contains('_recordingService.schedule('));
    expect(player, contains('_recordingService.removeListener('));
    expect(player, isNot(contains('Timer? _scheduledRecordingStartTimer')));
    expect(player, isNot(contains('Timer? _scheduledRecordingStopTimer')));
  });

  test('leaving the player does not stop the global FFmpeg recording', () {
    final player =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();
    final disposeStart = player.indexOf('  void dispose() {');
    final disposeEnd = player.indexOf(
      '  Future<void> _disposeMediaKitPlayer()',
      disposeStart,
    );
    expect(disposeStart, greaterThanOrEqualTo(0));
    expect(disposeEnd, greaterThan(disposeStart));

    final disposeBody = player.substring(disposeStart, disposeEnd);
    expect(disposeBody, isNot(contains('stopActive(')));
    expect(disposeBody, isNot(contains('cancelSchedule(')));
    expect(disposeBody, contains('removeListener(_onGlobalRecordingChanged)'));
  });
}
