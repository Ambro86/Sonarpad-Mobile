import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/podcast_service.dart';
import '../widgets/native_ios_accessible_view.dart';

class PodcastChaptersScreen extends StatelessWidget {
  PodcastChaptersScreen({
    super.key,
    required this.episode,
    this.chapters,
    PodcastService? service,
  }) : _chaptersFuture = chapters == null
            ? (service ?? PodcastService()).fetchEpisodeChapters(episode)
            : Future.value(chapters);

  final PodcastEpisode episode;
  final List<PodcastChapter>? chapters;
  final Future<List<PodcastChapter>> _chaptersFuture;

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
          future: _chaptersFuture,
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
            if (useNativeIosAccessibleViews) {
              return NativeIosAccessibleList(
                sections: [
                  NativeIosListSection(
                    rows: chapters
                        .asMap()
                        .entries
                        .map((entry) => NativeIosListRow(
                              id: 'chapter_${entry.key}',
                              title: entry.value.title,
                              subtitle: _format(entry.value.start),
                            ))
                        .toList(growable: false),
                  ),
                ],
                onEvent: (event) {
                  if (event.type != 'activate' || event.id == null) return;
                  final index = int.tryParse(event.id!.replaceFirst('chapter_', ''));
                  if (index != null && index >= 0 && index < chapters.length) {
                    Navigator.pop(context, chapters[index].start);
                  }
                },
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: chapters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
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
