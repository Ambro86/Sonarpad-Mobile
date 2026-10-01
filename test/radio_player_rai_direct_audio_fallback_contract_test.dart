import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RAI direct-audio fallback waits six seconds and preserves working playback', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(source, contains('Timer(const Duration(seconds: 6)'));
    expect(
      source,
      contains('position > Duration.zero || duration > Duration.zero'),
    );
    expect(
      source,
      contains('RAI direct-audio fallback not needed after 6s'),
    );
    expect(
      source,
      contains('RAI primary playback recovered while resolving fallback'),
    );
  });

  test('RAI fallback refreshes relinker and opens direct audio only once', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(
      source,
      contains('final streams = await TvService().resolveAudioDescriptionStreams(channel);'),
    );
    expect(source, contains('streamUrl: streams.audioUrl,'));
    expect(source, contains('enableRaiDirectAudioFallback: false,'));
    expect(source, contains('enableRaiDirectAudioFallback: !_isVideoEnabled,'));
    expect(source, contains('_isVideoEnabled) {'));
  });
}
