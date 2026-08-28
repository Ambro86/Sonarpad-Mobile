import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/sonartube_screen.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_favorites_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_history_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  testWidgets('scrolls through every playlist video with standard list', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const playlist = SonarTubeItem(
      kind: SonarTubeItemKind.playlist,
      id: 'PL_FLO',
      title: 'Flo La Piccola Robinson 1981',
      url: 'https://www.youtube.com/playlist?list=PL_FLO',
    );
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      enableDirectNavigation: false,
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 1,
            'items': List.generate(
              50,
              (index) => {
                'kind': 'video',
                'id': 'video_${index + 1}',
                'title': 'Episodio ${index + 1}',
                'url': 'https://www.youtube.com/watch?v=video_${index + 1}',
              },
            ),
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarTubeScreen(collection: playlist, service: service),
      ),
    );
    await tester.pumpAndSettle();

    final firstVideo =
        find.byKey(const ValueKey('sonartube_video_video_1'));
    expect(firstVideo, findsOneWidget);

    // This test verifies that every playlist item remains reachable in the
    // standard list. Accessibility semantics are covered separately by the
    // shared-renderer/TalkBack contract tests, so do not depend here on the
    // internal node shape produced by MergeSemantics.

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('sonartube_video_video_50')),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.byKey(const ValueKey('sonartube_video_video_50')),
      findsOneWidget,
    );
  });

  testWidgets('search results keep Back visible after scrolling many results', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      enableDirectNavigation: false,
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 1,
            'items': List.generate(
              60,
              (index) => {
                'kind': 'video',
                'id': 'result_${index + 1}',
                'title': 'Risultato ${index + 1}',
                'url': 'https://www.youtube.com/watch?v=result_${index + 1}',
              },
            ),
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarTubeScreen(service: service),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('sonartube_search_field')),
      'annalisa',
    );
    await tester.tap(find.byKey(const ValueKey('sonartube_search_button')));
    await tester.pumpAndSettle();

    final back = find.byKey(const ValueKey('sonartube_search_results_back'));
    expect(back, findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Risultato 60'),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Risultato 60'), findsOneWidget);
    expect(back, findsOneWidget);
    expect(tester.getTopLeft(back).dy, lessThan(100));
  });


  testWidgets('favorites keep Back visible after scrolling many saved items', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final favoritesService = SonarTubeFavoritesService();
    for (var index = 1; index <= 60; index++) {
      await favoritesService.toggleFavorite(
        SonarTubeItem(
          kind: SonarTubeItemKind.video,
          id: 'favorite_$index',
          title: 'Preferito $index',
          url: 'https://www.youtube.com/watch?v=favorite_$index',
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarTubeScreen(favoritesService: favoritesService),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sonartube_favorites_button')));
    await tester.pumpAndSettle();

    final back = find.byKey(const ValueKey('sonartube_favorites_back'));
    expect(back, findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Preferito 60'),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Preferito 60'), findsOneWidget);
    expect(back, findsOneWidget);
    expect(tester.getTopLeft(back).dy, lessThan(100));
  });

  testWidgets('recent videos keep Back visible after scrolling long history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final historyService = SonarTubeHistoryService();
    for (var index = 1; index <= 60; index++) {
      await historyService.addRecentVideo(
        SonarTubeItem(
          kind: SonarTubeItemKind.video,
          id: 'recent_$index',
          title: 'Video recente $index',
          url: 'https://www.youtube.com/watch?v=recent_$index',
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarTubeScreen(historyService: historyService),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sonartube_recent_videos_button')),
    );
    await tester.pumpAndSettle();

    final back = find.byKey(const ValueKey('sonartube_recent_videos_back'));
    expect(back, findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Video recente 1'),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Video recente 1'), findsOneWidget);
    expect(back, findsOneWidget);
    expect(tester.getTopLeft(back).dy, lessThan(100));
  });

  testWidgets('searches and opens a channel with its real videos', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      enableDirectNavigation: false,
      client: MockClient((request) async {
        final query = request.url.queryParameters;
        if (query.containsKey('browse')) {
          expect(query['browse'], 'UC123');
          expect(query['kind'], 'channel');
          return http.Response(
            jsonEncode({
              'ok': true,
              'page': 1,
              'items': [
                {
                  'kind': 'video',
                  'id': 'abcdefghijk',
                  'title': 'Video del canale',
                  'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 1,
            'items': [
              {
                'kind': 'video',
                'id': 'abcdefghijk',
                'title': 'Video trovato',
                'url': 'https://www.youtube.com/watch?v=abcdefghijk',
              },
              {
                'kind': 'channel',
                'id': 'UC123',
                'title': 'Canale trovato',
                'url': 'https://www.youtube.com/channel/UC123',
              },
              {
                'kind': 'playlist',
                'id': 'PL123',
                'title': 'Playlist trovata',
                'url': 'https://www.youtube.com/playlist?list=PL123',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarTubeScreen(service: service),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('sonartube_search_field')),
      'accessibilità',
    );
    await tester.tap(find.byKey(const ValueKey('sonartube_search_button')));
    await tester.pumpAndSettle();

    expect(find.text('Video trovato'), findsOneWidget);
    expect(find.text('Canale trovato'), findsOneWidget);
    expect(find.text('Playlist trovata'), findsOneWidget);

    await tester.tap(find.text('Canale trovato'));
    await tester.pumpAndSettle();

    expect(find.text('Video del canale'), findsOneWidget);
  });

  testWidgets('saves a channel and opens it from favorites', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      enableDirectNavigation: false,
      client: MockClient((request) async {
        if (request.url.queryParameters.containsKey('browse')) {
          return http.Response(
            jsonEncode({
              'ok': true,
              'page': 1,
              'items': [
                {
                  'kind': 'video',
                  'id': 'abcdefghijk',
                  'title': 'Video preferito del canale',
                  'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 1,
            'items': [
              {
                'kind': 'channel',
                'id': 'UC123',
                'title': 'Canale da salvare',
                'url': 'https://www.youtube.com/channel/UC123',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarTubeScreen(service: service),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('sonartube_search_field')),
      'canale',
    );
    await tester.tap(find.byKey(const ValueKey('sonartube_search_button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('sonartube_favorite_channel_UC123')),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Rimuovi canale dai preferiti'), findsOneWidget);
    expect(find.byKey(const ValueKey('sonartube_favorites_button')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('sonartube_search_results_back')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sonartube_favorites_button')));
    await tester.pumpAndSettle();

    expect(find.text('Canale da salvare'), findsOneWidget);
    await tester.tap(find.text('Canale da salvare'));
    await tester.pumpAndSettle();

    expect(find.text('Video preferito del canale'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('sonartube_collection_back')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sonartube_favorites_back')), findsOneWidget);
    expect(find.text('Canale da salvare'), findsOneWidget);
  });

  testWidgets('channel page toggles the channel favorite before the video list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const channel = SonarTubeItem(
      kind: SonarTubeItemKind.channel,
      id: 'UC123',
      title: 'Canale diretto',
      url: 'https://www.youtube.com/channel/UC123',
    );
    final favoritesService = SonarTubeFavoritesService();
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      enableDirectNavigation: false,
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 1,
            'items': [
              {
                'kind': 'video',
                'id': 'abcdefghijk',
                'title': 'Primo video del canale',
                'url': 'https://www.youtube.com/watch?v=abcdefghijk',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarTubeScreen(
          collection: channel,
          service: service,
          favoritesService: favoritesService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(
      const ValueKey('sonartube_collection_channel_favorite'),
    );
    expect(button, findsOneWidget);
    expect(find.text('Aggiungi canale ai preferiti'), findsOneWidget);
    expect(
      tester.getTopLeft(button).dy,
      lessThan(tester.getTopLeft(find.text('Primo video del canale')).dy),
    );

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Rimuovi canale dai preferiti'), findsOneWidget);
    final favorites = await favoritesService.loadFavorites();
    expect(favorites.where((item) => item.kind == SonarTubeItemKind.channel), hasLength(1));
    expect(favorites.single.id, 'UC123');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('load more skips duplicate continuation pages', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var requestCount = 0;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      enableDirectNavigation: false,
      client: MockClient((request) async {
        requestCount++;
        final token = request.url.queryParameters['token'];
        if (token == null) {
          return http.Response(
            jsonEncode({
              'ok': true,
              'page': 1,
              'next_token': 'page-2',
              'items': [
                {
                  'kind': 'video',
                  'id': 'abcdefghijk',
                  'title': 'Primo video',
                  'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                },
              ],
            }),
            200,
          );
        }
        if (token == 'page-2') {
          return http.Response(
            jsonEncode({
              'ok': true,
              'page': 2,
              'next_token': 'page-3',
              'items': [
                {
                  'kind': 'video',
                  'id': 'abcdefghijk',
                  'title': 'Primo video',
                  'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 3,
            'items': [
              {
                'kind': 'video',
                'id': 'lmnopqrstuv',
                'title': 'Secondo video',
                'url': 'https://www.youtube.com/watch?v=lmnopqrstuv',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarTubeScreen(service: service),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('sonartube_search_field')),
      'test',
    );
    await tester.tap(find.byKey(const ValueKey('sonartube_search_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sonartube_load_more')));
    await tester.pumpAndSettle();

    expect(find.text('Secondo video'), findsOneWidget);
    expect(requestCount, 3);
  });

}
