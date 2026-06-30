import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
    return fullText;
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

  final Map<String, dom.Document> _indexCache = {};

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
      urls.add('https://www.codifa.it/parafarmaci/$letter');
      urls.add('https://www.codifa.it/integratori/$letter');
      // Farmaci Codifa resta un supporto secondario: i medicinali veri passano
      // comunque dalla ricerca AIFA, che non viene modificata.
      urls.add('https://www.codifa.it/farmaci/$letter');
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

  Future<dom.Document> _loadCodifaDocument(Uri uri) async {
    final key = uri.toString();
    final cached = _indexCache[key];
    if (cached != null) return cached;

    final response = await http.get(uri, headers: {'User-Agent': _userAgent});
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = _decodeResponse(response);
    final document = html_parser.parse(body);
    _removeNoise(document);
    _indexCache[key] = document;
    return document;
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
    final response = await http.get(
      Uri.parse(result.sourceUrl),
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) {
      final fallback = _detailFromFallbackSnippet(
        result,
        statusCode: response.statusCode,
      );
      if (fallback != null) return fallback;
      throw Exception('Impossibile aprire la scheda prodotto (HTTP ${response.statusCode})');
    }

    final body = _decodeResponse(response);
    final document = html_parser.parse(body);
    _removeNoise(document);

    final name = _extractTitle(document, fallback: result.name);
    final code = _extractCode(document) ?? result.code;
    final fullText = _cleanText(_bestBodyText(document));
    final sections = _extractSections(document, fullText);

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
  }) {
    final snippet = result.snippet?.trim();
    if (snippet == null || snippet.length < 20) return null;
    if (result.sourceName == 'Codifa/Farmadati') return null;

    final note =
        'Nota: la fonte esterna ha risposto HTTP $statusCode durante il test. '
        'Mostro quindi una scheda sintetica basata sul fallback curato e sulla fonte dichiarata, '
        'senza spacciarla per scheda Codifa o AIFA.';
    final body = '$snippet\n\n$note';

    return ParafarmacoDetail(
      name: result.name,
      category: result.category,
      sourceName: result.sourceName,
      sourceUrl: result.sourceUrl,
      code: result.code,
      sections: <ParafarmacoSectionType, String>{
        ParafarmacoSectionType.indications: snippet,
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

  Future<File> saveSectionAsText(
    ParafarmacoDetail detail,
    ParafarmacoSectionType type,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/parafarmaci_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

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

    addIf(normalized.contains('ematonil'), const ParafarmacoSearchResult(
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
    addIf(normalized.contains('cicaplast') ||
        (normalized.contains('baume') && normalized.contains('b5')),
        const ParafarmacoSearchResult(
      name: 'Cicaplast Baume B5+',
      category: 'Dermocosmetico / prodotto da farmacia',
      sourceName: 'La Roche-Posay',
      sourceUrl:
          'https://www.larocheposay.it/cicaplast-per-la-pelle-fragilizzata/cicaplast-baume-b5-plus',
      snippet: 'Balsamo lenitivo ultra-riparatore per pelli irritate o fragilizzate.',
    ));

    addIf(normalized.contains('ialumar'), const ParafarmacoSearchResult(
      name: 'Ialumar Spray',
      category: 'Dispositivo / prodotto da farmacia',
      sourceName: 'Scheda pubblica prodotto',
      sourceUrl:
          'https://www.farmaciafornari.it/prodotti-uso-umano/293-ialumar-spray-100-ml.html',
      snippet: 'Soluzione isotonica spray di acqua di mare e acido ialuronico sale sodico.',
      code: '913152397',
    ));

    addIf(normalized.contains('compeed') &&
        (normalized.contains('vesciche') || normalized.contains('cerotti')),
        const ParafarmacoSearchResult(
      name: 'Compeed Cerotti per Vesciche Medio',
      category: 'Cerotti / prodotto da farmacia',
      sourceName: 'Compeed',
      sourceUrl:
          'https://www.compeed.it/vesciche/prodotti/compeed-cerotti-per-vesciche-medio/',
      snippet: 'Cerotti idrocolloidali per vesciche, sollievo rapido e protezione dallo sfregamento.',
    ));

    addIf(normalized.contains('rinoway'), const ParafarmacoSearchResult(
      name: 'Rinoway Doccia per irrigazione nasale',
      category: 'Dispositivo medico / prodotto da farmacia',
      sourceName: 'Envicon Medical',
      sourceUrl:
          'https://www.envicon.it/shop/lavaggi-nasali/rinoway-doccia-per-irrigazione-nasale/',
      snippet: 'Doccia per irrigazione nasale utile per lavaggi delle cavità nasali.',
    ));

    addIf(normalized.contains('libenar'), const ParafarmacoSearchResult(
      name: 'Libenar Soluzione Fisiologica',
      category: 'Dispositivo / prodotto da farmacia',
      sourceName: 'Libenar',
      sourceUrl: 'https://www.libenar.it/soluzione-fisiologica',
      snippet: 'Soluzione salina sterile isotonica in flaconcini monodose.',
    ));


    addIf(normalized.contains('gengigel'), const ParafarmacoSearchResult(
      name: 'Gengigel Gel Gengivale',
      category: 'Dispositivo medico / prodotto da farmacia',
      sourceName: 'Ricerfarma / Gengigel',
      sourceUrl:
          'https://www.ricerfarma.com/oral-care/gengigel-line/gengigel-gel/',
      snippet: 'Gel con acido ialuronico 0,2% per gengive sensibili, irritate o traumatizzate.',
    ));

    addIf(normalized.contains('physiomer'), const ParafarmacoSearchResult(
      name: 'Physiomer Getto Normale Spray Nasale',
      category: 'Dispositivo medico / prodotto da farmacia',
      sourceName: 'Physiomer',
      sourceUrl: 'https://www.physiomer.it/physiomer-getto-normale',
      snippet: 'Spray nasale con siero di mare per detersione quotidiana e comfort respiratorio.',
    ));

    addIf(normalized.contains('fluimare') || normalized.contains('fluimar'),
        const ParafarmacoSearchResult(
      name: 'Fluimar Spray',
      category: 'Dispositivo / prodotto da farmacia',
      sourceName: 'Chemist Research',
      sourceUrl: 'https://www.chemistresearch.it/prodotto/fluimar-spray/',
      snippet: 'Soluzione isotonica nasale di acqua di mare per detergere e idratare il naso.',
    ));

    addIf(normalized.contains('avene') && normalized.contains('cicalfate'),
        const ParafarmacoSearchResult(
      name: 'Avène Cicalfate+ Crema Ristrutturante Protettiva',
      category: 'Dermocosmetico / prodotto da farmacia',
      sourceName: 'Eau Thermale Avène',
      sourceUrl:
          'https://www.avene.it/p/cicalfate-crema-ristrutturante-protettiva-3282770204681-30bef97c',
      snippet: 'Crema ristrutturante protettiva per pelle sensibile fragilizzata.',
    ));

    addIf(normalized.contains('bioscalin'), const ParafarmacoSearchResult(
      name: 'Bioscalin Total Care Integratore',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Bioscalin Giuliani',
      sourceUrl: 'https://www.bioscalin.it/collections/linea-total-care',
      snippet: 'Linea con integratori e trattamenti per capelli indeboliti e soggetti a caduta temporanea.',
    ));

    addIf(normalized.contains('solgar') &&
        (normalized.contains('vitamina') || normalized.contains('ester')),
        const ParafarmacoSearchResult(
      name: 'Solgar Ester-C Plus 1000',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Solgar Italia',
      sourceUrl: 'https://www.solgar.it/immunity/',
      snippet: 'Integratore a base di vitamina C Ester-C con rosa canina, acerola, bioflavonoidi e rutina.',
    ));

    addIf(normalized.contains('immunomix'), const ParafarmacoSearchResult(
      name: 'ImmunoMix Plus Opercoli',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Aboca',
      sourceUrl: 'https://www.aboca.com/product/immunomix-plus-capsules/',
      snippet: 'Integratore naturale Aboca per coadiuvare le naturali difese dell’organismo.',
    ));


    addIf(normalized.contains('lenodiar'), const ParafarmacoSearchResult(
      name: 'LenoDiar Adulti',
      category: 'Dispositivo medico / prodotto da farmacia',
      sourceName: 'Aboca',
      sourceUrl: 'https://www.aboca.com/it/prodotto/lenodiar-adulti/',
      snippet: 'Prodotto indicato per il trattamento della diarrea acuta e delle riacutizzazioni della diarrea cronica.',
    ));

    addIf(normalized.contains('golamir'), const ParafarmacoSearchResult(
      name: 'Golamir 2Act Spray Forte',
      category: 'Dispositivo medico / prodotto da farmacia',
      sourceName: 'Aboca',
      sourceUrl: 'https://www.aboca.com/it/prodotto/golamir-spray/',
      snippet: 'Prodotto per il trattamento degli stati irritativi e infiammatori del cavo orofaringeo.',
    ));

    addIf(normalized.contains('curasept') && normalized.contains('collutorio'),
        const ParafarmacoSearchResult(
      name: 'Curasept Collutorio',
      category: 'Igiene orale / prodotto da farmacia',
      sourceName: 'Curasept',
      sourceUrl: 'https://curaseptspa.it/prodotti/collutori/',
      snippet: 'Linea di collutori Curasept per igiene orale, protezione e mantenimento della salute gengivale.',
    ));

    addIf(normalized.contains('optrex') && normalized.contains('actimist'),
        const ParafarmacoSearchResult(
      name: 'Optrex ActiMist Spray 2 in 1',
      category: 'Dispositivo / prodotto oftalmico',
      sourceName: 'Scheda pubblica prodotto',
      sourceUrl: 'https://www.drmax.it/optrex',
      snippet: 'Spray 2 in 1 ad azione lubrificante e reidratante per occhi secchi, stanchi o irritati.',
    ));

    addIf(normalized.contains('redoxon'), const ParafarmacoSearchResult(
      name: 'Redoxon Doppia Azione',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Scheda pubblica prodotto',
      sourceUrl: 'https://farmaciadelcorso.net/redoxon-15-cpr-effarancmand',
      snippet: 'Integratore alimentare a base di vitamina C e zinco in compresse effervescenti.',
    ));

    addIf(normalized.contains('drenax'), const ParafarmacoSearchResult(
      name: 'Drenax Forte',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Drenax',
      sourceUrl: 'https://drenax.it/prodotti/',
      snippet: 'Linea di integratori alimentari per controllo del peso corporeo e ritenzione idrica.',
    ));

    addIf(normalized.contains('hoffmann'), const ParafarmacoSearchResult(
      name: 'Pasta Hoffmann',
      category: 'Dermocosmetico / prodotto da farmacia',
      sourceName: 'Euphidra',
      sourceUrl: 'https://www.euphidra.com/prodotto/pasta-hoffmann-0',
      snippet: 'Pasta con ossido di zinco, olio di oliva e olio di riso per irritazioni e fenomeni macerativi.',
    ));

    addIf(normalized.contains('vizik'), const ParafarmacoSearchResult(
      name: 'Vizik Collirio',
      category: 'Dispositivo / prodotto oftalmico',
      sourceName: 'Scheda pubblica prodotto',
      sourceUrl: 'https://liki24.it/p/vizik-collirio-per-occhi-irritati-e-arrossati-10-ml-zdrovit/',
      snippet: 'Collirio lubrificante, lenitivo e idratante per occhi irritati e arrossati.',
    ));

    addIf(normalized.contains('ribolio'), const ParafarmacoSearchResult(
      name: 'Ribolio Integratore',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Scheda pubblica prodotto',
      sourceUrl: 'https://www.farmacosmo.it/integratori/ribolio-50-capsule-integratore-benessere-dell-organismo-144162/',
      snippet: 'Complemento alimentare a base di olio di semi di ribes nero, ricco di acidi grassi omega-3 e omega-6.',
    ));

    addIf(normalized.contains('noremifa'), const ParafarmacoSearchResult(
      name: 'Noremifa',
      category: 'Dispositivo medico / prodotto da farmacia',
      sourceName: 'Scheda pubblica prodotto',
      sourceUrl: 'https://www.drmax.it/noremifa-25bust-20ml',
      snippet: 'Dispositivo medico indicato in caso di reflusso gastroesofageo e disturbi correlati.',
    ));

    addIf(normalized.contains('viviscal'), const ParafarmacoSearchResult(
      name: 'Viviscal',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Viviscal Italia',
      sourceUrl: 'https://www.viviscalitalia.it/',
      snippet: 'Integratori e prodotti per capelli fini, fragili o soggetti a caduta temporanea.',
    ));

    addIf(normalized.contains('doppelherz') && normalized.contains('omega'),
        const ParafarmacoSearchResult(
      name: 'Doppelherz Omega-3 1400',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Doppelherz',
      sourceUrl: 'https://www.doppelherz.it/prodotti/doppelherz-aktiv-omega-3-1400',
      snippet: 'Integratore con acidi grassi omega-3 EPA e DHA da olio di pesce concentrato.',
    ));

    addIf(normalized.contains('zincovit'), const ParafarmacoSearchResult(
      name: 'Zincovit C',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'HealthAid Italia',
      sourceUrl: 'https://www.healthaiditalia.it/integratori/zincovit-cr-blister-60-s',
      snippet: 'Integratore con zinco, vitamina C e propoli per il sistema immunitario.',
    ));

    addIf(normalized.contains('dermovitamina') && normalized.contains('ragadi'),
        const ParafarmacoSearchResult(
      name: 'Dermovitamina Ragadi Gel Mani-Piedi',
      category: 'Dermocosmetico / prodotto da farmacia',
      sourceName: 'Dermovitamina',
      sourceUrl: 'https://www.dermovitamina.it/prodotto/ragadi-gel-mani-piedi-filmante-protettivo/',
      snippet: 'Gel filmante protettivo indicato per ragadi, screpolature, fissurazioni e piccoli tagli.',
    ));

    addIf(normalized.contains('bioscalin') && normalized.contains('energy'),
        const ParafarmacoSearchResult(
      name: 'Bioscalin Energy',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Bioscalin Giuliani',
      sourceUrl: 'https://www.bioscalin.it/',
      snippet: 'Linea Bioscalin per il benessere dei capelli fragili o soggetti a caduta temporanea.',
    ));

    addIf(normalized.contains('bioscalin') && normalized.contains('tricoage'),
        const ParafarmacoSearchResult(
      name: 'Bioscalin TricoAge',
      category: 'Integratore / prodotto da farmacia',
      sourceName: 'Bioscalin Giuliani',
      sourceUrl: 'https://www.bioscalin.it/',
      snippet: 'Linea Bioscalin per capelli assottigliati, fragili o soggetti a caduta.',
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
    if (uri == null || !uri.host.toLowerCase().contains('codifa.it')) {
      return false;
    }
    final segments = uri.pathSegments.map((s) => s.toLowerCase()).toList();
    if (segments.length < 3) return false;
    return segments.first == 'parafarmaci' ||
        segments.first == 'integratori' ||
        segments.first == 'farmaci';
  }

  String _absoluteCodifaUrl(String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) return href;
    if (href.startsWith('//')) return 'https:$href';
    if (href.startsWith('/')) return 'https://www.codifa.it$href';
    return 'https://www.codifa.it/$href';
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
        .where((part) => part.isNotEmpty && !stopWords.contains(part.toLowerCase()))
        .take(8)
        .map((part) => '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}')
        .toList();
    return words.join(' ').trim();
  }

  String _extractTitle(dom.Document document, {required String fallback}) {
    final candidates = <String?>[
      document.querySelector('h1')?.text,
      document.querySelector('meta[property="og:title"]')?.attributes['content'],
      document.querySelector('title')?.text,
      fallback,
    ];
    for (final candidate in candidates) {
      final cleaned = _cleanText(candidate ?? '');
      if (cleaned.isNotEmpty) return _cleanTitle(cleaned);
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
      RegExp(r'\bCodice\s+(?:prodotto|articolo)\s*[:\-]?\s*([A-Z0-9]{4,20})\b', caseSensitive: false),
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
      if (_isUsefulSectionText(text)) {
        sections[type] = text.trim();
      }
    }

    for (final type in ParafarmacoSectionType.values) {
      if (type == ParafarmacoSectionType.complete ||
          (sections[type]?.trim().isNotEmpty ?? false)) {
        continue;
      }
      final extracted = _extractSectionFromPlainText(fullText, type);
      if (extracted != null && _isUsefulSectionText(extracted)) {
        sections[type] = extracted.trim();
      }
    }

    return sections;
  }

  bool _isUsefulSectionText(String text) {
    final cleaned = _cleanText(text);
    if (cleaned.length < 40) return false;
    final normalized = _normalize(cleaned);
    if (normalized == 'componenti e' || normalized == 'e ingredienti') return false;
    return true;
  }

  ParafarmacoSectionType? _sectionTypeFromHeading(String raw) {
    final text = _normalize(raw);
    if (_containsAny(text, const [
      'indicazioni',
      'a cosa serve',
      'descrizione',
      'prodotto',
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
      'avvertenze',
      'controindicazioni',
      'precauzioni',
      'effetti collaterali',
      'effetti indesiderati',
    ])) {
      return ParafarmacoSectionType.warnings;
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

    String? _extractSectionFromPlainText(String text, ParafarmacoSectionType type) {
      final labels = switch (type) {
        ParafarmacoSectionType.indications => const [
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
            'Componenti',
            'Composizione',
            'Ingredienti',
            'INCI',
            'Allergeni',
          ],
        ParafarmacoSectionType.complete => const <String>[],
      };
      final stopLabels = const [
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
        'Avvertenze',
        'Controindicazioni',
        'Precauzioni',
        'Effetti collaterali',
        'Effetti indesiderati',
        'Componenti e ingredienti',
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
  
      for (final label in labels) {
        var searchFrom = 0;
        final labelLower = label.toLowerCase();
        while (searchFrom < lower.length) {
          final start = lower.indexOf(labelLower, searchFrom);
          if (start < 0) break;
          searchFrom = start + labelLower.length;
  
          final contentStart = start + label.length;
          var end = text.length;
          for (final stopLabel in stopLabels) {
            if (stopLabel.toLowerCase() == labelLower) continue;
            final index = lower.indexOf(stopLabel.toLowerCase(), contentStart + 8);
            if (index > contentStart && index < end) end = index;
          }
  
          final candidate = _cleanText(text.substring(contentStart, end));
          if (!_isUsefulSectionText(candidate)) continue;
  
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
      ..writeln(fullText);
    return buffer.toString().trim();
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

    int _resultScore(ParafarmacoSearchResult result, String query) {
      final q = _normalize(query);
      final name = _normalize(result.name);
      final url = _normalize(result.sourceUrl);
      final snippet = _normalize(result.snippet ?? '');
      final haystack = '$name $url $snippet';
      final meaningfulTokens = _meaningfulSearchTokens(query);
      final rawTokens = _searchTokens(query);
      final compactName = name.replaceAll(' ', '');
      final compactMeaningful = meaningfulTokens.join();
      final compactRaw = rawTokens.join();
  
      var score = 0;
      if (name == q) score += 180;
      if (name.startsWith(q)) score += 130;
      if (name.contains(q)) score += 90;
      if (compactRaw.isNotEmpty && compactName == compactRaw) score += 170;
      if (compactRaw.isNotEmpty && compactName.startsWith(compactRaw)) score += 120;
      if (compactMeaningful.isNotEmpty && compactName == compactMeaningful) score += 140;
      if (compactMeaningful.isNotEmpty && compactName.startsWith(compactMeaningful)) score += 95;
      if (meaningfulTokens.isNotEmpty && name.startsWith(meaningfulTokens.first)) score += 45;
  
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
      if (rawTokens.length >= 2 && matchedRaw <= 1) score -= 25;
  
      final genericAfterBrand = rawTokens.skip(1).toList();
      for (final token in genericAfterBrand) {
        if (name.contains(token) || url.contains(token)) {
          score += 18;
        }
      }
  
      if (result.category.toLowerCase().contains('integratore')) score += 3;
      if (result.category.toLowerCase().contains('parafarmaco')) score += 3;
      return score;
    }
  

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
    if (!raw.contains('Ã') && !raw.contains('Â') && !raw.contains('â€')) {
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
          .replaceAll('â€”', '—');
    }
  }

  String _safeFileName(String raw) => raw
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _cleanText(String raw) => _repairMojibake(raw)
      .replaceAll('\u00a0', ' ')
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
