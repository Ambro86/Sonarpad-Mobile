import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_collections.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_state.dart';
import 'package:sonarpad_mobile_starter/services/podcast_bookmarks_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CloudState wire;
  final adapter = CloudSyncCollections();
  final service = PodcastBookmarksService();
  final settings = AppSettingsService();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    wire = parseCloudState(
      jsonDecode(
        File('tests/fixtures/podcast_bookmarks_sync.json').readAsStringSync(),
      ),
    );
  });
  test(
    'Windows and Mac positions import, resume and export identically',
    () async {
      await adapter.write(wire);
      for (final row in wire['podcast_bookmarks']!) {
        expect(
          await settings.getMediaBookmark('podcast:${row['id']}'),
          row['data']['position_seconds'],
        );
      }
      expect(
        (await adapter.read())['podcast_bookmarks'],
        wire['podcast_bookmarks'],
      );
      await adapter.write({'radio': []});
      expect(
        (await adapter.read())['podcast_bookmarks'],
        wire['podcast_bookmarks'],
      );
    },
  );
  test('legacy positions migrate without overriding a remote point', () async {
    final url = wire['podcast_bookmarks']!.first['id'] as String;
    await settings.saveMediaBookmark('media:old', 77);
    await service.register(url, 'Episode', 'media:old');
    expect(await service.position(url), 77);
    expect((await service.read()).single['data']['updated_at'], 0);
    final merged = mergeCloudState(wire, {}, await adapter.read());
    await adapter.write(merged);
    await service.register(url, 'Episode', 'media:old');
    expect(await service.position(url), 123);
  });
  test('offline updates and first connection keep the newest whole point', () {
    final older = parseCloudState(jsonDecode(jsonEncode(wire)));
    final latest = parseCloudState(jsonDecode(jsonEncode(wire)));
    older['podcast_bookmarks']!.first['data'].addAll({
      'position_seconds': 180,
      'updated_at': 1794564200000,
    });
    latest['podcast_bookmarks']!.first['data'].addAll({
      'position_seconds': 0,
      'updated_at': 1794564300000,
    });
    for (final base in [wire, <String, List<Map<String, dynamic>>>{}]) {
      expect(
        mergeCloudState(latest, base, older)['podcast_bookmarks'],
        latest['podcast_bookmarks'],
      );
      expect(
        mergeCloudState(older, base, latest)['podcast_bookmarks'],
        latest['podcast_bookmarks'],
      );
    }
    expect(
      mergeCloudState(latest, wire, wire)['podcast_bookmarks'],
      latest['podcast_bookmarks'],
    );
  });
  test(
    'removal is a portable reset; invalid responses make no writes',
    () async {
      await adapter.write(wire);
      final url = wire['podcast_bookmarks']!.first['id'] as String;
      await settings.removeMediaBookmark('podcast:$url');
      expect(await service.position(url), 0);
      final saved = await service.read();
      expect(saved.length, 2);
      expect(saved.first['data']['updated_at'], greaterThan(0));
      final invalid = parseCloudState(jsonDecode(jsonEncode(wire)));
      invalid['podcast_bookmarks']!.last['data']['position_seconds'] = -1;
      await expectLater(adapter.write(invalid), throwsFormatException);
      expect(await service.read(), saved);
    },
  );
  test('updates remain ordered with a slow device clock', () async {
    wire['podcast_bookmarks']!.first['data']['updated_at'] = 8000000000000;
    await adapter.write(wire);
    final url = wire['podcast_bookmarks']!.first['id'] as String;
    await service.save(url, 0);
    final saved = await service.read();
    expect(saved.first['data']['updated_at'], 8000000000001);
    await service.save(url, 0);
    expect(await service.read(), saved);
  });
}
