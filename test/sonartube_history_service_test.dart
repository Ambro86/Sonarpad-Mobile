import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_history_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

SonarTubeItem video(int index, {String? url}) => SonarTubeItem(
  kind: SonarTubeItemKind.video,
  id: 'video_${index.toString().padLeft(5, '0')}',
  title: 'Video $index',
  url: url ?? 'https://www.youtube.com/watch?v=video_$index',
  channel: 'Canale $index',
  duration: '${index + 1}:00',
);

void main() {
  test('recent SonarTube videos are newest first and duplicate opens move to the top', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeHistoryService();

    await service.addRecentVideo(video(1));
    await service.addRecentVideo(video(2));
    await service.addRecentVideo(video(1));

    final recent = await service.loadRecentVideos();
    expect(recent.map((item) => item.id), ['video_00001', 'video_00002']);
  });

  test('recent SonarTube history keeps at most 100 videos', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeHistoryService();

    for (var index = 0; index < 105; index++) {
      await service.addRecentVideo(video(index));
    }

    final recent = await service.loadRecentVideos();
    expect(recent, hasLength(SonarTubeHistoryService.maxItems));
    expect(recent.first.id, 'video_00104');
    expect(recent.last.id, 'video_00005');
  });

  test('channels and playlists never enter the video history', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeHistoryService();

    await service.addRecentVideo(const SonarTubeItem(
      kind: SonarTubeItemKind.channel,
      id: 'UC123',
      title: 'Canale',
      url: 'https://www.youtube.com/channel/UC123',
    ));
    await service.addRecentVideo(const SonarTubeItem(
      kind: SonarTubeItemKind.playlist,
      id: 'PL123',
      title: 'Playlist',
      url: 'https://www.youtube.com/playlist?list=PL123',
    ));

    expect(await service.loadRecentVideos(), isEmpty);
  });

  test('recent videos never persist a temporary resolved stream URL', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeHistoryService();

    await service.addRecentVideo(video(
      7,
      url: 'https://temporary.example.invalid/direct-stream.m3u8',
    ));

    final stored = (await service.loadRecentVideos()).single;
    expect(stored.url, 'https://www.youtube.com/watch?v=video_00007');
    expect(stored.url, isNot(contains('temporary.example.invalid')));
  });

  test('clear recent videos removes the whole SonarTube history', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeHistoryService();

    await service.addRecentVideo(video(1));
    await service.addRecentVideo(video(2));
    expect(await service.loadRecentVideos(), hasLength(2));

    await service.clearRecentVideos();
    expect(await service.loadRecentVideos(), isEmpty);
  });


  test('remove one recent video keeps the remaining SonarTube history', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeHistoryService();

    await service.addRecentVideo(video(1));
    await service.addRecentVideo(video(2));
    await service.addRecentVideo(video(3));

    await service.removeRecentVideo('video_00002');

    final recent = await service.loadRecentVideos();
    expect(recent.map((item) => item.id), ['video_00003', 'video_00001']);
  });
}
