import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../utils/text_input_normalizer.dart';

class WeatherGeocodingResult {
  final int? id;
  final double latitude;
  final double longitude;
  final String name;
  final String? admin1;
  final String? admin2;
  final String? admin3;
  final String? admin4;
  final String? country;

  WeatherGeocodingResult({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.name,
    this.admin1,
    this.admin2,
    this.admin3,
    this.admin4,
    this.country,
  });

  factory WeatherGeocodingResult.fromJson(Map<String, dynamic> json) {
    return WeatherGeocodingResult(
      id: (json['id'] as num?)?.toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      name: json['name'] as String,
      admin1: json['admin1'] as String?,
      admin2: json['admin2'] as String?,
      admin3: json['admin3'] as String?,
      admin4: json['admin4'] as String?,
      country: json['country'] as String?,
    );
  }

  /// Compact location detail used to distinguish places with the same name.
  /// Open-Meteo's admin2 is generally the most useful county/province-level
  /// value. If it is missing, fall back to a more specific administrative
  /// level before showing the broader region and country.
  String get locationSubtitle {
    final parts = <String>[];

    void addUnique(String? value) {
      final normalized = value?.trim() ?? '';
      if (normalized.isEmpty) return;
      final lower = normalized.toLowerCase();
      if (lower == name.trim().toLowerCase()) return;
      if (parts.any((part) => part.toLowerCase() == lower)) return;
      parts.add(normalized);
    }

    final countyOrDistrict = _firstNonEmpty([admin2, admin3, admin4]);
    addUnique(countyOrDistrict);
    addUnique(admin1);
    addUnique(country);
    return parts.join(', ');
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      if (admin1 != null) 'admin1': admin1,
      if (admin2 != null) 'admin2': admin2,
      if (admin3 != null) 'admin3': admin3,
      if (admin4 != null) 'admin4': admin4,
      if (country != null) 'country': country,
    };
  }
}

class WeatherForecast {
  final Map<String, dynamic> current;
  final Map<String, dynamic> daily;
  final Map<String, dynamic> hourly;
  final Map<String, dynamic> airQualityCurrent;

  WeatherForecast({
    required this.current,
    required this.daily,
    required this.hourly,
    this.airQualityCurrent = const {},
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      current: json['current'] as Map<String, dynamic>? ?? {},
      daily: json['daily'] as Map<String, dynamic>? ?? {},
      hourly: json['hourly'] as Map<String, dynamic>? ?? {},
      airQualityCurrent:
          json['air_quality_current'] as Map<String, dynamic>? ?? {},
    );
  }
}

class OpenMeteoWeatherService {
  static const String _geocodeEndpoint =
      'https://geocoding-api.open-meteo.com/v1/search';
  static const String _forecastEndpoint =
      'https://api.open-meteo.com/v1/forecast';
  static const String _airQualityEndpoint =
      'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const int _cacheTtlSeconds = 600;

  final Map<String, _CacheEntry> _cache = {};

  Future<List<WeatherGeocodingResult>> searchCity(
    String query, {
    String? localeName,
  }) async {
    final normalizedQuery = normalizeSearchInput(query);
    if (normalizedQuery.isEmpty) return const [];
    final uri = Uri.parse(_geocodeEndpoint).replace(queryParameters: {
      'name': normalizedQuery,
      'count': '5',
      'language': _geocodingLanguageForLocale(localeName),
      'format': 'json',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['results'] != null) {
        final results = (data['results'] as List)
            .map((e) =>
                WeatherGeocodingResult.fromJson(e as Map<String, dynamic>))
            .toList();

        // Open-Meteo can occasionally expose the same GeoNames location more
        // than once. Keep the ranked order while removing only exact location
        // duplicates; distinct places with the same name must remain visible.
        final seen = <String>{};
        return [
          for (final result in results)
            if (seen.add(result.id != null
                ? 'id:${result.id}'
                : 'coord:${result.latitude},${result.longitude}'))
              result,
        ];
      }
    }
    return [];
  }


  String _geocodingLanguageForLocale(String? localeName) {
    final code = (localeName ?? '').toLowerCase().replaceAll('_', '-');
    final languageCode = code.split('-').first;

    return switch (languageCode) {
      'cs' => 'cs',
      'de' => 'de',
      'en' => 'en',
      'es' => 'es',
      'fr' => 'fr',
      'it' => 'it',
      'pl' => 'pl',
      'pt' => 'pt',
      'zh' => 'zh',
      'uk' => 'uk',
      _ => 'en',
    };
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

    // Start the optional air-quality request in parallel so it does not add a
    // second network wait to the weather screen. If CAMS/Open-Meteo air
    // quality is temporarily unavailable, the weather forecast must still
    // remain usable.
    final airQualityFuture = _getCurrentAirQuality(lat, lon);
    final res = await http.get(uri).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final airQualityCurrent = await airQualityFuture;
      final forecast = WeatherForecast(
        current: data['current'] as Map<String, dynamic>? ?? {},
        daily: data['daily'] as Map<String, dynamic>? ?? {},
        hourly: data['hourly'] as Map<String, dynamic>? ?? {},
        airQualityCurrent: airQualityCurrent,
      );
      _cache[cacheKey] =
          _CacheEntry(forecast: forecast, timestamp: DateTime.now());
      return forecast;
    }

    return null;
  }

  Future<Map<String, dynamic>> _getCurrentAirQuality(
    double lat,
    double lon,
  ) async {
    final uri = Uri.parse(_airQualityEndpoint).replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': 'european_aqi',
      'timezone': 'auto',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const {};
      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return const {};
      return data['current'] as Map<String, dynamic>? ?? const {};
    } catch (_) {
      return const {};
    }
  }
}

class _CacheEntry {
  final WeatherForecast forecast;
  final DateTime timestamp;

  _CacheEntry({required this.forecast, required this.timestamp});
}
