import 'package:flutter/material.dart';

import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/raiplay_service.dart';
import 'podcast_episode_player_screen.dart';

class RaiPlayScreen extends StatefulWidget {
  final String? pathId;
  final String? pageTitle;

  const RaiPlayScreen({super.key, this.pathId, this.pageTitle});

  @override
  State<RaiPlayScreen> createState() => _RaiPlayScreenState();
}

class _RaiPlayScreenState extends State<RaiPlayScreen> {
  final _settings = AppSettingsService();
  final _service = RaiPlayService();

  RaiPlayPage? _page;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final code = await _settings.getTvSecretCode();
      if (!_service.isSecretCodeValid(code)) {
        throw Exception('Codice non valido o mancante.');
      }

      RaiPlayPage page;
      if (widget.pathId == null) {
        page = await _service.loadRootPage(code);
      } else {
        page = await _service.loadPage(widget.pathId!, code,
            pageTitle: widget.pageTitle);
      }

      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile caricare i contenuti: $e';
        _loading = false;
      });
    }
  }

  void _openItem(RaiPlayItem item) async {
    if (item.kind == RaiPlayItemKind.page) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/raiplay/page'),
          builder: (_) => RaiPlayScreen(
            pathId: item.pathId,
            pageTitle: item.title,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      setState(() {
        _loading = true;
      });

      final mediaUrl = item.mediaUrl;
      final resolvedUrl = await _service.resolveMediaUrl(mediaUrl);

      final episode = PodcastEpisode(
        title: item.title,
        description: item.description,
        audioUrl: resolvedUrl,
        publishedAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/raiplay/player'),
          builder: (_) => PodcastEpisodePlayerScreen(
            episode: episode,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pageTitle ?? 'RaiPlay')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _page!.items.length,
                  itemBuilder: (context, index) {
                    final item = _page!.items[index];
                    final isMedia = item.kind == RaiPlayItemKind.media;

                    return Card(
                      child: ListTile(
                        leading: Icon(
                            isMedia ? Icons.play_circle_filled : Icons.folder),
                        title: Text(item.title),
                        subtitle: item.description.isNotEmpty
                            ? Text(item.description,
                                maxLines: 2, overflow: TextOverflow.ellipsis)
                            : null,
                        onTap: () => _openItem(item),
                        trailing: IconButton(
                          tooltip: isMedia ? 'Riproduci' : 'Apri cartella',
                          onPressed: () => _openItem(item),
                          icon: Icon(
                              isMedia ? Icons.play_arrow : Icons.chevron_right),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
