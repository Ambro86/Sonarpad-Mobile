import 'app_settings_service.dart';
import 'raiplay_service.dart';
import 'raiplay_sound_service.dart';
import 'tv_service.dart';

/// Central access check for recording features that must stay hidden unless
/// the user has explicitly unlocked Sonarpad extra features.
class RecordingFeatureAccess {
  const RecordingFeatureAccess._();

  static bool isCodeValid(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    return TvService().isSecretCodeValid(trimmed) ||
        RaiPlayService().isSecretCodeValid(trimmed) ||
        RaiPlaySoundService().isSecretCodeValid(trimmed);
  }

  static Future<bool> isUnlocked() async {
    final code = await AppSettingsService().getTvSecretCode();
    return isCodeValid(code);
  }
}
