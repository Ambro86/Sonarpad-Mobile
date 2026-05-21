import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/radio_station.dart';

class RadioService {
  static const _prefsKey = 'sonarpad_radio_favorites';
  static const _communityUrl =
      'https://sonarpad.com/api/get_community_radios.php';
  static const _addCommunityUrl =
      'https://sonarpad.com/api/add_community_radio.php';
  static const _headers = {
    'User-Agent': 'SonarpadMobile/0.1 (https://sonarpad.com)',
    'Accept': 'application/json',
  };
  static const languages = [
    RadioLanguageOption('it'),
    RadioLanguageOption('en'),
    RadioLanguageOption('de'),
    RadioLanguageOption('country:ch'),
    RadioLanguageOption('es'),
    RadioLanguageOption('pt'),
    RadioLanguageOption('sv'),
    RadioLanguageOption('vi'),
    RadioLanguageOption('cs'),
    RadioLanguageOption('pl'),
    RadioLanguageOption('fr'),
    RadioLanguageOption('sr'),
    RadioLanguageOption('uk'),
    RadioLanguageOption('hi'),
    RadioLanguageOption('lt'),
    RadioLanguageOption('ru'),
    RadioLanguageOption('zh'),
  ];
  static const genres = [
    RadioGenreOption('all', null),
    RadioGenreOption('news', 'news'),
    RadioGenreOption('music', 'music'),
    RadioGenreOption('sport', 'sport'),
    RadioGenreOption('talk', 'talk'),
    RadioGenreOption('pop', 'pop'),
    RadioGenreOption('rock', 'rock'),
    RadioGenreOption('classical', 'classical'),
    RadioGenreOption('jazz', 'jazz'),
    RadioGenreOption('dance', 'dance'),
    RadioGenreOption('blues', 'blues'),
    RadioGenreOption('country', 'country'),
    RadioGenreOption('hiphop', 'hiphop'),
    RadioGenreOption('electronic', 'electronic'),
    RadioGenreOption('latin', 'latin'),
    RadioGenreOption('reggae', 'reggae'),
    RadioGenreOption('metal', 'metal'),
    RadioGenreOption('folk', 'folk'),
    RadioGenreOption('religion', 'religion'),
    RadioGenreOption('local', 'local'),
    RadioGenreOption('culture', 'culture'),
    RadioGenreOption('oldies', 'oldies'),
    RadioGenreOption('kids', 'kids'),
    RadioGenreOption('ambient', 'ambient'),
  ];
  static const communityLanguages = [
    'italian',
    'english',
    'spanish',
    'french',
    'german',
    'portuguese',
    'swedish',
    'vietnamese',
    'czech',
    'polish',
    'serbian',
    'ukrainian',
    'lithuanian',
    'russian',
    'chinese',
    'hindi',
  ];

  final http.Client _client;

