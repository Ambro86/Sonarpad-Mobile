import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('favorite channel metadata refresh is lazy and persisted statically', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final favorites = File('lib/services/sonartube_favorites_service.dart')
        .readAsStringSync();
    final service =
        File('lib/services/sonartube_service.dart').readAsStringSync();

    expect(screen, contains('_prepareChannelForOpen'));
    expect(screen, contains('refreshChannelMetadata(prepared)'));
    expect(screen, contains('updateFavoriteMetadata(prepared)'));
    expect(
      screen,
      contains('final hasHandle = prepared.handle?.trim().isNotEmpty ?? false;'),
    );
    expect(
      screen,
      contains(
        'final hasSubscribers = prepared.subscribers?.trim().isNotEmpty ?? false;',
      ),
    );

    expect(favorites, contains('Future<SonarTubeItem?> updateFavoriteMetadata'));
    expect(favorites, contains('if (index < 0) return null;'));

    expect(service, contains('Future<SonarTubeItem> refreshChannelMetadata'));
    expect(service, contains("_searchInnerTube(item.title, type: 'channel')"));
    expect(service, contains('candidate.id == channelId'));
  });
}
