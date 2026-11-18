import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

typedef AniListQuery =
    Future<Map<String, dynamic>> Function(
      String query,
      Map<String, Object?> variables,
    );

class AniListCharacterService {
  static const _search =
      r'query($q:String!){Page(perPage:20){media(type:ANIME,search:$q,sort:[SEARCH_MATCH]){id title{native english romaji} synonyms format startDate{year}}}}';
  static const _cast =
      r'query($id:Int!,$p:Int!){Media(id:$id,type:ANIME){characters(page:$p,perPage:50,sort:[ROLE,ID]){pageInfo{hasNextPage} edges{role node{id name{full native alternative} description(asHtml:false) image{large medium}}}}}}';
  static final _cache = <String, (DateTime, Map<String, dynamic>)>{};
  static DateTime? _retryAfter;

  static Future<Map<String, dynamic>> _fetch(
    String query,
    Map<String, Object?> variables,
  ) async {
    final now = DateTime.now();
    final body = jsonEncode({'query': query, 'variables': variables});
    _cache.removeWhere((_, entry) => now.difference(entry.$1).inMinutes >= 15);
    final cached = _cache[body];
    if (cached != null) return cached.$2;
    if (_retryAfter?.isAfter(now) == true) {
      throw StateError('ANILIST_RATE_LIMIT');
    }
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.https('graphql.anilist.co', '/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 14));
      if (response.statusCode == 429) {
        final seconds =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        _retryAfter = now.add(Duration(seconds: seconds.clamp(1, 86400)));
      }
      if (response.statusCode != 200) {
        throw StateError('ANILIST_HTTP_ERROR');
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      if (payload['errors'] != null) throw StateError('ANILIST_GRAPHQL_ERROR');
      final data = payload['data'] as Map<String, dynamic>;
      if (_cache.length >= 16) _cache.remove(_cache.keys.first);
      _cache[body] = (now, data);
      return data;
    } finally {
      client.close();
    }
  }

  static String _key(String text) => text.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
  static bool validImageUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.authority == 's4.anilist.co' &&
        uri.path.startsWith('/file/anilistcdn/character/') &&
        !url.contains('..') &&
        !uri.path.contains('/default') &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.path.endsWith('.jpg') || uri.path.endsWith('.png'));
  }

  static Future<List<Map<String, Object?>>?> resolve(
    Iterable<String> titles,
    String year,
    String kind,
    Future<int?> Function(String, List<String>) choose, {
    AniListQuery query = _fetch,
  }) async {
    final names = {
      for (final t in titles)
        if (_key(t).isNotEmpty) _key(t): t,
    };
    final candidates = <int, Map>{};
    for (final name in names.values) {
      final data = await query(_search, {'q': name});
      for (final m in data['Page']['media'] as List) {
        final formats = kind == 'movie'
            ? {'MOVIE', 'OVA', 'SPECIAL', 'ONA'}
            : {'TV', 'TV_SHORT', 'OVA', 'SPECIAL', 'ONA'};
        if (!formats.contains(m['format']) ||
            year.isNotEmpty && '${m['startDate']['year']}' != year) {
          continue;
        }
        final aliases = [
          ...(m['title'] as Map).values,
          ...?m['synonyms'] as List?,
        ];
        if (aliases.whereType<String>().any(
          (alias) => names.containsKey(_key(alias)),
        )) {
          candidates[m['id'] as int] = m as Map;
        }
      }
    }
    if (candidates.isEmpty) return [];
    final items = candidates.values.toList();
    String title(Map m) =>
        (m['title']['english'] ?? m['title']['romaji'] ?? m['title']['native'])
            as String;
    final index = items.length == 1
        ? 0
        : await choose('production', [
            for (final m in items)
              'AniList — ${title(m)} (${m['startDate']['year']}, ${m['format']}) [${m['id']}]',
          ]);
    if (index == null) return null;
    final media = items[index], id = media['id'];
    final result = <Map<String, Object?>>[];
    for (var page = 1; page <= 4; page++) {
      final data = await query(_cast, {'id': id, 'p': page});
      final connection = data['Media']['characters'];
      for (final edge in connection['edges'] as List) {
        final node = edge['node'], name = node['name']['full'];
        final urls = [
          node['image']?['large'],
          node['image']?['medium'],
        ].whereType<String>().where(validImageUrl);
        if (node['id'] == null || name is! String || urls.isEmpty) continue;
        final description = node['description'] as String? ?? '';
        result.add({
          'id': 'anilist_${id}_${node['id']}',
          'name': name,
          'description': description.isEmpty
              ? 'Animated character candidate'
              : String.fromCharCodes(description.runes.take(600)),
          'provisional': true,
          'anilist': {
            'media_id': id,
            'media_title': title(media),
            'source_character_id': node['id'],
            'role': edge['role'] ?? '',
            'aliases': [
              ...?node['name']['alternative'] as List?,
              if (node['name']['native'] != null) node['name']['native'],
            ],
            'image_urls': [urls.first],
          },
        });
        if (result.length == 96) return result;
      }
      if (connection['pageInfo']['hasNextPage'] != true) break;
    }
    return result;
  }
}
