import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/audiodescription_service.dart';
import '../widgets/media_preservation_progress_dialog.dart';
import 'audiodescription_all_screen.dart';
import 'audiodescription_scheduled_screen.dart';
import '../models/podcast.dart';
import 'podcast_episode_player_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

const _scheduledAudiodescriptionsTitle = 'Audiodescrizioni in programma';

class AudiodescriptionRecentScreen extends StatefulWidget {
  const AudiodescriptionRecentScreen({super.key});

  @override
  State<AudiodescriptionRecentScreen> createState() =>
      _AudiodescriptionRecentScreenState();
}

class _AudiodescriptionRecentScreenState
    extends State<AudiodescriptionRecentScreen> {
  final _service = AudiodescriptionService();

  List<AudiodescriptionItem> _items = [];
  List<AudiodescriptionItem> _filteredItems = [];
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
      final items = await _service.fetchRecentCatalog(code);
      if (mounted) {
        setState(() {
          _items = items;
          _filteredItems = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredItems = _items;
      } else {
        final q = query.trim().toLowerCase();
        _filteredItems = _items
            .where((i) =>
                i.title.toLowerCase().contains(q) ||
                i.description.toLowerCase().contains(q))
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
        title: Text(l10n.audiodescriptionTitle),
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
              ? Center(child: Text('${l10n.audiodescriptionError}: $_error'))
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      sections: [
                        AccessibleListSection(
                          rows: [
                            const AccessibleListRow(id: 'scheduled', title: _scheduledAudiodescriptionsTitle),
                            AccessibleListRow(id: 'all', title: l10n.audiodescriptionAll),
                            ..._filteredItems.asMap().entries.map((entry) => AccessibleListRow(
                                  id: 'item_${entry.key}',
                                  title: entry.value.title,
                                  subtitle: '${entry.value.date} ${entry.value.description}'.trim(),
                                  actions: [
                                    AccessibleCustomAction(
                                      id: 'preserve_media',
                                      label: l10n.preserveMedia,
                                    ),
                                  ],
                                  visualActionId: 'preserve_media',
                                  visualActionIcon: 'download',
                                )),
                          ],
                        ),
                      ],
                      onEvent: (event) async {
                        if (event.id == null) return;
                        if (event.id!.startsWith('item_') &&
                            event.type == 'customAction' &&
                            event.action == 'preserve_media') {
                          final index = int.tryParse(event.id!.substring(5));
                          if (index != null &&
                              index >= 0 &&
                              index < _filteredItems.length) {
                            await _preserveMedia(_filteredItems[index]);
                          }
                          return;
                        }
                        if (event.type != 'activate') return;
                        if (event.id == 'scheduled') {
                          Navigator.push(context, MaterialPageRoute(
                            settings: const RouteSettings(name: '/audiodescriptions/scheduled'),
                            builder: (_) => const AudiodescriptionScheduledScreen(),
                          ));
                        } else if (event.id == 'all') {
                          Navigator.push(context, MaterialPageRoute(
                            settings: const RouteSettings(name: '/audiodescriptions/all'),
                            builder: (_) => const AudiodescriptionAllScreen(),
                          ));
                        } else if (event.id!.startsWith('item_')) {
                          final index = int.tryParse(event.id!.substring(5));
                          if (index != null && index >= 0 && index < _filteredItems.length) await _play(_filteredItems[index]);
                        }
                      },
                    )
                  : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredItems.length + 2,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const Icon(Icons.event_available),
                        title: const Text(_scheduledAudiodescriptionsTitle,
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                  name: '/audiodescriptions/scheduled'),
                              builder: (_) =>
                                  const AudiodescriptionScheduledScreen(),
                            ),
                          );
                        },
                      );
                    }

                    if (index == 1) {
                      return ListTile(
                        leading: const Icon(Icons.list),
                        title: Text(l10n.audiodescriptionAll,
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                  name: '/audiodescriptions/all'),
                              builder: (_) => const AudiodescriptionAllScreen(),
                            ),
                          );
                        },
                      );
                    }

                    final item = _filteredItems[index - 2];
                    return Semantics(
                      container: true,
                      customSemanticsActions: {
                        CustomSemanticsAction(label: l10n.preserveMedia): () =>
                            unawaited(_preserveMedia(item)),
                      },
                      child: ListTile(
                        title: Text(item.title),
                        subtitle:
                            Text('${item.date} ${item.description}'.trim()),
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
