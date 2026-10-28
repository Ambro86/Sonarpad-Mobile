import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/raiplay_service.dart';

void main() {
  const relinker = 'https://mediapolisvod.rai.it/relinker/relinkerServlet.htm?cont=test';
  const playable = 'https://cdn.example.org/film.mp4';
  const xml = '<url type="content">$playable</url>';

  test('successful relinker is resolved once without changing media URLs', () async {
    var calls = 0;
    final result = await http.runWithClient(
      () => RaiPlayService().resolvePlaybackUrls(relinker),
      () => MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['output'], '45');
        expect(request.headers['Origin'], 'https://www.raiplay.it');
        return http.Response(xml, 200);
      }),
    );
    expect(calls, 1);
    expect(result.audioUrl, playable);
    expect(result.videoUrl, playable);
  });

  for (final failure in ['503', '429', '408', 'empty', 'html', 'relinker', 'network', 'timeout']) {
    test('recovers from $failure without forwarding an invalid URL', () async {
      var calls = 0;
      final result = await http.runWithClient(
        () => RaiPlayService().resolvePlaybackUrls(relinker),
        () => MockClient((_) async {
          if (++calls > 1) return http.Response(xml, 200);
          switch (failure) {
            case 'network': throw http.ClientException('Connection closed');
            case 'timeout': throw TimeoutException('timeout');
            case 'empty': return http.Response('<root/>', 200);
            case 'html': return http.Response('<html>Unavailable</html>', 200);
            case 'relinker': return http.Response('<url>$relinker</url>', 200);
            default: return http.Response('', int.parse(failure));
          }
        }),
      );
      expect(calls, 2);
      expect(result.audioUrl, playable);
    });
  }

  for (final status in [200, 503, 403]) {
    test('unavailable response $status terminates with typed error', () async {
      var calls = 0;
      await expectLater(http.runWithClient(
        () => RaiPlayService().resolvePlaybackUrls(relinker),
        () => MockClient((_) async {
          calls++;
          return http.Response('<root/>', status);
        }),
      ), throwsA(isA<RaiPlayMediaUnavailable>()));
      expect(calls, status == 403 ? 1 : 3);
    });
  }

  test('a direct media URL needs no relinker request', () async {
    final result = await http.runWithClient(
      () => RaiPlayService().resolvePlaybackUrls(playable),
      () => MockClient((_) async => throw StateError('Unexpected HTTP request')),
    );
    expect(result.audioUrl, playable);
  });
}
