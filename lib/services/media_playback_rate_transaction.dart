import '../models/media_playback_speed.dart';

/// One already-initialized playback engine. No global player state is used.
class MediaPlaybackRateTarget {
  const MediaPlaybackRateTarget({
    required this.previousRate,
    required this.setRate,
  });

  final double previousRate;
  final Future<void> Function(double) setRate;
}

class MediaPlaybackRateException implements Exception {
  const MediaPlaybackRateException(this.cause, {required this.rollbackFailed});

  final Object cause;
  final bool rollbackFailed;

  @override
  String toString() =>
      'media_playback_rate_failed rollbackFailed=$rollbackFailed cause=$cause';
}

/// Applies one rate to every engine, restoring ALL previous rates on failure.
/// A video backend may only validate a rate when playback resumes, so resume
/// belongs to [afterApply] and is covered by the same rollback transaction.
Future<void> applyMediaPlaybackRate({
  required double rate,
  required List<MediaPlaybackRateTarget> targets,
  Future<void> Function()? afterApply,
  Future<void> Function()? beforeRollback,
}) async {
  if (!rate.isFinite || !mediaPlaybackSpeeds.contains(rate)) {
    throw ArgumentError.value(rate, 'rate', 'media_playback_rate_invalid');
  }
  try {
    for (final target in targets) {
      await target.setRate(rate);
    }
    await afterApply?.call();
  } catch (error) {
    var rollbackFailed = false;
    try {
      await beforeRollback?.call();
    } catch (_) {
      rollbackFailed = true;
    }
    // Include the failing target: some plugins update their Dart-side value
    // before throwing a platform error. Also keep trying if one restore fails.
    for (final target in targets.reversed) {
      try {
        await target.setRate(target.previousRate);
      } catch (_) {
        rollbackFailed = true;
      }
    }
    throw MediaPlaybackRateException(error, rollbackFailed: rollbackFailed);
  }
}
