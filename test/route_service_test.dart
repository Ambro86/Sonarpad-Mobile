import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/route_service.dart';

void main() {
  group('RouteService', () {
    const from = GeocodeCandidate(
      label: 'Oxford Circus',
      name: '',
      country: '',
      region: '',
      locality: '',
      postalcode: '',
      latitude: 51.5152,
      longitude: -0.1419,
    );
    const to = GeocodeCandidate(
      label: 'British Museum',
      name: '',
      country: '',
      region: '',
      locality: '',
      postalcode: '',
      latitude: 51.5194,
      longitude: -0.127,
    );
    final primaryBody = jsonEncode({
      'ok': true,
      'data': {
        'preferenza': 'fastest',
        'evita': '',
        'percorsi': [
          {
            'distanza': '1.2 mi',
            'distanza_metri': 1900,
            'durata_secondi': 1200,
            'durata': '20 min',
            'istruzioni': ['Walk to the stop', 'Take Bus 12 at 12:30'],
          },
          {
            'distanza': '1.4 mi',
            'distanza_metri': 2300,
            'durata_secondi': 1440,
            'durata': '24 min',
            'istruzioni': ['Take Underground Central'],
          },
        ],
      },
    });
    final orsBody = jsonEncode({
      'ok': true,
      'distance_meters': 1000,
      'duration_seconds': 600,
      'steps': [
        {
          'instruction': 'Continue',
          'distance_meters': 1000,
          'duration_seconds': 600,
        },
      ],
    });

    for (final profile in [
      RouteProfile.walking,
      RouteProfile.driving,
      RouteProfile.transit,
    ]) {
      test('primary route succeeds without ORS: ${profile.name}', () async {
        final calls = <String>[];
        final service = RouteService(
          client: MockClient((request) async {
            calls.add(request.url.path);
            expect(request.method, 'POST');
            expect(request.headers['X-Sonarpad-Route-Token'], isNotNull);
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['da'], '51.5152,-0.1419');
            expect(body['a'], '51.5194,-0.127');
            expect(body['paese'], 'gb');
            expect(body['lingua'], 'en');
            expect(body['partenza'], 'adesso');
            expect(
              body['mezzo'],
              profile == RouteProfile.walking
                  ? 'piedi'
                  : profile == RouteProfile.driving
                  ? 'auto'
                  : 'pullman',
            );
            return http.Response(primaryBody, 200);
          }),
        );
        final result = await service.calculateRoute(
          from: from,
          to: to,
          profile: profile,
          preference: RoutePreference.fastest,
          includeMunicipalities: false,
          language: 'en',
          countryCode: 'gb',
        );
        expect(calls, ['/api/percorsi.php']);
        expect(result.paths, hasLength(2));
        expect(result.paths.first.distanceText, '1.2 mi');
        expect(result.paths.first.durationText, '20 min');
        expect(
          result.paths.first.steps.last.instruction,
          'Take Bus 12 at 12:30',
        );
      });
    }

    for (final badResponse in [
      http.Response('upstream down', 502),
      http.Response('not JSON', 200),
      http.Response('{"ok":true,"data":{"percorsi":[]}}', 200),
      http.Response('{"ok":false}', 200),
    ]) {
      test(
        'primary failure falls back for walking and driving: ${badResponse.body}',
        () async {
          for (final profile in [RouteProfile.walking, RouteProfile.driving]) {
            final calls = <String>[];
            final service = RouteService(
              client: MockClient((request) async {
                calls.add(request.url.path);
                if (request.url.path.endsWith('/percorsi.php'))
                  return badResponse;
                expect(
                  request.url.queryParameters['profile'],
                  profile.apiValue,
                );
                return http.Response(orsBody, 200);
              }),
            );
            final result = await service.calculateRoute(
              from: from,
              to: to,
              profile: profile,
              preference: RoutePreference.fastest,
              includeMunicipalities: false,
              language: 'en',
              countryCode: 'gb',
            );
            expect(calls, ['/api/percorsi.php', '/api/ors_route.php']);
            expect(result.paths.first.distanceMeters, 1000);
            expect(result.paths.first.distanceText, isNull);
          }
        },
      );
    }

    test('scheduled transit sends selected time and origin timezone to Google', () async {
      final requests = <Map<String, dynamic>>[];
      final service = RouteService(client: MockClient((request) async {
        expect(request.url.path, '/api/percorsi.php');
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(primaryBody, 200);
      }));
      for (final profile in [RouteProfile.transit, RouteProfile.driving]) {
        await service.calculateRoute(from: from, to: to, profile: profile,
          preference: RoutePreference.fastest, includeMunicipalities: false,
          language: 'en', countryCode: 'gb', departureTime: '18:35', departureTimeZone: 'Europe/London');
      }
      expect(requests.first['partenza'], '18:35');
      expect(requests.first['fuso'], 'Europe/London');
      expect(requests.first['mezzo'], 'pullman');
      expect(requests.last['partenza'], 'adesso');
      expect(requests.last.containsKey('fuso'), isFalse);
    });

    test('transit failure never becomes a walking ORS route', () async {
      final calls = <String>[];
      final service = RouteService(
        client: MockClient((request) async {
          calls.add(request.url.path);
          return http.Response('{"ok":false}', 502);
        }),
      );
      await expectLater(
        service.calculateRoute(
          from: from,
          to: to,
          profile: RouteProfile.transit,
          preference: RoutePreference.fastest,
          includeMunicipalities: false,
          language: 'en',
          countryCode: 'gb',
        ),
        throwsException,
      );
      expect(calls, ['/api/percorsi.php']);
    });

    for (final profile in [RouteProfile.wheelchair]) {
      test('${profile.name} uses ORS directly', () async {
        final service = RouteService(
          client: MockClient((request) async {
            expect(request.url.path, '/api/ors_route.php');
            expect(request.url.queryParameters['profile'], profile.apiValue);
            return http.Response(orsBody, 200);
          }),
        );
        await service.calculateRoute(
          from: from,
          to: to,
          profile: profile,
          preference: RoutePreference.fastest,
          includeMunicipalities: false,
          language: 'en',
          countryCode: 'gb',
        );
      });
    }

    test(
      'shortest and cycling use primary; ignored preferences trigger ORS',
      () async {
        for (final profile in [RouteProfile.driving, RouteProfile.cycling]) {
          final calls = <String>[];
          final service = RouteService(
            client: MockClient((request) async {
              calls.add(request.url.path);
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['preferenza'], 'shortest');
              expect(
                body['mezzo'],
                profile == RouteProfile.cycling ? 'bici' : 'auto',
              );
              final response = jsonDecode(primaryBody) as Map<String, dynamic>;
              response['data']['preferenza'] = 'shortest';
              return http.Response(jsonEncode(response), 200);
            }),
          );
          final result = await service.calculateRoute(
            from: from,
            to: to,
            profile: profile,
            preference: RoutePreference.shortest,
            includeMunicipalities: false,
            language: 'en',
            countryCode: 'gb',
          );
          expect(calls, ['/api/percorsi.php']);
          expect(result.paths.first.distanceMeters, 1900);
        }
        final calls = <String>[];
        final service = RouteService(
          client: MockClient((request) async {
            calls.add(request.url.path);
            return http.Response(
              request.url.path.endsWith('percorsi.php') ? primaryBody : orsBody,
              200,
            );
          }),
        );
        await service.calculateRoute(
          from: from,
          to: to,
          profile: RouteProfile.walking,
          preference: RoutePreference.shortest,
          includeMunicipalities: false,
          language: 'en',
          countryCode: 'gb',
        );
        expect(calls, ['/api/percorsi.php', '/api/ors_route.php']);
      },
    );

    test('localities enrich the same primary route without ORS', () async {
      final calls = <String>[];
      final service = RouteService(
        client: MockClient((request) async {
          calls.add(request.url.path);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['includi_comuni'], true);
          expect(body['da'], '51.5152,-0.1419');
          final data = jsonDecode(primaryBody) as Map<String, dynamic>;
          data['data']['includi_comuni'] = true;
          (data['data']['percorsi'][0]['istruzioni'] as List).insert(
            0,
            'Locality detected along the route: London.',
          );
          return http.Response(jsonEncode(data), 200);
        }),
      );
      final result = await service.calculateRoute(
        from: from,
        to: to,
        profile: RouteProfile.driving,
        preference: RoutePreference.fastest,
        includeMunicipalities: true,
        language: 'en',
        countryCode: 'gb',
      );
      expect(calls, ['/api/percorsi.php']);
      expect(result.paths.first.distanceMeters, 1900);
      expect(result.paths.first.steps.first.instruction, contains('London'));
    });

    test('builds route API request with encoded query parameters', () async {
      Uri? requestedUri;

      final service = RouteService(
        client: MockClient((request) async {
          requestedUri = request.url;
          expect(request.headers['X-Sonarpad-Route-Token'], isNotNull);
          return http.Response(
            jsonEncode({
              'ok': true,
              'distance_meters': 1000,
              'duration_seconds': 600,
              'steps': [],
            }),
            200,
          );
        }),
      );

      await service.calculateRoute(
        from: const GeocodeCandidate(
          label: 'Partenza',
          name: 'Partenza',
          country: 'Italia',
          region: '',
          locality: 'Roma',
          postalcode: '',
          latitude: 41.9028,
          longitude: 12.4964,
        ),
        to: const GeocodeCandidate(
          label: 'Arrivo',
          name: 'Arrivo',
          country: 'Italia',
          region: '',
          locality: 'Roma',
          postalcode: '',
          latitude: 41.9039,
          longitude: 12.4534,
        ),
        profile: RouteProfile.walking,
        preference: RoutePreference.fastest,
        includeMunicipalities: true,
        language: 'it',
        countryCode: 'it',
      );

      expect(requestedUri, isNotNull);
      expect(requestedUri!.path, '/api/ors_route.php');
      expect(requestedUri!.queryParameters['from_lat'], '41.9028');
      expect(requestedUri!.queryParameters['from_lon'], '12.4964');
      expect(requestedUri!.queryParameters['to_lat'], '41.9039');
      expect(requestedUri!.queryParameters['to_lon'], '12.4534');
      expect(requestedUri!.queryParameters['profile'], 'foot-walking');
      expect(requestedUri!.queryParameters['include_municipalities'], '1');
      expect(requestedUri!.queryParameters['boundary.country'], 'ITA');
    });

    test('maps unauthorized route server error to app message', () async {
      final service = RouteService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'ok': false, 'error': 'Client non autorizzato.'}),
            200,
          );
        }),
      );

      expect(
        () => service.calculateRoute(
          from: const GeocodeCandidate(
            label: 'Partenza',
            name: 'Partenza',
            country: 'Italia',
            region: '',
            locality: 'Roma',
            postalcode: '',
            latitude: 41.9028,
            longitude: 12.4964,
          ),
          to: const GeocodeCandidate(
            label: 'Arrivo',
            name: 'Arrivo',
            country: 'Italia',
            region: '',
            locality: 'Roma',
            postalcode: '',
            latitude: 41.9039,
            longitude: 12.4534,
          ),
          profile: RouteProfile.walking,
          preference: RoutePreference.fastest,
          includeMunicipalities: false,
          language: 'it',
          countryCode: 'it',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Client non autorizzato'),
          ),
        ),
      );
    });

    test(
      'Turkish geocoding and routes use TUR and preserve the language',
      () async {
        final requestedUris = <Uri>[];
        final service = RouteService(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/percorsi.php')) {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['lingua'], 'tr');
              return http.Response('{"ok":false}', 502);
            }
            requestedUris.add(request.url);
            return http.Response(
              jsonEncode({
                'ok': true,
                'results': [],
                'distance_meters': 1000,
                'duration_seconds': 600,
                'steps': [],
              }),
              200,
            );
          }),
        );
        const from = GeocodeCandidate(
          label: 'Taksim',
          name: 'Taksim',
          country: 'Türkiye',
          region: '',
          locality: 'İstanbul',
          postalcode: '',
          latitude: 41.0369,
          longitude: 28.9850,
        );
        const to = GeocodeCandidate(
          label: 'Sultanahmet',
          name: 'Sultanahmet',
          country: 'Türkiye',
          region: '',
          locality: 'İstanbul',
          postalcode: '',
          latitude: 41.0086,
          longitude: 28.9802,
        );

        for (final country in ['tr', 'TR', 'TUR']) {
          await service.geocode(
            query: 'Taksim, İstanbul',
            language: 'tr',
            countryCode: country,
          );
          await service.calculateRoute(
            from: from,
            to: to,
            profile: RouteProfile.walking,
            preference: RoutePreference.fastest,
            includeMunicipalities: false,
            language: 'tr',
            countryCode: country,
          );
        }

        expect(requestedUris, hasLength(6));
        for (final uri in requestedUris) {
          expect(uri.queryParameters['boundary.country'], 'TUR');
          expect(uri.queryParameters['language'], 'tr');
        }
        expect(requestedUris.first.queryParameters['q'], 'Taksim, İstanbul');
      },
    );
  });
}
