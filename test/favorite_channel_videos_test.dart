import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/favorite_channel_videos_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

const a = 'UCaaaaaaaaaaaaaaaaaaaaaa';
const b = 'UCbbbbbbbbbbbbbbbbbbbbbb';
SonarTubeItem channel(String id) => SonarTubeItem(kind: SonarTubeItemKind.channel, id: id, title: id, url: '');
String entry(String id, String date) => '<entry><yt:videoId>$id</yt:videoId><title>Title &amp; more</title><published>$date</published><author><name>Artist</name></author></entry>';
String feed(String entries) => '<feed xmlns="http://www.w3.org/2005/Atom" xmlns:yt="http://www.youtube.com/xml/schemas/2015">$entries</feed>';
void main() {
  test('merges feeds using absolute dates, newest first, preserving channel metadata', () async {
    final service = FavoriteChannelVideosService(client: MockClient((request) async => http.Response(feed(
      request.url.queryParameters['channel_id'] == a
        ? entry('old', '2026-10-20T12:00:00Z') : entry('new', '2026-10-22T12:00:00Z')), 200)));
    final result = await service.load([channel(a), channel(b)]);
    expect(result.items.map((e) => e.id), ['new', 'old']);
    expect(result.items.first.channelId, b);
    expect(result.items.first.channel, 'Artist');
    expect(result.items.first.title, 'Title & more');
    expect(result.failedChannels, 0);
  });
  test('ignores favorite videos and playlists', () async {
    var calls = 0;
    final service = FavoriteChannelVideosService(client: MockClient((_) async { calls++; return http.Response(feed(''), 200); }));
    final result = await service.load([const SonarTubeItem(kind: SonarTubeItemKind.video, id: 'v', title: 'v', url: ''),
      const SonarTubeItem(kind: SonarTubeItemKind.playlist, id: 'p', title: 'p', url: '')]);
    expect(calls, 0); expect(result.items, isEmpty);
  });
  test('deduplicates channels and videos', () async {
    var calls = 0;
    final service = FavoriteChannelVideosService(client: MockClient((_) async {calls++; return http.Response(feed(entry('v', '2026-10-22T10:00:00Z')),200);}));
    final result = await service.load([channel(a), channel(a), channel(b)]);
    expect(calls, 2); expect(result.items, hasLength(1));
  });
  test('partial failures preserve successful channels', () async {
    final service = FavoriteChannelVideosService(client: MockClient((r) async => r.url.queryParameters['channel_id'] == a
      ? http.Response('Unavailable', 503) : http.Response(feed(entry('v','2026-10-22T10:00:00Z')),200)));
    final result = await service.load([channel(a), channel(b)]);
    expect(result.failedChannels, 1); expect(result.items, hasLength(1));
  });
  test('all failures are reported rather than displayed as an empty feed', () async {
    final service = FavoriteChannelVideosService(client: MockClient((_) async => http.Response('Unavailable',503)));
    await expectLater(service.load([channel(a)]), throwsStateError);
  });
  test('malformed feeds are failures', () async {
    final service = FavoriteChannelVideosService(client: MockClient((_) async => http.Response('<html>Login</html>',200)));
    await expectLater(service.load([channel(a)]), throwsStateError);
  });
  test('empty channels and invalid dates do not create fake videos', () async {
    final service = FavoriteChannelVideosService(client: MockClient((_) async => http.Response(feed(entry('v','invalid')),200)));
    final result = await service.load([channel(a)]);
    expect(result.items,isEmpty); expect(result.failedChannels,0);
  });
  test('limits concurrent requests to four', () async {
    var running=0, peak=0;
    final service = FavoriteChannelVideosService(client: MockClient((_) async {
      running++; if (running>peak) peak=running;
      await Future<void>.delayed(const Duration(milliseconds: 5)); running--;
      return http.Response(feed(''),200);
    }));
    await service.load(List.generate(12,(i)=>channel('UC${i.toString().padLeft(22,'0')}')));
    expect(peak,lessThanOrEqualTo(4)); expect(peak,greaterThan(1));
  });
}
