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

void main() {
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
          if (request.url.path.endsWith('searchpg'))
            return http.Response('', 500);
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
          paths.add(request.url.path.split('/').last);
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
      expect(paths, ['searchpb', 'searchpg']);
      expect(response.results.map((item) => item.id), [
        'pb:matching',
        'pg:matching',
      ]);
      for (final item in response.results) {
        await service.loadDetail(query, item.id);
      }
      expect(paths, ['searchpb', 'searchpg', 'detailpb', 'detailpg']);
    },
  );
  test(
    'combined phone lookup deduplicates the existing provider fallback',
    () async {
      final service = ItaliaOnlineService(
        client: MockClient(
          (request) async => request.url.path.endsWith('searchpg')
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
      expect(response.results.map((item) => item.id), ['pg:matching']);
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
