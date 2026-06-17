import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

class AudiodescriptionItem {
  final String title;
  final String audioUrl;
  final String date;
  final String description;

  AudiodescriptionItem({
    required this.title,
    required this.audioUrl,
    required this.date,
    required this.description,
  });

  factory AudiodescriptionItem.fromJson(Map<String, dynamic> json) {
    return AudiodescriptionItem(
      title: (json['title'] ?? '').toString().trim(),
      audioUrl: (json['url'] ?? '').toString().trim(),
      date: (json['added'] != null) ? _formatDate(json['added']) : '',
      description: (json['partOf'] ?? '').toString().trim(),
    );
  }

  static String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final ms = (timestamp is int)
          ? timestamp * 1000
          : int.parse(timestamp.toString()) * 1000;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class AudiodescriptionGroup {
  final String title;
  final List<AudiodescriptionItem> items;

  AudiodescriptionGroup({
    required this.title,
    required this.items,
  });

  factory AudiodescriptionGroup.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString().trim();
    final data = json['data'] as List<dynamic>? ?? [];
    final items = data
        .map((e) => AudiodescriptionItem.fromJson(e as Map<String, dynamic>))
        .where((e) => e.audioUrl.isNotEmpty && e.title.isNotEmpty)
        .toList();

    return AudiodescriptionGroup(
      title: _normalizeTitle(title),
      items: items,
    );
  }

  static String _normalizeTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('film - audiodescrizioni') ||
        (title.startsWith('Film (') && title.endsWith(')'))) {
      return 'Film';
    }
    if (lower == 'miniserie tv - audiodescrizioni') {
      return 'Miniserie Tv';
    }
    return title;
  }
}


class AudiodescriptionScheduledProgram {
  final String dayLabel;
  final String time;
  final String channel;
  final String title;
  final String voiceText;
  final String dateTime;

  AudiodescriptionScheduledProgram({
    required this.dayLabel,
    required this.time,
    required this.channel,
    required this.title,
    required this.voiceText,
    required this.dateTime,
  });

  factory AudiodescriptionScheduledProgram.fromJson(
    Map<String, dynamic> json,
    String fallbackDayLabel,
  ) {
    final dayLabel = (json['giorno_label'] ?? fallbackDayLabel).toString().trim();
    final time = (json['orario'] ?? '').toString().trim();
    final channel = (json['canale'] ?? '').toString().trim();
    final title = (json['titolo'] ?? '').toString().trim();
    final voiceText = (json['testo_voce'] ?? '').toString().trim();
    final dateTime = (json['datetime'] ?? '').toString().trim();

    return AudiodescriptionScheduledProgram(
      dayLabel: dayLabel,
      time: time,
      channel: channel,
      title: title,
      voiceText: voiceText.isNotEmpty
          ? voiceText
          : '$dayLabel alle $time, $channel, $title.'.trim(),
      dateTime: dateTime,
    );
  }
}

class AudiodescriptionScheduledDay {
  final String label;
  final List<AudiodescriptionScheduledProgram> programs;

  AudiodescriptionScheduledDay({
    required this.label,
    required this.programs,
  });

  factory AudiodescriptionScheduledDay.fromJson(Map<String, dynamic> json) {
    final label = (json['giorno_label'] ?? json['data_estesa'] ?? '')
        .toString()
        .trim();
    final rawPrograms = json['programmi'] as List<dynamic>? ?? const [];
    final programs = rawPrograms
        .whereType<Map<String, dynamic>>()
        .map((e) => AudiodescriptionScheduledProgram.fromJson(e, label))
        .where((e) => e.title.isNotEmpty || e.voiceText.isNotEmpty)
        .toList();

    return AudiodescriptionScheduledDay(label: label, programs: programs);
  }
}

class AudiodescriptionService {
  static const _listUrlB64 =
      "GhUdXRJPS0YdExZHSggBDBwNBxIMXwIaCh0KHBVHTg4YSygCEBMGFVdaNwYBExMZTAVYMAYAHhJGXwQTF0YHFwANXk4YBQABXQYMQwQHBR0KFk4FWAIQSQUGARVHSA8WSgMcHQ8=";
  static const _catalogUrlB64 =
      "GhUdXRJPS0YdExZHSggBDBwNBxIMXwIaCh0KHBVHTg4YSygCEBMGFVdaNwYBExMZTAVYMAYAHhJGXwQTF0YHFwANXk4YBQABXQYMQwQHBR0KFk4FWAIQSQoOBgAFQgYAAUcKHAJHRxIaCg==";
  static const _urlKey = "rai-audio";
  static const _scheduledUrl =
      "https://sonarpad.com/api/audiodescrizioni/prossime_audiodescrizioni.php?mode=json";

  final http.Client _client;

  AudiodescriptionService({http.Client? client})
      : _client = client ?? http.Client();

  String _decodeObfuscatedUrl(String b64, String key) {
    final bytes = base64Decode(b64);
    final keyBytes = utf8.encode(key);
    final decoded = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return utf8.decode(decoded);
  }

