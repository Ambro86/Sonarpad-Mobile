import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'radio_player_screen.dart';
import 'radio_screen.dart';
import '../widgets/universal_accessible_view.dart'; // Per RadioTile
import '../utils/status_message.dart';

class RadioSearchResultsScreen extends StatefulWidget {
  final String languageCode;
  final RadioGenreOption genre;
  final String query;
  final bool recordingFeatureUnlocked;

  const RadioSearchResultsScreen({
    super.key,
    required this.languageCode,
    required this.genre,
    this.query = '',
    this.recordingFeatureUnlocked = false,
  });

  @override
  State<RadioSearchResultsScreen> createState() =>
      _RadioSearchResultsScreenState();
}

class _RadioSearchResultsScreenState extends State<RadioSearchResultsScreen> {
  static const _pageSize = 25;

  final _service = RadioService();
  final _resultsAccessibleListController =
      AccessibleListController(debugName: 'radio-results');
  late final RadioSearchSession _searchSession;
  List<RadioStation> _favorites = [];
  RadioSearchPage? _resultPage;
  Object? _searchError;
  bool _loadingPage = true;
  bool _scrollNewPageResultsToTop = false;

  @override
  void initState() {
    super.initState();
    _searchSession = _service.createSearchSession(
      languageCode: widget.languageCode,
      genre: widget.genre,
      query: widget.query,
    );
    _loadFavorites();
    unawaited(_loadPage(0, announce: false));
  }

  Future<void> _loadFavorites() async {
    final favorites = await _service.loadFavorites();
    if (!mounted) return;
    setState(() => _favorites = favorites);
  }

  Future<void> _loadPage(
    int page, {
    bool announce = true,
  }) async {
    if (_loadingPage && _resultPage != null) return;
    final previousPage = _resultPage?.pageIndex;
    setState(() {
      _loadingPage = true;
      _searchError = null;
    });
    try {
      final result = await _searchSession.loadPage(page, pageSize: _pageSize);
      if (!mounted) return;
      if (result.items.isEmpty && page > 0) {
        final current = await _searchSession.loadPage(
          page - 1,
          pageSize: _pageSize,
        );
        if (!mounted) return;
        setState(() {
          _resultPage = current;
          _loadingPage = false;
        });
        return;
      }
      _scrollNewPageResultsToTop =
          previousPage != null && previousPage != result.pageIndex;
      setState(() {
        _resultPage = result;
        _loadingPage = false;
      });
      if (announce) {
        showStatusMessage(
          context,
          AppLocalizations.of(context).radioPageCurrent(result.pageIndex + 1),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e;
        _loadingPage = false;
      });
    }
  }

