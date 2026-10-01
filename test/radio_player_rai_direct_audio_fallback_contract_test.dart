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

  test('RAI fallback keeps master first, then direct AD, then direct ITA only if needed', () {
    final playerSource =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();
    final tvSource = File('lib/services/tv_service.dart').readAsStringSync();

    expect(
      playerSource,
      contains('final streams = await TvService().resolveAudioDescriptionStreams(channel);'),
    );
    expect(playerSource, contains('streamUrl: streams.audioUrl,'));
    expect(
      playerSource,
      contains('raiNormalAudioFallbackUrl: normalAudioFallbackUrl,'),
    );
    expect(
      playerSource,
      contains('RAI direct AD stalled for 6s; falling back to direct ITA'),
    );
    expect(
      playerSource,
      contains('streamUrl: normalAudioUrl,'),
    );
    expect(playerSource, contains('enableRaiDirectAudioFallback: false,'));
    expect(playerSource, contains('enableRaiDirectAudioFallback: !_isVideoEnabled,'));
    expect(playerSource, contains('_isVideoEnabled) {'));

    expect(tvSource, contains('final String normalAudioUrl;'));
    expect(tvSource, contains('final normalAudioUrl = itaUrl ?? finalMasterUrl;'));
    expect(tvSource, contains('final audioUrl = adUrl ?? itaUrl ?? finalMasterUrl;'));
    expect(
      tvSource,
      isNot(contains('break; // AD trovata: precedenza assoluta, non cercare oltre')),
    );
  });

  test('RAI stalled playback is stopped with a bounded timeout before dispose', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(
      source,
      contains('await player.stop().timeout(const Duration(seconds: 2));'),
    );
    expect(
      source,
      contains('continuing with normal dispose'),
    );
    expect(
      source,
      contains("stage: 'master'"),
    );
    expect(
      source,
      contains("stage: 'direct AD'"),
    );
  });
}
