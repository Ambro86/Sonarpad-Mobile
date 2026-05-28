import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/route_service.dart';

void main() {
  group('RouteService', () {
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
            jsonEncode({
              'ok': false,
              'error': 'Client non autorizzato.',
            }),
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
  });
}
