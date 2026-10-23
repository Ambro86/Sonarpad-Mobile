import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

class TravelException implements Exception {
  const TravelException(this.code, {this.status, this.reference});
  final String code;
  final int? status;
  final String? reference;
}

class TravelCity {
  const TravelCity(this.id, this.name, this.country, this.region);
  final String id, name, country, region;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'region': region,
  };
  factory TravelCity.fromJson(Map<String, dynamic> j) => TravelCity(
    j['id'].toString(),
    j['name'] as String,
    j['country']?.toString() ?? '',
    j['region']?.toString() ?? '',
  );
}

class TravelQuery {
  TravelQuery({
    this.from = '',
    this.to = '',
    this.country = 'IT',
    this.currency = 'EUR',
    this.mode = 'train',
    DateTime? departure,
    this.returnDate,
    this.departureCity,
    this.arrivalCity,
    List<int>? ages,
  }) : departure = departure ?? DateUtilsTravel.today(),
       ages = ages ?? [40];
  String from, to, country, currency, mode;
  DateTime departure;
  DateTime? returnDate;
  List<int> ages;
  TravelCity? departureCity, arrivalCity;
  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'country': country,
    'currency': currency,
    'mode': mode,
    'departure': DateUtilsTravel.iso(departure),
    'returnDate': returnDate == null ? null : DateUtilsTravel.iso(returnDate!),
    'ages': ages,
    'departureCity': departureCity?.toJson(),
    'arrivalCity': arrivalCity?.toJson(),
  };
  factory TravelQuery.fromJson(Map<String, dynamic> j) => TravelQuery(
    from: j['from'] as String,
    to: j['to'] as String,
    country: j['country'] as String,
    currency: j['currency'] as String,
    mode: j['mode'] as String,
    departure: DateTime.parse(j['departure'] as String),
    returnDate: j['returnDate'] == null
        ? null
        : DateTime.parse(j['returnDate'] as String),
    ages: (j['ages'] as List).cast<int>().toList(),
    departureCity: j['departureCity'] == null
        ? null
        : TravelCity.fromJson(
            Map<String, dynamic>.from(j['departureCity'] as Map),
          ),
    arrivalCity: j['arrivalCity'] == null
        ? null
        : TravelCity.fromJson(
            Map<String, dynamic>.from(j['arrivalCity'] as Map),
          ),
  );
  TravelQuery copy() => TravelQuery.fromJson(toJson());
}

class DateUtilsTravel {
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime clamp(int year, int month, int day) =>
      DateTime(year, month, day.clamp(1, DateTime(year, month + 1, 0).day));
}

/// Only Sonarpad receives credentials. No personal checkout URLs or query bodies in logs.
class TravelService {
  TravelService({
    http.Client? client,
    String? clientToken,
    Future<void> Function(String)? logger,
  }) : _client = client ?? http.Client(),
       _clientToken =
           clientToken ??
           const String.fromEnvironment('SONARPAD_ROUTE_CLIENT_TOKEN'),
       _logger = logger ?? AppLogger.log;
  static final _base = Uri.parse(
    'https://sonarpad.com/api/test_omio_sessione.php',
  );
  final http.Client _client;
  final String _clientToken;
  final Future<void> Function(String) _logger;
  String? _session;
  bool _closed = false;
  static String? _safeReference(dynamic value) {
    final s = value?.toString() ?? '';
    return RegExp(r'^[a-fA-F0-9]{8,64}$').hasMatch(s) ? s : null;
  }

