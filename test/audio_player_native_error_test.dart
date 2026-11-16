import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';
import 'package:sonarpad_mobile_starter/utils/app_logger.dart';
import 'audio_voice_preview_test.dart' show PreviewPlayer;

class _ErrorPlayer extends PreviewPlayer {
  final errors = StreamController<PlayerException>.broadcast(sync: true);
  @override
  Stream<PlayerException> get errorStream => errors.stream;
}
class _LogPaths extends PathProviderPlatform {
  _LogPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native playback errors are logged without signed URLs and listener is released', () async {
    SharedPreferences.setMockInitialValues({});
    final folder = await Directory.systemTemp.createTemp('sonarpad-error-log-');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _LogPaths(folder.path);
    final player = _ErrorPlayer();
    final service = AudioPlayerService(player: player, isAndroid: true);
    try {
      player.errors.add(PlayerException(1002,
        'BehindLiveWindowException https://example.org/live?signature=secret-test', 0));
      final log = await AppLogger.readLogs();
      expect(log, contains('native player error code=1002'));
      expect(log, contains('BehindLiveWindowException'));
      expect(log, isNot(contains('secret-test')));
      await service.dispose();
      expect(player.errors.hasListener, isFalse);
    } finally {
      await service.dispose();
      await player.errors.close();
      await AppLogger.readLogs();
      PathProviderPlatform.instance = original;
      await folder.delete(recursive: true);
    }
  });
}
