library;

import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

enum SonarpadDspEffect {
  chorus(1),
  robot(2),
  superRobot(3),
  oldRadio(4),
  alien(5),
  pitchLow(6),
  pitchVeryLow(7),
  pitchHigh(8),
  pitchVeryHigh(9),
  monster(10),
  chipmunk(11),
  brightVoice(12),
  darkVoice(13),
  backwards(14),
  talkingGuitar(15),
  mosquito(16),
  oneOfMany(17),
  organVocoder(18),
  warped(19),
  swirling(21),
  vader(22),
  metallic(23),
  songbird(24),
  exterminator(25),
  rainAndThunder(26),
  jungle(27),
  crowd(28),
  slotMachines(29),
  traffic(30),
  spaceship(31),
  cricket(32),
  siren(33),
  sleighBells(34),
  dj(35),
  applause(36),
  badMelody(37),
  badHarmony(38),
  warmVoice(39),
  turtle(40),
  haunting(41);

  const SonarpadDspEffect(this.id);
  final int id;
}

@Native<
    Int32 Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
      Float,
      Int32,
      Int32,
    )>(symbol: 'sonarpad_dsp_process_file')
external int _processFile(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> assetPath,
  Pointer<Utf8> outputPath,
  int effectId,
  double amount,
  int sampleRate,
  int channels,
);

@Native<Void Function()>(symbol: 'sonarpad_dsp_cancel')
external void _cancel();

@Native<Pointer<Utf8> Function()>(symbol: 'sonarpad_dsp_last_error')
external Pointer<Utf8> _lastError();

@Native<Int32 Function()>(symbol: 'sonarpad_dsp_version')
external int _version();

final class SonarpadAudioDsp {
  const SonarpadAudioDsp._();

  static int get version => _version();

  static void cancelActive() => _cancel();

  static Future<void> processFile({
    required String inputPath,
    String? assetPath,
    required String outputPath,
    required SonarpadDspEffect effect,
    required double amount,
    int sampleRate = 44100,
    int channels = 2,
  }) {
    final normalizedAmount = amount.clamp(0.0, 1.0).toDouble();
    final normalizedAssetPath = assetPath ?? '';
    return Isolate.run(() {
      final input = inputPath.toNativeUtf8();
      final asset = normalizedAssetPath.toNativeUtf8();
      final output = outputPath.toNativeUtf8();
      try {
        final result = _processFile(
          input,
          asset,
          output,
          effect.id,
          normalizedAmount,
          sampleRate,
          channels,
        );
        if (result != 0) {
          final pointer = _lastError();
          final message = pointer == nullptr
              ? 'Errore DSP nativo $result.'
              : pointer.toDartString();
          throw StateError(message.isEmpty ? 'Errore DSP nativo $result.' : message);
        }
      } finally {
        malloc.free(input);
        malloc.free(asset);
        malloc.free(output);
      }
    });
  }
}
