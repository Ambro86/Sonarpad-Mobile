import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/route_screen.dart';
import 'package:sonarpad_mobile_starter/services/route_service.dart';
import 'package:sonarpad_mobile_starter/utils/app_logger.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

const origin = GeocodeCandidate(
  label: 'Via Francesco Cilea, 12, Torino, TO',
  name: 'Via Francesco Cilea, 12',
  country: 'it',
  region: '',
  locality: '',
  postalcode: '',
  latitude: 45.0983965,
  longitude: 7.7052344,
);
const school = {
  'indirizzo': 'IIS Romolo Zerboni, Via Paolo della Cella, Torino, TO',
  'nome': 'IIS Romolo Zerboni',
  'tipo': 'luogo',
  'latitude': 45.104888,
  'longitude': 7.6786255,
};
const distant = {
  'indirizzo':
      'Zerbonia Autodemolizioni, Strada Comunale Cabannoni, Alessandria, AL',
  'nome': 'Zerbonia Autodemolizioni',
  'tipo': 'luogo',
  'latitude': 44.8455399,
  'longitude': 8.6805169,
};
http.Response suggestions(List<Map<String, dynamic>> alternatives) =>
    http.Response(
      jsonEncode({
        'ok': true,
        'data': {'alternative': alternatives},
      }),
      200,
    );

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late PathProviderPlatform originalPaths;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp(
      'sonarpad_route_suggestions_',
    );
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(temporary.path);
  });
  tearDown(() async {
    await AppLogger.readLogs();
    PathProviderPlatform.instance = originalPaths;
    await temporary.delete(recursive: true);
  });

  test(
    'Google suggestions preserve all alternatives and rank nearby destinations first',
    () async {
      final requests = <http.Request>[];
      final service = RouteService(
        client: MockClient((request) async {
          requests.add(request);
          return suggestions([
            distant,
            school,
            {'indirizzo': 'zerboni torino'},
          ]);
        }),
      );
      final original = await service.geocode(
        query: 'zerboni',
        language: 'it',
        countryCode: 'it',
      );
      final nearby = await service.geocode(
        query: 'zerboni',
        language: 'it',
        countryCode: 'it',
        near: origin,
      );
      expect(original.map((c) => c.name), [
        'Zerbonia Autodemolizioni',
        'IIS Romolo Zerboni',
      ]);
      expect(nearby.map((c) => c.name), [
        'IIS Romolo Zerboni',
        'Zerbonia Autodemolizioni',
      ]);
      expect(nearby.first.latitude, school['latitude']);
      expect(nearby.first.longitude, school['longitude']);
      expect(nearby.every((c) => c.requiresConfirmation), isTrue);
      for (final request in requests) {
        expect(request.url.path, '/api/percorsi.php');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'azione': 'indirizzi',
          'q': 'zerboni',
          'paese': 'it',
          'lingua': 'it',
        });
      }
    },
  );

  test(
    'international suggestions use selected region and retain exact coordinates',
    () async {
      final service = RouteService(
        client: MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['paese'], 'gb');
          expect(body['lingua'], 'en-GB');
          return suggestions([
            {
              'indirizzo': '10 Downing Street, London, UK',
              'tipo': 'indirizzo',
              'latitude': 51.5033395,
              'longitude': -0.1275662,
            },
          ]);
        }),
      );
      final result = await service.geocode(
        query: '10 Downing Street',
        language: 'en-GB',
        countryCode: 'GB',
      );
      expect(result.single.longitude, -0.1275662);
      expect(result.single.requiresConfirmation, isFalse);
    },
  );

  final unavailable = [
    http.Response('unavailable', 502),
    http.Response('not json', 200),
    suggestions([]),
    suggestions([
      {'indirizzo': 'Old server without coordinates'},
    ]),
    suggestions([
      {...school, 'latitude': 91},
    ]),
    suggestions([
      {...school, 'civico_da_verificare': true},
    ]),
  ];
  for (var i = 0; i < unavailable.length; i++) {
    test(
      'Google unavailable or unusable preserves ORS fallback ($i)',
      () async {
        final calls = <String>[];
        final service = RouteService(
          client: MockClient((request) async {
            calls.add(request.url.path);
            if (request.method == 'POST') return unavailable[i];
            expect(request.url.queryParameters['q'], 'zerboni');
            expect(request.url.queryParameters['boundary.country'], 'ITA');
            return http.Response(
              jsonEncode({
                'ok': true,
                'results': [
                  {
                    'label': school['indirizzo'],
                    'latitude': school['latitude'],
                    'longitude': school['longitude'],
                  },
                ],
              }),
              200,
            );
          }),
        );
        final results = await service.geocode(
          query: 'zerboni',
          language: 'it',
          countryCode: 'it',
        );
        expect(calls, ['/api/percorsi.php', '/api/ors_geocode.php']);
        expect(results.single.displayLabel, school['indirizzo']);
        expect(results.single.latitude, school['latitude']);
      },
    );
  }

  for (final multiple in [true, false]) {
    testWidgets(
      'destination requires a choice before routing (multiple=$multiple)',
      (tester) async {
        configureAccessibleRendererRuntime(useFlutterOnIos: true);
        addTearDown(
          () => configureAccessibleRendererRuntime(useFlutterOnIos: false),
        );
        final routeRequests = <Map<String, dynamic>>[];
        final service = RouteService(
          client: MockClient((request) async {
            expect(request.url.path, '/api/percorsi.php');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['azione'] == 'indirizzi') {
              if (body['q'] == 'via francesco cilea 12') {
                return suggestions([
                  {
                    'indirizzo': origin.label,
                    'tipo': 'indirizzo',
                    'latitude': origin.latitude,
                    'longitude': origin.longitude,
                  },
                ]);
              }
              return suggestions([if (multiple) distant, school]);
            }
            routeRequests.add(body);
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {
                  'preferenza': 'fastest',
                  'evita': '',
                  'percorsi': [
                    {
                      'distanza': '2 km',
                      'distanza_metri': 2000,
                      'durata': '10 min',
                      'durata_secondi': 600,
                      'istruzioni': ['Arrivo alla destinazione.'],
                    },
                  ],
                },
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
            home: RouteScreen(routeService: service),
          ),
        );
        await tester.pumpAndSettle();
        final form = tester.widget<UniversalAccessibleList>(
          find.byType(UniversalAccessibleList),
        );
        await form.onEvent!(
          const AccessibleListEvent(
            type: 'textChanged',
            id: 'from',
            value: 'via francesco cilea 12',
          ),
        );
        await form.onEvent!(
          const AccessibleListEvent(
            type: 'textChanged',
            id: 'to',
            value: 'zerboni',
          ),
        );
        Future<void>? pending;
        await tester.runAsync(() async {
          pending = Future<void>.sync(
            () => form.onEvent!(
              const AccessibleListEvent(type: 'activate', id: 'calculate'),
            ),
          );
        });
        for (
          var i = 0;
          i < 100 && find.byType(AlertDialog).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(routeRequests, isEmpty);
        final choices = tester.widget<UniversalAccessibleList>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(UniversalAccessibleList),
          ),
        );
        final rows = choices.sections.expand((s) => s.rows).toList();
        expect(rows, hasLength(multiple ? 2 : 1));
        expect(rows.first.title, school['indirizzo']);
        // Choosing the farther option must be respected too; ranking is not a filter.
        final selection = multiple ? 1 : 0;
        await choices.onEvent!(
          AccessibleListEvent(type: 'activate', id: 'candidate_$selection'),
        );
        await tester.runAsync(() async => await pending);
        await tester.pumpAndSettle();
        expect(
          routeRequests.single['da'],
          '${origin.latitude},${origin.longitude}',
        );
        final chosen = multiple ? distant : school;
        expect(
          routeRequests.single['a'],
          '${chosen['latitude']},${chosen['longitude']}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
