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
}
