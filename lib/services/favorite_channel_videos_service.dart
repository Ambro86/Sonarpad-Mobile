import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'sonartube_service.dart';

class FavoriteChannelVideosResult {
  const FavoriteChannelVideosResult(this.items, this.failedChannels);
  final List<SonarTubeItem> items;
  final int failedChannels;
}

/// YouTube feeds contain a bounded window of recent uploads per channel,
/// with absolute publication dates suitable for merging across channels.
class FavoriteChannelVideosService {
  FavoriteChannelVideosService({http.Client? client, SonarTubeService? tube})
      : _client = client, _tube = tube ?? SonarTubeService();
  final http.Client? _client;
  final SonarTubeService _tube;

  Future<FavoriteChannelVideosResult> load(List<SonarTubeItem> favorites) async {
    final channels = <String, SonarTubeItem>{
      for (final item in favorites)
        if (item.kind == SonarTubeItemKind.channel) item.id: item,
    }.values.toList();
    final client = _client ?? http.Client();
    final videos = <String, SonarTubeItem>{};
    var failed = 0;
    var next = 0;
    Future<void> worker() async {
      while (next < channels.length) {
        final channel = channels[next++];
        try {
          var id = channel.channelId ?? channel.id;
          if (!RegExp(r'^UC[\w-]{22}$').hasMatch(id)) {
            final page = await _tube.browse(channel).timeout(const Duration(seconds: 25));
            if (page.items.isEmpty) continue;
            id = (await _tube.channelForVideo(page.items.first)
                .timeout(const Duration(seconds: 20))).id;
          }
          if (!RegExp(r'^UC[\w-]{22}$').hasMatch(id)) {
            throw const FormatException('channel_id_unavailable');
          }
          final response = await client.get(Uri.https(
            'www.youtube.com', '/feeds/videos.xml', {'channel_id': id},
          )).timeout(const Duration(seconds: 20));
          if (response.statusCode != 200) throw StateError('feed_http_${response.statusCode}');
          final feed = XmlDocument.parse(response.body);
          if (feed.rootElement.name.local != 'feed') throw const FormatException('not_a_feed');
          for (final entry in feed.findAllElements('entry')) {
            String text(String name) => entry.descendants.whereType<XmlElement>()
                .where((node) => node.name.local == name).map((node) => node.innerText).firstOrNull ?? '';
            final videoId = text('videoId');
            final published = DateTime.tryParse(text('published'));
            if (videoId.isEmpty || published == null) continue;
            videos[videoId] = SonarTubeItem(
              kind: SonarTubeItemKind.video, id: videoId, title: text('title'),
              url: 'https://www.youtube.com/watch?v=$videoId',
              channelId: id, channel: text('name').isEmpty ? channel.title : text('name'),
              published: published.toUtc().toIso8601String(),
            );
          }
        } catch (_) {
          failed++;
        }
      }
    }
    try {
      await Future.wait(List.generate(channels.length.clamp(0, 4), (_) => worker()));
      if (channels.isNotEmpty && failed == channels.length) {
        throw StateError('all_channel_feeds_failed');
      }
      final items = videos.values.toList()..sort((a, b) {
        final order = DateTime.parse(b.published!).compareTo(DateTime.parse(a.published!));
        return order != 0 ? order : a.id.compareTo(b.id);
      });
      return FavoriteChannelVideosResult(items, failed);
    } finally {
      if (_client == null) client.close();
    }
  }
}
