import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';

void main() {
  const runLiveTest = bool.fromEnvironment('RUN_LIVE_TV_TESTS');

  test(
    'resolves the public K2 Discovery+ page through Aurora channel 24',
    () async {
      final channel = TvChannel(
        name: 'K2',
        url: 'https://play.discoveryplus.com/channel/watch/'
            'f4a4e9af-8af5-54a1-96b8-281b59b00742/'
            '366a7d01-78f8-568b-a429-54dcc5f6a1d6',
        category: 'Bambini',
        streamResolver: 'aurora_channel',
        // Discovery+ page UUID: the resolver must replace it with K2's
        // numeric Aurora channel ID (24).
        resolverChannelId: 'f4a4e9af-8af5-54a1-96b8-281b59b00742',
      );

      final streamUrl = await TvService().resolveStreamUrl(channel);

      expect(Uri.tryParse(streamUrl)?.hasAbsolutePath, isTrue);
      expect(streamUrl.toLowerCase(), contains('.m3u8'));
      expect(streamUrl, isNot(equals(channel.url)));
    },
    skip: runLiveTest
        ? false
        : 'Live test: run with '
            '--dart-define=RUN_LIVE_TV_TESTS=true.',
  );

  test(
    'resolves the public Frisbee Discovery+ page through Aurora channel 26',
    () async {
      final channel = TvChannel(
        name: 'Frisbee',
        url: 'https://play.discoveryplus.com/channel/watch/'
            '0056c9f0-e41e-5adc-80c0-dba41beaa77b/'
            '95e29bf3-0593-5589-bf63-133456ed024c',
        category: 'Bambini',
        streamResolver: 'aurora_channel',
        resolverChannelId: '0056c9f0-e41e-5adc-80c0-dba41beaa77b',
      );

      final streamUrl = await TvService().resolveStreamUrl(channel);

      expect(Uri.tryParse(streamUrl)?.hasAbsolutePath, isTrue);
      expect(streamUrl.toLowerCase(), contains('.m3u8'));
      expect(streamUrl, isNot(equals(channel.url)));
    },
    skip: runLiveTest
        ? false
        : 'Live test: run with '
            '--dart-define=RUN_LIVE_TV_TESTS=true.',
  );
}
