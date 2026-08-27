import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'aifa_service.dart';
import 'app_cache_service.dart';

class ParafarmacoSearchResult {
  final String name;
  final String category;
  final String sourceName;
  final String sourceUrl;
  final String? snippet;
  final String? code;

  const ParafarmacoSearchResult({
    required this.name,
    required this.category,
    required this.sourceName,
    required this.sourceUrl,
    this.snippet,
    this.code,
  });
}

class ParafarmacoDetail {
  final String name;
  final String category;
  final String sourceName;
  final String sourceUrl;
  final String? code;
  final Map<ParafarmacoSectionType, String> sections;
  final String fullText;

  const ParafarmacoDetail({
    required this.name,
    required this.category,
    required this.sourceName,
    required this.sourceUrl,
    required this.sections,
    required this.fullText,
    this.code,
  });

  String sectionText(ParafarmacoSectionType type) {
    if (type == ParafarmacoSectionType.complete) return fullText;
    final direct = sections[type];
    if (direct != null && direct.trim().length >= 40) return direct.trim();
    return _missingSectionText(type);
  }

  String _missingSectionText(ParafarmacoSectionType type) {
    return 'Questa sezione non è disponibile o non è stata trovata in modo affidabile nella fonte pubblica. '
        'Apri la scheda completa per leggere tutto il testo disponibile e verifica sempre confezione, medico o farmacista.';
  }
}

enum ParafarmacoSectionType {
  indications,
  usage,
  warnings,
  composition,
  complete,
}

extension ParafarmacoSectionTypeLabel on ParafarmacoSectionType {
  String get label {
    switch (this) {
      case ParafarmacoSectionType.indications:
        return 'A cosa serve';
      case ParafarmacoSectionType.usage:
        return 'Posologia o modalità d\'uso';
      case ParafarmacoSectionType.warnings:
        return 'Avvertenze';
      case ParafarmacoSectionType.composition:
        return 'Composizione';
      case ParafarmacoSectionType.complete:
        return 'Scheda completa / bugiardino';
    }
  }
}

class ParafarmacoService {
  static const _userAgent =
      'Mozilla/5.0 (compatible; SonarpadMobile/1.0; +https://sonarpad.com)';
  static const _codifaIndexUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
      'Mobile/15E148 Safari/604.1';
  static const _legacyCodifaBase = 'https://codifa-legacy.farmadati.it';
  static const _publicCodifaBase = 'https://www.codifa.it';

  static final Map<String, List<ParafarmacoSearchResult>>
      _alphabeticalResultCache = {};

  final http.Client? _client;
  final Map<String, dom.Document> _indexCache = {};

  ParafarmacoService({http.Client? client}) : _client = client;

  /// Restituisce l'indice alfabetico dei medicinali Codifa per una lettera.
  /// L'indice serve soltanto per lo sfoglia A-Z: aprendo un elemento Sonarpad
  /// torna alla ricerca AIFA ufficiale per mostrare confezioni e bugiardino.
  Future<List<ParafarmacoSearchResult>> browseDrugsByLetter(
    String rawLetter,
  ) {
    return _browseCodifaAlphabeticalSection(
      section: 'farmaci',
      rawLetter: rawLetter,
    );
  }

  /// Restituisce l'indice alfabetico dei parafarmaci Codifa per una lettera.
  Future<List<ParafarmacoSearchResult>> browseParafarmaciByLetter(
    String rawLetter,
  ) {
    return _browseCodifaAlphabeticalSection(
      section: 'parafarmaci',
      rawLetter: rawLetter,
    );
  }

