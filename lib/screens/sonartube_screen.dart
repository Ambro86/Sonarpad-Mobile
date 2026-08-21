import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../models/podcast.dart';
import '../services/sonartube_favorites_service.dart';
import '../services/sonartube_service.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';

class SonarTubeScreen extends StatefulWidget {
  const SonarTubeScreen({
    super.key,
    this.collection,
    this.service,
    this.favoritesService,
  });

  final SonarTubeItem? collection;
  final SonarTubeService? service;
  final SonarTubeFavoritesService? favoritesService;

  @override
  State<SonarTubeScreen> createState() => _SonarTubeScreenState();
}

class _SonarTubeScreenState extends State<SonarTubeScreen> {
  late final SonarTubeService _service = widget.service ?? SonarTubeService();
  late final SonarTubeFavoritesService _favoritesService =
      widget.favoritesService ?? SonarTubeFavoritesService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final AccessibleListController _accessibleListController =
      AccessibleListController(debugName: 'sonartube');
  List<SonarTubeItem> _items = const [];
  Set<String> _favoriteKeys = const {};
  String? _query;
  String? _nextToken;
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _resolvingId;
  Object? _error;

  bool get _isCollection => widget.collection != null;

  @override
  void initState() {
    super.initState();
    _loadFavoriteKeys();
    if (_isCollection) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCollection());
    }
  }

  Future<void> _loadFavoriteKeys() async {
    final favorites = await _favoritesService.loadFavorites();
    if (!mounted) return;
    setState(() {
      _favoriteKeys = favorites.map(_favoritesService.itemKey).toSet();
    });
  }

  Future<void> _toggleFavorite(
    SonarTubeItem item, {
    String? accessibleRowId,
  }) async {
    final key = _favoritesService.itemKey(item);
    final added = await _favoritesService.toggleFavorite(item);
    if (!mounted) return;
    setState(() {
      final next = Set<String>.from(_favoriteKeys);
      if (added) {
        next.add(key);
      } else {
        next.remove(key);
      }
      _favoriteKeys = next;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (accessibleRowId != null) {
      await _accessibleListController.refreshAccessibilityRow(accessibleRowId);
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showStatusMessage(
      context,
      added
          ? l10n.sonarTubeFavoriteAdded(item.title)
          : l10n.sonarTubeFavoriteRemoved(item.title),
    );
  }

  Future<void> _openFavorites() async {
    final item = await Navigator.push<SonarTubeItem>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/sonartube/favorites'),
        builder: (_) =>
            _SonarTubeFavoritesScreen(favoritesService: _favoritesService),
      ),
    );
    await _loadFavoriteKeys();
    if (item != null && mounted) await _openItem(item);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _loading) {
      _searchFocusNode.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _query = query;
      _items = const [];
      _nextToken = null;
      _page = 1;
    });
    try {
      final result = await _service.search(query);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _nextToken = result.nextToken;
        _page = result.page;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCollection() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.browse(widget.collection!);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _nextToken = result.nextToken;
        _page = result.page;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    var token = _nextToken;
    if (token == null || token.isEmpty || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final known = _items.map(_sonarTubeItemKey).toSet();
      final appended = <SonarTubeItem>[];
      var currentPage = _page;
      final visitedTokens = <String>{};

      // YouTube continuation pages can occasionally contain only items that
      // were already present. Follow a few consecutive continuation tokens
      // in the same user action, but never loop forever on a stale token.
      for (var attempt = 0; attempt < 3 && token != null; attempt++) {
        if (!visitedTokens.add(token)) {
          token = null;
          break;
        }
        final nextPage = currentPage + 1;
        final result = _isCollection
            ? await _service.browse(
                widget.collection!,
                token: token,
                page: nextPage,
              )
            : await _service.search(_query!, token: token, page: nextPage);
        currentPage = result.page;
        for (final item in result.items) {
          if (known.add(_sonarTubeItemKey(item))) {
            appended.add(item);
          }
        }
        final nextToken = result.nextToken;
        token = nextToken == null ||
                nextToken.isEmpty ||
                visitedTokens.contains(nextToken)
            ? null
            : nextToken;
        if (appended.isNotEmpty) break;
      }

      if (!mounted) return;
      setState(() {
        if (appended.isNotEmpty) {
          _items = [..._items, ...appended];
        }
        _nextToken = appended.isEmpty ? null : token;
        _page = currentPage;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _sonarTubeItemKey(SonarTubeItem item) =>
      '${item.kind.name}:${item.id}';

  Future<void> _openItem(SonarTubeItem item) async {
    if (item.kind != SonarTubeItemKind.video) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/sonartube/collection'),
          builder: (_) => SonarTubeScreen(
            collection: item,
            service: _service,
            favoritesService: _favoritesService,
          ),
        ),
      );
      return;
    }

    setState(() {
      _resolvingId = item.id;
      _error = null;
    });
    try {
      final episode = await _resolveEpisode(item);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/sonartube/player'),
          builder: (_) => PodcastEpisodePlayerScreen(
            episode: episode,
            isVideoSupported: true,
            startWithVideoThenRestorePreference: true,
            refreshEpisode: () => _resolveEpisode(item),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _resolvingId = null);
    }
  }

  Future<PodcastEpisode> _resolveEpisode(SonarTubeItem item) async {
    final media = await _service.resolve(item);
    return PodcastEpisode(
      id: 'sonartube:${item.id}',
      title: media.title,
      description: media.channel ?? '',
      audioUrl: media.audioUrl,
      videoUrl: media.videoUrl,
    );
  }

  String _itemType(AppLocalizations l10n, SonarTubeItem item) {
    return switch (item.kind) {
      SonarTubeItemKind.video => item.isLive ? l10n.sonarTubeLive : '',
      SonarTubeItemKind.channel => l10n.sonarTubeChannel,
      SonarTubeItemKind.playlist => l10n.sonarTubePlaylist,
    };
  }

  String? _subtitle(AppLocalizations l10n, SonarTubeItem item) {
    final values = <String>[
      _itemType(l10n, item),
      if (item.channel?.isNotEmpty ?? false) item.channel!,
      if (item.duration?.isNotEmpty ?? false) item.duration!,
      if (item.published?.isNotEmpty ?? false) item.published!,
      if (item.views?.isNotEmpty ?? false) item.views!,
    ].where((value) => value.isNotEmpty).toList();
    return values.isEmpty ? null : values.join(' · ');
  }

  Widget _buildFlutterSonarTubeItem(
    AppLocalizations l10n,
    SonarTubeItem item, {
    required bool resolving,
    required bool canFavorite,
    required bool isFavorite,
    required String favoriteLabel,
    required String? subtitle,
  }) {
    final card = Card(
      child: ListTile(
        leading: item.thumbnailUrl == null
            ? ExcludeSemantics(
                child: Icon(
                  item.kind == SonarTubeItemKind.video
                      ? Icons.play_circle_outline
                      : item.kind == SonarTubeItemKind.channel
                          ? Icons.account_circle
                          : Icons.playlist_play,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.thumbnailUrl!,
                  width: 88,
                  height: 56,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const ExcludeSemantics(
                    child: SizedBox(
                      width: 88,
                      child: Icon(Icons.video_library),
                    ),
                  ),
                ),
              ),
        title: Text(item.title),
        subtitle: Text(
          resolving ? l10n.sonarTubeResolving : (subtitle ?? ''),
        ),
        trailing: resolving
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : canFavorite
                ? ExcludeSemantics(
                    child: IconButton(
                      key: ValueKey(
                        'sonartube_favorite_${item.kind.name}_${item.id}',
                      ),
                      tooltip: favoriteLabel,
                      onPressed: () => _toggleFavorite(item),
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
                    ),
                  )
                : const ExcludeSemantics(child: Icon(Icons.play_arrow)),
        enabled: _resolvingId == null,
        onTap: _resolvingId == null ? () => _openItem(item) : null,
      ),
    );
    return Semantics(
      key: ValueKey('sonartube_${item.kind.name}_${item.id}'),
      container: true,
      button: true,
      label: [
        item.title,
        if (subtitle?.isNotEmpty ?? false) subtitle!,
      ].join(', '),
      onTap: _resolvingId == null ? () => _openItem(item) : null,
      child: ExcludeSemantics(child: card),
    );
  }

  Widget _buildSharedAccessibleSonarTube(AppLocalizations l10n) {
    final rows = <AccessibleListRow>[];
    if (!_isCollection) {
      rows.add(AccessibleListRow(
        id: 'favorites',
        title: l10n.sonarTubeFavorites,
        flutterChild: OutlinedButton.icon(
          key: const ValueKey('sonartube_favorites_button'),
          onPressed: _openFavorites,
          icon: const Icon(Icons.favorite),
          label: Text(l10n.sonarTubeFavorites),
        ),
      ));
      rows.add(AccessibleListRow(
        id: 'query',
        title: l10n.sonarTubeSearchLabel,
        kind: 'textField',
        value: _searchController.text,
        placeholder: l10n.sonarTubeSearchPrompt,
        textInputAction: 'search',
        onSubmitted: (_) => _search(),
        flutterChild: TextField(
          key: const ValueKey('sonartube_search_field'),
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            labelText: l10n.sonarTubeSearchLabel,
            hintText: l10n.sonarTubeSearchPrompt,
            prefixIcon: const Icon(Icons.search),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
      ));
      rows.add(AccessibleListRow(
        id: 'search',
        title: l10n.search,
        kind: 'button',
        enabled: !_loading,
        flutterChild: FilledButton(
          key: const ValueKey('sonartube_search_button'),
          onPressed: _loading ? null : _search,
          child: Text(l10n.search),
        ),
      ));
    }
    if (_loading) {
      rows.add(AccessibleListRow(
        id: 'loading',
        title: l10n.loading,
        kind: 'text',
      ));
    }
    if (_error != null) {
      rows.add(AccessibleListRow(
        id: 'error',
        title: l10n.error(l10n.localizeTechnicalError(_error!)),
        kind: 'text',
      ));
    }
    if (!_loading && _items.isEmpty) {
      rows.add(AccessibleListRow(
        id: 'empty',
        title: _query == null && !_isCollection
            ? l10n.sonarTubeSearchPrompt
            : l10n.sonarTubeNoResults,
        kind: 'text',
      ));
    }
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final resolving = _resolvingId == item.id;
      final canFavorite = item.kind != SonarTubeItemKind.video;
      final isFavorite = _favoriteKeys.contains(_favoritesService.itemKey(item));
      final favoriteLabel = isFavorite
          ? l10n.sonarTubeRemoveFavorite
          : l10n.sonarTubeAddFavorite;
      final subtitle = resolving ? l10n.sonarTubeResolving : _subtitle(l10n, item);
      rows.add(AccessibleListRow(
        id: 'item_$i',
        title: item.title,
        subtitle: subtitle,
        accessibilityLabel: [
          item.title,
          if (subtitle?.isNotEmpty ?? false) subtitle!,
        ].join(', '),
        enabled: _resolvingId == null,
        actions: canFavorite
            ? [AccessibleCustomAction(id: 'favorite', label: favoriteLabel)]
            : const [],
        flutterChild: _buildFlutterSonarTubeItem(
          l10n,
          item,
          resolving: resolving,
          canFavorite: canFavorite,
          isFavorite: isFavorite,
          favoriteLabel: favoriteLabel,
          subtitle: subtitle,
        ),
      ));
    }
    if (_nextToken != null) {
      rows.add(AccessibleListRow(
        id: 'load_more',
        title: _loadingMore ? l10n.loading : l10n.sonarTubeLoadMore,
        kind: 'button',
        enabled: !_loadingMore,
        flutterChild: FilledButton.tonal(
          key: const ValueKey('sonartube_load_more'),
          onPressed: _loadingMore ? null : _loadMore,
          child: _loadingMore
              ? SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: l10n.loading,
                  ),
                )
              : Text(l10n.sonarTubeLoadMore),
        ),
      ));
    }

    return UniversalAccessibleList(
      controller: _accessibleListController,
      sections: [AccessibleListSection(rows: rows)],
      onEvent: (event) async {
        if (event.id == 'query' && event.type == 'textChanged') {
          _searchController.text = event.value?.toString() ?? '';
          return;
        }
        if (event.type == 'customAction' &&
            event.action == 'favorite' &&
            event.id?.startsWith('item_') == true) {
          final index = int.tryParse(event.id!.substring(5));
          if (index != null && index >= 0 && index < _items.length) {
            await _toggleFavorite(
              _items[index],
              accessibleRowId: event.id,
            );
          }
          return;
        }
        if (event.type != 'activate' || event.id == null) return;
        if (event.id == 'favorites') {
          await _openFavorites();
        } else if (event.id == 'search') {
          await _search();
        } else if (event.id == 'load_more') {
          await _loadMore();
        } else if (event.id!.startsWith('item_')) {
          final index = int.tryParse(event.id!.substring(5));
          if (index != null && index >= 0 && index < _items.length) {
            await _openItem(_items[index]);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection?.title ?? l10n.sonarTubeTitle),
      ),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? _buildSharedAccessibleSonarTube(l10n)
            : Column(
          children: [
            if (!_isCollection)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('sonartube_favorites_button'),
                      onPressed: _openFavorites,
                      icon: const Icon(Icons.favorite),
                      label: Text(l10n.sonarTubeFavorites),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('sonartube_search_field'),
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              labelText: l10n.sonarTubeSearchLabel,
                              hintText: l10n.sonarTubeSearchPrompt,
                              prefixIcon: const Icon(Icons.search),
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _search(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          key: const ValueKey('sonartube_search_button'),
                          onPressed: _loading ? null : _search,
                          child: Text(l10n.search),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_loading) LinearProgressIndicator(semanticsLabel: l10n.loading),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.error(l10n.localizeTechnicalError(_error!)),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: !_loading && _items.isEmpty
                  ? Center(
                      child: ExcludeSemantics(
                        excluding: _query == null && !_isCollection,
                        child: Text(
                          _query == null && !_isCollection
                              ? l10n.sonarTubeSearchPrompt
                              : l10n.sonarTubeNoResults,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: _items.length + (_nextToken == null ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: FilledButton.tonal(
                                key: const ValueKey('sonartube_load_more'),
                                onPressed: _loadingMore ? null : _loadMore,
                                child: _loadingMore
                                    ? SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          semanticsLabel: l10n.loading,
                                        ),
                                      )
                                    : Text(l10n.sonarTubeLoadMore),
                              ),
                            ),
                          );
                        }
                        final item = _items[index];
                        final resolving = _resolvingId == item.id;
                        final canFavorite =
                            item.kind != SonarTubeItemKind.video;
                        final isFavorite = _favoriteKeys.contains(
                          _favoritesService.itemKey(item),
                        );
                        final favoriteLabel = isFavorite
                            ? l10n.sonarTubeRemoveFavorite
                            : l10n.sonarTubeAddFavorite;
                        final card = Card(
                          child: ListTile(
                            leading: item.thumbnailUrl == null
                                ? ExcludeSemantics(
                                    child: Icon(
                                      item.kind == SonarTubeItemKind.video
                                          ? Icons.play_circle_outline
                                          : item.kind ==
                                                SonarTubeItemKind.channel
                                          ? Icons.account_circle
                                          : Icons.playlist_play,
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      item.thumbnailUrl!,
                                      width: 88,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      excludeFromSemantics: true,
                                      errorBuilder: (_, _, _) =>
                                          const ExcludeSemantics(
                                            child: SizedBox(
                                              width: 88,
                                              child: Icon(Icons.video_library),
                                            ),
                                          ),
                                    ),
                                  ),
                            title: Text(item.title),
                            subtitle: Text(
                              resolving
                                  ? l10n.sonarTubeResolving
                                  : (_subtitle(l10n, item) ?? ''),
                            ),
                            trailing: resolving
                                ? const SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : canFavorite
                                ? ExcludeSemantics(
                                    child: IconButton(
                                      key: ValueKey(
                                        'sonartube_favorite_${item.kind.name}_${item.id}',
                                      ),
                                      tooltip: favoriteLabel,
                                      onPressed: () => _toggleFavorite(item),
                                      icon: Icon(
                                        isFavorite
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                      ),
                                    ),
                                  )
                                : const ExcludeSemantics(
                                    child: Icon(Icons.play_arrow),
                                  ),
                            enabled: _resolvingId == null,
                            onTap: () => _openItem(item),
                          ),
                        );
                        final subtitle = resolving
                            ? l10n.sonarTubeResolving
                            : _subtitle(l10n, item);
                        return Semantics(
                          key: ValueKey(
                            'sonartube_${item.kind.name}_${item.id}',
                          ),
                          container: true,
                          button: true,
                          label: [
                            item.title,
                            if (subtitle?.isNotEmpty ?? false) subtitle!,
                          ].join(', '),
                          onTap: _resolvingId == null
                              ? () => _openItem(item)
                              : null,
                          customSemanticsActions: canFavorite
                              ? {
                                  CustomSemanticsAction(
                                    label: favoriteLabel,
                                  ): () =>
                                      _toggleFavorite(item),
                                }
                              : null,
                          child: ExcludeSemantics(child: card),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SonarTubeFavoritesScreen extends StatefulWidget {
  const _SonarTubeFavoritesScreen({required this.favoritesService});

  final SonarTubeFavoritesService favoritesService;

  @override
  State<_SonarTubeFavoritesScreen> createState() =>
      _SonarTubeFavoritesScreenState();
}

class _SonarTubeFavoritesScreenState extends State<_SonarTubeFavoritesScreen> {
  List<SonarTubeItem> _favorites = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favorites = await widget.favoritesService.loadFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _loading = false;
    });
  }

  Future<void> _remove(SonarTubeItem item) async {
    await widget.favoritesService.toggleFavorite(item);
    if (!mounted) return;
    showStatusMessage(
      context,
      AppLocalizations.of(context).sonarTubeFavoriteRemoved(item.title),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sonarTubeFavorites)),
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(semanticsLabel: l10n.loading),
              )
            : _favorites.isEmpty
            ? Center(
                child: Text(
                  l10n.sonarTubeNoFavorites,
                  textAlign: TextAlign.center,
                ),
              )
            : useSharedAccessibleViewModel
                ? UniversalAccessibleList(
                    sections: [
                      AccessibleListSection(
                        rows: _favorites
                            .asMap()
                            .entries
                            .map((entry) {
                              final item = entry.value;
                              final type = item.kind == SonarTubeItemKind.channel
                                  ? l10n.sonarTubeChannel
                                  : l10n.sonarTubePlaylist;
                              return AccessibleListRow(
                                id: 'favorite_${entry.key}',
                                title: item.title,
                                subtitle: type,
                                actions: [
                                  AccessibleCustomAction(
                                    id: 'remove',
                                    label: l10n.sonarTubeRemoveFavorite,
                                  ),
                                ],
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                    onEvent: (event) async {
                      if (event.id?.startsWith('favorite_') != true) return;
                      final index = int.tryParse(event.id!.substring(9));
                      if (index == null || index < 0 || index >= _favorites.length) return;
                      final item = _favorites[index];
                      if (event.type == 'customAction' && event.action == 'remove') {
                        await _remove(item);
                      } else if (event.type == 'activate') {
                        if (mounted) Navigator.pop(context, item);
                      }
                    },
                  )
                : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final item = _favorites[index];
                  final type = item.kind == SonarTubeItemKind.channel
                      ? l10n.sonarTubeChannel
                      : l10n.sonarTubePlaylist;
                  return Semantics(
                    customSemanticsActions: {
                      CustomSemanticsAction(
                        label: l10n.sonarTubeRemoveFavorite,
                      ): () =>
                          _remove(item),
                    },
                    child: Card(
                      child: ListTile(
                        key: ValueKey(
                          'sonartube_favorite_item_${item.kind.name}_${item.id}',
                        ),
                        leading: item.thumbnailUrl == null
                            ? Icon(
                                item.kind == SonarTubeItemKind.channel
                                    ? Icons.account_circle
                                    : Icons.playlist_play,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  item.thumbnailUrl!,
                                  width: 88,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  excludeFromSemantics: true,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 88,
                                    child: Icon(Icons.video_library),
                                  ),
                                ),
                              ),
                        title: Text(item.title),
                        subtitle: Text(type),
                        trailing: ExcludeSemantics(
                          child: IconButton(
                            key: ValueKey(
                              'sonartube_remove_favorite_${item.kind.name}_${item.id}',
                            ),
                            tooltip: l10n.sonarTubeRemoveFavorite,
                            onPressed: () => _remove(item),
                            icon: const Icon(Icons.favorite),
                          ),
                        ),
                        onTap: () => Navigator.pop(context, item),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
