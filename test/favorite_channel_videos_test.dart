import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/favorite_channel_videos_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

const a = 'UCaaaaaaaaaaaaaaaaaaaaaa';
const b = 'UCbbbbbbbbbbbbbbbbbbbbbb';
SonarTubeItem channel(String id) => SonarTubeItem(kind: SonarTubeItemKind.channel, id: id, title: id, url: '');
SonarTubeItem video(String id, {String? published, bool live = false}) => SonarTubeItem(
  kind: SonarTubeItemKind.video, id: id, title: 'Same title', url: 'https://www.youtube.com/watch?v=$id',
  duration: '1:02:58', views: '100 views', published: published, isLive: live);
String entry(String id, String date) => '<entry><yt:videoId>$id</yt:videoId><published>$date</published></entry>';
String feed(String entries) => '<feed xmlns="http://www.w3.org/2005/Atom" xmlns:yt="http://www.youtube.com/xml/schemas/2015">$entries</feed>';
class FakeTube extends SonarTubeService {
  FakeTube(this.pages, {this.failed = const {}});
  final Map<String, List<SonarTubeItem>> pages;
  final Set<String> failed;
  final calls = <String>[];
  int active = 0, peak = 0;
  @override
  Future<SonarTubePage> browse(SonarTubeItem collection, {String? token, int page = 1,
      SonarTubeChannelSort channelSort = SonarTubeChannelSort.newest}) async {
    expect(channelSort, SonarTubeChannelSort.newest);
    expect(page, 1); expect(token, isNull);
    calls.add(collection.id); active++;
    if (active > peak) peak = active;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    active--;
    if (failed.contains(collection.id)) throw StateError('channel unavailable');
    return SonarTubePage(items: pages[collection.id] ?? [], page: 1);
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('uses channel Videos tab, never adds RSS shorts with the same title', () async {
    final tube = FakeTube({a: [video('B5bZSENQi7g')]});
    final service = FavoriteChannelVideosService(tube: tube, client: MockClient((_) async =>
      http.Response(feed(entry('fhtVTpdl5hA', '2026-10-28T14:58:16Z') +
        entry('B5bZSENQi7g', '2026-10-27T17:01:07Z')), 200)));
    for (var i = 0; i < 2; i++) {
      final result = await service.load([channel(a)]);
      expect(result.items.map((v) => v.id), ['B5bZSENQi7g']);
      expect(result.items.single.duration, '1:02:58');
      expect(result.items.single.views, '100 views');
      expect(result.items.single.published, '2026-10-27T17:01:07.000Z');
    }
  });
  test('merges absolute dates across channels without deduplicating titles', () async {
    final service = FavoriteChannelVideosService(tube: FakeTube({a: [video('old')], b: [video('new')]}),
      client: MockClient((r) async => http.Response(feed(r.url.queryParameters['channel_id'] == a
        ? entry('old', '2026-10-20T12:00:00Z') : entry('new', '2026-10-22T12:00:00Z')), 200)));
    final result = await service.load([channel(a), channel(b)]);
    expect(result.items.map((v) => v.id), ['new', 'old']);
    expect(result.items.first.channelId, b);
  });
  for (final status in [404, 429, 503]) {
    test('retries date feed HTTP $status without sourcing videos from it', () async {
      var calls = 0;
      final service = FavoriteChannelVideosService(tube: FakeTube({a: [video('v')]}),
        client: MockClient((_) async => ++calls < 3 ? http.Response('Unavailable', status)
          : http.Response(feed(entry('v','2026-10-22T12:00:00Z')),200)));
      expect((await service.load([channel(a)])).items.single.id, 'v');
      expect(calls, 3);
    });
  }
  for (final body in ['<html>Unavailable</html>', '<invalid']) {
    test('keeps channel videos if date feed is invalid: $body', () async {
      final service = FavoriteChannelVideosService(tube: FakeTube({a: [video('v', published:'2 days ago')]}),
        client: MockClient((_) async => http.Response(body,200)));
      final result = await service.load([channel(a)]);
      expect(result.items.single.published, '2 days ago'); expect(result.failedChannels, 0);
    });
  }
  test('feed access failure does not discard channel videos', () async {
    var calls = 0;
    final service = FavoriteChannelVideosService(tube: FakeTube({a: [video('v')]}),
      client: MockClient((_) async { calls++; return http.Response('Forbidden',403); }));
    expect((await service.load([channel(a)])).items.single.id, 'v'); expect(calls,1);
  });
  test('keeps videos absent from feed and caps each channel at 15', () async {
    final service = FavoriteChannelVideosService(tube: FakeTube({a: [video('live',live:true),
      ...List.generate(30,(i)=>video('v$i'))]}), client: MockClient((_) async => http.Response(feed(''),200)));
    final result = await service.load([channel(a)]);
    expect(result.items.map((v)=>v.id), List.generate(15,(i)=>'v$i'));
  });
  test('ignores video favorites and deduplicates channels and video IDs', () async {
    final tube = FakeTube({a:[video('v')], b:[video('v')]});
    final service = FavoriteChannelVideosService(tube:tube,client:MockClient((_) async=>http.Response(feed(''),200)));
    final result = await service.load([channel(a),channel(a),video('ignored'),channel(b)]);
    expect(tube.calls,[a,b]); expect(result.items,hasLength(1));
  });
  test('partial channel failure preserves successful channels; all failures are reported', () async {
    final tube=FakeTube({b:[video('v')]},failed:{a});
    final service=FavoriteChannelVideosService(tube:tube,client:MockClient((_) async=>http.Response(feed(''),200)));
    final result=await service.load([channel(a),channel(b)]);
    expect(result.failedChannels,1);expect(result.items.single.id,'v');
    await expectLater(service.load([channel(a)]),throwsStateError);
  });
  test('limits concurrency and leaves empty channels empty even with RSS entries', () async {
    final tube=FakeTube({});
    final service=FavoriteChannelVideosService(tube:tube,client:MockClient((_) async=>throw StateError('empty channel needs no feed')));
    final result=await service.load(List.generate(12,(i)=>channel('UC${i.toString().padLeft(22,'0')}')));
    expect(result.items,isEmpty);expect(tube.peak,lessThanOrEqualTo(4));expect(tube.peak,greaterThan(1));
  });
}
