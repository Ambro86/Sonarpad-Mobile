import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/route_result_screen.dart';
import 'package:sonarpad_mobile_starter/services/route_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  testWidgets(
    'route alternatives expose all service details to the list and native accessibility model',
    (tester) async {
      configureAccessibleRendererRuntime(useFlutterOnIos: true);
      addTearDown(
        () => configureAccessibleRendererRuntime(useFlutterOnIos: false),
      );
      const from = GeocodeCandidate(
        label: 'Start',
        name: '',
        country: '',
        region: '',
        locality: '',
        postalcode: '',
        latitude: 45.09,
        longitude: 7.68,
      );
      const firstService =
          'Take Bus 75. Board at Cigna at 19:01; get off at Grosseto at 19:11.';
      const otherService =
          'Take Bus 46. Board at Lauro Rossi at 19:26; get off at Rebaudengo at 19:31.';
      const transfer =
          'Take Bus 2. Board at Rebaudengo at 19:41; get off at Roccavione at 19:48.';
      RoutePath path(List<String> details) => RoutePath(
        distanceMeters: 2800,
        durationSeconds: 1200,
        distanceText: '2.8 km',
        durationText: '20 min',
        steps: const [],
        municipalityChanges: const [],
        transitDetails: details,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RouteResultScreen(
            result: RouteResult(
              from: from,
              to: from,
              profile: RouteProfile.transit,
              preference: RoutePreference.fastest,
              paths: [
                path([firstService]),
                path([otherService, transfer]),
                path([]),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(RouteResultScreen));
      final duration = '${AppLocalizations.of(context).routeDuration}: 20 min';
      final expected = [
        '$duration\n$firstService',
        '$duration\n$otherService\n$transfer',
        duration,
      ];
      for (final text in expected) {
        expect(find.text(text), findsOneWidget);
      }
      if (useSharedAccessibleViewModel) {
        final model = tester.widget<UniversalAccessibleList>(
          find.byType(UniversalAccessibleList),
        );
        final rows = model.sections.expand((section) => section.rows).toList();
        expect(rows.map((row) => row.toMap()['subtitle']), expected);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}
