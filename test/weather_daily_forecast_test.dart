import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/weather_screen.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  setUp(() {
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
    SharedPreferences.setMockInitialValues({
      'sonarpad_weather_city': jsonEncode({
        'latitude': 45.1,
        'longitude': 7.6,
        'name': 'Torino',
      }),
    });
  });
  tearDown(() => configureAccessibleRendererRuntime(useFlutterOnIos: false));
  testWidgets(
    'daily conditions follow selected day independently of current weather',
    (tester) async {
      var requestedDailyCode = false;
      final client = MockClient((request) async {
        if (request.url.host.startsWith('air-quality')) {
          return http.Response('{"current":{"european_aqi":20}}', 200);
        }
        requestedDailyCode = request.url.queryParameters['daily']!
            .split(',')
            .contains('weather_code');
        return http.Response(
          jsonEncode({
            'current': {'weather_code': 0, 'temperature_2m': 15},
            'daily': {
              'time': ['2026-11-13', '2026-11-14', '2026-11-15'],
              'weather_code': [3, 61, null],
              'precipitation_probability_max': [20, 80, null],
            },
          }),
          200,
        );
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const WeatherScreen(),
          ),
        );
        await tester.pumpAndSettle();
        UniversalAccessibleList list() => tester
            .widgetList<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList),
            )
            .firstWhere((w) => w.debugTag == 'weather');
        List<AccessibleListRow> rows() =>
            list().sections.expand((s) => s.rows).toList();
        AccessibleListRow row(String id) =>
            rows().firstWhere((r) => r.id == id);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(WeatherScreen)),
        );
        expect(requestedDailyCode, true);
        expect(row('situation').valueLabel, l10n.weatherConditionClearSky);
        expect(
          row('daily_situation').valueLabel,
          l10n.weatherConditionOvercast,
        );
        expect(row('rain_probability').valueLabel, '20 %');
        await list().onEvent!(
          const AccessibleListEvent(id: 'day', type: 'slider', value: 1),
        );
        await tester.pumpAndSettle();
        expect(row('day').sliderValue, 1);
        expect(rows().any((r) => r.id == 'situation'), false);
        expect(
          row('daily_situation').valueLabel,
          l10n.weatherConditionLightRain,
        );
        expect(row('rain_probability').valueLabel, '80 %');
        await list().onEvent!(
          const AccessibleListEvent(id: 'day', type: 'slider', value: 2),
        );
        await tester.pumpAndSettle();
        expect(row('daily_situation').valueLabel, '-');
        expect(row('rain_probability').valueLabel, '-');
        await tester.pumpWidget(const SizedBox());
      }, () => client);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
