import 'podcast.dart';

class ChromecastMedia {
  const ChromecastMedia(this.url, this.mime);
  final String url, mime;

  static ChromecastMedia? fromEpisode(
    PodcastEpisode episode, {
    required bool video,
  }) {
    // Separate tracks need muxing; never silently drop the selected audio.
    if (video &&
        episode.videoUrl != null &&
        episode.videoUrl != episode.audioUrl) {
      return null;
    }
    final url = video ? episode.videoUrl ?? episode.audioUrl : episode.audioUrl;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    final path = uri.path.toLowerCase();
    final hint = uri.queryParameters['mime'];
    final mime =
        hint != null &&
            RegExp(r'^(audio|video)/[a-zA-Z0-9.+-]+$').hasMatch(hint)
        ? hint
        : path.endsWith('.m3u8')
        ? 'application/x-mpegURL'
        : path.endsWith('.mpd')
        ? 'application/dash+xml'
        : path.endsWith('.mp4')
        ? 'video/mp4'
        : path.endsWith('.m4a')
        ? 'audio/mp4'
        : path.endsWith('.aac')
        ? 'audio/aac'
        : path.endsWith('.ogg') || path.endsWith('.opus')
        ? 'audio/ogg'
        : path.endsWith('.webm')
        ? (video ? 'video/webm' : 'audio/webm')
        : path.endsWith('.wav')
        ? 'audio/wav'
        : path.endsWith('.flac')
        ? 'audio/flac'
        : video
        ? 'video/mp4'
        : 'audio/mpeg';
    return ChromecastMedia(url, mime);
  }
}
