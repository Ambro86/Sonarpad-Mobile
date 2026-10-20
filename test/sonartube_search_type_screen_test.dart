import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/sonartube_screen.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
  });

  tearDown(() {
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
  });

  testWidgets(
    'search selector keeps one adjustable node query and filter across rebuilds',
    (tester) async {
      var requests = 0;
      final service = SonarTubeService(
        enableDirectNavigation: false,
        client: MockClient((_) async {
          requests++;
          return http.Response('{"ok":true,"items":[]}', 200);
        }),
      );
      await tester.pumpWidget(_app(SonarTubeScreen(service: service)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sonartube_search_field')),
        'Flo',
      );

      final selector = find.byKey(
        const ValueKey('sonartube_search_type_slider_semantics'),
      );
      final originalNode = tester.getSemantics(selector).id;
      var control = tester.widget<Semantics>(selector);
      expect(control.properties.label, 'Tipo di ricerca');
      expect(control.properties.value, 'Tutto');
      expect(control.properties.increasedValue, 'Playlist');
      control.properties.onIncrease!();
      await tester.pump();
      control = tester.widget<Semantics>(selector);
      expect(control.properties.value, 'Playlist');
      expect(tester.getSemantics(selector).id, originalNode);

      // UIKit uses the same row event. The model supplies every spoken value
      // so repeated native increments also have the exact category labels.
      final list = tester.widget<UniversalAccessibleList>(
        find.byType(UniversalAccessibleList),
      );
      final row = list.sections
          .expand((section) => section.rows)
          .singleWhere((row) => row.id == 'search_type');
      expect(row.kind, 'slider');
      expect(row.sliderStep, 1);
      expect(row.value, 'Playlist');
      expect(row.valueLabel, 'Playlist');
      expect(row.options.map((option) => option.label), [
        'Tutto',
        'Playlist',
        'Canali',
        'Corsi',
        'Podcast',
      ]);
      await list.onEvent!(
        const AccessibleListEvent(id: 'search_type', type: 'slider', value: 2),
      );
      await tester.pump();
      control = tester.widget<Semantics>(selector);
      expect(control.properties.value, 'Canali');
      expect(control.properties.increasedValue, 'Corsi');
      expect(tester.getSemantics(selector).id, originalNode);
      control.properties.onIncrease!();
      await tester.pump();
      expect(tester.widget<Semantics>(selector).properties.value, 'Corsi');
      expect(tester.getSemantics(selector).id, originalNode);
      tester.widget<Semantics>(selector).properties.onIncrease!();
      await tester.pump();
      expect(tester.widget<Semantics>(selector).properties.value, 'Podcast');
      expect(tester.getSemantics(selector).id, originalNode);

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('sonartube_search_field')),
      );
      expect(field.controller!.text, 'Flo');
      expect(requests, 0);
    },
    semanticsEnabled: true,
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'selected playlist filter survives pagination collection opening and Back',
    (tester) async {
      final searchRequests = <Map<String, String>>[];
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        enableDirectNavigation: false,
        client: MockClient((request) async {
          final query = request.url.queryParameters;
          if (query['browse'] != null) {
            expect(query['kind'], 'playlist');
            expect(query['browse'], 'PL_flo_2');
            return http.Response(
              jsonEncode({
                'ok': true,
                'page': 1,
                'items': [
                  {
                    'kind': 'video',
                    'id': 'abcdefghijk',
                    'title': 'Episodio di Flo',
                    'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                    'views': '100 visualizzazioni',
                  },
                ],
              }),
              200,
            );
          }
          searchRequests.add(Map.of(query));
          final page = int.parse(query['page']!);
          return http.Response(
            jsonEncode({
              'ok': true,
              'page': page,
              if (page == 1) 'next_token': 'playlist-page-2',
              'items': [
                {
                  'kind': 'playlist',
                  'id': 'PL_flo_$page',
                  'title': 'Flo playlist $page',
                  'url': 'https://www.youtube.com/playlist?list=PL_flo_$page',
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(_app(SonarTubeScreen(service: service)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sonartube_search_field')),
        'Flo',
      );
      tester
          .widget<Slider>(
            find.byKey(const ValueKey('sonartube_search_type_slider')),
          )
          .onChanged!(1);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sonartube_search_button')));
      await tester.pumpAndSettle();
      expect(find.text('Flo playlist 1'), findsOneWidget);
      expect(searchRequests.single['q'], 'Flo');
      expect(searchRequests.single['type'], 'playlist');

      await tester.tap(find.byKey(const ValueKey('sonartube_load_more')));
      await tester.pumpAndSettle();
      expect(find.text('Flo playlist 2'), findsOneWidget);
      expect(searchRequests, hasLength(2));
      expect(searchRequests.last['q'], 'Flo');
      expect(searchRequests.last['type'], 'playlist');
      expect(searchRequests.last['token'], 'playlist-page-2');
      expect(searchRequests.last['page'], '2');

      await tester.tap(find.text('Flo playlist 2'));
      await tester.pumpAndSettle();
      expect(find.text('Episodio di Flo'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sonartube_collection_back')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('sonartube_search_results_back')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Slider>(
              find.byKey(const ValueKey('sonartube_search_type_slider')),
            )
            .value,
        1,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('sonartube_search_field')),
            )
            .controller!
            .text,
        'Flo',
      );
    },
  );  testWidgets(
    'selected course filter survives pagination collection opening and Back',
    (tester) async {
      final searchRequests = <Map<String, String>>[];
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        enableDirectNavigation: false,
        client: MockClient((request) async {
          final query = request.url.queryParameters;
          if (query['browse'] != null) {
            expect(query['kind'], 'playlist');
            expect(query['browse'], 'PL_flo_2');
            return http.Response(
              jsonEncode({
                'ok': true,
                'page': 1,
                'items': [
                  {
                    'kind': 'video',
                    'id': 'abcdefghijk',
                    'title': 'Episodio di Flo',
                    'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                    'views': '100 visualizzazioni',
                  },
                ],
              }),
              200,
            );
          }
          searchRequests.add(Map.of(query));
          final page = int.parse(query['page']!);
          return http.Response(
            jsonEncode({
              'ok': true,
              'page': page,
              if (page == 1) 'next_token': 'playlist-page-2',
              'items': [
                {
                  'kind': 'playlist',
                  'collection_type': 'course',
                  'id': 'PL_flo_$page',
                  'title': 'Flo playlist $page',
                  'url': 'https://www.youtube.com/playlist?list=PL_flo_$page',
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(_app(SonarTubeScreen(service: service)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sonartube_search_field')),
        'Flo',
      );
      tester
          .widget<Slider>(
            find.byKey(const ValueKey('sonartube_search_type_slider')),
          )
          .onChanged!(3);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sonartube_search_button')));
      await tester.pumpAndSettle();
      expect(find.text('Flo playlist 1'), findsOneWidget);
      expect(searchRequests.single['q'], 'Flo');
      expect(searchRequests.single['type'], 'course');

      await tester.tap(find.byKey(const ValueKey('sonartube_load_more')));
      await tester.pumpAndSettle();
      expect(find.text('Flo playlist 2'), findsOneWidget);
      expect(searchRequests, hasLength(2));
      expect(searchRequests.last['q'], 'Flo');
      expect(searchRequests.last['type'], 'course');
      expect(searchRequests.last['token'], 'playlist-page-2');
      expect(searchRequests.last['page'], '2');

      await tester.tap(find.text('Flo playlist 2'));
      await tester.pumpAndSettle();
      expect(find.text('Episodio di Flo'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sonartube_collection_back')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('sonartube_search_results_back')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Slider>(
              find.byKey(const ValueKey('sonartube_search_type_slider')),
            )
            .value,
        3,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('sonartube_search_field')),
            )
            .controller!
            .text,
        'Flo',
      );
    },
  );  testWidgets(
    'selected podcast filter survives pagination collection opening and Back',
    (tester) async {
      final searchRequests = <Map<String, String>>[];
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        enableDirectNavigation: false,
        client: MockClient((request) async {
          final query = request.url.queryParameters;
          if (query['browse'] != null) {
            expect(query['kind'], 'playlist');
            expect(query['browse'], 'PL_flo_2');
            return http.Response(
              jsonEncode({
                'ok': true,
                'page': 1,
                'items': [
                  {
                    'kind': 'video',
                    'id': 'abcdefghijk',
                    'title': 'Episodio di Flo',
                    'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                    'views': '100 visualizzazioni',
                  },
                ],
              }),
              200,
            );
          }
          searchRequests.add(Map.of(query));
          final page = int.parse(query['page']!);
          return http.Response(
            jsonEncode({
              'ok': true,
              'page': page,
              if (page == 1) 'next_token': 'playlist-page-2',
              'items': [
                {
                  'kind': 'playlist',
                  'collection_type': 'podcast',
                  'id': 'PL_flo_$page',
                  'title': 'Flo playlist $page',
                  'url': 'https://www.youtube.com/playlist?list=PL_flo_$page',
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(_app(SonarTubeScreen(service: service)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sonartube_search_field')),
        'Flo',
      );
      tester
          .widget<Slider>(
            find.byKey(const ValueKey('sonartube_search_type_slider')),
          )
          .onChanged!(4);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sonartube_search_button')));
      await tester.pumpAndSettle();
      expect(find.text('Flo playlist 1'), findsOneWidget);
      expect(searchRequests.single['q'], 'Flo');
      expect(searchRequests.single['type'], 'podcast');

      await tester.tap(find.byKey(const ValueKey('sonartube_load_more')));
      await tester.pumpAndSettle();
      expect(find.text('Flo playlist 2'), findsOneWidget);
      expect(searchRequests, hasLength(2));
      expect(searchRequests.last['q'], 'Flo');
      expect(searchRequests.last['type'], 'podcast');
      expect(searchRequests.last['token'], 'playlist-page-2');
      expect(searchRequests.last['page'], '2');

      await tester.tap(find.text('Flo playlist 2'));
      await tester.pumpAndSettle();
      expect(find.text('Episodio di Flo'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sonartube_collection_back')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('sonartube_search_results_back')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Slider>(
              find.byKey(const ValueKey('sonartube_search_type_slider')),
            )
            .value,
        4,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('sonartube_search_field')),
            )
            .controller!
            .text,
        'Flo',
      );
    },
  );
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('it'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
