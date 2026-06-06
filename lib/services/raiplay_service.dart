import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';

enum RaiPlayItemKind { media, page }

const _menuSectionSourcePrefix = 'raiplay-menu-section:';

class RaiPlayItem {
  final String id;
  final String title;
  final String description;
  final RaiPlayItemKind kind;
  final String pathId;
  final String mediaUrl;

  RaiPlayItem({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.pathId,
    required this.mediaUrl,
  });
}

class RaiPlayPage {
  final String title;
  final List<RaiPlayItem> items;

  RaiPlayPage({
    required this.title,
    required this.items,
  });
}

class RaiPlayResolvedMedia {
  final String audioUrl;
  final String videoUrl;
  final String? audioLanguage;
  final String? audioName;

  const RaiPlayResolvedMedia({
    required this.audioUrl,
    required this.videoUrl,
    this.audioLanguage,
    this.audioName,
  });

  bool get hasDescribedAudio {
    return audioLanguage?.toLowerCase() == 'des' ||
        audioName?.toLowerCase() == 'audiodescrizione';
  }
}

class RaiPlayService {
  static const _baseUrlB64 = "BT9NUQVqHVc7T1RfJlUTPlshC3lYBw==";
  static const _menuUrlB64 = "BT9NUQVqHVc7T1RfJlUTPlshC3lYB3ZbAShFRiBAGiw=";
  static const _searchUrlB64 =
      "BT9NUQVqHVc7T1RfJlUTPlshC3lYB3ZXECldCT5aFm0INBs8XSMQXz4lHS4OIxRSEyJEES9dDBAkXVU4Bm8fJFQSK1UM";

  static const _searchTemplateIn = "6470a982e4e0301afe1f81f1";
  static const _searchTemplateOut = "6516ac5d40da6c377b151642";
  static const _searchPageSize = 12;

  String? decodeUrl(String encoded, String secretKey) {
    if (secretKey.trim().isEmpty) return null;
    try {
      final key = utf8.encode(secretKey.trim());
      final bytes = base64Decode(encoded);
      final decoded = List<int>.generate(
        bytes.length,
        (i) => bytes[i] ^ key[i % key.length],
      );
      return utf8.decode(decoded);
    } catch (_) {
      return null;
    }
  }

  bool isSecretCodeValid(String secretKey) {
    final decoded = decodeUrl(_baseUrlB64, secretKey);
    return decoded != null && decoded.startsWith('http');
  }

  Future<RaiPlayPage> loadRootPage(String secretKey) async {
    final url = decodeUrl(_menuUrlB64, secretKey);
    if (url == null) {
      throw Exception('Codice segreto non valido.');
    }

    final resp = await _get(url);
    if (resp.statusCode != 200) {
      throw Exception('Impossibile caricare il menu RaiPlay.');
    }

    final root = jsonDecode(resp.body);
    final sections = root['menuv4'] ?? root['menuv3'];
    if (sections == null || sections is! List) {
      throw Exception('Menu RaiPlay non disponibile.');
    }

    final items = <RaiPlayItem>[];
    final seen = <String>{};

    for (var section in sections) {
      if (section is! Map<String, dynamic>) continue;
      final item = _parseRootSection(section);
      if (item != null && seen.add(item.id)) {
        items.add(item);
      }
    }

    items.add(RaiPlayItem(
      id: 'page|root|TGR',
      title: 'TGR',
      description: 'Telegiornali Regionali',
      kind: RaiPlayItemKind.page,
      pathId: 'local:tgr_regions',
      mediaUrl: '',
    ));

    return RaiPlayPage(title: 'RaiPlay', items: items);
  }

