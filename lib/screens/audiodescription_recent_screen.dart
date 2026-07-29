import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/audiodescription_service.dart';
import 'audiodescription_all_screen.dart';
import 'audiodescription_scheduled_screen.dart';
import '../models/podcast.dart';
import 'podcast_episode_player_screen.dart';
import '../utils/status_message.dart';

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
                    return ListTile(
                      title: Text(item.title),
                      subtitle: Text('${item.date} ${item.description}'.trim()),
                      trailing: const Icon(Icons.play_arrow),
                      onTap: () => _play(item),
                    );
                  },
                ),
    );
  }
}
