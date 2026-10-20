import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/podcast_service.dart';

Map<String, dynamic> show(int id, String title) => {
  'show_id': id,
  'title': title,
  'author_name': null,
  'author': {'fullname': 'Radio Taormina'},
};

PodcastService service({
  int appleStatus = 200,
  int catalogStatus = 200,
  int exactStatus = 200,
  String exactTitle = 'Almanacco',
  List<Map<String, dynamic>> catalog = const [],
  List<Map<String, dynamic>> apple = const [],
}) => PodcastService(client: MockClient((request) async {
  if (request.url.host == 'itunes.apple.com') {
    return http.Response(jsonEncode({'results': apple}), appleStatus);
  }
  if (request.url.path == '/v2/search') {
    return http.Response(jsonEncode({'response': {'items': catalog}}), catalogStatus);
  }
  expect(request.url.path, '/v2/shows/almanacco');
  return http.Response(jsonEncode({'response': {'show': show(5587296, exactTitle)}}), exactStatus);
}));

void main() {
  test('recovers unindexed show and author using the exact permalink', () async {
    final results = await service().searchPodcasts('  Almanacco  ');
    expect(results, hasLength(1));
    expect(results.single.author, 'Radio Taormina');
    expect(results.single.feedUrl, 'https://www.spreaker.com/show/5587296/episodes/feed');
  });

  test('direct result survives failures of both search catalogs', () async {
    final results = await service(appleStatus: 503, catalogStatus: 503).searchPodcasts('Almanacco');
    expect(results, hasLength(1));
  });

  test('unavailable permalink keeps ordinary search results', () async {
    for (final status in [404, 503]) {
      final results = await service(exactStatus: status,
        catalog: [show(1, 'Almanacco diverso')]).searchPodcasts('Almanacco');
      expect(results.single.title, 'Almanacco diverso');
    }
  });

  test('unrelated renamed permalink is not added', () async {
    final results = await service(exactTitle: 'Another podcast').searchPodcasts('Almanacco');
    expect(results, isEmpty);
  });

  test('duplicate feeds removed, distinct homonyms kept', () async {
    final results = await service(catalog: [show(5587296, 'Almanacco'),
      show(2, 'Almanacco')]).searchPodcasts('Almanacco');
    expect(results, hasLength(2));
    expect(results.map((r) => r.feedUrl).toSet(), hasLength(2));
  });

  test('exact title appears before partial Apple matches', () async {
    final results = await service(apple: [{
      'collectionName': 'Almanacco diverso', 'artistName': 'Example',
      'feedUrl': 'https://example.org/rss',
    }]).searchPodcasts('Almanacco');
    expect(results, hasLength(2));
    expect(results.first.title, 'Almanacco');
  });

  test('both Spreaker requests failing still keeps Apple results', () async {
    final results = await service(exactStatus: 503, catalogStatus: 503, apple: [{
      'collectionName': 'Example', 'feedUrl': 'https://example.org/rss',
    }]).searchPodcasts('Almanacco');
    expect(results.single.title, 'Example');
  });

  test('complete outage is reported', () async {
    await expectLater(service(appleStatus: 503, exactStatus: 503, catalogStatus: 503)
        .searchPodcasts('Almanacco'), throwsException);
  });

  test('real Almanacco search and feed', () async {
    final client = http.Client();
    addTearDown(client.close);
    final podcasts = PodcastService(client: client);
    final results = await podcasts.searchPodcasts('Almanacco');
    final found = results.singleWhere((item) => item.feedUrl ==
        'https://www.spreaker.com/show/5587296/episodes/feed');
    expect(found.author, 'Radio Taormina');
    final details = await podcasts.fetchPodcastDetails(found);
    expect(details.title, 'Almanacco');
  }, skip: !const bool.fromEnvironment('SONARPAD_LIVE_PODCAST_TEST'),
     timeout: const Timeout(Duration(seconds: 120)));
}
