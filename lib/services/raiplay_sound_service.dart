import 'dart:convert';
import 'package:http/http.dart' as http;

enum RaiPlaySoundItemKind { audio, page }

class RaiPlaySoundItem {
  final String id;
  final String title;
  final String description;
  final RaiPlaySoundItemKind kind;
  final String pathId;
  final String audioUrl;

  RaiPlaySoundItem({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.pathId,
    required this.audioUrl,
  });
}

class RaiPlaySoundPage {
  final String title;
  final List<RaiPlaySoundItem> items;

  RaiPlaySoundPage({
    required this.title,
    required this.items,
  });
}

class RaiPlaySoundService {
  static const _baseUrlB64 = "BT9NUQVqHVc7T1RfJlUTPlshCyReBjdSSi9E";
  static const _genresUrlB64 =
      "BT9NUQVqHVc7T1RfJlUTPlshCyReBjdSSi9ERy1WGycIPFwmQi0H";
  static const _searchUrlB64 =
      "BT9NUQVqHVc7T1RfJlUTPlshCyReBjdSSi9ERytHGi8bIRsvHjAIG2AzGT0fKFEMBTVADiVbRl41RBNhQXFdOkIWOEQHLg==";
  static const _suggestionUrlB64 =
      "BT9NUQVqHVc7T1RfJlUTPlshCyReBjdSSi9ERytHGi8bIRsvHjAIG2AzGT0fKFEMBTVADiVbRl41RBNhQXJdJF4GN1JLNUUPLVYGNhM6HA==";
  static const _searchTemplateIn = "650d4cc74d28b941fec3218c";
  static const _searchTemplateOut = "6516d22540da6c377b151643";
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
      final url = utf8.decode(decoded);
      if (url.startsWith('http')) return url;
      return null;
    } catch (e) {
      return null;
    }
  }

  bool isSecretCodeValid(String secretKey) {
    return decodeUrl(_baseUrlB64, secretKey) != null;
  }

  String? getGenresUrl(String secretKey) {
    return decodeUrl(_genresUrlB64, secretKey);
  }

  String? getBaseUrl(String secretKey) {
    return decodeUrl(_baseUrlB64, secretKey);
  }

  Future<RaiPlaySoundPage> searchContent(String query, String secretKey) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw Exception('Inserisci un testo da cercare in RaiPlay Sound.');
    }

    final searchUrl = decodeUrl(_searchUrlB64, secretKey);
    if (searchUrl == null) {
      throw Exception('Codice segreto non valido.');
    }

    final effectiveQuery =
        await _refineSearchQuery(trimmedQuery, secretKey) ?? trimmedQuery;
    final body = {
      'templateIn': _searchTemplateIn,
      'templateOut': _searchTemplateOut,
      'params': {
        'from': 0,
        'size': _searchPageSize,
        'param': effectiveQuery,
        'sort': 'relevance',
      },
    };

    final response = await http
        .post(
          Uri.parse(searchUrl),
          headers: {
            'User-Agent': 'SonarpadMobile/0.1',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Impossibile cercare in RaiPlay Sound.');
    }

    final root = jsonDecode(response.body);
    final items = <RaiPlaySoundItem>[];
    final seen = <String>{};
    if (root is Map<String, dynamic>) {
      final podcastCards = root['aggs']?['podcast']?['cards'];
      if (podcastCards is List) {
        _collectCards(podcastCards, false, seen, items);
      }
      final audioCards = root['aggs']?['audio']?['cards'];
      if (audioCards is List) {
        _collectCards(audioCards, false, seen, items);
      }
    }

    return RaiPlaySoundPage(title: 'Risultati: $trimmedQuery', items: items);
  }

  Future<String?> _refineSearchQuery(String query, String secretKey) async {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) return null;

    final suggestionUrl = decodeUrl(_suggestionUrlB64, secretKey);
    if (suggestionUrl == null) return null;

    try {
      final response = await http
          .post(
            Uri.parse(suggestionUrl),
            headers: {
              'User-Agent': 'SonarpadMobile/0.1',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'text': query}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final root = jsonDecode(response.body);
      if (root is! Map<String, dynamic>) return null;
      final suggestions = root['suggestions'];
      if (suggestions is! List || suggestions.isEmpty) return null;
      final first = suggestions.first;
      if (first is! Map<String, dynamic>) return null;
      final suggestion = _stringField(first, 'text');
      if (suggestion == null) return null;

      final normalizedSuggestion = _normalizeSearchText(suggestion);
      if (normalizedSuggestion == normalizedQuery ||
          normalizedSuggestion.startsWith(normalizedQuery)) {
        return suggestion;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<RaiPlaySoundPage> loadPage(String url,
      {bool isRootPage = false}) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final root = jsonDecode(response.body);
    final title = root['title']?.toString() ?? 'RaiPlay Sound';
    final items = <RaiPlaySoundItem>[];
    final seen = <String>{};

    if (root['block'] != null && root['block']['cards'] is List) {
      _collectCards(root['block']['cards'], isRootPage, seen, items);
    }

    if (root['blocks'] is List) {
      for (var block in root['blocks']) {
        if (block['cards'] is List) {
          _collectCards(block['cards'], isRootPage, seen, items);
        }
      }
    }

    return RaiPlaySoundPage(
        title: title.isEmpty ? 'RaiPlay Sound' : title, items: items);
  }

  void _collectCards(
    List<dynamic> cards,
    bool isRootPage,
    Set<String> seen,
    List<RaiPlaySoundItem> items,
  ) {
    for (var card in cards) {
      if (card is! Map<String, dynamic>) continue;
      final item = _parseCard(card, isRootPage);
      if (item != null && seen.add(item.id)) {
        items.add(item);
      }
    }
  }

  RaiPlaySoundItem? _parseCard(Map<String, dynamic> card, bool isRootPage) {
    final pathId =
        _stringField(card, 'path_id') ?? _stringField(card, 'pathId') ?? '';
    final title = _preferredTitle(card);
    if (isRootPage && _shouldHideRootItem(title)) return null;

    final audioUrl = _nestedStringField(card, 'downloadable_audio', 'url') ??
        _nestedStringField(card, 'downlodable_audio', 'url') ??
        _nestedStringField(card, 'audio', 'url') ??
        '';
    final kind = audioUrl.isNotEmpty
        ? RaiPlaySoundItemKind.audio
        : (pathId.isNotEmpty ? RaiPlaySoundItemKind.page : null);
    if (kind == null) return null;

    final id = kind == RaiPlaySoundItemKind.audio
        ? 'audio|$audioUrl|$pathId'
        : 'page|$pathId';
    return RaiPlaySoundItem(
      id: id,
      title: title,
      description: _preferredDescription(card) ?? '',
      kind: kind,
      pathId: pathId,
      audioUrl: audioUrl,
    );
  }

  String _preferredTitle(Map<String, dynamic> card) {
    for (final key in [
      'titolo',
      'toptitle',
      'episode_title',
      'title',
      'label',
      'programma',
      'name',
      'brand',
      'program_title',
    ]) {
      final value = _stringField(card, key);
      if (value != null) return value;
    }
    return 'Elemento RaiPlay Sound';
  }

  String? _preferredDescription(Map<String, dynamic> card) {
    for (final key in [
      'sommario',
      'subtitle',
      'description',
      'vanity',
      'friendlyType',
    ]) {
      final value = _stringField(card, key);
      if (value != null) return value;
    }
    return null;
  }

  String? _stringField(Map<String, dynamic> value, String key) {
    final raw = value[key];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _nestedStringField(
    Map<String, dynamic> value,
    String objectKey,
    String fieldKey,
  ) {
    final object = value[objectKey];
    if (object is! Map<String, dynamic>) return null;
    return _stringField(object, fieldKey);
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
    return parts.join(' ').toLowerCase();
  }

  bool _shouldHideRootItem(String title) {
    final trimmed = title.trim();
    return trimmed == 'Audiodescrizioni-fiction' ||
        trimmed == 'Audiodescrizioni_film';
  }
}
