import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../utils/app_logger.dart';
import 'sonartube_service.dart';

class _FeedHttpFailure implements Exception {
  const _FeedHttpFailure(this.statusCode);
  final int statusCode;

  @override
  String toString() => statusCode.toString();
}

class FavoriteChannelVideosResult {
  const FavoriteChannelVideosResult(this.items, this.failedChannels);
  final List<SonarTubeItem> items;
  final int failedChannels;
}

/// Reuse the channel Videos tab; feeds supply dates only, never extra items.
class FavoriteChannelVideosService {
  FavoriteChannelVideosService({http.Client? client, SonarTubeService? tube})
      : _client = client, _tube = tube ?? SonarTubeService();
  final http.Client? _client;
  final SonarTubeService _tube;

  Future<http.Response> _loadFeed(http.Client client, String id) async {
    final uri = Uri.https('www.youtube.com', '/feeds/videos.xml', {'channel_id': id});
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await client.get(uri).timeout(const Duration(seconds: 20));
        final status = response.statusCode;
        if (status == 200) return response;
        final retryable = status == 404 || status == 408 || status == 429 || status >= 500;
        await AppLogger.log('FavoriteChannelVideos: feed channel=$id attempt=$attempt status=$status');
        if (!retryable || attempt >= 3) throw _FeedHttpFailure(status);
      } on http.ClientException catch (error) {
        await AppLogger.log('FavoriteChannelVideos: feed channel=$id attempt=$attempt network=$error');
        if (attempt >= 3) rethrow;
      } on TimeoutException {
        await AppLogger.log('FavoriteChannelVideos: feed channel=$id attempt=$attempt timeout');
        if (attempt >= 3) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
    }
  }

  Future<FavoriteChannelVideosResult> load(List<SonarTubeItem> favorites) async {
    final channels = <String, SonarTubeItem>{
      for (final item in favorites)
        if (item.kind == SonarTubeItemKind.channel) item.id: item,
    }.values.toList();
    final client = _client ?? http.Client();
    final videos = <String, SonarTubeItem>{};
    final ranks = <String, int>{};
    var failed = 0;
    var next = 0;
    Future<void> worker() async {
      while (next < channels.length) {
        final channelIndex = next++;
        final channel = channels[channelIndex];
        try {
          final page = await _tube.browse(
            channel, channelSort: SonarTubeChannelSort.newest,
          ).timeout(const Duration(seconds: 25));
          final items = page.items
              .where((item) => item.kind == SonarTubeItemKind.video && !item.isLive)
              .take(15).toList();
          if (items.isEmpty) continue;
          // RSS also includes Shorts. Use it only to date videos already
          // returned by the same Videos tab used when opening this channel.
          final dates = <String, String>{};
          try {
            var id = channel.channelId ?? channel.id;
            if (!RegExp(r'^UC[\w-]{22}$').hasMatch(id)) {
              id = items.first.channelId ?? '';
            }
            if (!RegExp(r'^UC[\w-]{22}$').hasMatch(id)) {
              id = (await _tube.channelForVideo(items.first)
                  .timeout(const Duration(seconds: 20))).id;
            }
            final response = await _loadFeed(client, id);
            final feed = XmlDocument.parse(response.body);
            for (final entry in feed.findAllElements('entry')) {
              String text(String name) => entry.descendants.whereType<XmlElement>()
                  .where((node) => node.name.local == name)
                  .map((node) => node.innerText).firstOrNull ?? '';
              final published = DateTime.tryParse(text('published'));
              if (published != null) {
                dates[text('videoId')] = published.toUtc().toIso8601String();
              }
            }
          } catch (error) {
            await AppLogger.log('FavoriteChannelVideos: dates unavailable channel=${channel.id} error=$error; keeping channel videos');
          }
          for (var index = 0; index < items.length; index++) {
            final item = items[index];
            final rank = channelIndex * 15 + index;
            if (ranks.containsKey(item.id) && ranks[item.id]! <= rank) continue;
            ranks[item.id] = rank;
            videos[item.id] = SonarTubeItem(
              kind: item.kind, id: item.id, title: item.title, url: item.url,
              channelId: item.channelId ?? channel.channelId ?? channel.id,
              channel: item.channel ?? channel.title,
              thumbnailUrl: item.thumbnailUrl, duration: item.duration,
              views: item.views, published: dates[item.id] ?? item.published,
              description: item.description, isLive: item.isLive,
            );
          }
        } catch (error, stack) {
          failed++;
          await AppLogger.log('FavoriteChannelVideos: failed channel=${channel.id} error=$error\n$stack');
        }
      }
    }
    try {
      await Future.wait(List.generate(channels.length.clamp(0, 4), (_) => worker()));
      await AppLogger.log('FavoriteChannelVideos: channels=${channels.length} videos=${videos.length} failed=$failed');
      if (channels.isNotEmpty && failed == channels.length) {
        throw StateError('all_channel_videos_failed');
      }
      final items = videos.values.toList()..sort((a, b) {
        final dateA = DateTime.tryParse(a.published ?? '');
        final dateB = DateTime.tryParse(b.published ?? '');
        if (dateA != null && dateB != null) {
          final order = dateB.compareTo(dateA);
          if (order != 0) return order;
        } else if (dateA != null || dateB != null) {
          return dateA != null ? -1 : 1;
        }
        return ranks[a.id]!.compareTo(ranks[b.id]!);
      });
      return FavoriteChannelVideosResult(items, failed);
    } finally {
      if (_client == null) client.close();
    }
  }
}
