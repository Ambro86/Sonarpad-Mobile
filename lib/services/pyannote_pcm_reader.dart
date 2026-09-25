import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// Keep the isolate closure outside the analyzer's scope: it must never capture
/// its open WAV file, ONNX session or progress callback.
Future<Float32List> readPyannotePcmBatch({
  required String wavPath,
  required int dataOffset,
  required int sampleCount,
  required int windowSamples,
  required List<int> starts,
}) async {
  final transfer = await Isolate.run(
    () => _readBatch(
      wavPath: wavPath,
      dataOffset: dataOffset,
      sampleCount: sampleCount,
      windowSamples: windowSamples,
      starts: starts,
    ),
  );
  return transfer.materialize().asFloat32List();
}

Future<TransferableTypedData> _readBatch({
  required String wavPath,
  required int dataOffset,
  required int sampleCount,
  required int windowSamples,
  required List<int> starts,
}) async {
  final batch = Float32List(starts.length * windowSamples);
  final file = await File(wavPath).open(mode: FileMode.read);
  try {
    for (var row = 0; row < starts.length; row++) {
      final startSample = starts[row];
      if (startSample >= sampleCount) continue;
      final available = math.min(windowSamples, sampleCount - startSample);
      await file.setPosition(dataOffset + startSample * 2);
      final bytes = await file.read(available * 2);
      final targetOffset = row * windowSamples;
      for (var i = 0; i < bytes.length ~/ 2; i++) {
        var raw = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
        if ((raw & 0x8000) != 0) raw -= 0x10000;
        batch[targetOffset + i] = raw / 32768.0;
      }
    }
    return TransferableTypedData.fromList([batch.buffer.asUint8List()]);
  } finally {
    await file.close();
  }
}
