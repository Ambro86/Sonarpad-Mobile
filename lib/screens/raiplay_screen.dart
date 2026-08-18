import 'package:flutter/material.dart';

import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/raiplay_service.dart';
import '../services/recent_searches_service.dart';
import 'podcast_episode_player_screen.dart';
import 'recent_searches_screen.dart';
import '../widgets/native_ios_accessible_view.dart';

class RaiPlayScreen extends StatefulWidget {
  final String? pathId;
  final String? pageTitle;
  final String? searchQuery;

  const RaiPlayScreen(
      {super.key, this.pathId, this.pageTitle, this.searchQuery});

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
  bool _autoOpenedSingleItem = false;

  /// true solo se siamo nella root (nessun pathId e nessuna ricerca attiva)
  bool get _isRoot => widget.pathId == null && widget.searchQuery == null;

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

      RaiPlayPage page;
      if (widget.searchQuery != null) {
        page = await _service.searchContent(widget.searchQuery!, code);
      } else if (widget.pathId == null) {
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
      _openSingleNestedItemIfNeeded(page);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile caricare i contenuti: $e';
        _loading = false;
      });
    }
  }

  void _openSingleNestedItemIfNeeded(RaiPlayPage page) {
    if (_isRoot || _autoOpenedSingleItem || page.items.length != 1) return;
    _autoOpenedSingleItem = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openItem(page.items.single, replaceCurrentRoute: true);
    });
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    await RecentSearchesService().addSearch('raiplay', query);

    if (!mounted) return;
    _searchController
        .clear(); // Pulisci prima di spostarsi, così tornando indietro è pulito
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/raiplay/search'),
        builder: (_) => RaiPlayScreen(
          searchQuery: query,
          pageTitle: 'Risultati: $query',
        ),
      ),
    );
  }

  Future<void> _openRecentSearches() async {
    final query = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => const RecentSearchesScreen(
          title: 'Ricerche recenti',
          domain: 'raiplay',
        ),
      ),
    );
    if (query == null || !mounted) return;
    _searchController.text = query;
    await _search();
  }

  void _openItem(
    RaiPlayItem item, {
    bool replaceCurrentRoute = false,
  }) async {
    if (item.kind == RaiPlayItemKind.page) {
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/raiplay/page'),
        builder: (_) => RaiPlayScreen(
          pathId: item.pathId,
          pageTitle: item.title,
        ),
      );
      if (replaceCurrentRoute) {
        Navigator.pushReplacement(context, route);
      } else {
        Navigator.push(context, route);
      }
    } else {
      if (!mounted) return;
      setState(() => _loading = true);

      final mediaUrl = item.mediaUrl;
      final resolvedMedia = await _service.resolvePlaybackUrls(mediaUrl);

      final episode = PodcastEpisode(
        title: item.title,
        description: item.description,
        audioUrl: resolvedMedia.audioUrl,
        videoUrl: resolvedMedia.videoUrl,
        id: 'raiplay:${item.id}',
        publishedAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() => _loading = false);

      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/raiplay/player'),
        builder: (_) => PodcastEpisodePlayerScreen(
            episode: episode, isVideoSupported: true),
      );
      if (replaceCurrentRoute) {
        Navigator.pushReplacement(context, route);
      } else {
        Navigator.push(context, route);
      }
    }
  }

  Widget _buildNativeIosBody() {
    final items = _page?.items ?? const <RaiPlayItem>[];
    final rows = <NativeIosListRow>[
      if (_isRoot)
        NativeIosListRow(id: 'search_query', title: 'Cerca su RaiPlay', kind: 'textField', value: _searchController.text),
      if (_isRoot) const NativeIosListRow(id: 'search', title: 'Cerca', kind: 'button'),
      if (_isRoot) const NativeIosListRow(id: 'recent', title: 'Ricerche recenti'),
      if (_error != null) NativeIosListRow(id: 'error', kind: 'text', title: _error!),
      for (var i = 0; i < items.length; i++)
        NativeIosListRow(
          id: 'item_$i',
          title: items[i].title,
          subtitle: items[i].description.isNotEmpty ? items[i].description : null,
        ),
    ];
    return NativeIosAccessibleList(
      sections: [NativeIosListSection(rows: rows)],
      onEvent: (event) async {
        if (event.id == 'search_query' && event.type == 'textChanged') {
          _searchController.text = event.value?.toString() ?? '';
        } else if (event.id == 'search' && event.type == 'activate') {
          await _search();
        } else if (event.id == 'recent' && event.type == 'activate') {
          await _openRecentSearches();
        } else if (event.type == 'activate' && event.id?.startsWith('item_') == true) {
          final i = int.tryParse(event.id!.substring(5));
          if (i != null && i < items.length) _openItem(items[i]);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pageTitle ?? 'RaiPlay')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _page == null
              ? Center(child: Text(_error!))
              : useNativeIosAccessibleViews
                  ? _buildNativeIosBody()
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
                                  hintText:
                                      'Es. TG1, Blob, Un posto al sole...',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _search(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.search),
                              tooltip: 'Cerca',
                              onPressed: _search,
                            ),
                            IconButton(
                              icon: const Icon(Icons.history),
                              tooltip: 'Ricerche recenti',
                              onPressed: _openRecentSearches,
                            ),
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
                          final isMedia = item.kind == RaiPlayItemKind.media;

                          return Card(
                            key: ValueKey('raiplay_item_${item.id}'),
                            child: ListTile(
                              key: ValueKey('raiplay_item_tile_${item.id}'),
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
