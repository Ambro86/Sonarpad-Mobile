import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Inspect the microphone WAV before music, jingles or stereo export can
/// change its channel layout. Sample short windows even for long recordings.
Future<String> podcastCaptureChannelInfo(File file) async {
  final input = await file.open();
  try {
    final length = await input.length();
    final header = await input.read(12);
    if (header.length != 12 ||
        ascii.decode(header.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(header.sublist(8), allowInvalid: true) != 'WAVE') {
      return 'sourceChannels=unknown';
    }
    var channels = 0, frameSize = 0, bits = 0, encoding = 0;
    for (var offset = 12; offset + 8 <= length;) {
      await input.setPosition(offset);
      final chunk = await input.read(8);
      final id = String.fromCharCodes(chunk.take(4));
      final size = ByteData.sublistView(chunk).getUint32(4, Endian.little);
      final start = offset + 8;
      offset = start + size + (size.isOdd ? 1 : 0);
      if (id == 'fmt ' && size >= 16 && start + 16 <= length) {
        final format = ByteData.sublistView(
          await input.read(math.min(40, size)),
        );
        encoding = format.getUint16(0, Endian.little);
        // WAVE_FORMAT_EXTENSIBLE can also contain ordinary interleaved PCM.
        if (encoding == 0xfffe &&
            format.lengthInBytes >= 40 &&
            format.getUint16(16, Endian.little) >= 22 &&
            format.getUint32(24, Endian.little) == 1) {
          encoding = 1;
        }
        channels = format.getUint16(2, Endian.little);
        frameSize = format.getUint16(12, Endian.little);
        bits = format.getUint16(14, Endian.little);
      }
      if (id != 'data' || channels == 0) continue;
      final info = 'sourceChannels=$channels bits=$bits';
      if (channels != 2 || encoding != 1 || bits != 16 || frameSize != 4) {
        return info;
      }
      final frames = math.min(size, length - start) ~/ frameSize;
      final window = math.min(4096, frames);
      var energy = 0.0, difference = 0.0;
      for (final index in {0, (frames - window) ~/ 2, frames - window}) {
        await input.setPosition(start + frameSize * index);
        final samples = ByteData.sublistView(
          await input.read(frameSize * window),
        );
        for (var i = 0; i + 4 <= samples.lengthInBytes; i += 4) {
          final left = samples.getInt16(i, Endian.little);
          final right = samples.getInt16(i + 2, Endian.little);
          energy += left * left + right * right;
          difference += (left - right) * (left - right);
        }
      }
      if (energy == 0) return '$info sampledLR=silent';
      if (difference == 0) return '$info sampledLR=identical';
      final db = 10 * math.log(difference / energy) / math.ln10;
      return '$info sampledLR=different differenceDb=${db.toStringAsFixed(1)}';
    }
    return 'sourceChannels=unknown';
  } finally {
    await input.close();
  }
}
