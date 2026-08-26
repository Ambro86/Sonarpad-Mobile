import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'radio_player_screen.dart';
import 'radio_screen.dart';
import '../widgets/universal_accessible_view.dart'; // Per RadioTile
import '../utils/status_message.dart';

class RadioSearchResultsScreen extends StatefulWidget {
  final Future<List<RadioStation>> resultsFuture;
  final String query;

  const RadioSearchResultsScreen({
    super.key,
    required this.resultsFuture,
    this.query = '',
  });

  @override
  State<RadioSearchResultsScreen> createState() =>
      _RadioSearchResultsScreenState();
}

class _RadioSearchResultsScreenState extends State<RadioSearchResultsScreen> {
  static const _pageSize = 25;

  final _service = RadioService();
  List<RadioStation> _favorites = [];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _service.loadFavorites();
    if (!mounted) return;
    setState(() => _favorites = favorites);
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
        showStatusMessage(context, exists
            ? l10n.radioFavoriteRemoved(station.name)
            : l10n.radioFavoriteAdded(station.name));
  }

  void _changePage(
    int page,
    int totalPages, {
    bool announce = true,
  }) {
    final nextPage = page.clamp(0, totalPages - 1).toInt();
    if (nextPage == _page) return;
    setState(() => _page = nextPage);
    if (!announce) return;
    final l10n = AppLocalizations.of(context);
    showStatusMessage(
      context,
      l10n.radioPageOf(nextPage + 1, totalPages),
    );
  }

  Widget _buildPageSelector(
    AppLocalizations l10n,
    int currentPage,
    int totalPages,
  ) {
    final pageNumber = currentPage + 1;
    final pageLabel = l10n.radioPageOf(pageNumber, totalPages);
    if (totalPages <= 1) {
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

    final increasedPage = pageNumber < totalPages ? pageNumber + 1 : pageNumber;
    final decreasedPage = pageNumber > 1 ? pageNumber - 1 : pageNumber;
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
                valueLabel: '',
                kind: 'slider',
                sliderValue: pageNumber.toDouble(),
                sliderMin: 1,
                sliderMax: totalPages.toDouble(),
                sliderStep: 1,
                sliderIncreasedValueLabel:
                    l10n.radioPageOf(increasedPage, totalPages),
                sliderDecreasedValueLabel:
                    l10n.radioPageOf(decreasedPage, totalPages),
              ),
            ],
          ),
        ],
        onEvent: (event) {
          if (event.type != 'slider' ||
              event.id != 'radio_page_selector' ||
              event.value is! num) {
            return;
          }
          final requestedPage = (event.value as num).round() - 1;
          _changePage(requestedPage, totalPages, announce: false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.radioSearchResults)),
      body: FutureBuilder<List<RadioStation>>(
        future: widget.resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.radioSearching),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _radioSearchErrorMessage(l10n, snapshot.error),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }
          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.query.trim().isNotEmpty ? l10n.radioNoResultsWithQuery : l10n.radioNoResultsGeneric,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final totalPages = (results.length + _pageSize - 1) ~/ _pageSize;
          final currentPage = _page.clamp(0, totalPages - 1).toInt();
          final start = currentPage * _pageSize;
          final end = start + _pageSize < results.length
              ? start + _pageSize
              : results.length;
          final visibleResults = results.sublist(start, end);
          return Column(
            children: [
              _buildPageSelector(l10n, currentPage, totalPages),
              Expanded(
                child: useSharedAccessibleViewModel
                    ? UniversalAccessibleList(
                        key: ValueKey('shared-radio-results-$currentPage-${visibleResults.length}'),
                        sections: [
                          AccessibleListSection(
                            rows: visibleResults.map((station) {
                              final isFavorite = _favorites.any((item) => item.streamUrl == station.streamUrl);
                              return AccessibleListRow(
                                id: station.streamUrl,
                                title: station.name,
                                subtitle: station.detailsText,
                                accessibilityLabel: station.accessibilityLabel,
                                kind: 'action',
                                actions: [
                                  AccessibleCustomAction(
                                    id: 'favorite',
                                    label: isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                        onEvent: (event) async {
                          final id = event.id;
                          if (id == null) return;
                          final index = visibleResults.indexWhere((e) => e.streamUrl == id);
                          if (index < 0) return;
                          final station = visibleResults[index];
                          if (event.type == 'activate') {
                            await _play(station);
                          } else if (event.type == 'customAction' && event.action == 'favorite') {
                            await _toggleFavorite(station);
                          }
                        },
                      )
                    : ListView.builder(
                  key: PageStorageKey('radio_results_page_$currentPage'),
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleResults.length,
                  itemBuilder: (context, index) {
                    final station = visibleResults[index];
                    final isFavorite = _favorites
                        .any((item) => item.streamUrl == station.streamUrl);
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
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('radio_previous_page'),
                            onPressed: currentPage > 0
                                ? () => _changePage(currentPage - 1, totalPages)
                                : null,
                            icon: const Icon(Icons.navigate_before),
                            label: Text(l10n.radioPreviousPage),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('radio_next_page'),
                            onPressed: currentPage + 1 < totalPages
                                ? () => _changePage(currentPage + 1, totalPages)
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
        },
      ),
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
