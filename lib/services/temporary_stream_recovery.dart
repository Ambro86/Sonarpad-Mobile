/// Bounded recovery for signed YouTube media URLs. Caller owns the player.
class TemporaryStreamRecovery {
  int attempts = 0;
  Duration? _position;
  DateTime? _progressAt;
  DateTime? _pausedAt;

  String? observe({
    required DateTime now,
    required Duration position,
    required Duration duration,
    required bool playing,
    bool completed = false,
    bool failed = false,
  }) {
    if (attempts >= 2) {
      return null;
    }
    final empty =
        completed &&
        duration > const Duration(seconds: 5) &&
        position < const Duration(seconds: 1);
    if ((completed && !empty) ||
        (duration > Duration.zero &&
            position >= duration - const Duration(seconds: 1))) {
      _progressAt = now;
      return null;
    }
    String? reason;
    if (failed || empty) {
      reason = 'player-error';
    } else if (!playing) {
      _pausedAt ??= now;
      _progressAt = now;
      return null;
    } else if (_pausedAt != null) {
      if (now.difference(_pausedAt!) >= const Duration(minutes: 10)) {
        reason = 'long-pause';
      }
      _pausedAt = null;
      _progressAt = now;
    } else if (_position == null ||
        (position - _position!).inMilliseconds.abs() >= 500) {
      _progressAt = now;
    } else if (_progressAt != null &&
        now.difference(_progressAt!) >= const Duration(seconds: 20)) {
      reason = 'stalled';
    }
    _position = position;
    _progressAt ??= now;
    if (reason != null) {
      attempts++;
      _progressAt = now;
    }
    return reason;
  }
}
