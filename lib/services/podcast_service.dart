import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/podcast.dart';

class PodcastService {
  static const _prefsKey = 'sonarpad_podcast_subscriptions';
  final http.Client _client;
  PodcastService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PodcastSubscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    return raw.map((e) => PodcastSubscription.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveSubscriptions(List<PodcastSubscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, subscriptions.map((e) => jsonEncode(e.toJson())).toList());
  }


  Future<List<PodcastSearchResult>> searchPodcasts(String query, {String country = 'IT'}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': q,
      'media': 'podcast',
      'entity': 'podcast',
      'country': country,
      'limit': '25',
    });
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ricerca podcast non riuscita: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>? ?? const []);
    return results.map((raw) {
      final item = raw as Map<String, dynamic>;
      final feedUrl = (item['feedUrl'] ?? '').toString();
      if (feedUrl.isEmpty) return null;
      return PodcastSearchResult(
        title: (item['collectionName'] ?? 'Podcast senza titolo').toString(),
        author: (item['artistName'] ?? '').toString(),
        feedUrl: feedUrl,
        artworkUrl: item['artworkUrl100']?.toString(),
      );
    }).whereType<PodcastSearchResult>().toList();
  }

  Future<PodcastSubscription> addSearchResult(PodcastSearchResult result) async {
    final sub = PodcastSubscription(
      title: result.title,
      feedUrl: result.feedUrl,
      artworkUrl: result.artworkUrl,
    );
    final list = await loadSubscriptions();
    if (!list.any((e) => e.feedUrl == result.feedUrl)) {
      await saveSubscriptions([...list, sub]);
    }
    return sub;
  }

  Future<PodcastSubscription> addSubscription(String feedUrl) async {
    final response = await _client.get(Uri.parse(feedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Feed non raggiungibile: ${response.statusCode}');
    }
    final doc = XmlDocument.parse(response.body);
    final channel = doc.findAllElements('channel').isNotEmpty ? doc.findAllElements('channel').first : null;
    final title = channel?.findElements('title').firstOrNull?.innerText.trim() ?? feedUrl;
    final sub = PodcastSubscription(title: title, feedUrl: feedUrl);
    final list = await loadSubscriptions();
    if (!list.any((e) => e.feedUrl == feedUrl)) {
      await saveSubscriptions([...list, sub]);
    }
    return sub;
  }

  Future<List<PodcastEpisode>> fetchEpisodes(PodcastSubscription subscription) async {
    final response = await _client.get(Uri.parse(subscription.feedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore feed podcast: ${response.statusCode}');
    }
    final doc = XmlDocument.parse(response.body);
    return doc.findAllElements('item').map((item) {
      final enclosure = item.findElements('enclosure').firstOrNull;
      final mediaContent = item.findAllElements('content', namespace: '*').firstOrNull;
      final audioUrl = enclosure?.getAttribute('url') ?? mediaContent?.getAttribute('url') ?? '';
      return PodcastEpisode(
        title: item.findElements('title').firstOrNull?.innerText.trim() ?? 'Episodio senza titolo',
        description: _cleanHtml(item.findElements('description').firstOrNull?.innerText ?? ''),
        audioUrl: audioUrl,
        publishedAt: null,
      );
    }).where((e) => e.audioUrl.isNotEmpty).toList();
  }

  Future<File> downloadEpisode(PodcastEpisode episode) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = episode.title.replaceAll(RegExp(r'[^a-zA-Z0-9àèéìòùÀÈÉÌÒÙ _.-]'), '_');
    final ext = p.extension(Uri.parse(episode.audioUrl).path).isEmpty ? '.mp3' : p.extension(Uri.parse(episode.audioUrl).path);
    final file = File(p.join(dir.path, '$safeTitle$ext'));
    final request = http.Request('GET', Uri.parse(episode.audioUrl));
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download non riuscito: ${response.statusCode}');
    }
    final sink = file.openWrite();
    await response.stream.pipe(sink);
    return file;
  }

  String _cleanHtml(String value) {
    final text = html_parser.parse(value).body?.text ?? value;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

extension FirstOrNullXml on Iterable<XmlElement> {
  XmlElement? get firstOrNull => isEmpty ? null : first;
}
