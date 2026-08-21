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

class AudiodescriptionFilmScreen extends StatefulWidget {
  final AudiodescriptionGroup filmGroup;

  const AudiodescriptionFilmScreen({super.key, required this.filmGroup});

  @override
  State<AudiodescriptionFilmScreen> createState() =>
      _AudiodescriptionFilmScreenState();
}

class _AudiodescriptionFilmScreenState
    extends State<AudiodescriptionFilmScreen> {
  final _service = AudiodescriptionService();

  late List<AudiodescriptionItem> _sortedItems;
  List<AudiodescriptionItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _sortedItems = List.of(widget.filmGroup.items)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _filteredItems = _sortedItems;
  }

  void _onSearch(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredItems = _sortedItems;
      } else {
        final q = query.trim().toLowerCase();
        _filteredItems = _sortedItems
            .where((i) => i.title.toLowerCase().contains(q))
            .toList();
      }
    });
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
        title: Text(l10n.audiodescriptionFilm),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.audiodescriptionSearch,
                filled: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _onSearch,
            ),
          ),
        ),
      ),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: _filteredItems
                      .asMap()
                      .entries
                      .map((entry) => AccessibleListRow(
                            id: 'film_${entry.key}',
                            title: entry.value.title,
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
                final index = int.tryParse(event.id!.replaceFirst('film_', ''));
                if (index == null ||
                    index < 0 ||
                    index >= _filteredItems.length) {
                  return;
                }
                if (event.type == 'customAction' &&
                    event.action == 'preserve_media') {
                  await _preserveMedia(_filteredItems[index]);
                } else if (event.type == 'activate') {
                  await _play(_filteredItems[index]);
                }
              },
            )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredItems.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          return Semantics(
            container: true,
            customSemanticsActions: {
              CustomSemanticsAction(label: l10n.preserveMedia): () =>
                  unawaited(_preserveMedia(item)),
            },
            child: ListTile(
              title: Text(item.title),
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
