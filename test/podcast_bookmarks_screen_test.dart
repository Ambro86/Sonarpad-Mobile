import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_bookmarks_screen.dart';
import 'package:sonarpad_mobile_starter/services/podcast_bookmarks_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  test(
    'media bookmark titles persist, old positions remain visible, removal cleans metadata',
    () async {
      SharedPreferences.setMockInitialValues({'bookmark_old': 42});
      final settings = AppSettingsService();
      await settings.saveMediaBookmark('new', 120, title: 'Film');
      await settings.saveMediaBookmark('new', 121);
      final rows = await settings.mediaBookmarks();
      expect(rows.singleWhere((r) => r.id == 'new').title, 'Film');
      expect(rows.singleWhere((r) => r.id == 'new').seconds, 121);
      expect(rows.singleWhere((r) => r.id == 'old').seconds, 42);
      await settings.removeMediaBookmark('new');
      expect((await settings.mediaBookmarks()).single.id, 'old');
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'media_bookmark_title_new',
        ),
        false,
      );
      await settings.saveMediaBookmark('old', 0);
      expect(await settings.mediaBookmarks(), isEmpty);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'all bookmarks removes only the chosen document position $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        configureAccessibleRendererRuntime(useFlutterOnIos: true);
        final document = DocumentItem(
          id: 'book',
          name: 'Libro',
          path: 'https://example.org/book',
          extension: 'librivox',
          addedAt: DateTime(2026),
          bookmarkIndex: 2,
          bookmarkIndexes: [0, 2, 3],
        );
        SharedPreferences.setMockInitialValues({
          'document_library_v1': DocumentItem.listToJsonString([document]),
          'bookmark_media:file:///missing/movie.mp4': 123,
          'bookmark_sonartube:old-video': 456,
          'bookmark_document_media:book': 89,
          'bookmark_zero': 0,
          'bookmark_invalid': 'invalid',
        });
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          configureAccessibleRendererRuntime(useFlutterOnIos: false);
        });
        final library = DocumentLibraryService();
        const url = 'https://example.org/episode.mp3';
        final podcasts = PodcastBookmarksService();
        await podcasts.register(url, 'Podcast', 'legacy');
        await podcasts.save(url, 90);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastBookmarksScreen(includeDocuments: true),
          ),
        );

        await tester.pumpAndSettle();
        List<AccessibleListRow> rows() => tester
            .widget<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList),
            )
            .sections
            .single
            .rows;
        expect(find.text('Gestisci tutti i segnalibri'), findsOneWidget);
        expect(
          rows(),
          hasLength(7),
        ); // three media + podcast + three document positions
        expect(
          rows().singleWhere((r) => r.id == 'media:document_media:book').title,
          'Libro',
        );
        expect(
          rows()
              .singleWhere(
                (r) => r.id == 'media:media:file:///missing/movie.mp4',
              )
              .subtitle,
          '0:02:03',
        );
        final row = rows().singleWhere(
          (r) => r.id == 'document:${document.id}:2',
        );
        expect(row.onActivate, isNotNull);
        expect(row.actions.single.id, 'remove');
        expect(row.visualActions.single.id, 'remove');
        final removal = row.onCustomAction!('remove');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elimina'));
        await tester.pumpAndSettle();
        await removal;
        await library.load();
        expect(library.documents.single.bookmarkIndex, 0);
        expect(library.documents.single.bookmarkIndexes, [0, 3]);
        expect(await podcasts.position(url), 90);
        expect(rows(), hasLength(6));
        final media = rows().singleWhere(
          (r) => r.id == 'media:sonartube:old-video',
        );
        expect(media.actions.single.id, 'remove');
        expect(media.visualActions.single.id, 'remove');
        final removeMedia = media.onCustomAction!('remove');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elimina'));
        await tester.pumpAndSettle();
        await removeMedia;
        final settings = AppSettingsService();
        expect(await settings.getMediaBookmark('sonartube:old-video'), isNull);
        expect(
          await settings.getMediaBookmark('media:file:///missing/movie.mp4'),
          123,
        );
        expect(await podcasts.position(url), 90);
        expect(rows(), hasLength(5));
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
        configureAccessibleRendererRuntime(useFlutterOnIos: false);
      },
    );
    testWidgets(
      'bookmark manager has independent entries and confirmed removal $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        configureAccessibleRendererRuntime(useFlutterOnIos: true);
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          configureAccessibleRendererRuntime(useFlutterOnIos: false);
        });
        SharedPreferences.setMockInitialValues({});
        final service = PodcastBookmarksService();
        const first = 'https://example.org/a.mp3';
        const second = 'https://example.org/b.mp3';
        await service.register(first, 'Episodio uno', 'a');
        await service.save(first, 123);
        await service.register(second, 'Episodio due', 'b');
        await service.save(second, 456);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastBookmarksScreen(),
          ),
        );
        await tester.pumpAndSettle();
        List<AccessibleListRow> rows() => tester
            .widget<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList),
            )
            .sections
            .single
            .rows;
        final firstRow = rows().singleWhere((r) => r.id == first);
        expect(firstRow.subtitle, '0:02:03');
        expect(firstRow.onActivate, isNotNull);
        expect(firstRow.actions.single.id, 'remove');
        expect(firstRow.visualActions.single.id, 'remove');
        final cancel = firstRow.onCustomAction!('remove');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        await cancel;
        expect(await service.position(first), 123);
        final remove = firstRow.onCustomAction!('remove');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elimina'));
        await tester.pumpAndSettle();
        await remove;
        expect(rows().single.id, second);
        expect(await service.position(first), 0);
        expect(await service.position(second), 456);
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
        configureAccessibleRendererRuntime(useFlutterOnIos: false);
      },
    );
  }
}
