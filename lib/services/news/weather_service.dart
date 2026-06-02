import 'dart:convert';
import 'package:http/http.dart' as http;

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
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      name: json['name'] as String,
      admin1: json['admin1'] as String?,
      country: json['country'] as String?,
    );
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
    final uri = Uri.parse(
        '$_geocodeEndpoint?name=${Uri.encodeComponent(query)}&count=5&language=it&format=json');
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

    final queryParams = [
      'latitude=$lat',
      'longitude=$lon',
      'current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,is_day',
      'hourly=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,weather_code,precipitation_probability,precipitation,rain,showers,snowfall,snow_depth,pressure_msl,surface_pressure,cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,visibility,evapotranspiration,vapour_pressure_deficit,wind_speed_10m,wind_speed_80m,wind_direction_80m,freezing_level_height,soil_temperature_0cm,soil_temperature_6cm,soil_temperature_18cm,soil_temperature_54cm,soil_moisture_0_to_1cm,soil_moisture_1_to_3cm,soil_moisture_3_to_9cm,soil_moisture_9_to_27cm,soil_moisture_27_to_81cm,shortwave_radiation,uv_index_clear_sky',
      'daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_probability_max,precipitation_sum,rain_sum,showers_sum,snowfall_sum,precipitation_hours,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,sunrise,sunset,daylight_duration,sunshine_duration,uv_index_max,uv_index_clear_sky_max,shortwave_radiation_sum,et0_fao_evapotranspiration',
      'timezone=auto'
    ].join('&');

    final uri = Uri.parse('$_forecastEndpoint?$queryParams');
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
