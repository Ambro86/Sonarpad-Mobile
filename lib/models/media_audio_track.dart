/// One playable language/variant, independent of codec and bitrate variants.
class MediaAudioTrack {
  const MediaAudioTrack({
    required this.id,
    required this.label,
    required this.url,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String url;
  final bool isDefault;

  static bool _playable(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  static List<MediaAudioTrack> fromServer(Object? value) {
    if (value is! List) return const [];
    final tracks = <String, MediaAudioTrack>{};
    for (final entry in value) {
      if (entry is! Map) continue;
      final id = entry['id']?.toString() ?? '';
      final url = entry['url']?.toString() ?? '';
      if (id.isEmpty || !_playable(url)) continue;
      final label = entry['label']?.toString().trim() ?? '';
      tracks.putIfAbsent(
        id,
        () => MediaAudioTrack(
          id: id,
          label: label.isEmpty ? id : label,
          url: url,
          isDefault: entry['is_default'] == true,
        ),
      );
    }
    return tracks.values.toList(growable: false);
  }

  static List<MediaAudioTrack> fromYouTube(Map<String, dynamic> streaming) {
    final chosen = <String, Map>{};
    final formats = streaming['adaptiveFormats'];
    if (formats is! List) return const [];
    int bitrate(Map format) =>
        format['bitrate'] is num ? (format['bitrate'] as num).toInt() : 0;
    for (final format in formats) {
      if (format is! Map) continue;
      final track = format['audioTrack'];
      final mime = format['mimeType']?.toString() ?? '';
      final url = format['url']?.toString() ?? '';
      if (track is! Map || !mime.startsWith('audio/') || !_playable(url)) {
        continue;
      }
      final id = track['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final previous = chosen[id];
      final mp4 = mime.startsWith('audio/mp4');
      final previousMp4 = previous?['mimeType']?.toString().startsWith(
        'audio/mp4',
      );
      if (previous == null ||
          (mp4 && previousMp4 != true) ||
          (mp4 == previousMp4 && bitrate(format) > bitrate(previous))) {
        chosen[id] = format;
      }
    }
    return chosen.entries
        .map((entry) {
          final track = entry.value['audioTrack'] as Map;
          final label = track['displayName']?.toString().trim() ?? '';
          return MediaAudioTrack(
            id: entry.key,
            label: label.isEmpty ? entry.key : label,
            url: entry.value['url'] as String,
            isDefault: track['audioIsDefault'] == true,
          );
        })
        .toList(growable: false);
  }
}
