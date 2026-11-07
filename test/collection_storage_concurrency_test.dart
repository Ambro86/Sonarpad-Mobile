import 'dart:async';
import 'dart:convert';
// Supplied by flutter_test, like its simulated event loop.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_favorites_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_service.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_api.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_collections.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_state.dart';
import 'package:sonarpad_mobile_starter/services/collection_storage.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/services/radio_service.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';
import 'package:sonarpad_mobile_starter/services/podcast_service.dart';
import 'package:sonarpad_mobile_starter/models/radio_station.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';

const a = SonarTubeItem(
  kind: SonarTubeItemKind.video,
  id: 'aaaaaaaaaaa',
  title: 'A',
  url: 'https://www.youtube.com/watch?v=aaaaaaaaaaa',
);
const b = SonarTubeItem(
  kind: SonarTubeItemKind.video,
  id: 'bbbbbbbbbbb',
  title: 'B',
  url: 'https://www.youtube.com/watch?v=bbbbbbbbbbb',
);

class PausedCollections extends CloudSyncCollections {
  final entered = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<void> write(CloudState state) async {
    entered.complete();
    await resume.future;
    await super.write(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test('idle storage queue can leave a completed event loop', () async {
    var completed = false;
    fakeAsync((clock) {
      CollectionStorage.run(() async => 1).then((_) => completed = true);
      clock.flushMicrotasks();
    });
    expect(completed, isTrue);
    expect(await CollectionStorage.run(() async => 2)
        .timeout(const Duration(seconds: 1)), 2);
  });
  test('failed writes release the queue without bypassing waiting or nested writes', () async {
    final order = <int>[];
    final gate = Completer<void>();
    final first = CollectionStorage.run(() async {
      order.add(1);
      await gate.future;
      throw StateError('test write failure');
    });
    final failure = expectLater(first, throwsStateError);
    final next = CollectionStorage.run(() async {
      order.add(2);
      return CollectionStorage.run(() async => 3);
    });
    await Future<void>.delayed(Duration.zero);
    expect(order, [1]);
    gate.complete();
    await failure;
    expect(await next, 3);
    expect(order, [1, 2]);
    expect(await CollectionStorage.run(() async => 4), 4);
  });
  test(
    'concurrent additions from different service instances both survive',
    () async {
      await Future.wait([
        SonarTubeFavoritesService().toggleFavorite(a),
        SonarTubeFavoritesService().toggleFavorite(b),
      ]);
      expect(
        (await SonarTubeFavoritesService().loadFavorites())
            .map((e) => e.id)
            .toSet(),
        {a.id, b.id},
      );
    },
  );
  test('metadata update cannot overwrite a simultaneous addition', () async {
    await SonarTubeFavoritesService().toggleFavorite(a);
    await Future.wait([
      SonarTubeFavoritesService().toggleFavorite(b),
      SonarTubeFavoritesService().updateFavoriteMetadata(a),
    ]);
    expect(await SonarTubeFavoritesService().loadFavorites(), hasLength(2));
  });
  test(
    'local favorite and preference edit during cloud apply survive',
    () async {
      final collections = PausedCollections();
      final service = CloudSyncService(
        collections: collections,
        api: CloudSyncApi(
          logger: (_) async {},
          client: MockClient((request) async {
            if (request.url.queryParameters['action'] == 'create') {
              return http.Response('{"group_id":"g","sequence":0}', 200);
            }
            final body = jsonDecode(request.body) as Map;
            return http.Response(
              jsonEncode({
                'group_id': 'g',
                'sequence': body['sequence'],
                'state': body['state'],
              }),
              200,
            );
          }),
        ),
      );
      final syncing = service.connect();
      await collections.entered.future;
      final addition = SonarTubeFavoritesService().toggleFavorite(a);
      final preference = AppSettingsService().setWeatherCity('Torino');
      collections.resume.complete();
      await syncing;
      await addition;
      await preference;
      expect(await SonarTubeFavoritesService().loadFavorites(), hasLength(1));
      expect(await AppSettingsService().getWeatherCity(), 'Torino');
    },
  );
  test(
    'stale radio snapshot preserves additions but explicit removal still works',
    () async {
      const r1 = RadioStation(
        name: 'A',
        streamUrl: 'https://a.example/stream',
        languageCode: 'it',
      );
      const r2 = RadioStation(
        name: 'B',
        streamUrl: 'https://b.example/stream',
        languageCode: 'it',
      );
      final service = RadioService();
      await Future.wait([
        service.saveFavorites([r1]),
        RadioService().saveFavorites([r2]),
      ]);
      expect(await service.loadFavorites(), hasLength(2));
      await service.saveFavorites([r2], explicitlyRemoved: [r1.streamUrl]);
      expect((await service.loadFavorites()).single.streamUrl, r2.streamUrl);
    },
  );
  test('stale TV and podcast snapshots preserve additions', () async {
    final tv = TvService();
    await Future.wait([
      tv.saveFavorites([TvChannel(name: 'A', url: '', category: '')]),
      TvService().saveFavorites([TvChannel(name: 'B', url: '', category: '')]),
    ]);
    expect(await tv.loadFavorites(), hasLength(2));
    final podcasts = PodcastService();
    final p1 = PodcastSubscription(
      title: 'A',
      feedUrl: 'https://a.example/feed',
    );
    final p2 = PodcastSubscription(
      title: 'B',
      feedUrl: 'https://b.example/feed',
    );
    await Future.wait([
      podcasts.saveSubscriptions([p1]),
      PodcastService().saveSubscriptions([p2]),
    ]);
    expect(await podcasts.loadSubscriptions(), hasLength(2));
    await podcasts.removeSubscription(p1);
    expect((await podcasts.loadSubscriptions()).single.feedUrl, p2.feedUrl);
  });
}
