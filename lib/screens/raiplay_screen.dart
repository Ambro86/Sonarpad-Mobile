import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/raiplay_service.dart';
import '../services/recording_feature_access.dart';
import '../services/recent_searches_service.dart';
import '../utils/app_logger.dart';
import '../utils/media_open_guard.dart';
import 'podcast_episode_player_screen.dart';
import 'recent_searches_screen.dart';
import '../widgets/online_ai_audiodescription_action.dart';
import '../widgets/universal_accessible_view.dart';

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
  final MediaOpenGuard _mediaOpenGuard = MediaOpenGuard();

  RaiPlayPage? _page;
  bool _loading = true;
  String? _error;
  bool _autoOpenedSingleItem = false;
  bool _aiAudiodescriptionUnlocked = false;

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
      final language = await _settings.loadAppLanguage();
      final aiAudiodescriptionUnlocked =
          language == 'it' && RecordingFeatureAccess.isCodeValid(code);

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
        _aiAudiodescriptionUnlocked = aiAudiodescriptionUnlocked;
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

  bool _canCreateAiAudiodescription(RaiPlayItem item) =>
      _aiAudiodescriptionUnlocked && item.kind == RaiPlayItemKind.media;

  Future<void> _createAiAudiodescription(RaiPlayItem item) async {
    if (!mounted || !_canCreateAiAudiodescription(item)) return;
    try {
      final resolved = await _service.resolvePlaybackUrls(item.mediaUrl);
      if (!mounted) return;
      await createAiAudiodescriptionFromRemoteVideo(
        context,
        url: resolved.videoUrl,
        title: item.title,
        headers: const <String, String>{
          'Origin': 'https://www.raiplay.it',
          'Referer': 'https://www.raiplay.it/',
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Sonarpad',
        },
      );
    } catch (error, stack) {
      await AppLogger.log(
        'RaiPlay AI audio description: preparation failed error=$error\n$stack',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile preparare il video.')),
        );
      }
    }
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
      final itemKey = 'raiplay:${item.id}';
      if (!_mediaOpenGuard.tryAcquire(itemKey)) {
        await AppLogger.log(
          'MEDIA_OPEN_GUARD duplicate ignored source=raiplay '
          'active=${_mediaOpenGuard.activeKey} requested=$itemKey',
        );
        return;
      }

      try {
        if (!mounted) return;
        setState(() => _loading = true);

        final mediaUrl = item.mediaUrl;
        final resolvedMedia = await _service.resolvePlaybackUrls(mediaUrl);

        final episode = PodcastEpisode(
          title: item.title,
          description: item.description,
          audioUrl: resolvedMedia.audioUrl,
          videoUrl: resolvedMedia.videoUrl,
          id: itemKey,
          publishedAt: DateTime.now(),
        );

        if (!mounted) return;
        setState(() => _loading = false);

        final route = MaterialPageRoute(
          settings: const RouteSettings(name: '/raiplay/player'),
          builder: (playerContext) => PodcastEpisodePlayerScreen(
            episode: episode,
            isVideoSupported: true,
            extraActions: _canCreateAiAudiodescription(item)
                ? <PodcastPlayerExtraAction>[
                    PodcastPlayerExtraAction(
                      id: 'create_ai_audiodescription',
                      label: () => onlineCreateAiAudiodescriptionLabel,
                      icon: Icons.auto_awesome,
                      pauseBeforeOpen: true,
                      onPressed: () => createAiAudiodescriptionFromRemoteVideo(
                        playerContext,
                        url: resolvedMedia.videoUrl,
                        title: item.title,
                        headers: const <String, String>{
                          'Origin': 'https://www.raiplay.it',
                          'Referer': 'https://www.raiplay.it/',
                          'User-Agent':
                              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Sonarpad',
                        },
                      ),
                    ),
                  ]
                : const <PodcastPlayerExtraAction>[],
          ),
        );
        if (replaceCurrentRoute) {
          await Navigator.pushReplacement(context, route);
        } else {
          await Navigator.push(context, route);
        }
      } finally {
        _mediaOpenGuard.release(itemKey);
      }
    }
  }

  Widget _buildSharedAccessibleBody() {
    final items = _page?.items ?? const <RaiPlayItem>[];
    final rows = <AccessibleListRow>[
      if (_isRoot)
        AccessibleListRow(id: 'search_query', title: 'Cerca su RaiPlay', kind: 'textField', value: _searchController.text, textInputAction: 'search', onSubmitted: (_) => _search()),
      if (_isRoot) const AccessibleListRow(id: 'search', title: 'Cerca', kind: 'button'),
      if (_isRoot) const AccessibleListRow(id: 'recent', title: 'Ricerche recenti'),
      if (_error != null) AccessibleListRow(id: 'error', kind: 'text', title: _error!),
      for (var i = 0; i < items.length; i++)
        AccessibleListRow(
          id: 'item_$i',
          title: items[i].title,
          subtitle: items[i].description.isNotEmpty ? items[i].description : null,
          actions: _canCreateAiAudiodescription(items[i])
              ? const <AccessibleCustomAction>[
                  AccessibleCustomAction(
                    id: 'create_ai_audiodescription',
                    label: onlineCreateAiAudiodescriptionLabel,
                  ),
                ]
              : const <AccessibleCustomAction>[],
          visualActions: _canCreateAiAudiodescription(items[i])
              ? const <AccessibleVisualAction>[
                  AccessibleVisualAction(
                    id: 'create_ai_audiodescription',
                    label: onlineCreateAiAudiodescriptionLabel,
                    icon: 'ai',
                  ),
                ]
              : const <AccessibleVisualAction>[],
        ),
    ];
    return UniversalAccessibleList(
      sections: [AccessibleListSection(rows: rows)],
      onEvent: (event) async {
        if (event.id == 'search_query' && event.type == 'textChanged') {
          _searchController.text = event.value?.toString() ?? '';
        } else if (event.id == 'search' && event.type == 'activate') {
          await _search();
        } else if (event.id == 'recent' && event.type == 'activate') {
          await _openRecentSearches();
        } else if (event.type == 'customAction' &&
            event.action == 'create_ai_audiodescription' &&
            event.id?.startsWith('item_') == true) {
          final i = int.tryParse(event.id!.substring(5));
          if (i != null && i >= 0 && i < items.length) {
            await _createAiAudiodescription(items[i]);
          }
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
              : useSharedAccessibleViewModel
                  ? _buildSharedAccessibleBody()
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

                          return Semantics(
                            customSemanticsActions:
                                _canCreateAiAudiodescription(item)
                                    ? <CustomSemanticsAction, VoidCallback>{
                                        const CustomSemanticsAction(
                                          label: onlineCreateAiAudiodescriptionLabel,
                                        ): () => _createAiAudiodescription(item),
                                      }
                                    : null,
                            child: Card(
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
                              trailing: _canCreateAiAudiodescription(item)
                                  ? ExcludeSemantics(
                                      child: IconButton(
                                        tooltip: onlineCreateAiAudiodescriptionLabel,
                                        icon: const Icon(Icons.auto_awesome),
                                        onPressed: () =>
                                            _createAiAudiodescription(item),
                                      ),
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
