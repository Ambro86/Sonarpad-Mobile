import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/tmdb_character_service.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_fallbacks.dart';

void main() {
  Map<String, dynamic> credits() => {
    'cast': [
      {
        'id': 1,
        'name': 'Actor',
        'profile_path': '/portrait.jpg',
        'roles': [
          {'character': 'Anna', 'credit_id': 'one'},
          {'character': 'Maria', 'credit_id': 'two'},
        ],
      },
    ],
  };
  Map<String, dynamic> details({bool animation = false}) => {
    'id': 1981,
    'name': 'Streghe',
    'first_air_date': '1998-10-07',
    'genres': [
      if (animation) {'id': 16},
    ],
  };

  test(
    'ambiguous production, season and episode route to episode credits',
    () async {
      final calls = <(String, Map<String, String>)>[];
      final choices = <String>[];
      final service = TmdbCharacterService(
        language: 'it',
        lookup: (action, parameters) async {
          calls.add((action, Map.of(parameters)));
          return switch (action) {
            'search_movie' => {'results': []},
            'search_tv' => {
              'results': [
                {'id': 1981, 'name': 'Streghe', 'first_air_date': '1998-10-07'},
                {
                  'id': 79611,
                  'name': 'Streghe',
                  'first_air_date': '2018-10-14',
                },
              ],
            },
            'tv_details' => {
              ...details(),
              'seasons': [
                {'season_number': 1, 'name': 'Stagione 1'},
                {'season_number': 2, 'name': 'Stagione 2'},
              ],
            },
            'season_details' => {
              'episodes': [
                {'episode_number': 1, 'name': 'Episode'},
              ],
            },
            'episode_credits' => credits(),
            _ => throw StateError(action),
          };
        },
      );
      final result = await service.resolve('Streghe', '', (key, options) async {
        choices.add(key);
        if (key == 'production') expect(options.first, contains('1998'));
        return key == 'production' ? 0 : 1;
      });
      expect(choices, ['production', 'season', 'episode']);
      expect(calls.last.$1, 'episode_credits');
      expect(calls.last.$2, {
        'series_id': '1981',
        'season_number': '2',
        'episode_number': '1',
      });
      expect(result!.map((item) => item['name']), ['Anna', 'Maria']);
      expect(
        (result.first['tmdb'] as Map)['profile_image_url'],
        endsWith('/portrait.jpg'),
      );
    },
  );

  test(
    'cancelling selection never silently chooses another production',
    () async {
      final service = TmdbCharacterService(
        lookup: (action, _) async => {
          'results': [
            {'id': 1, 'name': 'A'},
          ],
        },
      );
      expect(await service.resolve('A', '', (_, _) async => null), isNull);
    },
  );

  test('animation keeps character metadata and omits voice actor photos', () {
    final cast = TmdbCharacterService.catalogFromCredits(
      credits(),
      details(animation: true),
      kind: 'tv',
    );
    expect(cast, hasLength(2));
    for (final item in cast) {
      expect((item['tmdb'] as Map)['profile_image_url'], isNull);
      expect(item['provisional'], isTrue);
    }
  });

  test(
    'catalog roundtrip keeps only image URLs; a full catalog retains references',
    () {
      final cast = TmdbCharacterService.catalogFromCredits(
        credits(),
        details(),
        kind: 'tv',
      );
      final old = [
        for (var index = 0; index < 96; index++)
          <String, Object?>{
            'id': 'old$index',
            'name': 'Name $index',
            'description': 'Known appearance',
          },
      ];
      final merged = AudioDescriptionFallbacks.mergeCharacterCatalog(old, cast);
      final roundtrip = jsonDecode(jsonEncode(merged)) as List;
      expect(roundtrip, hasLength(98));
      expect((roundtrip.last['tmdb'] as Map)['person_id'], 1);
      expect(jsonEncode(merged), isNot(contains('inlineData')));
      expect(jsonEncode(merged), isNot(contains('base64')));
    },
  );

  test('checkpoint restore retains TMDB references and same-ID observations', () {
    final cast = TmdbCharacterService.catalogFromCredits(credits(), details(), kind: 'tv');
    final observed = <String, Object?>{
      'id': cast.first['id'], 'name': 'Nome localizzato',
      'description': 'Giacca rossa vista nel video', 'provisional': true,
    };
    final before = AudioDescriptionFallbacks.mergeCharacterCatalog(cast, [observed]);
    final saved = jsonDecode(jsonEncode({'glossary': before})) as Map;
    final restored = AudioDescriptionFallbacks.mergeCharacterCatalog(
      [], [for (final entry in saved['glossary'] as List) Map<String, Object?>.from(entry as Map)],
    );
    final references = restored.where((item) => item['tmdb'] is Map).toList();
    final observations = restored.where((item) => item['tmdb'] is! Map).toList();
    expect(references, cast);
    expect(observations.single, observed);
    final corrected = AudioDescriptionFallbacks.mergeCharacterCatalog(restored, [
      {...observed, 'description': 'Giacca blu verificata dopo la ripresa'},
    ]);
    expect(corrected.where((item) => item['tmdb'] is Map).toList(), cast);
    expect(corrected.where((item) => item['tmdb'] is! Map).single['description'],
        'Giacca blu verificata dopo la ripresa');
  });

  test('provisional identities can change; user identities stay stable', () {
    final provisional = <String, Object?>{
      'id': 'x',
      'name': 'Anna',
      'description': 'Red hair',
      'provisional': true,
    };
    final corrected = <String, Object?>{
      'id': 'x',
      'name': 'Maria',
      'description': 'Black hair',
      'provisional': true,
    };
    expect(
      AudioDescriptionFallbacks.mergeCharacterCatalog(
        [provisional],
        [corrected],
      ).single['name'],
      'Maria',
    );
    final known = Map<String, Object?>.from(provisional)..remove('provisional');
    final result = AudioDescriptionFallbacks.mergeCharacterCatalog(
      [known],
      [corrected],
    ).single;
    expect(result['name'], 'Anna');
    expect(result['provisional'], isNull);
  });

  test('portraits use bounded JPEG download and local cache', () async {
    final cache = await Directory.systemTemp.createTemp('tmdb-test-');
    addTearDown(() => cache.delete(recursive: true));
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response.bytes([255, 216, 255, 1, 2, 3], 200);
    });
    const url = 'https://image.tmdb.org/t/p/w185/portrait.jpg';
    final first = await TmdbCharacterService.downloadImage(
      url,
      cacheDirectory: cache,
      client: client,
    );
    final second = await TmdbCharacterService.downloadImage(
      url,
      cacheDirectory: cache,
      client: client,
    );
    expect(first.path, second.path);
    expect(requests, 1);
    expect(await first.readAsBytes(), [255, 216, 255, 1, 2, 3]);
  });

  test('rejects arbitrary URLs and oversized portraits', () async {
    for (final url in [
      'file:///secret',
      'https://example.com/t/p/w185/a.jpg',
      'https://image.tmdb.org.evil.test/t/p/w185/a.jpg',
      'https://image.tmdb.org/t/p/w185/../a.jpg',
    ]) {
      expect(TmdbCharacterService.validImageUrl(url), isFalse);
    }
    final cache = await Directory.systemTemp.createTemp('tmdb-limit-');
    addTearDown(() => cache.delete(recursive: true));
    final client = MockClient(
      (_) async => http.Response.bytes(List.filled(1024 * 1024 + 1, 255), 200),
    );
    await expectLater(
      TmdbCharacterService.downloadImage(
        'https://image.tmdb.org/t/p/w185/a.jpg',
        cacheDirectory: cache,
        client: client,
      ),
      throwsFormatException,
    );
  });
}
