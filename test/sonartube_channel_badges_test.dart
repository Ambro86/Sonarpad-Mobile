import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

const channel = SonarTubeItem(
  kind: SonarTubeItemKind.channel,
  id: 'UCnfd-Yur_dJD9vLvSA9h8rw',
  title: 'Lo Scribacchino',
  url: 'https://www.youtube.com/@LoScribacchino/videos',
);

void main() {
  test(
    'channel badge rows preserve public videos and exclude members-only',
    () async {
      // Reduced real response: Hype video, members-only video, collaboration,
      // ordinary video. Keep only metadata, without tracking or playback URLs.
      final fixture = File(
        'test/fixtures/sonartube_channel_hype.json',
      ).readAsStringSync();
      final client = MockClient((request) async {
        expect(request.url.host, 'www.youtube.com');
        return http.Response(
          fixture,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final page = await SonarTubeService(client: client).browse(channel);
      expect(page.items.map((item) => item.id), [
        '1o9lnx4-VrQ',
        't0x0gxyqnFI',
        't4PepnB0X5s',
      ]);
      expect(page.items.first.views, '25K visualizzazioni');
      expect(page.items.first.channel, 'Lo Scribacchino');
      expect(page.items.first.published, '3 giorni fa');
      expect(page.items[1].channel, 'Lo Scribacchino e Golgota_79');
      expect(page.items[1].views, '6,7K visualizzazioni');
      expect(page.items[2].views, '32K visualizzazioni');
    },
  );

  test(
    'live reported channel includes public Hype video',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final service = SonarTubeService(
        client: client,
        endpoint: Uri.parse('http://127.0.0.1:9/youtube_resolve.php'),
      );
      final page = await service.browse(channel);
      expect(page.items.map((item) => item.id), contains('1o9lnx4-VrQ'));
      expect(page.items.map((item) => item.id), isNot(contains('YWSvIPz82dY')));
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_SONARTUBE_TESTS'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
