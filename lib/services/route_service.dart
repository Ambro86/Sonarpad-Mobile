import 'dart:convert';
import 'dart:developer' as developer;
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
  final String region;
  final String locality;
  final String postalcode;
  final double latitude;
  final double longitude;

  const GeocodeCandidate({
    required this.label,
    required this.name,
    required this.country,
    required this.region,
    required this.locality,
    required this.postalcode,
    required this.latitude,
    required this.longitude,
  });

  factory GeocodeCandidate.fromJson(Map<String, dynamic> json) {
    return GeocodeCandidate(
      label: (json['label'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      region: (json['region'] ?? '').toString(),
      locality: (json['locality'] ?? '').toString(),
      postalcode: (json['postalcode'] ?? '').toString(),
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

class RouteMunicipalityChange {
  final String name;
  final double distanceMeters;

  const RouteMunicipalityChange({
    required this.name,
    required this.distanceMeters,
  });

  factory RouteMunicipalityChange.fromJson(Map<String, dynamic> json) {
    return RouteMunicipalityChange(
      name: (json['name'] ?? '').toString(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
    );
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
  final List<RouteMunicipalityChange> municipalityChanges;

  const RoutePath({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    required this.municipalityChanges,
  });

  factory RoutePath.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'] as List<dynamic>? ?? [];
    final municipalitiesJson =
        json['municipality_changes'] as List<dynamic>? ?? [];
    return RoutePath(
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      steps: stepsJson.map((e) => RouteStep.fromJson(e)).toList(),
      municipalityChanges: municipalitiesJson
          .map((e) => RouteMunicipalityChange.fromJson(e))
          .toList(),
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
  static const _clientToken =
      String.fromEnvironment('SONARPAD_ROUTE_CLIENT_TOKEN');
  static const _unauthorizedClientError = 'Client non autorizzato.';

  final http.Client _client;

  RouteService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'User-Agent': 'Sonarpad/1.0.0',
        'Accept': 'application/json',
        'X-Sonarpad-Route-Token': _clientToken,
      };

  String _countryAlpha3(String countryCode) {
    switch (countryCode.toLowerCase()) {
      case 'it':
        return 'ITA';
      case 'fr':
        return 'FRA';
      case 'au':
        return 'AUS';
      case 'ca':
        return 'CAN';
      case 'de':
        return 'DEU';
      case 'es':
        return 'ESP';
      case 'pt':
        return 'PRT';
      case 'br':
        return 'BRA';
      case 'cn':
        return 'CHN';
      case 'pl':
        return 'POL';
      case 'cz':
      case 'cs':
        return 'CZE';
      case 'us':
        return 'USA';
      case 'gb':
      case 'uk':
        return 'GBR';
      default:
        return 'ITA';
    }
  }

  Future<List<GeocodeCandidate>> geocode({
    required String query,
    required String language, // es: 'it'
    required String countryCode, // es: 'it'
  }) async {
    final q = query.trim();
    if (q.isEmpty) throw Exception(_invalidAddress(language));

    final results = await _fetchGeocode(
      query: q,
      language: language,
      countryCode: countryCode,
    );

    if (_isAllCityFallback(results, q)) {
      final simplified = _simplifyQuery(q);
      if (simplified != null) {
        try {
          final fallbackResults = await _fetchGeocode(
            query: simplified,
            language: language,
            countryCode: countryCode,
          );
          if (fallbackResults.isNotEmpty &&
              !_isAllCityFallback(fallbackResults, simplified)) {
            return fallbackResults;
          }
        } catch (error) {
          developer.log('Route geocode fallback failed', error: error);
        }
      }

      final moreSimplified = _simplifyQueryMore(q);
      if (moreSimplified != null) {
        try {
          final fallbackResults = await _fetchGeocode(
            query: moreSimplified,
            language: language,
            countryCode: countryCode,
          );
          if (fallbackResults.isNotEmpty &&
              !_isAllCityFallback(fallbackResults, moreSimplified)) {
            return fallbackResults;
          }
        } catch (error) {
          developer.log('Route geocode fallback failed', error: error);
        }
      }
    }

    return results;
  }

  Future<List<GeocodeCandidate>> _fetchGeocode({
    required String query,
    required String language,
    required String countryCode,
  }) async {
    final uri =
        Uri.parse('$_baseUrl/ors_geocode.php').replace(queryParameters: {
      'q': query,
      'size': '20',
      'layers': 'address,street,venue',
      'sources': 'osm,oa',
      'boundary.country': _countryAlpha3(countryCode),
      'language': language,
    });

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception(_networkGeocodeError(language, response.statusCode));
    }

    final data = jsonDecode(response.body);
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? _serverGenericError(language));
    }

    final resultsJson = data['results'] as List<dynamic>? ?? [];
    return resultsJson.map((e) => GeocodeCandidate.fromJson(e)).toList();
  }

  bool _isAllCityFallback(
      List<GeocodeCandidate> results, String originalQuery) {
    if (results.isEmpty || _splitWords(originalQuery).length <= 1) {
      return false;
    }

    return results.every((candidate) =>
        candidate.postalcode.isEmpty &&
        (candidate.name == candidate.locality ||
            candidate.name == candidate.region ||
            candidate.name == candidate.country));
  }

  String? _simplifyQuery(String query) {
    final words = _splitWords(query);
    if (words.length <= 1) return null;

    const prefixes = {
      'via',
      'corso',
      'viale',
      'piazza',
      'vicolo',
      'largo',
      'strada',
      'v.',
      'c.so',
      'p.zza',
      'p.za',
    };
    if (prefixes.contains(words.first.toLowerCase())) {
      words.removeAt(0);
    }

    if (words.isEmpty) return null;
    return words.join(' ');
  }

  String? _simplifyQueryMore(String query) {
    final words = _splitWords(query);

    const prefixes = {
      'via',
      'corso',
      'viale',
      'piazza',
      'vicolo',
      'largo',
      'strada',
      'v.',
      'c.so',
      'p.zza',
      'p.za',
    };
    if (words.isNotEmpty && prefixes.contains(words.first.toLowerCase())) {
      words.removeAt(0);
    }

    if (words.length > 2) {
      words.removeAt(0);
      return words.join(' ');
    }

    return null;
  }

  List<String> _splitWords(String query) =>
      query.split(' ').where((word) => word.trim().isNotEmpty).toList();

  Uri _routeEndpointUri(Map<String, String> params) {
    final base = Uri.parse(_baseUrl);
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        'ors_route.php',
      ],
      queryParameters: params,
    );
  }

  String _invalidAddress(String language) => switch (language) {
        'en' => 'Invalid address',
        'fr' => 'Adresse non valide',
        'es' => 'Dirección no válida',
        'pt' || 'pt_BR' => 'Endereço inválido',
        'zh' || 'zh_CN' => '地址无效',
        'pl' => 'Nieprawidłowy adres',
        'de' => 'Ungültige Adresse',
        _ => 'Indirizzo non valido',
      };

  String _networkGeocodeError(String language, int statusCode) =>
      switch (language) {
        'en' => 'Geocoding network error: HTTP $statusCode',
        'fr' => 'Erreur réseau de géocodage : HTTP $statusCode',
        'es' => 'Error de red de geocodificación: HTTP $statusCode',
        'pt' || 'pt_BR' => 'Erro de rede de geocodificação: HTTP $statusCode',
        'zh' || 'zh_CN' => '地理编码网络错误：HTTP $statusCode',
        'pl' => 'Błąd sieci geokodowania: HTTP $statusCode',
        'de' => 'Netzwerkfehler bei der Geokodierung: HTTP $statusCode',
        _ => 'Errore di rete geocode: HTTP $statusCode',
      };

  String _networkRouteError(String language, int statusCode) =>
      switch (language) {
        'en' => 'Route network error: HTTP $statusCode',
        'fr' => 'Erreur réseau de calcul d\'itinéraire : HTTP $statusCode',
        'es' => 'Error de red de ruta: HTTP $statusCode',
        'pt' || 'pt_BR' => 'Erro de rede de rota: HTTP $statusCode',
        'zh' || 'zh_CN' => '路线网络错误：HTTP $statusCode',
        'pl' => 'Błąd sieci trasy: HTTP $statusCode',
        'de' => 'Netzwerkfehler bei der Routenberechnung: HTTP $statusCode',
        _ => 'Errore di rete route: HTTP $statusCode',
      };

  String _serverGenericError(String language) => switch (language) {
        'en' => 'Server error',
        'fr' => 'Erreur du serveur',
        'es' => 'Error del servidor',
        'pt' || 'pt_BR' => 'Erro do servidor',
        'zh' || 'zh_CN' => '服务器错误',
        'pl' => 'Błąd serwera',
        'de' => 'Serverfehler',
        _ => 'Errore dal server',
      };

  String _routeCalculationServerError(String language) => switch (language) {
        'en' => 'Route calculation error from server',
        'fr' => 'Erreur de calcul d\'itinéraire du serveur',
        'es' => 'Error de cálculo de ruta del servidor',
        'pt' || 'pt_BR' => 'Erro de cálculo de rota do servidor',
        'zh' || 'zh_CN' => '服务器路线计算错误',
        'pl' => 'Błąd obliczania trasy po stronie serwera',
        'de' => 'Fehler bei der Routenberechnung auf dem Server',
        _ => 'Errore di calcolo percorso dal server',
      };

  String _unauthorizedError(String language) => switch (language) {
        'en' =>
          'Unauthorized client. Update Sonarpad or check the app configuration.',
        'fr' =>
          'Client non autorisé. Mettez à jour Sonarpad ou vérifiez la configuration de l\'application.',
        'es' =>
          'Cliente no autorizado. Actualiza Sonarpad o comprueba la configuración de la app.',
        'pt' =>
          'Cliente não autorizado. Atualize o Sonarpad ou verifique a configuração da app.',
        'pt_BR' || 'pt-BR' =>
          'Cliente não autorizado. Atualize o Sonarpad ou verifique a configuração do aplicativo.',
        'zh' || 'zh_CN' || 'zh-CN' =>
          '客户端未授权。请更新 Sonarpad 或检查应用配置。',
        'pl' =>
          'Klient nieautoryzowany. Zaktualizuj Sonarpad albo sprawdź konfigurację aplikacji.',
        'de' =>
          'Nicht autorisierter Client. Aktualisiere Sonarpad oder überprüfe die App-Konfiguration.',
        _ =>
          'Client non autorizzato. Aggiorna Sonarpad o verifica la configurazione dell\'app.',
      };

  String _addressNotFound(String language, bool isStart) => switch (language) {
        'en' => isStart
            ? 'Starting address not found'
            : 'Destination address not found',
        'fr' => isStart
            ? 'Adresse de départ introuvable'
            : 'Adresse de destination introuvable',
        'es' => isStart
            ? 'Dirección de salida no encontrada'
            : 'Dirección de llegada no encontrada',
        'pt' || 'pt_BR' => isStart
            ? 'Endereço de partida não encontrado'
            : 'Endereço de destino não encontrado',
        'zh' || 'zh_CN' => isStart ? '未找到起始地址' : '未找到目的地地址',
        'pl' => isStart
            ? 'Nie znaleziono adresu początkowego'
            : 'Nie znaleziono adresu docelowego',
        'de' => isStart
            ? 'Startadresse nicht gefunden'
            : 'Zieladresse nicht gefunden',
        _ => isStart
            ? 'Indirizzo di partenza non trovato'
            : 'Indirizzo di arrivo non trovato',
      };

  String _serverError(dynamic error, String fallback, String language) {
    final message = error?.toString();
    if (message == null || message.trim().isEmpty) {
      return fallback;
    }
    if (message.trim() == _unauthorizedClientError) {
      return _unauthorizedError(language);
    }
    return message;
  }

  Future<RouteResult> calculateRoute({
    required GeocodeCandidate from,
    required GeocodeCandidate to,
    required RouteProfile profile,
    required RoutePreference preference,
    required bool includeMunicipalities,
    required String language,
    required String countryCode,
  }) async {
    final uri = _routeEndpointUri({
      'from_lat': from.latitude.toString(),
      'from_lon': from.longitude.toString(),
      'to_lat': to.latitude.toString(),
      'to_lon': to.longitude.toString(),
      'profile': profile.apiValue,
      'preference': preference.apiValue,
      'avoid': '',
      'include_municipalities': includeMunicipalities ? '1' : '0',
      'language': language,
      'boundary.country': _countryAlpha3(countryCode),
    });

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_networkRouteError(language, response.statusCode));
    }

    final data = jsonDecode(response.body);
    if (data['ok'] != true) {
      throw Exception(
        _serverError(
          data['error'],
          _routeCalculationServerError(language),
          language,
        ),
      );
    }

    List<RoutePath> paths = [];
    if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
      paths =
          (data['routes'] as List).map((e) => RoutePath.fromJson(e)).toList();
    } else {
      paths = [
        RoutePath(
          distanceMeters: (data['distance_meters'] as num?)?.toDouble() ?? 0.0,
          durationSeconds:
              (data['duration_seconds'] as num?)?.toDouble() ?? 0.0,
          steps: (data['steps'] as List<dynamic>? ?? [])
              .map((e) => RouteStep.fromJson(e))
              .toList(),
          municipalityChanges: const [],
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
    required bool includeMunicipalities,
    required String language,
    required String countryCode,
  }) async {
    final fromCandidates = await geocode(
        query: fromAddress, language: language, countryCode: countryCode);
    if (fromCandidates.isEmpty) {
      throw Exception(_addressNotFound(language, true));
    }

    final toCandidates = await geocode(
        query: toAddress, language: language, countryCode: countryCode);
    if (toCandidates.isEmpty) {
      throw Exception(_addressNotFound(language, false));
    }

    return calculateRoute(
      from: fromCandidates.first,
      to: toCandidates.first,
      profile: profile,
      preference: preference,
      includeMunicipalities: includeMunicipalities,
      language: language,
      countryCode: countryCode,
    );
  }
}
