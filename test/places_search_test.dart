import 'dart:convert';
import 'package:sonarpad_mobile_starter/utils/home_item_catalog.dart';
import 'package:sonarpad_mobile_starter/services/home_customization_service.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/italiaonline_service.dart';

const legacy =
    '''<response><status>200</status><current_page>1</current_page><isLastPage>0</isLastPage><results>
<result><id>duplicate</id><name>Bar Uno</name><address>Via Roma 12</address><city>Torino</city><phones><phone><number>01112345</number></phone></phones></result>
<result><id>extra</id><name>Bar Due</name><address>Via Roma 120</address><city>Torino</city></result>
</results></response>''';

http.Response places({bool withHours = true, String? website}) => http.Response(
  jsonEncode({
    'ok': true,
    'data': {
      'risultati': [
        {
          'id': 'new',
          'nome': 'Bar Uno',
          'indirizzo': 'Via Roma, 12, Torino',
          'telefoni': ['011 12345'],
          'categorie': ['Bar'],
          'descrizione': 'Caffetteria',
          'stelle': 4.5,
          'numero_recensioni': 23,
          'sito_web': ?website,
          if (withHours) ...{
            'stato_apertura': 'Chiuso · Apre alle ore 12:30',
            'orari_apertura': [
              {
                'giorno': 'venerdì',
                'data': '2026-11-06',
                'fasce': ['12:30–14:30', '19:30–23'],
              },
              {
                'giorno': 'lunedì',
                'data': null,
                'fasce': ['Chiuso'],
              },
            ],
          },
        },
      ],
    },
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

SearchQuery query({
  int page = 1,
  DirectoryKind kind = DirectoryKind.pagineGialle,
  bool reverse = false,
}) => SearchQuery(
  kind: kind,
  what: reverse ? '01112345' : 'bar',
  where: 'Torino',
  page: page,
  reverse: reverse,
);

void main() {
  test(
    'international phone searches send normalized number and never use Italian directories',
    () async {
      for (final country in ['fr', 'it']) {
        for (final fail in [false, true]) {
          final calls = <Uri>[];
          final service = ItaliaOnlineService(
            clientToken: 'test-only',
            client: MockClient((request) async {
              calls.add(request.url);
              expect(request.url.host, 'sonarpad.com');
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['telefono'], '+33158592222');
              expect(body['q'], '+33158592222');
              expect(body['paese'], country);
              expect(body['lingua'], 'en');
              expect(body['citta'], '');
              return fail ? http.Response('', 503) : places();
            }),
          );
          final result = service.searchPhone(
            SearchQuery(
              kind: DirectoryKind.pagineBianche,
              what: '0033 1 58 59 22 22',
              where: 'ignored',
              country: country,
              language: 'en',
              reverse: true,
            ),
          );
          if (fail) {
            await expectLater(result, throwsException);
          } else {
            final response = await result;
            expect(response.results.single.id, 'place:new');
            expect(response.isLastPage, isTrue);
          }
          expect(calls, hasLength(1));
        }
      }
    },
  );

  test(
    'Italian phone searches merge three sources, prefer places and preserve legacy detail IDs',
    () async {
      final calls = <String>[];
      final service = ItaliaOnlineService(
        clientToken: 'test-only',
        client: MockClient((request) async {
          calls.add(request.url.path);
          if (request.url.host == 'sonarpad.com') {
            expect(jsonDecode(request.body)['telefono'], '01112345');
            return places();
          }
          if (request.url.host == 'www.paginegialle.it') {
            return http.Response('''<input id="numero" value="01112345">
<div class="search-itm" data-tr="listing-search-itm"><div class="search-itm__info">
<a href="https://www.paginegialle.it/extra"><h2 class="search-itm__rag">PG result</h2></a>
<div class="search-itm__adr">Via Roma 120, Torino</div>
<span class="search-itm__phone-item">01112345</span></div></div>''', 200);
          }
          final prefix = request.url.path.endsWith('searchpb') ? 'PB' : 'PG';
          return http.Response(
            legacy
                .replaceFirst('Bar Due', '$prefix result')
                .replaceFirst(
                  '<name>$prefix result</name>',
                  '<name>$prefix result</name><phones><phone><number>01112345</number></phone></phones>',
                ),
            200,
          );
        }),
      );
      final response = await service.searchPhone(query(reverse: true));
      expect(
        calls,
        containsAll([
          '/api/luoghi.php',
          '/searchpb',
          '/ricerca/telefono-01112345',
        ]),
      );
      expect(response.results.map((r) => r.id), [
        'place:new',
        'pb:extra',
        'pg:extra',
      ]);
      expect(response.results.first.inlineDetail, isNotNull);
    },
  );

  test(
    'phone lookup keeps directory results when places fails and places results when directories fail',
    () async {
      for (final placesFail in [false, true]) {
        final service = ItaliaOnlineService(
          clientToken: 'test-only',
          client: MockClient((request) async {
            if (request.url.host == 'sonarpad.com') {
              return placesFail ? http.Response('', 503) : places();
            }
            if (placesFail && request.url.host == 'www.paginegialle.it') {
              return http.Response('''<input id="numero" value="01112345">
<div class="search-itm" data-tr="listing-search-itm"><div class="search-itm__info">
<a href="https://www.paginegialle.it/duplicate"><h2 class="search-itm__rag">Bar Uno</h2></a>
<span class="search-itm__phone-item">01112345</span></div></div>''', 200);
            }
            return placesFail
                ? http.Response(legacy, 200)
                : http.Response('', 503);
          }),
        );
        final response = await service.searchPhone(query(reverse: true));
        expect(
          response.results.map((r) => r.id),
          placesFail ? ['pb:duplicate', 'pg:duplicate'] : ['place:new'],
        );
      }
    },
  );

  test(
    'English details localize labels and hours without translating fetched content',
    () async {
      final service = ItaliaOnlineService(
        clientToken: 'test-only',
        client: MockClient(
          (request) async =>
              places(withHours: false, website: 'https://example.org'),
        ),
      );
      final response = await service.searchActivities(
        SearchQuery(
          kind: DirectoryKind.pagineGialle,
          what: 'hotel',
          country: 'fr',
          language: 'en',
        ),
        includeItalianDirectories: false,
      );
      final detail = response.results.single.inlineDetail!;
      for (final expected in [
        'Category: Bar',
        'Address: Via Roma, 12, Torino',
        'Phone: 011 12345',
        'Website: https://example.org',
        'Rating: 4.5 out of 5 stars (23 reviews)',
        'Opening hours not available',
        'Caffetteria',
      ]) {
        expect(detail.body, contains(expected));
      }
      for (final old in [
        'Categoria:',
        'Indirizzo:',
        'Telefono:',
        'Sito web:',
        'Valutazione:',
        'Orari non disponibili',
      ]) {
        expect(detail.body, isNot(contains(old)));
      }
      expect(
        formatOpeningRange('05–00', language: 'en'),
        'from 05:00 to 00:00',
      );
      expect(
        formatOpeningRange('19–02', language: 'en'),
        'from 19:00 to 02:00 the following day',
      );
      expect(
        openingDayLabel(
          'Friday',
          '2026-11-06',
          DateTime(2026, 11, 6),
          language: 'en',
        ),
        'Today',
      );
      expect(
        openingDayLabel(
          'Saturday',
          '2026-11-07',
          DateTime(2026, 11, 6),
          language: 'en',
        ),
        'Tomorrow',
      );
    },
  );

  test(
    'country and language reach endpoint and foreign country skips Italian sources',
    () async {
      final service = ItaliaOnlineService(
        clientToken: 'test-only',
        client: MockClient((request) async {
          expect(request.url.host, 'sonarpad.com');
          expect(jsonDecode(request.body), {
            'q': 'museum',
            'citta': 'Paris',
            'paese': 'fr',
            'lingua': 'it',
          });
          return places();
        }),
      );
      final response = await service.searchActivities(
        SearchQuery(
          kind: DirectoryKind.pagineGialle,
          what: 'museum',
          where: 'Paris',
          country: 'fr',
          language: 'it',
        ),
      );
      expect(response.results.single.id, 'place:new');
      expect(response.isLastPage, isTrue);
    },
  );

  test(
    'places is visible without RaiLuce in both Italian and other languages',
    () {
      for (final italian in [false, true]) {
        expect(
          availableHomeItemIds(
            isItalian: italian,
            isTvCodeValid: false,
            isRaiPlayValid: false,
            isRaiPlaySoundCodeValid: false,
          ),
          contains(HomeItemIds.directory),
        );
      }
    },
  );

  test(
    'international search never calls Italian directories even on failure',
    () async {
      for (final fail in [false, true]) {
        final calls = <Uri>[];
        final service = ItaliaOnlineService(
          clientToken: 'test-only',
          client: MockClient((request) async {
            calls.add(request.url);
            expect(request.url.host, 'sonarpad.com');
            return fail ? http.Response('', 503) : places();
          }),
        );
        final result = service.searchActivities(
          query(),
          includeItalianDirectories: false,
        );
        if (fail) {
          await expectLater(result, throwsException);
        } else {
          final response = await result;
          expect(response.results.single.id, 'place:new');
          expect(response.isLastPage, isTrue);
        }
        expect(calls, hasLength(1));
      }
    },
  );

  test('website uses existing detail links and remains optional', () async {
    for (final website in [null, '', 'https://example.org/ristorante/']) {
      final service = ItaliaOnlineService(
        clientToken: 'test-only',
        client: MockClient(
          (request) async => request.url.host == 'sonarpad.com'
              ? places(website: website)
              : http.Response(legacy, 200),
        ),
      );
      final response = await service.searchActivities(query());
      final detail = response.results.first.inlineDetail!;
      if (website == null || website.isEmpty) {
        expect(detail.websites, isEmpty);
        expect(detail.body, isNot(contains('Sito web:')));
      } else {
        expect(detail.websites, [website]);
        expect(detail.body, contains('Sito web: $website'));
      }
    }
  });
  test('readable ranges and today/tomorrow across year boundary', () {
    expect(formatOpeningRange('05–00'), 'dalle 05:00 alle 00:00');
    expect(formatOpeningRange('05–22:30'), 'dalle 05:00 alle 22:30');
    expect(
      formatOpeningRange('19–02'),
      'dalle 19:00 alle 02:00 del giorno successivo',
    );
    expect(formatOpeningRange('Chiuso'), 'Chiuso');
    expect(formatOpeningRange('Aperto 24 ore'), 'Aperto 24 ore');
    final now = DateTime(2026, 12, 31, 23);
    expect(openingDayLabel('giovedì', '2026-12-31', now), 'Oggi');
    expect(openingDayLabel('venerdì', '2027-01-01', now), 'Domani');
    expect(openingDayLabel('sabato', '2027-01-02', now), 'sabato');
    expect(openingDayLabel('sabato', null, now), 'sabato');
  });
  test('older responses without hours remain usable', () async {
    final service = ItaliaOnlineService(
      clientToken: 'test-only',
      client: MockClient(
        (request) async => request.url.host == 'sonarpad.com'
            ? places(withHours: false)
            : http.Response(legacy, 200),
      ),
    );
    final response = await service.searchActivities(query());
    expect(
      response.results.first.inlineDetail!.body,
      contains('Orari non disponibili'),
    );
    expect(
      response.results.first.inlineDetail!.body,
      isNot(contains('Stato apertura:')),
    );
  });
  test(
    'new results first, duplicates removed, existing pagination and details preserved',
    () async {
      final service = ItaliaOnlineService(
        clientToken: 'test-only',
        client: MockClient((request) async {
          if (request.url.host == 'sonarpad.com') {
            expect(request.method, 'POST');
            expect(request.headers['X-Sonarpad-Route-Token'], 'test-only');
            expect(jsonDecode(request.body), {
              'q': 'bar',
              'citta': 'Torino',
              'paese': 'it',
              'lingua': 'it',
            });
            return places();
          }
          expect(
            request.headers.containsKey('X-Sonarpad-Route-Token'),
            isFalse,
          );
          if (request.url.path.endsWith('detailpg')) {
            expect(request.url.queryParameters['id'], 'extra');
            expect(request.url.queryParameters['where'], 'Torino');
            return http.Response(
              '<response><status>200</status><detail><name>Bar Due</name></detail></response>',
              200,
            );
          }
          return http.Response(legacy, 200);
        }),
      );
      final response = await service.searchActivities(query());
      expect(response.results.map((r) => r.id), ['place:new', 'pg:extra']);
      expect(response.isLastPage, isFalse);
      final detail = response.results.first.inlineDetail!;
      for (final text in [
        'Stato apertura: Chiuso · Apre alle ore 12:30',
        'dalle 12:30 alle 14:30; dalle 19:30 alle 23:00',
        ': Chiuso',
      ]) {
        expect(detail.body, contains(text));
        expect(detail.description, contains(text));
      }
      expect(
        response.results.first.inlineDetail!.body,
        contains('4.5 su 5 stelle (23 recensioni)'),
      );
      expect(
        response.results.first.inlineDetail!.description,
        contains('Caffetteria'),
      );
      expect(
        (await service.loadDetail(query(), response.results.last.id)).title,
        'Bar Due',
      );
    },
  );

  test('unavailable new endpoint falls back to the original results', () async {
    final service = ItaliaOnlineService(
      clientToken: 'test-only',
      client: MockClient(
        (request) async => request.url.host == 'sonarpad.com'
            ? http.Response('', 503)
            : http.Response(legacy, 200),
      ),
    );
    final response = await service.searchActivities(query());
    expect(response.results.map((r) => r.id), ['duplicate', 'extra']);
    expect(response.isLastPage, isFalse);
  });

  test('legacy failure does not discard new results', () async {
    final service = ItaliaOnlineService(
      clientToken: 'test-only',
      client: MockClient(
        (request) async => request.url.host == 'sonarpad.com'
            ? places()
            : http.Response('', 503),
      ),
    );
    final response = await service.searchActivities(query());
    expect(response.results.single.id, 'place:new');
  });

  test('name search and later pages do not call the new endpoint', () async {
    final service = ItaliaOnlineService(
      clientToken: 'test-only',
      client: MockClient((request) async {
        expect(request.url.host, isNot('sonarpad.com'));
        return http.Response(legacy, 200);
      }),
    );
    await service.searchActivities(query(kind: DirectoryKind.pagineBianche));
    await service.searchActivities(query(reverse: true, page: 2));
    final response = await service.searchActivities(query(page: 2));
    expect(response.results.map((r) => r.id), ['duplicate', 'extra']);
  });

  test('matching central telephone does not merge different branches', () {
    final primary = SearchResult(
      id: 'new',
      name: 'Bar Uno',
      address: 'Via Roma 120, Torino',
      phones: ['01112345'],
    );
    final other = SearchResult(
      id: 'old',
      name: 'Bar Uno',
      address: 'Via Roma 12',
      city: 'Torino',
      phones: ['01112345'],
    );
    expect(sameDirectoryPlace(primary, other), isFalse);
  });

  test('existing PB fallback retains the source of old detail links', () async {
    final service = ItaliaOnlineService(
      clientToken: 'test-only',
      client: MockClient((request) async {
        if (request.url.host == 'sonarpad.com') return places();
        if (request.url.path.endsWith('searchpg')) {
          return http.Response('', 500);
        }
        return http.Response(legacy, 200);
      }),
    );
    final response = await service.searchActivities(query());
    expect(response.actualKind, DirectoryKind.pagineBianche);
    expect(response.results.last.id, 'pb:extra');
  });
}
