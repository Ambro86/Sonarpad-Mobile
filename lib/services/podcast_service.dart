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
  static const countries = [
    PodcastCountry('ae', 'Emirati Arabi Uniti'),
    PodcastCountry('al', 'Albania'),
    PodcastCountry('am', 'Armenia'),
    PodcastCountry('at', 'Austria'),
    PodcastCountry('au', 'Australia'),
    PodcastCountry('az', 'Azerbaigian'),
    PodcastCountry('bd', 'Bangladesh'),
    PodcastCountry('be', 'Belgio'),
    PodcastCountry('bg', 'Bulgaria'),
    PodcastCountry('bo', 'Bolivia'),
    PodcastCountry('bn', 'Brunei'),
    PodcastCountry('br', 'Brasile'),
    PodcastCountry('bt', 'Bhutan'),
    PodcastCountry('bw', 'Botswana'),
    PodcastCountry('ca', 'Canada'),
    PodcastCountry('ch', 'Svizzera'),
    PodcastCountry('ci', 'Costa d\'Avorio'),
    PodcastCountry('cl', 'Cile'),
    PodcastCountry('cm', 'Camerun'),
    PodcastCountry('cn', 'Cina'),
    PodcastCountry('co', 'Colombia'),
    PodcastCountry('cr', 'Costa Rica'),
    PodcastCountry('cy', 'Cipro'),
    PodcastCountry('cz', 'Repubblica Ceca'),
    PodcastCountry('dk', 'Danimarca'),
    PodcastCountry('do', 'Repubblica Dominicana'),
    PodcastCountry('dz', 'Algeria'),
    PodcastCountry('ee', 'Estonia'),
    PodcastCountry('ec', 'Ecuador'),
    PodcastCountry('eg', 'Egitto'),
    PodcastCountry('et', 'Etiopia'),
    PodcastCountry('fi', 'Finlandia'),
    PodcastCountry('fr', 'Francia'),
    PodcastCountry('de', 'Germania'),
    PodcastCountry('ge', 'Georgia'),
    PodcastCountry('gh', 'Ghana'),
    PodcastCountry('gr', 'Grecia'),
    PodcastCountry('gt', 'Guatemala'),
    PodcastCountry('hr', 'Croazia'),
    PodcastCountry('hk', 'Hong Kong'),
    PodcastCountry('hn', 'Honduras'),
    PodcastCountry('hu', 'Ungheria'),
    PodcastCountry('id', 'Indonesia'),
    PodcastCountry('in', 'India'),
    PodcastCountry('ie', 'Irlanda'),
    PodcastCountry('is', 'Islanda'),
    PodcastCountry('il', 'Israele'),
    PodcastCountry('it', 'Italia'),
    PodcastCountry('jp', 'Giappone'),
    PodcastCountry('jm', 'Giamaica'),
    PodcastCountry('jo', 'Giordania'),
    PodcastCountry('ke', 'Kenya'),
    PodcastCountry('kh', 'Cambogia'),
    PodcastCountry('kg', 'Kirghizistan'),
    PodcastCountry('kr', 'Corea del Sud'),
    PodcastCountry('kz', 'Kazakistan'),
    PodcastCountry('kw', 'Kuwait'),
    PodcastCountry('la', 'Laos'),
    PodcastCountry('lk', 'Sri Lanka'),
    PodcastCountry('lt', 'Lituania'),
    PodcastCountry('lb', 'Libano'),
    PodcastCountry('lu', 'Lussemburgo'),
    PodcastCountry('lv', 'Lettonia'),
    PodcastCountry('ma', 'Marocco'),
    PodcastCountry('mg', 'Madagascar'),
    PodcastCountry('ml', 'Mali'),
    PodcastCountry('mk', 'Macedonia del Nord'),
    PodcastCountry('mn', 'Mongolia'),
    PodcastCountry('mt', 'Malta'),
    PodcastCountry('mv', 'Maldive'),
    PodcastCountry('mx', 'Messico'),
    PodcastCountry('mu', 'Mauritius'),
    PodcastCountry('my', 'Malesia'),
    PodcastCountry('na', 'Namibia'),
    PodcastCountry('ng', 'Nigeria'),
    PodcastCountry('ni', 'Nicaragua'),
    PodcastCountry('nl', 'Paesi Bassi'),
    PodcastCountry('np', 'Nepal'),
    PodcastCountry('nz', 'Nuova Zelanda'),
    PodcastCountry('no', 'Norvegia'),
    PodcastCountry('pe', 'Peru'),
    PodcastCountry('pa', 'Panama'),
    PodcastCountry('ph', 'Filippine'),
    PodcastCountry('pk', 'Pakistan'),
    PodcastCountry('pl', 'Polonia'),
    PodcastCountry('pt', 'Portogallo'),
    PodcastCountry('py', 'Paraguay'),
    PodcastCountry('qa', 'Qatar'),
    PodcastCountry('ro', 'Romania'),
    PodcastCountry('rs', 'Serbia'),
    PodcastCountry('sa', 'Arabia Saudita'),
    PodcastCountry('sg', 'Singapore'),
    PodcastCountry('si', 'Slovenia'),
    PodcastCountry('sk', 'Slovacchia'),
    PodcastCountry('es', 'Spagna'),
    PodcastCountry('se', 'Svezia'),
    PodcastCountry('sn', 'Senegal'),
    PodcastCountry('sv', 'El Salvador'),
    PodcastCountry('th', 'Thailandia'),
    PodcastCountry('tn', 'Tunisia'),
    PodcastCountry('tr', 'Turchia'),
    PodcastCountry('tz', 'Tanzania'),
    PodcastCountry('tw', 'Taiwan'),
    PodcastCountry('ua', 'Ucraina'),
    PodcastCountry('ug', 'Uganda'),
    PodcastCountry('uz', 'Uzbekistan'),
    PodcastCountry('gb', 'Regno Unito'),
    PodcastCountry('us', 'Stati Uniti'),
    PodcastCountry('uy', 'Uruguay'),
    PodcastCountry('ve', 'Venezuela'),
    PodcastCountry('vn', 'Vietnam'),
    PodcastCountry('zm', 'Zambia'),
    PodcastCountry('zw', 'Zimbabwe'),
    PodcastCountry('ar', 'Argentina'),
  ];
  static const categories = [
    PodcastCategory(null, 'Tutte le categorie'),
    PodcastCategory(1301, 'Arti'),
    PodcastCategory(1321, 'Affari'),
    PodcastCategory(1303, 'Commedia'),
    PodcastCategory(1304, 'Istruzione'),
    PodcastCategory(1483, 'Narrativa'),
    PodcastCategory(1511, 'Governo'),
    PodcastCategory(1512, 'Salute e fitness'),
    PodcastCategory(1487, 'Storia'),
    PodcastCategory(1305, 'Bambini e famiglia'),
    PodcastCategory(1502, 'Tempo libero'),
    PodcastCategory(1310, 'Musica'),
    PodcastCategory(1489, 'Notizie'),
    PodcastCategory(1314, 'Religione e spiritualita'),
    PodcastCategory(1533, 'Scienza'),
    PodcastCategory(1324, 'Societa e cultura'),
    PodcastCategory(1545, 'Sport'),
    PodcastCategory(1318, 'Tecnologia'),
    PodcastCategory(1488, 'True crime'),
    PodcastCategory(1309, 'TV e film'),
  ];
  final http.Client _client;
  PodcastService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PodcastSubscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    return raw.map((e) => PodcastSubscription.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveSubscriptions(
      List<PodcastSubscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefsKey, subscriptions.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<List<PodcastSearchResult>> searchPodcasts(String query,
      {String country = 'it', PodcastCategory? category}) async {
    final q = query.trim();
    if (q.isEmpty && category?.genreId == null) return const [];
    final appleParams = {
      'media': 'podcast',
      'entity': 'podcast',
      'country': country,
      'limit': '25',
      if (q.isNotEmpty) 'term': q,
      if (category?.genreId != null) 'genreId': '${category!.genreId}',
    };
    final results = <PodcastSearchResult>[];
    final errors = <Object>[];
    try {
      results.addAll(await _searchApple(appleParams));
    } catch (e) {
      errors.add(e);
    }
    try {
      results.addAll(await _searchSpreaker(
        q.isEmpty ? category?.name ?? '' : q,
      ));
    } catch (e) {
      errors.add(e);
    }
    if (results.isEmpty && errors.isNotEmpty) {
      throw Exception(errors.join(' | '));
    }
    return _dedupResults(results);
  }

  Future<List<PodcastSearchResult>> _searchApple(
      Map<String, String> params) async {
    final uri = Uri.https('itunes.apple.com', '/search', params);
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ricerca podcast non riuscita: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>? ?? const []);
    return results
        .map((raw) {
          final item = raw as Map<String, dynamic>;
          final feedUrl = (item['feedUrl'] ?? '').toString();
          if (feedUrl.isEmpty) return null;
          return PodcastSearchResult(
            title:
                (item['collectionName'] ?? 'Podcast senza titolo').toString(),
            author: (item['artistName'] ?? '').toString(),
            feedUrl: feedUrl,
            artworkUrl: item['artworkUrl100']?.toString(),
          );
        })
        .whereType<PodcastSearchResult>()
        .toList();
  }

  Future<List<PodcastSearchResult>> _searchSpreaker(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('api.spreaker.com', '/v2/search', {
      'q': q,
      'type': 'shows',
      'limit': '20',
    });
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ricerca Spreaker non riuscita: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = decoded['response'] as Map<String, dynamic>? ?? const {};
    final results = payload['items'] as List<dynamic>? ?? const [];
    return results
        .map((raw) {
          final item = raw as Map<String, dynamic>;
          final showId = item['show_id']?.toString() ?? '';
          final title = (item['title'] ?? '').toString();
          if (showId.isEmpty || title.trim().isEmpty) return null;
          final image = item['image_url'] ?? item['site_url'];
          return PodcastSearchResult(
            title: title,
            author: (item['author_name'] ?? '').toString(),
            feedUrl: 'https://www.spreaker.com/show/$showId/episodes/feed',
            artworkUrl: image?.toString(),
          );
        })
        .whereType<PodcastSearchResult>()
        .toList();
  }

  List<PodcastSearchResult> _dedupResults(List<PodcastSearchResult> results) {
    final seenFeedUrls = <String>{};
    final seenTitles = <String>{};
    return results.where((result) {
      final feedKey = result.feedUrl.trim().toLowerCase();
      final titleKey =
          '${result.title.trim().toLowerCase()}|${result.author.trim().toLowerCase()}';
      if (seenFeedUrls.contains(feedKey) || seenTitles.contains(titleKey)) {
        return false;
      }
      seenFeedUrls.add(feedKey);
      seenTitles.add(titleKey);
      return true;
    }).toList();
  }

  Future<PodcastSubscription> addSearchResult(
      PodcastSearchResult result) async {
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

  Future<PodcastDetails> fetchPodcastDetails(PodcastSearchResult result) async {
    final response = await _client.get(Uri.parse(result.feedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Feed non raggiungibile: ${response.statusCode}');
    }
    final doc = XmlDocument.parse(utf8.decode(response.bodyBytes));
    final channel = doc.findAllElements('channel').firstOrNull;
    if (channel == null) {
      return PodcastDetails(
        title: result.title,
        author: result.author,
        description: '',
        feedUrl: result.feedUrl,
        artworkUrl: result.artworkUrl,
      );
    }

    final title = channel.findElements('title').firstOrNull?.innerText.trim();
    final description = _cleanHtml(
      channel.findElements('description').firstOrNull?.innerText ??
          channel
              .findAllElements('summary', namespace: '*')
              .firstOrNull
              ?.innerText ??
          '',
    );
    final author = channel
            .findAllElements('author', namespace: '*')
            .firstOrNull
            ?.innerText
            .trim() ??
        result.author;
    final artworkUrl = channel
            .findAllElements('image', namespace: '*')
            .firstOrNull
            ?.getAttribute('href') ??
        channel
            .findElements('image')
            .firstOrNull
            ?.findElements('url')
            .firstOrNull
            ?.innerText
            .trim() ??
        result.artworkUrl;

    return PodcastDetails(
      title: title?.isEmpty ?? true ? result.title : title!,
      author: author,
      description: description,
      feedUrl: result.feedUrl,
      artworkUrl: artworkUrl,
    );
  }

  Future<PodcastSubscription> addSubscription(String feedUrl) async {
    final response = await _client.get(Uri.parse(feedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Feed non raggiungibile: ${response.statusCode}');
    }
    final doc = XmlDocument.parse(utf8.decode(response.bodyBytes));
    final channel = doc.findAllElements('channel').isNotEmpty
        ? doc.findAllElements('channel').first
        : null;
    final title =
        channel?.findElements('title').firstOrNull?.innerText.trim() ?? feedUrl;
    final sub = PodcastSubscription(title: title, feedUrl: feedUrl);
    final list = await loadSubscriptions();
    if (!list.any((e) => e.feedUrl == feedUrl)) {
      await saveSubscriptions([...list, sub]);
    }
    return sub;
  }

  Future<void> removeSubscription(PodcastSubscription subscription) async {
    final list = await loadSubscriptions();
    list.removeWhere((e) => e.feedUrl == subscription.feedUrl);
    await saveSubscriptions(list);
  }

  Future<List<PodcastEpisode>> fetchEpisodes(
      PodcastSubscription subscription) async {
    final response = await _client.get(Uri.parse(subscription.feedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore feed podcast: ${response.statusCode}');
    }
    final doc = XmlDocument.parse(utf8.decode(response.bodyBytes));
    return doc
        .findAllElements('item')
        .map((item) {
          final enclosure = item.findElements('enclosure').firstOrNull;
          final mediaContent =
              item.findAllElements('content', namespace: '*').firstOrNull;
          final audioUrl = enclosure?.getAttribute('url') ??
              mediaContent?.getAttribute('url') ??
              '';
          return PodcastEpisode(
            title: item.findElements('title').firstOrNull?.innerText.trim() ??
                'Episodio senza titolo',
            description: _cleanHtml(
                item.findElements('description').firstOrNull?.innerText ?? ''),
            audioUrl: audioUrl,
            publishedAt: null,
          );
        })
        .where((e) => e.audioUrl.isNotEmpty)
        .toList();
  }

  Future<File> downloadEpisode(PodcastEpisode episode) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle =
        episode.title.replaceAll(RegExp(r'[^a-zA-Z0-9àèéìòùÀÈÉÌÒÙ _.-]'), '_');
    final ext = p.extension(Uri.parse(episode.audioUrl).path).isEmpty
        ? '.mp3'
        : p.extension(Uri.parse(episode.audioUrl).path);
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
