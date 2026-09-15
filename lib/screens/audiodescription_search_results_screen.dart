import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/audiodescription_service.dart';
import '../utils/status_message.dart';
import '../widgets/media_preservation_progress_dialog.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';

class AudiodescriptionSearchResultsScreen extends StatefulWidget {
  final String query;

  const AudiodescriptionSearchResultsScreen({
    super.key,
    required this.query,
  });

  @override
  State<AudiodescriptionSearchResultsScreen> createState() =>
      _AudiodescriptionSearchResultsScreenState();
}

class _AudiodescriptionSearchResultsScreenState
    extends State<AudiodescriptionSearchResultsScreen> {
  final _service = AudiodescriptionService();

  List<AudiodescriptionItem> _results = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final code = await AppSettingsService().getTvSecretCode();
      final groups = await _service.fetchGroupedCatalog(code);
      final query = widget.query.trim().toLowerCase();

      final results = <AudiodescriptionItem>[];
      final seen = <String>{};

      for (final group in groups) {
        final groupMatches = group.title.toLowerCase().contains(query);
        for (final item in group.items) {
          final matches = groupMatches ||
              item.title.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query);
          if (!matches) continue;

          // Evita eventuali duplicati presenti in più sezioni del catalogo.
          final key = '${item.audioUrl}\u0000${item.title}';
          if (seen.add(key)) {
            results.add(item);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
        title: Text(l10n.audiodescriptionSearch),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.audiodescriptionLoading),
                ],
              ),
            )
          : _error.isNotEmpty
              ? Center(child: Text(l10n.audiodescriptionError))
              : _results.isEmpty
                  ? Center(child: Text(l10n.audiodescriptionEmpty))
                  : useSharedAccessibleViewModel
                      ? UniversalAccessibleList(
                          sections: [
                            AccessibleListSection(
                              rows: _results
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => AccessibleListRow(
                                      id: 'item_${entry.key}',
                                      title: entry.value.title,
                                      subtitle:
                                          '${entry.value.date} ${entry.value.description}'
                                              .trim(),
                                      actions: [
                                        AccessibleCustomAction(
                                          id: 'preserve_media',
                                          label: l10n.preserveMedia,
                                        ),
                                      ],
                                      visualActionId: 'preserve_media',
                                      visualActionIcon: 'download',
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          onEvent: (event) async {
                            if (event.id == null ||
                                !event.id!.startsWith('item_')) {
                              return;
                            }
                            final index =
                                int.tryParse(event.id!.substring(5));
                            if (index == null ||
                                index < 0 ||
                                index >= _results.length) {
                              return;
                            }
                            final item = _results[index];
                            if (event.type == 'customAction' &&
                                event.action == 'preserve_media') {
                              await _preserveMedia(item);
                            } else if (event.type == 'activate') {
                              await _play(item);
                            }
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            return Semantics(
                              container: true,
                              customSemanticsActions: {
                                CustomSemanticsAction(
                                  label: l10n.preserveMedia,
                                ): () => unawaited(_preserveMedia(item)),
                              },
                              child: ListTile(
                                title: Text(item.title),
                                subtitle: Text(
                                  '${item.date} ${item.description}'.trim(),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_arrow),
                                    ExcludeSemantics(
                                      child: IconButton(
                                        icon: const Icon(Icons.download),
                                        tooltip: l10n.preserveMedia,
                                        onPressed: () =>
                                            unawaited(_preserveMedia(item)),
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
