import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  const runLiveTests = bool.fromEnvironment('RUN_LIVE_SONARTUBE_TESTS');
  final service = SonarTubeService(
    // Intentionally unusable: when these tests pass, navigation really came
    // from direct InnerTube and did not silently use sonarpad.com.
    endpoint: Uri.parse('http://127.0.0.1:9/youtube_resolve.php'),
  );

  SonarTubePage? firstPage;

  setUpAll(() async {
    if (!runLiveTests) return;
    firstPage = await service.search('elisa');
  });

  test(
    'live direct InnerTube search returns real video results',
    () async {
      final page = firstPage!;
      expect(page.items, isNotEmpty);
      final videos = page.items
          .where((item) => item.kind == SonarTubeItemKind.video)
          .toList();
      expect(videos, isNotEmpty);
      expect(videos.every((item) => item.title.trim().isNotEmpty), isTrue);
      expect(
        videos.every(
          (item) => item.url.startsWith('https://www.youtube.com/watch?v='),
        ),
        isTrue,
      );
      expect(
        page.items.any((item) {
          final haystack = '${item.title} ${item.channel ?? ''}'.toLowerCase();
          return haystack.contains('elisa');
        }),
        isTrue,
        reason: 'The live search did not return any Elisa-related result.',
      );
    },
    skip: runLiveTests
        ? false
        : 'Live test: run with '
            '--dart-define=RUN_LIVE_SONARTUBE_TESTS=true.',
  );

  test(
    'live direct InnerTube continuation loads a different page',
    () async {
      final page = firstPage!;
      expect(page.hasMore, isTrue,
          reason: 'YouTube search did not expose a continuation token.');
      final next = await service.search(
        'elisa',
        token: page.nextToken,
        page: 2,
      );
      expect(next.items, isNotEmpty);
      expect(next.page, 2);
      final firstIds = page.items
          .map((item) => '${item.kind.name}:${item.id}')
          .toSet();
      final nextIds = next.items
          .map((item) => '${item.kind.name}:${item.id}')
          .toSet();
      expect(
        nextIds.difference(firstIds),
        isNotEmpty,
        reason: 'The continuation repeated only first-page results.',
      );
    },
    skip: runLiveTests
        ? false
        : 'Live test: run with '
            '--dart-define=RUN_LIVE_SONARTUBE_TESTS=true.',
  );

  test(
    'live direct InnerTube opens a channel through its uploads playlist',
    () async {
      final channel = firstPage!.items
          .where((item) => item.kind == SonarTubeItemKind.channel)
          .first;
      final page = await service.browse(channel);
      expect(page.items, isNotEmpty);
      expect(
        page.items.every((item) => item.kind == SonarTubeItemKind.video),
        isTrue,
      );
    },
    skip: runLiveTests
        ? false
        : 'Live test: run with '
            '--dart-define=RUN_LIVE_SONARTUBE_TESTS=true.',
  );

  test(
    'live direct InnerTube opens a playlist',
    () async {
      final playlist = firstPage!.items
          .where((item) => item.kind == SonarTubeItemKind.playlist)
          .first;
      final page = await service.browse(playlist);
      expect(page.items, isNotEmpty);
      expect(
        page.items.every((item) => item.kind == SonarTubeItemKind.video),
        isTrue,
      );
    },
    skip: runLiveTests
        ? false
        : 'Live test: run with '
            '--dart-define=RUN_LIVE_SONARTUBE_TESTS=true.',
  );
}
