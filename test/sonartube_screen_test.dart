import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/sonartube_screen.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  testWidgets('builds every playlist video for VoiceOver traversal', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    const playlist = SonarTubeItem(
      kind: SonarTubeItemKind.playlist,
      id: 'PL_FLO',
      title: 'Flo La Piccola Robinson 1981',
      url: 'https://www.youtube.com/playlist?list=PL_FLO',
    );
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
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

    expect(
      find.byKey(const ValueKey('sonartube_video_video_50')),
      findsOneWidget,
    );
    final firstVideoSemantics = tester.getSemantics(
      find.byKey(const ValueKey('sonartube_video_video_1')),
    );
    expect(firstVideoSemantics.label, contains('Episodio 1'));
    expect(
      firstVideoSemantics.getSemanticsData().customSemanticsActionIds,
      isEmpty,
    );
    semanticsHandle.dispose();
  });

  testWidgets('searches and opens a channel with its real videos', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
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
    await tester.tap(find.byKey(const ValueKey('sonartube_favorites_button')));
    await tester.pumpAndSettle();

    expect(find.text('Canale da salvare'), findsOneWidget);
    await tester.tap(find.text('Canale da salvare'));
    await tester.pumpAndSettle();

    expect(find.text('Video preferito del canale'), findsOneWidget);
  });
}
