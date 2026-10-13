import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/screens/sonarmusic_screen.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

const _labels = [
  'Tutto',
  'Brani',
  'Album',
  'Artisti',
  'Playlist',
  'Video musicali',
];

Widget _app(SonarMusicService service, {Locale locale = const Locale('it')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SonarMusicScreen(service: service),
);

AccessibleListRow _searchTypeRow(WidgetTester tester) => tester
    .widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList))
    .sections
    .expand((section) => section.rows)
    .singleWhere((row) => row.id == 'search_type');

Future<void> _submitSearch(WidgetTester tester) async {
  final searchButton = find.widgetWithText(FilledButton, 'Cerca');
  await tester.ensureVisible(searchButton);
  await tester.tap(searchButton);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Run the Flutter renderer on both target platforms. UIKit's descriptor
    // is checked below; this does not simulate a native VoiceOver session.
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
  });

  tearDown(() {
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
  });

  testWidgets('Turkish music choices use ARB labels and retain the search text',
    (tester) async {
      final service = SonarMusicService(
        directCatalog: false,
        endpoint: Uri.parse('https://example.test/youtube_music_resolve.php'),
        client: MockClient((_) async {
          fail('Changing a category must not start a search.');
        }),
      );
      final l10n = lookupSupportedAppLocalizations('tr');
      await tester.pumpWidget(_app(service, locale: const Locale('tr')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'İstanbul');
      final row = _searchTypeRow(tester);
      expect(row.options.map((option) => option.label), [
        l10n.sonarMusicAll, l10n.sonarMusicSong, l10n.sonarMusicAlbum,
        l10n.sonarMusicArtist, l10n.sonarMusicPlaylist, l10n.sonarMusicVideo,
      ]);
      final selector = find.bySemanticsLabel(row.title);
      final node = tester.getSemantics(selector);
      final originalId = node.id;
      expect(node.getSemanticsData().value, 'Tümü');
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(tester.getSemantics(selector).id, originalId);
      expect(tester.getSemantics(selector).getSemanticsData().value, 'Şarkılar');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'İstanbul');
    },
  );

  testWidgets(
    'all music categories keep one adjustable node and preserve the query',
    (tester) async {
      var requests = 0;
      final service = SonarMusicService(
        directCatalog: false,
        endpoint: Uri.parse('https://example.test/youtube_music_resolve.php'),
        client: MockClient((_) async {
          requests++;
          return http.Response('{"ok":true,"items":[]}', 200);
        }),
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elisa Luce');

      final selector = find.bySemanticsLabel('Tipo di ricerca');
      final originalNodeId = tester.getSemantics(selector).id;
      final row = _searchTypeRow(tester);
      expect(row.kind, 'slider');
      expect(row.sliderMin, 0);
      expect(row.sliderMax, 5);
      expect(row.sliderStep, 1);
      expect(row.options.map((option) => option.value), [0, 1, 2, 3, 4, 5]);
      expect(row.options.map((option) => option.label), _labels);
      expect(row.toMap()['options'], [
        for (var index = 0; index < _labels.length; index++)
          {'value': index, 'label': _labels[index]},
      ]);

      for (var index = 0; index < _labels.length; index++) {
        final node = tester.getSemantics(selector);
        final data = node.getSemanticsData();
        expect(node.id, originalNodeId);
        expect(data.value, _labels[index]);
        expect(data.increasedValue, _labels[(index + 1).clamp(0, 5)]);
        expect(data.decreasedValue, _labels[(index - 1).clamp(0, 5)]);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Elisa Luce',
        );
        node.owner!.performAction(node.id, SemanticsAction.increase);
        await tester.pump();
      }
      // Increasing beyond the final category stays at the final category.
      expect(
        tester.getSemantics(selector).getSemanticsData().value,
        'Video musicali',
      );

      for (var index = _labels.length - 1; index >= 0; index--) {
        final node = tester.getSemantics(selector);
        expect(node.id, originalNodeId);
        expect(node.getSemanticsData().value, _labels[index]);
        node.owner!.performAction(node.id, SemanticsAction.decrease);
        await tester.pump();
      }
      expect(tester.getSemantics(selector).id, originalNodeId);
      expect(tester.getSemantics(selector).getSemanticsData().value, 'Tutto');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Elisa Luce',
      );
      expect(requests, 0);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'artist page shows songs without a duplicate search button',
    (tester) async {
      final service = SonarMusicService(
        directCatalog: false,
        endpoint: Uri.parse('https://example.test/youtube_music_resolve.php'),
        client: MockClient((request) async {
          expect(request.url.queryParameters['browse'], 'UCelisa');
          return http.Response(jsonEncode({
            'ok': true,
            'title': 'Elisa',
            'items': [
              {
                'kind': 'song',
                'id': 'abcdefghijk',
                'video_id': 'abcdefghijk',
                'title': 'Canzone di Elisa',
                'artist': 'Elisa',
              },
            ],
          }), 200);
        }),
      );
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarMusicScreen(
          service: service,
          collection: const SonarMusicItem(
            kind: 'artist',
            id: 'UCelisa',
            browseId: 'UCelisa',
            title: 'Elisa',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Canzone di Elisa'), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.search), findsNothing);
      expect(find.byType(TextField), findsNothing);
      final rows = tester.widget<UniversalAccessibleList>(
        find.byType(UniversalAccessibleList),
      ).sections.expand((section) => section.rows);
      expect(rows.any((row) => row.id == 'search' ||
          row.id == 'search_field' || row.id == 'search_type' ||
          row.id == 'suggest'), isFalse);
    },
  );

  testWidgets(
    'music filter reaches search pagination and remains selected after Back',
    (tester) async {
      final searches = <Map<String, String>>[];
      final browses = <Map<String, String>>[];
      final service = SonarMusicService(
        directCatalog: false,
        endpoint: Uri.parse('https://example.test/youtube_music_resolve.php'),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.host, 'example.test');
          final query = request.url.queryParameters;
          if (query['browse'] != null) {
            browses.add(Map.of(query));
            return http.Response(
              jsonEncode({
                'ok': true,
                'title': 'Album di Elisa',
                'items': [
                  {
                    'kind': 'song',
                    'id': 'abcdefghijk',
                    'video_id': 'abcdefghijk',
                    'title': 'Traccia album',
                  },
                ],
              }),
              200,
            );
          }
          searches.add(Map.of(query));
          final page = int.parse(query['page']!);
          return http.Response(
            jsonEncode({
              'ok': true,
              if (page == 1) 'next_token': 'elisa-albums-page-2',
              'items': [
                {
                  'kind': 'album',
                  'id': 'MPREalbum$page',
                  'browse_id': 'MPREalbum$page',
                  'title': 'Album Elisa $page',
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elisa');
      tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
      await tester.pump();
      await _submitSearch(tester);

      expect(find.text('Album Elisa 1'), findsOneWidget);
      expect(searches.single['q'], 'Elisa');
      expect(searches.single['type'], 'album');
      expect(searches.single['page'], '1');

      await tester.tap(find.text('Carica altri risultati'));
      await tester.pumpAndSettle();
      expect(find.text('Album Elisa 2'), findsOneWidget);
      expect(searches, hasLength(2));
      expect(searches.last['q'], 'Elisa');
      expect(searches.last['type'], 'album');
      expect(searches.last['page'], '2');
      expect(searches.last['token'], 'elisa-albums-page-2');

      await tester.tap(find.text('Album Elisa 2'));
      await tester.pumpAndSettle();
      expect(find.text('Traccia album'), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.search), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(browses.single['browse'], 'MPREalbum2');
      await tester.tap(find.byType(SonarpadBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Album Elisa 2'), findsOneWidget);
      expect(searches, hasLength(2));
      await tester.tap(
        find.byKey(const ValueKey('sonarmusic_search_results_back')),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Slider>(find.byType(Slider)).value, 2);
      expect(_searchTypeRow(tester).valueLabel, 'Album');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Elisa',
      );
      await _submitSearch(tester);
      expect(searches, hasLength(3));
      expect(searches.last['q'], 'Elisa');
      expect(searches.last['type'], 'album');
      expect(searches.last['page'], '1');
      expect(searches.last.containsKey('token'), isFalse);
    },
  );
}
