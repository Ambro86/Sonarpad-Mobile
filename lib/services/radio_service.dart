import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/radio_station.dart';

class RadioService {
  static const _favoritesPrefsKey = 'sonarpad_radio_favorites';
  static const _recentPrefsKey = 'sonarpad_radio_recent';
  static const _directoryLanguagesPrefsKey =
      'sonarpad_radio_directory_languages';
  static const _directoryCountriesPrefsKey = 'sonarpad_radio_directory_countries';
  static const _directoryCacheHours = 72;
  static const _communityUrl =
      'https://sonarpad.com/api/get_community_radios.php';
  static const _addCommunityUrl =
      'https://sonarpad.com/api/add_community_radio.php';
  static const _headers = {
    'User-Agent': 'SonarpadMobile/0.1 (https://sonarpad.com)',
    'Accept': 'application/json',
  };
  static const _radioBrowserMirrors = [
    'all.api.radio-browser.info',
    'de1.api.radio-browser.info',
    'fi1.api.radio-browser.info',
    'at1.api.radio-browser.info',
  ];

  static const languages = [
    RadioLanguageOption('it'),
    RadioLanguageOption('en'),
    RadioLanguageOption('tr'),
    RadioLanguageOption('de'),
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
  static const countries = [
    RadioCountryOption('it'),
    RadioCountryOption('us'),
    RadioCountryOption('gb'),
    RadioCountryOption('tr'),
    RadioCountryOption('fr'),
    RadioCountryOption('es'),
    RadioCountryOption('de'),
    RadioCountryOption('ch'),
    RadioCountryOption('at'),
    RadioCountryOption('be'),
    RadioCountryOption('nl'),
    RadioCountryOption('pt'),
    RadioCountryOption('br'),
    RadioCountryOption('ar'),
    RadioCountryOption('mx'),
    RadioCountryOption('ca'),
    RadioCountryOption('au'),
    RadioCountryOption('ie'),
    RadioCountryOption('se'),
    RadioCountryOption('pl'),
    RadioCountryOption('jp'),
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
    'turkish',
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

  Future<List<RadioLanguageOption>> loadDirectoryLanguages() async {
    final items = await _loadCachedRadioBrowserDirectory(
      prefsKey: _directoryLanguagesPrefsKey,
      path: '/json/languages',
    );
    final dynamicOptions = items
        .map(_languageOptionFromRadioBrowser)
        .whereType<RadioLanguageOption>()
        .toList();
    return _mergeLanguageOptions([...languages, ...dynamicOptions]);
  }

  Future<List<RadioCountryOption>> loadDirectoryCountries() async {
    final items = await _loadCachedRadioBrowserDirectory(
      prefsKey: _directoryCountriesPrefsKey,
      path: '/json/countrycodes',
    );
    final dynamicOptions = items
        .map(_countryOptionFromRadioBrowser)
        .whereType<RadioCountryOption>()
        .toList();
    return _mergeCountryOptions([...countries, ...dynamicOptions]);
  }

  Future<List<RadioStation>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoritesPrefsKey) ?? const [];
    return _normalizeStations(
      raw.map((item) => RadioStation.fromJson(jsonDecode(item))).toList(),
    );
  }

  Future<void> saveFavorites(List<RadioStation> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeStations(favorites);
    await prefs.setStringList(
      _favoritesPrefsKey,
      normalized.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<List<RadioStation>> loadRecentRadios() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentPrefsKey) ?? const [];
    return _normalizeStations(
      raw.map((item) => RadioStation.fromJson(jsonDecode(item))).toList(),
      sortByName: false,
    );
  }

