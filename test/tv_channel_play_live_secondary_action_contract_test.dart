import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every TV channel surface exposes direct live playback', () {
    final tv = File('lib/screens/tv_screen.dart').readAsStringSync();
    final favorites =
        File('lib/screens/favorite_tvs_screen.dart').readAsStringSync();

    expect(tv, contains("id: 'play_live'"));
    expect(tv, contains("event.action == 'play_live'"));
    expect(tv, contains('onPlayLive: () => widget.onPlayLive(channel)'));
    expect(tv, contains("icon: 'play'"));
    expect(tv, contains('icon: const Icon(Icons.play_arrow)'));

    expect(favorites, contains("id: 'play_live'"));
    expect(favorites, contains("event.action == 'play_live'"));
    expect(favorites, contains('widget.onPlayLive(channel)'));
    expect(favorites, contains("icon: 'play'"));
    expect(favorites, contains('icon: const Icon(Icons.play_arrow)'));
  });

  test('direct TV playback resolves the stream and opens the player', () {
    final tv = File('lib/screens/tv_screen.dart').readAsStringSync();

    expect(tv, contains('Future<void> _playLiveChannel(TvChannel channel)'));
    expect(tv, contains('_service.resolveStreamUrl(channel)'));
    expect(tv, contains("RouteSettings(name: '/tv/channel/player')"));
    expect(tv, contains('RadioPlayerScreen('));
    expect(tv, contains('tvChannel: channel'));
  });

  test('live-play visual controls stay hidden from screen readers', () {
    final shared =
        File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final native =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(shared, contains("'play' => Icons.play_arrow"));
    expect(shared, contains('return ExcludeSemantics('));
    expect(native, contains('case "play": return "play.fill"'));
    expect(native, contains('stack.accessibilityElementsHidden = true'));
    expect(native, contains('button.isAccessibilityElement = false'));
  });

  test('every locale contains the direct TV playback label', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) =>
            file.path.contains('/app_') && file.path.endsWith('.arb'));

    for (final file in arbFiles) {
      expect(
        file.readAsStringSync(),
        contains('"tvPlayLive"'),
        reason: 'Missing tvPlayLive in ${file.path}',
      );
    }

    final localizations = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('/app_localizations'));
    for (final file in localizations) {
      expect(
        file.readAsStringSync(),
        contains('tvPlayLive'),
        reason: 'Missing generated tvPlayLive in ${file.path}',
      );
    }
  });
}
