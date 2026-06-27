import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/podcast_service.dart';

class PodcastChaptersScreen extends StatelessWidget {
  PodcastChaptersScreen({
    super.key,
    required this.episode,
  });

  final PodcastEpisode episode;
  final PodcastService _service = PodcastService();

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.podcastChapters)),
      body: SafeArea(
        child: FutureBuilder<List<PodcastChapter>>(
          future: _service.fetchEpisodeChapters(episode),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.loading,
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text(l10n.error(snapshot.error!)));
            }
            final chapters = snapshot.data ?? const <PodcastChapter>[];
            if (chapters.isEmpty) {
              return Center(child: Text(l10n.podcastChaptersUnavailable));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: chapters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return Card(
                  child: ListTile(
                    key: ValueKey('podcast_chapter_${chapter.start.inMilliseconds}'),
                    leading: const Icon(Icons.bookmark),
                    title: Text(chapter.title),
                    subtitle: Text(_format(chapter.start)),
                    onTap: () => Navigator.pop(context, chapter.start),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
