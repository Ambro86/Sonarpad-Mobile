import '../l10n/italian_directory_labels.dart';
import 'dart:convert';
import 'package:flutter/widgets.dart' show Locale;
import '../l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../utils/app_logger.dart';

AppLocalizations placeStrings(String language) {
  final parts = language.replaceAll('-', '_').split('_');
  final locale = Locale(parts.first, parts.length > 1 ? parts[1] : null);
  if (!AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  )) {
    return lookupAppLocalizations(const Locale('en'));
  }
  return lookupAppLocalizations(locale);
}

String formatOpeningRange(String value, {String language = 'it'}) {
  final text = placeStrings(language);
  final match = RegExp(
    r'^\s*(\d{1,2})(?::(\d{2}))?\s*[–-]\s*(\d{1,2})(?::(\d{2}))?\s*$',
  ).firstMatch(value);
  if (match == null) return value;
  final h1 = int.parse(match[1]!);
  final m1 = int.parse(match[2] ?? '0');
  final h2 = int.parse(match[3]!);
  final m2 = int.parse(match[4] ?? '0');
  if (h1 > 24 ||
      h2 > 24 ||
      m1 > 59 ||
      m2 > 59 ||
      (h1 == 24 && m1 != 0) ||
      (h2 == 24 && m2 != 0)) {
    return value;
  }
  String time(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  final end = h2 * 60 + m2;
  final suffix = end == 0 || end == 1440
      ? ''
      : end < h1 * 60 + m1
      ? text.placesNextDay
      : '';
  return text.placesRange
          .replaceAll('%start%', time(h1, m1))
          .replaceAll('%end%', time(h2 % 24, m2)) +
      suffix;
}

String openingDayLabel(
  String name,
  String? date,
  DateTime now, {
  String language = 'it',
}) {
  final text = placeStrings(language);
  final parsed = DateTime.tryParse(date ?? '');
  if (parsed == null) return name;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(parsed.year, parsed.month, parsed.day);
  if (day == today) return text.placesToday;
  if (day == DateTime(now.year, now.month, now.day + 1)) {
    return text.placesTomorrow;
  }
  return name;
}

enum DirectoryKind { pagineBianche, pagineGialle }

extension DirectoryKindExtension on DirectoryKind {
  String get label {
    switch (this) {
      case DirectoryKind.pagineBianche:
        return 'Ricerca nominativi';
      case DirectoryKind.pagineGialle:
        return 'Luoghi e attività';
    }
  }

  String get searchEndpoint {
    switch (this) {
      case DirectoryKind.pagineBianche:
        return _decode('Hi5YUxU4Qho=');
      case DirectoryKind.pagineGialle:
        return _decode('Hi5YUxU4Qh8=');
    }
  }

  String get detailEndpoint {
    switch (this) {
      case DirectoryKind.pagineBianche:
        return _decode('CS5NQB88Qho=');
      case DirectoryKind.pagineGialle:
        return _decode('CS5NQB88Qh8=');
    }
  }

  String get primaryFieldLabel {
    switch (this) {
      case DirectoryKind.pagineBianche:
        return 'Inserisci nome o cognome';
      case DirectoryKind.pagineGialle:
        return 'Inserisci luogo o attività';
    }
  }
}

class SearchQuery {
  final DirectoryKind kind;
  final String what;
  final String where;
  final int page;
  final bool reverse;
  final String country;
  final String language;

  SearchQuery({
    required this.kind,
    required this.what,
    this.where = '',
    this.page = 1,
    this.reverse = false,
    this.country = 'it',
    this.language = 'it',
  });
}

class SearchResult {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? province;
  final String? category;
  final List<String> phones;
  final DetailResponse? inlineDetail;
  final String? ratingText;

  SearchResult({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.province,
    this.category,
    required this.phones,
    this.inlineDetail,
    this.ratingText,
  });
}

class SearchResponse {
  final String? displayWhere;
  final int currentPage;
  final bool isLastPage;
  final List<SearchResult> results;
  final List<String>? ambiguousPlaces;
  final DirectoryKind actualKind;

  SearchResponse({
    this.displayWhere,
    required this.currentPage,
    required this.isLastPage,
    required this.results,
    this.ambiguousPlaces,
    required this.actualKind,
  });
}

class DetailResponse {
  final String title;
  final String body;
  final String? description;
  final String? category;
  final String? address;
  final String? locality;
  final List<String> phones;
  final List<String> emails;
  final List<String> websites;
  final String? publicUrl;

  DetailResponse({
    required this.title,
    required this.body,
    this.description,
    this.category,
    this.address,
    this.locality,
    this.phones = const [],
    this.emails = const [],
    this.websites = const [],
    this.publicUrl,
  });
}

String _decode(String encoded) {
  final key = 'mK9!vP2xL8#qT4zN7@rW1sY6dF0hJ3uBzUrL1BirM@|\\'.codeUnits;
  final bytes = base64Decode(encoded);
  final decoded = <int>[];
  for (int i = 0; i < bytes.length; i++) {
    decoded.add(bytes[i] ^ key[i % key.length]);
  }
  return utf8.decode(decoded);
}

String normalizeDirectoryPhone(String input) {
  final trimmed = input.trim();
  if (!RegExp(r'^\+?[0-9\s()./\-]+$').hasMatch(trimmed)) {
    throw const FormatException(
      'Inserisci un numero di telefono italiano valido.',
    );
  }
  var value = trimmed.replaceAll(RegExp(r'[\s()./\-]'), '');
  if (value.startsWith('+39')) {
    value = value.substring(3);
  } else if (value.startsWith('0039')) {
    value = value.substring(4);
  } else if (value.startsWith('+') || value.startsWith('00')) {
    throw const FormatException(
      'Inserisci un numero italiano, con prefisso +39 facoltativo.',
    );
  }
  if (value.length < 5 || value.length > 15) {
    throw const FormatException(
      'Inserisci un numero di telefono completo di prefisso.',
    );
  }
  return value;
}

bool sameDirectoryPlace(SearchResult primary, SearchResult other) {
  String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), ' ').trim();
  if (normalize(primary.name) != normalize(other.name)) return false;
  final address = normalize(primary.address ?? '');
  final street = normalize(other.address ?? '');
  if (address.isNotEmpty && street.isNotEmpty) {
    final city = normalize(other.city ?? '');
    return (address == street || address.startsWith('$street ')) &&
        (city.isEmpty || address.contains(city));
  }
  String phone(String value) => value.replaceAll(RegExp(r'\D'), '');
  return other.phones.any(
    (p) =>
        phone(p).isNotEmpty && primary.phones.any((n) => phone(n) == phone(p)),
  );
}

