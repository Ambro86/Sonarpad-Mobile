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
  final _searchController = TextEditingController();

  RaiPlayPage? _page;
  bool _loading = true;
  String? _error;
  bool _searching = false;
  String _secretCode = '';

  /// true solo se siamo nella root (nessun pathId fornito)
  bool get _isRoot => widget.pathId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final code = await _settings.getTvSecretCode();
      if (!_service.isSecretCodeValid(code)) {
        throw Exception('Codice non valido o mancante.');
      }
      _secretCode = code;

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

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _service.searchContent(query, _secretCode);
      if (!mounted) return;
      setState(() {
        _page = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore nella ricerca: $e';
        _searching = false;
      });
    }
  }

  Future<void> _resetToRoot() async {
    _searchController.clear();
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
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
      setState(() => _loading = true);

      final mediaUrl = item.mediaUrl;
      final resolvedUrl = await _service.resolveMediaUrl(mediaUrl);

      final episode = PodcastEpisode(
        title: item.title,
        description: item.description,
        audioUrl: resolvedUrl,
        publishedAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() => _loading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/raiplay/player'),
          builder: (_) => PodcastEpisodePlayerScreen(episode: episode),
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
          : _error != null && _page == null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    // Casella di ricerca: visibile solo nella root
                    if (_isRoot)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  labelText: 'Cerca su RaiPlay',
                                  hintText: 'Es. TG1, Blob, Un posto al sole...',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _search(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_searching)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                ),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: 'Cerca',
                                onPressed: _search,
                              ),
                              if (_page?.title.startsWith('Risultati:') == true)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Torna alla home',
                                  onPressed: _resetToRoot,
                                ),
                            ],
                          ],
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _page!.items.length,
                        itemBuilder: (context, index) {
                          final item = _page!.items[index];
                          final isMedia =
                              item.kind == RaiPlayItemKind.media;

                          return Card(
                            child: ListTile(
                              leading: Icon(isMedia
                                  ? Icons.play_circle_filled
                                  : Icons.folder),
                              title: Text(item.title),
                              subtitle: item.description.isNotEmpty
                                  ? Text(item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis)
                                  : null,
                              onTap: () => _openItem(item),
                              trailing: IconButton(
                                tooltip: isMedia
                                    ? 'Riproduci'
                                    : 'Apri cartella',
                                onPressed: () => _openItem(item),
                                icon: Icon(isMedia
                                    ? Icons.play_arrow
                                    : Icons.chevron_right),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
