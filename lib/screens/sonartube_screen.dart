import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/document_library_service.dart';
import '../services/app_settings_service.dart';
import '../services/sonartube_favorites_service.dart';
import '../services/sonartube_history_service.dart';
import '../services/sonartube_service.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';
import 'document_reader_screen.dart';
import 'podcast_episode_player_screen.dart';

class SonarTubeScreen extends StatefulWidget {
  const SonarTubeScreen({
    super.key,
    this.collection,
    this.searchQuery,
    this.service,
    this.favoritesService,
    this.historyService,
  }) : assert(collection == null || searchQuery == null);

  final SonarTubeItem? collection;
  final String? searchQuery;
  final SonarTubeService? service;
  final SonarTubeFavoritesService? favoritesService;
  final SonarTubeHistoryService? historyService;

  @override
  State<SonarTubeScreen> createState() => _SonarTubeScreenState();
}

class _SonarTubeScreenState extends State<SonarTubeScreen> {
  late final SonarTubeService _service = widget.service ?? SonarTubeService();
  late final SonarTubeFavoritesService _favoritesService =
      widget.favoritesService ?? SonarTubeFavoritesService();
  late final SonarTubeHistoryService _historyService =
      widget.historyService ?? SonarTubeHistoryService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final AccessibleListController _accessibleListController =
      AccessibleListController(debugName: 'sonartube');
  final GlobalKey _searchLoadMoreFocusTargetKey = GlobalKey(
    debugLabel: 'sonartube_search_load_more_target',
  );
  int? _searchLoadMoreFocusIndex;
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
  bool get _isChannelCollection =>
      widget.collection?.kind == SonarTubeItemKind.channel;
  bool get _isSearchResults => widget.searchQuery != null;

