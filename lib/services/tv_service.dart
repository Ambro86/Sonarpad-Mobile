import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TvChannel {
  final String name;
  final String url;
  final String category;

  TvChannel({
    required this.name,
    required this.url,
    required this.category,
  });
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
  static const _staticKeyParts = ['sonar', 'pad-', 'SonarSecure-'];
  static const _la7StreamUrl = 'https://d1chghleocc9sm.cloudfront.net/v1/master/3722c60a815c199d9c0ef36c5b73da68a62b09d1/cc-evfku205gqrtf/Live.m3u8';
  
  static const _oggiInTvGuideUrlPayloadJson = r'''{"payload_b64":"csAxIXZQMnhMMiawFTr6bjtEskCkzkNJJ+Zweyc6I0xoq5wAQq2me+nsGOl55vyuggHwBZyk/4KnTrP2iV7rNEEN7i90j4pqQXbXPAgPICMLN0By","algorithm":"gzip-xor-base64-v1"}''';
  static const _tvChannelsPayloadJson = r'''{"payload_b64":"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","algorithm":"gzip-xor-base64-v1"}''';
  static const _regionalTvChannelsPayloadJson = r'''{"payload_b64":"csAxIXZQMnhMMo4nOUegdie+WUmPr85Uj4uCpYb+eOdb7HZeI0qNCD7T7Xlq+7Z34/VojdnssHYJrF8MsIN5yUmAdYLumBrJ3Y1fD74xbk4UyD4bsx3g1GAH6rS84/ksoTk2E5536VjBOx7IYFz//hI2DPNEaUMkNk3znFwDXVNEy6+Gs3OSPhzVG0YQg3Bp3eSj7+Wkpd4LYzxx8+P6woCB2UIxKrXej36b/GQGUDa4cAtnmqla69uoehBDRXsxpp4RqRyyEb2tNmQ3RJW5O0OAP5bLMLL7atRd6lJbLxaATCMxAitjohs7CnWm8GxiW/cpCuMxbLffbLf1U/FkojcCWoVMxjem+MWbDOpyuO3x5muELmrcBfSFOTGK+6DNBm7b8XfmwsQz3QmoQRHIYcfwje/j6a/9frT35X3LSJAB0+UwSVGeMvCSSyeQcTJY3NtQUPd59Qt0svtvFwdksay9OjgKmvZiPQ5k+4hsR/DPixpoUFDgJboB3rR9+kw2i1mzYuAt7dEazKqaDh9C4uZTFVroYKOYNLxcfPoDvLE4NM0LJo6uRuYotBkMQS6GKep2TCJciQi9d+cbBLcfoVRw3Yajra9G/ZLbihg22u50J3iLTuUkSfsUHWepqHC90J//JfXmqFYzNKCZe5KO5vtS6z6+F1P51ZkPdA1En4a3jokxcqsPFN38rlbpsXG4IuphfOeNxneAac0Cjxlm1p/E7BdAnZkWb0g/i8gTcTmVjP5/4OICFuz5mn3DHcnXD61/vpIBJVvcgr8JnPx3OuYCfkoBgt3XSOoVjd2rqOKYfZyj64RqZrXV2olVFmKSBjU+9aVCugpQaYSeOgOcaO3qhFh7lqmb1blGphnTTe0eV4EtT068jcyJlzeGZ9n9I7ZqIVodQZXSJwJnRFNQLXnn6d3g86kkH5uyX2+/GiEWGGMlNIHm4g/wnzFkRgr9R/OSo2Fn9slLaF5vcpsYVy7GQK+O7p3wN0eSRb3Y39Qbbz2LB58SAEU432sE7yI6wA4cHgit33noxPQWM2kGNWfSFvJILtsEpWMAJYJnmwxGTIQgLwJRjGnZ8nnBdaUpLNf7ap9EHcW3PdAjH2Hjs+EG9SGj6f6D/x9RGzuowx7Am1t4odnr+KqBC34Z7jhe3ixIhkEE5pqfiPnqheU6X5gG/OZMKymJwo2+uOSPdWsu7A2nUaHJyUuv2sKbPjxELlIfjs8cWK21XEvL5fk9wfo3KdGjQkDrRKo9dpJbEzDKsexZqrT9c+A3ELAhv6gIMI0TRLCApOyH3E9/hFv7uzzcd4W10GEzWaOz1BZ+pVZy0+NCEyrQeFJDS8FxorM/2VPCGIPgejoFJ/UcaJeYyEILf1ZwcHb0G/SmyQTBY7F4eLnhwbvnVehk6clOMa09b9Lk+vxkvSAGuAbTnN+ZQGRWuk77GmFgTyho/0tmf+5y0XUG7zm8FXEjH0yiGtHoO7jrCkXH+pRGTPi9gA3RKZkhlfOiwa2bVrk/6/VtUloaCv0hrS0mvPojNLr6SPFEQDayGWwEluc+TWqkJO9VdvTNXcVIDDBvPnm6WcvsyUkcPX4PnbDVm+w5mzvNd4e8B7jHWHJM","algorithm":"gzip-xor-base64-v1"}''';

  String _tvCategory(String name) {
    final n = name.toLowerCase().replaceAll(' ', '');
    if (n.startsWith('rai')) return 'Rai';
    if (n.startsWith('rete4') || n.startsWith('canale5') || n.startsWith('italia1') || n.startsWith('italia2') || n.startsWith('tgcom24') || n.startsWith('iris') || n.startsWith('la5') || n.startsWith('20') || n.startsWith('cine34') || n.startsWith('topcrime') || n.startsWith('focus') || n.startsWith('extra') || n.startsWith('boing') || n.startsWith('cartoon')) {
      return 'Mediaset';
    }
    return 'Altri';
  }

  bool isRaiAudioDescriptionChannel(TvChannel channel) {
    return (channel.name == 'Rai 1' || channel.name == 'Rai 2' || channel.name == 'Rai 3') &&
           channel.url.contains('mediapolis.rai.it/relinker/');
  }

  String _decodePayload(String jsonStr, String secretKey) {
    final Map<String, dynamic> payload = jsonDecode(jsonStr);
    final String algorithm = payload['algorithm'];
    if (algorithm != 'gzip-xor-base64-v1') {
      throw Exception('Algoritmo payload non supportato: $algorithm');
    }

    final String b64 = payload['payload_b64'];
    final List<int> encrypted = base64Decode(b64);

    final List<int> key = utf8.encode(secretKey).toList();
    for (var part in _staticKeyParts) {
      key.addAll(utf8.encode(part));
    }

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
      final regionalJson = _decodePayload(_regionalTvChannelsPayloadJson, secretKey.trim());
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

  Future<List<TvProgram>> loadChannelGuide(String channel, String secretKey) async {
    final template = _decodePayload(_oggiInTvGuideUrlPayloadJson, secretKey.trim());
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    var normalizedChannel = channel.toLowerCase()
        .replaceAll('(dtt)', '')
        .replaceAll(' dtt', '')
        .replaceAll(' hd', '')
        .replaceAll('twenty seven', '27')
        .replaceAll('twentyseven', '27');
    normalizedChannel = normalizedChannel.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalizedChannel.endsWith('hd')) {
      normalizedChannel = normalizedChannel.substring(0, normalizedChannel.length - 2);
    }
    
    switch (normalizedChannel) {
      case 'la7dtt': normalizedChannel = 'la7'; break;
      case 'mediaset20':
      case '20mediaset': normalizedChannel = '20'; break;
      case 'mediaset27':
      case '27mediaset': normalizedChannel = '27'; break;
      case 'retequattro':
      case 'rete4mediaset':
      case 'mediasetrete4': normalizedChannel = 'rete4'; break;
      case 'canale5mediaset':
      case 'mediasetcanale5': normalizedChannel = 'canale5'; break;
      case 'italia1mediaset':
      case 'mediasetitalia1': normalizedChannel = 'italia1'; break;
      case 'italia2mediaset':
      case 'mediasetitalia2': normalizedChannel = 'italia2'; break;
      case 'sportitalialive24': normalizedChannel = 'sportitalia'; break;
      case 'virginradio': normalizedChannel = 'virginradiotv'; break;
      default:
        if (normalizedChannel.contains('rete4') || normalizedChannel.contains('retequattro')) {
          normalizedChannel = 'rete4';
        }
    }

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
        startTime: item['start_time'] is int ? item['start_time'] as int : int.tryParse(item['start_time'].toString()) ?? 0,
        endTime: item['end_time'] is int ? item['end_time'] as int : int.tryParse(item['end_time'].toString()) ?? 0,
      ));
    }
    
    return programs.where((p) => p.title.isNotEmpty).toList();
  }
}
