import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/media_join_service.dart';

MediaJoinItemInfo item(String path, [String? name]) => MediaJoinItemInfo(
  path: path,
  originalName: name,
  hasVideo: false,
  hasAudio: true,
  duration: const Duration(seconds: 30),
  videoStreamIndex: null,
  audioStreamIndex: 0,
  width: null,
  height: null,
  rotationDegrees: 0,
  frameRate: null,
);

void main() {
  test('imported media keeps its original Unicode name and cache path', () {
    const path = '/cache/81EB17C7-440A-4C79-9D87_intro.m4a';
    const name = 'Introduzione – città e perché 🎵.m4a';
    final media = item(path, name);
    expect(media.displayName, name);
    expect(media.path, path);
  });

  test('missing or blank picker names fall back to the file basename', () {
    for (final name in [null, '', '  ']) {
      expect(
        item('/cache/registrazione.wav', name).displayName,
        'registrazione.wav',
      );
    }
  });

  test('reordering duplicate names keeps each name with its actual media', () {
    final items = [
      item('/cache/uuid1_clip.wav', 'clip.wav'),
      item('/cache/uuid2_finale.wav', 'Finale.wav'),
      item('/cache/uuid3_clip.wav', 'clip.wav'),
    ];
    final moved = items.removeAt(2);
    items.insert(0, moved);
    expect(items.map((value) => value.displayName), [
      'clip.wav',
      'clip.wav',
      'Finale.wav',
    ]);
    expect(items.map((value) => value.path), [
      '/cache/uuid3_clip.wav',
      '/cache/uuid1_clip.wav',
      '/cache/uuid2_finale.wav',
    ]);
  });

  test('both renderers and reorder announcements use the original name', () {
    final screen = File(
      'lib/screens/media_join_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('originalName: picked.name'));
    expect('final fileName = item.displayName;'.allMatches(screen).length, 2);
    expect(screen, contains(r"'${to + 1}. ${_items[to].displayName}'"));
    expect(screen, isNot(contains('p.basename(item.path)')));
    expect(screen, isNot(contains('p.basename(_items[to].path)')));
  });
}