  Future<List<ParafarmacoSearchResult>> _browseCodifaAlphabeticalSection({
    required String section,
    required String rawLetter,
  }) async {
    final letter = _normalizeAlphabeticalLetter(rawLetter);
    if (letter == null) return const [];

    final cacheKey = '$section:$letter';
    final cached = _client == null ? _alphabeticalResultCache[cacheKey] : null;
    if (cached != null) return List.of(cached);

    Object? lastError;
    var hadSuccessfulResponse = false;
    for (final base in const [_legacyCodifaBase, _publicCodifaBase]) {
      try {
        final uri = Uri.parse('$base/$section/${letter.toLowerCase()}');
        final results = await _browseCodifaIndexPage(
          uri,
          section: section,
          letter: letter,
        );
        hadSuccessfulResponse = true;
        if (results.isNotEmpty) {
          if (_client == null) {
            _alphabeticalResultCache[cacheKey] = List.unmodifiable(results);
          }
          return List.of(results);
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (hadSuccessfulResponse) return const [];
    if (lastError != null) throw lastError;
    return const [];
  }

  Future<List<ParafarmacoSearchResult>> _browseCodifaIndexPage(
    Uri uri, {
    required String section,
    required String letter,
  }) async {
    // Gli indici alfabetici Codifa non vanno passati attraverso la pulizia
    // usata per le schede prodotto: alcune versioni del sito racchiudono
    // l'elenco in contenitori di navigazione/menu, che verrebbero rimossi.
    final document = await _loadCodifaIndexDocument(uri);
    final links = document.querySelectorAll('a[href]');
    final results = <ParafarmacoSearchResult>[];
    final expectedSection = section.toLowerCase();
    final expectedLetter = letter.toLowerCase();

    for (final link in links) {
      final href = link.attributes['href']?.trim() ?? '';
      if (!_isCodifaProductHref(href)) continue;

      final url = _absoluteCodifaUrl(href);
      final parsed = Uri.tryParse(url);
      if (parsed == null) continue;
      final segments = parsed.pathSegments.map((value) => value.toLowerCase()).toList();
      if (segments.length < 3 ||
          segments.first != expectedSection ||
          segments[1] != expectedLetter) {
        continue;
      }

      final rawName = _cleanText(link.text);
      final name = rawName.isNotEmpty ? rawName : _nameFromCodifaUrl(url);
      if (name.length < 2 || _initialCatalogLetter(name) != letter) continue;

      final parentText = _cleanText(link.parent?.text ?? '');
      results.add(
        ParafarmacoSearchResult(
          name: name,
          category: _categoryFromCodifaUrl(url),
          sourceName: 'Codifa/Farmadati',
          sourceUrl: url,
          snippet: _snippetFromParent(parentText, name),
        ),
      );
    }

    final deduplicated = _deduplicateResults(results);
    deduplicated.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return deduplicated;
  }

  String? _normalizeAlphabeticalLetter(String rawLetter) {
    final value = rawLetter.trim().toUpperCase();
    if (value.length != 1) return null;
    final code = value.codeUnitAt(0);
    return code >= 0x41 && code <= 0x5A ? value : null;
  }

  String? _initialCatalogLetter(String value) {
    const foldedInitials = <String, String>{
      'À': 'A',
      'Á': 'A',
      'Â': 'A',
      'Ã': 'A',
      'Ä': 'A',
      'Å': 'A',
      'Ç': 'C',
      'È': 'E',
      'É': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'Ì': 'I',
      'Í': 'I',
      'Î': 'I',
      'Ï': 'I',
      'Ñ': 'N',
      'Ò': 'O',
      'Ó': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ö': 'O',
      'Ù': 'U',
      'Ú': 'U',
      'Û': 'U',
      'Ü': 'U',
      'Ý': 'Y',
    };
    for (final rune in value.trim().runes) {
      final upper = String.fromCharCode(rune).toUpperCase();
      final folded = foldedInitials[upper] ?? upper;
      if (folded.length != 1) continue;
      final code = folded.codeUnitAt(0);
      if (code >= 0x41 && code <= 0x5A) return folded;
    }
    return null;
  }

  /// Rimuove soltanto le schede di medicinali Codifa già rappresentate dai
  /// risultati ufficiali AIFA. Integratori, dispositivi e parafarmaci con lo
  /// stesso marchio restano disponibili.
  List<ParafarmacoSearchResult> excludeAifaMedicationDuplicates(
    List<ParafarmacoSearchResult> products,
    List<AifaDrugResult> aifaDrugs,
  ) {
    if (aifaDrugs.isEmpty) return List.of(products);
    return products
        .where((product) =>
            !isMedicationResult(product) ||
            !aifaDrugs.any((drug) =>
                _sameCommercialMedicine(product.name, drug.denominazione)))
        .toList(growable: false);
  }

  bool isMedicationResult(ParafarmacoSearchResult product) {
    final path = Uri.tryParse(product.sourceUrl)?.path.toLowerCase() ?? '';
    return path.contains('/farmaci/') ||
        product.category.toLowerCase().contains('medicinale');
  }

  bool _sameCommercialMedicine(String productName, String aifaName) {
    final product = _normalize(productName);
    final aifa = _normalize(aifaName);
    if (product.length < 3 || aifa.length < 3) return false;
    return product == aifa ||
        product.startsWith('$aifa ') ||
        aifa.startsWith('$product ');
  }

  Future<List<ParafarmacoSearchResult>> searchProducts(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) return const [];

    final found = <String, ParafarmacoSearchResult>{};

    // Codifa/Farmadati non espone una ricerca pubblica stabile con ?search=.
    // La strada più affidabile sulle pagine pubbliche è aprire gli indici
    // alfabetici (/parafarmaci/m, /integratori/m, ecc.) e filtrare i link in
    // modo locale. Così Polase, Multicentrum, Saugella, Vea, ecc. vengono
    // trovati senza toccare la pipeline AIFA/AIC.
    for (final url in _codifaIndexUrlsForQuery(query)) {
      try {
        final results = await _searchCodifaPage(Uri.parse(url), query);
        for (final result in results) {
          found[result.sourceUrl] = result;
        }
        if (found.length >= 30) break;
      } catch (_) {
        // Sito non raggiungibile o layout cambiato: passa alla variante dopo.
      }
    }

    // Fallback breve sulle vecchie varianti, utile se Codifa dovesse riattivare
    // una pagina di ricerca indicizzabile. Non è la fonte primaria.
    if (found.length < 6) {
      final encoded = Uri.encodeComponent(query);
      final searchUrls = <String>[
        'https://www.codifa.it/farmaci?search=$encoded',
        'https://www.codifa.it/parafarmaci?search=$encoded',
        'https://www.codifa.it/integratori?search=$encoded',
      ];
      for (final url in searchUrls) {
        try {
          final results = await _searchCodifaPage(Uri.parse(url), query);
          for (final result in results) {
            found[result.sourceUrl] = result;
          }
          if (found.length >= 30) break;
        } catch (_) {}
      }
    }

    for (final direct in _knownDirectProductResults(query)) {
      found[direct.sourceUrl] = direct;
    }

    final list = found.values.toList();
    list.sort((a, b) {
      final aScore = _resultScore(a, query);
      final bScore = _resultScore(b, query);
      return bScore.compareTo(aScore);
    });
    return list.take(30).toList();
  }

  List<String> _codifaIndexUrlsForQuery(String query) {
    final tokens = _meaningfulSearchTokens(query);
    final letters = <String>{};
    for (final token in tokens) {
      final match = RegExp(r'[a-z0-9]').firstMatch(token);
      if (match != null) letters.add(match.group(0)!);
      if (letters.length >= 2) break;
    }
    if (letters.isEmpty) {
      final normalized = _normalize(query);
      if (normalized.isNotEmpty) letters.add(normalized[0]);
    }

    final urls = <String>[];
    for (final letter in letters) {
      // Dal 2026 www.codifa.it reindirizza gli indici alfabetici al dominio
      // legacy di Farmadati. Usiamo direttamente la variante HTTPS ufficiale:
      // evita redirect fragili su iOS e, soprattutto, mantiene coerenti gli
      // href assoluti restituiti dalla pagina. Il dominio pubblico resta come
      // fallback nel caso Farmadati cambi nuovamente instradamento.
      for (final base in const [_legacyCodifaBase, _publicCodifaBase]) {
        urls.add('$base/parafarmaci/$letter');
        urls.add('$base/integratori/$letter');
        // Farmaci Codifa resta un supporto secondario: i medicinali veri
        // passano comunque dalla ricerca AIFA, che non viene modificata.
        urls.add('$base/farmaci/$letter');
      }
    }
    return urls;
  }

  Future<List<ParafarmacoSearchResult>> _searchCodifaPage(
      Uri uri, String query) async {
    final document = await _loadCodifaDocument(uri);
    final links = document.querySelectorAll('a[href]');
    final results = <ParafarmacoSearchResult>[];
    final tokens = _meaningfulSearchTokens(query);

    for (final link in links) {
      final href = link.attributes['href']?.trim() ?? '';
      if (!_isCodifaProductHref(href)) continue;

      final url = _absoluteCodifaUrl(href);
      final rawName = _cleanText(link.text);
      final name = rawName.isNotEmpty ? rawName : _nameFromCodifaUrl(url);
      if (name.length < 2) continue;

      final parentText = _cleanText(link.parent?.text ?? '');
      final normalizedHaystack = _normalize('$name $parentText $url');
      if (!_matchesQueryTokens(normalizedHaystack, tokens)) continue;

      results.add(ParafarmacoSearchResult(
        name: name,
        category: _categoryFromCodifaUrl(url),
        sourceName: 'Codifa/Farmadati',
        sourceUrl: url,
        snippet: _snippetFromParent(parentText, name),
      ));
    }
    return _deduplicateResults(results);
  }

  Future<dom.Document> _loadCodifaIndexDocument(Uri uri) async {
    final key = 'alphabetical:${uri.toString()}';
    final cached = _indexCache[key];
    if (cached != null) return cached;

    final response = await _getCodifaIndex(uri);
    if (response.statusCode != 200) {
      _throwCodifaHttp(response);
    }

    final body = _decodeResponse(response);
    final document = html_parser.parse(body);

    // Non chiamare _removeNoise(document) qui. Per gli indici A-Z servono
    // tutti i link della pagina; filtriamo poi in modo stretto per sezione,
    // lettera e host invece di eliminare contenitori HTML a priori.
    _indexCache[key] = document;
    return document;
  }

  Future<http.Response> _getCodifaIndex(Uri uri) {
    const headers = <String, String>{
      'User-Agent': _codifaIndexUserAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'it-IT,it;q=0.9,en;q=0.7',
    };
    final client = _client;
    if (client != null) {
      return client.get(uri, headers: headers);
    }
    return http.get(uri, headers: headers);
  }

  Future<dom.Document> _loadCodifaDocument(Uri uri) async {
    final key = uri.toString();
    final cached = _indexCache[key];
    if (cached != null) return cached;

    final response = await _get(uri);
    if (response.statusCode != 200) {
      _throwCodifaHttp(response);
    }

    final body = _decodeResponse(response);
    final document = html_parser.parse(body);
    _removeNoise(document);
    _indexCache[key] = document;
    return document;
  }

  Never _throwCodifaHttp(http.Response response) {
    throw Exception('HTTP ${response.statusCode}');
  }

  Future<http.Response> _get(Uri uri) {
    final client = _client;
    if (client != null) {
      return client.get(uri, headers: {'User-Agent': _userAgent});
    }
    return http.get(uri, headers: {'User-Agent': _userAgent});
  }

  List<ParafarmacoSearchResult> _deduplicateResults(
      List<ParafarmacoSearchResult> results) {
    final byUrl = <String, ParafarmacoSearchResult>{};
    for (final result in results) {
      byUrl[result.sourceUrl] = result;
    }
    return byUrl.values.toList();
  }

  bool _matchesQueryTokens(String normalizedHaystack, List<String> tokens) {
    if (tokens.isEmpty) return true;
    if (!normalizedHaystack.contains(tokens.first)) return false;
    if (tokens.length == 1) return true;

    final matched = tokens.where(normalizedHaystack.contains).length;
    if (matched >= 2) return true;

    // Per query come "Vea olio" o "Pic aerosol" il secondo termine è molto
    // generico e può non comparire nel nome pagina. Se il marchio è forte, non
    // scartiamo il risultato: l'ordinamento farà salire quello più pertinente.
    return tokens.first.length >= 3;
  }

  Future<ParafarmacoDetail> loadDetail(ParafarmacoSearchResult result) async {
    if (result.sourceUrl.startsWith('sonarpad://')) {
      return _detailFromCuratedSearchResult(result);
    }

    http.Response response;
    try {
      response = await _get(Uri.parse(result.sourceUrl));
    } catch (_) {
      final fallback = _detailFromFallbackSnippet(
        result,
        statusCode: 0,
        reason: 'la fonte esterna non è raggiungibile in modo stabile',
      );
      if (fallback != null) return fallback;
      rethrow;
    }
    if (response.statusCode != 200) {
      final fallback = _detailFromFallbackSnippet(
        result,
        statusCode: response.statusCode,
      );
      if (fallback != null) return fallback;
      throw Exception(
          'Impossibile aprire la scheda prodotto (HTTP ${response.statusCode})');
    }

    final body = _decodeResponse(response);
    final document = html_parser.parse(body);
    _removeNoise(document);

    final name = _extractTitle(document, fallback: result.name);
    final code = _extractCode(document) ?? result.code;
    final fullText = _cleanText(_bestBodyText(document));
    final sections = _extractSections(document, fullText);

    // Alcuni siti esterni caricano il contenuto via JavaScript oppure mostrano
    // soprattutto prezzi, pulsanti e materiale commerciale. In quei casi è più
    // corretto aprire una scheda sintetica curata dal fallback, invece di
    // far leggere a VoiceOver una pagina lunga ma poco utile.
    if (result.sourceName != 'Codifa/Farmadati' &&
        _shouldUseExternalSnippetFallback(fullText, sections)) {
      final fallback = _detailFromFallbackSnippet(
        result,
        statusCode: response.statusCode,
        parsedName: name,
        parsedCode: code,
        reason: 'la fonte esterna non espone sezioni leggibili in modo stabile',
      );
      if (fallback != null) return fallback;
    }

    return ParafarmacoDetail(
      name: name,
      category: result.category,
      sourceName: result.sourceName,
      sourceUrl: result.sourceUrl,
      code: code,
      sections: sections,
      fullText: _buildCompleteText(
        name: name,
        category: result.category,
        sourceName: result.sourceName,
        sourceUrl: result.sourceUrl,
        code: code,
        fullText: fullText,
      ),
    );
  }

  ParafarmacoDetail? _detailFromFallbackSnippet(
    ParafarmacoSearchResult result, {
    required int statusCode,
    String? parsedName,
    String? parsedCode,
    String? reason,
  }) {
    final snippet = result.snippet?.trim();
    if (snippet == null || snippet.length < 20) return null;
    if (result.sourceName == 'Codifa/Farmadati') return null;

    final reasonText = reason ??
        (statusCode == 200
            ? 'la fonte esterna non espone sezioni leggibili in modo stabile'
            : 'la fonte esterna ha risposto HTTP $statusCode durante l\'apertura');
    final note = 'Nota: $reasonText. '
        'Mostro quindi una scheda sintetica basata sul fallback curato e sulla fonte dichiarata, '
        'senza spacciarla per scheda Codifa o AIFA.';
    final body = '$snippet\n\n$note';
    final name = (parsedName?.trim().isNotEmpty ?? false)
        ? parsedName!.trim()
        : result.name;
    final code = parsedCode ?? result.code;

    return ParafarmacoDetail(
      name: name,
      category: result.category,
      sourceName: result.sourceName,
      sourceUrl: result.sourceUrl,
      code: code,
      sections: <ParafarmacoSectionType, String>{
        ParafarmacoSectionType.indications: snippet,
      },
      fullText: _buildCompleteText(
        name: name,
        category: result.category,
        sourceName: result.sourceName,
        sourceUrl: result.sourceUrl,
        code: code,
        fullText: body,
      ),
    );
  }

  ParafarmacoDetail _detailFromCuratedSearchResult(
      ParafarmacoSearchResult result) {
    final snippet = result.snippet?.trim() ?? '';
    final note =
        'Nota: questa è una scheda sintetica di fallback usata quando la fonte pubblica non restituisce in modo affidabile la variante richiesta. '
        'Non sostituisce confezione, medico o farmacista.';
    final body = snippet.isNotEmpty ? '$snippet\n\n$note' : note;

    return ParafarmacoDetail(
      name: result.name,
      category: result.category,
      sourceName: result.sourceName,
      sourceUrl: result.sourceUrl,
      code: result.code,
      sections: <ParafarmacoSectionType, String>{
        if (snippet.length >= 20) ParafarmacoSectionType.indications: snippet,
      },
      fullText: _buildCompleteText(
        name: result.name,
        category: result.category,
        sourceName: result.sourceName,
        sourceUrl: result.sourceUrl,
        code: result.code,
        fullText: body,
      ),
    );
  }

  bool _shouldUseExternalSnippetFallback(
    String fullText,
    Map<ParafarmacoSectionType, String> sections,
  ) {
    final cleaned = _cleanText(fullText);
    final normalized = _normalize(cleaned);
    final usefulSections = sections.entries
        .where((entry) => entry.value.trim().length >= 80)
        .length;

    if (cleaned.length < 500) return true;
    if (usefulSections == 0 && cleaned.length < 1200) return true;

    final commercialNoise = _containsAny(normalized, const [
      'costo spedizione',
      'tasse incluse',
      'risparmia',
      'acquista online',
      'carrello',
      'richiedi ora il campione',
      'loading',
    ]);
    if (commercialNoise && usefulSections <= 1) return true;

    return false;
  }

  Future<File> saveSectionAsText(
    ParafarmacoDetail detail,
    ParafarmacoSectionType type,
  ) async {
    final cacheDir = await AppCacheService.directory(
      AppCacheService.parafarmaciFolder,
    );

    final safeName = _safeFileName('${detail.name}_${type.name}');
    final file = File('${cacheDir.path}/$safeName.txt');
    final isCodifa = detail.sourceName == 'Codifa/Farmadati';
    final buffer = StringBuffer()
      ..writeln(detail.name)
      ..writeln(detail.category);
    if (!isCodifa) {
      buffer.writeln('Fonte: ${detail.sourceName}');
    }
    if (detail.code != null && detail.code!.trim().isNotEmpty) {
      buffer.writeln('Codice: ${detail.code}');
    }
    buffer
      ..writeln()
      ..writeln(type.label)
      ..writeln()
      ..writeln(detail.sectionText(type));
    if (!isCodifa) {
      buffer
        ..writeln()
        ..writeln('Nota: verifica sempre confezione, medico o farmacista.');
    }

    await file.writeAsString(buffer.toString(), encoding: utf8);
    return file;
  }

  List<ParafarmacoSearchResult> _knownDirectProductResults(String query) {
    final normalized = _normalize(query);
    final results = <ParafarmacoSearchResult>[];

    void addIf(bool condition, ParafarmacoSearchResult result) {
      if (condition) results.add(result);
    }

    void addCurated(
      bool condition, {
      required String name,
      required String category,
      required String slug,
      required String snippet,
      String? code,
    }) {
      addIf(
        condition,
        ParafarmacoSearchResult(
          name: name,
          category: category,
          sourceName: 'Scheda sintetica Sonarpad',
          sourceUrl: 'sonarpad://parafarmaci/$slug',
          snippet: snippet,
          code: code,
        ),
      );
    }

    addCurated(
      normalized.contains('connettivina') && normalized.contains('bio'),
      name: 'Connettivina Bio crema',
      category: 'Prodotto cutaneo / prodotto da farmacia',
      slug: 'connettivina-bio-crema',
      snippet:
          'Scheda sintetica per la variante Connettivina Bio crema. Usare secondo indicazioni presenti sulla confezione o fornite da medico/farmacista.',
    );
    addCurated(
      normalized.contains('gola') && normalized.contains('act'),
      name: 'Gola Act spray',
      category: 'Prodotto gola / prodotto da farmacia',
      slug: 'gola-act-spray',
      snippet:
          'Scheda sintetica per Gola Act spray. Prodotto per il benessere della gola; verificare sempre modalità d’uso e avvertenze sulla confezione.',
    );
    addCurated(
      normalized.contains('arnica') && normalized.contains('viti'),
      name: 'Arnica Viti gel',
      category: 'Dermocosmetico / prodotto da farmacia',
      slug: 'arnica-viti-gel',
      snippet:
          'Scheda sintetica per Arnica Viti gel. Gel topico della linea Arnica; verificare sempre modalità d’uso, cute integra e avvertenze sulla confezione.',
    );
    addCurated(
      normalized.contains('tantum') &&
          normalized.contains('verde') &&
          normalized.contains('natura') &&
          normalized.contains('spray'),
      name: 'Tantum Verde Natura spray',
      category: 'Prodotto gola / prodotto da farmacia',
      slug: 'tantum-verde-natura-spray',
      snippet:
          'Scheda sintetica per Tantum Verde Natura spray. Variante non AIFA della linea Tantum Verde Natura; verificare sempre composizione e modalità d’uso sulla confezione.',
    );
    addCurated(
      normalized.contains('tantum') &&
          normalized.contains('verde') &&
          normalized.contains('natura') &&
          normalized.contains('caramelle'),
      name: 'Tantum Verde Natura caramelle',
      category: 'Prodotto gola / prodotto da farmacia',
      slug: 'tantum-verde-natura-caramelle',
      snippet:
          'Scheda sintetica per Tantum Verde Natura caramelle. Variante in caramelle/pastiglie; verificare sempre ingredienti, allergeni e modalità d’uso sulla confezione.',
    );
    addCurated(
      normalized.contains('artelac') && normalized.contains('complete'),
      name: 'Artelac Complete collirio',
      category: 'Dispositivo oftalmico / prodotto da farmacia',
      slug: 'artelac-complete-collirio',
      snippet:
          'Scheda sintetica per Artelac Complete collirio. Prodotto oftalmico lubrificante; verificare sempre istruzioni e periodo di utilizzo dopo apertura.',
    );
    addCurated(
      normalized.contains('eucerin') && normalized.contains('aquaphor'),
      name: 'Eucerin Aquaphor',
      category: 'Dermocosmetico / prodotto da farmacia',
      slug: 'eucerin-aquaphor',
      snippet:
          'Scheda sintetica per Eucerin Aquaphor. Trattamento dermocosmetico per pelle secca o fragilizzata; verificare sempre indicazioni e ingredienti sulla confezione.',
    );
    addCurated(
      normalized.contains('somatoline') && normalized.contains('cosmetic'),
      name: 'Somatoline Cosmetic',
      category: 'Dermocosmetico / prodotto da farmacia',
      slug: 'somatoline-cosmetic',
      snippet:
          'Scheda sintetica per Somatoline Cosmetic. Linea dermocosmetica; verificare sempre prodotto specifico, modalità d’uso e avvertenze sulla confezione.',
    );
    addCurated(
      normalized.contains('bionike') && normalized.contains('proxera'),
      name: 'BioNike Proxera',
      category: 'Dermocosmetico / prodotto da farmacia',
      slug: 'bionike-proxera',
      snippet:
          'Scheda sintetica per BioNike Proxera. Linea dermocosmetica per pelle secca o sensibile; verificare sempre variante e modalità d’uso sulla confezione.',
    );
    addCurated(
      normalized.contains('massigen') &&
          normalized.contains('magnesio') &&
          normalized.contains('potassio'),
      name: 'Massigen Magnesio Potassio',
      category: 'Integratore / prodotto da farmacia',
      slug: 'massigen-magnesio-potassio',
      snippet:
          'Scheda sintetica per Massigen Magnesio Potassio. Integratore di sali minerali; verificare sempre dosaggio, età d’uso e avvertenze sulla confezione.',
    );
    addCurated(
      normalized.contains('aboca') && normalized.contains('libramed'),
      name: 'Aboca Libramed',
      category: 'Dispositivo medico / prodotto da farmacia',
      slug: 'aboca-libramed',
      snippet:
          'Scheda sintetica per Aboca Libramed. Prodotto Aboca; verificare sempre istruzioni ufficiali, modalità d’uso e avvertenze sulla confezione.',
    );
    addCurated(
      normalized.contains('thealoz') && normalized.contains('duo'),
      name: 'Thealoz Duo collirio',
      category: 'Dispositivo oftalmico / prodotto da farmacia',
      slug: 'thealoz-duo-collirio',
      snippet:
          'Scheda sintetica per Thealoz Duo collirio. Prodotto oftalmico lubrificante; verificare sempre istruzioni e periodo di utilizzo dopo apertura.',
    );
    addCurated(
      normalized.contains('floradix') && normalized.contains('ferro'),
      name: 'Floradix ferro',
      category: 'Integratore / prodotto da farmacia',
      slug: 'floradix-ferro',
      snippet:
          'Scheda sintetica per Floradix ferro. Integratore con ferro; verificare sempre dose giornaliera, età d’uso e avvertenze sulla confezione.',
    );
    addCurated(
      normalized.contains('ginexid') && normalized.contains('schiuma'),
      name: 'Ginexid schiuma',
      category: 'Prodotto ginecologico / prodotto da farmacia',
      slug: 'ginexid-schiuma',
      snippet:
          'Scheda sintetica per Ginexid schiuma. Prodotto per igiene/uso ginecologico; verificare sempre modalità d’uso e avvertenze sulla confezione.',
    );
    addCurated(
      normalized.contains('hylo') && normalized.contains('dual'),
      name: 'Hylo Dual collirio',
      category: 'Dispositivo oftalmico / prodotto da farmacia',
      slug: 'hylo-dual-collirio',
      snippet:
          'Scheda sintetica per Hylo Dual collirio. Prodotto oftalmico lubrificante; verificare sempre istruzioni e periodo di utilizzo dopo apertura.',
    );
    addCurated(
      normalized.contains('hylo') && normalized.contains('fresh'),
      name: 'Hylo Fresh collirio',
      category: 'Dispositivo oftalmico / prodotto da farmacia',
      slug: 'hylo-fresh-collirio',
      snippet:
          'Scheda sintetica per Hylo Fresh collirio. Prodotto oftalmico lubrificante; verificare sempre istruzioni e periodo di utilizzo dopo apertura.',
    );
    addCurated(
      normalized.contains('apropos') &&
          normalized.contains('spray') &&
          normalized.contains('gola'),
      name: 'Apropos spray gola',
      category: 'Prodotto gola / prodotto da farmacia',
      slug: 'apropos-spray-gola',
      snippet:
          'Scheda sintetica per Apropos spray gola. Prodotto per il benessere della gola; verificare sempre composizione e modalità d’uso sulla confezione.',
    );
    addCurated(
      normalized.contains('apropos') && normalized.contains('caramelle'),
      name: 'Apropos caramelle',
      category: 'Prodotto gola / prodotto da farmacia',
      slug: 'apropos-caramelle',
      snippet:
          'Scheda sintetica per Apropos caramelle. Caramelle/pastiglie della linea Apropos; verificare sempre ingredienti, allergeni e modalità d’uso.',
    );
    addCurated(
      normalized.contains('ribolio') && normalized.contains('gola'),
      name: 'Ribolio spray gola',
      category: 'Prodotto gola / prodotto da farmacia',
      slug: 'ribolio-spray-gola',
      snippet:
          'Scheda sintetica per Ribolio spray gola. Prodotto per il benessere della gola; verificare sempre composizione e modalità d’uso sulla confezione.',
    );
    addCurated(
      normalized.contains('propoli') && normalized.contains('evsp'),
      name: 'Propoli EVSP spray',
      category: 'Prodotto gola / prodotto da farmacia',
      slug: 'propoli-evsp-spray',
      snippet:
          'Scheda sintetica per Propoli EVSP spray. Spray a base di propoli; verificare sempre ingredienti, allergeni e modalità d’uso sulla confezione.',
    );
    addCurated(
      normalized.contains('tonimer') && normalized.contains('normal'),
      name: 'Tonimer Normal spray',
      category: 'Dispositivo nasale / prodotto da farmacia',
      slug: 'tonimer-normal-spray',
      snippet:
          'Scheda sintetica per Tonimer Normal spray. Spray nasale della linea Tonimer; verificare sempre istruzioni e frequenza d’uso sulla confezione.',
    );
    addCurated(
      normalized.contains('isomar') && normalized.contains('occhi'),
      name: 'Isomar Occhi',
      category: 'Dispositivo oftalmico / prodotto da farmacia',
      slug: 'isomar-occhi',
      snippet:
          'Scheda sintetica per Isomar Occhi. Prodotto oftalmico; verificare sempre istruzioni, sterilità e periodo di utilizzo dopo apertura.',
    );
    addCurated(
      normalized.contains('ialumar') && normalized.contains('baby'),
      name: 'Ialumar Baby',
      category: 'Dispositivo nasale / prodotto da farmacia',
      slug: 'ialumar-baby',
      snippet:
          'Scheda sintetica per Ialumar Baby. Prodotto nasale pediatrico della linea Ialumar; verificare sempre età d’uso e istruzioni sulla confezione.',
    );
    addCurated(
      normalized.contains('floradix') && normalized.contains('magnesio'),
      name: 'Floradix Magnesio',
      category: 'Integratore / prodotto da farmacia',
      slug: 'floradix-magnesio',
      snippet:
          'Scheda sintetica per Floradix Magnesio. Integratore con magnesio; verificare sempre dose giornaliera e avvertenze sulla confezione.',
    );
    addCurated(
      normalized.contains('longlife') && normalized.contains('magnesio'),
      name: 'LongLife Magnesio',
      category: 'Integratore / prodotto da farmacia',
      slug: 'longlife-magnesio',
      snippet:
          'Scheda sintetica per LongLife Magnesio. Integratore con magnesio; verificare sempre forma specifica, dose giornaliera e avvertenze sulla confezione.',
    );

    addCurated(
      normalized.contains('aboca') &&
          normalized.contains('immunomix') &&
          normalized.contains('difesa'),
      name: 'Aboca Immunomix Difesa',
      category: 'Integratore / prodotto da farmacia',
      slug: 'aboca-immunomix-difesa',
      snippet:
          'Scheda sintetica per Aboca Immunomix Difesa. Integratore della linea Immunomix per il supporto delle difese dell’organismo; verificare sempre istruzioni ufficiali.',
    );

    addCurated(
      normalized.contains('neobianacid') && normalized.contains('reflusso'),
      name: 'NeoBianacid Reflusso',
      category: 'Dispositivo gastrointestinale / prodotto da farmacia',
      slug: 'neobianacid-reflusso',
      snippet:
          'Scheda sintetica per NeoBianacid Reflusso. Prodotto della linea NeoBianacid per disturbi correlati ad acidità e reflusso; verificare sempre istruzioni, dosaggio e avvertenze sulla confezione ufficiale.',
    );
    addCurated(
      normalized.contains('neobianacid'),
      name: 'NeoBianacid',
      category: 'Dispositivo gastrointestinale / prodotto da farmacia',
      slug: 'neobianacid',
      snippet:
          'Scheda sintetica per NeoBianacid. Prodotto della linea Aboca NeoBianacid per disturbi correlati ad acidità e reflusso; verificare sempre istruzioni, dosaggio e avvertenze sulla confezione ufficiale.',
    );

    addIf(
        normalized.contains('ematonil'),
        const ParafarmacoSearchResult(
          name: 'Ematonil Plus Emulsione',
          category: 'Parafarmaco / prodotto da farmacia',
          sourceName: 'Codifa/Farmadati',
          sourceUrl:
              'https://www.codifa.it/parafarmaci/e/ematonil-plus-emulsione-idratanti-tonificanti-rassodanti-multifunzione-corpo',
          snippet: 'A base di arnica, escina e bromelina.',
          code: 'PARAF/MINSAN 902649298',
        ));

    // Alcuni prodotti non emergono dagli indici pubblici Codifa/Farmadati.
    // In questi casi offriamo un fallback chiaramente indicato come scheda
    // pubblica/sito produttore o scheda pubblica prodotto, senza confonderlo
    // con la ricerca AIFA e senza spacciarlo per fonte Codifa.
    addIf(
        normalized.contains('cicaplast') ||
            (normalized.contains('baume') && normalized.contains('b5')),
        const ParafarmacoSearchResult(
          name: 'Cicaplast Baume B5+',
          category: 'Dermocosmetico / prodotto da farmacia',
          sourceName: 'La Roche-Posay',
          sourceUrl:
              'https://www.larocheposay.it/cicaplast-per-la-pelle-fragilizzata/cicaplast-baume-b5-plus',
          snippet:
              'Balsamo lenitivo ultra-riparatore per pelli irritate o fragilizzate.',
        ));

    addIf(
        normalized.contains('ialumar'),
        const ParafarmacoSearchResult(
          name: 'Ialumar Spray',
          category: 'Dispositivo / prodotto da farmacia',
          sourceName: 'Scheda pubblica prodotto',
          sourceUrl:
              'https://www.farmaciafornari.it/prodotti-uso-umano/293-ialumar-spray-100-ml.html',
          snippet:
              'Soluzione isotonica spray di acqua di mare e acido ialuronico sale sodico.',
          code: '913152397',
        ));

    addIf(
        normalized.contains('vea') && normalized.contains('olio'),
        const ParafarmacoSearchResult(
          name: 'Vea Olio',
          category: 'Dermocosmetico / prodotto da farmacia',
          sourceName: 'Scheda pubblica prodotto',
          sourceUrl: 'https://www.vea.it/prodotti/vea-olio/',
          snippet:
              'Olio dermatologico a base di vitamina E pura, indicato per pelle secca, arrossata o sensibile.',
        ));

    addIf(
        normalized.contains('gse') &&
            (normalized.contains('intimo') || normalized.contains('intima')),
        const ParafarmacoSearchResult(
          name: 'Gse Intimo',
          category: 'Prodotto per igiene intima / prodotto da farmacia',
          sourceName: 'Prodeco Pharma',
          sourceUrl:
              'https://www.prodecopharma.com/prodotto/gse-intimo-detergente/',
          snippet:
              'Detergente intimo della linea GSE pensato per l’igiene e il benessere delle parti intime.',
        ));

    addIf(
        normalized.contains('cicatridina') && normalized.contains('ovuli'),
        const ParafarmacoSearchResult(
          name: 'Cicatridina ovuli',
          category: 'Dispositivo per ginecologia / prodotto da farmacia',
          sourceName: 'Codifa/Farmadati',
          sourceUrl:
              'https://www.codifa.it/parafarmaci/c/cicatridina-dispositivi-per-ginecologia--altri',
          snippet: 'Dispositivo ginecologico della linea Cicatridina.',
        ));

    addIf(
        normalized.contains('cicatridina') && normalized.contains('crema'),
        const ParafarmacoSearchResult(
          name: 'Cicatridina crema',
          category: 'Medicazione per ferite / prodotto da farmacia',
          sourceName: 'Codifa/Farmadati',
          sourceUrl:
              'https://www.codifa.it/parafarmaci/c/cicatridina-medicazioni-per-ferite-piaghe-e-ulcere--altre',
          snippet: 'Prodotto Cicatridina per processi riparativi cutanei.',
        ));

    addIf(
        normalized.contains('rilastil') && normalized.contains('difesa'),
        const ParafarmacoSearchResult(
          name: 'Rilastil Difesa crema',
          category: 'Dermocosmetico / prodotto da farmacia',
          sourceName: 'Rilastil',
          sourceUrl: 'https://www.rilastil.com/it/difesa-crema-sterile/',
          snippet:
              'Crema protettiva della linea Rilastil Difesa per pelle sensibile o reattiva.',
        ));

    addIf(
        normalized.contains('rilastil') && normalized.contains('xerolact'),
        const ParafarmacoSearchResult(
          name: 'Rilastil Xerolact',
          category: 'Dermocosmetico / prodotto da farmacia',
          sourceName: 'Rilastil',
          sourceUrl: 'https://www.rilastil.com/it/xerolact/',
          snippet:
              'Linea Rilastil Xerolact per pelle secca, molto secca o soggetta a xerosi.',
        ));

    addIf(
        normalized.contains('la roche') && normalized.contains('lipikar'),
        const ParafarmacoSearchResult(
          name: 'La Roche-Posay Lipikar',
          category: 'Dermocosmetico / prodotto da farmacia',
          sourceName: 'La Roche-Posay',
          sourceUrl: 'https://www.larocheposay.it/lipikar',
          snippet:
              'Linea Lipikar per pelle secca, sensibile o a tendenza atopica.',
        ));

    addIf(
        normalized.contains('massigen') && normalized.contains('dailyvit'),
        const ParafarmacoSearchResult(
          name: 'Massigen Dailyvit',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Massigen',
          sourceUrl: 'https://www.massigen.it/prodotti/dailyvit/',
          snippet:
              'Integratore multivitaminico e multiminerale della linea Massigen Dailyvit.',
        ));

    addIf(
        normalized.contains('massigen') && normalized.contains('difesa'),
        const ParafarmacoSearchResult(
          name: 'Massigen Pronto Difesa',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Massigen',
          sourceUrl: 'https://www.massigen.it/prodotti/pronto-difesa/',
          snippet:
              'Integratore della linea Massigen Pronto Difesa per il supporto delle difese dell’organismo.',
        ));

    addIf(
        normalized.contains('compeed') &&
            (normalized.contains('vesciche') || normalized.contains('cerotti')),
        const ParafarmacoSearchResult(
          name: 'Compeed Cerotti per Vesciche Medio',
          category: 'Cerotti / prodotto da farmacia',
          sourceName: 'Compeed',
          sourceUrl:
              'https://www.compeed.it/vesciche/prodotti/compeed-cerotti-per-vesciche-medio/',
          snippet:
              'Cerotti idrocolloidali per vesciche, sollievo rapido e protezione dallo sfregamento.',
        ));

    addIf(
        normalized.contains('rinoway'),
        const ParafarmacoSearchResult(
          name: 'Rinoway Doccia per irrigazione nasale',
          category: 'Dispositivo medico / prodotto da farmacia',
          sourceName: 'Envicon Medical',
          sourceUrl:
              'https://www.envicon.it/shop/lavaggi-nasali/rinoway-doccia-per-irrigazione-nasale/',
          snippet:
              'Doccia per irrigazione nasale utile per lavaggi delle cavità nasali.',
        ));

    addIf(
        normalized.contains('libenar'),
        const ParafarmacoSearchResult(
          name: 'Libenar Soluzione Fisiologica',
          category: 'Dispositivo / prodotto da farmacia',
          sourceName: 'Libenar',
          sourceUrl: 'https://www.libenar.it/soluzione-fisiologica',
          snippet: 'Soluzione salina sterile isotonica in flaconcini monodose.',
        ));

    addIf(
        normalized.contains('gengigel'),
        const ParafarmacoSearchResult(
          name: 'Gengigel Gel Gengivale',
          category: 'Dispositivo medico / prodotto da farmacia',
          sourceName: 'Ricerfarma / Gengigel',
          sourceUrl:
              'https://www.ricerfarma.com/oral-care/gengigel-line/gengigel-gel/',
          snippet:
              'Gel con acido ialuronico 0,2% per gengive sensibili, irritate o traumatizzate.',
        ));

    addIf(
        normalized.contains('physiomer'),
        const ParafarmacoSearchResult(
          name: 'Physiomer Getto Normale Spray Nasale',
          category: 'Dispositivo medico / prodotto da farmacia',
          sourceName: 'Physiomer',
          sourceUrl: 'https://www.physiomer.it/physiomer-getto-normale',
          snippet:
              'Spray nasale con siero di mare per detersione quotidiana e comfort respiratorio.',
        ));

    addIf(
        normalized.contains('fluimare') || normalized.contains('fluimar'),
        const ParafarmacoSearchResult(
          name: 'Fluimar Spray',
          category: 'Dispositivo / prodotto da farmacia',
          sourceName: 'Chemist Research',
          sourceUrl: 'https://www.chemistresearch.it/prodotto/fluimar-spray/',
          snippet:
              'Soluzione isotonica nasale di acqua di mare per detergere e idratare il naso.',
        ));

    addIf(
        normalized.contains('avene') && normalized.contains('cicalfate'),
        const ParafarmacoSearchResult(
          name: 'Avène Cicalfate+ Crema Ristrutturante Protettiva',
          category: 'Dermocosmetico / prodotto da farmacia',
          sourceName: 'Eau Thermale Avène',
          sourceUrl:
              'https://www.avene.it/p/cicalfate-crema-ristrutturante-protettiva-3282770204681-30bef97c',
          snippet:
              'Crema ristrutturante protettiva per pelle sensibile fragilizzata.',
        ));

    addIf(
        normalized.contains('bioscalin'),
        const ParafarmacoSearchResult(
          name: 'Bioscalin Total Care Integratore',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Bioscalin Giuliani',
          sourceUrl: 'https://www.bioscalin.it/collections/linea-total-care',
          snippet:
              'Linea con integratori e trattamenti per capelli indeboliti e soggetti a caduta temporanea.',
        ));

    addIf(
        normalized.contains('solgar') &&
            (normalized.contains('vitamina') || normalized.contains('ester')),
        const ParafarmacoSearchResult(
          name: 'Solgar Ester-C Plus 1000',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Solgar Italia',
          sourceUrl: 'https://www.solgar.it/immunity/',
          snippet:
              'Integratore a base di vitamina C Ester-C con rosa canina, acerola, bioflavonoidi e rutina.',
        ));

    addIf(
        normalized.contains('immunomix'),
        const ParafarmacoSearchResult(
          name: 'ImmunoMix Plus Opercoli',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Aboca',
          sourceUrl: 'https://www.aboca.com/product/immunomix-plus-capsules/',
          snippet:
              'Integratore naturale Aboca per coadiuvare le naturali difese dell’organismo.',
        ));

    addIf(
        normalized.contains('lenodiar'),
        const ParafarmacoSearchResult(
          name: 'LenoDiar Adulti',
          category: 'Dispositivo medico / prodotto da farmacia',
          sourceName: 'Aboca',
          sourceUrl: 'https://www.aboca.com/it/prodotto/lenodiar-adulti/',
          snippet:
              'Prodotto indicato per il trattamento della diarrea acuta e delle riacutizzazioni della diarrea cronica.',
        ));

    addIf(
        normalized.contains('golamir'),
        const ParafarmacoSearchResult(
          name: 'Golamir 2Act Spray Forte',
          category: 'Dispositivo medico / prodotto da farmacia',
          sourceName: 'Aboca',
          sourceUrl: 'https://www.aboca.com/it/prodotto/golamir-spray/',
          snippet:
              'Prodotto per il trattamento degli stati irritativi e infiammatori del cavo orofaringeo.',
        ));

    addIf(
        normalized.contains('curasept') && normalized.contains('collutorio'),
        const ParafarmacoSearchResult(
          name: 'Curasept Collutorio',
          category: 'Igiene orale / prodotto da farmacia',
          sourceName: 'Curasept',
          sourceUrl: 'https://curaseptspa.it/prodotti/collutori/',
          snippet:
              'Linea di collutori Curasept per igiene orale, protezione e mantenimento della salute gengivale.',
        ));

    addIf(
        normalized.contains('optrex') && normalized.contains('actimist'),
        const ParafarmacoSearchResult(
          name: 'Optrex ActiMist Spray 2 in 1',
          category: 'Dispositivo / prodotto oftalmico',
          sourceName: 'Scheda pubblica prodotto',
          sourceUrl: 'https://www.drmax.it/optrex',
          snippet:
              'Spray 2 in 1 ad azione lubrificante e reidratante per occhi secchi, stanchi o irritati.',
        ));

    addIf(
        normalized.contains('redoxon'),
        const ParafarmacoSearchResult(
          name: 'Redoxon Doppia Azione',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Scheda pubblica prodotto',
          sourceUrl: 'https://farmaciadelcorso.net/redoxon-15-cpr-effarancmand',
          snippet:
              'Integratore alimentare a base di vitamina C e zinco in compresse effervescenti.',
        ));

    addIf(
        normalized.contains('drenax'),
        const ParafarmacoSearchResult(
          name: 'Drenax Forte',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Drenax',
          sourceUrl: 'https://drenax.it/prodotti/',
          snippet:
              'Linea di integratori alimentari per controllo del peso corporeo e ritenzione idrica.',
        ));

    addIf(
        normalized.contains('hoffmann'),
        const ParafarmacoSearchResult(
          name: 'Pasta Hoffmann',
          category: 'Dermocosmetico / prodotto da farmacia',
          sourceName: 'Euphidra',
          sourceUrl: 'https://www.euphidra.com/prodotto/pasta-hoffmann-0',
          snippet:
              'Pasta con ossido di zinco, olio di oliva e olio di riso per irritazioni e fenomeni macerativi.',
        ));

    addIf(
        normalized.contains('vizik'),
        const ParafarmacoSearchResult(
          name: 'Vizik Collirio',
          category: 'Dispositivo / prodotto oftalmico',
          sourceName: 'Scheda pubblica prodotto',
          sourceUrl:
              'https://liki24.it/p/vizik-collirio-per-occhi-irritati-e-arrossati-10-ml-zdrovit/',
          snippet:
              'Collirio lubrificante, lenitivo e idratante per occhi irritati e arrossati.',
        ));

    addIf(
        normalized.contains('ribolio'),
        const ParafarmacoSearchResult(
          name: 'Ribolio Integratore',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Scheda pubblica prodotto',
          sourceUrl:
              'https://www.farmacosmo.it/integratori/ribolio-50-capsule-integratore-benessere-dell-organismo-144162/',
          snippet:
              'Complemento alimentare a base di olio di semi di ribes nero, ricco di acidi grassi omega-3 e omega-6.',
        ));

    addIf(
        normalized.contains('noremifa'),
        const ParafarmacoSearchResult(
          name: 'Noremifa',
          category: 'Dispositivo medico / prodotto da farmacia',
          sourceName: 'Scheda pubblica prodotto',
          sourceUrl: 'https://www.drmax.it/noremifa-25bust-20ml',
          snippet:
              'Dispositivo medico indicato in caso di reflusso gastroesofageo e disturbi correlati.',
        ));

    addIf(
        normalized.contains('viviscal'),
        const ParafarmacoSearchResult(
          name: 'Viviscal',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Viviscal Italia',
          sourceUrl: 'https://www.viviscalitalia.it/',
          snippet:
              'Integratori e prodotti per capelli fini, fragili o soggetti a caduta temporanea.',
        ));

    addIf(
        normalized.contains('doppelherz') && normalized.contains('omega'),
        const ParafarmacoSearchResult(
          name: 'Doppelherz Omega-3 1400',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Doppelherz',
          sourceUrl:
              'https://www.doppelherz.it/prodotti/doppelherz-aktiv-omega-3-1400',
          snippet:
              'Integratore con acidi grassi omega-3 EPA e DHA da olio di pesce concentrato.',
        ));

    addIf(
        normalized.contains('zincovit'),
        const ParafarmacoSearchResult(
          name: 'Zincovit C',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'HealthAid Italia',
          sourceUrl:
              'https://www.healthaiditalia.it/integratori/zincovit-cr-blister-60-s',
          snippet:
              'Integratore con zinco, vitamina C e propoli per il sistema immunitario.',
        ));

    addIf(
        normalized.contains('dermovitamina') && normalized.contains('ragadi'),
        const ParafarmacoSearchResult(
          name: 'Dermovitamina Ragadi Gel Mani-Piedi',
          category: 'Dermocosmetico / prodotto da farmacia',
          sourceName: 'Dermovitamina',
          sourceUrl:
              'https://www.dermovitamina.it/prodotto/ragadi-gel-mani-piedi-filmante-protettivo/',
          snippet:
              'Gel filmante protettivo indicato per ragadi, screpolature, fissurazioni e piccoli tagli.',
        ));

    addIf(
        normalized.contains('bioscalin') && normalized.contains('energy'),
        const ParafarmacoSearchResult(
          name: 'Bioscalin Energy',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Bioscalin Giuliani',
          sourceUrl: 'https://www.bioscalin.it/',
          snippet:
              'Linea Bioscalin per il benessere dei capelli fragili o soggetti a caduta temporanea.',
        ));

    addIf(
        normalized.contains('bioscalin') && normalized.contains('tricoage'),
        const ParafarmacoSearchResult(
          name: 'Bioscalin TricoAge',
          category: 'Integratore / prodotto da farmacia',
          sourceName: 'Bioscalin Giuliani',
          sourceUrl: 'https://www.bioscalin.it/',
          snippet:
              'Linea Bioscalin per capelli assottigliati, fragili o soggetti a caduta.',
        ));

    return results;
  }

  String _decodeResponse(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return latin1.decode(response.bodyBytes);
    }
  }

  bool _isCodifaProductHref(String href) {
    final url = _absoluteCodifaUrl(href);
    final uri = Uri.tryParse(url);
    if (uri == null || !_isSupportedCodifaHost(uri.host)) return false;
    final segments = uri.pathSegments.map((s) => s.toLowerCase()).toList();
    if (segments.length < 3) return false;
    return segments.first == 'parafarmaci' ||
        segments.first == 'integratori' ||
        segments.first == 'farmaci';
  }

  bool _isSupportedCodifaHost(String rawHost) {
    final host = rawHost.toLowerCase();
    return host == 'codifa.it' ||
        host == 'www.codifa.it' ||
        host == 'codifa-legacy.farmadati.it';
  }

  String _absoluteCodifaUrl(String href) {
    final trimmed = href.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && _isSupportedCodifaHost(uri.host)) {
        // Alcuni href legacy sono ancora scritti in HTTP. Il medesimo host
        // espone HTTPS: lo canonicalizziamo per non introdurre clear-text.
        return uri.replace(scheme: 'https').toString();
      }
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      final uri = Uri.tryParse('https:$trimmed');
      if (uri != null && _isSupportedCodifaHost(uri.host)) {
        return uri.replace(scheme: 'https').toString();
      }
      return 'https:$trimmed';
    }
    if (trimmed.startsWith('/')) return '$_legacyCodifaBase$trimmed';
    return '$_legacyCodifaBase/$trimmed';
  }

  String _categoryFromCodifaUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/farmaci/')) return 'Medicinale / scheda Codifa';
    if (lower.contains('/integratori/')) return 'Integratore';
    if (lower.contains('/dispositivi/')) return 'Dispositivo medico';
    return 'Parafarmaco / prodotto da farmacia';
  }

  String _nameFromCodifaUrl(String url) {
    final uri = Uri.parse(url);
    final last = uri.pathSegments.isEmpty ? url : uri.pathSegments.last;
    final stopWords = <String>{
      'integratori',
      'parafarmaci',
      'farmaci',
      'prodotti',
      'prodotto',
      'corpo',
      'viso',
      'minerali',
      'vitamine',
    };
    final words = last
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((part) =>
            part.isNotEmpty && !stopWords.contains(part.toLowerCase()))
        .take(8)
        .map((part) =>
            '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}')
        .toList();
    return words.join(' ').trim();
  }

  String _extractTitle(dom.Document document, {required String fallback}) {
    final candidates = <String?>[
      document.querySelector('h1')?.text,
      document
          .querySelector('meta[property="og:title"]')
          ?.attributes['content'],
      document.querySelector('title')?.text,
      fallback,
    ];
    for (final candidate in candidates) {
      final cleaned = _cleanText(candidate ?? '');
      if (cleaned.isEmpty) continue;
      final normalized = _normalize(cleaned);
      if (normalized.contains('indice dei') &&
          normalized.contains('ordine alfabetico')) {
        continue;
      }
      if (normalized == 'farmaci' ||
          normalized == 'parafarmaci' ||
          normalized == 'integratori') {
        continue;
      }
      return _cleanTitle(cleaned);
    }
    return fallback;
  }

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\s*-\s*Codifa.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\|\s*Codifa.*$', caseSensitive: false), '')
        .trim();
  }

  String? _extractCode(dom.Document document) {
    final text = _cleanText(_bestBodyText(document));
    final patterns = <RegExp>[
      RegExp(r'\bMINSAN\s*[:\-]?\s*(\d{6,12})\b', caseSensitive: false),
      RegExp(r'\bPARAF\s*[:\-]?\s*(\d{6,12})\b', caseSensitive: false),
      RegExp(r'\bCodice\s+(?:prodotto|articolo)\s*[:\-]?\s*([A-Z0-9]{4,20})\b',
          caseSensitive: false),
      RegExp(r'\bEAN\s*[:\-]?\s*(\d{8,14})\b', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(0);
    }
    return null;
  }

  Map<ParafarmacoSectionType, String> _extractSections(
      dom.Document document, String fullText) {
    final sections = <ParafarmacoSectionType, String>{};

    final headingTags = document.querySelectorAll('h1,h2,h3,h4,strong,b');
    for (final heading in headingTags) {
      final label = _cleanText(heading.text);
      if (label.length < 3 || label.length > 90) continue;
      final type = _sectionTypeFromHeading(label);
      if (type == null || type == ParafarmacoSectionType.complete) continue;

      final text = _collectTextAfterHeading(heading);
      if (_isUsefulSectionTextForType(text, type)) {
        sections[type] = text.trim();
      }
    }

    for (final type in ParafarmacoSectionType.values) {
      if (type == ParafarmacoSectionType.complete ||
          (sections[type]?.trim().isNotEmpty ?? false)) {
        continue;
      }
      final extracted = _extractSectionFromPlainText(fullText, type);
      if (extracted != null && _isUsefulSectionTextForType(extracted, type)) {
        sections[type] = extracted.trim();
      }
    }

    return sections;
  }

  bool _isUsefulSectionText(String text) {
    final cleaned = _cleanText(text);
    if (cleaned.length < 40) return false;
    final normalized = _normalize(cleaned);
    if (normalized == 'componenti e' || normalized == 'e ingredienti') {
      return false;
    }
    return true;
  }

  bool _isUsefulSectionTextForType(
    String text,
    ParafarmacoSectionType type,
  ) {
    if (!_isUsefulSectionText(text)) return false;
    final normalized = _normalize(text);

    if (type == ParafarmacoSectionType.indications &&
        _startsWithAny(normalized, const [
          'quando non dev essere usato',
          'quando non devessere usato',
          'quando non deve essere usato',
          'controindicazioni',
          'ipersensibilita',
          'avvertenze',
          'precauzioni',
          'effetti indesiderati',
          'effetti collaterali',
        ])) {
      return false;
    }

    if (type == ParafarmacoSectionType.composition &&
        (_startsWithAny(normalized, const [
              'vedi lista ingredienti',
              'contenitore sottopressione',
              'durante la gravidanza',
              'gravidanza',
              'allattamento',
              'fertilita',
              'effetti sulla capacita',
              'a cosa serve',
              'indicazioni',
              'modalita d uso',
              'modalita duso',
              'descrizione',
              'avvertenze',
              'precauzioni',
              'non utilizzare',
              'tenere il prodotto',
              'tenere lontano',
            ]) ||
            _containsAny(normalized, const [
              'durante la gravidanza',
              'durante l allattamento',
              'non deve essere utilizzato durante l allattamento',
              'capacita di guidare',
              'contenitore sottopressione',
            ]))) {
      return false;
    }

    return true;
  }

  ParafarmacoSectionType? _sectionTypeFromHeading(String raw) {
    final text = _normalize(raw);
    if (_containsAny(text, const [
      'avvertenze',
      'controindicazioni',
      'quando non dev essere usato',
      'quando non devessere usato',
      'quando non deve essere usato',
      'ipersensibilita',
      'precauzioni',
      'effetti collaterali',
      'effetti indesiderati',
    ])) {
      return ParafarmacoSectionType.warnings;
    }
    if (_containsAny(text, const [
      'indicazioni',
      'a cosa serve',
      'descrizione',
      'che cos e',
      'che cosè',
    ])) {
      return ParafarmacoSectionType.indications;
    }
    if (_containsAny(text, const [
      'modalita d uso',
      'modalita duso',
      'come si usa',
      'come usare',
      'uso',
      'posologia',
      'modo d uso',
      'modo duso',
    ])) {
      return ParafarmacoSectionType.usage;
    }
    if (_containsAny(text, const [
      'componenti',
      'composizione',
      'ingredienti',
      'inci',
    ])) {
      return ParafarmacoSectionType.composition;
    }
    return null;
  }

  String _collectTextAfterHeading(dom.Element heading) {
    final parts = <String>[];
    var sibling = heading.nextElementSibling;
    var guard = 0;
    while (sibling != null && guard < 16) {
      guard += 1;
      final tag = sibling.localName?.toLowerCase() ?? '';
      if (const {'h1', 'h2', 'h3', 'h4'}.contains(tag)) break;
      final text = _cleanText(sibling.text);
      if (text.isNotEmpty) parts.add(text);
      sibling = sibling.nextElementSibling;
    }
    return _cleanText(parts.join('\n\n'));
  }

  String? _extractSectionFromPlainText(
      String text, ParafarmacoSectionType type) {
    final labels = switch (type) {
      ParafarmacoSectionType.indications => const [
          'Perché si usa',
          'Perche si usa',
          'A cosa serve',
          'Indicazioni',
          'Descrizione e caratteristiche',
          'Descrizione',
          'Che cos’è',
          'Che cos\'è',
        ],
      ParafarmacoSectionType.usage => const [
          'Modalità d\'uso',
          'Modalità d’uso',
          'Come si usa',
          'Come si utilizza',
          'Posologia',
          'Modo d\'uso',
          'Modo d’uso',
        ],
      ParafarmacoSectionType.warnings => const [
          'Avvertenze',
          'Controindicazioni',
          'Precauzioni',
          'Effetti collaterali',
          'Effetti indesiderati',
        ],
      ParafarmacoSectionType.composition => const [
          'Componenti e ingredienti',
          'Elenco degli eccipienti',
          'Principio attivo',
          'Componenti',
          'Composizione',
          'Ingredienti',
          'INCI',
          'Allergeni',
        ],
      ParafarmacoSectionType.complete => const <String>[],
    };
    final stopLabels = const [
      'Perché si usa',
      'Perche si usa',
      'A cosa serve',
      'Indicazioni',
      'Descrizione e caratteristiche',
      'Descrizione',
      'Che cos’è',
      'Che cos\'è',
      'Modalità d\'uso',
      'Modalità d’uso',
      'Come si usa',
      'Come si utilizza',
      'Posologia',
      'Modo d\'uso',
      'Modo d’uso',
      'Avvertenze speciali e precauzioni di impiego',
      'Avvertenze',
      "Quando non dev'essere usato",
      'Quando non dev’essere usato',
      'Controindicazioni',
      'Precauzioni',
      'Effetti collaterali',
      'Effetti indesiderati',
      'Interazioni con altri medicinali',
      'Fertilità, gravidanza e allattamento',
      'Effetti sulla capacità di guidare',
      'Sovradosaggio',
      'Scadenza',
      'Elenco degli eccipienti',
      'Componenti e ingredienti',
      'Principio attivo',
      'Componenti',
      'Composizione',
      'Ingredienti',
      'INCI',
      'Allergeni',
      'Formato',
      'Conservazione',
      'Produttore',
      'Recensioni',
      'Confezioni',
      'Data di immissione in commercio',
      'Fonte',
      'URL',
    ];

    final lower = text.toLowerCase();
    String? best;
    var bestLength = 0;

    final orderedLabels = [...labels]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final label in orderedLabels) {
      var searchFrom = 0;
      final labelLower = label.toLowerCase();
      while (searchFrom < lower.length) {
        final start = _indexOfSectionLabel(lower, labelLower, searchFrom);
        if (start < 0) break;
        searchFrom = start + labelLower.length;

        final contentStart = start + label.length;
        var end = text.length;
        for (final stopLabel in stopLabels) {
          if (stopLabel.toLowerCase() == labelLower) continue;
          final index = _indexOfSectionLabel(
            lower,
            stopLabel.toLowerCase(),
            contentStart + 8,
          );
          if (index > contentStart && index < end) end = index;
        }

        final candidate = _cleanupExtractedSection(
          _cleanText(text.substring(contentStart, end)),
          type,
        );
        if (!_isUsefulSectionTextForType(candidate, type)) continue;

        // Le prime occorrenze su Codifa spesso sono solo il menu: "A cosa serve
        // Confezioni Indicazioni...". Scorriamo tutte le occorrenze e teniamo
        // quella con più testo utile.
        if (candidate.length > bestLength) {
          best = candidate;
          bestLength = candidate.length;
        }
      }
    }
    return best;
  }

  int _indexOfSectionLabel(String text, String label, int start) {
    var searchFrom = start;
    while (searchFrom < text.length) {
      final index = text.indexOf(label, searchFrom);
      if (index < 0) return -1;
      if (_hasSectionLabelBoundary(text, index, label.length)) {
        return index;
      }
      searchFrom = index + label.length;
    }
    return -1;
  }

  bool _hasSectionLabelBoundary(String text, int start, int length) {
    final before = start == 0 ? '' : text[start - 1];
    final afterIndex = start + length;
    final after = afterIndex >= text.length ? '' : text[afterIndex];
    return !_isAsciiLetterOrDigit(before) && !_isAsciiLetterOrDigit(after);
  }

  bool _isAsciiLetterOrDigit(String value) {
    if (value.isEmpty) return false;
    final code = value.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122);
  }

  String _cleanupExtractedSection(
    String text,
    ParafarmacoSectionType type,
  ) {
    var cleaned = _cleanText(text)
        .replaceFirst(RegExp(r'^(\?|:|;|,|\.)\s*'), '')
        .replaceFirst(
            RegExp(r'^(e caratteristiche|e ingredienti|pio attivo)\s+',
                caseSensitive: false),
            '')
        .replaceFirst(
            RegExp(r'^(ingredienti|componenti)\s*[:\-]?\s*',
                caseSensitive: false),
            '');
    if (type == ParafarmacoSectionType.indications) {
      cleaned = cleaned.replaceFirst(
        RegExp(r'^(e caratteristiche)\s+', caseSensitive: false),
        '',
      );
    }
    if (type == ParafarmacoSectionType.composition) {
      cleaned = cleaned.replaceFirst(
        RegExp(r'^(principio attivo|pio attivo)\s+', caseSensitive: false),
        '',
      );
    }
    return _cleanText(cleaned);
  }

  String _buildCompleteText({
    required String name,
    required String category,
    required String sourceName,
    required String sourceUrl,
    required String? code,
    required String fullText,
  }) {
    final isCodifa = sourceName == 'Codifa/Farmadati';
    final buffer = StringBuffer()
      ..writeln(name)
      ..writeln(category);
    if (!isCodifa) {
      buffer.writeln('Fonte: $sourceName');
    }
    if (code != null && code.trim().isNotEmpty) buffer.writeln('Codice: $code');
    buffer
      ..writeln()
      ..writeln(_removeLeadingSectionIndex(fullText));
    return buffer.toString().trim();
  }

  String _removeLeadingSectionIndex(String fullText) {
    final lines = fullText
        .split('\n')
        .map(_cleanText)
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 6) return fullText;

    final scanLimit = lines.length < 80 ? lines.length : 80;
    for (var start = 0; start < scanLimit; start += 1) {
      if (!_isSectionIndexLine(lines[start])) continue;

      var end = start;
      while (end < lines.length && _isSectionIndexLine(lines[end])) {
        end += 1;
      }

      if (end - start < 3) continue;

      final removeEnd =
          _isRepeatedFirstSectionTitle(lines[start], lines[end - 1])
              ? end - 1
              : end;
      if (removeEnd - start < 3) continue;

      final removeFrom = start > 0 && _isSectionIndexPrefix(lines[start - 1])
          ? start - 1
          : start;
      return [
        ...lines.take(removeFrom),
        ...lines.skip(removeEnd),
      ].join('\n\n');
    }

    return fullText;
  }

  bool _isSectionIndexPrefix(String line) {
    final normalized = _normalize(line);
    return normalized == 'para';
  }

  bool _isRepeatedFirstSectionTitle(String first, String last) {
    final normalizedFirst = _normalize(first);
    final normalizedLast = _normalize(last);
    if (normalizedFirst == normalizedLast) return true;
    return normalizedFirst.startsWith('cos e ') &&
        normalizedLast.startsWith('cos e ');
  }

  bool _isSectionIndexLine(String line) {
    final normalized = _normalize(line);
    if (normalized.startsWith('cos e ') || normalized.startsWith('cos e?')) {
      return true;
    }
    return const {
      'a cosa serve',
      'confezioni',
      'indicazioni',
      'posologia',
      'controindicazioni',
      'avvertenze',
      'avvertenze speciali e precauzioni di impiego',
      'interazioni con altri medicinali',
      'interazioni con altri medicinali e altre forme di interazione',
      'fertilita gravidanza e allattamento',
      'effetti sulla capacita di guidare',
      'effetti sulla capacita di guidare veicoli e sull uso di macchinari',
      'effetti indesiderati',
      'effetti collaterali',
      'sovradosaggio',
      'scadenza',
      'conservazione',
      'elenco degli eccipienti',
      'modalita d uso',
      'modalita duso',
      'descrizione e caratteristiche',
      'componenti e ingredienti',
      'componenti',
      'composizione',
      'ingredienti',
    }.contains(normalized);
  }

  String _bestBodyText(dom.Document document) {
    final candidates = <dom.Element?>[
      document.querySelector('main'),
      document.querySelector('article'),
      document.querySelector('[role="main"]'),
      document.body,
    ];
    for (final candidate in candidates) {
      final text = _cleanText(candidate?.text ?? '');
      if (text.length >= 200) return text;
    }
    return _cleanText(document.body?.text ?? document.text ?? '');
  }

  void _removeNoise(dom.Document document) {
    for (final selector in const [
      'script',
      'style',
      'noscript',
      'svg',
      'img',
      'picture',
      'form',
      'button',
      'nav',
      'footer',
      'header',
      '.advertisement',
      '.ads',
      '.cookie',
      '.modal',
      '.breadcrumb',
      '.breadcrumbs',
      '.navbar',
      '.menu',
      '.social',
    ]) {
      document.querySelectorAll(selector).forEach((e) => e.remove());
    }
  }

  bool _containsAny(String text, List<String> needles) =>
      needles.any((needle) => text.contains(needle));

  bool _startsWithAny(String text, List<String> prefixes) =>
      prefixes.any((prefix) => text.startsWith(prefix));

  int _resultScore(ParafarmacoSearchResult result, String query) {
    final q = _normalize(query);
    final name = _normalize(result.name);
    final url = _normalize(result.sourceUrl);
    final snippet = _normalize(result.snippet ?? '');
    final haystack = '$name $url $snippet';
    final nameUrl = '$name $url';
    final meaningfulTokens = _meaningfulSearchTokens(query);
    final rawTokens = _searchTokens(query);
    final compactName = name.replaceAll(' ', '');
    final compactMeaningful = meaningfulTokens.join();
    final compactRaw = rawTokens.join();

    var score = 0;
    if (result.sourceUrl.startsWith('sonarpad://')) score += 120;
    if (name == q) score += 180;
    if (name.startsWith(q)) score += 130;
    if (name.contains(q)) score += 90;
    if (compactRaw.isNotEmpty && compactName == compactRaw) score += 170;
    if (compactRaw.isNotEmpty && compactName.startsWith(compactRaw)) {
      score += 120;
    }
    if (compactMeaningful.isNotEmpty && compactName == compactMeaningful) {
      score += 140;
    }
    if (compactMeaningful.isNotEmpty &&
        compactName.startsWith(compactMeaningful)) {
      score += 95;
    }
    if (meaningfulTokens.isNotEmpty &&
        name.startsWith(meaningfulTokens.first)) {
      score += 45;
    }

    for (final token in meaningfulTokens) {
      if (name.contains(token)) score += 26;
      if (url.contains(token)) score += 9;
      if (snippet.contains(token)) score += 6;
    }
    for (final token in rawTokens) {
      if (name.contains(token)) score += 15;
      if (url.contains(token)) score += 8;
      if (snippet.contains(token)) score += 5;
    }

    final matchedRaw = rawTokens.where(haystack.contains).length;
    if (rawTokens.isNotEmpty && matchedRaw == rawTokens.length) score += 55;
    if (rawTokens.length >= 2 && matchedRaw <= 1) score -= 35;

    // I termini dopo il marchio spesso descrivono la variante giusta:
    // "intimo", "ovuli", "olio", "difesa", "baby", "tricoage", ecc.
    // Prima il vecchio ordinamento li trattava troppo debolmente e poteva
    // scegliere pagine vicine ma sbagliate, ad esempio Gse Eye Drops per
    // "Gse Intimo" oppure Vea Bucato per "Vea olio".
    final tailTokens = rawTokens.skip(1).toList();
    for (final token in tailTokens) {
      if (name.contains(token)) {
        score += 65;
      } else if (url.contains(token)) {
        score += 45;
      } else if (snippet.contains(token)) {
        score += 6;
        if (!nameUrl.contains(token)) score -= 10;
      } else if (!_veryGenericTailToken(token)) {
        score -= 38;
      }
    }

    score += _specificIntentScore(rawTokens, name, url, snippet);

    if (result.category.toLowerCase().contains('integratore')) score += 3;
    if (result.category.toLowerCase().contains('parafarmaco')) score += 3;
    return score;
  }

  int _specificIntentScore(
    List<String> rawTokens,
    String name,
    String url,
    String snippet,
  ) {
    final haystack = '$name $url $snippet';
    final nameUrl = '$name $url';
    var score = 0;

    bool has(String token) => rawTokens.contains(token);

    if (has('intimo') || has('intima')) {
      if (_containsAny(nameUrl, const [
        'intimo',
        'intima',
        'ginecologia',
        'cosmesi intima',
        'igiene intima'
      ])) {
        score += 110;
      }
      if (_containsAny(nameUrl,
          const ['eye', 'occhi', 'oftalmologia', 'colliri', 'gocce oculari'])) {
        score -= 140;
      }
    }

    if (has('ovuli') || has('ovulo')) {
      if (_containsAny(
          nameUrl, const ['ginecologia', 'vaginale', 'vaginali', 'ovuli'])) {
        score += 120;
      }
      if (_containsAny(
          nameUrl, const ['gastrointestinale', 'supposte', 'rettale'])) {
        score -= 110;
      }
    }

    if (has('olio')) {
      if (_containsAny(nameUrl, const ['olio', 'oil'])) score += 95;
      if (_containsAny(
          nameUrl, const ['bucato', 'detersivo', 'igienici vari'])) {
        score -= 120;
      }
    }

    if (has('difesa') || has('difese')) {
      if (_containsAny(nameUrl, const ['difesa', 'difese', 'defence'])) {
        score += 100;
      }
      if (name.contains('aqua') && !name.contains('difesa')) {
        score -= 55;
      }
    }

    for (final token in const [
      'xerolact',
      'lipikar',
      'dailyvit',
      'tricoage',
      'energy',
      'ragadi',
      'baby',
      'actimist',
      'pronto',
    ]) {
      if (has(token) && nameUrl.contains(token)) score += 90;
    }

    if ((has('collirio') || has('gocce') || has('occhi')) &&
        _containsAny(nameUrl, const [
          'collirio',
          'colliri',
          'gocce',
          'occhi',
          'oftalmologia',
          'oculari'
        ])) {
      score += 70;
    }

    if ((has('nasale') || has('spray')) &&
        _containsAny(nameUrl, const ['nasale', 'naso', 'spray'])) {
      score += 35;
    }

    if (haystack.contains('indice dei parafarmaci in ordine alfabetico')) {
      score -= 160;
    }
    return score;
  }

  bool _veryGenericTailToken(String token) => const {
        'crema',
        'gel',
        'spray',
        'collirio',
        'gocce',
        'pasta',
        'protezione',
        'plus',
        'classico',
        'adulti',
        'adulto',
        'bambini',
        'flaconcini',
        'flaconi',
        'cerotti',
        'vesciche',
        'fascia',
        'doccia',
        'nasale',
        'aerosol',
        'compresse',
        'compressa',
        'capsule',
        'capsula',
        'bustine',
        'bustina',
      }.contains(token);

  List<String> _searchTokens(String raw) => _normalize(raw)
      .split(RegExp(r'\s+'))
      .where((token) => token.length >= 2)
      .toList();

  List<String> _meaningfulSearchTokens(String raw) {
    const generic = {
      'crema',
      'gel',
      'spray',
      'collirio',
      'pasta',
      'protezione',
      'olio',
      'plus',
      'classic',
      'classico',
      'ricarica',
      'adulti',
      'adulto',
      'bambini',
      'flaconcini',
      'flaconi',
      'cerotti',
      'vesciche',
      'fascia',
      'doccia',
      'nasale',
      'aerosol',
      'compresse',
      'compressa',
      'capsule',
      'capsula',
      'bustine',
      'bustina',
    };
    final tokens = _searchTokens(raw);
    final meaningful = tokens.where((t) => !generic.contains(t)).toList();
    return meaningful.isEmpty ? tokens : meaningful;
  }

  String? _snippetFromParent(String parentText, String name) {
    final cleaned = _cleanText(parentText);
    if (cleaned.isEmpty || _normalize(cleaned) == _normalize(name)) return null;
    if (cleaned.length <= 260) return cleaned;
    return '${cleaned.substring(0, 260).trim()}…';
  }

  String _repairMojibake(String raw) {
    if (!raw.contains('Ã') && !raw.contains('Â') && !raw.contains('â')) {
      return raw;
    }
    try {
      return utf8.decode(latin1.encode(raw), allowMalformed: false);
    } catch (_) {
      return raw
          .replaceAll('Ã ', 'à')
          .replaceAll('Ã¡', 'á')
          .replaceAll('Ã¨', 'è')
          .replaceAll('Ã©', 'é')
          .replaceAll('Ã¬', 'ì')
          .replaceAll('Ã²', 'ò')
          .replaceAll('Ã¹', 'ù')
          .replaceAll('Ã‡', 'Ç')
          .replaceAll('Ã§', 'ç')
          .replaceAll('Â°', '°')
          .replaceAll('Â', '')
          .replaceAll('â€™', '’')
          .replaceAll('â€˜', '‘')
          .replaceAll('â€œ', '“')
          .replaceAll('â€�', '”')
          .replaceAll('â€“', '–')
          .replaceAll('â€”', '—')
          .replaceAll('â', '’')
          .replaceAll('â', '‘')
          .replaceAll('â', '“')
          .replaceAll('â', '”')
          .replaceAll('â', '–')
          .replaceAll('â', '—');
    }
  }

  String _safeFileName(String raw) => raw
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _cleanText(String raw) => _repairMojibake(raw)
      .replaceAll('\u00a0', ' ')
      .replaceAll(
          RegExp(
              r'FARMACIINTEGRATORIPRINCIPI ATTIVIVETERINARIALIMENTI VETERINARI',
              caseSensitive: false),
          ' ')
      .replaceAll(
          RegExp(
              r'PARAFARMACIINTEGRATORIPRINCIPI ATTIVIVETERINARIALIMENTI VETERINARI',
              caseSensitive: false),
          ' ')
      .replaceAll(
          RegExp(
              r'FARMACIPARAFARMACIPRINCIPI ATTIVIVETERINARIALIMENTI VETERINARI',
              caseSensitive: false),
          ' ')
      .replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .trim();

  String _normalize(String raw) {
    final lower = raw.toLowerCase();
    const accents = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    var out = lower;
    accents.forEach((from, to) => out = out.replaceAll(from, to));
    return out
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