  Future<void> _play(RadioStation station) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/player'),
        builder: (_) => RadioPlayerScreen(station: station),
      ),
    );
    await _loadFavorites();
    await _restoreResultFocusAfterPlayer(station);
  }

  Future<void> _playAndRecord(RadioStation station) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/player'),
        builder: (_) => RadioPlayerScreen(
          station: station,
          autoStartRecording: true,
        ),
      ),
    );
    await _loadFavorites();
    await _restoreResultFocusAfterPlayer(station);
  }

  Future<void> _restoreResultFocusAfterPlayer(RadioStation station) async {
    if (!mounted || !useSharedAccessibleViewModel) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _resultsAccessibleListController.focusAccessibleRow(
      station.streamUrl,
      mode: AccessibleFocusMode.routeReturnJump,
      animated: false,
    );
  }

  Future<void> _toggleFavorite(RadioStation station) async {
    final l10n = AppLocalizations.of(context);
    final exists =
        _favorites.any((item) => item.streamUrl == station.streamUrl);
    final next = exists
        ? _favorites
            .where((item) => item.streamUrl != station.streamUrl)
            .toList()
        : [..._favorites, station];
    await _service.saveFavorites(next);
    if (!mounted) return;
    setState(() => _favorites = next);
    showStatusMessage(
      context,
      exists
          ? l10n.radioFavoriteRemoved(station.name)
          : l10n.radioFavoriteAdded(station.name),
    );
  }

  Widget _buildPageSelector(
    AppLocalizations l10n,
    RadioSearchPage page,
  ) {
    final pageNumber = page.pageIndex + 1;
    final pageLabel = l10n.radioPageCurrent(pageNumber);
    if (!page.hasPrevious && !page.hasNext) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            pageLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    final increasedPage = page.hasNext ? pageNumber + 1 : pageNumber;
    final decreasedPage = page.hasPrevious ? pageNumber - 1 : pageNumber;
    return SizedBox(
      height: 96,
      child: UniversalAccessibleList(
        key: const ValueKey('radio_page_selector_shared'),
        debugTag: 'radio-page-selector',
        showVerticalScrollIndicator: false,
        sections: [
          AccessibleListSection(
            rows: [
              AccessibleListRow(
                id: 'radio_page_selector',
                title: pageLabel,
                accessibilityLabel: '',
                value: pageLabel,
                valueLabel: pageLabel,
                kind: 'slider',
                sliderValue: pageNumber.toDouble(),
                sliderMin: 1,
                sliderMax:
                    (page.hasNext ? pageNumber + 1 : pageNumber).toDouble(),
                sliderStep: 1,
                sliderIncreasedValueLabel:
                    l10n.radioPageCurrent(increasedPage),
                sliderDecreasedValueLabel:
                    l10n.radioPageCurrent(decreasedPage),
              ),
            ],
          ),
        ],
        onEvent: (event) {
          if (_loadingPage ||
              event.type != 'slider' ||
              event.id != 'radio_page_selector' ||
              event.value is! num) {
            return;
          }
          final requestedPage = (event.value as num).round() - 1;
          if (requestedPage == page.pageIndex) return;
          if (requestedPage > page.pageIndex && !page.hasNext) return;
          if (requestedPage < page.pageIndex && !page.hasPrevious) return;
          unawaited(_loadPage(requestedPage, announce: false));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = _resultPage;
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.radioSearchResults)),
      body: page == null && _loadingPage
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.radioSearching),
                ],
              ),
            )
          : _searchError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _radioSearchErrorMessage(l10n, _searchError),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                )
              : page == null || page.items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.query.trim().isNotEmpty
                              ? l10n.radioNoResultsWithQuery
                              : l10n.radioNoResultsGeneric,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _buildResults(l10n, page),
    );
  }

  Widget _buildResults(AppLocalizations l10n, RadioSearchPage page) {
    final visibleResults = page.items;
    if (_scrollNewPageResultsToTop &&
        useSharedAccessibleViewModel &&
        visibleResults.isNotEmpty) {
      _scrollNewPageResultsToTop = false;
      final firstResultId = visibleResults.first.streamUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _resultsAccessibleListController.scrollTo(
            firstResultId,
            animated: false,
          ),
        );
      });
    }

    return Column(
      children: [
        _buildPageSelector(l10n, page),
        if (_loadingPage) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: useSharedAccessibleViewModel
              ? UniversalAccessibleList(
                  key: const ValueKey('shared-radio-results'),
                  controller: _resultsAccessibleListController,
                  debugTag: 'radio-results',
                  sections: [
                    AccessibleListSection(
                      rows: visibleResults.map((station) {
                        final isFavorite = _favorites.any(
                          (item) => item.streamUrl == station.streamUrl,
                        );
                        return AccessibleListRow(
                          id: station.streamUrl,
                          title: station.name,
                          subtitle: station.detailsText,
                          accessibilityLabel: station.accessibilityLabel,
                          kind: 'action',
                          actions: [
                            AccessibleCustomAction(
                              id: 'favorite',
                              label: isFavorite
                                  ? l10n.radioRemoveFavorite
                                  : l10n.radioAddFavorite,
                            ),
                            if (widget.recordingFeatureUnlocked)
                              AccessibleCustomAction(
                                id: 'play_record',
                                label: l10n.playAndRecord,
                              ),
                          ],
                          visualActions: [
                            if (widget.recordingFeatureUnlocked)
                              AccessibleVisualAction(
                                id: 'play_record',
                                label: l10n.playAndRecord,
                                icon: 'record',
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                  onEvent: (event) async {
                    final id = event.id;
                    if (id == null) return;
                    final index = visibleResults
                        .indexWhere((e) => e.streamUrl == id);
                    if (index < 0) return;
                    final station = visibleResults[index];
                    if (event.type == 'activate') {
                      await _play(station);
                    } else if (event.type == 'customAction' &&
                        event.action == 'favorite') {
                      await _toggleFavorite(station);
                    } else if (event.type == 'customAction' &&
                        event.action == 'play_record' &&
                        widget.recordingFeatureUnlocked) {
                      await _playAndRecord(station);
                    }
                  },
                )
              : ListView.builder(
                  key: PageStorageKey(
                    'radio_results_page_${page.pageIndex}',
                  ),
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleResults.length,
                  itemBuilder: (context, index) {
                    final station = visibleResults[index];
                    final isFavorite = _favorites.any(
                      (item) => item.streamUrl == station.streamUrl,
                    );
                    return Padding(
                      key: ValueKey(
                        'radio_search_result_row_${station.streamUrl}',
                      ),
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: RadioTile(
                        key: ValueKey(
                          'radio_search_result_tile_${station.streamUrl}',
                        ),
                        station: station,
                        isFavorite: isFavorite,
                        isPlaying: false,
                        onPlay: () => _play(station),
                        onToggleFavorite: () => _toggleFavorite(station),
                        extraSemanticsActions: {
                          if (widget.recordingFeatureUnlocked)
                            CustomSemanticsAction(label: l10n.playAndRecord):
                                () => _playAndRecord(station),
                        },
                        extraTrailingActions: [
                          if (widget.recordingFeatureUnlocked)
                            IconButton(
                              key: ValueKey(
                                'radio_search_play_record_${station.streamUrl}',
                              ),
                              tooltip: l10n.playAndRecord,
                              onPressed: () => _playAndRecord(station),
                              icon: const Icon(Icons.fiber_manual_record),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (page.hasPrevious || page.hasNext)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('radio_previous_page'),
                      onPressed: !_loadingPage && page.hasPrevious
                          ? () => _loadPage(page.pageIndex - 1)
                          : null,
                      icon: const Icon(Icons.navigate_before),
                      label: Text(l10n.radioPreviousPage),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('radio_next_page'),
                      onPressed: !_loadingPage && page.hasNext
                          ? () => _loadPage(page.pageIndex + 1)
                          : null,
                      icon: const Icon(Icons.navigate_next),
                      label: Text(l10n.radioNextPage),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _radioSearchErrorMessage(AppLocalizations l10n, Object? error) {
  final raw = error.toString();
  final normalized = raw.toLowerCase();
  final isRadioBrowserConnectionError =
      normalized.contains('failed host lookup') ||
          normalized.contains('socketexception') ||
          normalized.contains('clientexception') ||
          normalized.contains('timeoutexception') ||
          normalized.contains('connection') ||
          normalized.contains('nodename nor servname') ||
          normalized.contains('radio browser non raggiungibile') ||
          normalized.contains('http 502') ||
          normalized.contains('http 503') ||
          normalized.contains('http 504');

  if (isRadioBrowserConnectionError) {
    return l10n.radioBrowserConnectionError;
  }
  return l10n.radioSearchRawError(l10n.technicalErrorGeneric);
}
