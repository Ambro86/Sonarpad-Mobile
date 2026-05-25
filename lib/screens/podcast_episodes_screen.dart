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

  @override
  void initState() {
    super.initState();
    _episodes = _service.fetchEpisodes(widget.subscription);
  }

  Future<void> _refresh() async {
    final refreshed = _service.fetchEpisodes(widget.subscription);
    setState(() => _episodes = refreshed);
    await refreshed;
  }

  void _openEpisode(PodcastEpisode episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/player'),
        builder: (_) => PodcastEpisodePlayerScreen(episode: episode),
      ),
    );
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
            final episodes = snapshot.data ?? const [];
            if (episodes.isEmpty) {
              return Center(child: Text(l10n.noAudioEpisodesFound));
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: episodes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final episode = episodes[index];
                  return Card(
                    child: ListTile(
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
