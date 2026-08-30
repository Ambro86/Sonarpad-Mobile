import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weather fetches European AQI without making weather depend on it', () {
    final source = File('lib/services/news/weather_service.dart').readAsStringSync();
    expect(source, contains('air-quality-api.open-meteo.com/v1/air-quality'));
    expect(source, contains("'current': 'european_aqi'"));
    expect(source, contains('_getCurrentAirQuality'));
    expect(source, contains('catch (_)'));
    expect(source, contains('airQualityCurrent: airQualityCurrent'));
  });

  test('weather exposes air quality in both shared UIKit and Flutter paths', () {
    final source = File('lib/screens/weather_screen.dart').readAsStringSync();
    expect(source, contains("id: 'air_quality'"));
    expect(source, contains('title: l10n.weatherAirQuality'));
    expect(source, contains('Text(l10n.weatherAirQuality)'));
    expect(source, contains("forecast.airQualityCurrent['european_aqi']"));
    expect(source, contains('weatherAirQualityExtremelyPoor'));
  });

  test('every locale contains air quality labels', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'));
    for (final file in arbFiles) {
      final source = file.readAsStringSync();
      expect(source, contains('"weatherAirQuality"'), reason: file.path);
      expect(source, contains('"weatherAirQualityGood"'), reason: file.path);
      expect(source, contains('"weatherAirQualityExtremelyPoor"'), reason: file.path);
    }
  });
}
