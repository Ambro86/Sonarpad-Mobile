import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'route_service.dart';

class RecentRouteItem {
  final String id;
  final String fromLabel;
  final String toLabel;
  final String fromName;
  final String toName;
  final double fromLatitude;
  final double fromLongitude;
  final double toLatitude;
  final double toLongitude;
  final RouteProfile profile;
  final RoutePreference preference;
  final bool includeMunicipalities;
  final String language;
  final String countryCode;
  final DateTime createdAt;

  const RecentRouteItem({
    required this.id,
    required this.fromLabel,
    required this.toLabel,
    required this.fromName,
    required this.toName,
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toLatitude,
    required this.toLongitude,
    required this.profile,
    required this.preference,
    required this.includeMunicipalities,
    required this.language,
    required this.countryCode,
    required this.createdAt,
  });

  GeocodeCandidate get fromCandidate => GeocodeCandidate(
        label: fromLabel,
        name: fromName,
        country: '',
        region: '',
        locality: '',
        postalcode: '',
        latitude: fromLatitude,
        longitude: fromLongitude,
      );

  GeocodeCandidate get toCandidate => GeocodeCandidate(
        label: toLabel,
        name: toName,
        country: '',
        region: '',
        locality: '',
        postalcode: '',
        latitude: toLatitude,
        longitude: toLongitude,
      );

  String get fromDisplayLabel => fromLabel.trim().isNotEmpty
      ? fromLabel.trim()
      : (fromName.trim().isNotEmpty ? fromName.trim() : 'Partenza');

  String get toDisplayLabel => toLabel.trim().isNotEmpty
      ? toLabel.trim()
      : (toName.trim().isNotEmpty ? toName.trim() : 'Destinazione');

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromLabel': fromLabel,
        'toLabel': toLabel,
        'fromName': fromName,
        'toName': toName,
        'fromLatitude': fromLatitude,
        'fromLongitude': fromLongitude,
        'toLatitude': toLatitude,
        'toLongitude': toLongitude,
        'profile': profile.name,
        'preference': preference.name,
        'includeMunicipalities': includeMunicipalities,
        'language': language,
        'countryCode': countryCode,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RecentRouteItem.fromJson(Map<String, dynamic> json) {
    RouteProfile parseProfile(String value) => RouteProfile.values.firstWhere(
          (profile) => profile.name == value || profile.apiValue == value,
          orElse: () => RouteProfile.driving,
        );
    RoutePreference parsePreference(String value) =>
        RoutePreference.values.firstWhere(
          (preference) =>
              preference.name == value || preference.apiValue == value,
          orElse: () => RoutePreference.fastest,
        );

    return RecentRouteItem(
      id: (json['id'] ?? '').toString(),
      fromLabel: (json['fromLabel'] ?? '').toString(),
      toLabel: (json['toLabel'] ?? '').toString(),
      fromName: (json['fromName'] ?? '').toString(),
      toName: (json['toName'] ?? '').toString(),
      fromLatitude: (json['fromLatitude'] as num?)?.toDouble() ?? 0.0,
      fromLongitude: (json['fromLongitude'] as num?)?.toDouble() ?? 0.0,
      toLatitude: (json['toLatitude'] as num?)?.toDouble() ?? 0.0,
      toLongitude: (json['toLongitude'] as num?)?.toDouble() ?? 0.0,
      profile: parseProfile((json['profile'] ?? '').toString()),
      preference: parsePreference((json['preference'] ?? '').toString()),
      includeMunicipalities: json['includeMunicipalities'] == true,
      language: (json['language'] ?? 'it').toString(),
      countryCode: (json['countryCode'] ?? 'it').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  static RecentRouteItem fromResult({
    required RouteResult result,
    required String language,
    required String countryCode,
    required bool includeMunicipalities,
  }) {
    final id = _stableId(
      result.from.latitude,
      result.from.longitude,
      result.to.latitude,
      result.to.longitude,
      result.profile,
      result.preference,
      includeMunicipalities,
      countryCode,
    );
    return RecentRouteItem(
      id: id,
      fromLabel: result.from.displayLabel,
      toLabel: result.to.displayLabel,
      fromName: result.from.name,
      toName: result.to.name,
      fromLatitude: result.from.latitude,
      fromLongitude: result.from.longitude,
      toLatitude: result.to.latitude,
      toLongitude: result.to.longitude,
      profile: result.profile,
      preference: result.preference,
      includeMunicipalities: includeMunicipalities,
      language: language,
      countryCode: countryCode,
      createdAt: DateTime.now(),
    );
  }

  static String _stableId(
    double fromLatitude,
    double fromLongitude,
    double toLatitude,
    double toLongitude,
    RouteProfile profile,
    RoutePreference preference,
    bool includeMunicipalities,
    String countryCode,
  ) {
    String fixed(double value) => value.toStringAsFixed(6);
    return [
      fixed(fromLatitude),
      fixed(fromLongitude),
      fixed(toLatitude),
      fixed(toLongitude),
      profile.name,
      preference.name,
      includeMunicipalities ? 'municipalities' : 'no_municipalities',
      countryCode.toLowerCase(),
    ].join('|');
  }
}

class RecentRoutesService {
  static const _key = 'sonarpad_recent_routes_v1';

  Future<List<RecentRouteItem>> loadRecentRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((item) => RecentRouteItem.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ))
          .where((item) => item.id.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecentRoute(RecentRouteItem route) async {
    final prefs = await SharedPreferences.getInstance();
    var routes = await loadRecentRoutes();
    routes.removeWhere((item) => item.id == route.id);
    routes.insert(0, route);
    if (routes.length > 50) {
      routes = routes.take(50).toList();
    }
    await prefs.setString(
      _key,
      jsonEncode(routes.map((route) => route.toJson()).toList()),
    );
  }

  Future<void> removeRecentRoute(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await loadRecentRoutes();
    routes.removeWhere((route) => route.id == id);
    await prefs.setString(
      _key,
      jsonEncode(routes.map((route) => route.toJson()).toList()),
    );
  }

  Future<void> clearRecentRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
