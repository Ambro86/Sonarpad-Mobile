import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

class TvChannel {
  final String name;
  final String url;
  final String category;

  TvChannel({
    required this.name,
    required this.url,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'category': category,
      };

  factory TvChannel.fromJson(Map<String, dynamic> json) => TvChannel(
        name: json['name'] as String,
        url: json['url'] as String,
        category: json['category'] as String? ?? 'Altri',
      );
}

class TvProgram {
  final String title;
  final String hour;
  final int startTime;
  final int endTime;

  TvProgram({
    required this.title,
    required this.hour,
    required this.startTime,
    required this.endTime,
  });
}

class TvService {
  static const _prefsKey = 'sonarpad_tv_favorites';
  static const _staticKeyParts = ['sonar', 'pad-', 'SonarSecure-'];
  static const _la7StreamUrl =
      'https://d1chghleocc9sm.cloudfront.net/v1/master/3722c60a815c199d9c0ef36c5b73da68a62b09d1/cc-evfku205gqrtf/Live.m3u8';

  static const _oggiInTvGuideUrlPayloadJson =
      r'''{"payload_b64":"csAxIXZQMnhMMiawFTr6bjtEskCkzkNJJ+Zweyc6I0xoq5wAQq2me+nsGOl55vyuggHwBZyk/4KnTrP2iV7rNEEN7i90j4pqQXbXPAgPICMLN0By","algorithm":"gzip-xor-base64-v1"}''';
  static const _oggiInTvTimelineUrlPayloadJson =
      r'''{"payload_b64":"csAxIXZQMnhMMuhZfR1S+OWXPRn4oJR5K4nkpYbgWGup/jgB+m6jPWForBe9oLtOwaBOreEeoqetOYbKLTxeLIC4fDkh4S9vy3U4I3E=","algorithm":"gzip-xor-base64-v1"}''';
  static const _tvChannelsPayloadJson =
      r'''{"payload_b64":"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","algorithm":"gzip-xor-base64-v1"}''';
  static const _regionalTvChannelsPayloadJson =
      r'''{"payload_b64":"csAxIXZQMnhMMo4nOUegdie+WUmPr85Uj4uCpYb+eOdb7HZeI0qNCD7T7Xlq+7Z34/VojdnssHYJrF8MsIN5yUmAdYLumBrJ3Y1fD74xbk4UyD4bsx3g1GAH6rS84/ksoTk2E5536VjBOx7IYFz//hI2DPNEaUMkNk3znFwDXVNEy6+Gs3OSPhzVG0YQg3Bp3eSj7+Wkpd4LYzxx8+P6woCB2UIxKrXej36b/GQGUDa4cAtnmqla69uoehBDRXsxpp4RqRyyEb2tNmQ3RJW5O0OAP5bLMLL7atRd6lJbLxaATCMxAitjohs7CnWm8GxiW/cpCuMxbLffbLf1U/FkojcCWoVMxjem+MWbDOpyuO3x5muELmrcBfSFOTGK+6DNBm7b8XfmwsQz3QmoQRHIYcfwje/j6a/9frT35X3LSJAB0+UwSVGeMvCSSyeQcTJY3NtQUPd59Qt0svtvFwdksay9OjgKmvZiPQ5k+4hsR/DPixpoUFDgJboB3rR9+kw2i1mzYuAt7dEazKqaDh9C4uZTFVroYKOYNLxcfPoDvLE4NM0LJo6uRuYotBkMQS6GKep2TCJciQi9d+cbBLcfoVRw3Yajra9G/ZLbihg22u50J3iLTuUkSfsUHWepqHC90J//JfXmqFYzNKCZe5KO5vtS6z6+F1P51ZkPdA1En4a3jokxcqsPFN38rlbpsXG4IuphfOeNxneAac0Cjxlm1p/E7BdAnZkWb0g/i8gTcTmVjP5/4OICFuz5mn3DHcnXD61/vpIBJVvcgr8JnPx3OuYCfkoBgt3XSOoVjd2rqOKYfZyj64RqZrXV2olVFmKSBjU+9aVCugpQaYSeOgOcaO3qhFh7lqmb1blGphnTTe0eV4EtT068jcyJlzeGZ9n9I7ZqIVodQZXSJwJnRFNQLXnn6d3g86kkH5uyX2+/GiEWGGMlNIHm4g/wnzFkRgr9R/OSo2Fn9slLaF5vcpsYVy7GQK+O7p3wN0eSRb3Y39Qbbz2LB58SAEU432sE7yI6wA4cHgit33noxPQWM2kGNWfSFvJILtsEpWMAJYJnmwxGTIQgLwJRjGnZ8nnBdaUpLNf7ap9EHcW3PdAjH2Hjs+EG9SGj6f6D/x9RGzuowx7Am1t4odnr+KqBC34Z7jhe3ixIhkEE5pqfiPnqheU6X5gG/OZMKymJwo2+uOSPdWsu7A2nUaHJyUuv2sKbPjxELlIfjs8cWK21XEvL5fk9wfo3KdGjQkDrRKo9dpJbEzDKsexZqrT9c+A3ELAhv6gIMI0TRLCApOyH3E9/hFv7uzzcd4W10GEzWaOz1BZ+pVZy0+NCEyrQeFJDS8FxorM/2VPCGIPgejoFJ/UcaJeYyEILf1ZwcHb0G/SmyQTBY7F4eLnhwbvnVehk6clOMa09b9Lk+vxkvSAGuAbTnN+ZQGRWuk77GmFgTyho/0tmf+5y0XUG7zm8FXEjH0yiGtHoO7jrCkXH+pRGTPi9gA3RKZkhlfOiwa2bVrk/6/VtUloaCv0hrS0mvPojNLr6SPFEQDayGWwEluc+TWqkJO9VdvTNXcVIDDBvPnm6WcvsyUkcPX4PnbDVm+w5mzvNd4e8B7jHWHJM","algorithm":"gzip-xor-base64-v1"}''';

