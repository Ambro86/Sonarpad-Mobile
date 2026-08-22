import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Media Cutter routes curated effects through native DSP', () {
    final source = File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    expect(source, contains("package:sonarpad_audio_dsp/sonarpad_audio_dsp.dart"));
    expect(source, contains('SonarpadDspEffect.chorus'));
    expect(source, contains('SonarpadDspEffect.robot'));
    expect(source, contains('SonarpadDspEffect.superRobot'));
    expect(source, contains('SonarpadDspEffect.oldRadio'));
    expect(source, contains('SonarpadDspEffect.talkingGuitar'));
    expect(source, contains('SonarpadDspEffect.organVocoder'));
    expect(source, contains('_renderNativeDspPcm'));
    expect(source, contains('DSP PCM extraction'));
    expect(source, contains('_postNativeDspFilter'));
    expect(source, contains('_processNativeDspStep'));
    expect(source, contains('SonarpadAudioDsp.cancelActive'));
    expect(source, contains('itemCount: _availableEffects.length'));
    expect(source, isNot(contains('itemCount: _MediaPartEffect.values.length')));
  });
}
