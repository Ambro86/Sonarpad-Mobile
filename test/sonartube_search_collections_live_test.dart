import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  const enabled = bool.fromEnvironment('RUN_LIVE_CHANNEL_COLLECTIONS');
  for (final direct in [true, false]) {
    test('live course and podcast search with ${direct ? 'Dart' : 'local PHP'}', () async {
      final source = File(r'C:\Users\ambro\Documents\youtube_resolve.php').readAsStringSync();
      final token = RegExp("const SONARPAD_YOUTUBE_CLIENT_TOKEN = '([^']+)'").firstMatch(source)!.group(1)!;
      final network = http.Client();
      addTearDown(network.close);
      final client = MockClient((request) async {
        expect(request.url.host, direct ? 'www.youtube.com' : '127.0.0.1');
        final copy = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        return http.Response.fromStream(await network.send(copy));
      });
      addTearDown(client.close);
      final service = SonarTubeService(
        endpoint: Uri.parse('http://127.0.0.1:18796/youtube_resolve.php'),
        clientToken: token, client: client, enableDirectNavigation: direct,
      );
      for (final type in [SonarTubeSearchType.courses, SonarTubeSearchType.podcasts]) {
        final category = type == SonarTubeSearchType.courses ? 'course' : 'podcast';
        final result = await service.search('science', type: type);
        expect(result.items, isNotEmpty);
        expect(result.items.every((item) => item.collectionType == category && item.kind == SonarTubeItemKind.playlist), isTrue);
        final videos = await service.browse(result.items.first);
        expect(videos.items, isNotEmpty);
        if (result.hasMore) {
          final next = await service.search('science', type: type, token: result.nextToken, page: result.page + 1);
          expect(next.page, greaterThan(result.page));
          expect(next.items.every((item) => item.collectionType == category), isTrue);
        }
      }
    }, skip: !enabled, timeout: const Timeout(Duration(minutes: 3)));
  }
}
