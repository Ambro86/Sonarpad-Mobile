import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/podcast_service.dart';
import 'podcast_episode_player_screen.dart';

/// Schermata che mostra gli episodi di un singolo podcast iscritto.
class PodcastEpisodesScreen extends StatefulWidget {
  const PodcastEpisodesScreen({super.key, required this.subscription});

  final PodcastSubscription subscription;

  @override
  State<PodcastEpisodesScreen> createState() => _PodcastEpisodesScreenState();
}

class _PodcastEpisodesScreenState extends State<PodcastEpisodesScreen> {
  final _service = PodcastService();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _episodeKeys = {};
  final Map<String, FocusNode> _episodeFocusNodes = {};
  String? _semanticFocusedEpisodeKey;
  late Future<List<PodcastEpisode>> _episodes;
  Set<String> _playedAudioUrls = {};

  @override
  void initState() {
    super.initState();
    _episodes = _service.fetchEpisodes(widget.subscription);
    _loadPlayedEpisodes();
  }

  @override
  void dispose() {
    for (final node in _episodeFocusNodes.values) {
      node.dispose();
    }
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
        builder: (_) => _PlayedEpisodesScreen(
          subscription: widget.subscription,
        ),
      ),
    ).then((_) => _loadPlayedEpisodes());
  }

  Future<void> _openEpisode(PodcastEpisode episode) async {
    await _service.markEpisodeAsPlayed(widget.subscription.feedUrl, episode);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/player'),
        builder: (_) => PodcastEpisodePlayerScreen(episode: episode),
      ),
    );
    _loadPlayedEpisodes();
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

    final hasDateButton = _hasDatedEpisodes(visibleEpisodes);
    final listIndex = episodeIndex +
        (_playedAudioUrls.isNotEmpty ? 1 : 0) +
        (hasDateButton ? 1 : 0);

    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final targetOffset = (listIndex * 96.0)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    _scheduleEpisodeFocusRestore(selectedEpisode);
  }

  bool _hasDatedEpisodes(List<PodcastEpisode> episodes) =>
      episodes.any((episode) => episode.publishedAt != null);

  String _episodeKey(PodcastEpisode episode) =>
      episode.id ?? episode.audioUrl;

  GlobalKey _keyForEpisode(PodcastEpisode episode) =>
      _episodeKeys.putIfAbsent(_episodeKey(episode), () => GlobalKey());

  FocusNode _focusNodeForEpisode(PodcastEpisode episode) =>
      _episodeFocusNodes.putIfAbsent(
        _episodeKey(episode),
        () => FocusNode(debugLabel: 'podcast_episode_${_episodeKey(episode)}'),
      );

  void _scheduleEpisodeFocusRestore(PodcastEpisode episode, {int attempt = 0}) {
    final targetKey = _episodeKey(episode);
    final semanticsView = View.of(context);
    final textDirection = Directionality.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;

      final itemContext = _episodeKeys[targetKey]?.currentContext;
      if (itemContext == null) {
        if (attempt < 8) {
          _scheduleEpisodeFocusRestore(episode, attempt: attempt + 1);
        }
        return;
      }

      setState(() => _semanticFocusedEpisodeKey = targetKey);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      if (itemContext.mounted) {
        await Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.1,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;

      final focusNode = _episodeFocusNodes[targetKey];
      if (focusNode != null && focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
      SemanticsService.sendAnnouncement(
        semanticsView,
        episode.title,
        textDirection,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.subscription.title)),
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
              return Center(child: Text(l10n.error(snapshot.error!)));
            }
            final allEpisodes = snapshot.data ?? const [];
            final unplayedEpisodes = allEpisodes
                .where((e) => !_playedAudioUrls.contains(e.audioUrl))
                .toList();
            final hasDateButton = _hasDatedEpisodes(unplayedEpisodes);
            final itemCount = unplayedEpisodes.length +
                (_playedAudioUrls.isNotEmpty ? 1 : 0) +
                (hasDateButton ? 1 : 0);

            if (itemCount == 0) {
              return Center(child: Text(l10n.noAudioEpisodesFound));
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: itemCount,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  var currentIndex = index;

                  if (_playedAudioUrls.isNotEmpty && currentIndex == 0) {
                    return Card(
                      child: ListTile(
                        key: const ValueKey('podcast_played_episodes'),
                        leading: const Icon(Icons.history),
                        title: Text(l10n.podcastPlayedEpisodes),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openPlayedEpisodes,
                      ),
                    );
                  }

                  if (_playedAudioUrls.isNotEmpty) {
                    currentIndex -= 1;
                  }

                  if (hasDateButton && currentIndex == 0) {
                    return Card(
                      child: ListTile(
                        key: const ValueKey('podcast_select_date'),
                        leading: const Icon(Icons.event),
                        title: Text(l10n.podcastSelectDate),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openDateSelector(unplayedEpisodes),
                      ),
                    );
                  }

                  if (hasDateButton) {
                    currentIndex -= 1;
                  }

                  final episode = unplayedEpisodes[currentIndex];

                  final episodeKey = _episodeKey(episode);
                  return Semantics(
                    focused: _semanticFocusedEpisodeKey == episodeKey,
                    child: Focus(
                      focusNode: _focusNodeForEpisode(episode),
                      child: Card(
                        key: _keyForEpisode(episode),
                        child: ListTile(
                          key: ValueKey('podcast_episode_tile_${episode.id ?? episode.audioUrl}'),
                          title: Text(episode.title),
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
      final dateKey = '${localDate.year.toString().padLeft(4, '0')}-'
          '${localDate.month.toString().padLeft(2, '0')}-'
          '${localDate.day.toString().padLeft(2, '0')}';
      if (seenDates.add(dateKey)) {
        dateEpisodes.add(_PodcastDateEpisode(localDate, episode));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.podcastSelectDate)),
      body: SafeArea(
        child: dateEpisodes.isEmpty
            ? Center(child: Text(l10n.podcastNoDatesAvailable))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: dateEpisodes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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

class _PlayedEpisodesScreenState extends State<_PlayedEpisodesScreen> {
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
      appBar: AppBar(
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
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _episodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final episode = _episodes[index];
                    return Card(
                      key: ValueKey('played_podcast_episode_${episode.id}'),
                      child: ListTile(
                        key: ValueKey(
                            'played_podcast_episode_tile_${episode.id}'),
                        title: Text(episode.title),
                        subtitle: Text(
                          episode.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/podcasts/player'),
                            builder: (_) => PodcastEpisodePlayerScreen(episode: episode),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
