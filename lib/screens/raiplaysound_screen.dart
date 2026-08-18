import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/podcast_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/recent_searches_service.dart';
import '../utils/list_timestamp_formatter.dart';
import 'podcast_episode_player_screen.dart';
import 'recent_searches_screen.dart';
import '../utils/status_message.dart';
import '../widgets/native_ios_accessible_view.dart';

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
  final NativeIosListController _nativeListController = NativeIosListController();

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

  bool _hasDatedAudioItems(List<RaiPlaySoundItem> items) => items.any(
        (item) =>
            item.kind == RaiPlaySoundItemKind.audio && item.publishedAt != null,
      );

  Future<void> _openDateSelector(List<RaiPlaySoundItem> items) async {
    final selectedItem = await Navigator.push<RaiPlaySoundItem>(
      context,
      MaterialPageRoute(
        builder: (_) => _RaiPlaySoundDateSelectorScreen(items: items),
      ),
    );
    if (selectedItem == null || !mounted) return;

    final itemIndex = items.indexWhere((item) => item.id == selectedItem.id);
    if (itemIndex < 0) return;
    if (useNativeIosAccessibleViews) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _nativeListController.scrollTo('item_$itemIndex');
      return;
    }

    final listIndex = itemIndex + (_hasDatedAudioItems(items) ? 1 : 0);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _tryScrollToItemIndex(listIndex);
  }

  Future<void> _tryScrollToItemIndex(int listIndex, {int attempt = 0}) async {
    if (!mounted) return;
    if (!_scrollController.hasClients) {
      if (attempt < 3) {
        Future<void>.delayed(
          Duration(milliseconds: 250 + (attempt * 150)),
          () => _tryScrollToItemIndex(listIndex, attempt: attempt + 1),
        );
      }
      return;
    }

    try {
      await _scrollController.scrollToIndex(
        listIndex,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 300),
      );
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.scrollToIndex(
        listIndex,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 120),
      );
    } catch (_) {
      if (attempt < 3) {
        Future<void>.delayed(
          Duration(milliseconds: 300 + (attempt * 200)),
          () => _tryScrollToItemIndex(listIndex, attempt: attempt + 1),
        );
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

  Widget _buildNativeIosBody(AppLocalizations l10n, List<RaiPlaySoundItem> items, bool hasDateButton) {
    return NativeIosAccessibleList(
      controller: _nativeListController,
      sections: [
        NativeIosListSection(rows: [
          if (_isRoot)
            NativeIosListRow(id: 'search_query', title: 'Cerca su RaiPlay Sound', kind: 'textField', value: _searchController.text),
          if (_isRoot) const NativeIosListRow(id: 'search', title: 'Cerca', kind: 'button'),
          if (_isRoot) const NativeIosListRow(id: 'recent', title: 'Ricerche recenti'),
          if (_error != null) NativeIosListRow(id: 'error', kind: 'text', title: _error!),
          if (hasDateButton) NativeIosListRow(id: 'select_date', title: l10n.podcastSelectDate),
          for (var i = 0; i < items.length; i++)
            NativeIosListRow(
              id: 'item_$i',
              title: items[i].kind == RaiPlaySoundItemKind.audio
                  ? titleWithListTimestamp(items[i].title, items[i].publishedAt, l10n.localeName)
                  : items[i].title,
              subtitle: items[i].description.isNotEmpty ? items[i].description : null,
              actions: [
                if (items[i].kind == RaiPlaySoundItemKind.audio && _canSubscribeCurrentPage)
                  const NativeIosCustomAction(id: 'subscribe', label: 'Aggiungi ai podcast'),
              ],
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
          if (event.type == 'customAction' && event.action == 'subscribe') {
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
              : useNativeIosAccessibleViews
                  ? _buildNativeIosBody(l10n, items, hasDateButton)
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
  const _RaiPlaySoundDateSelectorScreen({required this.items});

  final List<RaiPlaySoundItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = DateFormat.yMMMMd(l10n.localeName);
    final datedItems = <_RaiPlaySoundDatedItem>[];
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
        datedItems.add(_RaiPlaySoundDatedItem(localDate, item));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.podcastSelectDate)),
      body: SafeArea(
        child: datedItems.isEmpty
            ? Center(child: Text(l10n.podcastNoDatesAvailable))
            : useNativeIosAccessibleViews
                ? NativeIosAccessibleList(
                    sections: [NativeIosListSection(rows: [
                      for (var i = 0; i < datedItems.length; i++)
                        NativeIosListRow(id: 'date_$i', title: formatter.format(datedItems[i].date)),
                    ])],
                    onEvent: (event) {
                      if (event.type != 'activate' || event.id == null) return;
                      final i = int.tryParse(event.id!.replaceFirst('date_', ''));
                      if (i != null && i < datedItems.length) Navigator.pop(context, datedItems[i].item);
                    },
                  )
                : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: datedItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final datedItem = datedItems[index];
                  return Card(
                    child: ListTile(
                      title: Text(formatter.format(datedItem.date)),
                      onTap: () => Navigator.pop(context, datedItem.item),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _RaiPlaySoundDatedItem {
  const _RaiPlaySoundDatedItem(this.date, this.item);

  final DateTime date;
  final RaiPlaySoundItem item;
}
