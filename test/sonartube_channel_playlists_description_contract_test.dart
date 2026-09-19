import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel screen exposes public playlists through the verified resolver API', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final service = File('lib/services/sonartube_service.dart').readAsStringSync();

    expect(screen, contains("id: 'channel_playlists'"));
    expect(screen, contains("ValueKey('sonartube_channel_playlists')"));
    expect(screen, contains('showChannelPlaylists: true'));
    expect(screen, contains('await _service.channelPlaylists('));
    expect(service, contains('Future<SonarTubePage> channelPlaylists('));
    expect(service, contains("'kind': 'channel_playlists'"));
  });

  test('every main SonarTube video row exposes a lazy description action', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final service = File('lib/services/sonartube_service.dart').readAsStringSync();

    expect(screen, contains("id: 'view_description'"));
    expect(screen, contains("ValueKey('sonartube_description_\${item.id}')"));
    expect(screen, contains('l10n.sonarTubeViewDescription'));
    expect(screen, contains('class _SonarTubeDescriptionScreen'));
    expect(screen, contains('widget.service.videoDescription(widget.item)'));
    expect(service, contains('Future<String> videoDescription('));
    expect(service, contains("'metadata': '1'"));
  });

  test('all locales contain channel playlist and video description labels', () {
    for (final file in Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))) {
      final source = file.readAsStringSync();
      for (final key in const [
        'sonarTubeChannelPlaylists',
        'sonarTubeChannelShorts',
        'sonarTubeViewDescription',
        'sonarTubeDescription',
        'sonarTubeNoDescription',
      ]) {
        expect(source, contains('"$key"'), reason: '${file.path}: $key');
      }
    }
  });
}
