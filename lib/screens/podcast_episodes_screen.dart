import 'dart:async';
import 'package:flutter/semantics.dart';
import '../services/recording_feature_access.dart';
import '../widgets/media_preservation_progress_dialog.dart';
import '../models/media_playback_speed.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/podcast_service.dart';
import '../utils/app_logger.dart';
import '../utils/list_timestamp_formatter.dart';
import '../utils/media_open_guard.dart';
import 'podcast_episode_player_screen.dart';
import '../widgets/universal_accessible_view.dart';

mixin _PodcastPreservation<T extends StatefulWidget> on State<T> {
  bool _canPreserve = false;

  @override
  void initState() {
    super.initState();
    _loadPreservationAccess();
  }

  Future<void> _loadPreservationAccess() async {
    final unlocked = await RecordingFeatureAccess.isUnlocked();
    if (mounted) setState(() => _canPreserve = unlocked);
  }

  Future<void> _preserveEpisode(PodcastEpisode episode) async {
    if (!await RecordingFeatureAccess.isUnlocked() || !mounted) return;
    final path = Uri.tryParse(episode.audioUrl)?.path.toLowerCase() ?? '';
    final extension =
        RegExp(
          r'\.(mp3|m4a|mp4|aac|ogg|opus|wav|flac)$',
        ).firstMatch(path)?.group(1) ??
        'mp3';
    await preserveMediaWithProgress(
      context,
      title: episode.title,
      fileName: '${episode.title}.$extension',
      resolveUrl: () async => episode.audioUrl,
    );
  }

  List<AccessibleCustomAction> _preservationActions(AppLocalizations l10n) => [
    if (_canPreserve)
      AccessibleCustomAction(id: 'preserve_media', label: l10n.preserveMedia),
  ];

  Widget _episodeTile(PodcastEpisode episode, ListTile tile) {
    if (!_canPreserve) return tile;
    final label = AppLocalizations.of(context).preserveMedia;
    return Semantics(
      container: true,
      customSemanticsActions: {
        CustomSemanticsAction(label: label): () =>
            unawaited(_preserveEpisode(episode)),
      },
      child: Row(
        children: [
          Expanded(child: tile),
          ExcludeSemantics(
            child: IconButton(
              tooltip: label,
              icon: const Icon(Icons.download),
              onPressed: () => unawaited(_preserveEpisode(episode)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Schermata che mostra gli episodi di un singolo podcast iscritto.
class PodcastEpisodesScreen extends StatefulWidget {
  const PodcastEpisodesScreen({super.key, required this.subscription});

  final PodcastSubscription subscription;

  @override
  State<PodcastEpisodesScreen> createState() => _PodcastEpisodesScreenState();
}

class _PodcastEpisodesScreenState extends State<PodcastEpisodesScreen>
    with _PodcastPreservation<PodcastEpisodesScreen> {
  final _service = PodcastService();
  final _scrollController = AutoScrollController();
  final AccessibleListController _accessibleListController =
      AccessibleListController(debugName: 'podcast_episodes');
  late Future<List<PodcastEpisode>> _episodes;
  Set<String> _playedAudioUrls = {};
  final MediaOpenGuard _mediaOpenGuard = MediaOpenGuard();

  @override
  void initState() {
    super.initState();
    _episodes = _service.fetchEpisodes(widget.subscription);
    _loadPlayedEpisodes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayedEpisodes() async {
    final list = await _service.getPlayedEpisodes(widget.subscription.feedUrl);
    if (!mounted) return;
    setState(() {
      _playedAudioUrls = list.map((e) => e.audioUrl).toSet();
    });
  }

  Future<void> _refresh() async {
    final refreshed = _service.fetchEpisodes(widget.subscription);
    setState(() => _episodes = refreshed);
    await refreshed;
    await _loadPlayedEpisodes();
  }

  void _openPlayedEpisodes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PlayedEpisodesScreen(subscription: widget.subscription),
      ),
    ).then((_) => _loadPlayedEpisodes());
  }

  Future<void> _openEpisode(PodcastEpisode episode) async {
    final itemKey = episode.id ?? episode.audioUrl;
    if (!_mediaOpenGuard.tryAcquire(itemKey)) {
      await AppLogger.log(
        'MEDIA_OPEN_GUARD duplicate ignored source=podcast '
        'active=${_mediaOpenGuard.activeKey} requested=$itemKey',
      );
      return;
    }

    try {
      await _service.markEpisodeAsPlayed(widget.subscription.feedUrl, episode);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/podcasts/player'),
          builder: (_) => PodcastEpisodePlayerScreen(
            speedCategory: MediaPlaybackSpeedCategory.podcasts,
            episode: episode,
          ),
        ),
      );
      _loadPlayedEpisodes();
    } finally {
      _mediaOpenGuard.release(itemKey);
    }
  }

  Future<void> _openDateSelector(List<PodcastEpisode> episodes) async {
    final selectedEpisode = await Navigator.push<PodcastEpisode>(
      context,
      MaterialPageRoute(
        builder: (_) => _PodcastDateSelectorScreen(episodes: episodes),
      ),
    );
    if (selectedEpisode == null || !mounted) return;

    final visibleEpisodes = episodes
        .where((e) => !_playedAudioUrls.contains(e.audioUrl))
        .toList();
    final episodeIndex = visibleEpisodes.indexWhere(
      (e) => e.audioUrl == selectedEpisode.audioUrl,
    );
    if (episodeIndex < 0) return;

    if (useSharedAccessibleViewModel) {
      await _accessibleListController.focusAccessibleRow(
        selectedEpisode.id ?? selectedEpisode.audioUrl,
        mode: AccessibleFocusMode.routeReturnJump,
      );
      return;
    }

    final hasDateButton = _hasDatedEpisodes(visibleEpisodes);
    final listIndex =
        episodeIndex +
        (_playedAudioUrls.isNotEmpty ? 1 : 0) +
        (hasDateButton ? 1 : 0);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _tryScrollToEpisodeIndex(listIndex);
  }

  Future<void> _tryScrollToEpisodeIndex(
    int listIndex, {
    int attempt = 0,
  }) async {
    if (!mounted) return;

    if (!_scrollController.hasClients) {
      if (attempt < 3) {
        Future<void>.delayed(
          Duration(milliseconds: 250 + (attempt * 150)),
          () => _tryScrollToEpisodeIndex(listIndex, attempt: attempt + 1),
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

      // Dopo il ritorno dal selettore data, su iOS/VoiceOver a volte
      // l'albero semantico resta agganciato alla AppBar. Un secondo scroll
      // leggero stabilizza il posizionamento senza forzare il focus.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.scrollToIndex(
        listIndex,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 120),
      );
    } catch (_) {
      if (!mounted) return;
      if (attempt < 3) {
        Future<void>.delayed(
          Duration(milliseconds: 300 + (attempt * 200)),
          () => _tryScrollToEpisodeIndex(listIndex, attempt: attempt + 1),
        );
      }
    }
  }

  bool _hasDatedEpisodes(List<PodcastEpisode> episodes) =>
      episodes.any((episode) => episode.publishedAt != null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(widget.subscription.title)),
      body: SafeArea(
        child: FutureBuilder<List<PodcastEpisode>>(
          future: _episodes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.loadingEpisodes,
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(l10n.error(l10n.technicalErrorGeneric)),
              );
            }
            final allEpisodes = snapshot.data ?? const [];
            final unplayedEpisodes = allEpisodes
                .where((e) => !_playedAudioUrls.contains(e.audioUrl))
                .toList();
            final hasDateButton = _hasDatedEpisodes(unplayedEpisodes);
            final itemCount =
                unplayedEpisodes.length +
                (_playedAudioUrls.isNotEmpty ? 1 : 0) +
                (hasDateButton ? 1 : 0);

            if (itemCount == 0) {
              return Center(child: Text(l10n.noAudioEpisodesFound));
            }
            if (useSharedAccessibleViewModel) {
              final rows = <AccessibleListRow>[
                if (_playedAudioUrls.isNotEmpty)
                  AccessibleListRow(
                    id: '__played__',
                    title: l10n.podcastPlayedEpisodes,
                    kind: 'action',
                  ),
                if (hasDateButton)
                  AccessibleListRow(
                    id: '__date__',
                    title: l10n.podcastSelectDate,
                    kind: 'action',
                  ),
                ...unplayedEpisodes.map(
                  (episode) => AccessibleListRow(
                    id: episode.id ?? episode.audioUrl,
                    title: titleWithListTimestamp(
                      episode.title,
                      episode.publishedAt,
                      l10n.localeName,
                    ),
                    subtitle: episode.description,
                    actions: _preservationActions(l10n),
                    visualActionId: _canPreserve ? 'preserve_media' : null,
                    visualActionIcon: _canPreserve ? 'download' : null,
                    kind: 'action',
                  ),
                ),
              ];
              return UniversalAccessibleList(
                key: ValueKey(
                  'shared-podcast-episodes-${widget.subscription.feedUrl}-${rows.length}',
                ),
                controller: _accessibleListController,
                refreshEnabled: true,
                sections: [AccessibleListSection(rows: rows)],
                onEvent: (event) async {
                  if (event.type == 'refresh') {
                    await _refresh();
                    return;
                  }
                  if ((event.type != 'activate' &&
                          event.type != 'customAction') ||
                      event.id == null) {
                    return;
                  }
                  if (event.id == '__played__') {
                    _openPlayedEpisodes();
                    return;
                  }
                  if (event.id == '__date__') {
                    await _openDateSelector(unplayedEpisodes);
                    return;
                  }
                  final index = unplayedEpisodes.indexWhere(
                    (episode) => (episode.id ?? episode.audioUrl) == event.id,
                  );
                  if (index < 0) return;
                  if (event.type == 'customAction') {
                    if (event.action == 'preserve_media') {
                      await _preserveEpisode(unplayedEpisodes[index]);
                    }
                  } else {
                    await _openEpisode(unplayedEpisodes[index]);
                  }
                },
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: itemCount,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  var currentIndex = index;

                  if (_playedAudioUrls.isNotEmpty && currentIndex == 0) {
                    return AutoScrollTag(
                      key: const ValueKey('podcast_played_episodes_scroll'),
                      controller: _scrollController,
                      index: index,
                      child: Card(
                        child: ListTile(
                          key: const ValueKey('podcast_played_episodes'),
                          leading: const Icon(Icons.history),
                          title: Text(l10n.podcastPlayedEpisodes),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openPlayedEpisodes,
                        ),
                      ),
                    );
                  }

                  if (_playedAudioUrls.isNotEmpty) {
                    currentIndex -= 1;
                  }

                  if (hasDateButton && currentIndex == 0) {
                    return AutoScrollTag(
                      key: const ValueKey('podcast_select_date_scroll'),
                      controller: _scrollController,
                      index: index,
                      child: Card(
                        child: ListTile(
                          key: const ValueKey('podcast_select_date'),
                          leading: const Icon(Icons.event),
                          title: Text(l10n.podcastSelectDate),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDateSelector(unplayedEpisodes),
                        ),
                      ),
                    );
                  }

                  if (hasDateButton) {
                    currentIndex -= 1;
                  }

                  final episode = unplayedEpisodes[currentIndex];

                  return AutoScrollTag(
                    key: ValueKey('podcast_episode_scroll_$index'),
                    controller: _scrollController,
                    index: index,
                    child: Card(
                      child: _episodeTile(
                        episode,
                        ListTile(
                          key: ValueKey(
                            'podcast_episode_tile_${episode.id ?? episode.audioUrl}',
                          ),
                          title: Text(
                            titleWithListTimestamp(
                              episode.title,
                              episode.publishedAt,
                              l10n.localeName,
                            ),
                          ),
                          subtitle: Text(
                            episode.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openEpisode(episode),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PodcastDateSelectorScreen extends StatelessWidget {
  const _PodcastDateSelectorScreen({required this.episodes});

  final List<PodcastEpisode> episodes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = DateFormat.yMMMMd(l10n.localeName);
    final dateEpisodes = <_PodcastDateEpisode>[];
    final seenDates = <String>{};

    for (final episode in episodes) {
      final publishedAt = episode.publishedAt;
      if (publishedAt == null) continue;
      final localDate = publishedAt.toLocal();
      final dateKey =
          '${localDate.year.toString().padLeft(4, '0')}-'
          '${localDate.month.toString().padLeft(2, '0')}-'
          '${localDate.day.toString().padLeft(2, '0')}';
      if (seenDates.add(dateKey)) {
        dateEpisodes.add(_PodcastDateEpisode(localDate, episode));
      }
    }

    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.podcastSelectDate)),
      body: SafeArea(
        child: dateEpisodes.isEmpty
            ? Center(child: Text(l10n.podcastNoDatesAvailable))
            : useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                sections: [
                  AccessibleListSection(
                    rows: dateEpisodes
                        .asMap()
                        .entries
                        .map(
                          (entry) => AccessibleListRow(
                            id: entry.key.toString(),
                            title: formatter.format(entry.value.date),
                            kind: 'action',
                          ),
                        )
                        .toList(),
                  ),
                ],
                onEvent: (event) {
                  if (event.type != 'activate' || event.id == null) return;
                  final index = int.tryParse(event.id!);
                  if (index != null &&
                      index >= 0 &&
                      index < dateEpisodes.length) {
                    Navigator.pop(context, dateEpisodes[index].episode);
                  }
                },
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: dateEpisodes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = dateEpisodes[index];
                  return Card(
                    child: ListTile(
                      title: Text(formatter.format(item.date)),
                      onTap: () => Navigator.pop(context, item.episode),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PodcastDateEpisode {
  const _PodcastDateEpisode(this.date, this.episode);

  final DateTime date;
  final PodcastEpisode episode;
}

class _PlayedEpisodesScreen extends StatefulWidget {
  final PodcastSubscription subscription;

  const _PlayedEpisodesScreen({required this.subscription});

  @override
  State<_PlayedEpisodesScreen> createState() => _PlayedEpisodesScreenState();
}

class _PlayedEpisodesScreenState extends State<_PlayedEpisodesScreen>
    with _PodcastPreservation<_PlayedEpisodesScreen> {
  final _service = PodcastService();
  List<PodcastEpisode> _episodes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.getPlayedEpisodes(widget.subscription.feedUrl);
    if (!mounted) return;
    setState(() {
      _episodes = list;
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.confirmClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearHistory),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _service.clearPlayedEpisodes(widget.subscription.feedUrl);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SonarpadAppBar(
        title: Text(l10n.podcastPlayedEpisodes),
        actions: [
          if (_episodes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: l10n.clearHistory,
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _episodes.isEmpty
          ? Center(child: Text(l10n.noAudioEpisodesFound))
          : useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              key: ValueKey('shared-played-podcast-${_episodes.length}'),
              sections: [
                AccessibleListSection(
                  rows: _episodes.asMap().entries.map((entry) {
                    final episode = entry.value;
                    return AccessibleListRow(
                      id: entry.key.toString(),
                      title: titleWithListTimestamp(
                        episode.title,
                        episode.publishedAt,
                        l10n.localeName,
                      ),
                      subtitle: episode.description,
                      actions: _preservationActions(l10n),
                      visualActionId: _canPreserve ? 'preserve_media' : null,
                      visualActionIcon: _canPreserve ? 'download' : null,
                      kind: 'action',
                    );
                  }).toList(),
                ),
              ],
              onEvent: (event) async {
                if ((event.type != 'activate' &&
                        event.type != 'customAction') ||
                    event.id == null) {
                  return;
                }
                final index = int.tryParse(event.id!);
                if (index == null || index < 0 || index >= _episodes.length) {
                  return;
                }
                if (event.type == 'customAction') {
                  if (event.action == 'preserve_media') {
                    await _preserveEpisode(_episodes[index]);
                  }
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/podcasts/player'),
                    builder: (_) => PodcastEpisodePlayerScreen(
                      speedCategory: MediaPlaybackSpeedCategory.podcasts,
                      episode: _episodes[index],
                    ),
                  ),
                );
              },
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _episodes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final episode = _episodes[index];
                return Card(
                  key: ValueKey('played_podcast_episode_${episode.id}'),
                  child: _episodeTile(
                    episode,
                    ListTile(
                      key: ValueKey(
                        'played_podcast_episode_tile_${episode.id}',
                      ),
                      title: Text(
                        titleWithListTimestamp(
                          episode.title,
                          episode.publishedAt,
                          l10n.localeName,
                        ),
                      ),
                      subtitle: Text(
                        episode.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(
                            name: '/podcasts/player',
                          ),
                          builder: (_) => PodcastEpisodePlayerScreen(
                            speedCategory: MediaPlaybackSpeedCategory.podcasts,
                            episode: episode,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
