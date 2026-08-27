import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TV remains Italian-only and code-gated from the home screen', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(home, contains('if (_isTvCodeValid && isItalian)'));
    expect(home, contains("routeName: '/tv'"));
    expect(main, contains("'/tv': (context) => italianOnlyRoute(context, const TvScreen())"));
  });

  test('radio and TV rows expose gated play-and-record actions and visual buttons', () {
    final radioResults =
        File('lib/screens/radio_search_results_screen.dart').readAsStringSync();
    final radioFavorites =
        File('lib/screens/favorite_radios_screen.dart').readAsStringSync();
    final tv = File('lib/screens/tv_screen.dart').readAsStringSync();
    final tvFavorites =
        File('lib/screens/favorite_tvs_screen.dart').readAsStringSync();

    for (final source in [radioResults, radioFavorites, tv, tvFavorites]) {
      expect(source, contains("id: 'play_record'"));
      expect(source, contains('playAndRecord'));
      expect(source, contains('recordingFeatureUnlocked'));
      expect(source, contains("icon: 'record'"));
    }

    expect(radioResults, contains('autoStartRecording: true'));
    expect(radioFavorites, contains('autoStartRecording: true'));
    expect(tv, contains('autoStartRecording: true'));
    expect(tvFavorites, contains('widget.onPlayAndRecord(channel)'));
  });

  test('visible Flutter play-and-record buttons stay excluded from screen reader semantics', () {
    final radio = File('lib/screens/radio_screen.dart').readAsStringSync();
    final radioResults =
        File('lib/screens/radio_search_results_screen.dart').readAsStringSync();
    final tv = File('lib/screens/tv_screen.dart').readAsStringSync();
    final tvFavorites =
        File('lib/screens/favorite_tvs_screen.dart').readAsStringSync();

    expect(radio, contains('trailing: ExcludeSemantics('));
    expect(radioResults, contains('extraTrailingActions: ['));
    expect(tv, contains('child: ExcludeSemantics('));
    expect(tvFavorites, contains('child: ExcludeSemantics('));
  });

  test('automatic recording is re-gated inside the player', () {
    final player =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();
    final tvChannel =
        File('lib/screens/tv_channel_screen.dart').readAsStringSync();

    expect(player, contains('final bool autoStartRecording;'));
    expect(player, contains('!_isRecordingFeatureUnlocked'));
    expect(player, contains('await _toggleRecording();'));
    expect(tvChannel, contains('autoStartRecording: widget.autoStartRecording'));
  });

  test('every locale contains play and record label', () {
    for (final entity in Directory('lib/l10n').listSync()) {
      if (entity is! File || !entity.path.endsWith('.arb')) continue;
      final data = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
      expect(
        data.containsKey('playAndRecord'),
        isTrue,
        reason: '${entity.path} missing playAndRecord',
      );
    }
  });
}
