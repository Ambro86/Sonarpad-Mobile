import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tmdb_service.dart';
import '../utils/app_logger.dart';
import 'tmdb_character_strings.dart';

typedef TmdbChoose = Future<int?> Function(String key, List<String> options);
typedef TmdbLookup =
    Future<Map<String, dynamic>> Function(
      String action,
      Map<String, String> parameters,
    );

class TmdbCharacterService {
  TmdbCharacterService({TmdbLookup? lookup, this.language = 'en'})
    : _lookup =
          lookup ??
          ((action, parameters) => TmdbService().characterLookup(
            action,
            parameters,
            languageCode: language,
          ));
  final TmdbLookup _lookup;
  final String language;
  static List<Map<String, dynamic>> rows(Map value, String key) => [
    for (final item in value[key] as List? ?? [])
      if (item is Map) Map<String, dynamic>.from(item),
  ];

  Future<List<Map<String, Object?>>?> resolve(
    String title,
    String year,
    TmdbChoose choose,
  ) async {
    final productions = <Map<String, dynamic>>[];
    for (final kind in ['movie', 'tv']) {
      final result = await _lookup('search_$kind', {
        'query': title,
        'year': year,
      });
      final matches = rows(result, 'results');
      unawaited(
        AppLogger.log(
          'TMDB search kind=$kind results=${matches.length} '
          'total=${result['total_results']} pages=${result['total_pages']}',
        ),
      );
      productions.addAll(matches.map((item) => {...item, 'media_type': kind}));
    }
    if (productions.isEmpty) {
      throw StateError(TmdbCharacterStrings.get(language, 'no_results'));
    }
    final selected = await choose('production', [
      for (final item in productions)
        '${item['title'] ?? item['name']} (${(item['release_date'] ?? item['first_air_date'] ?? '').toString().split('-').first}) — ${TmdbCharacterStrings.get(language, item['media_type'] as String)}',
    ]);
    if (selected == null) return null;
    final production = productions[selected];
    final kind = production['media_type'] as String;
    final params = <String, String>{
      kind == 'movie' ? 'movie_id' : 'series_id': '${production['id']}',
    };
    final details = await _lookup('${kind}_details', params);
    int? season;
    int? episode;
    var action = '${kind}_credits';
    if (kind == 'tv') {
      final seasons = rows(details, 'seasons');
      if (seasons.isNotEmpty) {
        final index = await choose('season', [
          for (final item in seasons)
            '${item['name']} (${item['air_date'] ?? ''})',
        ]);
        if (index == null) return null;
        season = (seasons[index]['season_number'] as num).toInt();
        params['season_number'] = '$season';
        action = 'season_credits';
        final seasonDetails = await _lookup('season_details', params);
        final episodes = rows(seasonDetails, 'episodes');
        if (episodes.isNotEmpty) {
          final index = await choose('episode', [
            TmdbCharacterStrings.get(language, 'whole_season'),
            for (final item in episodes)
              '${item['episode_number']} — ${item['name']}',
          ]);
          if (index == null) return null;
          if (index > 0) {
            episode = (episodes[index - 1]['episode_number'] as num).toInt();
            params['episode_number'] = '$episode';
            action = 'episode_credits';
          }
        }
      }
    }
    final credits = await _lookup(action, params);
    final cast = catalogFromCredits(
      credits,
      details,
      kind: kind,
      season: season,
      episode: episode,
    );
    if (cast.isEmpty) {
      throw StateError(TmdbCharacterStrings.get(language, 'no_cast'));
    }
    return cast;
  }

  static List<Map<String, Object?>> catalogFromCredits(
    Map credits,
    Map details, {
    required String kind,
    int? season,
    int? episode,
  }) {
    final animation = rows(details, 'genres').any((item) => item['id'] == 16);
    final result = <String, Map<String, Object?>>{};
    for (final actor in [
      ...rows(credits, 'cast'),
      ...rows(credits, 'guest_stars'),
    ]) {
      var roles = rows(actor, 'roles');
      if (roles.isEmpty) roles = [actor];
      for (final role in roles) {
        final name = (role['character'] ?? '').toString().trim();
        if (name.isEmpty || actor['id'] == null) continue;
        final id =
            'tmdb_${details['id']}_${actor['id']}_${role['credit_id'] ?? ''}';
        final profile = actor['profile_path']?.toString() ?? '';
        result[id] = {
          'id': id,
          'name': name,
          'description':
              'TMDB cast candidate: ${actor['name']}. Identity in the video is NOT verified.',
          'provisional': true,
          'tmdb': <String, Object?>{
            'actor_name': actor['name'],
            'person_id': actor['id'],
            'credit_id': role['credit_id'] ?? '',
            'production_id': details['id'],
            'production_title': details['title'] ?? details['name'],
            'production_year': int.tryParse(
              (details['release_date'] ?? details['first_air_date'] ?? '')
                  .toString()
                  .split('-')
                  .first,
            ),
            'media_type': kind,
            'season_number': season,
            'episode_number': episode,
            'animation': animation,
            'profile_image_url':
                !animation && profile.startsWith('/') && !profile.contains('..')
                ? 'https://image.tmdb.org/t/p/w185$profile'
                : null,
          },
        };
      }
    }
    return result.values.take(96).toList();
  }