  Future<RaiPlayPage> loadPage(String pathId, String secretKey,
      {String? pageTitle}) async {
    if (pathId.startsWith(_menuSectionSourcePrefix)) {
      return _loadMenuSectionPage(
        pathId.substring(_menuSectionSourcePrefix.length),
        secretKey,
      );
    }

    if (pathId == 'local:tgr_regions') {
      final regions = [
        'Abruzzo',
        'Basilicata',
        'Calabria',
        'Campania',
        'Emilia-Romagna',
        'Friuli-Venezia Giulia',
        'Lazio',
        'Liguria',
        'Lombardia',
        'Marche',
        'Molise',
        'Piemonte',
        'Puglia',
        'Sardegna',
        'Sicilia',
        'Toscana',
        'Trentino-Alto Adige',
        'Umbria',
        'Valle d’Aosta',
        'Veneto'
      ];
      return RaiPlayPage(
        title: 'TGR',
        items: regions
            .map((r) => RaiPlayItem(
                  id: 'search_auto_open:TGR $r',
                  title: r,
                  description: 'TGR $r',
                  kind: RaiPlayItemKind.page,
                  pathId: 'search_auto_open:TGR $r',
                  mediaUrl: '',
                ))
            .toList(),
      );
    }

    if (pathId.startsWith('search:')) {
      final query = pathId.substring(7);
      return searchContent(query, secretKey);
    }

    if (pathId.startsWith('search_auto_open:')) {
      final query = pathId.substring(17);
      final searchResults = await searchContent(query, secretKey);
      if (searchResults.items.isNotEmpty) {
        final firstItem = searchResults.items.first;
        if (firstItem.kind == RaiPlayItemKind.page) {
          return loadPage(firstItem.pathId, secretKey,
              pageTitle: firstItem.title);
        }
      }
      return searchResults;
    }

    final baseUrl = decodeUrl(_baseUrlB64, secretKey);
    if (baseUrl == null) {
      throw Exception('Codice segreto non valido.');
    }

    String fullUrl;
    if (pathId.startsWith('http://') || pathId.startsWith('https://')) {
      fullUrl = pathId;
    } else {
      fullUrl = _absoluteUrl(pathId, baseUrl);
    }

    final resp = await _get(fullUrl);
    if (resp.statusCode != 200) {
      throw Exception('Impossibile caricare la pagina RaiPlay.');
    }

    final root = jsonDecode(resp.body);
    final items = <RaiPlayItem>[];
    final seen = <String>{};

    _collectNestedItems(root, seen, items, baseUrl);
    if (items.isEmpty && root is Map<String, dynamic>) {
      final item = _parseCard(root, baseUrl);
      if (item != null) items.add(item);
    }

    return RaiPlayPage(
      title: pageTitle ?? _pageTitle(root),
      items: items,
    );
  }

  RaiPlayItem? _parseRootSection(Map<String, dynamic> section) {
    final rawTitle = _stringField(section, 'name');
    if (rawTitle == null) return null;

    String title = rawTitle;
    if (title.toLowerCase() == 'cerca' || title.toLowerCase() == 'esplora cerca') {
      title = 'Esplora';
    }

    if (title.toLowerCase() == 'altro') return null;
    final elements = section['elements'];
    if (elements is List && elements.isNotEmpty) {
      String desc = _stringField(section, 'title') ?? _stringField(section, 'menu_type') ?? '';
      if (desc.toLowerCase() == 'cerca' || desc.toLowerCase() == 'esplora cerca') {
        desc = 'Esplora';
      }
      return RaiPlayItem(
        id: 'page|root|$title',
        title: title,
        description: desc,
        kind: RaiPlayItemKind.page,
        pathId: '$_menuSectionSourcePrefix$title',
        mediaUrl: '',
      );
    }

    final pathId = _stringField(section, 'path_id');
    if (pathId != null && _isSupportedInternalTarget(pathId)) {
      String desc = _stringField(section, 'menu_type') ?? '';
      if (desc.toLowerCase() == 'cerca' || desc.toLowerCase() == 'esplora cerca') {
        desc = 'Esplora';
      }
      return RaiPlayItem(
        id: 'page|$pathId',
        title: title,
        description: desc,
        kind: RaiPlayItemKind.page,
        pathId: pathId,
        mediaUrl: '',
      );
    }

    return null;
  }

  Future<RaiPlayPage> _loadMenuSectionPage(
      String sectionName, String secretKey) async {
    final url = decodeUrl(_menuUrlB64, secretKey);
    final baseUrl = decodeUrl(_baseUrlB64, secretKey);
    if (url == null || baseUrl == null) {
      throw Exception('Codice segreto non valido.');
    }

    final resp = await _get(url);
    if (resp.statusCode != 200) {
      throw Exception('Impossibile caricare il menu RaiPlay.');
    }

    final root = jsonDecode(resp.body);
    final sections = root['menuv4'] ?? root['menuv3'];
    if (sections == null || sections is! List) {
      throw Exception('Menu RaiPlay non disponibile.');
    }

    Map<String, dynamic>? section;
    for (final entry in sections) {
      if (entry is! Map<String, dynamic>) continue;
      final name = _stringField(entry, 'name');
      
      String? title = name;
      if (title != null && (title.toLowerCase() == 'cerca' || title.toLowerCase() == 'esplora cerca')) {
        title = 'Esplora';
      }

      if (title != null && title.toLowerCase() == sectionName.toLowerCase()) {
        section = entry;
        break;
      }
    }
    if (section == null) {
      throw Exception('Sezione RaiPlay non trovata.');
    }

    final elements = section['elements'];
    if (elements is! List) {
      throw Exception('Sezione RaiPlay non disponibile.');
    }

    final items = <RaiPlayItem>[];
    final seen = <String>{};
    _collectCards(elements, seen, items, baseUrl);

    return RaiPlayPage(
      title: _stringField(section, 'title') ??
          _stringField(section, 'name') ??
          'RaiPlay',
      items: items,
    );
  }

