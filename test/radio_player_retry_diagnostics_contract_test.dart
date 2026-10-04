import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retry resolves fresh URLs and is guarded against repeat taps', () {
    final source = File('lib/screens/radio_player_screen.dart').readAsStringSync();
    expect(source, contains('Future<void> _retryStreamPlayback()'));
    expect(source, contains('await _play(reconnecting: true);'));
    expect(RegExp(r'if \(!mounted \|\|\s*_streamRetryInProgress \|\|\s*widget.tvChannel == null\)').hasMatch(source), isTrue);
    expect(source, contains('requestId != _playRequestId'));
    expect(source, contains('final streams ='));
    expect(source, contains('await TvService().resolveAudioDescriptionStreams('));
    expect(RegExp(r"id: 'retry_stream',\s*kind: 'button',\s*title: l10n.retry").hasMatch(source), isTrue);
    expect(source, contains("event.id == 'retry_stream' && event.type == 'activate'"));
  });

  test('recovery messages and first real progress drive the UI', () {
    final source = File('lib/screens/radio_player_screen.dart').readAsStringSync();
    expect(RegExp(r'_streamRecovery\.reconnect\(\);\s*_error = null;').hasMatch(source), isTrue);
    expect(source, contains('position > Duration.zero && _mediaKitPlaying && !_mediaKitBuffering'));
    expect(source, contains('_streamRecovery.observe('));
    expect(source, contains('announceStatusMessage(context, message)'));
    expect(source, contains('startup_wait_exceeded'));
    expect(source, contains('l10n.streamReconnecting'));
  });

  test('diagnostics do not detach disposal or alter player configuration', () {
    final source = File('lib/screens/radio_player_screen.dart').readAsStringSync();
    expect(source, contains('final player = mk.Player();'));
    expect(source, contains('await _disposeMediaKitPlayer();'));
    expect(source, contains('await player.dispose();'));
    expect(source, isNot(contains('unawaited(player.dispose())')));
    expect(source, contains('_mediaKitDisposeInFlight'));
    expect(source, contains('await player.stop().timeout(const Duration(seconds: 2));'));
    expect(source, contains('Timer(const Duration(seconds: 6)'));
    expect(source, contains('position > Duration.zero || duration > Duration.zero'));
    expect(source, contains('player.stream.log.listen'));
  });

  test('all locales have complete localized stream messages', () {
    final arbs = Directory('lib/l10n').listSync().whereType<File>()
        .where((file) => file.path.endsWith('.arb'));
    final keys = ['streamReconnecting', 'streamPlaybackRetryMessage'];
    for (final file in arbs) {
      final values = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in keys) {
        expect(values[key], isA<String>(), reason: file.path);
        expect((values[key] as String).trim(), isNotEmpty, reason: file.path);
        expect(values['@$key'], isNotNull, reason: file.path);
      }
    }
  });
}
