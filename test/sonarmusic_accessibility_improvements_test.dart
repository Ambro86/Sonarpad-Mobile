import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/utils/sonarmusic_item_subtitle.dart';

void main() {
  test('SonarMusic removes duplicate kind, artist and duration from subtitles', () {
    expect(
      sonarMusicItemSubtitle(
        title: 'Una canzone', kind: 'song', kindLabel: 'Brani',
        artist: 'Giorgia', duration: '3:34',
        subtitle: 'Brano • Giorgia • Giorgia • 3:34',
      ),
      'Brani · Giorgia · 3:34',
    );
    expect(
      sonarMusicItemSubtitle(
        title: 'Giorgia', kind: 'artist', kindLabel: 'Artisti',
        artist: 'Giorgia', subtitle: 'Artista • Giorgia',
      ),
      'Artisti',
    );
  });

  test('SonarMusic retains distinct useful information and existing order', () {
    expect(
      sonarMusicItemSubtitle(
        title: 'Brano famoso', kind: 'song', kindLabel: 'Songs',
        artist: 'Adele', duration: '4:10',
        subtitle: 'Song • Adele • Album 2026 • 4:10',
      ),
      'Songs · Adele · 4:10 · Album 2026',
    );
    expect(
      sonarMusicItemSubtitle(
        title: 'My Song', kind: 'song', kindLabel: 'Songs',
        subtitle: 'Song • Artist Name • Guest Artist',
      ),
      'Songs · Artist Name · Guest Artist',
    );
  });

  test('load more requests focus on the first newly appended row', () {
    final screen = File('lib/screens/sonarmusic_screen.dart').readAsStringSync();
    final native = File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();
    expect(screen, contains('firstAppendedIndex = previousCount;'));
    expect(screen, contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(screen, contains("_accessible.focusTo('item_\$firstAppendedIndex', animated: false)"));
    expect(native, contains('self.debugTag == "sonarmusic"'));
    expect(native, contains('ONE_SHOT_FOCUS_FALLBACK'));
  });

  test('search results have only back navigation, without a search button', () {
    final source = File('lib/screens/sonarmusic_screen.dart').readAsStringSync();
    final start = source.indexOf('appBar: widget.searchQuery != null');
    final end = source.indexOf(': SonarpadAppBar(title:', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final resultsBar = source.substring(start, end);
    expect(resultsBar, contains("ValueKey('sonarmusic_search_results_back')"));
    expect(resultsBar, isNot(contains('Icons.search')));
    expect(resultsBar, isNot(contains('sonarmusic_search_button')));
  });

  test('Flutter and UIKit row labels share exactly the same subtitle builder', () {
    final screen = File('lib/screens/sonarmusic_screen.dart').readAsStringSync();
    expect(RegExp(r'_itemSubtitle\(item\)').allMatches(screen).length, 2);
  });
}
