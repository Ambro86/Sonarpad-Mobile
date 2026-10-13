/// Builds a single, non-repeated subtitle for both UIKit and Flutter rows.
/// YouTube Music may return the artist, track type and duration both as
/// structured fields and in its human-readable subtitle.
String sonarMusicItemSubtitle({
  required String title,
  required String kind,
  required String kindLabel,
  String? artist,
  String? duration,
  String? subtitle,
  String Function(String rawDuration)? formatDuration,
}) {
  String normalized(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^[\s.,;:!?…]+|[\s.,;:!?…]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  // These are category descriptors, not titles. The upstream Music response
  // may use a different language or the singular form (e.g. Brani / Brano).
  const kindDescriptors = <String, Set<String>>{
    'song': {'brano', 'brani', 'canzone', 'canzoni', 'song', 'songs',
      'track', 'tracks', 'titre', 'titres', 'canción', 'canciones',
      'música', 'musica', 'músicas', 'utwór', 'utwory', 'skladba',
      'skladby', 'пісня', 'пісні', 'melodie', 'melodii', '歌曲'},
    'video': {'video', 'videos', 'vídeo', 'vídeos', 'video musicali',
      'music video', 'music videos', 'videoclip', 'videoclipuri',
      'musikvideo', 'musikvideos', 'clip', 'clips'},
    'artist': {'artista', 'artisti', 'artist', 'artists', 'artiste',
      'artistes', 'artistas', 'künstler', 'umělec', 'umělci',
      'виконавець', 'виконавці', '艺人'},
    'album': {'album', 'albums', 'álbum', 'álbumes', 'alben',
      'álbuns', 'albumy', 'alba', 'альбом', 'альбоми', '专辑'},
    'playlist': {'playlist', 'playlists', 'playlisty', 'liste',
      'список відтворення', 'плейлисти', '播放列表'},
  };

  // The server sometimes supplies the clock only in the free-form
  // subtitle, not in the dedicated duration field. Extract it once so it
  // can be spoken naturally and never repeated in the metadata.
  final metadata = subtitle?.split(RegExp(r'\s*[•·]\s*')) ?? const <String>[];
  final clockPattern = RegExp(r'^\d+:[0-5]\d(?::[0-5]\d)?$');
  final embeddedClock = metadata
      .map((part) => part.trim())
      .where((part) => clockPattern.hasMatch(part))
      .firstOrNull;
  final clock = duration?.trim().isNotEmpty == true
      ? duration!.trim()
      : embeddedClock;

  final parts = <String>[];
  final seen = <String>{normalized(title)};

  void append(String? raw, {bool fromServer = false}) {
    if (raw == null) return;
    for (final rawPiece in raw.split(RegExp(r'\s*[•·]\s*'))) {
      final piece = rawPiece.trim();
      final key = normalized(piece);
      if (key.isEmpty) continue;
      if (fromServer && clock != null && clockPattern.hasMatch(piece)) {
        continue;
      }
      if (fromServer && (key == normalized(kindLabel) ||
          (kindDescriptors[kind]?.contains(key) ?? false))) {
        continue;
      }
      if (seen.add(key)) parts.add(piece);
    }
  }

  append(kindLabel);
  append(artist);
  if (clock != null) {
    append(formatDuration?.call(clock) ?? clock);
  }
  append(subtitle, fromServer: true);
  return parts.join('. ');
}
