import 'package:matcher/matcher.dart';
import 'package:test_api/test_api.dart';
import 'package:sonarpad_mobile_starter/services/raiplay_service.dart';

void main() {
  test('keeps RaiPlay video master separate from described audio track', () {
    const masterUrl =
        'https://example.com/path/master.m3u8?token=abc';
    const playlist = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",LANGUAGE="ita",NAME="Italiano",URI="ita/audio.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",LANGUAGE="des",NAME="Audiodescrizione",URI="des/audio.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=2400000,AUDIO="audio"
video/playlist.m3u8
''';

    final media = RaiPlayService().resolveHlsPlaybackUrlsFromPlaylist(
      masterUrl,
      playlist,
      fallbackAudioUrl: masterUrl,
      logChildUrls: false,
    );

    expect(media.videoUrl, masterUrl);
    expect(media.hasDescribedAudio, isTrue);
    expect(
      media.audioUrl,
      'https://example.com/path/des/audio.m3u8?token=abc',
    );
  });

  test('resolves a real Mare Fuori episode into separate video and audio URLs',
      () async {
    const secretKey = String.fromEnvironment('RAIPLAY_SECRET');
    if (secretKey.trim().isEmpty) {
      markTestSkipped(
        'Pass RAIPLAY_SECRET with '
        '--dart-define=RAIPLAY_SECRET=<code> to run the real RaiPlay test.',
      );
      return;
    }

    final service = RaiPlayService();
    expect(service.isSecretCodeValid(secretKey), isTrue);

    final home = await service.loadRootPage(secretKey);
    print('RaiPlay home items: ${home.items.map((item) => item.title).join(' | ')}');
    final mareFuoriPage = home.items.firstWhere(
      (item) => item.kind == RaiPlayItemKind.page,
    );
    print('RaiPlay selected home item: ${mareFuoriPage.title}');

    expect(mareFuoriPage, isNotNull);

    final episode = await _findEpisodeInLatestSeason(
      service,
      secretKey,
      mareFuoriPage!,
    );

    expect(episode, isNotNull);

    final resolved = await service.resolvePlaybackUrls(episode!.mediaUrl);

    expect(resolved.videoUrl.toLowerCase(), contains('.m3u8'));
    expect(resolved.audioUrl.toLowerCase(), contains('.m3u8'));
    expect(resolved.videoUrl, isNot(equals(resolved.audioUrl)));
  });
}

Future<RaiPlayItem?> _findEpisodeInLatestSeason(
  RaiPlayService service,
  String secretKey,
  RaiPlayItem page,
) async {
  final visited = <String>{};
  final root = await service.loadPage(page.pathId, secretKey, pageTitle: page.title);
  print('RaiPlay Mare Fuori items: ${root.items.map((item) => item.title).join(' | ')}');
  final season = await _findSeasonPage(service, secretKey, root, visited);
  final episodePage = season ?? root;
  return _findEpisode(service, secretKey, episodePage, visited);
}

Future<RaiPlayPage?> _findSeasonPage(
  RaiPlayService service,
  String secretKey,
  RaiPlayPage page,
  Set<String> visited, {
  int depth = 0,
}) async {
  if (depth > 3) return null;
  final seasonItems = page.items
      .where((item) =>
          item.kind == RaiPlayItemKind.page &&
          _normalized(item.title).contains('stagione'))
      .toList();
  if (seasonItems.isNotEmpty) {
    final firstSeason = _firstOrNull(
          seasonItems.where((item) => _seasonNumber(item.title) == 1),
        ) ??
        seasonItems.first;
    print('RaiPlay selected season: ${firstSeason.title}');
    if (visited.add(firstSeason.pathId)) {
      return service.loadPage(firstSeason.pathId, secretKey, pageTitle: firstSeason.title);
    }
  }

  for (final item in page.items) {
    if (item.kind != RaiPlayItemKind.page || !visited.add(item.pathId)) {
      continue;
    }
    final child =
        await service.loadPage(item.pathId, secretKey, pageTitle: item.title);
    print('RaiPlay season scan depth=$depth page="${item.title}" '
        'items=${child.items.map((childItem) => childItem.title).join(' | ')}');
    final found = await _findSeasonPage(
      service,
      secretKey,
      child,
      visited,
      depth: depth + 1,
    );
    if (found != null) return found;
  }
  return null;
}

Future<RaiPlayItem?> _findEpisode(
  RaiPlayService service,
  String secretKey,
  RaiPlayPage page,
  Set<String> visited, {
  int depth = 0,
}) async {
  print('RaiPlay episode candidates: ${page.items.map((item) => item.title).join(' | ')}');
  final media = page.items.where((item) => item.kind == RaiPlayItemKind.media);
  final firstMedia = _firstOrNull(
        media.where((item) => _normalized(item.title).contains('vite spezzate')),
      ) ??
      _firstOrNull(media);
  if (firstMedia != null) return firstMedia;
  if (depth > 3) return null;

  for (final item in page.items) {
    if (item.kind != RaiPlayItemKind.page || !visited.add(item.pathId)) {
      continue;
    }
    final child =
        await service.loadPage(item.pathId, secretKey, pageTitle: item.title);
    final found = await _findEpisode(
      service,
      secretKey,
      child,
      visited,
      depth: depth + 1,
    );
    if (found != null) return found;
  }
  return null;
}

String _normalized(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

int _seasonNumber(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return match == null ? -1 : int.tryParse(match.group(0)!) ?? -1;
}

T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}

void expect(Object? actual, Object? expected) {
  final matcher = expected is Matcher ? expected : equals(expected);
  if (!matcher.matches(actual, <Object?, Object?>{})) {
    throw Exception('Expected $actual to match $expected');
  }
}
