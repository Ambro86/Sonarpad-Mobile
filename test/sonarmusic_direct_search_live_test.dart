import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';

void main() {
  for (final type in ['song', 'album', 'artist', 'playlist', 'video']) {
    test('live $type search and pagination work with PHP blocked', () async {
      final network = http.Client();
      addTearDown(network.close);
      final client = MockClient((request) async {
        expect(request.url.host, 'music.youtube.com', reason: 'PHP must not be needed');
        final copy = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)..bodyBytes = request.bodyBytes;
        return http.Response.fromStream(await network.send(copy));
      });
      addTearDown(client.close);
      final service = SonarMusicService(client: client);
      final first = await service.search('Grateful Dead', type: type);
      expect(first.items, isNotEmpty);
      expect(first.items.every((item) => item.kind == type), isTrue, reason: first.items.where((item) => item.kind != type).map((item) => '${item.kind}: ${item.title}').join('; '));
      if (first.hasMore) {
        final second = await service.search('Grateful Dead', type: type, token: first.nextToken, page: 2);
        expect(second.items, isNotEmpty);
      }
      // ignore: avoid_print
      print('$type: ${first.items.length} initial results; more=${first.hasMore}');
    }, skip: !const bool.fromEnvironment('RUN_LIVE_SONARMUSIC_DIRECT'), timeout: const Timeout(Duration(minutes: 2)));
  }
}