  void _collectNestedItems(
    dynamic value,
    Set<String> seen,
    List<RaiPlayItem> items,
    String baseUrl,
  ) {
    if (value is List) {
      for (final entry in value) {
        _collectEntry(entry, seen, items, baseUrl);
      }
      return;
    }
    if (value is Map<String, dynamic>) {
      for (final key in ['items', 'contents', 'blocks', 'sets', 'elements']) {
        final array = value[key];
        if (array is List) {
          for (final entry in array) {
            _collectEntry(entry, seen, items, baseUrl);
          }
        }
      }
    }
  }

  void _collectEntry(
    dynamic entry,
    Set<String> seen,
    List<RaiPlayItem> items,
    String baseUrl,
  ) {
    if (entry is Map<String, dynamic>) {
      final item = _parseCard(entry, baseUrl);
      if (item != null && seen.add(item.id)) {
        items.add(item);
      }
    }
    _collectNestedItems(entry, seen, items, baseUrl);
  }

  void _collectCards(
    List cards,
    Set<String> seen,
    List<RaiPlayItem> items,
    String baseUrl,
  ) {
    for (var card in cards) {
      if (card is! Map<String, dynamic>) continue;
      final item = _parseCard(card, baseUrl);
      if (item != null && seen.add(item.id)) {
        items.add(item);
      }
    }
  }

  RaiPlayItem? _parseCard(Map<String, dynamic> card, String baseUrl) {
    if (card.containsKey('action')) return null;
    final type = _stringField(card, 'type');
    if (type == 'label' || type == 'placeholder') return null;
    if ((_stringField(card, 'menu_type') ?? '').toLowerCase() ==
        'raiplay separatore nav'.toLowerCase()) {
      return null;
    }

    final video = card['video'];
    final mediaUrl = video is Map<String, dynamic>
        ? _stringField(video, 'content_url') ?? _stringField(card, 'video_url')
        : _stringField(card, 'video_url');
    String? rawPathId;
    final pathId = _stringField(card, 'path_id');
    if (pathId != null && _isSupportedInternalTarget(pathId)) {
      rawPathId = pathId;
    } else {
      final url = _stringField(card, 'url');
      if (url != null) rawPathId = _htmlUrlToJsonPath(url);
    }

    final title = _preferredTitle(card);
    if (title == null) return null;

    if (mediaUrl != null) {
      return RaiPlayItem(
        id: 'media|$mediaUrl|${rawPathId ?? ''}',
        title: title,
        description: _preferredDescription(card) ?? '',
        kind: RaiPlayItemKind.media,
        pathId: '',
        mediaUrl: mediaUrl,
      );
    }
    if (rawPathId != null) {
      final pathId = _absoluteUrl(rawPathId, baseUrl);
      return RaiPlayItem(
        id: 'page|$pathId',
        title: title,
        description: _preferredDescription(card) ?? '',
        kind: RaiPlayItemKind.page,
        pathId: pathId,
        mediaUrl: '',
      );
    }
    return null;
  }

  String? _preferredTitle(Map<String, dynamic> card) {
    for (final key in [
      'titolo',
      'episode_title',
      'toptitle',
      'title',
      'name',
      'label',
      'programma',
      'program_name',
    ]) {
      final value = _stringField(card, key);
      if (value != null) return value;
    }
    return null;
  }

  String? _preferredDescription(Map<String, dynamic> card) {
    for (final key in [
      'sommario',
      'description',
      'vanity',
      'caption',
      'subtitle',
      'duration_in_minutes',
      'menu_type',
    ]) {
      final value = _stringField(card, key);
      if (value != null) return value;
    }
    return null;
  }

  String _pageTitle(dynamic root) {
    if (root is Map<String, dynamic>) {
      return _stringField(root, 'name') ??
          _stringField(root, 'title') ??
          _stringField(root, 'label') ??
          'RaiPlay';
    }
    return 'RaiPlay';
  }

