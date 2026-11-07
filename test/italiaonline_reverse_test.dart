import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/italiaonline_service.dart';

const fixture =
    '''<response><status>200</status><current_page>2</current_page><isLastPage>1</isLastPage><results>
<result><id>matching</id><name>Ente pubblico</name><phones><phone><number>+39 02 0202</number></phone></phones></result>
<result><id>other</id><name>Risultato non pertinente</name><phones><phone><number>021234567</number></phone></phones></result>
</results></response>''';

const yellowFixture = '''<input id="numero" value="020202">
<div class="search-itm" data-tr="listing-search-itm"><div class="search-itm__info">
<a href="https://www.paginegialle.it/matching"><h2 class="search-itm__rag">Ente pubblico</h2></a>
<div class="search-itm__adr">Via Roma, 12 - Milano</div>
<span class="search-itm__phone-item">+39 02 0202</span></div></div>
<div class="search-itm" data-tr="listing-search-itm"><div class="search-itm__info">
<a href="https://www.paginegialle.it/sponsor"><h2 class="search-itm__rag">Sponsored</h2></a>
<span class="search-itm__phone-item">021234567</span></div></div>''';

void main() {
  test('international format keeps country codes and national zeroes', () {
    expect(normalizePlacePhone('0033 1 58 59 22 22'), '+33158592222');
    expect(normalizePlacePhone('+39 (02) 0202'), '+39020202');
    expect(normalizePlacePhone('01 58 59 22 22'), '0158592222');
    for (final value in ['', '123', 'abc', '02+0202', '+1234567890123456']) {
      expect(() => normalizePlacePhone(value), throwsFormatException);
    }
  });

  test(
    'phone formats preserve the leading zero and reject text/other countries',
    () {
      for (final value in ['02 02 02', '+39 (02) 02-02', '0039 02.02.02']) {
        expect(normalizeDirectoryPhone(value), '020202');
      }
      for (final value in ['', '123', 'Milano', '+33 123456789', '02+0202']) {
        expect(() => normalizeDirectoryPhone(value), throwsFormatException);
      }
    },
  );
  test(
    'reverse request normalizes number, ignores place, preserves page and filters other numbers',
    () async {
      final service = ItaliaOnlineService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['what'], '020202');
          expect(request.url.queryParameters.containsKey('where'), isFalse);
          expect(request.url.queryParameters['page'], '2');
          return http.Response(fixture, 200);
        }),
      );
      final response = await service.search(
        SearchQuery(
          kind: DirectoryKind.pagineBianche,
          what: '+39 (02) 0202',
          where: 'Roma',
          page: 2,
          reverse: true,
        ),
      );
      expect(response.results.map((r) => r.id), ['matching']);
      expect(response.currentPage, 2);
    },
  );
  test(
    'yellow pages server fallback preserves reverse mode and actual detail provider',
    () async {
      var calls = 0;
      final service = ItaliaOnlineService(
        client: MockClient((request) async {
          calls++;
          if (request.url.host == 'www.paginegialle.it') {
            return http.Response('', 500);
          }
          expect(request.url.path.endsWith('searchpb'), isTrue);
          return http.Response(fixture, 200);
        }),
      );
      final response = await service.search(
        SearchQuery(
          kind: DirectoryKind.pagineGialle,
          what: '020202',
          reverse: true,
        ),
      );
      expect(calls, 2);
      expect(response.actualKind, DirectoryKind.pagineBianche);
      expect(response.results.map((r) => r.id), ['matching']);
    },
  );
  test('normal name search retains location and all results', () async {
    final service = ItaliaOnlineService(
      client: MockClient((request) async {
        expect(request.url.queryParameters['what'], 'Comune');
        expect(request.url.queryParameters['where'], 'Milano');
        return http.Response(fixture, 200);
      }),
    );
    expect(
      (await service.search(
        SearchQuery(
          kind: DirectoryKind.pagineBianche,
          what: 'Comune',
          where: 'Milano',
        ),
      )).results.length,
      2,
    );
  });
  test(
    'unavailable reverse service is not presented as a missing owner',
    () async {
      final service = ItaliaOnlineService(
        client: MockClient((_) async => http.Response('', 500)),
      );
      await expectLater(
        service.search(
          SearchQuery(
            kind: DirectoryKind.pagineGialle,
            what: '020202',
            reverse: true,
          ),
        ),
        throwsException,
      );
    },
  );
  test(
    'phone section searches both providers and routes each detail to its source',
    () async {
      final paths = <String>[];
      final service = ItaliaOnlineService(
        client: MockClient((request) async {
          final yellow = request.url.host == 'www.paginegialle.it';
          paths.add(yellow ? 'pg-phone' : request.url.path.split('/').last);
          if (yellow) {
            expect(request.url.path, '/ricerca/telefono-020202/p-2');
            expect(request.url.queryParameters, isEmpty);
            return http.Response(yellowFixture, 200);
          }
          expect(request.url.queryParameters['what'], '020202');
          expect(request.url.queryParameters.containsKey('where'), isFalse);
          if (request.url.path.contains('detail')) {
            expect(request.url.queryParameters['id'], 'matching');
            return http.Response(
              '<response><detail><name>Ente pubblico</name></detail></response>',
              200,
            );
          }
          expect(request.url.queryParameters['page'], '2');
          return http.Response(fixture, 200);
        }),
      );
      final query = SearchQuery(
        kind: DirectoryKind.pagineBianche,
        what: '+39 02 0202',
        page: 2,
        reverse: true,
      );
      final response = await service.searchPhone(query);
      expect(paths, ['searchpb', 'pg-phone']);
      expect(response.results.map((item) => item.id), [
        'pb:matching',
        'pg:matching',
      ]);
      for (final item in response.results) {
        await service.loadDetail(query, item.id);
      }
      expect(paths, ['searchpb', 'pg-phone', 'detailpb', 'detailpg']);
    },
  );
  test(
    'combined phone lookup deduplicates the existing provider fallback',
    () async {
      final service = ItaliaOnlineService(
        client: MockClient(
          (request) async => request.url.host == 'www.paginegialle.it'
              ? http.Response('', 500)
              : http.Response(fixture, 200),
        ),
      );
      final response = await service.searchPhone(
        SearchQuery(
          kind: DirectoryKind.pagineBianche,
          what: '020202',
          reverse: true,
        ),
      );
      expect(response.results.map((item) => item.id), ['pb:matching']);
    },
  );
  test(
    'combined phone lookup keeps results when one provider is unavailable',
    () async {
      final service = ItaliaOnlineService(
        client: MockClient(
          (request) async => request.url.path.endsWith('searchpb')
              ? http.Response('', 503)
              : http.Response(yellowFixture, 200),
        ),
      );
      final response = await service.searchPhone(
        SearchQuery(
          kind: DirectoryKind.pagineBianche,
          what: '020202',
          reverse: true,
        ),
      );
      expect(response.results.map((item) => item.id), ['pg:matching']);
    },
  );
  test(
    'yellow phone page filters sponsors and preserves pagination without sending API tokens',
    () async {
      final service = ItaliaOnlineService(
        clientToken: 'private-test-token',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://www.paginegialle.it/ricerca/telefono-020202',
          );
          expect(
            request.headers.containsKey('X-Sonarpad-Route-Token'),
            isFalse,
          );
          return http.Response(
            '$yellowFixture<a class="next-page-btn" data-pageurl="/ricerca/telefono-020202/p-2"></a>',
            200,
          );
        }),
      );
      final result = await service.search(
        SearchQuery(
          kind: DirectoryKind.pagineGialle,
          what: '0039 (02) 0202',
          where: 'ignored',
          reverse: true,
        ),
      );
      expect(result.results.single.id, 'matching');
      expect(result.results.single.address, contains('Milano'));
      expect(result.isLastPage, isFalse);
    },
  );

  test(
    'blocked yellow response is not confused with no matching phone',
    () async {
      for (final body in [
        '<html>Access denied</html>',
        '<input id="numero" value="011999999">',
      ]) {
        final service = ItaliaOnlineService(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          service.search(
            SearchQuery(
              kind: DirectoryKind.pagineGialle,
              what: '020202',
              reverse: true,
            ),
          ),
          throwsException,
        );
      }
      final service = ItaliaOnlineService(
        client: MockClient(
          (_) async => http.Response('<input id="numero" value="020202">', 200),
        ),
      );
      final result = await service.search(
        SearchQuery(
          kind: DirectoryKind.pagineGialle,
          what: '020202',
          reverse: true,
        ),
      );
      expect(result.results, isEmpty);
      expect(result.isLastPage, isTrue);
    },
  );

  test('live public Comune di Milano number through both directories', () async {
    // Public institutional contact: https://www.comune.milano.it/it/amministrazione/amministrazione-trasparente/organizzazione/telefono-e-posta-elettronica/il-comune-e...-pronto
    final service = ItaliaOnlineService();
    for (final kind in DirectoryKind.values) {
      final result = await service.search(
        SearchQuery(kind: kind, what: '+39 02 0202', reverse: true),
      );
      expect(result.results, isNotEmpty);
      expect(
        result.results.every(
          (r) => r.phones.any((p) => normalizeDirectoryPhone(p) == '020202'),
        ),
        isTrue,
      );
    }
  }, skip: Platform.environment['SONARPAD_LIVE_DIRECTORY_TEST'] != '1');
}
