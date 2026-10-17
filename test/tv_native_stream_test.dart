import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/tv_native_stream.dart';

void main() {
  test('direct manifests need no extra network request', () async {
    final client = MockClient((_) => throw StateError('unexpected request'));
    for (final path in ['live.m3u8?token=x', 'live.MPD?token=x']) {
      final result = await TvNativeStream.detect(
        'https://example.org/$path',
        headers: {},
        client: client,
      );
      expect(
        result,
        path.startsWith('live.m3u8')
            ? TvNativeStreamFormat.hls
            : TvNativeStreamFormat.dash,
      );
    }
  });

  test(
    'PHP HLS and DASH are identified by content with playback headers',
    () async {
      for (final entry in {
        '\uFEFF\n#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\na.m3u8':
            TvNativeStreamFormat.hls,
        '<?xml version="1.0"?><MPD xmlns="urn:mpeg:dash:schema:mpd:2011">':
            TvNativeStreamFormat.dash,
      }.entries) {
        final client = MockClient((request) async {
          expect(request.headers['User-Agent'], 'TV test');
          expect(request.followRedirects, isTrue);
          return http.Response(entry.key, 200, headers: {'content-type': 'application/vnd.apple.mpegurl; charset=utf-8'});
        });
        expect(
          await TvNativeStream.detect(
            'https://example.org/pluto.php?id=1',
            headers: {'User-Agent': 'TV test'},
            client: client,
          ),
          entry.value,
        );
      }
    },
  );

  test(
    'HTML errors, HTTP errors and unavailable endpoints retain MediaKit',
    () async {
      for (final client in [
        MockClient((_) async => http.Response('<html>error</html>', 200)),
        MockClient((_) async => http.Response('#EXTM3U', 403)),
        MockClient((_) async => throw http.ClientException('offline')),
      ]) {
        expect(
          await TvNativeStream.detect(
            'https://example.org/live.php',
            headers: {},
            client: client,
          ),
          isNull,
        );
      }
    },
  );

  test('a stalled resolver has a bounded wait', () async {
    final pending = Completer<http.Response>();
    final result = await TvNativeStream.detect(
      'https://example.org/live.php',
      headers: {},
      client: MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 20),
    );
    expect(result, isNull);
    pending.complete(http.Response('#EXTM3U', 200));
  });

  test('DASH is native only on Android; unknown formats retain MediaKit', () {
    expect(
      TvNativeStream.supported(TvNativeStreamFormat.hls, android: false),
      isTrue,
    );
    expect(
      TvNativeStream.supported(TvNativeStreamFormat.hls, android: true),
      isTrue,
    );
    expect(
      TvNativeStream.supported(TvNativeStreamFormat.dash, android: true),
      isTrue,
    );
    expect(
      TvNativeStream.supported(TvNativeStreamFormat.dash, android: false),
      isFalse,
    );
    expect(TvNativeStream.supported(null, android: true), isFalse);
    expect(
      TvNativeStream.fromUrl('https://example.org/a.php?fake=.m3u8'),
      isNull,
    );
  });
}
