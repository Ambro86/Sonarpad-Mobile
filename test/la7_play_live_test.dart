import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sonarpad_mobile_starter/services/la7_play_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final overrides = HttpOverrides.current;
  setUp(() => HttpOverrides.global = null);
  tearDown(() => HttpOverrides.global = overrides);
  test(
    'live catalogue, free HLS and catch-up',
    () async {
      final service = La7PlayService();
      final programs = await service.loadPage('programs');
      expect(programs.items.length, greaterThan(10));
      final program = programs.items.firstWhere(
        (p) => p.title == 'Otto e mezzo',
      );
      final episodes = await service.loadPage(program.target);
      expect(episodes.items, isNotEmpty);
      String? stream;
      for (final episode in episodes.items.take(12)) {
        try {
          stream = await service.resolveVod(episode.target);
          break;
        } catch (error) {
          if (!error.toString().contains('Widevine')) rethrow;
        }
      }
      expect(stream, isNotNull, reason: 'No free episode in sampled catalogue');
      final manifest = await http
          .get(Uri.parse(stream!))
          .timeout(const Duration(seconds: 30));
      expect(manifest.statusCode, 200);
      expect(manifest.body.startsWith('#EXTM3U'), isTrue);
      final days = await service.loadPage('rivedi');
      expect(days.items, isNotEmpty);
      final day = await service.loadPage(days.items.first.target);
      expect(day.items, isNotEmpty);
    },
    skip: Platform.environment['SONARPAD_LIVE_LA7_TEST'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
