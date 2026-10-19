import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import '../models/podcast.dart';
import '../utils/app_logger.dart';

class TgcomVideo {
  const TgcomVideo({
    required this.guid,
    required this.title,
    required this.description,
  });
  final String guid, title, description;
}

/// Resolves the public video associated with a TGcom video article, on demand.
/// Expiring media URLs are never persisted or written to diagnostics.
class TgcomVideoService {
  TgcomVideoService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  void dispose() => _client.close();

  static bool supports(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        const {
          'www.tgcom24.mediaset.it',
          'tgcom24.mediaset.it',
        }.contains(uri.host) &&
        uri.path.contains('/video/');
  }

  Future<TgcomVideo?> fetch(String url) async {
    if (!supports(url)) return null;
    final response = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    AppLogger.log('News TGcom video: metadata HTTP ${response.statusCode}');
    if (response.statusCode != 200) return null;
    return parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  static TgcomVideo? parse(String source) {
    final document = html.parse(source);
    final objects = <Map>[];
    void collect(Object? value) {
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
      } else if (value is Map) {
        objects.add(value);
        collect(value['@graph']);
      }
    }

    for (final script in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      try {
        collect(jsonDecode(script.text));
      } on FormatException {
        /* Other structured data can still be valid. */
      }
    }
    bool hasType(Map value, String type) =>
        value['@type'] == type ||
        (value['@type'] is List && (value['@type'] as List).contains(type));
    String clean(Object? value) =>
        html.parseFragment(value is String ? value : '').text?.trim() ?? '';
    for (final video in objects.where((v) => hasType(v, 'VideoObject'))) {
      final finder = Uri.tryParse(video['contentUrl']?.toString() ?? '');
      if (finder == null ||
          finder.scheme != 'https' ||
          finder.host != 'link-ott-prod.mediaset.net') {
        continue;
      }
      final match = RegExp(
        r'^/finder/(F[A-Z][0-9]{14})$',
      ).firstMatch(finder.path);
      if (match == null) continue;
      var description = clean(video['description']);
      for (final article in objects.where((v) => hasType(v, 'NewsArticle'))) {
        final body = clean(article['articleBody']);
        if (body.isNotEmpty) {
          description = body;
          break;
        }
      }
      return TgcomVideo(
        guid: match.group(1)!,
        title: clean(video['name']),
        description: description,
      );
    }
    return null;
  }

  Future<PodcastEpisode> resolve(TgcomVideo video) async {
    if (!RegExp(r'^F[A-Z][0-9]{14}$').hasMatch(video.guid)) {
      throw const FormatException('Invalid media ID');
    }
    final watch = Stopwatch()..start();
    var uri = Uri.https(
      'link.theplatform.eu',
      '/s/PR1GhC/media/guid/2702976343/${video.guid}',
      {'mbr': 'true', 'formats': 'M3U'},
    );
    AppLogger.log('News TGcom video: resolve started id=${video.guid}');
    for (var redirects = 0; redirects <= 5; redirects++) {
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final body = await response.stream.bytesToString().timeout(
        const Duration(seconds: 15),
      );
      AppLogger.log(
        'News TGcom video: resolve HTTP ${response.statusCode} host=${uri.host} step=$redirects elapsedMs=${watch.elapsedMilliseconds}',
      );
      if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers['location'];
        if (location == null) {
          throw const FormatException('Missing media redirect');
        }
        uri = uri.resolve(location);
        if (uri.scheme != 'https' ||
            !(uri.host.endsWith('.mediaset.net') ||
                uri.host == 'link.theplatform.eu')) {
          throw const FormatException('Unexpected media destination');
        }
        continue;
      }
      if (response.statusCode != 200 ||
          !body.trimLeft().startsWith('#EXTM3U')) {
        throw const FormatException('Video stream unavailable');
      }
      return PodcastEpisode(
        id: 'news-video:${video.guid}',
        title: video.title,
        description: video.description,
        audioUrl: uri.toString(),
        videoUrl: uri.toString(),
      );
    }
    throw const FormatException('Too many media redirects');
  }
}