  String? _stringField(Map<String, dynamic> value, String key) {
    final raw = value[key];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isSupportedInternalTarget(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed.contains('raiplay.it') &&
          (trimmed.endsWith('.json') || trimmed.contains('.json?'));
    }
    return trimmed.startsWith('/') && trimmed.endsWith('.json');
  }

  String? _htmlUrlToJsonPath(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.endsWith('.json')) return trimmed;
    if (trimmed.endsWith('.html')) {
      return '${trimmed.substring(0, trimmed.length - 5)}.json';
    }
    if (trimmed.startsWith('/')) return '$trimmed.json';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final replaced = trimmed.replaceAll('.html', '.json');
      return replaced == trimmed ? '$trimmed.json' : replaced;
    }
    return null;
  }

  String _absoluteUrl(String pathOrUrl, String baseUrl) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return '$baseUrl$trimmed';
  }

  Future<http.Response> _get(String url) {
    return http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'SonarpadMobile/0.1'},
    );
  }

  /// Cerca contenuti su RaiPlay tramite l'endpoint /ricerca.json?q=[query].
  ///
  /// Usa lo stesso meccanismo di autenticazione degli altri metodi del servizio.
  Future<RaiPlayPage> searchContent(String query, String secretKey) async {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      throw Exception('Inserisci un testo da cercare in RaiPlay.');
    }

    final searchUrl = decodeUrl(_searchUrlB64, secretKey);
    final baseUrl = decodeUrl(_baseUrlB64, secretKey);
    if (searchUrl == null || baseUrl == null) {
      throw Exception('Codice segreto non valido.');
    }

    final body = {
      "templateIn": _searchTemplateIn,
      "templateOut": _searchTemplateOut,
      "params": {
        "param": normalizedQuery,
        "from": 0,
        "sort": "relevance",
        "size": _searchPageSize,
        "additionalSize": _searchPageSize,
        "onlyVideoQuery": false,
        "onlyProgramsQuery": false,
      }
    };

    final resp = await http.post(
      Uri.parse(searchUrl),
      headers: {
        'User-Agent': 'SonarpadMobile/0.1',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception('Impossibile eseguire la ricerca su RaiPlay.');
    }

    final root = jsonDecode(resp.body);
    final items = <RaiPlayItem>[];
    final seen = <String>{};
    if (root is Map<String, dynamic>) {
      final titleCards = root['agg']?['titoli']?['cards'];
      if (titleCards is List) {
        _collectCards(titleCards, seen, items, baseUrl);
      }
      final videoCards = root['agg']?['video']?['cards'];
      if (videoCards is List) {
        _collectCards(videoCards, seen, items, baseUrl);
      }
    }

    return RaiPlayPage(
      title: 'Risultati: $query',
      items: items,
    );
  }

  String _normalizeSearchText(String text) {
    final parts = <String>[];
    final buffer = StringBuffer();
    for (final codeUnit in text.trim().codeUnits) {
      final isWhitespace = codeUnit == 9 ||
          codeUnit == 10 ||
          codeUnit == 11 ||
          codeUnit == 12 ||
          codeUnit == 13 ||
          codeUnit == 32;
      if (isWhitespace) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }
    return parts.join(' ');
  }

  Future<String> resolveMediaUrl(String url) async {
    final media = await resolvePlaybackUrls(url);
    return media.audioUrl;
  }

  Future<RaiPlayResolvedMedia> resolvePlaybackUrls(String url) async {
    String resolvedUrl = url;
    await AppLogger.log('RaiPlayService: Inizio risoluzione media per: $url');

    if (url.contains('/relinker/relinkerServlet')) {
      final sep = url.contains('?') ? '&' : '?';
      final xmlUrl = '$url${sep}output=45&pl=native';
      await AppLogger.log('RaiPlayService: Interrogo il relinker XML: $xmlUrl');
      try {
        final resp = await http.get(Uri.parse(xmlUrl));
        if (resp.statusCode == 200) {
          final body = resp.body;
          final match = RegExp(r'<url[^>]*type="content"[^>]*>([^<]+)</url>')
              .firstMatch(body);
          if (match != null) {
            resolvedUrl = match.group(1)!;
          } else {
            // Se fallisce con type="content", proviamo qualsiasi <url> o <url type="...">
            final matchAny =
                RegExp(r'<url[^>]*>([^<]+)</url>').firstMatch(body);
            if (matchAny != null) {
              resolvedUrl = matchAny.group(1)!;
            }
          }
          await AppLogger.log(
              'RaiPlayService: Relinker risolto in: $resolvedUrl');
        } else {
          await AppLogger.log(
              'RaiPlayService: Errore relinker HTTP ${resp.statusCode}');
        }
      } catch (e) {
        await AppLogger.log('RaiPlayService: Eccezione relinker: $e');
      }
    }

    if (resolvedUrl.toLowerCase().contains('.m3u8')) {
      await AppLogger.log(
          'RaiPlayService: Scarico playlist M3U8 per cercare audiodescrizione: $resolvedUrl');
      try {
        final resp = await http.get(Uri.parse(resolvedUrl));
        if (resp.statusCode == 200) {
          final finalMasterUrl = resp.request?.url.toString() ?? resolvedUrl;
          if (finalMasterUrl != resolvedUrl) {
            await AppLogger.log(
                'RaiPlayService: Redirect rilevato!\nOriginale: $resolvedUrl\nFinale: $finalMasterUrl');
          }

          final playlist = resp.body;
          final media = resolveHlsPlaybackUrlsFromPlaylist(
            finalMasterUrl,
            playlist,
            fallbackAudioUrl: resolvedUrl,
          );

          if (media.hasDescribedAudio) {
            await AppLogger.log(
                'RaiPlayService: Restituisco traccia AD: ${media.audioUrl}');
            return media;
          }
          if (media.audioUrl != resolvedUrl) {
            await AppLogger.log(
                'RaiPlayService: Restituisco traccia ITA: ${media.audioUrl}');
            return media;
          }

          await AppLogger.log(
              'RaiPlayService: Nessuna traccia AD/ITA trovata, uso master playlist.');
          return RaiPlayResolvedMedia(
            audioUrl: resolvedUrl,
            videoUrl: finalMasterUrl,
          );
        } else {
          await AppLogger.log(
              'RaiPlayService: Errore M3U8 HTTP ${resp.statusCode}');
        }
      } catch (e) {
        await AppLogger.log('RaiPlayService: Eccezione download M3U8: $e');
      }
    }

    return RaiPlayResolvedMedia(
      audioUrl: resolvedUrl,
      videoUrl: resolvedUrl,
    );
  }

  RaiPlayResolvedMedia resolveHlsPlaybackUrlsFromPlaylist(
    String masterUrl,
    String playlist, {
    String? fallbackAudioUrl,
    bool logChildUrls = true,
  }) {
    String? adUrl;
    String? itaUrl;
    String? audioLanguage;
    String? audioName;

    final lines = playlist.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#EXT-X-MEDIA:') &&
          trimmed.contains('TYPE=AUDIO')) {
        final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(trimmed);
        if (uriMatch != null) {
          final uri = uriMatch.group(1)!;
          final langMatch = RegExp(r'LANGUAGE="([^"]+)"').firstMatch(trimmed);
          final nameMatch = RegExp(r'NAME="([^"]+)"').firstMatch(trimmed);
          final lang = langMatch?.group(1)?.toLowerCase();
          final name = nameMatch?.group(1)?.toLowerCase();

          if (lang == 'des' || name == 'audiodescrizione') {
            adUrl = _resolveHlsChildUrl(masterUrl, uri, log: logChildUrls);
            audioLanguage = lang;
            audioName = name;
            break;
          }
          if (lang == 'ita' && itaUrl == null) {
            itaUrl = _resolveHlsChildUrl(masterUrl, uri, log: logChildUrls);
            audioLanguage = lang;
            audioName = name;
          }
        }
      }
    }

    return RaiPlayResolvedMedia(
      audioUrl: adUrl ?? itaUrl ?? fallbackAudioUrl ?? masterUrl,
      videoUrl: masterUrl,
      audioLanguage: audioLanguage,
      audioName: audioName,
    );
  }

  String _resolveHlsChildUrl(String masterUrl, String childUri,
      {bool log = true}) {
    final masterUri = Uri.parse(masterUrl);
    var resolvedUri = masterUri.resolve(childUri);

    if (!resolvedUri.hasQuery && masterUri.hasQuery) {
      resolvedUri = resolvedUri.replace(query: masterUri.query);
    }

    final finalUrl = resolvedUri.toString();
    if (log) {
      AppLogger.log('RaiPlayService: Child URI risolto in: $finalUrl');
    }
    return finalUrl;
  }
}
