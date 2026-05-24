import 'dart:convert';
import 'package:http/http.dart' as http;

enum RaiPlayItemKind { media, page }

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

class RaiPlayService {
  static const _baseUrlB64 = "BT9NUQVqHVc7T1RfJlUTPlshC3lYBw==";
  static const _menuUrlB64 = "BT9NUQVqHVc7T1RfJlUTPlshC3lYB3ZbAShFRiBAGiw=";

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

    final resp = await http.get(Uri.parse(url));
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
      final item = _parseRootSection(section);
      if (item != null && seen.add(item.id)) {
        items.add(item);
      }
    }

    return RaiPlayPage(title: 'RaiPlay', items: items);
  }

  Future<RaiPlayPage> loadPage(String pathId, String secretKey, {String? pageTitle}) async {
    final baseUrl = decodeUrl(_baseUrlB64, secretKey);
    if (baseUrl == null) {
      throw Exception('Codice segreto non valido.');
    }

    String fullUrl;
    if (pathId.startsWith('http://') || pathId.startsWith('https://')) {
      fullUrl = pathId;
    } else {
      fullUrl = '$baseUrl$pathId';
    }

    final resp = await http.get(Uri.parse(fullUrl));
    if (resp.statusCode != 200) {
      throw Exception('Impossibile caricare la pagina RaiPlay.');
    }

    final root = jsonDecode(resp.body);
    final items = <RaiPlayItem>[];
    final seen = <String>{};

    final blocks = root['blocks'];
    if (blocks != null && blocks is List) {
      for (var block in blocks) {
        final cards = block['cards'];
        if (cards != null && cards is List) {
          _collectCards(cards, seen, items);
        }
      }
    }

    return RaiPlayPage(title: pageTitle ?? 'RaiPlay', items: items);
  }

  RaiPlayItem? _parseRootSection(Map<String, dynamic> section) {
    final name = section['name']?.toString().trim();
    final pathId = section['path_id']?.toString().trim();

    if (name != null && name.isNotEmpty && pathId != null && pathId.isNotEmpty) {
      return RaiPlayItem(
        id: pathId,
        title: name,
        description: '',
        kind: RaiPlayItemKind.page,
        pathId: pathId,
        mediaUrl: '',
      );
    }
    return null;
  }

  void _collectCards(List cards, Set<String> seen, List<RaiPlayItem> items) {
    for (var card in cards) {
      if (card is! Map<String, dynamic>) continue;
      
      final type = card['type']?.toString() ?? '';
      
      if (type == 'RaiPlay Programma Item' || type == 'RaiPlay Playlist Item') {
        final title = card['name']?.toString().trim() ?? '';
        final pathId = card['path_id']?.toString().trim() ?? '';
        if (title.isNotEmpty && pathId.isNotEmpty && seen.add(pathId)) {
          items.add(RaiPlayItem(
            id: pathId,
            title: title,
            description: card['description']?.toString().trim() ?? '',
            kind: RaiPlayItemKind.page,
            pathId: pathId,
            mediaUrl: '',
          ));
        }
      } else if (type == 'RaiPlay Video Item') {
        final title = card['episode_title']?.toString().trim() ?? card['name']?.toString().trim() ?? '';
        var mediaUrl = card['video_url']?.toString().trim() ?? '';
        if (title.isNotEmpty && mediaUrl.isNotEmpty && seen.add(mediaUrl)) {
          items.add(RaiPlayItem(
            id: mediaUrl,
            title: title,
            description: card['description']?.toString().trim() ?? '',
            kind: RaiPlayItemKind.media,
            pathId: '',
            mediaUrl: mediaUrl,
          ));
        }
      } else if (type == 'RaiPlay Orizzontale Item') {
        final title = card['name']?.toString().trim() ?? '';
        final pathId = card['path_id']?.toString().trim() ?? '';
        if (title.isNotEmpty && pathId.isNotEmpty && seen.add(pathId)) {
          items.add(RaiPlayItem(
            id: pathId,
            title: title,
            description: card['description']?.toString().trim() ?? '',
            kind: RaiPlayItemKind.page,
            pathId: pathId,
            mediaUrl: '',
          ));
        }
      }
    }
  }

  Future<String> resolveMediaUrl(String url) async {
    String resolvedUrl = url;
    
    if (url.contains('/relinker/relinkerServlet')) {
      final sep = url.contains('?') ? '&' : '?';
      final xmlUrl = '$url${sep}output=45&pl=native';
      try {
        final resp = await http.get(Uri.parse(xmlUrl));
        if (resp.statusCode == 200) {
          final body = resp.body;
          final match = RegExp(r'<url[^>]*type="content"[^>]*>([^<]+)</url>').firstMatch(body);
          if (match != null) {
            resolvedUrl = match.group(1)!;
          } else {
            // Se fallisce con type="content", proviamo qualsiasi <url> o <url type="...">
            final matchAny = RegExp(r'<url[^>]*>([^<]+)</url>').firstMatch(body);
            if (matchAny != null) {
              resolvedUrl = matchAny.group(1)!;
            }
          }
        }
      } catch (_) {}
    }

    if (resolvedUrl.toLowerCase().contains('.m3u8')) {
      try {
        final resp = await http.get(Uri.parse(resolvedUrl));
        if (resp.statusCode == 200) {
          final playlist = resp.body;
          String? adUrl;
          String? itaUrl;
          
          final lines = playlist.split('\n');
          for (var line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('#EXT-X-MEDIA:') && trimmed.contains('TYPE=AUDIO')) {
              final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(trimmed);
              if (uriMatch != null) {
                final uri = uriMatch.group(1)!;
                final langMatch = RegExp(r'LANGUAGE="([^"]+)"').firstMatch(trimmed);
                final nameMatch = RegExp(r'NAME="([^"]+)"').firstMatch(trimmed);
                final lang = langMatch?.group(1)?.toLowerCase();
                final name = nameMatch?.group(1)?.toLowerCase();
                
                if (lang == 'des' || name == 'audiodescrizione') {
                  adUrl = _resolveHlsChildUrl(resolvedUrl, uri);
                  break; // Audiodescrizione trovata, ha precedenza assoluta
                }
                if (lang == 'ita' && itaUrl == null) {
                  itaUrl = _resolveHlsChildUrl(resolvedUrl, uri);
                }
              }
            }
          }
          if (adUrl != null) return adUrl;
          if (itaUrl != null) return itaUrl;
        }
      } catch (_) {}
    }

    return resolvedUrl;
  }

  String _resolveHlsChildUrl(String masterUrl, String childUri) {
    if (childUri.startsWith('http://') || childUri.startsWith('https://')) {
      return childUri;
    }
    
    final masterUri = Uri.parse(masterUrl);
    final query = masterUri.hasQuery ? '?${masterUri.query}' : '';
    final path = masterUri.path;
    final lastSlash = path.lastIndexOf('/');
    final basePath = lastSlash != -1 ? path.substring(0, lastSlash) : path;
    
    final scheme = masterUri.scheme;
    final host = masterUri.host;
    
    if (childUri.contains('?')) {
      return '$scheme://$host$basePath/$childUri';
    } else {
      return '$scheme://$host$basePath/$childUri$query';
    }
  }
}
