import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android La7 audio-only uses background just_audio while other TV stays unchanged', () {
    final source = File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(source, contains('bool get _useAndroidLa7BackgroundAudio'));
    expect(source, contains('Platform.isAndroid'));
    expect(source, contains("widget.tvChannel!.name.trim().toLowerCase() == 'la7'"));
    expect(source, contains('!_isVideoEnabled'));
    expect(source, contains('if (_useAndroidLa7BackgroundAudio)'));
    expect(source, contains('Android La7 audio-only uses just_audio background/ExoPlayer'));
    expect(source, contains("'engine': 'just_audio_exoplayer'"));
    expect(source, contains('await _audio.setUrl('));
    expect(source, contains('unawaited(_audio.play()'));
    expect(source, contains('Future<void> _recoverAndroidLa7BackgroundAudio('));
    expect(source, contains('android_la7_auto_recovery'));
    expect(source, contains('await _play(reconnecting: true);'));

    final la7Branch = source.indexOf('if (_useAndroidLa7BackgroundAudio)');
    final genericTvBranch = source.indexOf('if (_requiresTvMediaKitPlayback)', la7Branch);
    expect(la7Branch, greaterThanOrEqualTo(0));
    expect(genericTvBranch, greaterThan(la7Branch));
    expect(source, contains("'RadioPlayer: TV MediaKit playback selected '"));
  });

  test('turning La7 video off on Android returns to the background audio engine', () {
    final source = File('lib/screens/radio_player_screen.dart').readAsStringSync();
    expect(source, contains('Future<void> _applyTvMediaKitVideoSetting(bool enable)'));
    expect(source, contains('Audio-only La7 on Android is intentionally handed back'));
    expect(source, contains('await _play();'));
  });

  test('Android manifest keeps the foreground media playback service required by just_audio background', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'));
    expect(manifest, contains('com.ryanheise.audioservice.AudioService'));
    expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
  });
}
