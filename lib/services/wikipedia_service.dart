import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class WikipediaSearchResult {
  final int pageId;
  final String title;
  const WikipediaSearchResult({required this.pageId, required this.title});
}

class WikipediaArticle {
  final String title;
  final String text;
  final String url;
  const WikipediaArticle({required this.title, required this.text, required this.url});
}

class WikipediaService {
  final http.Client _client;
  WikipediaService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<WikipediaSearchResult>> search(String query, {String lang = 'it'}) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'srlimit': '10',
      'format': 'json',
      'formatversion': '2',
    });
    final response = await _client.get(uri, headers: {'User-Agent': 'SonarpadMobile/0.1'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore Wikipedia: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final hits = (json['query']['search'] as List).cast<Map<String, dynamic>>();
    return hits.map((e) => WikipediaSearchResult(pageId: e['pageid'] as int, title: e['title'] as String)).toList();
  }

  Future<WikipediaArticle> importArticle(int pageId, {String lang = 'it'}) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'parse',
      'pageid': '$pageId',
      'prop': 'text',
      'disableeditsection': '1',
      'format': 'json',
      'formatversion': '2',
    });
    final response = await _client.get(uri, headers: {'User-Agent': 'SonarpadMobile/0.1'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore importazione Wikipedia: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final parse = json['parse'] as Map<String, dynamic>;
    final title = parse['title'] as String;
    final html = parse['text'] as String;
    final text = html_parser.parse(html).body?.text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim() ?? '';
    final url = 'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';
    return WikipediaArticle(title: title, text: text, url: url);
  }
}
