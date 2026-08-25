import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../widgets/media_preservation_progress_dialog.dart';
import '../services/podcast_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/recent_searches_service.dart';
import '../utils/list_timestamp_formatter.dart';
import 'podcast_episode_player_screen.dart';
import 'recent_searches_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class RaiPlaySoundScreen extends StatefulWidget {
  final String? url;
  final String? searchQuery;
  final RaiPlaySoundService? service;

  const RaiPlaySoundScreen({
    super.key,
    this.url,
    this.searchQuery,
    this.service,
  });

  @override
  State<RaiPlaySoundScreen> createState() => _RaiPlaySoundScreenState();
}

class _RaiPlaySoundScreenState extends State<RaiPlaySoundScreen> {
  final _settings = AppSettingsService();
  late final _service = widget.service ?? RaiPlaySoundService();
  final _podcastService = PodcastService();
  final _searchController = TextEditingController();
  final _scrollController = AutoScrollController();
  final AccessibleListController _accessibleListController =
      AccessibleListController(debugName: 'raiplaysound');

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
    _scrollController.dispose();
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
        publishedAt: item.publishedAt ?? DateTime.now(),
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

  Future<String?> _resolvedAudioUrlForItem(RaiPlaySoundItem item) async {
    if (item.kind != RaiPlaySoundItemKind.audio) return null;
    final code = await _settings.getTvSecretCode();
    final baseUrl = _service.getBaseUrl(code);
    if (baseUrl == null) return null;

    var audioPath = item.audioUrl.trim();
    if (audioPath.isEmpty) return null;
    if (!audioPath.startsWith('http')) {
      if (!audioPath.startsWith('/')) audioPath = '/$audioPath';
      audioPath = '$baseUrl$audioPath';
    }
    return audioPath;
  }

  Future<void> _preserveMedia(RaiPlaySoundItem item) async {
    await preserveMediaWithProgress(
      context,
      title: item.title,
      resolveUrl: () async {
        final audioUrl = await _resolvedAudioUrlForItem(item);
        if (audioUrl == null || audioUrl.isEmpty) {
          throw const FormatException('Missing RaiPlay Sound audio URL');
        }
        return audioUrl;
      },
    );
  }

  bool _hasDatedAudioItems(List<RaiPlaySoundItem> items) => items.any(
        (item) =>
            item.kind == RaiPlaySoundItemKind.audio && item.publishedAt != null,
      );

