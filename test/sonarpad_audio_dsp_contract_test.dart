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
      final sample =
          (0.24 * math.sin(2 * math.pi * 180 * t) +
                  0.10 * math.sin(2 * math.pi * 360 * t))
              .toDouble();
      data[frame * channels] = sample;
      data[frame * channels + 1] = sample;
    }

    final directory = await Directory.systemTemp.createTemp('sonarpad_dsp_');
    final input = File('${directory.path}/input.f32');
    final choirAsset = File('${directory.path}/choir_asset.f32');
    final chorus = File('${directory.path}/chorus.f32');
    final melodicChorus = File('${directory.path}/melodic_chorus.f32');
    final robot = File('${directory.path}/robot.f32');
    final superRobot = File('${directory.path}/super_robot.f32');
    final ghost = File('${directory.path}/ghost.f32');
    final oldRadio = File('${directory.path}/old_radio.f32');
    final megaphone = File('${directory.path}/megaphone.f32');
    final fadeIn = File('${directory.path}/fade_in.f32');
    final fadeOut = File('${directory.path}/fade_out.f32');
    final distortion = File('${directory.path}/distortion.f32');
    final loFi = File('${directory.path}/lofi.f32');
    final reverseEcho = File('${directory.path}/reverse_echo.f32');
    final talkingGuitar = File('${directory.path}/talking_guitar.f32');
    final organVocoder = File('${directory.path}/organ_vocoder.f32');
    try {
      await input.writeAsBytes(data.buffer.asUint8List(), flush: true);
      final assetData = Float32List(frames * channels);
      for (var frame = 0; frame < frames; frame++) {
        final t = frame / sampleRate;
        final sample =
            (0.16 * math.sin(2 * math.pi * 220 * t) +
                    0.12 * math.sin(2 * math.pi * 277.18 * t) +
                    0.10 * math.sin(2 * math.pi * 329.63 * t))
                .toDouble();
        assetData[frame * channels] = sample;
        assetData[frame * channels + 1] = sample;
      }
      await choirAsset.writeAsBytes(
        assetData.buffer.asUint8List(),
        flush: true,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: chorus.path,
        effect: SonarpadDspEffect.chorus,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        assetPath: choirAsset.path,
        outputPath: melodicChorus.path,
        effect: SonarpadDspEffect.chorus,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: robot.path,
        effect: SonarpadDspEffect.robot,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: superRobot.path,
        effect: SonarpadDspEffect.superRobot,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: ghost.path,
        effect: SonarpadDspEffect.ghost,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: oldRadio.path,
        effect: SonarpadDspEffect.oldRadio,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: megaphone.path,
        effect: SonarpadDspEffect.megaphone,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: fadeIn.path,
        effect: SonarpadDspEffect.fadeIn,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: fadeOut.path,
        effect: SonarpadDspEffect.fadeOut,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: distortion.path,
        effect: SonarpadDspEffect.distortion,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: loFi.path,
        effect: SonarpadDspEffect.loFi,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        outputPath: reverseEcho.path,
        effect: SonarpadDspEffect.reverseEcho,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        assetPath: choirAsset.path,
        outputPath: talkingGuitar.path,
        effect: SonarpadDspEffect.talkingGuitar,
        amount: 0.7,
      );
      await SonarpadAudioDsp.processFile(
        inputPath: input.path,
        assetPath: choirAsset.path,
        outputPath: organVocoder.path,
        effect: SonarpadDspEffect.organVocoder,
        amount: 0.7,
      );

      expect(await chorus.length(), await input.length());
      expect(await melodicChorus.length(), await input.length());
      expect(await robot.length(), await input.length());
      expect(await superRobot.length(), await input.length());
      expect(await ghost.length(), await input.length());
      expect(await oldRadio.length(), await input.length());
      expect(await megaphone.length(), await input.length());
      expect(await fadeIn.length(), await input.length());
      expect(await fadeOut.length(), await input.length());
      expect(await distortion.length(), await input.length());
      expect(await loFi.length(), await input.length());
      expect(await reverseEcho.length(), greaterThan(await input.length()));
      expect(await talkingGuitar.length(), await input.length());
      expect(await organVocoder.length(), await input.length());
      expect(
        await chorus.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await melodicChorus.readAsBytes(),
        isNot(equals(await chorus.readAsBytes())),
      );
      expect(
        await robot.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await robot.readAsBytes(),
        isNot(equals(await chorus.readAsBytes())),
      );
      expect(
        await superRobot.readAsBytes(),
        isNot(equals(await robot.readAsBytes())),
      );
      expect(
        await ghost.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await oldRadio.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await megaphone.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await fadeIn.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await fadeOut.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await distortion.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await loFi.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await reverseEcho.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await talkingGuitar.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
      expect(
        await organVocoder.readAsBytes(),
        isNot(equals(await input.readAsBytes())),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
