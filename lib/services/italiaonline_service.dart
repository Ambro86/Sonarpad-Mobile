import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../utils/app_logger.dart';

enum DirectoryKind {
  pagineBianche,
  pagineGialle,
}

extension DirectoryKindExtension on DirectoryKind {
  String get label {
    switch (this) {
      case DirectoryKind.pagineBianche:
        return 'Pagine Bianche';
      case DirectoryKind.pagineGialle:
        return 'Pagine Gialle';
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
        return 'Inserisci attività';
    }
  }
}

class SearchQuery {
  final DirectoryKind kind;
  final String what;
  final String where;
  final int page;

  SearchQuery({
    required this.kind,
    required this.what,
    this.where = '',
    this.page = 1,
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

  SearchResult({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.province,
    this.category,
    required this.phones,
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

class ItaliaOnlineService {
  String get _baseUrl => _decode('BT9NUUx/HRUjWkodMRoTOlYsGzZeHTVfCiMeAT4c');
  String get _client => _decode('HSlUThQ5Xh0=');
  String get _version => _decode('XmUAD0M=');

  Future<SearchResponse> search(SearchQuery query) async {
    final what = query.what.trim();
    if (what.isEmpty) {
      throw Exception('Il campo ${query.kind.primaryFieldLabel} è vuoto.');
    }

    final mappedWhat = _mappedSearchTerm(query.kind, what);
    final queryParams = <String, String>{
      'client': _client,
      'version': _version,
      'what': mappedWhat,
    };
    if (query.where.trim().isNotEmpty) {
      queryParams['where'] = query.where.trim();
    }
    if (query.page > 1) {
      queryParams['page'] = query.page.toString();
    }

    final uri = Uri.parse('$_baseUrl${query.kind.searchEndpoint}')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      if (response.statusCode == 500) {
        if (query.kind == DirectoryKind.pagineGialle) {
          try {
            return await search(SearchQuery(
              kind: DirectoryKind.pagineBianche,
              what: what,
              where: query.where,
              page: query.page,
            ));
          } catch (e) {
            await AppLogger.log(
              'ItaliaOnlineService: fallback Pagine Bianche failed after '
              'Pagine Gialle returned 500: $e',
            );
            return _emptySearchResponse(DirectoryKind.pagineBianche);
          }
        }
        return _emptySearchResponse(query.kind);
      }
      throw Exception('Errore di rete: ${response.statusCode}');
    }

    return _parseSearchResponse(response.bodyBytes, query.kind);
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
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      throw Exception('Risultato non valido: identificativo mancante.');
    }

    final queryParams = <String, String>{
      'client': _client,
      'version': _version,
      'id': trimmedId,
      'what': query.what.trim(),
    };
    if (query.where.trim().isNotEmpty) {
      queryParams['where'] = query.where.trim();
    }

    final uri = Uri.parse('$_baseUrl${query.kind.detailEndpoint}')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(const Duration(seconds: 45));
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
      final places = placesNode
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
    final currentPage = int.tryParse(
            responseNode.getElement('current_page')?.innerText.trim() ?? '1') ??
        1;
    final isLastPageStr =
        responseNode.getElement('isLastPage')?.innerText.trim();
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

        results.add(SearchResult(
          id: id,
          name: name,
          address: address,
          city: city,
          province: province,
          category: category,
          phones: phones,
        ));
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
