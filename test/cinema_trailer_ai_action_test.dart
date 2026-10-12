import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/media_playback_speed.dart';
import 'package:sonarpad_mobile_starter/models/tmdb_movie.dart';
import 'package:sonarpad_mobile_starter/screens/cinema_detail_screen.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_episode_player_screen.dart';
import 'package:sonarpad_mobile_starter/services/recording_feature_access.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

const _trailerId = 'abcdefghijk';
const _trailerUrl = 'https://www.youtube.com/watch?v=$_trailerId';
const _extraFeatureCode = String.fromEnvironment('RAIPLAY_SECRET');

class _Routes extends NavigatorObserver {
  MaterialPageRoute<void>? trailer;
  late Completer<void> opened;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == '/cinema/trailer') {
      trailer = route as MaterialPageRoute<void>;
      opened.complete();
    }
  }
}

Widget _app(_Routes routes, {String locale = 'it'}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  navigatorObservers: [routes],
  home: CinemaDetailScreen(
    movie: TmdbMovie(
      id: 42,
      title: 'Film di prova',
      overview: 'La trama del film.',
      releaseDate: '2026-01-01',
    ),
  ),
);

http.Response _trailers(String id) => http.Response(
  jsonEncode({
    'results': [
      {'type': 'Trailer', 'site': 'YouTube', 'key': id},
    ],
  }),
  200,
);

http.Response _media(int version, {bool live = false}) => http.Response(
  jsonEncode({
    'ok': true,
    'title': 'Trailer ufficiale',
    'channel': 'Cinema',
    'stream': 'https://example.test/trailer-$version.mp4',
    'is_live': live,
  }),
  200,
);

