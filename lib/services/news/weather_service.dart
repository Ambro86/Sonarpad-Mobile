import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../utils/text_input_normalizer.dart';

class WeatherGeocodingResult {
  final double latitude;
  final double longitude;
  final String name;
  final String? admin1;
  final String? country;

  WeatherGeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.name,
    this.admin1,
    this.country,
  });

  factory WeatherGeocodingResult.fromJson(Map<String, dynamic> json) {
    return WeatherGeocodingResult(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      name: json['name'] as String,
      admin1: json['admin1'] as String?,
      country: json['country'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      if (admin1 != null) 'admin1': admin1,
      if (country != null) 'country': country,
    };
  }
}

class WeatherForecast {
  final Map<String, dynamic> current;
  final Map<String, dynamic> daily;
  final Map<String, dynamic> hourly;

  WeatherForecast({
    required this.current,
    required this.daily,
    required this.hourly,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      current: json['current'] as Map<String, dynamic>? ?? {},
      daily: json['daily'] as Map<String, dynamic>? ?? {},
      hourly: json['hourly'] as Map<String, dynamic>? ?? {},
    );
  }
}

class OpenMeteoWeatherService {
  static const String _geocodeEndpoint =
      'https://geocoding-api.open-meteo.com/v1/search';
  static const String _forecastEndpoint =
      'https://api.open-meteo.com/v1/forecast';
  static const int _cacheTtlSeconds = 600;

  final Map<String, _CacheEntry> _cache = {};

  Future<List<WeatherGeocodingResult>> searchCity(String query) async {
    final normalizedQuery = normalizeSearchInput(query);
    if (normalizedQuery.isEmpty) return const [];
    final uri = Uri.parse(_geocodeEndpoint).replace(queryParameters: {
      'name': normalizedQuery,
      'count': '5',
      'language': 'it',
      'format': 'json',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['results'] != null) {
        return (data['results'] as List)
            .map((e) =>
                WeatherGeocodingResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<WeatherForecast?> getForecast(double lat, double lon) async {
    final cacheKey = '$lat,$lon';
    if (_cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (DateTime.now().difference(entry.timestamp).inSeconds <
          _cacheTtlSeconds) {
        return entry.forecast;
      }
    }

    const currentFields = [
      'temperature_2m',
      'relative_humidity_2m',
      'weather_code',
    ];
    const dailyFields = [
      'temperature_2m_max',
      'temperature_2m_min',
      'precipitation_probability_max',
      'precipitation_sum',
      'wind_speed_10m_max',
    ];

    final uri = Uri.parse(_forecastEndpoint).replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': currentFields.join(','),
      'daily': dailyFields.join(','),
      'timezone': 'auto',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final forecast = WeatherForecast.fromJson(data);
      _cache[cacheKey] =
          _CacheEntry(forecast: forecast, timestamp: DateTime.now());
      return forecast;
    }

    return null;
  }
}

class _CacheEntry {
  final WeatherForecast forecast;
  final DateTime timestamp;

  _CacheEntry({required this.forecast, required this.timestamp});
}
