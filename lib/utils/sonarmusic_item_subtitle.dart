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

  final parts = <String>[];
  final seen = <String>{normalized(title)};

  void append(String? raw, {bool fromServer = false}) {
    if (raw == null) return;
    for (final rawPiece in raw.split(RegExp(r'\s*[•·]\s*'))) {
      final piece = rawPiece.trim();
      final key = normalized(piece);
      if (key.isEmpty) continue;
      if (fromServer && (key == normalized(kindLabel) ||
          (kindDescriptors[kind]?.contains(key) ?? false))) {
        continue;
      }
      if (seen.add(key)) parts.add(piece);
    }
  }

  append(kindLabel);
  append(artist);
  append(duration);
  append(subtitle, fromServer: true);
  return parts.join(' · ');
}
