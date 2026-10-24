import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channel = TvChannel(name: 'Rai 2', category: 'TV',
    url: 'https://example.org/relinker/relinkerServlet?cont=308718',
    httpUserAgent: 'HbbTV/1.6.1');
  const masterUrl = 'https://example.org/live/master.m3u8?token=test';
  const master = '#EXTM3U\n'
      '#EXT-X-MEDIA:TYPE=AUDIO,LANGUAGE="ita",NAME="Italiano",URI="ita.m3u8"\n'
      '#EXT-X-MEDIA:TYPE=AUDIO,LANGUAGE="des",NAME="Audiodescrizione",URI="des.m3u8"\n';
  for (final code in [200, 404, 410, 403, 500]) {
    test('AD playlist HTTP $code only missing tracks trigger fallback', () async {
      final urls = <Uri>[];
      final client = MockClient((request) async {
        urls.add(request.url);
        expect(request.headers['User-Agent'], 'HbbTV/1.6.1');
        if (request.url.path.endsWith('master.m3u8')) {
          return http.Response(master, 200, request: request);
        }
        expect(request.url.path, '/live/des.m3u8');
        expect(request.url.queryParameters['token'], 'test');
        return http.Response(code == 200 ? '#EXTM3U\n#EXTINF:10,\nsegment.ts' : '', code);
      });
      final unavailable = await http.runWithClient(() =>
          TvService().isRaiAudioDescriptionUnavailable(channel, masterUrl: masterUrl), () => client);
      expect(unavailable, code == 404 || code == 410);
      expect(urls.length, 2, reason: 'Reuse current master without resolving relinker again');
    });
  }
  for (final scenario in ['master missing', 'no AD', 'network error', 'malformed master']) {
    test('Unknown AD availability preserves native choice: $scenario', () async {
      final client = MockClient((request) async {
        if (scenario == 'network error') throw http.ClientException('offline');
        if (scenario == 'master missing') return http.Response('', 404);
        if (scenario == 'malformed master') return http.Response('<html>Error</html>', 200);
        return http.Response('#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,LANGUAGE="ita",URI="ita.m3u8"', 200);
      });
      expect(await http.runWithClient(() =>
        TvService().isRaiAudioDescriptionUnavailable(channel, masterUrl: masterUrl), () => client), isFalse);
    });
  }
}