Future<PodcastEpisodePlayerScreen> _openTrailer(
  WidgetTester tester,
  _Routes routes,
) async {
  final list = tester.widget<UniversalAccessibleList>(
    find.byType(UniversalAccessibleList),
  );
  // Observe the real navigation before its platform media controller is built.
  // This exercises cinema's loading/action wiring without decoding a video.
  await tester.runAsync(() async {
    routes.opened = Completer<void>();
    unawaited(
      Future<void>.sync(
        () => list.onEvent!(
          const AccessibleListEvent(type: 'activate', id: 'trailer'),
        ),
      ),
    );
    await routes.opened.future.timeout(const Duration(seconds: 3));
  });
  final route = routes.trailer!;
  final player = route.builder(
    tester.element(find.byType(CinemaDetailScreen)),
  ) as PodcastEpisodePlayerScreen;
  routes.navigator!.removeRoute(route);
  await tester.pumpAndSettle();
  return player;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
  });

  tearDown(() {
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
  });

  testWidgets(
    'cinema loads its localized trailer and keeps shared playback and URL refresh',
    (tester) async {
      final requests = <Uri>[];
      var resolutions = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/tmdb.php') {
          requests.add(request.url);
          return _trailers(_trailerId);
        }
        if (request.url.path == '/api/youtube_resolve.php') {
          expect(request.url.queryParameters['url'], _trailerUrl);
          return _media(++resolutions);
        }
        // Exercise the existing server fallback without contacting YouTube.
        return http.Response('{}', 503);
      });
      await http.runWithClient(() async {
        final routes = _Routes();
        await tester.pumpWidget(_app(routes));
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        expect(requests.single.queryParameters['language'], 'it-IT');
        expect(requests.single.queryParameters['movie_id'], '42');
        expect(
          find.byKey(const ValueKey('accessible_row_trailer')),
          findsOneWidget,
        );

        final player = await _openTrailer(tester, routes);
        expect(player.episode.id, 'cinema_trailer:42');
        expect(player.episode.title, 'Trailer ufficiale');
        expect(player.episode.audioUrl, 'https://example.test/trailer-1.mp4');
        expect(player.isVideoSupported, isTrue);
        expect(player.startWithVideoThenRestorePreference, isTrue);
        expect(player.speedCategory, MediaPlaybackSpeedCategory.sonartube);
        expect(player.extraActions, isEmpty);

        final refreshed = await tester.runAsync(player.refreshEpisode!);
        expect(refreshed!.id, player.episode.id);
        expect(refreshed.audioUrl, 'https://example.test/trailer-2.mp4');
        expect(resolutions, 2);
        expect(requests, hasLength(1));
        await tester.pumpWidget(const SizedBox());
      }, () => client);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('a stale locale response cannot replace the current trailer', (
    tester,
  ) async {
    final oldResponse = Completer<http.Response>();
    final requests = <Uri>[];
    final client = MockClient((request) async {
      if (request.url.path == '/api/tmdb.php') {
        requests.add(request.url);
        if (request.url.queryParameters['language'] == 'it-IT') {
          return oldResponse.future;
        }
        return _trailers('ZYXWVUTSRQP');
      }
      if (request.url.path == '/api/youtube_resolve.php') {
        expect(
          request.url.queryParameters['url'],
          'https://www.youtube.com/watch?v=ZYXWVUTSRQP',
        );
        expect(request.url.queryParameters['hl'], 'en');
        return _media(1);
      }
      return http.Response('{}', 503);
    });
    await http.runWithClient(() async {
      final routes = _Routes();
      await tester.pumpWidget(_app(routes));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(routes, locale: 'en'));
      await tester.pumpAndSettle();
      oldResponse.complete(_trailers(_trailerId));
      await tester.pumpAndSettle();
      expect(requests.map((request) => request.queryParameters['language']), [
        'it-IT',
        'en-US',
      ]);
      final player = await _openTrailer(tester, routes);
      expect(player.extraActions, isEmpty);
      await tester.pumpWidget(const SizedBox());
    }, () => client);
  });

  testWidgets(
    'unlocked Italian trailer action starts the existing cancellable AI import',
    (tester) async {
      expect(RecordingFeatureAccess.isCodeValid(_extraFeatureCode), isTrue);
      SharedPreferences.setMockInitialValues({
        'tvSecretCode': _extraFeatureCode,
      });
      var resolutions = 0;
      var preparing = false;
      var live = false;
      final preparation = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.url.path == '/api/tmdb.php') return _trailers(_trailerId);
        if (request.url.path == '/api/youtube_resolve.php') {
          expect(request.url.queryParameters['url'], _trailerUrl);
          resolutions++;
          return preparing
              ? preparation.future
              : _media(resolutions, live: live);
        }
        return http.Response('{}', 503);
      });
      await http.runWithClient(() async {
        final routes = _Routes();
        await tester.pumpWidget(_app(routes));
        await tester.pumpAndSettle();
        final player = await _openTrailer(tester, routes);
        final action = player.extraActions.single;
        expect(action.id, 'create_ai_audiodescription');
        expect(action.label(), 'Crea audiodescrizione con IA');
        expect(action.pauseBeforeOpen, isTrue);
        preparing = true;
        unawaited(action.onPressed());
        await tester.pumpAndSettle();
        expect(resolutions, 2);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Annulla'));
        preparation.complete(_media(2));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(CinemaDetailScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox());

        preparing = false;
        for (final scenario in [('it', true), ('en', false)]) {
          live = scenario.$2;
          final restrictedRoutes = _Routes();
          await tester.pumpWidget(_app(restrictedRoutes, locale: scenario.$1));
          await tester.pumpAndSettle();
          final restrictedPlayer = await _openTrailer(tester, restrictedRoutes);
          expect(restrictedPlayer.episode.isLive, live);
          expect(restrictedPlayer.extraActions, isEmpty);
          await tester.pumpWidget(const SizedBox());
        }
      }, () => client);
    },
    // Reuse the existing integration-test credential convention; no unlock
    // code is embedded in the test or bypassed in application code.
    skip: _extraFeatureCode.isEmpty,
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
