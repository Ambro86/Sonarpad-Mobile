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
