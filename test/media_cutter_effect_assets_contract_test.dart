import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active hybrid DSP effect assets are packaged and mapped', () {
    const assets = <String>[
      'choir_bed.mp3',
      'old_radio_static.mp3',
      'rain_thunder.mp3',
      'jungle_ambience.mp3',
      'crowd_ambience.mp3',
      'slot_machines.mp3',
      'traffic_ambience.mp3',
      'crickets.mp3',
      'sleigh_bells.mp3',
      'applause.mp3',
    ];
    final source = File(
      'lib/screens/media_cutter_screen.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final ffi = File(
      'packages/sonarpad_audio_dsp/lib/sonarpad_audio_dsp.dart',
    ).readAsStringSync();
    final cpp = File(
      'packages/sonarpad_audio_dsp/src/sonarpad_audio_dsp.cpp',
    ).readAsStringSync();

    expect(pubspec, isNot(contains('- assets/audio/effect_sources/\n')));
    for (final name in assets) {
      final file = File('assets/audio/effect_sources/$name');
      expect(file.existsSync(), isTrue, reason: name);
      expect(file.lengthSync(), greaterThan(10000), reason: name);
      expect(source, contains(name), reason: 'mapping $name');
      expect(
        pubspec,
        contains('assets/audio/effect_sources/$name'),
        reason: 'packaged $name',
      );
    }
    expect(pubspec, isNot(contains('guitar_carrier.mp3')));
    expect(pubspec, isNot(contains('organ_carrier.mp3')));
    expect(source, contains('_ensureNativeDspAssetPcmPath'));
    expect(source, contains('assetPath: assetPath'));
    expect(ffi, contains('String? assetPath'));
    expect(cpp, contains('class AssetLoop'));
    expect(cpp, contains('chorusWithAsset'));
    expect(cpp, contains('ambienceAsset'));
  });
}