  String _tvCategory(String name) {
    final n = normalizeChannelName(name);
    if (n.startsWith('rai')) return 'Rai';
    if (n == 'rete4' ||
        n == 'canale5' ||
        n == 'italia1' ||
        n == 'italia2' ||
        n == 'tgcom24' ||
        n == 'iris' ||
        n == 'la5' ||
        n == '20' ||
        n == '27' ||
        n == 'cine34' ||
        n == 'topcrime' ||
        n == 'focus' ||
        n == 'mediasetextra' ||
        n == 'boing' ||
        n == 'cartoonito') {
      return 'Mediaset';
    }
    return 'Altri';
  }

  bool isRaiAudioDescriptionChannel(TvChannel channel) {
    return (channel.name == 'Rai 1' ||
            channel.name == 'Rai 2' ||
            channel.name == 'Rai 3') &&
        channel.url.contains('mediapolis.rai.it/relinker/');
  }

  String _decodePayload(String jsonStr, String secretKey) {
    final key = utf8.encode(secretKey).toList();
    for (var part in _staticKeyParts) {
      key.addAll(utf8.encode(part));
    }
    final Map<String, dynamic> payload = jsonDecode(jsonStr);
    final String algorithm = payload['algorithm'];
    if (algorithm != 'gzip-xor-base64-v1') {
      throw Exception('Algoritmo payload non supportato: $algorithm');
    }

    final String b64 = payload['payload_b64'];
    final List<int> encrypted = base64Decode(b64);

    if (key.isEmpty) {
      throw Exception('Chiave payload TV non valida.');
    }

    final List<int> decrypted = List<int>.generate(
      encrypted.length,
      (i) => encrypted[i] ^ key[i % key.length],
    );

    final decompressed = gzip.decode(decrypted);
    return utf8.decode(decompressed);
  }

  bool isSecretCodeValid(String secretKey) {
    if (secretKey.trim().isEmpty) return false;
    try {
      _decodePayload(_tvChannelsPayloadJson, secretKey.trim());
      return true;
    } catch (_) {
      return false;
    }
  }

