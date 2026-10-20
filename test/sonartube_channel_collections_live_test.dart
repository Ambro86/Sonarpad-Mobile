import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  const enabled = bool.fromEnvironment('RUN_LIVE_CHANNEL_COLLECTIONS');
  test('Dart reads courses and podcasts through the local PHP and opens videos', () async {
    final php = File(r'C:\Users\ambro\Documents\youtube_resolve.php').readAsStringSync();
    final token = RegExp("const SONARPAD_YOUTUBE_CLIENT_TOKEN = '([^']+)'").firstMatch(php)!.group(1)!;
    final service = SonarTubeService(
      endpoint: Uri.parse('http://127.0.0.1:18796/youtube_resolve.php'),
      clientToken: token,
      enableDirectNavigation: false,
    );
    for (final courses in [true, false]) {
      final id = courses ? 'UCX6b17PVsYBQ0ip5gyeme-Q' : 'UCSHZKyawb77ixDdsGog4iWA';
      final channel = SonarTubeItem(kind: SonarTubeItemKind.channel, id: id, title: 'Channel', url: 'https://www.youtube.com/channel/$id');
      final page = courses ? await service.channelCourses(channel) : await service.channelPodcasts(channel);
      expect(page.items, isNotEmpty);
      expect(page.items.every((item) => item.kind == SonarTubeItemKind.playlist), isTrue);
      final videos = await service.browse(page.items.first);
      expect(videos.items, isNotEmpty);
      expect(videos.items.every((item) => item.kind == SonarTubeItemKind.video), isTrue);
      final directService = SonarTubeService(
        endpoint: Uri.parse('http://127.0.0.1:18796/youtube_resolve.php'),
        clientToken: token,
      );
      final directVideos = await directService.browse(page.items.first);
      expect(directVideos.items, isNotEmpty);
      if (page.hasMore) {
        final next = courses
            ? await service.channelCourses(channel, token: page.nextToken, page: 2)
            : await service.channelPodcasts(channel, token: page.nextToken, page: 2);
        expect(next.page, 2);
      }
    }
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 3)));
}