  Future<void> addRecentRadio(RadioStation station) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = await loadRecentRadios();
    final next = [
      station,
      ...recent.where((item) => item.streamUrl != station.streamUrl),
    ];
    final limited = _normalizeStations(next, sortByName: false).take(50).toList();
    await prefs.setStringList(
      _recentPrefsKey,
      limited.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> clearRecentRadios() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentPrefsKey);
  }

  Future<List<RadioStation>> searchRadios({
    required String languageCode,
    required RadioGenreOption genre,
    String query = '',
  }) async {
    final trimmedQuery = query.trim();
    final hasNameSearch = trimmedQuery.isNotEmpty;
    final stations = <RadioStation>[];
    final errors = <Object>[];

    Future<void> collect({required String? genreTag}) async {
      try {
        stations.addAll(await _fetchRadioBrowserStations(
          languageCode: languageCode,
          query: trimmedQuery,
          genreTag: genreTag,
          globalSearch: hasNameSearch,
        ));
      } catch (e) {
        errors.add(e);
      }
      try {
        stations.addAll(await _fetchCommunityStations(
          languageCode: languageCode,
          query: trimmedQuery,
          genreTag: genreTag,
          globalSearch: hasNameSearch,
        ));
      } catch (e) {
        errors.add(e);
      }
    }

    await collect(genreTag: genre.tag);

    var normalized = _normalizeStations(stations)
      ..sort((a, b) => _radioSearchRank(a, trimmedQuery, languageCode)
          .compareTo(_radioSearchRank(b, trimmedQuery, languageCode)));

    // Se l'utente cerca una stazione per nome e il filtro genere non produce
    // risultati, riprova automaticamente senza genere. È il caso tipico di
    // Kral FM o Metropol FM: meglio trovare la radio che bloccarla per tag.
    if (normalized.isEmpty && genre.tag != null) {
      await collect(genreTag: null);
      normalized = _normalizeStations(stations)
        ..sort((a, b) => _radioSearchRank(a, trimmedQuery, languageCode)
            .compareTo(_radioSearchRank(b, trimmedQuery, languageCode)));
    }

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

  Future<void> recordRadioBrowserClick(RadioStation station) async {
    final uuid = station.stationUuid.trim();
    if (uuid.isEmpty) return;
    for (final mirror in _radioBrowserMirrors) {
      try {
        final uri = Uri.https(mirror, '/json/url/$uuid');
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 3));
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (_) {
        // Non bloccare la riproduzione se il contatore click non risponde.
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadCachedRadioBrowserDirectory({
    required String prefsKey,
    required String path,
  }) async {
    final fresh = await _readCachedDirectoryItems(prefsKey, freshOnly: true);
    if (fresh != null) return fresh;
    try {
      final items = await _fetchRadioBrowserDirectory(path);
      await _saveCachedDirectoryItems(prefsKey, items);
      return items;
    } catch (_) {
      return await _readCachedDirectoryItems(prefsKey, freshOnly: false) ??
          const [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRadioBrowserDirectory(
    String path,
  ) async {
    Object? lastError;
    for (final mirror in _radioBrowserMirrors) {
      try {
        final uri = Uri.https(mirror, path, const {
          'hidebroken': 'true',
          'order': 'stationcount',
          'reverse': 'true',
        });
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('HTTP ${response.statusCode}');
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! List) return const [];
        return decoded.whereType<Map<String, dynamic>>().toList();
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception(lastError ?? 'Radio Browser non raggiungibile');
  }

  Future<List<Map<String, dynamic>>?> _readCachedDirectoryItems(
    String prefsKey, {
    required bool freshOnly,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final savedAt = DateTime.tryParse((decoded['savedAt'] ?? '').toString());
      if (savedAt == null) return null;
      if (freshOnly &&
          DateTime.now().difference(savedAt).inHours > _directoryCacheHours) {
        return null;
      }
      final items = decoded['items'];
      if (items is! List) return null;
      return items.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCachedDirectoryItems(
    String prefsKey,
    List<Map<String, dynamic>> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'items': items,
      }),
    );
  }

  RadioLanguageOption? _languageOptionFromRadioBrowser(
    Map<String, dynamic> item,
  ) {
    final name = (item['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final knownCode = _radioCodeFromBrowserLanguage(name);
    final code = knownCode.isNotEmpty ? knownCode : _dynamicLanguageCode(name);
    return RadioLanguageOption(
      code,
      label: name,
      stationCount: _intFromDynamic(item['stationcount']),
    );
  }

  RadioCountryOption? _countryOptionFromRadioBrowser(
    Map<String, dynamic> item,
  ) {
    final name = (item['name'] ?? '').toString().trim().toLowerCase();
    if (name.length != 2) return null;
    return RadioCountryOption(
      name,
      stationCount: _intFromDynamic(item['stationcount']),
    );
  }

  List<RadioLanguageOption> _mergeLanguageOptions(
    List<RadioLanguageOption> options,
  ) {
    final byCode = <String, RadioLanguageOption>{};
    for (final option in options) {
      if (option.code.trim().isEmpty) continue;
      final key = option.code.toLowerCase();
      final current = byCode[key];
      if (current == null ||
          (current.label.trim().isEmpty && option.label.trim().isNotEmpty) ||
          option.stationCount > current.stationCount) {
        byCode[key] = option;
      }
    }
    return byCode.values.toList()
      ..sort((a, b) {
        final priority = _preferredLanguagePriority(a.code)
            .compareTo(_preferredLanguagePriority(b.code));
        if (priority != 0) return priority;
        return _languageSortLabel(a).compareTo(_languageSortLabel(b));
      });
  }

  List<RadioCountryOption> _mergeCountryOptions(
    List<RadioCountryOption> options,
  ) {
    final byCode = <String, RadioCountryOption>{};
    for (final option in options) {
      if (option.code.trim().isEmpty) continue;
      final key = option.code.toLowerCase();
      final current = byCode[key];
      if (current == null || option.stationCount > current.stationCount) {
        byCode[key] = option;
      }
    }
    return byCode.values.toList()
      ..sort((a, b) {
        final priority = _preferredCountryPriority(a.code)
            .compareTo(_preferredCountryPriority(b.code));
        if (priority != 0) return priority;
        return a.code.compareTo(b.code);
      });
  }

  int _preferredLanguagePriority(String code) {
    const preferred = ['it', 'en', 'tr', 'de', 'es', 'fr', 'pt', 'pl'];
    final index = preferred.indexOf(code.toLowerCase());
    return index < 0 ? 1000 : index;
  }

  int _preferredCountryPriority(String code) {
    const preferred = ['it', 'us', 'gb', 'tr', 'de', 'fr', 'es', 'pt', 'pl'];
    final normalized = code.toLowerCase();
    final index = preferred.indexOf(normalized);
    return index < 0 ? 1000 : index;
  }

  String _languageSortLabel(RadioLanguageOption option) {
    final label = option.label.trim();
    return label.isEmpty ? option.code.toLowerCase() : label.toLowerCase();
  }

  Future<List<RadioStation>> _fetchRadioBrowserStations({
    required String languageCode,
    required String query,
    required String? genreTag,
    required bool globalSearch,
  }) async {
    Object? lastError;
    for (final mirror in _radioBrowserMirrors) {
      final params = {
        'hidebroken': 'true',
        'order': 'votes',
        'reverse': 'true',
        'limit': globalSearch ? '100' : '50',
        if (query.trim().isNotEmpty) 'name': query.trim(),
        if (genreTag != null && genreTag.trim().isNotEmpty) 'tag': genreTag,
        if (!globalSearch && _isCountryCode(languageCode))
          'countrycode': _countryCode(languageCode)
        else if (!globalSearch && _isCityCode(languageCode))
          'state': _cityCode(languageCode)
        else if (!globalSearch) ...{
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
            .where((station) => _matchesKeyword(station, query))
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
    required bool globalSearch,
  }) async {
    final wantedLanguage = _communityLanguageFromRadioCode(languageCode);
    if (!globalSearch && wantedLanguage == null) return const [];
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
            globalSearch ||
            wantedLanguage == null ||
            station.language.trim().toLowerCase() ==
                wantedLanguage.toLowerCase())
        .where((station) =>
            genreTag == null ||
            station.genre.trim().toLowerCase() == genreTag.toLowerCase())
        .map((station) => station.toRadioStation())
        .where((station) => _matchesKeyword(station, query))
        .toList();
  }

  RadioStation? _radioBrowserStation(String fallbackLanguageCode, Object raw) {
    final item = raw as Map<String, dynamic>;
    if (item['lastcheckok'] != 1) return null;
    final resolved = (item['url_resolved'] ?? '').toString().trim();
    final fallback = (item['url'] ?? '').toString().trim();
    final url = resolved.isEmpty ? fallback : resolved;
    if (url.isEmpty) return null;
    final rawName = (item['name'] ?? '').toString().trim();
    final name = rawName.isEmpty ? url : rawName;
    final browserLanguage = (item['language'] ?? '').toString().trim();
    final countryCode = (item['countrycode'] ?? '').toString().trim();
    return RadioStation(
      name: _cleanRadioName(name),
      streamUrl: url,
      languageCode: browserLanguage.isEmpty
          ? fallbackLanguageCode
          : _radioCodeFromBrowserLanguage(browserLanguage),
      stationUuid: (item['stationuuid'] ?? '').toString().trim(),
      countryCode: countryCode,
      countryName: (item['country'] ?? '').toString().trim(),
      language: browserLanguage,
      tags: _cleanTags((item['tags'] ?? '').toString()),
      homepage: (item['homepage'] ?? '').toString().trim(),
      favicon: (item['favicon'] ?? '').toString().trim(),
      codec: (item['codec'] ?? '').toString().trim(),
      bitrate: _intFromDynamic(item['bitrate']),
      votes: _intFromDynamic(item['votes']),
      clickCount: _intFromDynamic(item['clickcount']),
      source: 'RadioBrowser',
    );
  }

  _CommunityRadioStation? _communityStation(String fallbackLanguageCode, Object raw) {
    final item = raw as Map<String, dynamic>;
    final url = (item['url'] ?? '').toString().trim();
    if (url.isEmpty) return null;
    final name = (item['name'] ?? '').toString().trim();
    final label = (item['genre_label'] ?? '').toString().trim();
    final language = (item['language'] ?? '').toString().trim();
    final genre = (item['genre'] ?? '').toString().trim();
    return _CommunityRadioStation(
      name: _cleanRadioName(name),
      streamUrl: url,
      languageCode: _radioCodeFromBrowserLanguage(language).isEmpty
          ? fallbackLanguageCode
          : _radioCodeFromBrowserLanguage(language),
      language: language,
      genre: genre,
      tags: label.isEmpty ? genre : label,
    );
  }

  List<RadioStation> _normalizeStations(
    List<RadioStation> stations, {
    bool sortByName = true,
  }) {
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
      normalized.add(station.copyWith(name: name, streamUrl: url));
    }
    if (sortByName) {
      normalized.sort((a, b) =>
          _radioNamePriority(a.name).compareTo(_radioNamePriority(b.name)));
    }
    return normalized;
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
  }

  String _radioBrowserLanguageName(String code) {
    if (_isDynamicLanguageCode(code)) return _dynamicLanguageName(code);
    return switch (code) {
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
      'tr' => 'turkish',
      'uk' => 'ukrainian',
      'vi' => 'vietnamese',
      'zh' => 'chinese',
      _ => code,
    };
  }

  String _radioCodeFromBrowserLanguage(String language) {
    final normalized = _compactRadioName(language);
    return switch (normalized) {
      'czech' || 'cesky' => 'cs',
      'english' => 'en',
      'spanish' || 'espanol' => 'es',
      'french' || 'francais' => 'fr',
      'italian' || 'italiano' => 'it',
      'lithuanian' => 'lt',
      'polish' => 'pl',
      'portuguese' => 'pt',
      'russian' => 'ru',
      'serbian' => 'sr',
      'swedish' => 'sv',
      'turkish' || 'turkce' => 'tr',
      'ukrainian' => 'uk',
      'vietnamese' => 'vi',
      'chinese' => 'zh',
      'hindi' => 'hi',
      _ => '',
    };
  }

  bool _isDynamicLanguageCode(String code) => code.startsWith('language:');

  String _dynamicLanguageCode(String name) =>
      'language:${Uri.encodeComponent(name.trim().toLowerCase())}';

  String _dynamicLanguageName(String code) {
    final raw = code.substring('language:'.length);
    return Uri.decodeComponent(raw);
  }

  bool _isCountryCode(String code) => code.startsWith('country:');

  String _countryCode(String code) =>
      code.substring('country:'.length).toUpperCase();

  bool _isCityCode(String code) => code.startsWith('city:');

  String _cityCode(String code) =>
      code.substring('city:'.length);

  String? _communityLanguageFromRadioCode(String code) => switch (code) {
        'it' || 'country:it' => 'italian',
        'en' || 'country:us' || 'country:gb' || 'country:ca' || 'country:au' || 'country:ie' => 'english',
        'es' || 'country:es' || 'country:mx' || 'country:ar' => 'spanish',
        'fr' || 'country:fr' || 'country:be' || 'country:ch' => 'french',
        'pt' || 'country:pt' || 'country:br' => 'portuguese',
        'sv' || 'country:se' => 'swedish',
        'tr' || 'country:tr' => 'turkish',
        'vi' => 'vietnamese',
        'cs' => 'czech',
        'pl' || 'country:pl' => 'polish',
        'sr' => 'serbian',
        'uk' => 'ukrainian',
        'lt' => 'lithuanian',
        'ru' => 'russian',
        'zh' => 'chinese',
        'hi' => 'hindi',
        'country:de' || 'country:at' || 'de' => 'german',
        _ => null,
      };

  String _cleanRadioName(String value) => _collapseWhitespace(
        value
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll('&apos;', "'"),
      );

  String _cleanTags(String value) {
    final seen = <String>{};
    final cleaned = <String>[];
    for (final tag in value.split(',')) {
      final item = _collapseWhitespace(tag).trim();
      if (item.isEmpty) continue;
      final key = _compactRadioName(item);
      if (seen.add(key)) cleaned.add(item);
      if (cleaned.length == 4) break;
    }
    return cleaned.join(', ');
  }

  String _normalizedRadioName(String value) =>
      _collapseWhitespace(value.toLowerCase());

  String _collapseWhitespace(String value) {
    final words = value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
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

  String _radioSearchRank(
    RadioStation station,
    String keyword,
    String selectedLanguageCode,
  ) {
    final name = station.name;
    final query = _canonicalRadioName(keyword.trim());
    final normalized = _normalizedRadioName(name);
    final canonical = _canonicalRadioName(name);
    final compactQuery = _compactRadioName(keyword);
    final compactName = _compactRadioName(name);
    final tier = query.isEmpty
        ? 3
        : normalized == query || compactName == compactQuery
            ? 0
            : normalized.startsWith(query) || compactName.startsWith(compactQuery)
                ? 1
                : normalized.contains(' $query')
                    ? 2
                    : 3;
    final selectedCountry = _isCountryCode(selectedLanguageCode)
        ? _countryCode(selectedLanguageCode)
        : '';
    final countryBoost = selectedCountry.isNotEmpty &&
            station.countryCode.toUpperCase() == selectedCountry
        ? 0
        : 1;
    final languageBoost = !_isCountryCode(selectedLanguageCode) &&
            station.languageCode == selectedLanguageCode
        ? 0
        : 1;
    final rai = query == 'rai' && canonical.startsWith('rai radio ') ? 0 : 1;
    var position = normalized.indexOf(query);
    if (position < 0) position = compactName.indexOf(compactQuery);
    final popularity = 999999 - (station.votes + station.clickCount);
    return '$tier|$countryBoost|$languageBoost|$rai|${position < 0 ? 9999 : position}|$popularity|$canonical';
  }

  bool _matchesKeyword(RadioStation station, String keyword) {
    final query = _canonicalRadioName(keyword.trim());
    if (query.isEmpty) return true;
    final searchable = [
      station.name,
      station.countryName,
      station.language,
      station.tags,
    ].where((item) => item.trim().isNotEmpty).join(' ');
    final canonical = _canonicalRadioName(searchable);
    final compactQuery = _compactRadioName(keyword);
    final compactName = _compactRadioName(searchable);
    return canonical == query ||
        canonical.startsWith('$query ') ||
        canonical.contains(' $query ') ||
        (compactQuery.length >= 2 && compactName.contains(compactQuery)) ||
        (query.length >= 4 &&
            canonical.split(' ').any((word) => word.startsWith(query)));
  }

  String _compactRadioName(String value) {
    final normalized = _canonicalRadioName(value);
    final buffer = StringBuffer();
    for (final rune in normalized.runes) {
      if ((rune >= 48 && rune <= 57) || (rune >= 97 && rune <= 122)) {
        buffer.writeCharCode(rune);
      } else {
        final folded = switch (rune) {
          224 || 225 || 226 || 227 || 228 || 229 => 'a',
          232 || 233 || 234 || 235 => 'e',
          236 || 237 || 238 || 239 => 'i',
          242 || 243 || 244 || 245 || 246 => 'o',
          249 || 250 || 251 || 252 => 'u',
          241 => 'n',
          231 => 'c',
          287 || 286 => 'g', // ğ, Ğ
          305 || 304 => 'i', // ı, İ
          351 || 350 => 's', // ş, Ş
          _ => '',
        };
        buffer.write(folded);
      }
    }
    return buffer.toString();
  }

  int _intFromDynamic(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}

class _CommunityRadioStation {
  final String name;
  final String streamUrl;
  final String languageCode;
  final String language;
  final String genre;
  final String tags;

  const _CommunityRadioStation({
    required this.name,
    required this.streamUrl,
    required this.languageCode,
    required this.language,
    required this.genre,
    required this.tags,
  });

  RadioStation toRadioStation() => RadioStation(
        name: name,
        streamUrl: streamUrl,
        languageCode: languageCode,
        language: language,
        tags: tags,
        source: 'Sonarpad Community',
      );
}