  List<TvChannel> loadChannels(String secretKey) {
    if (secretKey.trim().isEmpty) return [];

    final channels = <TvChannel>[];

    try {
      final mainJson = _decodePayload(_tvChannelsPayloadJson, secretKey.trim());
      final mainData = jsonDecode(mainJson);
      for (var ch in mainData['channels']) {
        final name = (ch['name'] as String).trim();
        var url = (ch['url'] as String).trim();
        if (name == 'La7') {
          url = _la7StreamUrl;
        }
        if (name.isNotEmpty && url.isNotEmpty) {
          channels.add(TvChannel(
            name: name,
            url: url,
            category: _tvCategory(name),
          ));
        }
      }
    } catch (e) {
      // Ignora errori o logga
    }

    try {
      final regionalJson =
          _decodePayload(_regionalTvChannelsPayloadJson, secretKey.trim());
      final regionalData = jsonDecode(regionalJson);
      for (var ch in regionalData['channels']) {
        final name = (ch['name'] as String).trim();
        final url = (ch['url'] as String).trim();
        if (name.isNotEmpty && url.isNotEmpty) {
          channels.add(TvChannel(
            name: name,
            url: url,
            category: 'Regionali',
          ));
        }
      }
    } catch (e) {
      // Ignora errori o logga
    }

    return channels;
  }

  Future<Map<String, TvProgram>> loadCurrentPrograms(String secretKey) async {
    final template = _decodePayload(_oggiInTvTimelineUrlPayloadJson, secretKey.trim());
    final nowTime = DateTime.now();
    final date =
        '${nowTime.year}-${nowTime.month.toString().padLeft(2, '0')}-${nowTime.day.toString().padLeft(2, '0')}';
    final url = template.replaceAll('{date}', date);
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Sonarpad TV/1.0'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final root = jsonDecode(response.body);
    if (root is! List) return {};

    final currentPrograms = <String, TvProgram>{};
    final nowSec = nowTime.millisecondsSinceEpoch ~/ 1000;

    for (final group in root) {
      if (group is! List) continue;
      for (final item in group) {
        if (item is! Map<String, dynamic>) continue;
        final guideChannel = item['ch']?.toString().trim() ?? '';
        final title = item['title']?.toString().trim() ?? '';
        if (guideChannel.isEmpty || title.isEmpty) continue;

        final startTime = _readInt(item, 'startTime', 'start_time');
        final endTime = _readInt(item, 'endTime', 'end_time');

        if (startTime <= nowSec && endTime > nowSec) {
          final target = normalizeChannelName(guideChannel);
          currentPrograms[target] = TvProgram(
            title: title,
            hour: item['hour']?.toString().trim() ?? '',
            startTime: startTime,
            endTime: endTime,
          );
        }
      }
    }
    return currentPrograms;
  }

  Future<List<TvProgram>> loadChannelGuide(
      String channel, String secretKey, {DateTime? targetDate}) async {
    final dt = targetDate ?? DateTime.now();
    
    // Proviamo prima con la timeline generale filtrata per canale
    final timelinePrograms = await _loadTimelineChannelGuide(channel, secretKey.trim(), dt);
    if (timelinePrograms.isNotEmpty) {
      return timelinePrograms;
    }

    // Fallback sulla URL specifica per canale
    final template =
        _decodePayload(_oggiInTvGuideUrlPayloadJson, secretKey.trim());
    final date =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final normalizedChannel = normalizeChannelName(channel);

    final url = template
        .replaceAll('{channel}', Uri.encodeComponent(normalizedChannel))
        .replaceAll('{date}', date);

    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Sonarpad TV/1.0'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    final programs = <TvProgram>[];
    for (var item in data) {
      programs.add(TvProgram(
        title: item['title']?.toString().trim() ?? '',
        hour: item['hour']?.toString().trim() ?? '',
        startTime: _readInt(item, 'start_time', 'start_time'),
        endTime: _readInt(item, 'end_time', 'end_time'),
      ));
    }

    return programs.where((p) => p.title.isNotEmpty).toList();
  }

