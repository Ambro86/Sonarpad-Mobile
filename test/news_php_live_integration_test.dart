// Opt-in live audit: SONARPAD_NEWS_AUDIT_DIR and SONARPAD_NEWS_PHP required.
// Run with flutter test --no-pub test/news_php_live_integration_test.dart --reporter expanded.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/models/news_article.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/italian_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/english_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/spanish_news_sources.dart';
import 'package:sonarpad_mobile_starter/services/news_sources/news_rss_source.dart';

class AuditClient extends http.BaseClient {
  final int port;
  final http.Client inner = http.Client();
  final List<Map<String, dynamic>> responses = [];
  AuditClient(this.port);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == 'sonarpad.com' &&
        request.url.path.endsWith('/tinyfish_fetch_article.php')) {
      final local = Uri.parse(
        'http://127.0.0.1:$port/',
      ).replace(query: request.url.query);
      final forwarded = http.Request(request.method, local)
        ..headers.addAll(request.headers);
      final response = await http.Response.fromStream(
        await inner.send(forwarded),
      );
      if (request.url.queryParameters.containsKey('url')) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          data = {
            'invalid_json': true,
            'body': response.body.substring(
              0,
              response.body.length.clamp(0, 200),
            ),
          };
        }
        responses.add({
          'request_url': request.url.queryParameters['url'],
          'status': response.statusCode,
          ...data,
        });
      }
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    return inner.send(request);
  }

  @override
  void close() {
    inner.close();
    super.close();
  }
}

