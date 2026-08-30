import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/news/weather_service.dart';

void main() {
  test('weather results expose county before region and country', () {
    final result = WeatherGeocodingResult(
      id: 1,
      latitude: 50.666,
      longitude: -2.6,
      name: 'Abbotsbury',
      admin1: 'England',
      admin2: 'Dorset',
      country: 'United Kingdom',
    );

    expect(result.locationSubtitle, 'Dorset, England, United Kingdom');
  });

  test('weather results fall back to a more specific administrative level', () {
    final result = WeatherGeocodingResult(
      latitude: 50.53,
      longitude: -3.61,
      name: 'Abbotsbury',
      admin1: 'England',
      admin3: 'Teignbridge',
      country: 'United Kingdom',
    );

    expect(result.locationSubtitle, 'Teignbridge, England, United Kingdom');
  });

  test('weather location details avoid repeated names', () {
    final result = WeatherGeocodingResult(
      latitude: 52.52,
      longitude: 13.41,
      name: 'Berlin',
      admin1: 'Berlin',
      admin2: 'Berlin',
      country: 'Germany',
    );

    expect(result.locationSubtitle, 'Germany');
  });

  test('weather saved city round trip preserves administrative details', () {
    final original = WeatherGeocodingResult(
      id: 123,
      latitude: 50.1,
      longitude: -2.1,
      name: 'Example',
      admin1: 'England',
      admin2: 'Dorset',
      admin3: 'District',
      admin4: 'Parish',
      country: 'United Kingdom',
    );

    final restored = WeatherGeocodingResult.fromJson(original.toJson());

    expect(restored.id, 123);
    expect(restored.admin2, 'Dorset');
    expect(restored.admin3, 'District');
    expect(restored.admin4, 'Parish');
    expect(restored.locationSubtitle, 'Dorset, England, United Kingdom');
  });
}
