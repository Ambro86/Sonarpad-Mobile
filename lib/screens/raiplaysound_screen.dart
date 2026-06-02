import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/podcast_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/recent_searches_service.dart';
import 'podcast_episode_player_screen.dart';
import 'recent_searches_screen.dart';

class RaiPlaySoundScreen extends StatefulWidget {
  final String? url;
  final String? searchQuery;

  const RaiPlaySoundScreen({super.key, this.url, this.searchQuery});

  @override
  State<RaiPlaySoundScreen> createState() => _RaiPlaySoundScreenState();
}

class _RaiPlaySoundScreenState extends State<RaiPlaySoundScreen> {
  final _settings = AppSettingsService();
  final _service = RaiPlaySoundService();
  final _podcastService = PodcastService();
  final _searchController = TextEditingController();

  RaiPlaySoundPage? _page;
  bool _loading = true;
  String? _error;
  bool _autoOpenedSingleItem = false;

  /// true solo se siamo nella root e non stiamo visualizzando i risultati di una ricerca
  bool get _isRoot => widget.url == null && widget.searchQuery == null;

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
      final url = widget.url ?? _service.getGenresUrl(code);
      if (url == null && widget.searchQuery == null) {
        throw Exception('Codice non valido o mancante.');
      }

      RaiPlaySoundPage page;
      if (widget.searchQuery != null) {
        page = await _service.searchContent(widget.searchQuery!, code);
      } else {
        page = await _service.loadPage(url!, isRootPage: _isRoot);
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

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    await RecentSearchesService().addSearch('raiplaysound', query);

    if (!mounted) return;
    _searchController.clear();
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/raiplaysound/search'),
        builder: (_) => RaiPlaySoundScreen(
          searchQuery: query,
        ),
      ),
    );
  }

  Future<void> _openRecentSearches() async {
    final query = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => const RecentSearchesScreen(
          title: 'Ricerche recenti',
          domain: 'raiplaysound',
        ),
      ),
    );
    if (query == null || !mounted) return;
    _searchController.text = query;
    await _search();
  }

  void _openSingleNestedItemIfNeeded(RaiPlaySoundPage page) {
    if (_isRoot || _autoOpenedSingleItem || page.items.length != 1) return;
    _autoOpenedSingleItem = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openItem(page.items.single, replaceCurrentRoute: true);
    });
  }

  void _openItem(
    RaiPlaySoundItem item, {
    bool replaceCurrentRoute = false,
  }) async {
    final code = await _settings.getTvSecretCode();

    if (item.kind == RaiPlaySoundItemKind.page) {
      final baseUrl = _service.getBaseUrl(code);
      if (baseUrl == null) return;

      var path = item.pathId;
      if (!path.startsWith('/')) path = '/$path';
      if (!path.endsWith('.json')) path = '$path.json';

      final url = '$baseUrl$path';
      if (!mounted) return;
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/raiplaysound/page'),
        builder: (_) => RaiPlaySoundScreen(url: url),
      );
      if (replaceCurrentRoute) {
        Navigator.pushReplacement(context, route);
      } else {
        Navigator.push(context, route);
      }
    } else {
      final baseUrl = _service.getBaseUrl(code);
      if (baseUrl == null) return;

      var audioPath = item.audioUrl;
      if (!audioPath.startsWith('http')) {
        if (!audioPath.startsWith('/')) audioPath = '/$audioPath';
        audioPath = '$baseUrl$audioPath';
      }

      final episode = PodcastEpisode(
        title: item.title,
        description: item.description,
        audioUrl: audioPath,
        id: 'raiplaysound:${item.id}',
        publishedAt: DateTime.now(),
      );

      if (!mounted) return;
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/raiplaysound/player'),
        builder: (_) => PodcastEpisodePlayerScreen(
          episode: episode,
        ),
      );
      if (replaceCurrentRoute) {
        Navigator.pushReplacement(context, route);
      } else {
        Navigator.push(context, route);
      }
    }
  }

  Future<void> _subscribeCurrentPageToPodcasts() async {
    final page = _page;
    if (page == null || !_canSubscribeCurrentPage) return;

    try {
      final subscriptions = await _podcastService.loadSubscriptions();
      if (subscriptions.any((subscription) =>
          subscription.feedUrl.trim().toLowerCase() ==
          page.source.trim().toLowerCase())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Podcast già presente')),
        );
        return;
      }
      await _podcastService.addSubscription(page.source);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Podcast aggiunto: ${page.title}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore iscrizione podcast: $e')),
      );
    }
  }

  bool get _canSubscribeCurrentPage {
    final page = _page;
    if (page == null) return false;
    if (!page.source.trim().toLowerCase().contains('raiplaysound.it')) {
      return false;
    }
    return page.items.any((item) =>
        item.kind == RaiPlaySoundItemKind.audio &&
        item.audioUrl.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_page?.title ?? 'RaiPlay Sound')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _page == null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    if (_isRoot)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  labelText: 'Cerca su RaiPlay Sound',
                                  hintText: 'Es. GR, teatro, podcast...',
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
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _page!.items.length,
                        itemBuilder: (context, index) {
                          final item = _page!.items[index];
                          final isAudio =
                              item.kind == RaiPlaySoundItemKind.audio;

                          return Card(
                            child: Semantics(
                              customSemanticsActions: {
                                if (isAudio && _canSubscribeCurrentPage)
                                  const CustomSemanticsAction(
                                    label: 'Aggiungi ai podcast',
                                  ): () => unawaited(
                                        _subscribeCurrentPageToPodcasts(),
                                      ),
                              },
                              child: ListTile(
                                leading: Icon(
                                  isAudio ? Icons.audiotrack : Icons.folder,
                                ),
                                title: Text(item.title),
                                subtitle: item.description.isNotEmpty
                                    ? Text(
                                        item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                onTap: () => _openItem(item),
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
