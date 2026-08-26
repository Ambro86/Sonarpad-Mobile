import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube search retries automatically and exposes a manual retry', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final service = File('lib/services/sonartube_service.dart').readAsStringSync();

    expect(service, contains('Future<SonarTubePage> _loadNavigationPage'));
    expect(service, contains('for (var attempt = 0; attempt < 2; attempt++)'));
    expect(service, contains('Duration(milliseconds: 300)'));
    expect(service, contains('Future<SonarTubePage> _searchDirect'));
    expect(service, contains('Future<SonarTubePage> _browseDirect'));
    expect(service, contains('Future<SonarTubePage> _loadServerPage'));
    expect(service, contains('youtubei/v1/search'));
    expect(service, contains('youtubei/v1/browse'));
    expect(screen, contains("ValueKey('sonartube_search_retry')"));
    expect(screen, contains("id: 'retry'"));
    expect(screen, contains('child: Text(l10n.retry)'));
    expect(screen, contains('await _loadSearchResults();'));
  });

  test('SonarTube transcript technical failure exposes the same retry action', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(screen, contains("ValueKey('sonartube_transcript_retry')"));
    expect(screen, contains('Future<void> _retry() async'));
    expect(screen, contains('child: Text(l10n.retry)'));
  });
}
