import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/models/radio_station.dart';
import 'package:sonarpad_mobile_starter/services/radio_service.dart';

void main() {
  test('RadioBOSS is a first-class third radio source with diagnostic logging', () {
    final source = File('lib/services/radio_service.dart').readAsStringSync();
    expect(source, contains('https://sonarpad.com/api/radioboss.php'));
    expect(source, contains("source: 'RadioBOSS'"));
    expect(source, contains("'RadioBOSS: pagina sorgente "));
    expect(source, contains(r'${stations.length} risultati'));
    expect(source, contains('_fetchRadioBossStationsPage'));
  });

  test('multi-source session deduplicates and loads later RadioBOSS pages lazily',
      () async {
    final requestedBossPages = <int>[];
    final client = MockClient((request) async {
      final uri = request.url;
      if (uri.host.contains('api.radio-browser.info')) {
        final offset = int.tryParse(uri.queryParameters['offset'] ?? '0') ?? 0;
        if (offset > 0) return http.Response('[]', 200);
        return http.Response(
          jsonEncode([
            {
              'lastcheckok': 1,
              'url_resolved': 'https://radio.example/shared',
              'name': 'Shared Radio',
              'language': 'italian',
              'countrycode': 'IT',
              'country': 'Italy',
              'tags': 'pop',
              'votes': 100,
              'clickcount': 20,
            },
            {
              'lastcheckok': 1,
              'url_resolved': 'https://radio.example/browser-only',
              'name': 'Browser Only',
              'language': 'italian',
              'countrycode': 'IT',
              'country': 'Italy',
              'tags': 'pop',
            },
          ]),
          200,
        );
      }
      if (uri.toString().startsWith(
          'https://sonarpad.com/api/get_community_radios.php')) {
        return http.Response(
          jsonEncode([
            {
              'name': 'Community Only',
              'url': 'https://radio.example/community',
              'language': 'italian',
              'genre': 'pop',
              'genre_label': 'Pop',
            }
          ]),
          200,
        );
      }
      if (uri.toString().startsWith(
          'https://sonarpad.com/api/radioboss.php')) {
        final page = int.tryParse(uri.queryParameters['page'] ?? '0') ?? 0;
        requestedBossPages.add(page);
        final stations = page == 0
            ? [
                {
                  'id': 'duplicate',
                  'name': 'Shared Radio',
                  'stream': 'https://radio.example/shared',
                  'genre': 'pop',
                },
                {
                  'id': 'boss-1',
                  'name': 'RadioBOSS One',
                  'stream': 'https://radio.example/boss-1',
                  'genre': 'pop',
                },
              ]
            : [
                {
                  'id': 'boss-2',
                  'name': 'RadioBOSS Two',
                  'stream': 'https://radio.example/boss-2',
                  'genre': 'pop',
                },
              ];
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': page,
            'has_more': page == 0,
            'stations': stations,
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final service = RadioService(client: client);
    final session = service.createSearchSession(
      languageCode: 'it',
      genre: const RadioGenreOption('pop', 'pop'),
    );

    final first = await session.loadPage(0, pageSize: 2);
    expect(first.items, hasLength(2));
    expect(first.hasNext, isTrue);
    expect(requestedBossPages, contains(0));

    final second = await session.loadPage(1, pageSize: 2);
    final names = <String>{...first.items.map((e) => e.name), ...second.items.map((e) => e.name)};
    expect(names.where((name) => name == 'Shared Radio'), hasLength(1));
    expect(names, contains('Community Only'));
    expect(names, contains('RadioBOSS One'));

    // Request a later page large enough to exhaust the first merged batch and
    // force the next RadioBOSS page. The already-returned first page remains
    // stable because later batches are appended, not globally re-sorted.
    final later = await session.loadPage(2, pageSize: 2);
    expect(requestedBossPages, contains(1));
    expect(
      later.items.where((RadioStation station) => station.source == 'RadioBOSS'),
      isNotEmpty,
    );
  });
  test('RadioBOSS receives city filters on city browsing searches', () async {
    Uri? bossUri;
    final client = MockClient((request) async {
      final uri = request.url;
      if (uri.host.contains('api.radio-browser.info')) {
        return http.Response('[]', 200);
      }
      if (uri.toString().startsWith(
          'https://sonarpad.com/api/get_community_radios.php')) {
        return http.Response('[]', 200);
      }
      if (uri.toString().startsWith(
          'https://sonarpad.com/api/radioboss.php')) {
        bossUri = uri;
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 0,
            'has_more': false,
            'stations': [
              {
                'id': 'torino',
                'name': 'Torino Radio',
                'stream': 'https://radio.example/torino',
                'genre': 'local',
              }
            ],
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final service = RadioService(client: client);
    final session = service.createSearchSession(
      languageCode: 'city:Torino',
      genre: const RadioGenreOption('all', null),
    );
    final page = await session.loadPage(0);
    expect(page.items.map((e) => e.name), contains('Torino Radio'));
    expect(bossUri, isNotNull);
    expect(bossUri!.queryParameters['city'], 'Torino');
    expect(bossUri!.queryParameters.containsKey('language'), isFalse);
    expect(bossUri!.queryParameters.containsKey('country'), isFalse);
  });

}
