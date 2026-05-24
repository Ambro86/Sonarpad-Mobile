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

  Future<RaiPlaySoundPage> loadPage(String url) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final root = jsonDecode(response.body);
    final title = root['title']?.toString() ?? 'RaiPlay Sound';
    final items = <RaiPlaySoundItem>[];
    final seen = <String>{};

    void parseCards(List<dynamic> cards) {
      for (var c in cards) {
        if (c is! Map) continue;
        final pathId =
            c['path_id']?.toString() ?? c['pathId']?.toString() ?? '';
        final itemTitle = c['name']?.toString() ??
            c['title']?.toString() ??
            c['brand']?.toString() ??
            c['program_title']?.toString() ??
            'Senza titolo';
        final description =
            c['description']?.toString() ?? c['subtitle']?.toString() ?? '';

        String audioUrl = '';
        if (c['downloadable_audio'] != null &&
            c['downloadable_audio']['url'] != null) {
          audioUrl = c['downloadable_audio']['url'].toString();
        } else if (c['downlodable_audio'] != null &&
            c['downlodable_audio']['url'] != null) {
          audioUrl = c['downlodable_audio']['url'].toString();
        } else if (c['audio'] != null && c['audio']['url'] != null) {
          audioUrl = c['audio']['url'].toString();
        }

        final kind = audioUrl.isNotEmpty
            ? RaiPlaySoundItemKind.audio
            : (pathId.isNotEmpty ? RaiPlaySoundItemKind.page : null);
        if (kind == null) continue;
        if (itemTitle.trim().isEmpty) continue;

        final id = kind == RaiPlaySoundItemKind.audio
            ? 'audio|$audioUrl|$pathId'
            : 'page|$pathId';
        if (seen.add(id)) {
          items.add(RaiPlaySoundItem(
            id: id,
            title: itemTitle.trim(),
            description: description.trim(),
            kind: kind,
            pathId: pathId,
            audioUrl: audioUrl,
          ));
        }
      }
    }

    if (root['block'] != null && root['block']['cards'] is List) {
      parseCards(root['block']['cards']);
    }

    if (root['blocks'] is List) {
      for (var block in root['blocks']) {
        if (block['cards'] is List) {
          parseCards(block['cards']);
        }
      }
    }

    return RaiPlaySoundPage(
        title: title.isEmpty ? 'RaiPlay Sound' : title, items: items);
  }
}
