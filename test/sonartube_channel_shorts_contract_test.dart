import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel screen exposes public Shorts through the verified resolver API', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final service = File('lib/services/sonartube_service.dart').readAsStringSync();

    expect(screen, contains("id: 'channel_shorts'"));
    expect(screen, contains("ValueKey('sonartube_channel_shorts')"));
    expect(screen, contains('showChannelShorts: true'));
    expect(screen, contains('await _service.channelShorts('));
    expect(service, contains('Future<SonarTubePage> channelShorts('));
    expect(service, contains("'kind': 'channel_shorts'"));
  });

  test('channel Shorts reuse normal SonarTube video rows and player', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(screen, contains('_openItem(_items[index])'));
    expect(screen, isNot(contains('ShortsPlayer')));
    expect(screen, isNot(contains('shortDuration')));
  });

  test('latest changelog documents playlists Shorts and descriptions in every locale', () {
    final changelog = jsonDecode(
      File('assets/changelog.json').readAsStringSync(),
    ) as List<dynamic>;
    final latest = changelog.first as Map<String, dynamic>;
    expect(latest['version'], '0.4.1');
    for (final locale in const [
      'it',
      'en',
      'fr',
      'es',
      'pt',
      'pt_BR',
      'pl',
      'cs',
      'de',
      'zh_CN',
      'uk',
    ]) {
      final entries = (latest[locale] as List<dynamic>).cast<String>();
      final shortsIndex = entries.indexWhere(
        (entry) => entry.toLowerCase().contains('shorts'),
      );
      expect(shortsIndex, greaterThan(0), reason: locale);
      expect(shortsIndex, lessThan(entries.length - 1), reason: locale);
      expect(entries[shortsIndex - 1].isNotEmpty, isTrue, reason: locale);
      expect(entries[shortsIndex + 1].isNotEmpty, isTrue, reason: locale);
    }
  });

}