  RadioService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<RadioStation>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    return _normalizeStations(
        raw.map((item) => RadioStation.fromJson(jsonDecode(item))).toList());
  }

  Future<void> saveFavorites(List<RadioStation> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeStations(favorites);
    await prefs.setStringList(
      _prefsKey,
      normalized.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<List<RadioStation>> searchRadios({
    required String languageCode,
    required RadioGenreOption genre,
    String query = '',
  }) async {
    final stations = <RadioStation>[];
    final errors = <Object>[];
    try {
      stations.addAll(await _fetchRadioBrowserStations(
        languageCode: languageCode,
        query: query,
        genreTag: genre.tag,
      ));
    } catch (e) {
      errors.add(e);
    }
    try {
      stations.addAll(await _fetchCommunityStations(
        languageCode: languageCode,
        query: query,
        genreTag: genre.tag,
      ));
    } catch (e) {
      errors.add(e);
    }
    final normalized = _normalizeStations(stations)
      ..sort((a, b) => _radioSearchRank(a.name, query)
          .compareTo(_radioSearchRank(b.name, query)));
    if (normalized.isEmpty && errors.isNotEmpty) {
      throw Exception(errors.join(' | '));
    }
    return normalized;
  }

  Future<String> addCommunityRadio({
    required String name,
    required String streamUrl,
    required String language,
    required String genre,
  }) async {
    final response = await _client.post(
      Uri.parse(_addCommunityUrl),
      headers: const {
        'User-Agent': 'SonarpadMobile/0.1 (https://sonarpad.com)',
        'Accept': 'application/json',
      },
      body: {
        'name': name,
        'url': streamUrl,
        'language': language,
        'genre': genre,
        'ui_language': 'it',
      },
    ).timeout(const Duration(seconds: 12));
    final decoded = _decodeJsonMap(response.body);
    final message = (decoded['message'] ?? '').toString().trim();
    final error = (decoded['error'] ?? '').toString().trim();
    final ok = decoded['ok'] == true;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(error.isEmpty ? 'HTTP ${response.statusCode}' : error);
    }
    if (!ok) throw Exception(error.isEmpty ? 'Richiesta rifiutata' : error);
    return message;
  }

  Future<List<RadioStation>> _fetchRadioBrowserStations({
    required String languageCode,
    required String query,
    required String? genreTag,
  }) async {
    Object? lastError;
    for (final mirror in const [
      'all.api.radio-browser.info',
      'de1.api.radio-browser.info',
      'fi1.api.radio-browser.info',
      'at1.api.radio-browser.info',
    ]) {
      final params = {
        'hidebroken': 'true',
        'order': 'votes',
        'reverse': 'true',
        'limit': '50',
        if (query.trim().isNotEmpty) 'name': query.trim(),
        if (genreTag != null && genreTag.trim().isNotEmpty) 'tag': genreTag,
        if (languageCode.startsWith('country:'))
          'countrycode': languageCode.substring('country:'.length)
        else ...{
          'language': _radioBrowserLanguageName(languageCode),
          'languageExact': 'true',
        },
      };
      try {
        final uri = Uri.https(mirror, '/json/stations/search', params);
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('HTTP ${response.statusCode}');
        }
        final items = jsonDecode(response.body) as List<dynamic>;
        return items
            .map((raw) => _radioBrowserStation(languageCode, raw))
            .whereType<RadioStation>()
            .where((station) => _matchesKeyword(station.name, query))
            .toList();
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception(lastError ?? 'Radio Browser non raggiungibile');
  }

  Future<List<RadioStation>> _fetchCommunityStations({
    required String languageCode,
    required String query,
    required String? genreTag,
  }) async {
    final wantedLanguage = _communityLanguageFromRadioCode(languageCode);
    if (wantedLanguage == null) return const [];
    final response = await _client
        .get(Uri.parse(_communityUrl), headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Community HTTP ${response.statusCode}');
    }
    final items = jsonDecode(response.body) as List<dynamic>;
    return items
        .map((raw) => _communityStation(languageCode, raw))
        .whereType<_CommunityRadioStation>()
        .where((station) =>
            station.language.trim().toLowerCase() ==
            wantedLanguage.toLowerCase())
        .where((station) =>
            genreTag == null ||
            station.genre.trim().toLowerCase() == genreTag.toLowerCase())
        .map((station) => station.toRadioStation())
        .where((station) => _matchesKeyword(station.name, query))
        .toList();
  }

  RadioStation? _radioBrowserStation(String languageCode, Object raw) {
    final item = raw as Map<String, dynamic>;
    if (item['lastcheckok'] != 1) return null;
    final resolved = (item['url_resolved'] ?? '').toString().trim();
    final fallback = (item['url'] ?? '').toString().trim();
    final url = resolved.isEmpty ? fallback : resolved;
    if (url.isEmpty) return null;
    final rawName = (item['name'] ?? '').toString().trim();
    final tags = (item['tags'] ?? '').toString().trim();
    final name = rawName.isEmpty
        ? url
        : tags.isEmpty
            ? rawName
            : '$rawName - $tags';
    return RadioStation(
      name: _cleanRadioName(name),
      streamUrl: url,
      languageCode: languageCode,
    );
  }

  _CommunityRadioStation? _communityStation(String languageCode, Object raw) {
    final item = raw as Map<String, dynamic>;
    final url = (item['url'] ?? '').toString().trim();
    if (url.isEmpty) return null;
    final name = (item['name'] ?? '').toString().trim();
    final label = (item['genre_label'] ?? '').toString().trim();
    return _CommunityRadioStation(
      name: _cleanRadioName(label.isEmpty ? name : '$name - $label'),
      streamUrl: url,
      languageCode: languageCode,
      language: (item['language'] ?? '').toString(),
      genre: (item['genre'] ?? '').toString(),
    );
  }

  List<RadioStation> _normalizeStations(List<RadioStation> stations) {
    final seenUrls = <String>{};
    final seenNames = <String>{};
    final normalized = <RadioStation>[];
    for (final station in stations) {
      final name = _cleanRadioName(station.name);
      final url = station.streamUrl.trim();
      if (name.isEmpty || url.isEmpty) continue;
      final nameKey = _canonicalRadioName(name);
      final urlKey = _normalizeStreamUrl(url);
      if (seenNames.contains(nameKey) || seenUrls.contains(urlKey)) continue;
      seenNames.add(nameKey);
      seenUrls.add(urlKey);
      normalized.add(RadioStation(
        name: name,
        streamUrl: url,
        languageCode: station.languageCode,
      ));
    }
    normalized.sort((a, b) =>
        _radioNamePriority(a.name).compareTo(_radioNamePriority(b.name)));
    return normalized;
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
  }

  String _radioBrowserLanguageName(String code) => switch (code) {
        'cs' => 'czech',
        'en' => 'english',
        'es' => 'spanish',
        'fr' => 'french',
        'it' => 'italian',
        'lt' => 'lithuanian',
        'pl' => 'polish',
        'pt' => 'portuguese',
        'ru' => 'russian',
        'sr' => 'serbian',
        'sv' => 'swedish',
        'uk' => 'ukrainian',
        'vi' => 'vietnamese',
        'zh' => 'chinese',
        _ => code,
      };

  String? _communityLanguageFromRadioCode(String code) => switch (code) {
        'it' => 'italian',
        'en' => 'english',
        'es' => 'spanish',
        'fr' => 'french',
        'pt' => 'portuguese',
        'sv' => 'swedish',
        'vi' => 'vietnamese',
        'cs' => 'czech',
        'pl' => 'polish',
        'sr' => 'serbian',
        'uk' => 'ukrainian',
        'lt' => 'lithuanian',
        'ru' => 'russian',
        'zh' => 'chinese',
        'hi' => 'hindi',
        'country:de' || 'de' => 'german',
        _ => null,
      };

  String _cleanRadioName(String value) =>
      _collapseWhitespace(value.replaceAll('&', ''));

  String _normalizedRadioName(String value) =>
      _collapseWhitespace(value.toLowerCase());

  String _collapseWhitespace(String value) {
    final words = value.trim().split(' ').where((word) => word.isNotEmpty);
    return words.join(' ');
  }

  String _canonicalRadioName(String value) {
    var name = _normalizedRadioName(value);
    if (name.startsWith('radio rai ')) {
      name = 'rai radio ${name.substring('radio rai '.length)}';
    }
    return name
        .replaceAll('rai radiouno', 'rai radio 1')
        .replaceAll('rai radiodue', 'rai radio 2')
        .replaceAll('rai radiotre', 'rai radio 3')
        .replaceAll('rai radio1', 'rai radio 1')
        .replaceAll('rai radio2', 'rai radio 2')
        .replaceAll('rai radio3', 'rai radio 3')
        .replaceAll('rai radio uno', 'rai radio 1')
        .replaceAll('rai radio due', 'rai radio 2')
        .replaceAll('rai radio tre', 'rai radio 3');
  }

  String _normalizeStreamUrl(String rawUrl) {
    final raw = rawUrl.trim();
    final parsed = Uri.tryParse(raw);
    if (parsed == null || parsed.host.isEmpty) {
      var key = raw.replaceFirst('http://', '').replaceFirst('https://', '');
      if (key.endsWith('/')) key = key.substring(0, key.length - 1);
      return key.toLowerCase();
    }
    final path = parsed.path.endsWith('/')
        ? parsed.path.substring(0, parsed.path.length - 1)
        : parsed.path;
    return '${parsed.host.toLowerCase()}$path${parsed.hasQuery ? '?${parsed.query}' : ''}';
  }

  String _radioNamePriority(String value) {
    final normalized = _normalizedRadioName(value);
    final canonical = _canonicalRadioName(value);
    final raiRadio = normalized.startsWith('rai radio ') ? '0' : '1';
    final rai = normalized.startsWith('rai ') ? '0' : '1';
    return '$raiRadio|$rai|${canonical.padLeft(80)}';
  }

  String _radioSearchRank(String name, String keyword) {
    final query = _canonicalRadioName(keyword.trim());
    if (query.isEmpty) return _radioNamePriority(name);
    final normalized = _normalizedRadioName(name);
    final canonical = _canonicalRadioName(name);
    final tier = normalized == query
        ? 0
        : normalized.startsWith(query)
            ? 1
            : normalized.contains(' $query')
                ? 2
                : 3;
    final rai = query == 'rai' && canonical.startsWith('rai radio ') ? 0 : 1;
    final position = normalized.indexOf(query);
    return '$tier|$rai|${position < 0 ? 9999 : position}|$canonical';
  }

  bool _matchesKeyword(String name, String keyword) {
    final query = _canonicalRadioName(keyword.trim());
    if (query.isEmpty) return true;
    final canonical = _canonicalRadioName(name);
    return canonical == query ||
        canonical.startsWith('$query ') ||
        canonical.contains(' $query ') ||
        (query.length >= 4 &&
            canonical.split(' ').any((word) => word.startsWith(query)));
  }
}

class _CommunityRadioStation {
  final String name;
  final String streamUrl;
  final String languageCode;
  final String language;
  final String genre;

  const _CommunityRadioStation({
    required this.name,
    required this.streamUrl,
    required this.languageCode,
    required this.language,
    required this.genre,
  });

  RadioStation toRadioStation() => RadioStation(
        name: name,
        streamUrl: streamUrl,
        languageCode: languageCode,
      );
}