class ItaliaOnlineService {
  ItaliaOnlineService({http.Client? client, String? clientToken})
    : _httpClient = client,
      _clientToken =
          clientToken ??
          const String.fromEnvironment('SONARPAD_ROUTE_CLIENT_TOKEN');
  final String _clientToken;
  final http.Client? _httpClient;
  Future<http.Response> _get(Uri uri) => _httpClient?.get(uri) ?? http.get(uri);
  String get _baseUrl => _decode('BT9NUUx/HRUjWkodMRoTOlYsGzZeHTVfCiMeAT4c');
  String get _client => _decode('HSlUThQ5Xh0=');
  String get _version => _decode('XmUAD0M=');

  Future<List<SearchResult>> _searchPlaces(SearchQuery query) async {
    if (_clientToken.isEmpty) {
      throw Exception('places_not_configured');
    }
    final uri = Uri.parse('https://sonarpad.com/api/luoghi.php');
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Sonarpad/Mobile',
      'X-Sonarpad-Route-Token': _clientToken,
    };
    final body = jsonEncode({
      'q': query.what,
      'citta': query.where,
      'paese': query.country,
      'lingua': query.language,
    });
    final response =
        await (_httpClient?.post(uri, headers: headers, body: body) ??
                http.post(uri, headers: headers, body: body))
            .timeout(const Duration(seconds: 40));
    if (response.statusCode != 200) {
      throw Exception('places_unavailable');
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['ok'] != true) throw Exception('places_search_failed');
    final results = (json['data'] as Map<String, dynamic>)['risultati'] as List;
    final text = placeStrings(query.language);
    return results.map((value) {
      final p = value as Map<String, dynamic>;
      final name = p['nome'] as String;
      final address = p['indirizzo'] as String?;
      final phones = List<String>.from(p['telefoni'] as List);
      final categories = List<String>.from(p['categorie'] as List).join(', ');
      final website = (p['sito_web'] as String?)?.trim();
      final websites = [if (website != null && website.isNotEmpty) website];
      final stars = p['stelle'] as num?;
      final count = p['numero_recensioni'] as int?;
      final rating = stars != null && stars.isFinite && stars >= 1 && stars <= 5
          ? text.placesRating.replaceAll('%stars%', '$stars') +
                (count == null
                    ? ''
                    : text.placesReviews.replaceAll('%count%', '$count'))
          : null;
      final status = p['stato_apertura'] as String?;
      final hours = <String>[];
      final now = DateTime.now();
      for (final day in (p['orari_apertura'] as List? ?? const [])) {
        if (day is! Map) continue;
        final name = day['giorno'] as String? ?? '';
        final date = day['data'] as String?;
        final ranges = (day['fasce'] as List? ?? const [])
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .map((value) => formatOpeningRange(value, language: query.language))
            .toList();
        if (name.trim().isEmpty || ranges.isEmpty) continue;
        hours.add(
          '${openingDayLabel(name, date, now, language: query.language)}: ${ranges.join('; ')}',
        );
      }
      final description = [
        p['descrizione'] as String?,
        rating,
        if (status != null && status.trim().isNotEmpty)
          '${text.placesStatus}: $status',
        hours.isEmpty
            ? text.placesHoursMissing
            : '${text.placesHours}:\n${hours.join('\n')}',
      ].whereType<String>().where((s) => s.isNotEmpty).join('\n');
      final body = [
        name,
        if (categories.isNotEmpty) '${text.placesCategory}: $categories',
        '${text.placesAddress}: ${address ?? text.placesUnavailable}',
        '${text.placesPhone}: ${phones.isEmpty ? text.placesUnavailable : phones.join(' - ')}',
        if (websites.isNotEmpty) '${text.placesWebsite}: ${websites.first}',
        if (description.isNotEmpty) description,
      ].join('\n\n');
      return SearchResult(
        id: 'place:${p['id'] as String}',
        name: name,
        address: address,
        category: categories.isEmpty ? null : categories,
        phones: phones,
        ratingText: rating,
        inlineDetail: DetailResponse(
          title: name,
          body: body,
          address: address,
          category: categories.isEmpty ? null : categories,
          phones: phones,
          description: description.isEmpty ? null : description,
          websites: websites,
        ),
      );
    }).toList();
  }

  Future<SearchResponse> searchActivities(
    SearchQuery query, {
    bool includeItalianDirectories = true,
  }) async {
    if (!includeItalianDirectories ||
        (!query.reverse &&
            query.kind == DirectoryKind.pagineGialle &&
            query.country != 'it')) {
      return SearchResponse(
        displayWhere: query.where,
        currentPage: 1,
        isLastPage: true,
        results: await _searchPlaces(query),
        actualKind: DirectoryKind.pagineGialle,
      );
    }
    if (query.reverse ||
        query.kind != DirectoryKind.pagineGialle ||
        query.page > 1) {
      return search(query);
    }
    // Start both requests together; an unavailable source must not hide the other.
    final primaryFuture = _searchPlaces(query).then<List<SearchResult>?>(
      (items) => items,
      onError: (Object _, StackTrace stackTrace) => null,
    );
    SearchResponse? legacy;
    Object? legacyError;
    try {
      legacy = await search(query);
    } catch (error) {
      legacyError = error;
    }
    final primary = await primaryFuture;
    if (primary == null || primary.isEmpty) {
      if (legacy != null) return legacy;
      throw legacyError ??
          Exception('Ricerca temporaneamente non disponibile.');
    }
    if (legacy?.ambiguousPlaces?.isNotEmpty ?? false) return legacy!;
    final source = legacy?.actualKind ?? DirectoryKind.pagineGialle;
    final prefix = source == DirectoryKind.pagineBianche ? 'pb:' : 'pg:';
    final results = [...primary];
    for (final item in legacy?.results ?? <SearchResult>[]) {
      if (primary.any((place) => sameDirectoryPlace(place, item))) continue;
      results.add(
        SearchResult(
          id: '$prefix${item.id}',
          name: item.name,
          address: item.address,
          city: item.city,
          province: item.province,
          category: item.category,
          phones: item.phones,
        ),
      );
    }
    return SearchResponse(
      displayWhere: legacy?.displayWhere ?? query.where,
      currentPage: legacy?.currentPage ?? query.page,
      isLastPage: legacy?.isLastPage ?? true,
      results: results,
      actualKind: source,
    );
  }

  Future<SearchResponse> searchPhone(SearchQuery query) async {
    final number = normalizeDirectoryPhone(query.what);
    final results = <SearchResult>[];
    final seen = <String>{};
    final errors = <Object>[];
    var succeeded = false;
    var isLastPage = true;
    for (final kind in DirectoryKind.values) {
      try {
        final response = await search(
          SearchQuery(
            kind: kind,
            what: number,
            page: query.page,
            reverse: true,
          ),
        );
        succeeded = true;
        isLastPage = isLastPage && response.isLastPage;
        final prefix = response.actualKind == DirectoryKind.pagineBianche
            ? 'pb:'
            : 'pg:';
        for (final item in response.results) {
          final id = '$prefix${item.id}';
          if (seen.add(id)) {
            results.add(
              SearchResult(
                id: id,
                name: item.name,
                address: item.address,
                city: item.city,
                province: item.province,
                category: item.category,
                phones: item.phones,
              ),
            );
          }
        }
      } catch (error) {
        errors.add(error);
      }
    }
    if (!succeeded || (results.isEmpty && errors.isNotEmpty)) {
      throw Exception(errors.join('\n'));
    }
    return SearchResponse(
      currentPage: query.page,
      isLastPage: isLastPage,
      results: results,
      actualKind: query.kind,
    );
  }

  Future<SearchResponse> search(SearchQuery query) async {
    final what = query.reverse
        ? normalizeDirectoryPhone(query.what)
        : query.what.trim();
    if (what.isEmpty) {
      throw Exception('Il campo ${query.kind.primaryFieldLabel} è vuoto.');
    }

    final mappedWhat = _mappedSearchTerm(query.kind, what);
    final queryParams = <String, String>{
      'client': _client,
      'version': _version,
      'what': mappedWhat,
    };
    if (!query.reverse && query.where.trim().isNotEmpty) {
      queryParams['where'] = query.where.trim();
    }
    if (query.page > 1) {
      queryParams['page'] = query.page.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl${query.kind.searchEndpoint}',
    ).replace(queryParameters: queryParams);

    final response = await _get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      if (response.statusCode == 500) {
        if (query.kind == DirectoryKind.pagineGialle) {
          try {
            return await search(
              SearchQuery(
                kind: DirectoryKind.pagineBianche,
                what: what,
                where: query.where,
                page: query.page,
                reverse: query.reverse,
              ),
            );
          } catch (e) {
            if (query.reverse) rethrow;
            await AppLogger.log(
              'ItaliaOnlineService: fallback Pagine Bianche failed after '
              'Pagine Gialle returned 500: $e',
            );
            return _emptySearchResponse(DirectoryKind.pagineBianche);
          }
        }
        if (query.reverse) {
          throw Exception(ItalianDirectoryLabels.serviceUnavailable);
        }
        return _emptySearchResponse(query.kind);
      }
      throw Exception('Errore di rete: ${response.statusCode}');
    }

    final parsed = _parseSearchResponse(response.bodyBytes, query.kind);
    if (!query.reverse) return parsed;
    if (parsed.ambiguousPlaces != null) {
      throw Exception(ItalianDirectoryLabels.reverseUnavailable);
    }
    return SearchResponse(
      displayWhere: parsed.displayWhere,
      currentPage: parsed.currentPage,
      isLastPage: parsed.isLastPage,
      ambiguousPlaces: parsed.ambiguousPlaces,
      actualKind: parsed.actualKind,
      results: parsed.results
          .where(
            (r) => r.phones.any((phone) {
              try {
                return normalizeDirectoryPhone(phone) == what;
              } catch (_) {
                return false;
              }
            }),
          )
          .toList(),
    );
  }

  String _mappedSearchTerm(DirectoryKind kind, String what) {
    if (kind == DirectoryKind.pagineGialle &&
        what.trim().toLowerCase() == 'bar') {
      return 'bar caffetteria';
    }
    return what;
  }

  SearchResponse _emptySearchResponse(DirectoryKind kind) {
    return SearchResponse(
      currentPage: 1,
      isLastPage: true,
      results: [],
      actualKind: kind,
    );
  }

  Future<DetailResponse> loadDetail(SearchQuery query, String id) async {
    if (id.startsWith('pb:') || id.startsWith('pg:')) {
      return loadDetail(
        SearchQuery(
          kind: id.startsWith('pb:')
              ? DirectoryKind.pagineBianche
              : DirectoryKind.pagineGialle,
          what: query.what,
          where: query.reverse ? '' : query.where,
          page: query.page,
          reverse: query.reverse,
        ),
        id.substring(3),
      );
    }

    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      throw Exception('Risultato non valido: identificativo mancante.');
    }

    final queryParams = <String, String>{
      'client': _client,
      'version': _version,
      'id': trimmedId,
      'what': query.reverse
          ? normalizeDirectoryPhone(query.what)
          : query.what.trim(),
    };
    if (!query.reverse && query.where.trim().isNotEmpty) {
      queryParams['where'] = query.where.trim();
    }

    final uri = Uri.parse(
      '$_baseUrl${query.kind.detailEndpoint}',
    ).replace(queryParameters: queryParams);

    final response = await _get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception('Errore di rete: ${response.statusCode}');
    }

    return _parseDetailResponse(response.bodyBytes, query.kind);
  }

  SearchResponse _parseSearchResponse(List<int> bodyBytes, DirectoryKind kind) {
    // Gestione charset simile a _decodeServerText in bdciechi_service.dart se necessario
    String xmlStr;
    try {
      xmlStr = utf8.decode(bodyBytes);
    } catch (_) {
      xmlStr = latin1.decode(bodyBytes);
    }

    final document = XmlDocument.parse(xmlStr);
    final responseNode = document.getElement('response');
    if (responseNode == null) {
      throw Exception('Risposta XML non valida');
    }

    final status = responseNode.getElement('status')?.innerText.trim();
    if (status == '302') {
      final placesNode = responseNode.getElement('places');
      final places =
          placesNode
              ?.findElements('place')
              .map((e) => e.getElement('address')?.innerText.trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];
      return SearchResponse(
        currentPage: 1,
        isLastPage: true,
        results: [],
        ambiguousPlaces: places,
        actualKind: kind,
      );
    }

    if (status != '200') {
      throw Exception('Ricerca non riuscita (status $status).');
    }

    final displayWhere = responseNode.getElement('where')?.innerText.trim();
    final currentPage =
        int.tryParse(
          responseNode.getElement('current_page')?.innerText.trim() ?? '1',
        ) ??
        1;
    final isLastPageStr = responseNode
        .getElement('isLastPage')
        ?.innerText
        .trim();
    bool isLastPage = isLastPageStr == '1';

    final resultsNode = responseNode.getElement('results');
    final results = <SearchResult>[];

    if (resultsNode != null) {
      for (final resultNode in resultsNode.findElements('result')) {
        final id = resultNode.getElement('id')?.innerText.trim() ?? '';
        final name = resultNode.getElement('name')?.innerText.trim() ?? '';
        if (id.isEmpty || name.isEmpty) continue;

        final address = resultNode.getElement('address')?.innerText.trim();
        final city = resultNode.getElement('city')?.innerText.trim();
        final province = resultNode.getElement('province')?.innerText.trim();
        final category = resultNode.getElement('category')?.innerText.trim();

        final phonesNode = resultNode.getElement('phones');
        final phones = <String>[];
        if (phonesNode != null) {
          for (final phoneNode in phonesNode.findElements('phone')) {
            final number = phoneNode.getElement('number')?.innerText.trim();
            if (number != null && number.isNotEmpty) {
              phones.add(number);
            }
          }
        }

        results.add(
          SearchResult(
            id: id,
            name: name,
            address: address,
            city: city,
            province: province,
            category: category,
            phones: phones,
          ),
        );
      }
    }

    // Deduplicate logic omitted for brevity, keeping simple for mobile display

    return SearchResponse(
      displayWhere: displayWhere,
      currentPage: currentPage,
      isLastPage: isLastPage,
      results: results,
      actualKind: kind,
    );
  }

  DetailResponse _parseDetailResponse(List<int> bodyBytes, DirectoryKind kind) {
    String xmlStr;
    try {
      xmlStr = utf8.decode(bodyBytes);
    } catch (_) {
      xmlStr = latin1.decode(bodyBytes);
    }

    final document = XmlDocument.parse(xmlStr);
    final responseNode = document.getElement('response');
    if (responseNode == null) {
      throw Exception('Dettaglio XML non valido');
    }

    final detailNode = responseNode.getElement('detail');
    if (detailNode == null) {
      throw Exception('Nodo detail mancante');
    }

    final name = detailNode.getElement('name')?.innerText.trim();
    final description = detailNode.getElement('description')?.innerText.trim();
    final category = detailNode.getElement('category')?.innerText.trim();
    final address = detailNode.getElement('address')?.innerText.trim();
    final city = detailNode.getElement('city')?.innerText.trim();
    final province = detailNode.getElement('province')?.innerText.trim();
    final publicUrl = detailNode.getElement('public_url')?.innerText.trim();

    final phones = <String>[];
    final phonesNode = detailNode.getElement('phones');
    if (phonesNode != null) {
      for (final phoneNode in phonesNode.findElements('phone')) {
        final number = phoneNode.getElement('number')?.innerText.trim();
        if (number != null && number.isNotEmpty) phones.add(number);
      }
    }

    final websites = <String>[];
    final websitesNode = detailNode.getElement('websites');
    if (websitesNode != null) {
      for (final siteNode in websitesNode.findElements('website')) {
        final u = siteNode.getElement('url')?.innerText.trim();
        if (u != null && u.isNotEmpty) websites.add(u);
      }
    }

    final emails = <String>[];
    final emailsNode = detailNode.getElement('emails');
    if (emailsNode != null) {
      for (final emNode in emailsNode.findElements('email')) {
        final e = emNode.getElement('address')?.innerText.trim();
        if (e != null && e.isNotEmpty) emails.add(e);
      }
    }

    final buffer = StringBuffer();
    if (description != null && description.isNotEmpty) {
      buffer.writeln(description);
      buffer.writeln();
    }
    if (category != null && category.isNotEmpty) {
      buffer.writeln('Categoria: $category');
      buffer.writeln();
    }

    // Indirizzo
    String locality = '';
    if (city != null && province != null) {
      locality = '$city ($province)';
    } else if (city != null) {
      locality = city;
    } else if (province != null) {
      locality = province;
    }

    if (address != null && address.isNotEmpty) {
      buffer.writeln('Indirizzo:');
      buffer.writeln(address);
      if (locality.isNotEmpty) buffer.writeln(locality);
      buffer.writeln();
    } else if (locality.isNotEmpty) {
      buffer.writeln('Località:');
      buffer.writeln(locality);
      buffer.writeln();
    }

    if (phones.isNotEmpty) {
      buffer.writeln('Numeri di telefono:');
      for (final p in phones) {
        buffer.writeln(p);
      }
      buffer.writeln();
    }

    if (emails.isNotEmpty) {
      buffer.writeln('Email:');
      for (final e in emails) {
        buffer.writeln(e);
      }
      buffer.writeln();
    }

    if (websites.isNotEmpty) {
      buffer.writeln('Siti web:');
      for (final w in websites) {
        buffer.writeln(w);
      }
      buffer.writeln();
    }

    if (publicUrl != null && publicUrl.isNotEmpty) {
      buffer.writeln('Scheda web:');
      buffer.writeln(publicUrl);
    }

    return DetailResponse(
      title: name ?? 'Dettaglio',
      body: buffer.toString().trim(),
      description: description,
      category: category,
      address: address,
      locality: locality,
      phones: phones,
      emails: emails,
      websites: websites,
      publicUrl: publicUrl,
    );
  }
}
