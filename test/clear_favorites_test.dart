import 'package:sonarpad_mobile_starter/services/podcast_service.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/radio_station.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_deletions.dart';
import 'package:sonarpad_mobile_starter/services/radio_service.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_favorites_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_library_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarpad_audiodescriptions_favorites_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarpad_audiodescriptions_service.dart';
import 'package:sonarpad_mobile_starter/widgets/clear_favorites_button.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'sonarpad_cloud_sync_v1': '{"group_id":"test"}',
    }),
  );

  test(
    'clearing each collection preserves the others and records cloud removals',
    () async {
      final radio = RadioService();
      final tv = TvService();
      final tube = SonarTubeFavoritesService();
      final music = SonarMusicLibraryService();
      const descriptions = SonarpadAudiodescriptionsFavoritesService();
      await radio.saveFavorites([
        const RadioStation(
          name: 'Radio A',
          streamUrl: 'https://example.com/a',
          languageCode: 'it',
        ),
        const RadioStation(
          name: 'Radio B',
          streamUrl: 'https://example.com/b',
          languageCode: 'fr',
        ),
      ]);
      await tv.saveFavorites([
        TvChannel(
          name: 'TV A',
          url: 'https://example.com/tv-a',
          category: 'Test',
        ),
        TvChannel(
          name: 'TV B',
          url: 'https://example.com/tv-b',
          category: 'Test',
        ),
      ]);
      for (final id in ['abcdefghijk', 'lmnopqrstuv']) {
        await tube.toggleFavorite(
          SonarTubeItem(
            kind: SonarTubeItemKind.video,
            id: id,
            title: id,
            url: 'https://www.youtube.com/watch?v=$id',
          ),
        );
      }
      const song = SonarMusicItem(
        kind: 'song',
        id: 'song1',
        title: 'Song',
        videoId: 'song1',
      );
      await music.toggle(song);
      await music.remember(song);
      await descriptions.toggle(
        SonarpadAudiodescriptionItem.fromJson({
          'type': 'folder',
          'title': 'Series',
          'path': '/series',
        }),
      );

      await radio.clearFavorites();
      expect(await radio.loadFavorites(), isEmpty);
      expect(await tv.loadFavorites(), hasLength(2));
      expect(await tube.loadFavorites(), hasLength(2));
      await tv.clearFavorites();
      expect(await tv.loadFavorites(), isEmpty);
      expect(await tube.loadFavorites(), hasLength(2));
      await tube.clearFavorites();
      expect(await tube.loadFavorites(), isEmpty);
      expect(await music.favorites(), hasLength(1));
      expect(await descriptions.load(), hasLength(1));
      await music.clearFavorites();
      expect(await music.favorites(), isEmpty);
      expect(await music.recent(), hasLength(1));
      expect(await descriptions.load(), hasLength(1));
      await descriptions.clearFavorites();
      expect(await descriptions.load(), isEmpty);
      expect(await music.recent(), hasLength(1));
      final events = await CloudSyncDeletions.read();
      for (final collection in ['radio', 'tv', 'sonartube']) {
        final removed = events.where((e) => e['collection'] == collection);
        expect(removed, hasLength(2), reason: collection);
        expect(removed.map((e) => e['id']).toSet(), hasLength(2));
      }
      await radio.clearFavorites();
      await tv.clearFavorites();
      await tube.clearFavorites();
      expect(await CloudSyncDeletions.read(), hasLength(6));
    },
  );

  test(
    'clearing subscriptions preserves favorites and records every removal',
    () async {
      final service = PodcastService();
      final radio = RadioService();
      await service.saveSubscriptions([
        const PodcastSubscription(
          title: 'First',
          feedUrl: 'https://example.com/first.xml',
        ),
        const PodcastSubscription(
          title: 'Second',
          feedUrl: 'https://example.com/second.xml',
        ),
      ]);
      await radio.saveFavorites([
        const RadioStation(
          name: 'Radio',
          streamUrl: 'https://example.com/radio',
          languageCode: 'it',
        ),
      ]);
      await service.clearSubscriptions();
      expect(await service.loadSubscriptions(), isEmpty);
      expect(await radio.loadFavorites(), hasLength(1));
      final removed = await CloudSyncDeletions.read();
      expect(removed.map((e) => e['collection']).toSet(), {'podcasts'});
      expect(removed.map((e) => e['id']).toSet(), {
        'https://example.com/first.xml',
        'https://example.com/second.xml',
      });
      await service.clearSubscriptions();
      expect(await CloudSyncDeletions.read(), hasLength(2));
    },
  );

  for (final podcasts in [false, true]) {
    testWidgets('clear command requires confirmation (podcasts: $podcasts)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var clears = 0;
      final label = podcasts
          ? 'Rimuovi tutte le iscrizioni'
          : 'Svuota preferiti';
      final confirmation = podcasts
          ? 'Rimuovere tutte le iscrizioni?'
          : 'Sei sicuro di voler rimuovere tutti i preferiti di questa sezione?';
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ClearFavoritesButton(
                  label: podcasts ? label : null,
                  confirmation: podcasts ? confirmation : null,
                  onClear: () async {
                    clears++;
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(IconButton)).getSemanticsData().tooltip,
        contains(label),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(clears, 0);
      expect(find.text(confirmation), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(clears, 0);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, label));
      await tester.pumpAndSettle();
      expect(clears, 1);
      semantics.dispose();
    });
  }
}
