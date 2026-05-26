import 'dart:convert';
import 'package:http/http.dart' as http;

enum RouteProfile {
  walking('foot-walking'),
  cycling('cycling-regular'),
  driving('driving-car'),
  wheelchair('wheelchair');

  final String apiValue;
  const RouteProfile(this.apiValue);
}

enum RoutePreference {
  fastest('fastest'),
  shortest('shortest');

  final String apiValue;
  const RoutePreference(this.apiValue);
}

class GeocodeCandidate {
  final String label;
  final String name;
  final String country;
  final String locality;
  final double latitude;
  final double longitude;

  const GeocodeCandidate({
    required this.label,
    required this.name,
    required this.country,
    required this.locality,
    required this.latitude,
    required this.longitude,
  });

  factory GeocodeCandidate.fromJson(Map<String, dynamic> json) {
    return GeocodeCandidate(
      label: (json['label'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      locality: (json['locality'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get displayLabel {
    if (label.trim().isNotEmpty) return label;
    final parts = <String>[];
    if (name.trim().isNotEmpty) parts.add(name);
    if (locality.trim().isNotEmpty) parts.add(locality);
    if (country.trim().isNotEmpty) parts.add(country);
    return parts.join(', ');
  }
}

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      instruction: (json['instruction'] ?? '').toString(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RoutePath {
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  const RoutePath({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  factory RoutePath.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'] as List<dynamic>? ?? [];
    return RoutePath(
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      steps: stepsJson.map((e) => RouteStep.fromJson(e)).toList(),
    );
  }
}

class RouteResult {
  final GeocodeCandidate from;
  final GeocodeCandidate to;
  final List<RoutePath> paths;
  final RouteProfile profile;
  final RoutePreference preference;

  const RouteResult({
    required this.from,
    required this.to,
    required this.paths,
    required this.profile,
    required this.preference,
  });
}

class RouteService {
  static const _baseUrl = 'https://sonarpad.com/api';
  static const _clientToken = String.fromEnvironment('SONARPAD_ROUTE_CLIENT_TOKEN');
  
  final http.Client _client;

  RouteService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'User-Agent': 'Sonarpad/1.0.0',
        'Accept': 'application/json',
        'X-Sonarpad-Route-Token': _clientToken,
      };

  String _countryAlpha3(String countryCode) {
    switch (countryCode.toLowerCase()) {
      case 'it': return 'ITA';
      case 'fr': return 'FRA';
      case 'de': return 'DEU';
      case 'es': return 'ESP';
      case 'us': return 'USA';
      case 'gb': return 'GBR';
      default: return 'ITA';
    }
  }

  Future<List<GeocodeCandidate>> geocode({
    required String query,
    required String language, // es: 'it'
    required String countryCode, // es: 'it'
  }) async {
    final q = query.trim();
    if (q.isEmpty) throw Exception('Indirizzo non valido');

    final uri = Uri.parse('$_baseUrl/ors_geocode.php').replace(queryParameters: {
      'q': q,
      'size': '20',
      'layers': 'address,street,venue',
      'sources': 'osm,oa',
      'boundary.country': _countryAlpha3(countryCode),
      'language': language,
    });

    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Errore di rete geocode: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Errore dal server');
    }

    final resultsJson = data['results'] as List<dynamic>? ?? [];
    return resultsJson.map((e) => GeocodeCandidate.fromJson(e)).toList();
  }

  Future<RouteResult> calculateRoute({
    required GeocodeCandidate from,
    required GeocodeCandidate to,
    required RouteProfile profile,
    required RoutePreference preference,
    required String language,
    required String countryCode,
  }) async {
    final uri = Uri.parse('$_baseUrl/ors_route.php').replace(queryParameters: {
      'from_lat': from.latitude.toString(),
      'from_lon': from.longitude.toString(),
      'to_lat': to.latitude.toString(),
      'to_lon': to.longitude.toString(),
      'profile': profile.apiValue,
      'preference': preference.apiValue,
      'avoid': '',
      'include_municipalities': '0',
      'language': language,
      'boundary.country': _countryAlpha3(countryCode),
    });

    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Errore di rete route: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Errore di calcolo percorso dal server');
    }

    List<RoutePath> paths = [];
    if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
      paths = (data['routes'] as List).map((e) => RoutePath.fromJson(e)).toList();
    } else {
      paths = [
        RoutePath(
          distanceMeters: (data['distance_meters'] as num?)?.toDouble() ?? 0.0,
          durationSeconds: (data['duration_seconds'] as num?)?.toDouble() ?? 0.0,
          steps: (data['steps'] as List<dynamic>? ?? []).map((e) => RouteStep.fromJson(e)).toList(),
        )
      ];
    }

    return RouteResult(
      from: from,
      to: to,
      paths: paths,
      profile: profile,
      preference: preference,
    );
  }

  Future<RouteResult> routeFromAddresses({
    required String fromAddress,
    required String toAddress,
    required RouteProfile profile,
    required RoutePreference preference,
    required String language,
    required String countryCode,
  }) async {
    final fromCandidates = await geocode(query: fromAddress, language: language, countryCode: countryCode);
    if (fromCandidates.isEmpty) throw Exception('Indirizzo di partenza non trovato');

    final toCandidates = await geocode(query: toAddress, language: language, countryCode: countryCode);
    if (toCandidates.isEmpty) throw Exception('Indirizzo di arrivo non trovato');

    // Per semplicità prendiamo il primo risultato. In Rustnotepad c'era il NeedsSelection, 
    // ma per l'UI standard prendiamo il best match.
    return calculateRoute(
      from: fromCandidates.first,
      to: toCandidates.first,
      profile: profile,
      preference: preference,
      language: language,
      countryCode: countryCode,
    );
  }
}