  Future<List<TvProgram>> _loadTimelineChannelGuide(
      String channel, String secretKey, DateTime targetDate) async {
    try {
      final template = _decodePayload(_oggiInTvTimelineUrlPayloadJson, secretKey);
      final date =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      final url = template.replaceAll('{date}', date);
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Sonarpad TV/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return [];
      }

      final target = normalizeChannelName(channel);
      final root = jsonDecode(response.body);
      if (root is! List) return [];

      final programs = <TvProgram>[];
      for (final group in root) {
        if (group is! List) continue;
        for (final item in group) {
          if (item is! Map<String, dynamic>) continue;
          final guideChannel = item['ch']?.toString().trim() ?? '';
          if (normalizeChannelName(guideChannel) != target) continue;
          final title = item['title']?.toString().trim() ?? '';
          if (title.isEmpty) continue;
          programs.add(TvProgram(
            title: title,
            hour: item['hour']?.toString().trim() ?? '',
            startTime: _readInt(item, 'startTime', 'start_time'),
            endTime: _readInt(item, 'endTime', 'end_time'),
          ));
        }
      }
      return programs;
    } catch (e) {
      dev.log('Errore caricamento timeline: $e');
      return [];
    }
  }

  Future<List<TvChannel>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((item) => TvChannel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      dev.log('Errore caricamento canali tv preferiti: $e');
      return [];
    }
  }

  Future<void> saveFavorites(List<TvChannel> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = favorites.map((ch) => ch.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }

  Future<String> resolveStreamUrl(TvChannel channel) async {
    var resolvedUrl = channel.url;
    await AppLogger.log('Inizio risoluzione stream per: ${channel.name} (URL base: $resolvedUrl)');

    if (resolvedUrl.contains('/relinker/relinkerServlet')) {
      final uri = Uri.parse(resolvedUrl);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      queryParams.remove('forceUserAgent');
      queryParams['output'] = '54'; // Richiede l'URL assoluto in plain text
      final reqUrl = uri.replace(queryParameters: queryParams).toString();
      
      await AppLogger.log('Interrogo il relinker RAI con output=54: $reqUrl');
      
      final response = await http.get(
        Uri.parse(reqUrl),
        headers: {'User-Agent': 'Sonarpad TV/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        await AppLogger.log('Errore HTTP ${response.statusCode} dal relinker');
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final body = response.body.trim();
      if (body.startsWith('http')) {
        resolvedUrl = body;
        await AppLogger.log('Relinker risolto in (output=54): $resolvedUrl');
      } else if (body.startsWith('#EXTM3U')) {
        await AppLogger.log('Il relinker ha risposto direttamente con un HLS (EXTM3U).');
        resolvedUrl = reqUrl;
      } else {
        final match = RegExp(r'<url[^>]*type="content"[^>]*>([^<]+)</url>')
                .firstMatch(body) ??
            RegExp(r'<url[^>]*>([^<]+)</url>').firstMatch(body);
        if (match != null) {
          resolvedUrl = match.group(1)!.trim();
          await AppLogger.log('Relinker risolto da XML: $resolvedUrl');
        } else {
          await AppLogger.log('URL non trovato nel relinker: $body');
          throw Exception('Stream TV non trovato nel relinker.');
        }
      }
    }

    return resolvedUrl;
  }

  /// Per i canali RAI con audiodescrizione, scarica il master playlist HLS
  /// e restituisce l'URI della traccia AD se presente, altrimenti l'URL principale.
  Future<String> resolveAudioDescriptionStreamUrl(TvChannel channel) async {
    final masterUrl = await resolveStreamUrl(channel);
    await AppLogger.log('Cerco traccia AD nel master URL: $masterUrl');
    
    try {
      final response = await http.get(
        Uri.parse(masterUrl),
        headers: {'User-Agent': 'Sonarpad TV/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        await AppLogger.log('Errore HTTP ${response.statusCode} scaricando master playlist.');
        return masterUrl;
      }

      final body = response.body;
      if (!body.trimLeft().startsWith('#EXTM3U')) {
        return masterUrl;
      }

      final finalMasterUrl = response.request?.url.toString() ?? masterUrl;
      if (finalMasterUrl != masterUrl) {
        await AppLogger.log('Redirect rilevato!\nOriginale: $masterUrl\nFinale: $finalMasterUrl');
      }

      String? adUrl;
      String? itaUrl;

      for (final line in body.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('#EXT-X-MEDIA:')) continue;

        final attrs = _parseHlsAttributes(trimmed.substring('#EXT-X-MEDIA:'.length));
        if (attrs['TYPE'] != 'AUDIO') continue;

        final uri = attrs['URI'];
        if (uri == null || uri.isEmpty) continue;

        final language = (attrs['LANGUAGE'] ?? '').toLowerCase();
        final name = (attrs['NAME'] ?? '').toLowerCase();
        final characteristics = attrs['CHARACTERISTICS'] ?? '';

        final isAudioDescription = language == 'des' ||
            name.contains('audiodescri') ||
            characteristics.contains('describes-video');

        if (isAudioDescription) {
          await AppLogger.log('Trovata traccia DESC:\nURI=$uri\nLang=$language\nName=$name');
          adUrl = _resolveHlsChildUrl(finalMasterUrl, uri);
          break; // AD trovata: precedenza assoluta, non cercare oltre
        }

        if (language == 'ita' && itaUrl == null) {
          await AppLogger.log('Trovata traccia ITA (fallback):\nURI=$uri');
          itaUrl = _resolveHlsChildUrl(finalMasterUrl, uri);
        }
      }

      return adUrl ?? itaUrl ?? masterUrl;
    } catch (e) {
      dev.log('TvService: errore ricerca traccia AD: $e');
      await AppLogger.log('Errore durante la ricerca della traccia AD: $e');
      return masterUrl;
    }
  }

  /// Risolve l'URI del manifest audio mantenendo i parametri query del master
  /// (necessario per non perdere i token di autenticazione RAI/Akamai).
  String _resolveHlsChildUrl(String masterUrl, String childUri) {
    if (childUri.startsWith('http://') || childUri.startsWith('https://')) {
      return childUri;
    }

    final masterUri = Uri.parse(masterUrl);
    var resolvedUri = masterUri.resolve(childUri);

    if (!resolvedUri.hasQuery && masterUri.hasQuery) {
      resolvedUri = resolvedUri.replace(query: masterUri.query);
    }
    
    final finalUrl = resolvedUri.toString();
    AppLogger.log('Risolto child URI:\nDa: $childUri\nA: $finalUrl');
    return finalUrl;
  }

  /// Parsa gli attributi di una riga HLS, ad esempio:
  ///   TYPE=AUDIO,GROUP-ID="aac",LANGUAGE="des",URI="audio.m3u8"
  Map<String, String> _parseHlsAttributes(String attrString) {
    final result = <String, String>{};
    final pattern = RegExp(r'([A-Z-]+)=(?:"([^"]*)"|(\S+?)(?:,|$))');
    for (final match in pattern.allMatches(attrString)) {
      final key = match.group(1)!;
      final value = match.group(2) ?? match.group(3) ?? '';
      result[key] = value;
    }
    return result;
  }

  int _readInt(Map<String, dynamic> item, String camelKey, String snakeKey) {
    final value = item[camelKey] ?? item[snakeKey];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String normalizeChannelName(String name) {
    var normalized = name
        .toLowerCase()
        .replaceAll('(dtt)', '')
        .replaceAll(' dtt', '')
        .replaceAll(' hd', '')
        .replaceAll('twenty seven', '27')
        .replaceAll('twentyseven', '27');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalized.endsWith('hd')) {
      normalized = normalized.substring(0, normalized.length - 2);
    }

    switch (normalized) {
      case 'la7dtt':
        return 'la7';
      case 'mediaset20':
      case '20mediaset':
        return '20';
      case 'mediaset27':
      case '27mediaset':
        return '27';
      case 'retequattro':
      case 'rete4mediaset':
      case 'mediasetrete4':
        return 'rete4';
      case 'canale5mediaset':
      case 'mediasetcanale5':
        return 'canale5';
      case 'italia1mediaset':
      case 'mediasetitalia1':
        return 'italia1';
      case 'italia2mediaset':
      case 'mediasetitalia2':
        return 'italia2';
      case 'sportitalialive24':
        return 'sportitalia';
      case 'virginradio':
        return 'virginradiotv';
      default:
        if (normalized.contains('rete4') ||
            normalized.contains('retequattro')) {
          return 'rete4';
        }
        return normalized;
    }
  }
}
