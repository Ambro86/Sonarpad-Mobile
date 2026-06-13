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
  final String? streamResolver;
  final String? resolverEndpoint;
  final String? resolverRealm;
  final String? resolverChannelId;
  final String tvgId;
  final String tvgName;

  TvChannel({
    required this.name,
    required this.url,
    required this.category,
    this.streamResolver,
    this.resolverEndpoint,
    this.resolverRealm,
    this.resolverChannelId,
    this.tvgId = '',
    this.tvgName = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'category': category,
        'stream_resolver': streamResolver,
        'resolver_endpoint': resolverEndpoint,
        'resolver_realm': resolverRealm,
        'resolver_channel_id': resolverChannelId,
        'tvg_id': tvgId,
        'tvg_name': tvgName,
      };

  factory TvChannel.fromJson(Map<String, dynamic> json) => TvChannel(
        name: json['name'] as String,
        url: json['url'] as String,
        category: json['category'] as String? ?? 'Altri',
        streamResolver: json['stream_resolver'] as String?,
        resolverEndpoint: json['resolver_endpoint'] as String?,
        resolverRealm: json['resolver_realm'] as String?,
        resolverChannelId: json['resolver_channel_id'] as String?,
        tvgId: json['tvg_id']?.toString() ?? '',
        tvgName: json['tvg_name']?.toString() ?? '',
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
  static const _la7CinemaDashUrl =
      'https://d15umi5iaezxgx.cloudfront.net/HBBTV/LA7D/DASH/Live.mpd';

  static const _oggiInTvGuideUrlPayloadJson =
      r'''{"payload_b64":"csAxIXZQMnhMMiawFTr6bjtEskCkzkNJJ+Zweyc6I0xoq5wAQq2me+nsGOl55vyuggHwBZyk/4KnTrP2iV7rNEEN7i90j4pqQXbXPAgPICMLN0By","algorithm":"gzip-xor-base64-v1"}''';
  static const _oggiInTvTimelineUrlPayloadJson =
      r'''{"payload_b64":"csAxIXZQMnhMMuhZfR1S+OWXPRn4oJR5K4nkpYbgWGup/jgB+m6jPWForBe9oLtOwaBOreEeoqetOYbKLTxeLIC4fDkh4S9vy3U4I3E=","algorithm":"gzip-xor-base64-v1"}''';



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
      _decodePayload(_oggiInTvTimelineUrlPayloadJson, secretKey.trim());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<TvChannel>> loadChannels(String secretKey) async {
    if (secretKey.trim().isEmpty) return [];

    final channels = <TvChannel>[];

    try {
      final response = await http.get(
        Uri.parse(
            'https://sonarpad.com/api/tv_channels_resolver.php?resolve=0'),
        headers: {
          'X-Sonarpad-TV-Token':
              '__SONARPAD_ROUTE_CLIENT_TOKEN__',
          'X-Sonarpad-Route-Token': const String.fromEnvironment('SONARPAD_ROUTE_CLIENT_TOKEN'),
          'User-Agent': 'Sonarpad TV/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final mainData = jsonDecode(response.body);
        for (var ch in mainData['channels']) {
          final name = (ch['name'] as String)
              .replaceFirst(RegExp(r'^\[\d+\]\s*'), '')
              .trim();
          var url = (ch['url'] as String).trim();
          if (name == 'La7') url = _la7StreamUrl;
          if (name == 'La7 Cinema' || name == 'La7D' || name == 'LA7D') {
            url = _la7CinemaDashUrl;
          }
          if (name.isNotEmpty && url.isNotEmpty) {
              final gt = ch['group_title'] as String?;
              final cat = (gt == null || gt.trim().isEmpty) ? 'Altri' : gt.trim();
              
              channels.add(TvChannel(
              name: name,
              url: url,
              category: cat,
              streamResolver: ch['stream_resolver'] as String?,
              resolverEndpoint: ch['resolver_endpoint'] as String?,
              resolverRealm: ch['resolver_realm'] as String?,
              resolverChannelId: ch['resolver_channel_id'] as String?,
              tvgId: ch['tvg_id']?.toString() ?? '',
              tvgName: ch['tvg_name']?.toString() ?? '',
            ));
          }
        }
        if (channels.isNotEmpty) {
          dev.log('CANALI SCARICATI CON SUCCESSO DAL SERVER SONARPAD!');
          return channels;
        }
      }
      throw Exception('Nessun canale ricevuto dal server (status: ${response.statusCode})');
    } catch (e) {
      dev.log('Failed to load channels from network: $e');
      throw Exception('Impossibile scaricare i canali. Verifica la connessione internet e riprova.');
    }
  }

  Future<Map<String, TvProgram>> loadCurrentPrograms(String secretKey) async {
    final template =
        _decodePayload(_oggiInTvTimelineUrlPayloadJson, secretKey.trim());
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

  Future<List<TvProgram>> loadChannelGuide(String channel, String secretKey,
      {DateTime? targetDate}) async {
    final dt = targetDate ?? DateTime.now();

    // 1. Resolve exact channel name from timeline API
    String? exactChannelName;
    try {
      final timelineTemplate =
          _decodePayload(_oggiInTvTimelineUrlPayloadJson, secretKey.trim());
      final dateStr =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final timelineUrl = timelineTemplate.replaceAll('{date}', dateStr);
      final response = await http.get(Uri.parse(timelineUrl), headers: {
        'User-Agent': 'Sonarpad TV/1.0'
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final root = jsonDecode(response.body);
        if (root is List) {
          final targetNormalized = normalizeChannelName(channel);
          for (final group in root) {
            if (group is! List) continue;
            for (final item in group) {
              if (item is! Map<String, dynamic>) continue;
              final chName = item['ch']?.toString().trim() ?? '';
              if (normalizeChannelName(chName) == targetNormalized) {
                exactChannelName = chName;
                break;
              }
            }
            if (exactChannelName != null) break;
          }
        }
      }
    } catch (_) {}

    final targetChannelForApi = exactChannelName ?? channel;

    // Fallback sulla URL specifica per canale
    final template =
        _decodePayload(_oggiInTvGuideUrlPayloadJson, secretKey.trim());
    final date =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    final url = template
        .replaceAll('{channel}', Uri.encodeComponent(targetChannelForApi))
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

  List<String> guideLookupKeys(TvChannel channel) {
    final keys = <String>[];
    void add(String value) {
      final normalized = normalizeChannelName(value);
      if (normalized.isNotEmpty && !keys.contains(normalized)) {
        keys.add(normalized);
      }
    }

    add(channel.name);
    add(channel.tvgName);
    add(channel.tvgId);
    if (channel.tvgId.toLowerCase().endsWith('.it')) {
      add(channel.tvgId.substring(0, channel.tvgId.length - 3));
    }
    return keys;
  }

  String guideChannelName(TvChannel channel) {
    final tvgName = channel.tvgName.trim();
    if (tvgName.isNotEmpty) return tvgName;
    return channel.name;
  }

  Future<String> resolveStreamUrl(TvChannel channel) async {
    var resolvedUrl = channel.url;
    await AppLogger.log(
        'Inizio risoluzione stream per: ${channel.name} (URL base: $resolvedUrl)');
    // --- AUTORESOLVER DISCOVERY ---
    var effResolver = channel.streamResolver;
    var effChannelId = channel.resolverChannelId;
    
    final normName = normalizeChannelName(channel.name);
    final discoveryIds = {
      'realtime': '2',
      'nove': '3',
      'la9': '3',
      '9': '3',
      'dmax': '4',
      'foodnetwork': '6',
      'motortrend': '11',
      'discoverychannel': '12',
      'hgtv': '13',
      'k2': '24',
      'frisbee': '26',
      'giallo': '27',
      'giallotv': '27',
    };
    
    if (discoveryIds.containsKey(normName)) {
      effResolver = 'aurora_channel';
      effChannelId ??= discoveryIds[normName];
    }
    // ------------------------------

    if (effResolver == 'aurora_channel') {
      try {
        final endpoint =
            channel.resolverEndpoint ?? 'https://public.aurora.enhanced.live';
        final realm = channel.resolverRealm ?? 'it';
        final channelId = effChannelId;
        if (channelId != null) {
          final tokenUrl =
              '$endpoint/token?realm=${Uri.encodeComponent(realm)}';
          final baseHeaders = {
            'Accept': 'application/json,text/plain,*/*',
            'Content-Type': 'application/json',
            'Origin': 'https://nove.tv',
            'Referer': channel.url,
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
            'X-disco-client': 'WEB:UNKNOWN:wbdatv:2.1.9',
            'X-disco-params': 'realm=$realm',
            'X-Device-Info': 'STONEJS/1 (Unknown/Unknown; Windows/10; Unknown)'
          };
          final tokenResp =
              await http.get(Uri.parse(tokenUrl), headers: baseHeaders);
          if (tokenResp.statusCode == 200) {
            final tokenJson = jsonDecode(tokenResp.body);
            final token = tokenJson['data']?['attributes']?['token'];
            if (token != null) {
              final pbUrl = '$endpoint/playback/v3/channelPlaybackInfo';
              final pbHeaders = Map<String, String>.from(baseHeaders);
              pbHeaders['Authorization'] = 'Bearer $token';
              final pbBody = jsonEncode({
                'channelId': channelId,
                'deviceInfo': {
                  'adBlocker': false,
                  'drmSupported': true,
                  'hdrCapabilities': ['SDR'],
                  'hwDecodingCapabilities': [],
                  'soundCapabilities': ['STEREO'],
                },
                'wisteriaProperties': {
                  'device': {
                    'browser': {'name': 'chrome', 'version': '136'},
                    'type': 'desktop',
                  },
                  'platform': 'desktop',
                },
              });
              final pbResp = await http.post(Uri.parse(pbUrl),
                  headers: pbHeaders, body: pbBody);
              if (pbResp.statusCode == 200) {
                final match = RegExp(
                        'https?://[^\\s"\\\'<>\\\\]+?\\.m3u8[^\\s"\\\'<>\\\\]*')
                    .firstMatch(pbResp.body);
                if (match != null) {
                  final m3u8Url = match.group(0)!.replaceAll('\\/', '/');
                  await AppLogger.log('Aurora risolto: $m3u8Url');
                  return m3u8Url;
                }
              }
            }
          }
        }
      } catch (e) {
        await AppLogger.log('Errore resolver aurora: $e');
      }
    }

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
        await AppLogger.log(
            'Il relinker ha risposto direttamente con un HLS (EXTM3U).');
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

  static bool isDashStreamUrl(String url) {
    final parsed = Uri.tryParse(url);
    final path = (parsed?.path ?? url).toLowerCase();
    return path.endsWith('.mpd');
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
        await AppLogger.log(
            'Errore HTTP ${response.statusCode} scaricando master playlist.');
        return masterUrl;
      }

      final body = response.body;
      if (!body.trimLeft().startsWith('#EXTM3U')) {
        return masterUrl;
      }

      final finalMasterUrl = response.request?.url.toString() ?? masterUrl;
      if (finalMasterUrl != masterUrl) {
        await AppLogger.log(
            'Redirect rilevato!\nOriginale: $masterUrl\nFinale: $finalMasterUrl');
      }

      String? adUrl;
      String? itaUrl;

      for (final line in body.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('#EXT-X-MEDIA:')) continue;

        final attrs =
            _parseHlsAttributes(trimmed.substring('#EXT-X-MEDIA:'.length));
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
          await AppLogger.log(
              'Trovata traccia DESC:\nURI=$uri\nLang=$language\nName=$name');
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
        .replaceFirst(RegExp(r'^\s*\[\d+\]\s*'), '')
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
