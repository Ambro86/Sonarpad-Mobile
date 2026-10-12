import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_mix.dart';

void main() {
  bool available;
  try {
    available = Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } catch (_) {
    available = false;
  }
  test(
    'delayed narration tracks do not reduce the original soundtrack',
    () async {
      Future<double> render(int voices) async {
        final inputs = voices + 1;
        final filter = StringBuffer('[0:a]asplit=$inputs');
        for (var i = 0; i < inputs; i++) {
          filter.write('[a$i]');
        }
        filter.write(';');
        for (var i = 1; i < inputs; i++) {
          filter.write('[a$i]adelay=2000[b$i];');
        }
        filter.write('[a0]');
        for (var i = 1; i < inputs; i++) {
          filter.write('[b$i]');
        }
        filter.write(audioDescriptionMixFilter(inputs));
        final result = await Process.run('ffmpeg', [
          '-v',
          'error',
          '-f',
          'lavfi',
          '-i',
          'aevalsrc=0.25:s=48000:d=1',
          '-filter_complex',
          filter.toString(),
          '-t',
          '0.5',
          '-f',
          'f32le',
          'pipe:1',
        ], stdoutEncoding: null);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        final data = ByteData.sublistView(
          Uint8List.fromList(result.stdout as List<int>),
        );
        double sum = 0;
        // Exclude the limiter's initial lookahead delay.
        for (var i = 4800; i < data.lengthInBytes ~/ 4; i++) {
          final sample = data.getFloat32(i * 4, Endian.little);
          sum += sample * sample;
        }
        return math.sqrt(sum / (data.lengthInBytes ~/ 4 - 4800));
      }

      final oneVoice = await render(1);
      final manyVoices = await render(32);
      expect(oneVoice, closeTo(0.25, 0.001));
      expect(manyVoices, closeTo(oneVoice, 0.001));
    },
    skip: available ? false : 'Requires the FFmpeg executable',
  );
  test('source gain scales only the film while narration and ducking stay independent', () async {
    Future<List<double>> levels(double sourceVolume) async {
      final filter =
          '[0:a]${audioDescriptionSourceVolumeFilter(sourceVolume)}[source];'
          "[source]volume='if(between(t,1,2),0.25,1)':eval=frame[base];"
          '[1:a]adelay=1000[voice];'
          '[base][voice]${audioDescriptionMixFilter(2)}';
      final result = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'aevalsrc=0.2:s=48000:d=3',
        '-f',
        'lavfi',
        '-i',
        'aevalsrc=0.1:s=48000:d=1',
        '-filter_complex',
        filter,
        '-t',
        '3',
        '-ac',
        '1',
        '-ar',
        '48000',
        '-f',
        'f32le',
        'pipe:1',
      ], stdoutEncoding: null);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final samples = ByteData.sublistView(
        Uint8List.fromList(result.stdout as List<int>),
      );
      double average(double second) {
        final start = (second * 48000).round();
        const count = 4800;
        var sum = 0.0;
        for (var index = start; index < start + count; index++) {
          sum += samples.getFloat32(index * 4, Endian.little);
        }
        return sum / count;
      }

      return [average(0.4), average(1.4), average(2.4)];
    }

    final normal = await levels(1);
    final reduced = await levels(0.5);
    final muted = await levels(0);
    final amplified = await levels(2);
    expect(normal[0], closeTo(0.2, 0.001));
    expect(normal[1], closeTo(0.15, 0.001));
    expect(normal[2], closeTo(0.2, 0.001));
    expect(reduced[0], closeTo(0.1, 0.001));
    expect(reduced[1], closeTo(0.125, 0.001));
    expect(reduced[2], closeTo(0.1, 0.001));
    expect(muted[0], closeTo(0, 0.001));
    expect(muted[1], closeTo(0.1, 0.001));
    expect(muted[2], closeTo(0, 0.001));
    expect(amplified[0], closeTo(0.4, 0.001));
    expect(amplified[1], closeTo(0.2, 0.001));
    expect(amplified[2], closeTo(0.4, 0.001));
  }, skip: available ? false : 'Requires the FFmpeg executable');

  test('final MP3 encoder produces every selected bitrate even without narration', () async {
    final dir = await Directory.systemTemp.createTemp('sonarpad-mp3-bitrates-');
    addTearDown(() => dir.delete(recursive: true));
    for (final bitrate in [...audioDescriptionMp3Bitrates, null]) {
      final output = '${dir.path}/${bitrate ?? 'default'}.mp3';
      final encoded = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=48000:duration=1',
        '-af',
        '${audioDescriptionSourceVolumeFilter(0.5)},${audioDescriptionMixFilter(1)}',
        '-ac',
        '2',
        ...audioDescriptionMp3EncodingArguments(bitrate),
        output,
      ]);
      expect(encoded.exitCode, 0, reason: '${encoded.stderr}');
      final probed = await Process.run('ffprobe', [
        '-v',
        'error',
        '-select_streams',
        'a:0',
        '-show_entries',
        'stream=codec_name,bit_rate',
        '-of',
        'json',
        output,
      ]);
      expect(probed.exitCode, 0, reason: '${probed.stderr}');
      final stream =
          ((jsonDecode(probed.stdout as String) as Map)['streams'] as List)
                  .single
              as Map;
      expect(stream['codec_name'], 'mp3');
      expect(int.parse(stream['bit_rate'] as String), (bitrate ?? 192) * 1000);
    }
  }, skip: available ? false : 'Requires FFmpeg and FFprobe executables');
}
