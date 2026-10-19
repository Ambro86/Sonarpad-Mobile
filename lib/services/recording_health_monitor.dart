/// Uses actual bytes/media progress, not the elapsed recording timer.
class RecordingHealthMonitor {
  RecordingHealthMonitor(DateTime now) : _lastProgress = now;
  DateTime _lastProgress;
  int _bytes = 0, _mediaMs = 0;
  bool stalled = false;
  Duration idleFor(DateTime now) => now.difference(_lastProgress);
  bool update({
    required DateTime now,
    required int bytes,
    required int mediaMs,
  }) {
    if (bytes > _bytes || mediaMs > _mediaMs) _lastProgress = now;
    _bytes = bytes;
    _mediaMs = mediaMs;
    final next = idleFor(now) >= const Duration(seconds: 60);
    final changed = next != stalled;
    stalled = next;
    return changed;
  }
}
