import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';

void main() {
  for (final direct in [true, false]) {
    test('Grateful Dead complete discography via ${direct ? 'Dart' : 'PHP'}', () async {
      final php = File(r'C:\Users\ambro\Documents\youtube_music_resolve.php').readAsStringSync();
      final token = RegExp("const SONARPAD_YOUTUBE_CLIENT_TOKEN = '([^']+)'").firstMatch(php)!.group(1)!;
      final client = http.Client();
      addTearDown(client.close);
      final service = SonarMusicService(client: client, directCatalog: direct,
        endpoint: Uri.parse('http://127.0.0.1:18797/youtube_music_resolve.php'), clientToken: token);
      final search = await service.search('Grateful Dead', type: 'album');
      expect(search.items.length, greaterThan(2));
      expect(search.hasMore, isTrue);
      final moreSearch = await service.search('Grateful Dead', type: 'album', token: search.nextToken, page: 2);
      expect(moreSearch.items, isNotEmpty);
      final artist = await service.browse('UC9dWluHyEwvIj5NNs7KkJ0A');
      final sections = artist.items.where((item) => item.kind == 'collection').toList();
      expect(sections.length, greaterThanOrEqualTo(2));
      final albums = sections.first;
      final first = await service.browse(albums.browseId!, params: albums.browseParams);
      expect(first.items.length, greaterThan(10));
      expect(first.items.every((item) => item.kind == 'album'), isTrue);
      expect(first.hasMore, isTrue);
      final second = await service.browse(albums.browseId!, params: albums.browseParams, token: first.nextToken, page: 2);
      expect(second.items, isNotEmpty);
      final ids = first.items.map((item) => item.id).toSet();
      expect(second.items.any((item) => !ids.contains(item.id)), isTrue);
      // ignore: avoid_print
      print('${direct ? 'Dart' : 'PHP'} discography: ${first.items.length} + ${second.items.length} albums.');
    }, skip: !const bool.fromEnvironment('RUN_LIVE_SONARMUSIC_ALBUMS'), timeout: const Timeout(Duration(minutes: 3)));
  }
  test('Grateful Dead album search retains raw upstream entries across five pages', () async {
    final network = http.Client();
    addTearDown(network.close);
    var expectedIds = <String>{};
    final client = MockClient((request) async {
      expect(request.url.host, 'music.youtube.com');
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)..bodyBytes = request.bodyBytes;
      final response = await http.Response.fromStream(await network.send(copy));
      final raw = jsonDecode(utf8.decode(response.bodyBytes));
      expectedIds = {};
      void walk(dynamic value) {
        if (value is List) { for (final child in value) { walk(child); } }
        if (value is Map) {
          final row = value['musicResponsiveListItemRenderer'];
          if (row is Map) {
            final id = row['navigationEndpoint']?['browseEndpoint']?['browseId'];
            if (id is String && id.startsWith('MPRE')) expectedIds.add(id);
          }
          for (final child in value.values) { walk(child); }
        }
      }
      walk(raw);
      return response;
    });
    addTearDown(client.close);
    final service = SonarMusicService(client: client);
    String? token;
    final unique = <String>{};
    for (var page = 1; page <= 5; page++) {
      final result = await service.search('Grateful Dead', type: 'album', token: token, page: page);
      expect(expectedIds, isNotEmpty);
      expect(result.items.map((item) => item.id).toSet(), expectedIds);
      expect(result.items.every((item) => item.kind == 'album'), isTrue);
      unique.addAll(result.items.map((item) => item.id));
      token = result.nextToken;
      expect(token, isNotNull);
    }
    expect(unique.length, greaterThan(20));
    // ignore: avoid_print
    print('Grateful Dead: ${unique.length} distinct albums, five pages matched upstream.');
  }, skip: !const bool.fromEnvironment('RUN_LIVE_SONARMUSIC_ALBUMS'), timeout: const Timeout(Duration(minutes: 3)));
}
