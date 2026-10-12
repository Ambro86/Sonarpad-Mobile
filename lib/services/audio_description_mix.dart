const audioDescriptionMp3Bitrates = <int>[64, 96, 128, 192, 256];
const audioDescriptionDefaultBitrateKbps = 192;
const audioDescriptionDefaultSourceVolume = 1.0;

int normalizeAudioDescriptionBitrate(Object? value) =>
    value is num && audioDescriptionMp3Bitrates.contains(value)
    ? value.toInt()
    : audioDescriptionDefaultBitrateKbps;

double normalizeAudioDescriptionSourceVolume(Object? value) =>
    value is num && value.isFinite
    ? value.clamp(0.0, 2.0).toDouble()
    : audioDescriptionDefaultSourceVolume;

/// Apply this only to the prepared source track, before its ducking envelope.
String audioDescriptionSourceVolumeFilter(Object? sourceVolume) =>
    'volume=${normalizeAudioDescriptionSourceVolume(sourceVolume).toStringAsFixed(6)}';

List<String> audioDescriptionMp3EncodingArguments(Object? bitrateKbps) => [
  '-c:a',
  'libmp3lame',
  '-b:a',
  '${normalizeAudioDescriptionBitrate(bitrateKbps)}k',
];

/// Delayed narration inputs contain silence before each cue. FFmpeg's default
/// normalization counts those inputs too and attenuates the entire soundtrack.
String audioDescriptionMixFilter(int inputs) =>
    'amix=inputs=$inputs:duration=longest:dropout_transition=0:normalize=0,'
    'alimiter=limit=0.97:level=false';
