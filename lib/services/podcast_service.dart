import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/podcast.dart';
import 'raiplay_sound_service.dart';
import 'podcast_cache_service.dart';

typedef EmbeddedPodcastChapterLoader = Future<List<PodcastChapter>> Function(
  String mediaUrl,
);

class PodcastService {
  String _getPlayedEpisodesKey(String feedUrl) => 'sonarpad_played_episodes_$feedUrl';

  Future<List<PodcastEpisode>> getPlayedEpisodes(String feedUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getStringList(_getPlayedEpisodesKey(feedUrl)) ?? [];
    final list = <PodcastEpisode>[];
    for (final str in listStr) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        list.add(PodcastEpisode(
          title: decoded['title'] ?? '',
          description: decoded['description'] ?? '',
          audioUrl: decoded['audioUrl'] ?? '',
          publishedAt: decoded['publishedAt'] != null ? DateTime.parse(decoded['publishedAt']) : null,
          chaptersUrl: decoded['chaptersUrl'] as String?,
          chaptersType: decoded['chaptersType'] as String?,
        ));
      } catch (_) {}
    }
    return list;
  }

  Future<void> markEpisodeAsPlayed(String feedUrl, PodcastEpisode episode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getPlayedEpisodesKey(feedUrl);
    var current = await getPlayedEpisodes(feedUrl);
    
    // Rimuovi se c'è già
    current.removeWhere((e) => e.audioUrl == episode.audioUrl);
    
    // Aggiungi in cima
    current.insert(0, episode);
    
    // Tieni massimo 100
    if (current.length > 100) {
      current = current.sublist(0, 100);
    }
    
    final encoded = current.map((e) => jsonEncode({
      'title': e.title,
      'description': e.description,
      'audioUrl': e.audioUrl,
      'publishedAt': e.publishedAt?.toIso8601String(),
      'chaptersUrl': e.chaptersUrl,
      'chaptersType': e.chaptersType,
    })).toList();
    
    await prefs.setStringList(key, encoded);
  }

  Future<void> clearPlayedEpisodes(String feedUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getPlayedEpisodesKey(feedUrl));
  }

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
    PodcastCategory(null),
    PodcastCategory(1301),
    PodcastCategory(1321),
    PodcastCategory(1303),
    PodcastCategory(1304),
    PodcastCategory(1483),
    PodcastCategory(1511),
    PodcastCategory(1512),
    PodcastCategory(1487),
    PodcastCategory(1305),
    PodcastCategory(1502),
    PodcastCategory(1310),
    PodcastCategory(1489),
    PodcastCategory(1314),
    PodcastCategory(1533),
    PodcastCategory(1324),
    PodcastCategory(1545),
    PodcastCategory(1318),
    PodcastCategory(1488),
    PodcastCategory(1309),
    PodcastCategory(1482),
    PodcastCategory(1402),
    PodcastCategory(1459),
    PodcastCategory(1306),
    PodcastCategory(1405),
    PodcastCategory(1406),
    PodcastCategory(1410),
    PodcastCategory(1493),
    PodcastCategory(1412),
    PodcastCategory(1491),
    PodcastCategory(1492),
    PodcastCategory(1494),
    PodcastCategory(1496),
    PodcastCategory(1495),
    PodcastCategory(1497),
    PodcastCategory(1501),
    PodcastCategory(1499),
    PodcastCategory(1498),
    PodcastCategory(1500),
    PodcastCategory(1486),
    PodcastCategory(1484),
    PodcastCategory(1485),
    PodcastCategory(1513),
    PodcastCategory(1514),
    PodcastCategory(1518),
    PodcastCategory(1517),
    PodcastCategory(1515),
    PodcastCategory(1516),
    PodcastCategory(1519),
    PodcastCategory(1521),
    PodcastCategory(1522),
    PodcastCategory(1520),
    PodcastCategory(1510),
    PodcastCategory(1503),
    PodcastCategory(1504),
    PodcastCategory(1506),
    PodcastCategory(1507),
    PodcastCategory(1505),
    PodcastCategory(1508),
    PodcastCategory(1509),
    PodcastCategory(1523),
    PodcastCategory(1524),
    PodcastCategory(1525),
    PodcastCategory(1490),
    PodcastCategory(1526),
    PodcastCategory(1531),
    PodcastCategory(1530),
    PodcastCategory(1527),
    PodcastCategory(1529),
    PodcastCategory(1528),
    PodcastCategory(1438),
    PodcastCategory(1439),
    PodcastCategory(1463),
    PodcastCategory(1440),
    PodcastCategory(1441),
    PodcastCategory(1532),
    PodcastCategory(1444),
    PodcastCategory(1538),
    PodcastCategory(1539),
    PodcastCategory(1540),
    PodcastCategory(1541),
    PodcastCategory(1536),
    PodcastCategory(1534),
    PodcastCategory(1537),
    PodcastCategory(1542),
    PodcastCategory(1535),
    PodcastCategory(1543),
    PodcastCategory(1302),
    PodcastCategory(1443),
    PodcastCategory(1320),
    PodcastCategory(1544),
    PodcastCategory(1549),
    PodcastCategory(1548),
    PodcastCategory(1554),
    PodcastCategory(1560),
    PodcastCategory(1547),
    PodcastCategory(1553),
    PodcastCategory(1550),
    PodcastCategory(1552),
    PodcastCategory(1551),
    PodcastCategory(1546),
    PodcastCategory(1558),
    PodcastCategory(1556),
    PodcastCategory(1557),
    PodcastCategory(1559),
    PodcastCategory(1555),
    PodcastCategory(1562),
    PodcastCategory(1564),
    PodcastCategory(1565),
    PodcastCategory(1563),
    PodcastCategory(1561),
  ];
  final http.Client _client;
  final EmbeddedPodcastChapterLoader? _embeddedChapterLoader;

  PodcastService({
    http.Client? client,
    EmbeddedPodcastChapterLoader? embeddedChapterLoader,
  })  : _client = client ?? http.Client(),
        _embeddedChapterLoader = embeddedChapterLoader;

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

  Future<int> importSubscriptionsFromOpml(File file) async {
    final text = await file.readAsString();
    final document = XmlDocument.parse(text);
    final imported = <PodcastSubscription>[];

    for (final outline in document.findAllElements('outline')) {
      final feedUrl = _opmlAttribute(outline, 'xmlUrl')?.trim();
      if (feedUrl == null || feedUrl.isEmpty) continue;
      final titleAttr = _opmlAttribute(outline, 'title')?.trim();
      final textAttr = _opmlAttribute(outline, 'text')?.trim();
      final title = titleAttr?.isNotEmpty == true ? titleAttr : textAttr;
      imported.add(PodcastSubscription(
        title: title == null || title.isEmpty ? feedUrl : title,
        feedUrl: feedUrl,
      ));
    }

    if (imported.isEmpty) return 0;

    final current = await loadSubscriptions();
    final seen = current.map((e) => e.feedUrl.trim().toLowerCase()).toSet();
    final toAdd = <PodcastSubscription>[];
    for (final subscription in imported) {
      final key = subscription.feedUrl.trim().toLowerCase();
      if (seen.add(key)) {
        toAdd.add(subscription);
      }
    }

    if (toAdd.isEmpty) return 0;
    await saveSubscriptions([...current, ...toAdd]);
    return toAdd.length;
  }

  Future<String> exportSubscriptionsToOpml() async {
    final subscriptions = await loadSubscriptions();
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<opml version="1.0">')
      ..writeln('<head>')
      ..writeln('<title>Sonarpad Podcasts</title>')
      ..writeln('</head>')
      ..writeln('<body>');

    for (final subscription in subscriptions) {
      final title = _escapeOpmlAttribute(subscription.title);
      final url = _escapeOpmlAttribute(subscription.feedUrl);
      buffer.writeln(
        '  <outline text="$title" title="$title" type="rss" xmlUrl="$url" />',
      );
    }

    buffer
      ..writeln('</body>')
      ..writeln('</opml>');
    return buffer.toString();
  }

  String? _opmlAttribute(XmlElement element, String name) {
    for (final attribute in element.attributes) {
      if (attribute.name.local.toLowerCase() == name.toLowerCase()) {
        return attribute.value;
      }
    }
    return null;
  }

  String _escapeOpmlAttribute(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll("'", '&apos;');
  }

  Future<List<PodcastSearchResult>> searchPodcasts(String query,
      {String? country = 'it', PodcastCategory? category}) async {
    final q = query.trim();
    final genreId = category?.genreId;
    final topCountry = country ?? 'us';
    final appleParams = {
      'media': 'podcast',
      'entity': 'podcast',
      'country': ?country,
      'limit': '25',
      if (q.isNotEmpty) 'term': q,
      if (genreId != null) 'genreId': '$genreId',
    };
    final results = <PodcastSearchResult>[];
    final errors = <Object>[];
    Object? topByGenreError;
    if (q.isEmpty) {
      try {
        results.addAll(genreId == null
            ? await _searchAppleTopByCountry(topCountry)
            : await _searchAppleTopByGenre(genreId, topCountry));
      } catch (e) {
        topByGenreError = e;
      }
    }
    if (q.isNotEmpty || genreId != null) {
      try {
        results.addAll(await _searchApple(appleParams));
      } catch (e) {
        if (topByGenreError != null) errors.add(topByGenreError);
        errors.add(e);
      }
    } else if (topByGenreError != null) {
      errors.add(topByGenreError);
    }
    if (q.isNotEmpty) {
      try {
        results.addAll(await _searchSpreaker(q));
      } catch (e) {
        errors.add(e);
      }
    }
    if (results.isEmpty && errors.isNotEmpty) {
      throw Exception(errors.join(' | '));
    }
    return _dedupResults(results);
  }

  Future<List<PodcastSearchResult>> _searchApple(
      Map<String, String> params) async {
    final uri = Uri.https('itunes.apple.com', '/search', params);
    final results = await _fetchAppleItems(uri, 'Ricerca podcast non riuscita');
    return _appleItemsToResults(results);
  }

  Future<List<Map<String, dynamic>>> _fetchAppleItems(
      Uri uri, String errorMessage) async {
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$errorMessage: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>? ?? const []);
    return results.cast<Map<String, dynamic>>();
  }

  List<PodcastSearchResult> _appleItemsToResults(
      List<Map<String, dynamic>> results) {
    return results
        .map((item) {
          final feedUrl = (item['feedUrl'] ?? '').toString();
          if (feedUrl.isEmpty) return null;
          return PodcastSearchResult(
            title:
                (item['collectionName'] ?? 'Podcast').toString(),
            author: (item['artistName'] ?? '').toString(),
            feedUrl: feedUrl,
            artworkUrl: item['artworkUrl100']?.toString(),
          );
        })
        .whereType<PodcastSearchResult>()
        .toList();
  }

  Future<List<PodcastSearchResult>> _searchAppleTopByCountry(
      String country) async {
    final uri = Uri.parse('https://itunes.apple.com/$country/rss/toppodcasts/'
        'limit=50/json');
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Podcast per nazione non raggiungibili: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final feed = decoded['feed'] as Map<String, dynamic>? ?? const {};
    final rawEntries = feed['entry'];
    final entries = rawEntries is List
        ? rawEntries
        : rawEntries == null
            ? const []
            : [rawEntries];
    final ids = entries
        .map((raw) {
          final entry = raw as Map<String, dynamic>;
          final id = entry['id'] as Map<String, dynamic>? ?? const {};
          final attributes =
              id['attributes'] as Map<String, dynamic>? ?? const {};
          return attributes['im:id']?.toString();
        })
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return const [];
    final lookupUri = Uri.https('itunes.apple.com', '/lookup', {
      'id': ids.join(','),
      'country': country,
    });
    final lookup =
        await _fetchAppleItems(lookupUri, 'Lookup podcast non riuscito');
    return _appleItemsToResults(lookup);
  }

  Future<List<PodcastSearchResult>> _searchAppleTopByGenre(
      int genreId, String country) async {
    final uri = Uri.parse('https://itunes.apple.com/$country/rss/toppodcasts/'
        'limit=50/genre=$genreId/json');
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Categorie podcast non raggiungibili: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final feed = decoded['feed'] as Map<String, dynamic>? ?? const {};
    final rawEntries = feed['entry'];
    final entries = rawEntries is List
        ? rawEntries
        : rawEntries == null
            ? const []
            : [rawEntries];
    final ids = entries
        .map((raw) {
          final entry = raw as Map<String, dynamic>;
          final id = entry['id'] as Map<String, dynamic>? ?? const {};
          final attributes =
              id['attributes'] as Map<String, dynamic>? ?? const {};
          return attributes['im:id']?.toString();
        })
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return const [];
    final lookupUri = Uri.https('itunes.apple.com', '/lookup', {
      'id': ids.join(','),
      'country': country,
    });
    final lookup =
        await _fetchAppleItems(lookupUri, 'Lookup podcast non riuscito');
    final filtered =
        lookup.where((item) => _appleItemMatchesGenre(item, genreId)).toList();
    return _appleItemsToResults(filtered.isEmpty ? lookup : filtered);
  }

  bool _appleItemMatchesGenre(Map<String, dynamic> item, int genreId) {
    if (item['primaryGenreId']?.toString() == '$genreId') return true;
    final genreIds = item['genreIds'];
    if (genreIds is List) {
      return genreIds.any((id) => id.toString() == '$genreId');
    }
    return false;
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
    if (_isRaiPlaySoundUrl(feedUrl)) {
      final page = await RaiPlaySoundService().loadPage(feedUrl);
      final sub = PodcastSubscription(title: page.title, feedUrl: feedUrl);
      final list = await loadSubscriptions();
      if (!list.any((e) => e.feedUrl == feedUrl)) {
        await saveSubscriptions([...list, sub]);
      }
      return sub;
    }

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
    if (_isRaiPlaySoundUrl(subscription.feedUrl)) {
      return _fetchRaiPlaySoundEpisodes(subscription.feedUrl);
    }

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
          final chaptersLink = _extractPodcastChaptersLink(
            item,
            subscription.feedUrl,
          );
          return PodcastEpisode(
            title: item.findElements('title').firstOrNull?.innerText.trim() ??
                '—',
            description: _cleanHtml(
                item.findElements('description').firstOrNull?.innerText ?? ''),
            audioUrl: audioUrl,
            publishedAt: _parsePodcastDate(
                item.findElements('pubDate').firstOrNull?.innerText ?? ''),
            chaptersUrl: chaptersLink?.url,
            chaptersType: chaptersLink?.type,
          );
        })
        .where((e) => e.audioUrl.isNotEmpty)
        .toList();
  }

  Future<List<PodcastEpisode>> _fetchRaiPlaySoundEpisodes(String url) async {
    final page = await RaiPlaySoundService().loadPage(url);
    return page.items
        .where((item) => item.kind == RaiPlaySoundItemKind.audio)
        .map((item) {
          var audioUrl = item.audioUrl;
          if (!audioUrl.startsWith('http')) {
            final baseUri = Uri.parse(url);
            audioUrl = baseUri.resolve(audioUrl).toString();
          }
          return PodcastEpisode(
            title: item.title,
            description: item.description,
            audioUrl: audioUrl,
            id: 'raiplaysound:${item.id}',
            publishedAt: null,
          );
        })
        .where((episode) => episode.audioUrl.trim().isNotEmpty)
        .toList();
  }

  bool _isRaiPlaySoundUrl(String url) {
    return url.trim().toLowerCase().contains('raiplaysound.it');
  }

  DateTime? _parsePodcastDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      return HttpDate.parse(trimmed).toLocal();
    } catch (_) {}

    final rfc822Match = RegExp(
      r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+'
      r'([A-Za-z]{3})\s+'
      r'(\d{4})\s+'
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s+'
      r'([A-Za-z]{1,5}|[+-]\d{4})',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (rfc822Match != null) {
      final months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = months[rfc822Match.group(2)!.toLowerCase()];
      if (month != null) {
        final localLikeUtc = DateTime.utc(
          int.parse(rfc822Match.group(3)!),
          month,
          int.parse(rfc822Match.group(1)!),
          int.parse(rfc822Match.group(4)!),
          int.parse(rfc822Match.group(5)!),
          int.parse(rfc822Match.group(6) ?? '0'),
        );
        final zone = rfc822Match.group(7)!.toUpperCase();
        var offset = Duration.zero;
        final numericZone = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(zone);
        if (numericZone != null) {
          final minutes = int.parse(numericZone.group(2)!) * 60 +
              int.parse(numericZone.group(3)!);
          offset = Duration(
            minutes: numericZone.group(1) == '+' ? minutes : -minutes,
          );
        }
        return localLikeUtc.subtract(offset).toLocal();
      }
    }

    try {
      return DateTime.parse(trimmed).toLocal();
    } catch (_) {}
    return null;
  }


  Future<List<PodcastChapter>> fetchEpisodeChapters(PodcastEpisode episode) async {
    final candidates = <String>[];
    void addCandidate(String? url) {
      final trimmed = url?.trim();
      if (trimmed == null || trimmed.isEmpty) return;
      if (!candidates.any((candidate) => candidate == trimmed)) {
        candidates.add(trimmed);
      }
    }

    addCandidate(episode.chaptersUrl);
    addCandidate(extractEmbeddedChaptersUrl(episode.audioUrl));
    addCandidate(extractBuzzsproutChaptersUrl(episode.audioUrl));

    for (final url in candidates) {
      try {
        final response = await _client.get(Uri.parse(url));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final chapters = _parsePodcastChaptersJson(response.bodyBytes);
        if (chapters.isNotEmpty) {
          return chapters;
        }
      } catch (_) {
        // Prova il candidato successivo. Alcuni feed dichiarano link capitoli
        // non sempre raggiungibili o protetti da CDN.
      }
    }

    try {
      return await (_embeddedChapterLoader ?? _loadEmbeddedMediaChapters)(
        episode.audioUrl,
      );
    } catch (_) {
      // I capitoli incorporati sono un miglioramento opzionale: un formato non
      // supportato o un server che rifiuta FFprobe non deve bloccare il player.
      return const [];
    }
  }

  bool hasChapterSource(PodcastEpisode episode) {
    return (episode.chaptersUrl?.trim().isNotEmpty ?? false) ||
        extractEmbeddedChaptersUrl(episode.audioUrl) != null ||
        extractBuzzsproutChaptersUrl(episode.audioUrl) != null;
  }

  Future<List<PodcastChapter>> _loadEmbeddedMediaChapters(
    String mediaUrl,
  ) async {
    final session = await FFprobeKit.getMediaInformation(mediaUrl, 15000);
    final mediaInformation = session.getMediaInformation();
    if (mediaInformation == null) return const [];
    return parseEmbeddedMediaChapters(
      mediaInformation.getChapters().map((chapter) {
        return Map<dynamic, dynamic>.from(
          chapter.getAllProperties() ?? const <dynamic, dynamic>{},
        );
      }),
    );
  }

  List<PodcastChapter> parseEmbeddedMediaChapters(
    Iterable<Map<dynamic, dynamic>> rawChapters,
  ) {
    final chapters = <PodcastChapter>[];
    for (final raw in rawChapters) {
      final start = _parseChapterStartTime(raw['start_time']);
      if (start == null || start < Duration.zero) continue;
      final rawTags = raw['tags'];
      String? title;
      if (rawTags is Map) {
        for (final entry in rawTags.entries) {
          if (entry.key.toString().toLowerCase() != 'title') continue;
          final candidate = entry.value?.toString().trim();
          if (candidate != null && candidate.isNotEmpty) title = candidate;
          break;
        }
      }
      if (title == null) continue;
      chapters.add(PodcastChapter(start: start, title: title));
    }
    chapters.sort((a, b) => a.start.compareTo(b.start));
    final deduped = <PodcastChapter>[];
    Duration? lastStart;
    for (final chapter in chapters) {
      if (chapter.start == lastStart) continue;
      deduped.add(chapter);
      lastStart = chapter.start;
    }
    return deduped;
  }

  String? extractEmbeddedChaptersUrl(String url) {
    const marker = '/chapters/';
    final idx = url.lastIndexOf(marker);
    if (idx < 0) return null;
    final tail = url.substring(idx + marker.length);
    if (tail.startsWith('http://') || tail.startsWith('https://')) {
      return tail;
    }
    return null;
  }

  String? extractBuzzsproutChaptersUrl(String url) {
    // Supporta URL Buzzsprout diretti e URL wrappati, come op3.dev/.../www.buzzsprout.com/...
    const marker = '/episodes/';
    final episodeIdx = url.indexOf(marker);
    if (episodeIdx < 0) return null;
    final before = url.substring(0, episodeIdx);
    String? showId;
    for (final segment in before.split('/').reversed) {
      if (segment.isNotEmpty && RegExp(r'^[0-9]+$').hasMatch(segment)) {
        showId = segment;
        break;
      }
    }
    if (showId == null) return null;
    final after = url.substring(episodeIdx + marker.length);
    final match = RegExp(r'^[0-9]+').firstMatch(after);
    final episodeId = match?.group(0);
    if (episodeId == null || episodeId.isEmpty) return null;
    return 'https://www.buzzsprout.com/$showId/$episodeId/chapters.json';
  }

  _PodcastChaptersLink? _extractPodcastChaptersLink(
    XmlElement item,
    String feedUrl,
  ) {
    for (final element in item.findAllElements('chapters', namespace: '*')) {
      final url = element.getAttribute('url') ?? element.getAttribute('href');
      final resolved = _resolvePodcastUrl(feedUrl, url);
      if (resolved != null) {
        return _PodcastChaptersLink(
          resolved,
          element.getAttribute('type'),
        );
      }
    }

    for (final link in item.findAllElements('link', namespace: '*')) {
      final href = link.getAttribute('href');
      if (href == null || href.trim().isEmpty) continue;
      final rel = (link.getAttribute('rel') ?? '').toLowerCase();
      final type = link.getAttribute('type');
      final hrefLower = href.toLowerCase();
      final typeLower = (type ?? '').toLowerCase();
      final looksLikeChapters = rel.contains('chapter') ||
          hrefLower.contains('/chapters/') ||
          hrefLower.contains('chapters.json') ||
          hrefLower.contains('chapter') ||
          (typeLower.contains('json') &&
              (rel.contains('podcast') || hrefLower.contains('chapter')));
      if (!looksLikeChapters) continue;
      final resolved = _resolvePodcastUrl(feedUrl, href);
      if (resolved != null) {
        return _PodcastChaptersLink(resolved, type);
      }
    }

    return null;
  }

  String? _resolvePodcastUrl(String feedUrl, String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      return Uri.parse(feedUrl).resolve(trimmed).toString();
    } catch (_) {
      return trimmed;
    }
  }

  List<PodcastChapter> _parsePodcastChaptersJson(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) return const [];
    final rawChapters = decoded['chapters'];
    if (rawChapters is! List) return const [];
    final chapters = <PodcastChapter>[];
    for (final raw in rawChapters) {
      if (raw is! Map) continue;
      final start = _parseChapterStartTime(raw['startTime']);
      if (start == null || start < Duration.zero) continue;
      final title = raw['title']?.toString().trim();
      if (title == null || title.isEmpty) continue;
      final url = raw['url']?.toString().trim();
      final image = (raw['img'] ?? raw['image'])?.toString().trim();
      chapters.add(PodcastChapter(
        start: start,
        title: title,
        url: url == null || url.isEmpty ? null : url,
        imageUrl: image == null || image.isEmpty ? null : image,
      ));
    }
    chapters.sort((a, b) => a.start.compareTo(b.start));
    final deduped = <PodcastChapter>[];
    Duration? lastStart;
    for (final chapter in chapters) {
      if (lastStart != null && chapter.start == lastStart) continue;
      deduped.add(chapter);
      lastStart = chapter.start;
    }
    return deduped;
  }

  Duration? _parseChapterStartTime(dynamic value) {
    try {
      if (value is num) {
        if (value < 0) return null;
        return Duration(milliseconds: (value * 1000).floor());
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        final parts = trimmed.split(':');
        double totalSeconds;
        if (parts.length == 1) {
          totalSeconds = double.parse(parts[0]);
        } else if (parts.length == 2) {
          totalSeconds = double.parse(parts[0]) * 60 + double.parse(parts[1]);
        } else if (parts.length == 3) {
          totalSeconds = double.parse(parts[0]) * 3600 +
              double.parse(parts[1]) * 60 +
              double.parse(parts[2]);
        } else {
          return null;
        }
        if (totalSeconds < 0) return null;
        return Duration(milliseconds: (totalSeconds * 1000).floor());
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<File> downloadEpisode(PodcastEpisode episode) async {
    final cache = PodcastCacheService();
    await cache.cleanAutomatically();
    final dir = await cache.cacheDirectory();
    final safeTitle = episode.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9àèéìòùÀÈÉÌÒÙ _.-]'), '_')
        .trim();
    final safeBaseName = safeTitle.isEmpty ? 'podcast_episode' : safeTitle;
    final ext = p.extension(Uri.parse(episode.audioUrl).path).isEmpty
        ? '.mp3'
        : p.extension(Uri.parse(episode.audioUrl).path);
    final file = File(p.join(dir.path, '$safeBaseName$ext'));
    final request = http.Request('GET', Uri.parse(episode.audioUrl));
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download non riuscito: ${response.statusCode}');
    }
    final sink = file.openWrite();
    try {
      await response.stream.pipe(sink);
    } catch (_) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      rethrow;
    }
    await cache.cleanAutomatically();
    return file;
  }

  String _cleanHtml(String value) {
    final text = html_parser.parse(value).body?.text ?? value;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _PodcastChaptersLink {
  const _PodcastChaptersLink(this.url, this.type);

  final String url;
  final String? type;
}

extension FirstOrNullXml on Iterable<XmlElement> {
  XmlElement? get firstOrNull => isEmpty ? null : first;
}
