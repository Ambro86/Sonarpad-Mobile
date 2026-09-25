/// Delayed narration inputs contain silence before each cue. FFmpeg's default
/// normalization counts those inputs too and attenuates the entire soundtrack.
String audioDescriptionMixFilter(int inputs) =>
    'amix=inputs=$inputs:duration=longest:dropout_transition=0:normalize=0,'
    'alimiter=limit=0.97:level=false';
