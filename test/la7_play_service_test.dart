import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/la7_play_service.dart';

String fixture(String name) =>
    File('test/fixtures/la7play/$name.html').readAsStringSync();

Future<T> withPage<T>(String html, Future<T> Function() run) =>
    http.runWithClient(
      run,
      () => MockClient(
        (request) async => http.Response(
          html,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'search retains editorial clips separately from the program folder',
    () async {
      await http.runWithClient(
        () async {
          final page = await La7PlayService().search('Otto e mezzo');
          expect(
            page.items
                .where((item) => item.kind == La7PlayItemKind.page)
                .length,
            1,
          );
          final clips = page.items.where(
            (item) => item.kind == La7PlayItemKind.media,
          );
          expect(clips.length, 20);
          expect(
            clips.every((item) => item.target.contains('/video/')),
            isTrue,
          );
        },
        () => MockClient(
          (request) async => http.Response(
            fixture(request.url.path == '/programmi' ? 'programs' : 'prop'),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          ),
        ),
      );
    },
  );

  test('new catalogue lists programs without old manual entries', () async {
    final page = await withPage(
      fixture('programs'),
      () => La7PlayService().loadPage('programs'),
    );
    expect(page.items.length, 58);
    expect(page.items.any((item) => item.title == 'Otto e mezzo'), isTrue);
    expect(
      page.items.every(
        (item) => item.target.startsWith('program:https://www.la7play.it/'),
      ),
      isTrue,
    );
  });

  test(
    'new program folders contain full episodes, not editorial clips',
    () async {
      final page = await withPage(
        fixture('prop'),
        () => La7PlayService().loadPage(
          'program:https://www.la7play.it/otto-e-mezzo',
        ),
      );
      expect(page.items, isNotEmpty);
      expect(
        page.items.every((item) => item.target.contains('/puntate/')),
        isTrue,
      );
      expect(page.items.first.title, contains('30/10/2026'));
    },
  );

  test('guide parses split data chunks and opens the selected day', () async {
    await withPage(fixture('guide'), () async {
      final service = La7PlayService();
      final days = await service.loadPage('rivedi');
      expect(days.items.map((item) => item.title), [
        '27/10/2026',
        '26/10/2026',
      ]);
      final page = await service.loadPage(days.items.last.target);
      expect(page.items.first.title, '07:00 — Omnibus ST.27');
      expect(page.items.first.target, contains('/puntata-del-26-10-2026-'));
      expect(
        page.items.every((item) => item.kind == La7PlayItemKind.media),
        isTrue,
      );
    });
  });

  test('free video uses its CDN paths even when player supports DRM', () async {
    final url = await withPage(
      fixture('free-episode'),
      () => La7PlayService().resolveVod('https://www.la7play.it/episode'),
    );
    expect(
      url,
      startsWith('https://awsvodpkg.iltrovatore.it/local/hls/,/nk/content/'),
    );
    expect(url, endsWith(',.mp4.urlset/master.m3u8'));
    expect(url, isNot(contains('/nk/nk/')));
  });

  test('protected episode retains the DRM error', () async {
    await withPage(fixture('episode'), () async {
      await expectLater(
        La7PlayService().resolveVod('https://www.la7play.it/episode'),
        throwsA(predicate((error) => error.toString().contains('Widevine'))),
      );
    });
  });

  test('legacy m3u8 player remains supported', () async {
    final url = await withPage(
      '<script>var player={m3u8:"https://example.test/video.m3u8"}</script>',
      () => La7PlayService().resolveVod('https://www.la7.it/old-episode'),
    );
    expect(url, 'https://example.test/video.m3u8');
  });
}
