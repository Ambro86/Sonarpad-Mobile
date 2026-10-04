/// Preferences for recorded media only. These never affect TTS or live radio/TV.
enum MediaPlaybackSpeedCategory { media, podcasts, sonartube, audiobooks }

const mediaPlaybackSpeeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

double normalizeMediaPlaybackSpeed(double? value) =>
    value != null && value.isFinite && mediaPlaybackSpeeds.contains(value)
        ? value
        : 1.0;
