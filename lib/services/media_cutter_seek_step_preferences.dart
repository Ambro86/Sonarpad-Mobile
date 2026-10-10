import 'package:shared_preferences/shared_preferences.dart';

/// Persists the existing media cutter move-forward/backward interval.
/// It does not change the media player's seeking behavior.
class MediaCutterSeekStepPreferences {
  static const storageKey = 'sonarpad_media_cutter_seek_step_ms';
  static const defaultStep = Duration(seconds: 5);
  static const allowedSteps = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  static Future<Duration> load() async {
    final preferences = await SharedPreferences.getInstance();
    final milliseconds = preferences.getInt(storageKey);
    for (final step in allowedSteps) {
      if (step.inMilliseconds == milliseconds) {
        return step;
      }
    }
    return defaultStep;
  }

  static Future<void> save(Duration step) async {
    if (!allowedSteps.contains(step)) {
      throw ArgumentError.value(step, 'step', 'Unsupported media cutter step');
    }
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setInt(storageKey, step.inMilliseconds);
    if (!saved) {
      throw StateError('MEDIA_CUTTER_STEP_SAVE_FAILED');
    }
  }
}
