import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';

void main() {
  const id = '661f8f4c307fa30008033ab5';
  final service = TvService();
  final pluto = TvChannel(
    name: 'Gambero Rosso',
    url: 'https://sonarpad.com/api/pluto.php?id=$id',
    category: 'Cucina',
    tvgName: 'Gambero Rosso',
  );
  final terrestrial = TvChannel(
    name: 'Gambero Rosso',
    url: 'https://example.com/live',
    category: 'TV',
  );
  Map<String, Object> program(String title, int start, int end) => {
    'title': title,
    'hour': '18:00',
    'startTime': start,
    'endTime': end,
    'description': 'Descrizione episodio',
  };

  test('Pluto and terrestrial names never share guide keys', () {
    expect(service.plutoId(pluto), id);
    expect(service.guideLookupKeys(pluto), ['pluto:$id']);
    expect(service.guideLookupKeys(terrestrial), contains('gamberorosso'));
    expect(service.guideLookupKeys(terrestrial), isNot(contains('pluto:$id')));
    final malformed = TvChannel(
      name: 'Gambero Rosso',
      url: 'https://sonarpad.com/api/pluto.php?id=invalid',
      category: 'Pluto TV',
    );
    expect(service.guideLookupKeys(malformed), isEmpty);
  });

  test(
    'Pluto now survives an Oggi failure and ignores future and old data',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await http.runWithClient(
        () async {
          final programs = await service.loadCurrentPrograms(
            'invalid-test-key',
            channels: [pluto, terrestrial],
          );
          expect(programs['pluto:$id']?.title, 'Programma Pluto');
          expect(programs.containsKey('gamberorosso'), isFalse);
        },
        () => MockClient((request) async {
          expect(request.url.path, '/api/pluto_guide.php');
          expect(request.headers, contains('X-Sonarpad-TV-Token'));
          return http.Response(
            jsonEncode({
              'programs': {id: program('Programma Pluto', now - 60, now + 60)},
            }),
            200,
          );
        }),
      );
      for (final times in [
        [now + 60, now + 120],
        [now - 30000, now - 25000],
      ]) {
        await http.runWithClient(
          () async {
            expect(
              await service.loadCurrentPrograms(
                'invalid-test-key',
                channels: [pluto],
              ),
              isEmpty,
            );
          },
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'programs': {id: program('Non in onda', times[0], times[1])},
              }),
              200,
            ),
          ),
        );
      }
    },
  );

  test(
    'Pluto day guide uses id and date, filters invalid items and sorts',
    () async {
      await http.runWithClient(
        () async {
          final guide = await service.loadChannelGuideForChannel(
            pluto,
            '',
            targetDate: DateTime(2026, 10, 3),
          );
          expect(guide.map((p) => p.title), ['Prima', 'Dopo']);
          expect(guide.first.description, 'Descrizione episodio');
        },
        () => MockClient((request) async {
          expect(request.url.host, 'sonarpad.com');
          expect(request.url.queryParameters, {'id': id, 'date': '2026-10-03'});
          return http.Response(
            jsonEncode({
              'programs': [
                program('Dopo', 300, 400),
                program('', 100, 200),
                program('Prima', 100, 200),
                program('Errato', 500, 400),
                null,
              ],
            }),
            200,
          );
        }),
      );
    },
  );

  test(
    'Pluto outages leave now empty and surface day guide error without fallback',
    () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          expect(
            await service.loadCurrentPrograms(
              'invalid-test-key',
              channels: [pluto],
            ),
            isEmpty,
          );
          await expectLater(
            service.loadChannelGuideForChannel(pluto, ''),
            throwsException,
          );
          expect(requests, 2);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.path, '/api/pluto_guide.php');
          return http.Response('{}', 502);
        }),
      );
    },
  );

  test('An empty day remains empty', () async {
    await http.runWithClient(() async {
      expect(await service.loadChannelGuideForChannel(pluto, ''), isEmpty);
    }, () => MockClient((_) async => http.Response('{"programs":[]}', 200)));
  });
}
