import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/pyannote_pcm_reader.dart';

void main() {
  test(
    'PCM isolate reads overlapping windows while caller keeps file open',
    () async {
      final dir = await Directory.systemTemp.createTemp('pyannote-pcm-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/analysis.wav');
      const offset = 78; // The failing device log has a nonstandard WAV header.
      const samples = [-32768, -16384, 0, 16384, 32767];
      final bytes = ByteData(offset + samples.length * 2);
      for (var i = 0; i < samples.length; i++) {
        bytes.setInt16(offset + i * 2, samples[i], Endian.little);
      }
      await file.writeAsBytes(bytes.buffer.asUint8List());
      final openFile = await file.open();
      addTearDown(openFile.close);
      await openFile.setPosition(3);

      final batch = await readPyannotePcmBatch(
        wavPath: file.path,
        dataOffset: offset,
        sampleCount: samples.length,
        windowSamples: 4,
        starts: [0, 2, 5],
      );

      expect(batch, [
        -1.0,
        -0.5,
        0.0,
        0.5,
        0.0,
        0.5,
        32767 / 32768,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
      ]);
      expect(await openFile.position(), 3);
      expect(await openFile.length(), bytes.lengthInBytes);
    },
  );

  test('PCM isolate propagates file errors to the caller', () async {
    final dir = await Directory.systemTemp.createTemp('pyannote-pcm-missing-');
    addTearDown(() => dir.delete(recursive: true));
    await expectLater(
      readPyannotePcmBatch(
        wavPath: '${dir.path}/missing.wav',
        dataOffset: 44,
        sampleCount: 4,
        windowSamples: 4,
        starts: [0],
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
