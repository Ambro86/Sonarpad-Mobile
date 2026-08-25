import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every SonarTube result exposes the favorite action', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(
      source,
      contains("AccessibleCustomAction(id: 'favorite', label: favoriteLabel)"),
    );
    expect(
      source,
      contains('CustomSemanticsAction(label: favoriteLabel)'),
    );
    expect(source, isNot(contains('canFavorite')));
  });

  test('favorites screen recognizes and opens saved videos', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(
      source,
      contains('SonarTubeItemKind.video => l10n.sonarTubeVideo'),
    );
    expect(
      source,
      contains('if (item != null && mounted) await _openItem(item);'),
    );
  });

  test('favorite persistence accepts videos and stores public YouTube URLs', () {
    final source = File(
      'lib/services/sonartube_favorites_service.dart',
    ).readAsStringSync();

    expect(source, contains("'video' => SonarTubeItemKind.video"));
    expect(source, contains('favorites.add(_forFavoriteStorage(item))'));
    expect(source, contains("host == 'youtube.com'"));
    expect(source, contains("host == 'www.youtube.com'"));
    expect(source, contains("host == 'm.youtube.com'"));
    expect(source, contains("host == 'youtu.be'"));
    expect(
      source,
      contains("Uri.https('www.youtube.com', '/watch', {'v': item.id})"),
    );
  });

  test('every locale has a localized Video label and updated empty favorites text', () {
    final files = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(file.path));

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, contains('"sonarTubeVideo"'), reason: file.path);
      expect(source, contains('"sonarTubeNoFavorites"'), reason: file.path);
    }
  });
}
