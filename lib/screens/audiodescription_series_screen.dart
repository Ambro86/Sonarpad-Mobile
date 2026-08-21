import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../l10n/app_localizations.dart';
import '../services/audiodescription_service.dart';
import '../widgets/media_preservation_progress_dialog.dart';
import '../models/podcast.dart';
import 'podcast_episode_player_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class AudiodescriptionSeriesScreen extends StatefulWidget {
  final AudiodescriptionGroup group;

  const AudiodescriptionSeriesScreen({
    super.key,
    required this.group,
  });

  @override
  State<AudiodescriptionSeriesScreen> createState() =>
      _AudiodescriptionSeriesScreenState();
}

class _AudiodescriptionSeriesScreenState
    extends State<AudiodescriptionSeriesScreen> {
  final _service = AudiodescriptionService();
  late List<AudiodescriptionItem> _episodes;

  @override
  void initState() {
    super.initState();
    // Le API di RaiPlay spesso restituiscono le puntate in ordine cronologico inverso
    // (dalla più recente alla più vecchia). Le invertiamo per averle dalla 1 in poi.
    _episodes = widget.group.items.reversed.toList();
  }

  Future<void> _play(AudiodescriptionItem item) async {
    try {
      final resolvedUrl = await _service.resolveAudioUrl(item.audioUrl);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/audiodescriptions/player'),
          builder: (_) => PodcastEpisodePlayerScreen(
            episode: PodcastEpisode(
              title: item.title,
              description: item.description,
              audioUrl: resolvedUrl,
              id: item.audioUrl,
              publishedAt: DateTime.now(),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
                showStatusMessage(context, e.toString());
      }
    }
  }

  Future<void> _preserveMedia(AudiodescriptionItem item) async {
    await preserveMediaWithProgress(
      context,
      title: item.title,
      resolveUrl: () => _service.resolveAudioUrl(item.audioUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.title),
      ),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: _episodes
                      .asMap()
                      .entries
                      .map((entry) => AccessibleListRow(
                            id: 'episode_${entry.key}',
                            title: entry.value.title,
                            subtitle: entry.value.description.isNotEmpty
                                ? entry.value.description
                                : null,
                            actions: [
                              AccessibleCustomAction(
                                id: 'preserve_media',
                                label: l10n.preserveMedia,
                              ),
                            ],
                            visualActionId: 'preserve_media',
                            visualActionIcon: 'download',
                          ))
                      .toList(growable: false),
                ),
              ],
              onEvent: (event) async {
                if (event.id == null) return;
                final index =
                    int.tryParse(event.id!.replaceFirst('episode_', ''));
                if (index == null || index < 0 || index >= _episodes.length) {
                  return;
                }
                if (event.type == 'customAction' &&
                    event.action == 'preserve_media') {
                  await _preserveMedia(_episodes[index]);
                } else if (event.type == 'activate') {
                  await _play(_episodes[index]);
                }
              },
            )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _episodes.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          final item = _episodes[index];
          return Semantics(
            container: true,
            customSemanticsActions: {
              CustomSemanticsAction(label: l10n.preserveMedia): () =>
                  unawaited(_preserveMedia(item)),
            },
            child: ListTile(
              title: Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  item.description.isNotEmpty ? Text(item.description) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow),
                  ExcludeSemantics(
                    child: IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: l10n.preserveMedia,
                      onPressed: () => unawaited(_preserveMedia(item)),
                    ),
                  ),
                ],
              ),
              onTap: () => _play(item),
            ),
          );
        },
      ),
    );
  }
}
