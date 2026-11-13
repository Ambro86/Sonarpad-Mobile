import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/models/radio_station.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/screens/favorite_radios_screen.dart';
import 'package:sonarpad_mobile_starter/screens/favorite_tvs_screen.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_screen.dart';
import 'package:sonarpad_mobile_starter/screens/sonarpad_audiodescriptions_screen.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:sonarpad_mobile_starter/services/radio_service.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';
import 'package:sonarpad_mobile_starter/services/podcast_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarpad_audiodescriptions_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarpad_audiodescriptions_favorites_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

class _Paths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '${Directory.systemTemp.path}/sonarpad-sort-test-missing';
}

void main() {
  for (final collection in [
    'documents',
    'radio',
    'tv',
    'podcasts',
    'descriptions',
  ]) {
    testWidgets(
      '$collection exposes both sort actions and persists only its list',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final oldPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths();
        addTearDown(() => PathProviderPlatform.instance = oldPaths);
        final documents = DocumentLibraryService();
        final radio = RadioService();
        final tv = TvService();
        final podcasts = PodcastService();
        const descriptions = SonarpadAudiodescriptionsFavoritesService();
        const names = ['Zeta', 'anna', 'Beta'];
        late Widget screen;
        late Future<List<String>> Function() savedNames;
        await tester.runAsync(() async {
          if (collection == 'documents') {
            for (final parent in ['folder', 'other']) {
              for (final name in names.reversed) {
                await documents.add(
                  DocumentItem(
                    id: '$parent-$name',
                    name: name,
                    path: 'saved:librivox:$name',
                    extension: 'librivox',
                    addedAt: DateTime(2026),
                    parentId: parent,
                  ),
                );
              }
            }
            screen = const DocumentsScreen(folderId: 'folder');
            savedNames = () async {
              await documents.load();
              expect(
                documents.documents
                    .where((d) => d.parentId == 'other')
                    .map((d) => d.name),
                names,
              );
              return documents.documents
                  .where((d) => d.parentId == 'folder')
                  .map((d) => d.name)
                  .toList();
            };
          } else if (collection == 'radio') {
            await radio.saveFavorites([
              for (final name in names)
                RadioStation(
                  name: name,
                  streamUrl: 'https://example.org/$name',
                  languageCode: 'it',
                ),
            ]);
            screen = const FavoriteRadiosScreen();
            savedNames = () async =>
                (await radio.loadFavorites()).map((e) => e.name).toList();
          } else if (collection == 'tv') {
            final channels = [
              for (final name in names)
                TvChannel(
                  name: name,
                  url: 'https://example.org/$name',
                  category: 'Test',
                ),
            ];
            await tv.saveFavorites(channels);
            screen = FavoriteTvsScreen(
              channels: channels,
              currentPrograms: {},
              onOpenChannel: (_) {},
              onPlayLive: (_) {},
              onPlayAndRecord: (_) {},
            );
            savedNames = () async =>
                (await tv.loadFavorites()).map((e) => e.name).toList();
          } else if (collection == 'podcasts') {
            await podcasts.saveSubscriptions([
              for (final name in names)
                PodcastSubscription(
                  title: name,
                  feedUrl: 'https://example.org/$name.xml',
                ),
            ]);
            screen = const PodcastScreen();
            savedNames = () async => (await podcasts.loadSubscriptions())
                .map((e) => e.title)
                .toList();
          } else {
            await descriptions.save([
              for (final name in names)
                SonarpadAudiodescriptionItem.fromJson({
                  'type': 'file',
                  'title': name,
                  'path': '/$name',
                  'stream_url': 'https://example.org/temporary',
                }),
            ]);
            screen = const SonarpadAudiodescriptionsFavoritesScreen();
            savedNames = () async {
              final loaded = await descriptions.load();
              expect(loaded.every((e) => e.streamUrl.isEmpty), isTrue);
              return loaded.map((e) => e.title).toList();
            };
          }
        });
        List<AccessibleListRow> rows() => tester
            .widget<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList),
            )
            .sections
            .expand((s) => s.rows)
            .toList();
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('it'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: screen,
            ),
          );
          for (var i = 0; i < 100; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            if (find.byType(UniversalAccessibleList).evaluate().isNotEmpty &&
                rows().any((r) => r.title == 'Zeta')) {
              break;
            }
          }
        });
        final list = tester.widget<UniversalAccessibleList>(
          find.byType(UniversalAccessibleList),
        );
        final row = rows().firstWhere((r) => r.title == 'Zeta');
        expect(
          row.actions.where((a) => a.id == 'sort_favorites').single.label,
          'Ordina alfabeticamente',
        );
        expect(
          row.visualActions.where((a) => a.id == 'sort_favorites'),
          hasLength(1),
        );
        await tester.runAsync(() async {
          await list.onEvent!(
            AccessibleListEvent(
              type: 'customAction',
              id: row.id,
              action: 'sort_favorites',
            ),
          );
        });
        await tester.pumpAndSettle();
        expect(
          rows().where((r) => names.contains(r.title)).map((r) => r.title),
          ['anna', 'Beta', 'Zeta'],
        );
        expect(await tester.runAsync(savedNames), ['anna', 'Beta', 'Zeta']);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