  Future<void> _openDateSelector(List<RaiPlaySoundItem> items) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _RaiPlaySoundDateSelectorScreen(
          items: items,
          onOpenItem: (item) => _openItem(item),
        ),
      ),
    );
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
                showStatusMessage(context, 'Podcast già presente');
        return;
      }
      await _podcastService.addSubscription(page.source);
      if (!mounted) return;
            showStatusMessage(context, 'Podcast aggiunto: ${page.title}');
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, 'Errore iscrizione podcast: $e');
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

  Widget _buildSharedAccessibleBody(AppLocalizations l10n, List<RaiPlaySoundItem> items, bool hasDateButton) {
    return UniversalAccessibleList(
      controller: _accessibleListController,
      sections: [
        AccessibleListSection(rows: [
          if (_isRoot)
            AccessibleListRow(id: 'search_query', title: 'Cerca su RaiPlay Sound', kind: 'textField', value: _searchController.text, textInputAction: 'search', onSubmitted: (_) => _search()),
          if (_isRoot) const AccessibleListRow(id: 'search', title: 'Cerca', kind: 'button'),
          if (_isRoot) const AccessibleListRow(id: 'recent', title: 'Ricerche recenti'),
          if (_error != null) AccessibleListRow(id: 'error', kind: 'text', title: _error!),
          if (hasDateButton) AccessibleListRow(id: 'select_date', title: l10n.podcastSelectDate),
          for (var i = 0; i < items.length; i++)
            AccessibleListRow(
              id: 'item_$i',
              title: items[i].kind == RaiPlaySoundItemKind.audio
                  ? titleWithListTimestamp(items[i].title, items[i].publishedAt, l10n.localeName)
                  : items[i].title,
              subtitle: items[i].description.isNotEmpty ? items[i].description : null,
              actions: [
                if (items[i].kind == RaiPlaySoundItemKind.audio)
                  AccessibleCustomAction(
                    id: 'preserve_media',
                    label: l10n.preserveMedia,
                  ),
                if (items[i].kind == RaiPlaySoundItemKind.audio &&
                    _canSubscribeCurrentPage)
                  const AccessibleCustomAction(
                    id: 'subscribe',
                    label: 'Aggiungi ai podcast',
                  ),
              ],
              visualActionId: items[i].kind == RaiPlaySoundItemKind.audio
                  ? 'preserve_media'
                  : null,
              visualActionIcon: items[i].kind == RaiPlaySoundItemKind.audio
                  ? 'download'
                  : null,
            ),
        ]),
      ],
      onEvent: (event) async {
        if (event.id == 'search_query' && event.type == 'textChanged') {
          _searchController.text = event.value?.toString() ?? '';
        } else if (event.id == 'search' && event.type == 'activate') {
          await _search();
        } else if (event.id == 'recent' && event.type == 'activate') {
          await _openRecentSearches();
        } else if (event.id == 'select_date' && event.type == 'activate') {
          await _openDateSelector(items);
        } else if (event.id?.startsWith('item_') == true) {
          final i = int.tryParse(event.id!.substring(5));
          if (i == null || i >= items.length) return;
          if (event.type == 'customAction' &&
              event.action == 'preserve_media' &&
              items[i].kind == RaiPlaySoundItemKind.audio) {
            await _preserveMedia(items[i]);
          } else if (event.type == 'customAction' &&
              event.action == 'subscribe') {
            await _subscribeCurrentPageToPodcasts();
          } else if (event.type == 'activate') {
            _openItem(items[i]);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _page?.items ?? const <RaiPlaySoundItem>[];
    final hasDateButton = _hasDatedAudioItems(items);
    return Scaffold(
      appBar: AppBar(title: Text(_page?.title ?? 'RaiPlay Sound')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _page == null
              ? Center(child: Text(_error!))
              : useSharedAccessibleViewModel
                  ? _buildSharedAccessibleBody(l10n, items, hasDateButton)
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
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length + (hasDateButton ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (hasDateButton && index == 0) {
                            return AutoScrollTag(
                              key: const ValueKey(
                                'raiplaysound_select_date_scroll',
                              ),
                              controller: _scrollController,
                              index: index,
                              child: Card(
                                child: ListTile(
                                  key: const ValueKey(
                                    'raiplaysound_select_date',
                                  ),
                                  leading: const Icon(Icons.event),
                                  title: Text(l10n.podcastSelectDate),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openDateSelector(items),
                                ),
                              ),
                            );
                          }

                          final itemIndex = index - (hasDateButton ? 1 : 0);
                          final item = items[itemIndex];
                          final isAudio =
                              item.kind == RaiPlaySoundItemKind.audio;

                          return AutoScrollTag(
                            key: ValueKey(
                              'raiplaysound_item_scroll_${item.id}',
                            ),
                            controller: _scrollController,
                            index: index,
                            child: Card(
                              key: ValueKey('raiplaysound_item_${item.id}'),
                              child: Semantics(
                                key: ValueKey(
                                    'raiplaysound_item_semantics_${item.id}'),
                                container: true,
                                customSemanticsActions: {
                                  if (isAudio)
                                    CustomSemanticsAction(
                                      label: l10n.preserveMedia,
                                    ): () => unawaited(
                                          _preserveMedia(item),
                                        ),
                                  if (isAudio && _canSubscribeCurrentPage)
                                    const CustomSemanticsAction(
                                      label: 'Aggiungi ai podcast',
                                    ): () => unawaited(
                                          _subscribeCurrentPageToPodcasts(),
                                        ),
                                },
                                child: ListTile(
                                  key: ValueKey(
                                      'raiplaysound_item_tile_${item.id}'),
                                  leading: Icon(
                                    isAudio ? Icons.audiotrack : Icons.folder,
                                  ),
                                  title: Text(
                                    isAudio
                                        ? titleWithListTimestamp(
                                            item.title,
                                            item.publishedAt,
                                            l10n.localeName,
                                          )
                                        : item.title,
                                  ),
                                  subtitle: item.description.isNotEmpty
                                      ? Text(
                                          item.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  trailing: isAudio
                                      ? ExcludeSemantics(
                                          child: IconButton(
                                            icon: const Icon(Icons.download),
                                            tooltip: l10n.preserveMedia,
                                            onPressed: () => unawaited(
                                              _preserveMedia(item),
                                            ),
                                          ),
                                        )
                                      : null,
                                  onTap: () => _openItem(item),
                                ),
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

class _RaiPlaySoundDateSelectorScreen extends StatelessWidget {
  const _RaiPlaySoundDateSelectorScreen({
    required this.items,
    required this.onOpenItem,
  });

  final List<RaiPlaySoundItem> items;
  final void Function(RaiPlaySoundItem item) onOpenItem;

  List<RaiPlaySoundItem> _itemsForDate(DateTime date) {
    return items.where((item) {
      if (item.kind != RaiPlaySoundItemKind.audio) return false;
      final publishedAt = item.publishedAt;
      if (publishedAt == null) return false;
      final localDate = publishedAt.toLocal();
      return localDate.year == date.year &&
          localDate.month == date.month &&
          localDate.day == date.day;
    }).toList(growable: false);
  }

  void _openDate(BuildContext context, DateTime date) {
    final dateItems = _itemsForDate(date);
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/raiplaysound/date'),
        builder: (_) => _RaiPlaySoundDateItemsScreen(
          items: dateItems,
          onOpenItem: onOpenItem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = DateFormat.yMMMMd(l10n.localeName);
    final dates = <DateTime>[];
    final seenDates = <String>{};

    for (final item in items) {
      if (item.kind != RaiPlaySoundItemKind.audio) continue;
      final publishedAt = item.publishedAt;
      if (publishedAt == null) continue;
      final localDate = publishedAt.toLocal();
      final dateKey = '${localDate.year.toString().padLeft(4, '0')}-'
          '${localDate.month.toString().padLeft(2, '0')}-'
          '${localDate.day.toString().padLeft(2, '0')}';
      if (seenDates.add(dateKey)) {
        dates.add(localDate);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.podcastSelectDate)),
      body: SafeArea(
        child: dates.isEmpty
            ? Center(child: Text(l10n.podcastNoDatesAvailable))
            : useSharedAccessibleViewModel
                ? UniversalAccessibleList(
                    sections: [
                      AccessibleListSection(
                        rows: [
                          for (var i = 0; i < dates.length; i++)
                            AccessibleListRow(
                              id: 'date_$i',
                              title: formatter.format(dates[i]),
                            ),
                        ],
                      ),
                    ],
                    onEvent: (event) {
                      if (event.type != 'activate' || event.id == null) return;
                      final i = int.tryParse(
                        event.id!.replaceFirst('date_', ''),
                      );
                      if (i != null && i < dates.length) {
                        _openDate(context, dates[i]);
                      }
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: dates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final date = dates[index];
                      return Card(
                        child: ListTile(
                          title: Text(formatter.format(date)),
                          onTap: () => _openDate(context, date),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _RaiPlaySoundDateItemsScreen extends StatelessWidget {
  const _RaiPlaySoundDateItemsScreen({
    required this.items,
    required this.onOpenItem,
  });

  final List<RaiPlaySoundItem> items;
  final void Function(RaiPlaySoundItem item) onOpenItem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final flutterRows = <Widget>[
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          label: Text(l10n.back),
        ),
      ),
    ];
    final accessibleRows = <AccessibleListRow>[
      AccessibleListRow(
        id: 'back',
        title: l10n.back,
        kind: 'button',
        flutterChild: flutterRows.first,
      ),
    ];

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final title = titleWithListTimestamp(
        item.title,
        item.publishedAt,
        l10n.localeName,
      );
      final subtitle = item.description.isNotEmpty ? item.description : null;
      final child = Card(
        child: ListTile(
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          onTap: () => onOpenItem(item),
        ),
      );
      flutterRows.add(child);
      accessibleRows.add(
        AccessibleListRow(
          id: 'item_$index',
          title: title,
          subtitle: subtitle,
          flutterChild: child,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                sections: [AccessibleListSection(rows: accessibleRows)],
                onEvent: (event) {
                  if (event.type != 'activate' || event.id == null) return;
                  if (event.id == 'back') {
                    Navigator.pop(context);
                  } else if (event.id!.startsWith('item_')) {
                    final index = int.tryParse(event.id!.substring(5));
                    if (index != null && index >= 0 && index < items.length) {
                      onOpenItem(items[index]);
                    }
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

