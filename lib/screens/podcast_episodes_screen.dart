import 'package:flutter/material.dart';

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
  late Future<List<PodcastEpisode>> _episodes;
  Set<String> _playedAudioUrls = {};

  @override
  void initState() {
    super.initState();
    _episodes = _service.fetchEpisodes(widget.subscription);
    _loadPlayedEpisodes();
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
            
            final itemCount = unplayedEpisodes.length + (_playedAudioUrls.isNotEmpty ? 1 : 0);

            if (itemCount == 0) {
              return Center(child: Text(l10n.noAudioEpisodesFound));
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: itemCount,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (_playedAudioUrls.isNotEmpty && index == 0) {
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
                  
                  final epIndex = _playedAudioUrls.isNotEmpty ? index - 1 : index;
                  final episode = unplayedEpisodes[epIndex];
                  
                  return Card(
                    key: ValueKey('podcast_episode_${episode.id}'),
                    child: ListTile(
                      key: ValueKey('podcast_episode_tile_${episode.id}'),
                      title: Text(episode.title),
                      subtitle: Text(
                        episode.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _openEpisode(episode),
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
