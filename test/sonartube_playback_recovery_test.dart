import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('player recovery changes resolver even when direct resolution succeeded', () async {
    final hosts = <String>[];
    final service = SonarTubeService(client: MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host == 'www.youtube.com') {
        return http.Response(jsonEncode({
          'playabilityStatus': {'status':'OK'},
          'streamingData': {'formats': [{'itag':18, 'url':'https://unreachable.example/video.mp4',
            'mimeType':'video/mp4; codecs="avc1.42001E, mp4a.40.2"', 'audioQuality':'AUDIO_QUALITY_LOW', 'height':360}]},
          'videoDetails': {'videoId':'EN3BLMPVAT4', 'title':'Course lesson'}
        }), 200);
      }
      expect(request.url.queryParameters['url'], 'https://www.youtube.com/watch?v=EN3BLMPVAT4');
      return http.Response(jsonEncode({'ok':true, 'stream':'https://reachable.example/video.mp4'}), 200);
    }));
    const item = SonarTubeItem(kind: SonarTubeItemKind.video, id:'EN3BLMPVAT4', title:'Course lesson', url:'https://www.youtube.com/watch?v=EN3BLMPVAT4');
    final original = await service.resolve(item);
    expect(original.audioUrl, contains('unreachable.example'));
    final recovered = await service.recoverPlayback(item);
    expect(recovered.audioUrl, contains('reachable.example'));
    expect(recovered.title, item.title);
    expect(hosts, ['www.youtube.com', 'sonarpad.com']);
  });
}