  static bool validImageUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.authority == 'image.tmdb.org' &&
        uri.path.startsWith('/t/p/w185/') &&
        uri.path.endsWith('.jpg') &&
        !uri.path.contains('..') &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static Future<File> downloadImage(
    String url, {
    Directory? cacheDirectory,
    http.Client? client,
  }) async {
    if (!validImageUrl(url)) {
      throw const FormatException('Invalid TMDB portrait URL');
    }
    final directory =
        cacheDirectory ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'tmdb_portraits',
          ),
        );
    await directory.create(recursive: true);
    final file = File(
      p.join(directory.path, '${sha256.convert(utf8.encode(url))}.jpg'),
    );
    bool valid(List<int> data) =>
        data.length >= 3 &&
        data.length <= 1024 * 1024 &&
        data[0] == 255 &&
        data[1] == 216 &&
        data[2] == 255;
    if (await file.exists() &&
        DateTime.now().difference(await file.lastModified()).inDays < 30 &&
        await file.length() <= 1024 * 1024 &&
        valid(await file.readAsBytes())) {
      return file;
    }
    final httpClient = client ?? http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..followRedirects = false;
      request.headers['User-Agent'] = 'Sonarpad/TMDB';
      final response = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw HttpException('TMDB portrait HTTP ${response.statusCode}');
      }
      final data = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 12),
      )) {
        data.addAll(chunk);
        if (data.length > 1024 * 1024) {
          throw const FormatException('Oversized TMDB portrait');
        }
      }
      if (!valid(data)) throw const FormatException('Invalid JPEG portrait');
      await file.writeAsBytes(data, flush: true);
      final files = await directory
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.jpg'))
          .cast<File>()
          .toList();
      final ordered = <(File, DateTime)>[
        for (final entry in files) (entry, await entry.lastModified()),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      for (final entry in ordered.take(
        ordered.length > 128 ? ordered.length - 128 : 0,
      )) {
        await entry.$1.delete();
      }
      return file;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static const identityRule =
      'OPTIONAL TMDB EXCEPTION TO THE SPOKEN-NAME RULE: A supplied cast name may also be used without being spoken if the actual video and a supplied actor portrait support a confident visual match. A cast listing or weak resemblance alone is never sufficient. Portraits may show a different age, hairstyle or costume. When uncertain use a neutral visual label. Voice-actor portraits must never identify animated characters. Only user-confirmed catalog entries are authoritative: TMDB candidates and provisional identities inferred in previous chunks can be corrected by later evidence. Do not invent names from familiarity with an actor or the plot. Reference portraits are NOT frames from the video and must not be described as scenes. Names heard clearly linked in the video and user catalog names take precedence over untranslated cast names.'
      " CHARACTER NAME LOCALIZATION: TMDB character fields may contain untranslated original or English names. For TMDB-derived or provisional identities, use the established conventional character name in the requested audio-description language in BOTH character_glossary.name and description_text. Prefer the name clearly used in the video's target-language dialogue when available. Do not translate actor names or change character IDs, TMDB metadata, or explicitly user-confirmed names. Do not translate proper names literally or invent localized names: if no established localized form is known, retain the original. This rule concerns name spelling only, and never establishes who is visible in the video. Keep one consistent localized name per identity throughout the output. This is an explicit exception to instructions to keep names unchanged, only for TMDB-derived or provisional identities."
      ' ACTIVE CAST MATCHING: The supplied TMDB listing is authoritative for which character each listed actor portrays in this selected production/season/episode. Before writing each description, actively compare clearly visible faces with the supplied actor portraits. If you confidently recognize a listed actor in the video, use the associated character name from their FIRST visible appearance in this clip, even if dialogue has not yet spoken the name. Do not unnecessarily replace a recognized character with a generic age/gender label. Do not wait for later dialogue to confirm an already confident visual match. Account for hairstyle, costume and age differences. The cast listing alone does not prove that a person in a frame is that actor: if the face is unclear or the match is uncertain, retain a neutral description. Never force a match merely because someone is in the cast. All timing and dialogue-protection rules remain unchanged.'
      ' CAST COMPLETENESS: The TMDB cast may be incomplete. A person visible in the video may be absent from the supplied catalog and photographs. Never assume that every visible person must match a listed character, and never assign the closest-looking available character merely because the correct person is missing. If the available references do not support a confident match, use a name only when the video clearly and unambiguously identifies that person; otherwise use a neutral identifying visual description. A missing cast entry is not evidence that this person is someone else in the list. This does not prevent using a listed character name when the visual match is confident.';
}
