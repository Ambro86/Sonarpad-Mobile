import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_collections.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_state.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_deletions.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_library_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CloudState wire;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    wire = parseCloudState(
      jsonDecode(
        File('tests/fixtures/sonarmusic_sync.json').readAsStringSync(),
      ),
    );
  });
  test(
    'desktop wire imports songs, albums, artists and mixes and exports identically',
    () async {
      final adapter = CloudSyncCollections();
      await adapter.write(wire);
      expect((await adapter.read())['sonarmusic'], wire['sonarmusic']);
      final items = await SonarMusicLibraryService().favorites();
      expect(items.first.playable, true);
      expect(items.skip(1).every((item) => item.browsable), true);
      expect(items.last.browseParams, 'mix-params');
      await adapter.write({'radio': []});
      expect((await adapter.read())['sonarmusic'], wire['sonarmusic']);
    },
  );
  test(
    'first sync combines separate lists and old clients preserve music',
    () async {
      final remote = {'sonarmusic': wire['sonarmusic']!.take(2).toList()};
      final local = {'sonarmusic': wire['sonarmusic']!.skip(2).toList()};
      final merged = mergeCloudState(remote, {}, local);
      expect(
        merged['sonarmusic']!.map((v) => v['id']),
        unorderedEquals(wire['sonarmusic']!.map((v) => v['id'])),
      );
      expect(
        mergeCloudState(merged, {}, {'radio': []})['sonarmusic'],
        merged['sonarmusic'],
      );
      final adapter = CloudSyncCollections();
      await adapter.write(merged);
      expect((await adapter.read())['sonarmusic'], merged['sonarmusic']);
    },
  );
  test(
    'removal and clear record intent, cloud import and reorder do not',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'sonarpad_cloud_sync_v1',
        jsonEncode({'group_id': 'test-group'}),
      );
      final adapter = CloudSyncCollections();
      final library = SonarMusicLibraryService();
      await adapter.write(wire);
      expect(await CloudSyncDeletions.read(), isEmpty);
      final items = await library.favorites();
      await library.reorderFavorites(items.reversed.map((v) => v.key).toList());
      expect(await CloudSyncDeletions.read(), isEmpty);
      await library.toggle(items.first);
      expect(
        (await CloudSyncDeletions.read()).single['id'],
        wire['sonarmusic']!.first['id'],
      );
      await library.clearFavorites();
      expect(await library.favorites(), isEmpty);
      expect(
        (await CloudSyncDeletions.read()).map((v) => v['id']),
        unorderedEquals(wire['sonarmusic']!.map((v) => v['id'])),
      );
    },
  );
  test('malformed incoming identity does not modify favorites', () async {
    final adapter = CloudSyncCollections();
    await adapter.write(wire);
    final bad = parseCloudState(jsonDecode(jsonEncode(wire)));
    bad['sonarmusic']!.first['id'] = 'wrong';
    await expectLater(adapter.write(bad), throwsFormatException);
    expect((await adapter.read())['sonarmusic'], wire['sonarmusic']);
  });
  test(
    'cloud refresh preserves local-only metadata and does not share listening history',
    () async {
      final library = SonarMusicLibraryService();
      final item = SonarMusicItem.fromJson({
        ...wire['sonarmusic']!.first['data'] as Map<String, dynamic>,
        'album': 'Local album',
      });
      await library.toggle(item);
      await library.remember(item);
      await CloudSyncCollections().write(wire);
      expect((await library.favorites()).first.album, 'Local album');
      expect((await library.recent()).single.id, item.id);
      expect(
        (await CloudSyncCollections().read()).keys,
        isNot(contains('sonarmusic_history')),
      );
    },
  );
}
