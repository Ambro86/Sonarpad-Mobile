import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

class _ResolvedMusic extends SonarMusicService {
  _ResolvedMusic(this.media);
  final SonarTubeResolvedMedia media;
  @override
  Future<SonarTubeResolvedMedia> resolve(SonarMusicItem song) async => media;
}

void main() {
  test('music export combines catalog artist and title, preserving streams', () async {
    const media = SonarTubeResolvedMedia(title: 'Artist', audioUrl: 'audio',
      videoUrl: 'video', channel: 'Artist - Topic', isLive: true,
      selectedAudioTrackId: 'original');
    final result = await SonarMusicTubeAdapter(_ResolvedMusic(media)).resolve(
      const SonarTubeItem(kind: SonarTubeItemKind.video, id: 'id', url: 'https://music.youtube.com/watch?v=id',
        title: 'Song', channel: 'Artist'));
    expect(result.title, 'Artist - Song');
    expect(result.audioUrl, media.audioUrl);
    expect(result.videoUrl, media.videoUrl);
    expect(result.channel, media.channel);
    expect(result.isLive, media.isLive);
    expect(result.audioTracks, same(media.audioTracks));
    expect(result.selectedAudioTrackId, media.selectedAudioTrackId);
  });

  test('music export handles complete titles and missing catalog metadata', () async {
    for (final entry in [
      ('Artist - Song', 'Artist', 'ignored', 'Artist - Song'),
      ('artist – Song', 'Artist', 'ignored', 'artist – Song'),
      ('Song — Artist', 'Artist', 'ignored', 'Song — Artist'),
      ('Song', '', '', 'Resolved artist - Song'),
      ('YouTube Music', '', 'Resolved song', 'Resolved artist - Resolved song'),
      ('id', '', 'Resolved song', 'Resolved artist - Resolved song'),
    ]) {
      final adapter = SonarMusicTubeAdapter(_ResolvedMusic(
        SonarTubeResolvedMedia(title: entry.$3, audioUrl: 'audio',
          channel: 'Resolved artist')));
      final result = await adapter.resolve(SonarTubeItem(
        kind: SonarTubeItemKind.video, id: 'id', url: 'https://music.youtube.com/watch?v=id', title: entry.$1, channel: entry.$2));
      expect(result.title, entry.$4);
    }
    final adapter = SonarMusicTubeAdapter(_ResolvedMusic(
      const SonarTubeResolvedMedia(title: 'Song', audioUrl: 'audio')));
    final result = await adapter.resolve(const SonarTubeItem(
      kind: SonarTubeItemKind.video, id: 'id', url: 'https://music.youtube.com/watch?v=id', title: 'Song'));
    expect(result.title, 'Song');
  });
}
