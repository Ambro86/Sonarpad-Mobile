import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/temporary_stream_recovery.dart';

void main() {
  test('stalled playback recovers at most twice', () {
    final policy = TemporaryStreamRecovery();
    String? observe(int time) => policy.observe(
      now: DateTime(2026).add(Duration(seconds: time)),
      position: const Duration(seconds: 12),
      duration: const Duration(seconds: 245),
      playing: true,
    );
    expect(observe(0), isNull);
    expect(observe(19), isNull);
    expect(observe(20), 'stalled');
    expect(observe(40), 'stalled');
    expect(observe(60), isNull);
  });
  test('pause is silent and long resume renews URLs', () {
    final policy = TemporaryStreamRecovery();
    String? observe(int time, bool playing) => policy.observe(
      now: DateTime(2026).add(Duration(seconds: time)),
      position: const Duration(seconds: 12),
      duration: const Duration(seconds: 245),
      playing: playing,
    );
    expect(observe(0, false), isNull);
    expect(observe(590, false), isNull);
    expect(observe(601, true), 'long-pause');
    expect(observe(602, true), isNull);
  });
  test(
    'empty early completion recovers instead of treating the track as finished',
    () {
      final policy = TemporaryStreamRecovery();
      expect(
        policy.observe(
          now: DateTime(2026),
          position: Duration.zero,
          duration: const Duration(seconds: 245),
          playing: false,
          completed: true,
        ),
        'player-error',
      );
    },
  );
  test('completed media is never restarted', () {
    final policy = TemporaryStreamRecovery();
    for (final time in [0, 30, 60]) {
      expect(
        policy.observe(
          now: DateTime(2026).add(Duration(seconds: time)),
          position: const Duration(seconds: 245),
          duration: const Duration(seconds: 245),
          playing: true,
          completed: true,
        ),
        isNull,
      );
    }
    expect(policy.attempts, 0);
  });
  test('normal progress and short pause do not cause recovery', () {
    final policy = TemporaryStreamRecovery();
    for (var time = 0; time < 30; time++) {
      expect(
        policy.observe(
          now: DateTime(2026).add(Duration(seconds: time)),
          position: Duration(seconds: time),
          duration: const Duration(seconds: 245),
          playing: time != 10,
        ),
        isNull,
      );
    }
  });
}