  @override
  void initState() {
    super.initState();
    _loadFavoriteKeys();
    if (_isCollection) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCollection());
    } else if (_isSearchResults) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSearchResults());
    }
  }

  Future<void> _loadFavoriteKeys() async {
    final favorites = await _favoritesService.loadFavorites();
    if (!mounted) return;
    setState(() {
      _favoriteKeys = favorites.map(_favoritesService.itemKey).toSet();
    });
  }

  String _favoriteLabelForItem(
    AppLocalizations l10n,
    SonarTubeItem item, {
    required bool isFavorite,
  }) {
    if (item.kind == SonarTubeItemKind.channel) {
      return isFavorite
          ? l10n.sonarTubeRemoveChannelFavorite
          : l10n.sonarTubeAddChannelFavorite;
    }
    return isFavorite
        ? l10n.sonarTubeRemoveFavorite
        : l10n.sonarTubeAddFavorite;
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
        builder: (_) => _SonarTubeFavoritesScreen(
          favoritesService: _favoritesService,
          service: _service,
        ),
      ),
    );
    await _loadFavoriteKeys();
    if (item != null && mounted) await _openItem(item);
  }

  Future<void> _openRecentVideos() async {
    final item = await Navigator.push<SonarTubeItem>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/sonartube/recent-videos'),
        builder: (_) => _SonarTubeRecentVideosScreen(
          historyService: _historyService,
        ),
      ),
    );
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
    if (query.isEmpty) {
      _searchFocusNode.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/sonartube/search-results'),
        builder: (_) => SonarTubeScreen(
          searchQuery: query,
          service: _service,
          favoritesService: _favoritesService,
          historyService: _historyService,
        ),
      ),
    );
    if (mounted) {
      await _loadFavoriteKeys();
    }
  }

  Future<void> _loadSearchResults() async {
    if (_loading || !_isSearchResults) return;
    final query = widget.searchQuery!.trim();
    _query = query;
    setState(() {
      _loading = true;
      _error = null;
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

  Future<void> _retryCurrentLoad() async {
    if (_isSearchResults) {
      await _loadSearchResults();
      return;
    }
    if (_isCollection) {
      await _loadCollection();
    }
  }

  Future<void> _loadMore() async {
    var token = _nextToken;
    if (token == null || token.isEmpty || _loadingMore) return;
    final firstAppendedIndex = _items.length;
    var shouldFocusFirstAppendedItem = false;
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
          shouldFocusFirstAppendedItem = true;
          if (_isSearchResults) {
            _searchLoadMoreFocusIndex = firstAppendedIndex;
          }
        }
        _nextToken = appended.isEmpty ? null : token;
        _page = currentPage;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }

    if (!mounted || !shouldFocusFirstAppendedItem) return;

    if (_isSearchResults && !useSharedAccessibleViewModel) {
      await _focusFirstAppendedSearchResult(firstAppendedIndex);
      return;
    }

    if (!useSharedAccessibleViewModel) return;

    // Keep both collection browsing and the clean search-results route
    // renderer-neutral. On iOS this request is handled by UIKit; on Android
    // the shared Flutter renderer receives the same row id.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _accessibleListController.focusTo(
      'item_$firstAppendedIndex',
      animated: false,
    );
  }

  Future<void> _focusFirstAppendedSearchResult(int index) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _searchLoadMoreFocusIndex != index) return;

    final targetContext = _searchLoadMoreFocusTargetKey.currentContext;
    if (targetContext == null || !targetContext.mounted) return;

    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.35,
      duration: Duration.zero,
    );
    if (!mounted || !targetContext.mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _searchLoadMoreFocusIndex != index) return;
    _searchLoadMoreFocusTargetKey.currentContext
        ?.findRenderObject()
        ?.sendSemanticsEvent(const FocusSemanticEvent());
  }

  String _sonarTubeItemKey(SonarTubeItem item) =>
      '${item.kind.name}:${item.id}';


  String _shareableItemUrl(SonarTubeItem item) {
    final originalUrl = item.url.trim();
    final uri = Uri.tryParse(originalUrl);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return originalUrl;
    }

    return switch (item.kind) {
      SonarTubeItemKind.video =>
        Uri.https('www.youtube.com', '/watch', {'v': item.id}).toString(),
      SonarTubeItemKind.channel =>
        Uri.https('www.youtube.com', '/channel/${item.id}').toString(),
      SonarTubeItemKind.playlist =>
        Uri.https('www.youtube.com', '/playlist', {'list': item.id}).toString(),
    };
  }

  String _shareActionId(SonarTubeItem item) => switch (item.kind) {
    SonarTubeItemKind.video => 'share_video',
    SonarTubeItemKind.channel => 'share_channel',
    SonarTubeItemKind.playlist => 'share_playlist',
  };

  String _shareActionLabel(AppLocalizations l10n, SonarTubeItem item) =>
      switch (item.kind) {
        SonarTubeItemKind.video => l10n.sonarTubeShareVideo,
        SonarTubeItemKind.channel => l10n.sonarTubeShareChannel,
        SonarTubeItemKind.playlist => l10n.sonarTubeSharePlaylist,
      };

  Future<void> _shareItem(SonarTubeItem item) async {
    final url = _shareableItemUrl(item);
    await SharePlus.instance.share(
      ShareParams(
        text: '${item.title}\n$url',
        subject: item.title,
      ),
    );
  }

  Future<void> _openChannelForVideo(SonarTubeItem item) async {
    if (item.kind != SonarTubeItemKind.video) return;
    try {
      final channel = await _service.channelForVideo(item);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/sonartube/channel'),
          builder: (_) => SonarTubeScreen(
            collection: channel,
            service: _service,
            favoritesService: _favoritesService,
            historyService: _historyService,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _openComments(SonarTubeItem item) async {
    if (item.kind != SonarTubeItemKind.video || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/sonartube/comments'),
        builder: (_) => _SonarTubeCommentsScreen(
          item: item,
          service: _service,
        ),
      ),
    );
  }

  Future<void> _openTranscript(SonarTubeItem item) async {
    if (item.kind != SonarTubeItemKind.video || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/sonartube/transcript'),
        builder: (_) => _SonarTubeTranscriptScreen(
          item: item,
          service: _service,
        ),
      ),
    );
  }

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
            historyService: _historyService,
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
      final navigationItems = _isCollection
          ? _items
              .where((candidate) => candidate.kind == SonarTubeItemKind.video)
              .toList(growable: false)
          : const <SonarTubeItem>[];
      var navigationIndex = navigationItems.indexWhere(
        (candidate) => _sonarTubeItemKey(candidate) == _sonarTubeItemKey(item),
      );
      final episode = await _resolveEpisode(item);
      await _historyService.addRecentVideo(item);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final playerActions =
          await AppSettingsService().loadSonarTubePlayerActions();
      if (!mounted) return;

      SonarTubeItem currentVideoItem() => navigationIndex >= 0
          ? navigationItems[navigationIndex]
          : item;

      String currentFavoriteLabel() {
        final currentItem = currentVideoItem();
        final isFavorite = _favoriteKeys.contains(
          _favoritesService.itemKey(currentItem),
        );
        return _favoriteLabelForItem(
          l10n,
          currentItem,
          isFavorite: isFavorite,
        );
      }

      final extraPlayerActions = <PodcastPlayerExtraAction>[
        if (playerActions.contains(
          AppSettingsService.sonarTubePlayerActionShare,
        ))
          PodcastPlayerExtraAction(
            id: 'share_video',
            label: () => l10n.sonarTubeShareVideo,
            icon: Icons.share,
            pauseBeforeOpen: true,
            onPressed: () => _shareItem(currentVideoItem()),
          ),
        if (playerActions.contains(
          AppSettingsService.sonarTubePlayerActionFavorite,
        ))
          PodcastPlayerExtraAction(
            id: 'favorite',
            label: currentFavoriteLabel,
            icon: Icons.favorite_border,
            onPressed: () => _toggleFavorite(currentVideoItem()),
          ),
        if (playerActions.contains(
          AppSettingsService.sonarTubePlayerActionChannel,
        ))
          PodcastPlayerExtraAction(
            id: 'go_channel',
            label: () => l10n.sonarTubeGoToChannel,
            icon: Icons.account_circle_outlined,
            pauseBeforeOpen: true,
            onPressed: () => _openChannelForVideo(currentVideoItem()),
          ),
        if (playerActions.contains(
          AppSettingsService.sonarTubePlayerActionComments,
        ))
          PodcastPlayerExtraAction(
            id: 'view_comments',
            label: () => l10n.sonarTubeViewComments,
            icon: Icons.comment_outlined,
            pauseBeforeOpen: true,
            onPressed: () => _openComments(currentVideoItem()),
          ),
        if (playerActions.contains(
          AppSettingsService.sonarTubePlayerActionTranscript,
        ))
          PodcastPlayerExtraAction(
            id: 'transcribe_video',
            label: () => l10n.sonarTubeTranscribeVideo,
            icon: Icons.subject,
            pauseBeforeOpen: true,
            onPressed: () => _openTranscript(currentVideoItem()),
          ),
      ];

      Future<PodcastEpisode?> navigateEpisode(int direction) async {
        final targetIndex = navigationIndex + direction;
        if (navigationIndex < 0 ||
            targetIndex < 0 ||
            targetIndex >= navigationItems.length) {
          return null;
        }
        final targetItem = navigationItems[targetIndex];
        final resolved = await _resolveEpisode(targetItem);
        await _historyService.addRecentVideo(targetItem);
        navigationIndex = targetIndex;
        return resolved;
      }

      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/sonartube/player'),
          builder: (_) => PodcastEpisodePlayerScreen(
            episode: episode,
            isVideoSupported: true,
            startWithVideoThenRestorePreference: true,
            refreshEpisode: () {
              final currentItem = navigationIndex >= 0
                  ? navigationItems[navigationIndex]
                  : item;
              return _resolveEpisode(currentItem);
            },
            navigateEpisode: navigationIndex >= 0 ? navigateEpisode : null,
            hasPreviousEpisode: navigationIndex >= 0
                ? () => navigationIndex > 0
                : null,
            hasNextEpisode: navigationIndex >= 0
                ? () => navigationIndex + 1 < navigationItems.length
                : null,
            previousEpisodeLabel: navigationIndex >= 0
                ? l10n.sonarTubePreviousTrack
                : null,
            nextEpisodeLabel: navigationIndex >= 0
                ? l10n.sonarTubeNextTrack
                : null,
            showPreviousEpisodeAction: playerActions.contains(
              AppSettingsService.sonarTubePlayerActionPrevious,
            ),
            showNextEpisodeAction: playerActions.contains(
              AppSettingsService.sonarTubePlayerActionNext,
            ),
            extraActions: extraPlayerActions,
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
      if (item.kind == SonarTubeItemKind.channel &&
          (item.handle?.isNotEmpty ?? false))
        item.handle!,
      if (item.kind == SonarTubeItemKind.channel &&
          (item.subscribers?.isNotEmpty ?? false))
        item.subscribers!,
      if (item.kind != SonarTubeItemKind.channel &&
          (item.channel?.isNotEmpty ?? false))
        item.channel!,
      if (item.duration?.isNotEmpty ?? false) item.duration!,
      if (item.published?.isNotEmpty ?? false) item.published!,
      if (item.views?.isNotEmpty ?? false) item.views!,
    ].where((value) => value.isNotEmpty).toList();
    return values.isEmpty ? null : values.join(' · ');
  }

  List<AccessibleVisualAction> _sightedVisualActions(
    AppLocalizations l10n,
    SonarTubeItem item, {
    required bool isFavorite,
    required String favoriteLabel,
  }) {
    return [
      AccessibleVisualAction(
        id: 'favorite',
        label: favoriteLabel,
        icon: isFavorite ? 'favorite_filled' : 'favorite',
      ),
      AccessibleVisualAction(
        id: _shareActionId(item),
        label: _shareActionLabel(l10n, item),
        icon: 'share',
      ),
      if (item.kind == SonarTubeItemKind.video)
        AccessibleVisualAction(
          id: 'go_channel',
          label: l10n.sonarTubeGoToChannel,
          icon: 'channel',
        ),
      if (item.kind == SonarTubeItemKind.video)
        AccessibleVisualAction(
          id: 'view_comments',
          label: l10n.sonarTubeViewComments,
          icon: 'comments',
        ),
      if (item.kind == SonarTubeItemKind.video)
        AccessibleVisualAction(
          id: 'transcribe_video',
          label: l10n.sonarTubeTranscribeVideo,
          icon: 'transcript',
        ),
    ];
  }

  Widget _buildSightedActionBar(
    AppLocalizations l10n,
    SonarTubeItem item, {
    required bool isFavorite,
    required String favoriteLabel,
  }) {
    final enabled = _resolvingId == null;
    return ExcludeSemantics(
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 2,
        children: [
          IconButton(
            key: ValueKey(
              'sonartube_favorite_${item.kind.name}_${item.id}',
            ),
            tooltip: favoriteLabel,
            onPressed: enabled ? () => _toggleFavorite(item) : null,
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
          IconButton(
            key: ValueKey('sonartube_share_${item.kind.name}_${item.id}'),
            tooltip: _shareActionLabel(l10n, item),
            onPressed: enabled ? () => _shareItem(item) : null,
            icon: const Icon(Icons.share),
          ),
          if (item.kind == SonarTubeItemKind.video)
            IconButton(
              key: ValueKey('sonartube_channel_${item.id}'),
              tooltip: l10n.sonarTubeGoToChannel,
              onPressed: enabled ? () => _openChannelForVideo(item) : null,
              icon: const Icon(Icons.account_circle_outlined),
            ),
          if (item.kind == SonarTubeItemKind.video)
            IconButton(
              key: ValueKey('sonartube_comments_${item.id}'),
              tooltip: l10n.sonarTubeViewComments,
              onPressed: enabled ? () => _openComments(item) : null,
              icon: const Icon(Icons.comment_outlined),
            ),
          if (item.kind == SonarTubeItemKind.video)
            IconButton(
              key: ValueKey('sonartube_transcript_${item.id}'),
              tooltip: l10n.sonarTubeTranscribeVideo,
              onPressed: enabled ? () => _openTranscript(item) : null,
              icon: const Icon(Icons.subject),
            ),
        ],
      ),
    );
  }

  Widget _buildFlutterSonarTubeItem(
    AppLocalizations l10n,
    SonarTubeItem item, {
    required bool resolving,
    required bool isFavorite,
    required String favoriteLabel,
    required String? subtitle,
    bool includeCustomActions = false,
  }) {
    final card = Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
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
                : null,
            enabled: _resolvingId == null,
            onTap: _resolvingId == null ? () => _openItem(item) : null,
          ),
          if (!resolving)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _buildSightedActionBar(
                l10n,
                item,
                isFavorite: isFavorite,
                favoriteLabel: favoriteLabel,
              ),
            ),
        ],
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
      customSemanticsActions: includeCustomActions
          ? {
              CustomSemanticsAction(label: favoriteLabel):
                  () => _toggleFavorite(item),
              CustomSemanticsAction(label: _shareActionLabel(l10n, item)):
                  () => _shareItem(item),
              if (item.kind == SonarTubeItemKind.video)
                CustomSemanticsAction(label: l10n.sonarTubeGoToChannel):
                    () => _openChannelForVideo(item),
              if (item.kind == SonarTubeItemKind.video)
                CustomSemanticsAction(label: l10n.sonarTubeViewComments):
                    () => _openComments(item),
              if (item.kind == SonarTubeItemKind.video)
                CustomSemanticsAction(label: l10n.sonarTubeTranscribeVideo):
                    () => _openTranscript(item),
            }
          : null,
      child: ExcludeSemantics(child: card),
    );
  }

  Widget _buildSharedAccessibleSonarTube(AppLocalizations l10n) {
    final rows = <AccessibleListRow>[];
    if (_isCollection) {
      rows.add(
        AccessibleListRow(
          id: 'collection_title',
          title: widget.collection!.title,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: Text(
            widget.collection!.title,
            key: const ValueKey('sonartube_collection_content_title'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      );
    }
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
        id: 'recent_videos',
        title: l10n.sonarTubeRecentVideos,
        flutterChild: OutlinedButton.icon(
          key: const ValueKey('sonartube_recent_videos_button'),
          onPressed: _openRecentVideos,
          icon: const Icon(Icons.history),
          label: Text(l10n.sonarTubeRecentVideos),
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
    if (_isChannelCollection) {
      final channel = widget.collection!;
      final isFavorite = _favoriteKeys.contains(_favoritesService.itemKey(channel));
      final label = _favoriteLabelForItem(
        l10n,
        channel,
        isFavorite: isFavorite,
      );
      rows.add(AccessibleListRow(
        id: 'channel_favorite',
        title: label,
        kind: 'button',
        flutterChild: FilledButton.tonalIcon(
          key: const ValueKey('sonartube_collection_channel_favorite'),
          onPressed: () => _toggleFavorite(
            channel,
            accessibleRowId: 'channel_favorite',
          ),
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          label: Text(label),
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
        title: l10n.error(l10n.technicalErrorGeneric),
        kind: 'text',
      ));
      if (_isCollection) {
        rows.add(AccessibleListRow(
          id: 'retry',
          title: l10n.retry,
          kind: 'button',
          enabled: !_loading,
          flutterChild: FilledButton.tonal(
            key: const ValueKey('sonartube_retry'),
            onPressed: _loading ? null : _retryCurrentLoad,
            child: Text(l10n.retry),
          ),
        ));
      }
    }
    if (!_loading && _items.isEmpty && (_query != null || _isCollection)) {
      rows.add(AccessibleListRow(
        id: 'empty',
        title: l10n.sonarTubeNoResults,
        kind: 'text',
      ));
    }
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final resolving = _resolvingId == item.id;
      final isFavorite = _favoriteKeys.contains(_favoritesService.itemKey(item));
      final favoriteLabel = _favoriteLabelForItem(
        l10n,
        item,
        isFavorite: isFavorite,
      );
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
        actions: [
          AccessibleCustomAction(id: 'favorite', label: favoriteLabel),
          AccessibleCustomAction(
            id: _shareActionId(item),
            label: _shareActionLabel(l10n, item),
          ),
          if (item.kind == SonarTubeItemKind.video)
            AccessibleCustomAction(
              id: 'go_channel',
              label: l10n.sonarTubeGoToChannel,
            ),
          if (item.kind == SonarTubeItemKind.video)
            AccessibleCustomAction(
              id: 'view_comments',
              label: l10n.sonarTubeViewComments,
            ),
          if (item.kind == SonarTubeItemKind.video)
            AccessibleCustomAction(
              id: 'transcribe_video',
              label: l10n.sonarTubeTranscribeVideo,
            ),
        ],
        visualActions: _sightedVisualActions(
          l10n,
          item,
          isFavorite: isFavorite,
          favoriteLabel: favoriteLabel,
        ),
        flutterChild: _buildFlutterSonarTubeItem(
          l10n,
          item,
          resolving: resolving,
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
            event.action?.startsWith('share_') == true &&
            event.id?.startsWith('item_') == true) {
          final index = int.tryParse(event.id!.substring(5));
          if (index != null && index >= 0 && index < _items.length) {
            final item = _items[index];
            if (event.action == _shareActionId(item)) {
              await _shareItem(item);
            }
          }
          return;
        }
        if (event.type == 'customAction' &&
            (event.action == 'go_channel' ||
                event.action == 'view_comments' ||
                event.action == 'transcribe_video') &&
            event.id?.startsWith('item_') == true) {
          final index = int.tryParse(event.id!.substring(5));
          if (index != null && index >= 0 && index < _items.length) {
            final item = _items[index];
            if (event.action == 'go_channel') {
              await _openChannelForVideo(item);
            } else if (event.action == 'view_comments') {
              await _openComments(item);
            } else {
              await _openTranscript(item);
            }
          }
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
        } else if (event.id == 'channel_favorite' && _isChannelCollection) {
          await _toggleFavorite(
            widget.collection!,
            accessibleRowId: 'channel_favorite',
          );
        } else if (event.id == 'recent_videos') {
          await _openRecentVideos();
        } else if (event.id == 'search') {
          await _search();
        } else if (event.id == 'retry') {
          await _retryCurrentLoad();
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

  Widget _buildSearchResultsAccessible(AppLocalizations l10n) {
    final rows = <AccessibleListRow>[
      AccessibleListRow(
        id: 'title',
        title: l10n.searchResults,
        kind: 'text',
        accessibilityButtonTrait: false,
        flutterChild: Text(
          l10n.searchResults,
          key: const ValueKey('sonartube_search_results_title'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    ];

    if (_loading) {
      rows.add(
        AccessibleListRow(
          id: 'loading',
          title: l10n.loading,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: LinearProgressIndicator(semanticsLabel: l10n.loading),
        ),
      );
    } else if (_error != null) {
      final message = l10n.error(l10n.technicalErrorGeneric);
      rows.add(
        AccessibleListRow(
          id: 'error',
          title: message,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
      rows.add(
        AccessibleListRow(
          id: 'retry',
          title: l10n.retry,
          kind: 'button',
          enabled: !_loading,
          flutterChild: FilledButton.tonal(
            key: const ValueKey('sonartube_search_retry'),
            onPressed: _loading ? null : _loadSearchResults,
            child: Text(l10n.retry),
          ),
        ),
      );
    } else if (_items.isEmpty) {
      rows.add(
        AccessibleListRow(
          id: 'empty',
          title: l10n.sonarTubeNoResults,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: Text(
            l10n.sonarTubeNoResults,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      for (var index = 0; index < _items.length; index++) {
        final item = _items[index];
        final resolving = _resolvingId == item.id;
        final isFavorite = _favoriteKeys.contains(
          _favoritesService.itemKey(item),
        );
        final favoriteLabel = _favoriteLabelForItem(
          l10n,
          item,
          isFavorite: isFavorite,
        );
        final subtitle = resolving
            ? l10n.sonarTubeResolving
            : _subtitle(l10n, item);
        rows.add(
          AccessibleListRow(
            id: 'item_$index',
            title: item.title,
            subtitle: subtitle,
            accessibilityLabel: [
              item.title,
              if (subtitle?.isNotEmpty ?? false) subtitle!,
            ].join(', '),
            enabled: _resolvingId == null,
            actions: [
              AccessibleCustomAction(id: 'favorite', label: favoriteLabel),
              AccessibleCustomAction(
                id: _shareActionId(item),
                label: _shareActionLabel(l10n, item),
              ),
              if (item.kind == SonarTubeItemKind.video)
                AccessibleCustomAction(
                  id: 'go_channel',
                  label: l10n.sonarTubeGoToChannel,
                ),
              if (item.kind == SonarTubeItemKind.video)
                AccessibleCustomAction(
                  id: 'view_comments',
                  label: l10n.sonarTubeViewComments,
                ),
              if (item.kind == SonarTubeItemKind.video)
                AccessibleCustomAction(
                  id: 'transcribe_video',
                  label: l10n.sonarTubeTranscribeVideo,
                ),
            ],
            visualActions: _sightedVisualActions(
              l10n,
              item,
              isFavorite: isFavorite,
              favoriteLabel: favoriteLabel,
            ),
            flutterChild: _buildFlutterSonarTubeItem(
              l10n,
              item,
              resolving: resolving,
              isFavorite: isFavorite,
              favoriteLabel: favoriteLabel,
              subtitle: subtitle,
            ),
          ),
        );
      }
      if (_nextToken != null) {
        rows.add(
          AccessibleListRow(
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
          ),
        );
      }
    }

    return UniversalAccessibleList(
      controller: _accessibleListController,
      sections: [AccessibleListSection(rows: rows)],
      onEvent: (event) async {
        if (event.type == 'customAction' &&
            event.id?.startsWith('item_') == true) {
          final index = int.tryParse(event.id!.substring(5));
          if (index == null || index < 0 || index >= _items.length) return;
          final item = _items[index];
          if (event.action == 'favorite') {
            await _toggleFavorite(item, accessibleRowId: event.id);
          } else if (event.action == _shareActionId(item)) {
            await _shareItem(item);
          } else if (event.action == 'go_channel') {
            await _openChannelForVideo(item);
          } else if (event.action == 'view_comments') {
            await _openComments(item);
          } else if (event.action == 'transcribe_video') {
            await _openTranscript(item);
          }
          return;
        }
        if (event.type != 'activate' || event.id == null) return;
        if (event.id == 'retry') {
          await _loadSearchResults();
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

  Widget _buildSearchResultsMaterial(AppLocalizations l10n) {
    final rows = <Widget>[
      Text(
        l10n.searchResults,
        key: const ValueKey('sonartube_search_results_title'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
    ];

    if (_loading) {
      rows.add(LinearProgressIndicator(semanticsLabel: l10n.loading));
    } else if (_error != null) {
      rows.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.error(l10n.technicalErrorGeneric),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const ValueKey('sonartube_search_retry'),
              onPressed: _loading ? null : _loadSearchResults,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    } else if (_items.isEmpty) {
      rows.add(Text(l10n.sonarTubeNoResults, textAlign: TextAlign.center));
    } else {
      for (var index = 0; index < _items.length; index++) {
        final item = _items[index];
        final resolving = _resolvingId == item.id;
        final isFavorite = _favoriteKeys.contains(
          _favoritesService.itemKey(item),
        );
        final favoriteLabel = _favoriteLabelForItem(
          l10n,
          item,
          isFavorite: isFavorite,
        );
        final subtitle = resolving
            ? l10n.sonarTubeResolving
            : _subtitle(l10n, item);
        final itemWidget = _buildFlutterSonarTubeItem(
          l10n,
          item,
          resolving: resolving,
          isFavorite: isFavorite,
          favoriteLabel: favoriteLabel,
          subtitle: subtitle,
          includeCustomActions: true,
        );
        rows.add(
          index == _searchLoadMoreFocusIndex
              ? KeyedSubtree(
                  key: _searchLoadMoreFocusTargetKey,
                  child: itemWidget,
                )
              : itemWidget,
        );
      }
      if (_nextToken != null) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(
          key: const ValueKey('sonartube_search_results_back'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) => rows[index],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _service.setLocaleName(l10n.localeName);
    if (_isSearchResults) {
      return useSharedAccessibleViewModel
          ? Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                leading: BackButton(
                  key: const ValueKey('sonartube_search_results_back'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: SafeArea(
                child: _buildSearchResultsAccessible(l10n),
              ),
            )
          : _buildSearchResultsMaterial(l10n);
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !_isCollection,
        excludeHeaderSemantics: _isCollection && useSharedAccessibleViewModel,
        leading: _isCollection
            ? BackButton(
                key: const ValueKey('sonartube_collection_back'),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: _isCollection && useSharedAccessibleViewModel
            ? ExcludeSemantics(
                child: Text(widget.collection!.title),
              )
            : Text(widget.collection?.title ?? l10n.sonarTubeTitle),
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
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('sonartube_recent_videos_button'),
                      onPressed: _openRecentVideos,
                      icon: const Icon(Icons.history),
                      label: Text(l10n.sonarTubeRecentVideos),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.error(l10n.technicalErrorGeneric),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    if (_isCollection) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        key: const ValueKey('sonartube_retry'),
                        onPressed: _loading ? null : _retryCurrentLoad,
                        child: Text(l10n.retry),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: !_loading &&
                      _items.isEmpty &&
                      _query == null &&
                      !_isCollection
                  ? Center(
                      child: Text(
                        l10n.sonarTubeSearchPrompt,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: (_isChannelCollection ? 1 : 0) +
                          _items.length +
                          (!_loading && _items.isEmpty && _isCollection ? 1 : 0) +
                          (_nextToken == null ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (_isChannelCollection && index == 0) {
                          final channel = widget.collection!;
                          final isFavorite = _favoriteKeys.contains(
                            _favoritesService.itemKey(channel),
                          );
                          final label = _favoriteLabelForItem(
                            l10n,
                            channel,
                            isFavorite: isFavorite,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: FilledButton.tonalIcon(
                              key: const ValueKey(
                                'sonartube_collection_channel_favorite',
                              ),
                              onPressed: () => _toggleFavorite(channel),
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                              label: Text(label),
                            ),
                          );
                        }
                        var itemIndex = index - (_isChannelCollection ? 1 : 0);
                        if (itemIndex < _items.length) {
                          final item = _items[itemIndex];
                        final resolving = _resolvingId == item.id;
                        final isFavorite = _favoriteKeys.contains(
                          _favoritesService.itemKey(item),
                        );
                        final favoriteLabel = _favoriteLabelForItem(
                          l10n,
                          item,
                          isFavorite: isFavorite,
                        );
                        final subtitle = resolving
                            ? l10n.sonarTubeResolving
                            : _subtitle(l10n, item);
                          return _buildFlutterSonarTubeItem(
                            l10n,
                            item,
                            resolving: resolving,
                            isFavorite: isFavorite,
                            favoriteLabel: favoriteLabel,
                            subtitle: subtitle,
                            includeCustomActions: true,
                          );
                        }
                        itemIndex -= _items.length;
                        if (!_loading && _items.isEmpty && _isCollection) {
                          if (itemIndex == 0) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                l10n.sonarTubeNoResults,
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          itemIndex--;
                        }
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
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SonarTubeTranscriptScreen extends StatefulWidget {
  const _SonarTubeTranscriptScreen({
    required this.item,
    required this.service,
  });

  final SonarTubeItem item;
  final SonarTubeService service;

  @override
  State<_SonarTubeTranscriptScreen> createState() =>
      _SonarTubeTranscriptScreenState();
}

class _SonarTubeTranscriptScreenState
    extends State<_SonarTubeTranscriptScreen> {
  bool _loading = true;
  bool _unavailable = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final transcript = await widget.service.transcribe(widget.item);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      var safeTitle = (transcript.title ?? widget.item.title)
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (safeTitle.isEmpty) safeTitle = l10n.sonarTubeTranscript;
      if (safeTitle.length > 120) safeTitle = safeTitle.substring(0, 120).trim();
      final content = transcript.paragraphs.isEmpty
          ? transcript.text
          : transcript.paragraphs.join('\n\n');
      final document = await DocumentLibraryService().createTextDocument(
        name: '$safeTitle - ${l10n.sonarTubeTranscript}.txt',
        content: content,
        isTemporary: true,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/documents/reader'),
          builder: (_) => DocumentReaderScreen(document: document),
        ),
      );
    } on SonarTubeTranscriptUnavailableException {
      if (!mounted) return;
      setState(() {
        _unavailable = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _retry() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _unavailable = false;
      _failed = false;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    widget.service.setLocaleName(l10n.localeName);
    final flutterRows = <Widget>[
      Text(
        l10n.sonarTubeTranscript,
        key: const ValueKey('sonartube_transcript_title'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        widget.item.title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ];
    final accessibleRows = <AccessibleListRow>[
      AccessibleListRow(
        id: 'title',
        title: l10n.sonarTubeTranscript,
        kind: 'text',
        accessibilityButtonTrait: false,
        flutterChild: flutterRows[0],
      ),
      AccessibleListRow(
        id: 'video_title',
        title: widget.item.title,
        kind: 'text',
        accessibilityButtonTrait: false,
        flutterChild: flutterRows[1],
      ),
    ];

    if (_loading) {
      final child = LinearProgressIndicator(semanticsLabel: l10n.loading);
      flutterRows.add(child);
      accessibleRows.add(
        AccessibleListRow(
          id: 'loading',
          title: l10n.loading,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: child,
        ),
      );
    } else if (_unavailable) {
      final child = Text(
        l10n.sonarTubeNoTranscript,
        textAlign: TextAlign.center,
      );
      flutterRows.add(child);
      accessibleRows.add(
        AccessibleListRow(
          id: 'unavailable',
          title: l10n.sonarTubeNoTranscript,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: child,
        ),
      );
    } else if (_failed) {
      final message = l10n.error(l10n.technicalErrorGeneric);
      final child = Text(message, textAlign: TextAlign.center);
      final retryButton = FilledButton.tonal(
        key: const ValueKey('sonartube_transcript_retry'),
        onPressed: _retry,
        child: Text(l10n.retry),
      );
      flutterRows.add(child);
      flutterRows.add(retryButton);
      accessibleRows.add(
        AccessibleListRow(
          id: 'error',
          title: message,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: child,
        ),
      );
      accessibleRows.add(
        AccessibleListRow(
          id: 'retry',
          title: l10n.retry,
          kind: 'button',
          flutterChild: retryButton,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(
          key: const ValueKey('sonartube_transcript_back'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                sections: [AccessibleListSection(rows: accessibleRows)],
                onEvent: (event) async {
                  if (event.type != 'activate') return;
                  if (event.id == 'retry') {
                    await _retry();
                  }
                },
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: flutterRows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => flutterRows[index],
              ),
      ),
    );
  }
}

class _SonarTubeCommentsScreen extends StatefulWidget {
  const _SonarTubeCommentsScreen({
    required this.item,
    required this.service,
  });

  final SonarTubeItem item;
  final SonarTubeService service;

  @override
  State<_SonarTubeCommentsScreen> createState() =>
      _SonarTubeCommentsScreenState();
}

class _SonarTubeCommentsScreenState extends State<_SonarTubeCommentsScreen> {
  List<SonarTubeComment> _comments = const [];
  String? _nextToken;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await widget.service.comments(widget.item);
      if (!mounted) return;
      setState(() {
        _comments = page.items;
        _nextToken = page.nextToken;
        _page = page.page;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final token = _nextToken;
    if (token == null || token.isEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.service.comments(
        widget.item,
        token: token,
        page: _page + 1,
      );
      if (!mounted) return;
      final known = _comments.map((comment) => comment.id).toSet();
      setState(() {
        _comments = [
          ..._comments,
          ...page.items.where((comment) => known.add(comment.id)),
        ];
        _nextToken = page.nextToken;
        _page = page.page;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    widget.service.setLocaleName(l10n.localeName);
    final flutterRows = <Widget>[
      Text(
        l10n.sonarTubeComments,
        key: const ValueKey('sonartube_comments_title'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    ];
    final accessibleRows = <AccessibleListRow>[
      AccessibleListRow(
        id: 'title',
        title: l10n.sonarTubeComments,
        kind: 'text',
        accessibilityButtonTrait: false,
        flutterChild: flutterRows[0],
      ),
    ];

    if (_loading) {
      final child = LinearProgressIndicator(semanticsLabel: l10n.loading);
      flutterRows.add(child);
      accessibleRows.add(
        AccessibleListRow(
          id: 'loading',
          title: l10n.loading,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: child,
        ),
      );
    } else if (_failed && _comments.isEmpty) {
      final message = l10n.error(l10n.technicalErrorGeneric);
      final child = Text(message, textAlign: TextAlign.center);
      flutterRows.add(child);
      accessibleRows.add(
        AccessibleListRow(
          id: 'error',
          title: message,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: child,
        ),
      );
    } else if (_comments.isEmpty) {
      final child = Text(
        l10n.sonarTubeNoComments,
        textAlign: TextAlign.center,
      );
      flutterRows.add(child);
      accessibleRows.add(
        AccessibleListRow(
          id: 'empty',
          title: l10n.sonarTubeNoComments,
          kind: 'text',
          accessibilityButtonTrait: false,
          flutterChild: child,
        ),
      );
    } else {
      for (var index = 0; index < _comments.length; index++) {
        final comment = _comments[index];
        final author = comment.author?.trim() ?? '';
        final published = comment.published?.trim() ?? '';
        final title = author.isEmpty ? comment.text : author;
        final details = <String>[
          if (author.isNotEmpty) comment.text,
          if (published.isNotEmpty) published,
        ].join('\n');
        final child = Card(
          key: ValueKey('sonartube_comment_${comment.id}'),
          child: ListTile(
            title: Text(title),
            subtitle: details.isEmpty ? null : Text(details),
          ),
        );
        flutterRows.add(child);
        accessibleRows.add(
          AccessibleListRow(
            id: 'comment_$index',
            title: title,
            subtitle: details.isEmpty ? null : details,
            kind: 'text',
            accessibilityButtonTrait: false,
            flutterChild: child,
          ),
        );
      }
      if (_failed) {
        final message = l10n.error(l10n.technicalErrorGeneric);
        final child = Text(message, textAlign: TextAlign.center);
        flutterRows.add(child);
        accessibleRows.add(
          AccessibleListRow(
            id: 'error_more',
            title: message,
            kind: 'text',
            accessibilityButtonTrait: false,
            flutterChild: child,
          ),
        );
      }
      if (_nextToken != null && _nextToken!.isNotEmpty) {
        final child = SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            key: const ValueKey('sonartube_comments_load_more'),
            onPressed: _loadingMore ? null : _loadMore,
            child: _loadingMore
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.loading,
                    ),
                  )
                : Text(l10n.sonarTubeLoadMoreComments),
          ),
        );
        flutterRows.add(child);
        accessibleRows.add(
          AccessibleListRow(
            id: 'load_more',
            title: _loadingMore ? l10n.loading : l10n.sonarTubeLoadMoreComments,
            kind: 'button',
            enabled: !_loadingMore,
            flutterChild: child,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(
          key: const ValueKey('sonartube_comments_back'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                sections: [AccessibleListSection(rows: accessibleRows)],
                onEvent: (event) async {
                  if (event.type != 'activate' || event.id == null) return;
                  if (event.id == 'load_more') {
                    await _loadMore();
                  }
                },
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: flutterRows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) => flutterRows[index],
              ),
      ),
    );
  }
}

class _SonarTubeRecentVideosScreen extends StatefulWidget {
  const _SonarTubeRecentVideosScreen({required this.historyService});

  final SonarTubeHistoryService historyService;

  @override
  State<_SonarTubeRecentVideosScreen> createState() =>
      _SonarTubeRecentVideosScreenState();
}

class _SonarTubeRecentVideosScreenState
    extends State<_SonarTubeRecentVideosScreen> {
  List<SonarTubeItem> _recent = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recent = await widget.historyService.loadRecentVideos();
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _loading = false;
    });
  }

  Future<void> _deleteRecentVideo(SonarTubeItem item) async {
    await widget.historyService.removeRecentVideo(item.id);
    if (!mounted) return;
    setState(() {
      _recent = _recent
          .where((candidate) => candidate.id != item.id)
          .toList(growable: false);
    });
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.sonarTubeConfirmClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.historyService.clearRecentVideos();
    if (!mounted) return;
    setState(() => _recent = const []);
  }

  String? _subtitle(SonarTubeItem item) {
    final values = <String>[
      if (item.channel?.isNotEmpty ?? false) item.channel!,
      if (item.duration?.isNotEmpty ?? false) item.duration!,
      if (item.published?.isNotEmpty ?? false) item.published!,
      if (item.views?.isNotEmpty ?? false) item.views!,
    ];
    return values.isEmpty ? null : values.join(' · ');
  }

  Widget _buildSharedAccessibleRecentVideos(AppLocalizations l10n) {
    final rows = <AccessibleListRow>[];
    if (_loading) {
      rows.add(
        AccessibleListRow(
          id: 'loading',
          title: l10n.loading,
          kind: 'text',
          accessibilityButtonTrait: false,
        ),
      );
    } else if (_recent.isEmpty) {
      rows.add(
        AccessibleListRow(
          id: 'empty',
          title: l10n.sonarTubeNoRecentVideos,
          kind: 'text',
          accessibilityButtonTrait: false,
        ),
      );
    } else {
      rows.add(
        AccessibleListRow(
          id: 'clear_history',
          title: l10n.clearHistory,
          kind: 'button',
        ),
      );
      rows.addAll(
        _recent.asMap().entries.map((entry) {
          final item = entry.value;
          return AccessibleListRow(
            id: 'recent_${entry.key}',
            title: item.title,
            subtitle: _subtitle(item),
            kind: 'action',
            actions: [
              AccessibleCustomAction(
                id: 'delete_video',
                label: l10n.sonarTubeDeleteRecentVideo,
              ),
            ],
            visualActions: [
              AccessibleVisualAction(
                id: 'delete_video',
                label: l10n.sonarTubeDeleteRecentVideo,
                icon: 'remove',
              ),
            ],
          );
        }),
      );
    }

    return UniversalAccessibleList(
      sections: [AccessibleListSection(rows: rows)],
      onEvent: (event) async {
        if (event.id == null) return;
        if (event.id == 'clear_history' && event.type == 'activate') {
          await _clearHistory();
          return;
        }
        if (!event.id!.startsWith('recent_')) return;
        final index = int.tryParse(event.id!.substring(7));
        if (index == null || index < 0 || index >= _recent.length) return;
        final item = _recent[index];
        if (event.type == 'customAction' &&
            event.action == 'delete_video') {
          await _deleteRecentVideo(item);
          return;
        }
        if (event.type == 'activate' && mounted) {
          Navigator.pop(context, item);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(
          key: const ValueKey('sonartube_recent_videos_back'),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.sonarTubeRecentVideos),
        actions: [
          if (_recent.isNotEmpty && !useSharedAccessibleViewModel)
            IconButton(
              key: const ValueKey('sonartube_clear_recent_videos'),
              tooltip: l10n.clearHistory,
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_sweep),
            ),
        ],
      ),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? _buildSharedAccessibleRecentVideos(l10n)
            : _loading
                ? Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: l10n.loading,
                    ),
                  )
                : _recent.isEmpty
                    ? Center(
                        child: Text(
                          l10n.sonarTubeNoRecentVideos,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _recent.length,
                        itemBuilder: (context, index) {
                          final item = _recent[index];
                          return Semantics(
                            key: ValueKey('sonartube_recent_video_${item.id}'),
                            container: true,
                            customSemanticsActions: {
                              CustomSemanticsAction(
                                label: l10n.sonarTubeDeleteRecentVideo,
                              ): () => _deleteRecentVideo(item),
                            },
                            child: ListTile(
                              leading: item.thumbnailUrl == null
                                  ? const Icon(Icons.play_circle_outline)
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        item.thumbnailUrl!,
                                        width: 88,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        excludeFromSemantics: true,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox(
                                          width: 88,
                                          child: Icon(Icons.video_library),
                                        ),
                                      ),
                                    ),
                              title: Text(item.title),
                              subtitle: _subtitle(item) == null
                                  ? null
                                  : Text(_subtitle(item)!),
                              trailing: ExcludeSemantics(
                                child: IconButton(
                                  key: ValueKey('sonartube_delete_recent_video_${item.id}'),
                                  tooltip: l10n.sonarTubeDeleteRecentVideo,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteRecentVideo(item),
                                ),
                              ),
                              onTap: () => Navigator.pop(context, item),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _SonarTubeFavoritesScreen extends StatefulWidget {
  const _SonarTubeFavoritesScreen({
    required this.favoritesService,
    required this.service,
  });

  final SonarTubeFavoritesService favoritesService;
  final SonarTubeService service;

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

  Future<void> _openChannel(SonarTubeItem item) async {
    try {
      final channel = await widget.service.channelForVideo(item);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/sonartube/channel'),
          builder: (_) => SonarTubeScreen(
            collection: channel,
            service: widget.service,
            favoritesService: widget.favoritesService,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showStatusMessage(
        context,
        AppLocalizations.of(context).error(
          AppLocalizations.of(context).technicalErrorGeneric,
        ),
      );
    }
  }

  Future<void> _openComments(SonarTubeItem item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/sonartube/comments'),
        builder: (_) => _SonarTubeCommentsScreen(
          item: item,
          service: widget.service,
        ),
      ),
    );
  }

  Future<void> _openTranscript(SonarTubeItem item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/sonartube/transcript'),
        builder: (_) => _SonarTubeTranscriptScreen(
          item: item,
          service: widget.service,
        ),
      ),
    );
  }

  Widget _buildSharedAccessibleFavorites(AppLocalizations l10n) {
    final rows = <AccessibleListRow>[];
    if (_loading) {
      rows.add(
        AccessibleListRow(
          id: 'loading',
          title: l10n.loading,
          kind: 'text',
          accessibilityButtonTrait: false,
        ),
      );
    } else if (_favorites.isEmpty) {
      rows.add(
        AccessibleListRow(
          id: 'empty',
          title: l10n.sonarTubeNoFavorites,
          kind: 'text',
          accessibilityButtonTrait: false,
        ),
      );
    } else {
      rows.addAll(
        _favorites.asMap().entries.map((entry) {
          final item = entry.value;
          final type = switch (item.kind) {
            SonarTubeItemKind.video => l10n.sonarTubeVideo,
            SonarTubeItemKind.channel => l10n.sonarTubeChannel,
            SonarTubeItemKind.playlist => l10n.sonarTubePlaylist,
          };
          final favoriteSubtitle = <String>[
            type,
            if (item.kind == SonarTubeItemKind.channel &&
                (item.handle?.isNotEmpty ?? false))
              item.handle!,
            if (item.kind == SonarTubeItemKind.channel &&
                (item.subscribers?.isNotEmpty ?? false))
              item.subscribers!,
          ].join(' · ');
          final removeLabel = item.kind == SonarTubeItemKind.channel
              ? l10n.sonarTubeRemoveChannelFavorite
              : l10n.sonarTubeRemoveFavorite;
          return AccessibleListRow(
            id: 'favorite_${entry.key}',
            title: item.title,
            subtitle: favoriteSubtitle,
            actions: [
              AccessibleCustomAction(id: 'remove', label: removeLabel),
              if (item.kind == SonarTubeItemKind.video)
                AccessibleCustomAction(
                  id: 'go_channel',
                  label: l10n.sonarTubeGoToChannel,
                ),
              if (item.kind == SonarTubeItemKind.video)
                AccessibleCustomAction(
                  id: 'view_comments',
                  label: l10n.sonarTubeViewComments,
                ),
              if (item.kind == SonarTubeItemKind.video)
                AccessibleCustomAction(
                  id: 'transcribe_video',
                  label: l10n.sonarTubeTranscribeVideo,
                ),
            ],
            visualActions: [
              AccessibleVisualAction(
                id: 'remove',
                label: removeLabel,
                icon: 'remove',
              ),
              if (item.kind == SonarTubeItemKind.video)
                AccessibleVisualAction(
                  id: 'go_channel',
                  label: l10n.sonarTubeGoToChannel,
                  icon: 'channel',
                ),
              if (item.kind == SonarTubeItemKind.video)
                AccessibleVisualAction(
                  id: 'view_comments',
                  label: l10n.sonarTubeViewComments,
                  icon: 'comments',
                ),
              if (item.kind == SonarTubeItemKind.video)
                AccessibleVisualAction(
                  id: 'transcribe_video',
                  label: l10n.sonarTubeTranscribeVideo,
                  icon: 'transcript',
                ),
            ],
          );
        }),
      );
    }

    return UniversalAccessibleList(
      sections: [AccessibleListSection(rows: rows)],
      onEvent: (event) async {
        if (event.id?.startsWith('favorite_') != true) return;
        final index = int.tryParse(event.id!.substring(9));
        if (index == null || index < 0 || index >= _favorites.length) return;
        final item = _favorites[index];
        if (event.type == 'customAction' && event.action == 'remove') {
          await _remove(item);
        } else if (event.type == 'customAction' &&
            event.action == 'go_channel') {
          await _openChannel(item);
        } else if (event.type == 'customAction' &&
            event.action == 'view_comments') {
          await _openComments(item);
        } else if (event.type == 'customAction' &&
            event.action == 'transcribe_video') {
          await _openTranscript(item);
        } else if (event.type == 'activate') {
          if (mounted) Navigator.pop(context, item);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    widget.service.setLocaleName(l10n.localeName);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(
          key: const ValueKey('sonartube_favorites_back'),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.sonarTubeFavorites),
      ),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? _buildSharedAccessibleFavorites(l10n)
            : _loading
                ? Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: l10n.loading,
                    ),
                  )
                : _favorites.isEmpty
                    ? Center(
                        child: Text(
                          l10n.sonarTubeNoFavorites,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _favorites.length,
                        itemBuilder: (context, index) {
                          final item = _favorites[index];
                          final type = switch (item.kind) {
                            SonarTubeItemKind.video => l10n.sonarTubeVideo,
                            SonarTubeItemKind.channel => l10n.sonarTubeChannel,
                            SonarTubeItemKind.playlist => l10n.sonarTubePlaylist,
                          };
                          final favoriteSubtitle = <String>[
                            type,
                            if (item.kind == SonarTubeItemKind.channel &&
                                (item.handle?.isNotEmpty ?? false))
                              item.handle!,
                            if (item.kind == SonarTubeItemKind.channel &&
                                (item.subscribers?.isNotEmpty ?? false))
                              item.subscribers!,
                          ].join(' · ');
                          final removeLabel =
                              item.kind == SonarTubeItemKind.channel
                                  ? l10n.sonarTubeRemoveChannelFavorite
                                  : l10n.sonarTubeRemoveFavorite;
                          return Semantics(
                            customSemanticsActions: {
                              CustomSemanticsAction(label: removeLabel):
                                  () => _remove(item),
                              if (item.kind == SonarTubeItemKind.video)
                                CustomSemanticsAction(
                                  label: l10n.sonarTubeGoToChannel,
                                ): () => _openChannel(item),
                              if (item.kind == SonarTubeItemKind.video)
                                CustomSemanticsAction(
                                  label: l10n.sonarTubeViewComments,
                                ): () => _openComments(item),
                              if (item.kind == SonarTubeItemKind.video)
                                CustomSemanticsAction(
                                  label: l10n.sonarTubeTranscribeVideo,
                                ): () => _openTranscript(item),
                            },
                            child: Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    key: ValueKey(
                                      'sonartube_favorite_item_${item.kind.name}_${item.id}',
                                    ),
                                    leading: item.thumbnailUrl == null
                                        ? Icon(
                                            item.kind == SonarTubeItemKind.video
                                                ? Icons.play_circle_outline
                                                : item.kind ==
                                                        SonarTubeItemKind.channel
                                                    ? Icons.account_circle
                                                    : Icons.playlist_play,
                                          )
                                        : ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: Image.network(
                                              item.thumbnailUrl!,
                                              width: 88,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              excludeFromSemantics: true,
                                              errorBuilder: (_, _, _) =>
                                                  const SizedBox(
                                                width: 88,
                                                child:
                                                    Icon(Icons.video_library),
                                              ),
                                            ),
                                          ),
                                    title: Text(item.title),
                                    subtitle: Text(favoriteSubtitle),
                                    trailing: ExcludeSemantics(
                                      child: IconButton(
                                        key: ValueKey(
                                          'sonartube_remove_favorite_${item.kind.name}_${item.id}',
                                        ),
                                        tooltip: removeLabel,
                                        onPressed: () => _remove(item),
                                        icon: const Icon(Icons.favorite),
                                      ),
                                    ),
                                    onTap: () => Navigator.pop(context, item),
                                  ),
                                  if (item.kind == SonarTubeItemKind.video)
                                    Align(
                                      alignment:
                                          AlignmentDirectional.centerEnd,
                                      child: ExcludeSemantics(
                                        child: Wrap(
                                          spacing: 2,
                                          children: [
                                            IconButton(
                                              tooltip:
                                                  l10n.sonarTubeGoToChannel,
                                              onPressed: () =>
                                                  _openChannel(item),
                                              icon: const Icon(
                                                Icons.account_circle_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip:
                                                  l10n.sonarTubeViewComments,
                                              onPressed: () =>
                                                  _openComments(item),
                                              icon: const Icon(
                                                Icons.comment_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: l10n
                                                  .sonarTubeTranscribeVideo,
                                              onPressed: () =>
                                                  _openTranscript(item),
                                              icon: const Icon(Icons.subject),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
