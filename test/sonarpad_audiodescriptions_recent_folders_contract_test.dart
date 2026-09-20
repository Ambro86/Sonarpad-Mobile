import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sonarpad recent items can include folders from the API', () {
    final service = File(
      'lib/services/sonarpad_audiodescriptions_service.dart',
    ).readAsStringSync();

    expect(service, contains("bool get isFolder => type.toLowerCase() == 'folder'"));
    expect(service, contains('item.isFolder ||'));
    expect(service, contains("action: 'recent'"));
    expect(service, contains('groupRecentFolders: true'));
    expect(service, contains("'group_recent_folders': true"));
  });

  test('recent Audiodescriptions open folders with the shared folder screen', () {
    final source = File(
      'lib/screens/sonarpad_audiodescriptions_screen.dart',
    ).readAsStringSync();
    final homeStart = source.indexOf(
      'class _SonarpadAudiodescriptionsScreenState',
    );
    final allStart = source.indexOf(
      'class SonarpadAudiodescriptionsAllScreen',
    );
    expect(homeStart, greaterThanOrEqualTo(0));
    expect(allStart, greaterThan(homeStart));

    final home = source.substring(homeStart, allStart);
    expect(home, contains('if (item.isFolder) {'));
    expect(home, contains('await _openSonarpadAudiodescriptionFolder(context, item);'));
    expect(home, contains('if (item.isFolder) return;'));
    expect(home, contains('return _sharedCatalogRow(context, id, item);'));
    expect(home, contains('_legacyCatalogItem('));
  });

  test('folder rows do not expose the media download action', () {
    final source = File(
      'lib/screens/sonarpad_audiodescriptions_screen.dart',
    ).readAsStringSync();

    expect(source, contains('actions: item.isFolder'));
    expect(source, contains('visualActions: item.isFolder'));
    expect(source, contains('if (!item.isFolder)'));
  });
}