  Future<Map<String, dynamic>> request(
    String route, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    String? method,
    String? idempotencyKey,
  }) async {
    if (_closed) throw const TravelException('closed');
    if (_clientToken.isEmpty) {
      await _logger('[Travel] configuration: missing build token');
      throw const TravelException('configuration');
    }
    final watch = Stopwatch()..start();
    final verb = method ?? (body == null ? 'GET' : 'POST');
    try {
      final request = http.Request(
        verb,
        _base.replace(queryParameters: {'route': route, ...query}),
      );
      request.followRedirects = false;
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Sonarpad-Route-Token': _clientToken,
        'X-Sonarpad-Session': ?_session,
        'Idempotency-Key': ?idempotencyKey,
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 95));
      Map<String, dynamic>? data;
      try {
        data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        /* handled below */
      }
      final reference = _safeReference(data?['request_id']);
      await _logger(
        '[Travel] $verb $route http=${response.statusCode} elapsed_ms=${watch.elapsedMilliseconds}'
        '${reference == null ? '' : ' request_id=$reference'}',
      );
      final diagnostic = data?['diagnostic'];
      if (diagnostic is Map) {
        // Strict allowlist: never serialize the provider's raw error or body.
        final profile = diagnostic['profile'];
        final type = diagnostic['error_type'];
        await _logger(
          '[Travel] provider profile=${['chrome131', 'safari17_2_ios'].contains(profile) ? profile : 'unknown'}'
          ' timeout=${['Timeout', 'ConnectTimeout', 'ReadTimeout'].contains(type)}'
          ' retry_handled=${diagnostic['retry_handled'] == true}'
          ' challenge=${diagnostic['challenge_detected'] == true}',
        );
      }
      if (response.statusCode == 204) return {};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TravelException(
          'http',
          status: response.statusCode,
          reference: reference,
        );
      }
      if (data == null) throw const TravelException('response');
      return data;
    } on TravelException {
      rethrow;
    } on TimeoutException {
      await _logger(
        '[Travel] $verb $route timeout elapsed_ms=${watch.elapsedMilliseconds}',
      );
      throw const TravelException('timeout');
    } catch (_) {
      await _logger(
        '[Travel] $verb $route transport_or_response_error elapsed_ms=${watch.elapsedMilliseconds}',
      );
      throw const TravelException('network');
    }
  }

  Future<void> start(String locale, String currency) async {
    final data = await request(
      '/v1/sessions',
      body: {'locale': locale.replaceAll('_', '-'), 'currency': currency},
    );
    _session = data['token'] as String;
    if (data['currency'] != currency ||
        data['locale'] != locale.split(RegExp('[-_]')).first) {
      throw const TravelException('response');
    }
  }

  Future<List<TravelCity>> cities(String term, String country) async {
    final data = await request('/v1/cities', query: {'q': term});
    final cities = (data['items'] as List)
        .map((x) => TravelCity.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
    // Prefer the chosen country, but preserve international destinations.
    return [
      ...cities.where((c) => c.country == country),
      ...cities.where((c) => c.country != country),
    ];
  }

  Future<void> search(TravelQuery q, TravelCity from, TravelCity to) async {
    await request(
      '/v1/search',
      body: {
        'departure_id': from.id,
        'arrival_id': to.id,
        'outbound_date': DateUtilsTravel.iso(q.departure),
        'return_date': q.returnDate == null
            ? null
            : DateUtilsTravel.iso(q.returnDate!),
        'mode': q.mode,
        'ages': q.ages,
      },
    );
  }

  Future<Map<String, dynamic>> results({int page = 1, String? outbound}) =>
      request(
        outbound == null ? '/v1/search/results' : '/v1/search/inbounds',
        query: {'page': '$page', 'outbound_choice': ?outbound},
      );
  Future<void> close() async {
    if (_closed) return;
    try {
      if (_session != null) await request('/v1/session', method: 'DELETE');
    } catch (_) {
      /* server TTL also expires sessions */
    } finally {
      _closed = true;
      _session = null;
      _client.close();
    }
  }
}

class RecentTravelService {
  static const _key = 'sonarpad_recent_travel_queries_v1';
  static const _lastKey = 'sonarpad_last_travel_form_v1';
  Future<TravelQuery?> loadLast() async {
    final raw = (await SharedPreferences.getInstance()).getString(_lastKey);
    if (raw == null) return null;
    try {
      return TravelQuery.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLast(TravelQuery query) async {
    await (await SharedPreferences.getInstance()).setString(
      _lastKey,
      jsonEncode(query.toJson()),
    );
  }

  Future<List<TravelQuery>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <TravelQuery>[];
    for (final raw in prefs.getStringList(_key) ?? <String>[]) {
      try {
        result.add(
          TravelQuery.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        /* skip damaged item */
      }
    }
    return result.take(20).toList();
  }

  Future<void> add(TravelQuery query) async {
    final items = await load();
    final raw = jsonEncode(query.toJson());
    final saved = [
      raw,
      ...items.map((x) => jsonEncode(x.toJson())).where((x) => x != raw),
    ].take(20).toList();
    await (await SharedPreferences.getInstance()).setStringList(_key, saved);
  }

  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
