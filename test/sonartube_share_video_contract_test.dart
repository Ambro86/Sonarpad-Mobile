import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube exposes localized share actions for every result kind', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains("SonarTubeItemKind.video => 'share_video'"));
    expect(source, contains("SonarTubeItemKind.channel => 'share_channel'"));
    expect(source, contains("SonarTubeItemKind.playlist => 'share_playlist'"));
    expect(source, contains('l10n.sonarTubeShareVideo'));
    expect(source, contains('l10n.sonarTubeShareChannel'));
    expect(source, contains('l10n.sonarTubeSharePlaylist'));
    expect(source, contains("event.action?.startsWith('share_') == true"));
    expect(source, contains('CustomSemanticsAction('));
    expect(source, contains('SharePlus.instance.share('));
    expect(source, contains("text: '\${item.title}\\n\$url'"));
  });

  test('video, channel and playlist keep favorite and share actions together', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, isNot(contains('canFavorite')));
    expect(source, contains("AccessibleCustomAction(id: 'favorite', label: favoriteLabel)"));
    expect(source, contains('id: _shareActionId(item)'));
    expect(source, contains('label: _shareActionLabel(l10n, item)'));
  });

  test('SonarTube shares public YouTube URLs with canonical fallbacks', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('final originalUrl = item.url.trim();'));
    expect(
      source,
      contains("Uri.https('www.youtube.com', '/watch', {'v': item.id})"),
    );
    expect(
      source,
      contains("Uri.https('www.youtube.com', '/channel/\${item.id}')"),
    );
    expect(
      source,
      contains("Uri.https('www.youtube.com', '/playlist', {'list': item.id})"),
    );
    expect(source, isNot(contains('_service.resolve(item)\n      ShareParams')));
  });

  test('every app locale contains all SonarTube share labels', () {
    final l10nDir = Directory('lib/l10n');
    final arbFiles = l10nDir
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(file.path))
        .toList();

    expect(arbFiles, isNotEmpty);
    for (final file in arbFiles) {
      final source = file.readAsStringSync();
      for (final key in [
        'sonarTubeShareVideo',
        'sonarTubeShareChannel',
        'sonarTubeSharePlaylist',
      ]) {
        expect(
          source,
          contains('"$key"'),
          reason: '${file.path} must localize $key',
        );
      }
    }
  });
}
