import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Weather exposes current relative humidity in the shared UIKit model', () {
    final source = File('lib/screens/weather_screen.dart').readAsStringSync();

    expect(source, contains("id: 'humidity'"));
    expect(source, contains('title: l10n.weatherRelativeHumidity'));
    expect(
      source,
      contains("valueLabel: _currentPercentage('relative_humidity_2m')"),
    );
  });

  test('Weather formats humidity safely in both renderers', () {
    final source = File('lib/screens/weather_screen.dart').readAsStringSync();

    expect(source, contains('String _currentPercentage(String key)'));
    expect(source, contains("trailing: Text(_currentPercentage('relative_humidity_2m'))"));
    expect(source, isNot(contains("Text('\${forecast.current['relative_humidity_2m']}%')")));
  });
}
