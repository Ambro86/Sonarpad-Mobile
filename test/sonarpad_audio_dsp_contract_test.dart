import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_audio_dsp/sonarpad_audio_dsp.dart';

void main() {
  test('native DSP preserves PCM length and produces finite audio', () async {
    const sampleRate = 44100;
    const channels = 2;
    const frames = sampleRate ~/ 2;
    final data = Float32List(frames * channels);
    for (var frame = 0; frame < frames; frame++) {
      final t = frame / sampleRate;
      final sample = (0.24 * math.sin(2 * math.pi * 180 * t) +
              0.10 * math.sin(2 * math.pi * 360 * t))
          .toDouble();
      data[frame * channels] = sample;
      data[frame * channels + 1] = sample;
    }

    final directory = await Directory.systemTemp.createTemp('sonarpad_dsp_');
    final input = File('${directory.path}/input.f32');
    final chorus = File('${directory.path}/chorus.f32');
    final robot = File('${directory.path}/robot.f32');
    try {
      await input.writeAsBytes(data.buffer.asUint8List(), flush: true);
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: chorus.path,
        effect: SonarpadDspEffect.chorus,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: robot.path,
        effect: SonarpadDspEffect.robot,
        amount: 0.7,
      );

      expect(await chorus.length(), await input.length());
      expect(await robot.length(), await input.length());
      expect(await chorus.readAsBytes(), isNot(equals(await input.readAsBytes())));
      expect(await robot.readAsBytes(), isNot(equals(await input.readAsBytes())));
      expect(await robot.readAsBytes(), isNot(equals(await chorus.readAsBytes())));
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
