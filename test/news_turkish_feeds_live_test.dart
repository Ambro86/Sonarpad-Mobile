import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';

// Set SONARPAD_NEWS_FEED_FIXTURES to a directory containing freshly downloaded
// feeds and urls.json (name -> URL). Network snapshots stay outside the repo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final folder = Platform.environment['SONARPAD_NEWS_FEED_FIXTURES'];
  test('parses real Turkish feed dates and current headlines', () async {
    final urls = jsonDecode(File('$folder/urls.json').readAsStringSync()) as Map;
    for (final entry in urls.entries) {
      final bytes = File('$folder/${entry.key}.xml').readAsBytesSync();
      final service = NewsService(client: MockClient((_) async => http.Response.bytes(bytes, 200)));
      final articles = await service.fetchSourceNews(NewsRssSource(name: entry.key as String, uri: Uri.parse(entry.value as String)));
      expect(articles.length, greaterThan(5), reason: entry.key as String);
      expect(articles.every((a) => a.publishedAt != null), isTrue, reason: entry.key as String);
      final newest = articles.first.publishedAt!;
      expect(newest.isBefore(DateTime.now().add(const Duration(minutes: 10))), isTrue);
      expect(newest.isAfter(DateTime.now().subtract(const Duration(days: 7))), isTrue);
      // ignore: avoid_print
      print('${entry.key}: ${articles.length} articles, newest UTC ${newest.toUtc()}');
    }
  }, skip: folder == null ? 'Requires fresh network snapshots' : false);
}
