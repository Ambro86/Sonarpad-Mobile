import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  const enabled = bool.fromEnvironment('RUN_LIVE_COLLECTION_PLAYBACK');
  test('course lesson and podcast episode resolve and decode real audio/video', () async {
    final source = File(r'C:\Users\ambro\Documents\youtube_resolve.php').readAsStringSync();
    final token = RegExp("const SONARPAD_YOUTUBE_CLIENT_TOKEN = '([^']+)'").firstMatch(source)!.group(1)!;
    var serverAllowed = false;
    final network = http.Client();
    addTearDown(network.close);
    final client = MockClient((request) async {
      if (!serverAllowed) {
        expect(request.url.host, 'www.youtube.com',
            reason: 'The direct test must not silently fall back to PHP');
      }
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await network.send(copy));
    });
    addTearDown(client.close);
    final service = SonarTubeService(clientToken: token, client: client);
    final podcasts = await service.search('science', type: SonarTubeSearchType.podcasts);
    expect(podcasts.items, isNotEmpty);
    final episodes = await service.browse(podcasts.items.first);
    expect(episodes.items, isNotEmpty);
    final items = [
      const SonarTubeItem(kind: SonarTubeItemKind.video, id:'EN3BLMPVAT4', title:'Reported course lesson', url:'https://www.youtube.com/watch?v=EN3BLMPVAT4'),
      episodes.items.firstWhere((item) => item.kind == SonarTubeItemKind.video),
    ];
    for (final item in items) {
      for (final recover in [false, true]) {
        serverAllowed = recover;
        final media = recover ? await service.recoverPlayback(item) : await service.resolve(item);
        for (final url in {media.audioUrl, if (media.videoUrl != null) media.videoUrl!}) {
          final result = await Process.run('ffmpeg', ['-hide_banner', '-loglevel', 'error',
            '-rw_timeout', '15000000', '-i', url,
            if (media.videoUrl == null || url == media.videoUrl) ...['-map', '0:v:0'],
            if (media.videoUrl == null || url == media.audioUrl) ...['-map', '0:a:0'],
            '-t', '30', '-progress', 'pipe:1', '-f', 'null', '-']);
          expect(result.exitCode, 0, reason:'Decode failed: video=${item.id} recovery=$recover host=${Uri.parse(url).host}');
          final progress = result.stdout.toString();
          final times = RegExp(r'out_time_us=(\d+)').allMatches(progress)
              .map((match) => int.parse(match[1]!)).toList();
          expect(times.any((time) => time >= 29000000), isTrue,
              reason: 'Must actually decode at least 29 seconds, not just open a URL');
        }
        // ignore: avoid_print
        print('Decoded 30 seconds of audio/video: id=${item.id}, recovery=$recover, host=${Uri.parse(media.audioUrl).host}');
      }
    }
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 4)));
}