  Uint8List _xorWithLuceKey(Uint8List payload, String secretKey) {
    final staticParts = [
      ...utf8.encode('sonar'),
      ...utf8.encode('pad-'),
      ...utf8.encode('SonarSecure-'),
    ];
    final keyBytes = [...staticParts, ...utf8.encode(secretKey)];

    final result = Uint8List(payload.length);
    for (int i = 0; i < payload.length; i++) {
      result[i] = payload[i] ^ keyBytes[i % keyBytes.length];
    }
    return result;
  }

  Future<String> _fetchAndDecodeLucePayload(
      String url, String secretKey) async {
    final resp = await _client.get(Uri.parse(url), headers: {
      'User-Agent': 'SonarpadMobile/0.1',
    });
    if (resp.statusCode != 200) {
      throw Exception('Errore di rete: ${resp.statusCode}');
    }

    final root = jsonDecode(resp.body);
    final algorithm = root['algorithm'];
    if (algorithm != 'gzip-xor-base64-v1') {
      throw Exception('Algoritmo Luce non supportato: $algorithm');
    }

    final payloadB64 = root['payload_b64'];
    final encryptedBytes = base64Decode(payloadB64);
    final decryptedBytes = _xorWithLuceKey(encryptedBytes, secretKey);

    final unzipped = GZipDecoder().decodeBytes(decryptedBytes);
    return utf8.decode(unzipped);
  }

  Future<List<AudiodescriptionItem>> fetchRecentCatalog(
      String secretKey) async {
    if (secretKey.trim().isEmpty) {
      throw Exception('Codice segreto Luce mancante.');
    }

    final url = _decodeObfuscatedUrl(_listUrlB64, _urlKey);
    final rawJson = await _fetchAndDecodeLucePayload(url, secretKey);
    final list = jsonDecode(rawJson) as List<dynamic>;

    final items = list
        .map((e) => AudiodescriptionItem.fromJson(e))
        .where((e) => e.audioUrl.isNotEmpty)
        .toList();
    // In Rust it is sorted by added date descending
    return items;
  }

  Future<List<AudiodescriptionGroup>> fetchGroupedCatalog(
      String secretKey) async {
    if (secretKey.trim().isEmpty) {
      throw Exception('Codice segreto Luce mancante.');
    }

    final url = _decodeObfuscatedUrl(_catalogUrlB64, _urlKey);
    final rawJson = await _fetchAndDecodeLucePayload(url, secretKey);
    final list = jsonDecode(rawJson) as List<dynamic>;

    final groups = list
        .map((e) => AudiodescriptionGroup.fromJson(e))
        .where((g) => g.items.isNotEmpty)
        .toList();

    // Normalize and group by same title
    final merged = <String, List<AudiodescriptionItem>>{};
    for (var g in groups) {
      merged.putIfAbsent(g.title, () => []).addAll(g.items);
    }

    final result = merged.entries
        .map((e) => AudiodescriptionGroup(title: e.key, items: e.value))
        .toList();
    result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }


  Future<List<AudiodescriptionScheduledDay>> fetchScheduledCatalog() async {
    final resp = await _client.get(Uri.parse(_scheduledUrl), headers: {
      'User-Agent': 'SonarpadMobile/0.3',
      'Accept': 'application/json',
    });
    if (resp.statusCode != 200) {
      throw Exception('Errore di rete: ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Risposta audiodescrizioni non valida.');
    }

    final root = decoded['dati'] is Map<String, dynamic>
        ? decoded['dati'] as Map<String, dynamic>
        : decoded;
    if (root['ok'] == false) {
      final message = (root['messaggio'] ?? root['error'] ?? 'Servizio non disponibile')
          .toString();
      throw Exception(message);
    }

    final rawDays = root['giorni'] as List<dynamic>? ?? const [];
    return rawDays
        .whereType<Map<String, dynamic>>()
        .map(AudiodescriptionScheduledDay.fromJson)
        .where((day) => day.programs.isNotEmpty)
        .toList();
  }

  Future<String> resolveAudioUrl(String audioUrl) async {
    // This matches the Rust implementation resolve_audio_url_for_clipboard
    // which delegates to relinker XML if it contains /relinker/relinkerServlet
    // Actually RaiPlayService already does exactly this for video URLs
    // Since it's identical logic, we can just return it or use RaiPlayService logic
    // We will do a basic relinker resolve here.
    if (!audioUrl.contains('/relinker/relinkerServlet')) {
      return audioUrl;
    }

    final sep = audioUrl.contains('?') ? '&' : '?';
    final xmlUrl = '$audioUrl${sep}output=45&pl=native';
    try {
      final resp = await _client.get(Uri.parse(xmlUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)',
      });
      if (resp.statusCode == 200) {
        final body = resp.body;
        final match = RegExp(r'<url[^>]*type="content"[^>]*>([^<]+)</url>')
                .firstMatch(body) ??
            RegExp(r'<url[^>]*>([^<]+)</url>').firstMatch(body);
        if (match != null) {
          return match.group(1)!;
        }
      }
    } catch (_) {}
    return audioUrl;
  }
}