void main() {
  final directory = Platform.environment['SONARPAD_NEWS_AUDIT_DIR'];
  final phpFile = Platform.environment['SONARPAD_NEWS_PHP'];
  final international =
      Platform.environment['SONARPAD_NEWS_INTERNATIONAL'] == '1';
  final allSources = international
      ? [
          ...englishNewsSources.where(
            (s) => [
              'BBC News',
              'World news The Guardian',
              'Sky News – Home',
              'NPR – News',
              'Al Jazeera – Breaking News',
            ].any((name) => s.name.startsWith(name)),
          ),
          ...spanishNewsSources.where(
            (s) => [
              'EL PAÍS – Portada',
              'El Mundo – Portada',
              'RTVE Noticias – Temas noticias',
              'elDiario.es – Portada',
              'La Vanguardia – Portada',
            ].contains(s.name),
          ),
          NewsRssSource(
            name: 'Repubblica (additional)',
            uri: Uri.parse('https://www.repubblica.it/rss/homepage/rss2.0.xml'),
          ),
        ]
      : italianNewsSources;
  final selectedNames = Platform.environment['SONARPAD_NEWS_SOURCES']?.split(
    '|',
  );
  final sources = allSources
      .where(
        (source) =>
            selectedNames == null || selectedNames.contains(source.name),
      )
      .toList();
  NewsLanguage languageFor(String name) =>
      englishNewsSources.any((s) => s.name == name)
      ? NewsLanguage.english
      : spanishNewsSources.any((s) => s.name == name)
      ? NewsLanguage.spanish
      : NewsLanguage.italian;
  test(
    'Italian sources: real NewsService -> local PHP -> Python',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory(directory!)..createSync(recursive: true);
      final manifestFile = File('${dir.path}/manifest.json');
      final output = File('${dir.path}/results.jsonl');
      final collectOnly =
          Platform.environment['SONARPAD_NEWS_COLLECT_ONLY'] == '1';
      final router = File('${dir.path}/router.php');
      router.writeAsStringSync(
        '<?php require ${jsonEncode(phpFile!.replaceAll(r'\', '/'))};',
      );
      final servers = <Process>[];
      final clients = <AuditClient>[];
      final services = <NewsService>[];
      try {
        for (var i = 0; i < 6; i++) {
          final port = 18940 + i;
          final server = await Process.start(
            'php',
            ['-S', '127.0.0.1:$port', router.path],
            environment: {
              'SONARPAD_READER_DISABLE_TINYFISH':
                  Platform.environment['SONARPAD_NEWS_ENABLE_TINYFISH'] == '1'
                  ? '0'
                  : '1',
            },
          );
          server.stdout.drain<void>();
          server.stderr.drain<void>();
          servers.add(server);
          final client = AuditClient(port);
          clients.add(client);
          services.add(NewsService(client: client));
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        NewsService.resetTinyfishFallbackOnlyPolicyForTests();
        expect(
          await services.first.loadTinyfishFallbackOnlyPolicyForSession(),
          isFalse,
          reason: 'Local PHP policy must select the PHP-first path',
        );
        List<dynamic> manifest;
        if (manifestFile.existsSync()) {
          manifest = jsonDecode(manifestFile.readAsStringSync()) as List;
        } else {
          manifest = [];
          var index = 0;
          await Future.wait(
            List.generate(6, (worker) async {
              while (index < sources.length) {
                final source = sources[index++];
                final items = <Map<String, dynamic>>[];
                String? error;
                try {
                  final articles = await services[worker]
                      .fetchSourceNews(
                        source,
                        language: languageFor(source.name),
                      )
                      .timeout(const Duration(seconds: 90));
                  final seen = <String>{};
                  for (final article in articles) {
                    if (!seen.add(article.link)) continue;
                    final resolved = await services[worker]
                        .resolveArticleUrlForSharing(article.link);
                    if (RegExp(
                      r'^/(?:tag|author|category)/',
                    ).hasMatch(Uri.parse(resolved).path)) {
                      continue;
                    }
                    items.add({
                      'title': article.title,
                      'link': article.link,
                      'resolved': resolved,
                      'summary': article.summary,
                      'source': source.name,
                      'language': languageFor(source.name).name,
                    });
                    if (items.length == 5) break;
                  }
                } catch (e) {
                  error = '$e';
                }
                manifest.add({
                  'source': source.name,
                  'feed': '${source.uri}',
                  'articles': items,
                  'error': error,
                });
                File('${dir.path}/manifest.partial.json').writeAsStringSync(
                  const JsonEncoder.withIndent('  ').convert(manifest),
                );
                // ignore: avoid_print
                print(
                  'COLLECT ${source.name}: ${items.length}/5 ${error ?? ''}',
                );
              }
            }),
          );
          manifestFile.writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(manifest),
          );
        }
        if (collectOnly) return;
        final articles = [
          for (final source in manifest) ...source['articles'] as List,
        ];
        final completed = <String>{};
        final contractErrors = <String>[];
        final hostQueues = <String, Future<void>>{};
        if (output.existsSync()) {
          for (final line in output.readAsLinesSync()) {
            if (line.trim().isNotEmpty) {
              final row = jsonDecode(line);
              completed.add('${row['source']}|${row['link']}');
            }
          }
        }
        var index = 0;
        await Future.wait(
          List.generate(6, (worker) async {
            while (index < articles.length) {
              final row = Map<String, dynamic>.from(articles[index++]);
              if (completed.contains('${row['source']}|${row['link']}')) {
                continue;
              }
              final host = Uri.parse(row['resolved']).host;
              final previous = hostQueues[host] ?? Future<void>.value();
              final released = Completer<void>();
              hostQueues[host] = released.future;
              await previous;
              final client = clients[worker];
              client.responses.clear();
              final watch = Stopwatch()..start();
              try {
                final result = await services[worker]
                    .fetchArticleContent(
                      NewsArticle(
                        id: row['link'],
                        title: row['title'],
                        link: row['resolved'],
                        summary: row['summary'],
                        source: row['source'],
                        publishedAt: null,
                      ),
                      language: NewsLanguage.values.byName(
                        row['language'] ?? 'italian',
                      ),
                    )
                    .timeout(const Duration(seconds: 65));
                for (final response in client.responses.where(
                  (r) => r['ok'] == true,
                )) {
                  if (response['format'] == 'text' &&
                      (result.text != (response['markdown'] as String).trim() ||
                          result.text.runes.length !=
                              response['text_length'])) {
                    contractErrors.add(
                      '${row['source']}: PHP text changed in Dart',
                    );
                  }
                }
                row.addAll({
                  'dart_text': result.text,
                  'dart_length': result.text.length,
                  'dart_url': result.url,
                  'summary_only':
                      result.text.trim() == (row['summary'] as String).trim(),
                });
              } catch (e) {
                row['error'] = '$e';
              } finally {
                await Future<void>.delayed(const Duration(milliseconds: 500));
                released.complete();
              }
              row['php'] = List.of(client.responses);
              row['elapsed_ms'] = watch.elapsedMilliseconds;
              output.writeAsStringSync(
                '${jsonEncode(row)}\n',
                mode: FileMode.append,
              );
              // ignore: avoid_print
              print(
                'ARTICLE ${row['source']}: php=${client.responses.map((r) => r['status']).join(',')} dart=${row['dart_length']} ${row['title']}',
              );
            }
          }),
        );
        expect(articles, isNotEmpty);
        expect(contractErrors, isEmpty, reason: contractErrors.join('\n'));
      } finally {
        for (final client in clients) {
          client.close();
        }
        for (final server in servers) {
          server.kill();
          await server.exitCode;
        }
      }
    },
    skip: directory == null || phpFile == null,
    timeout: const Timeout(Duration(hours: 2)),
  );
}
