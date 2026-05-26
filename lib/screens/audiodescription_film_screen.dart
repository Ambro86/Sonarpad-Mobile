import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ui_audiodescription_localizations.dart';
import '../models/radio_station.dart';
import '../services/audiodescription_service.dart';
import '../models/podcast.dart';
import 'podcast_episode_player_screen.dart';

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

  List<AudiodescriptionItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.filmGroup.items;
  }

  void _onSearch(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredItems = widget.filmGroup.items;
      } else {
        final q = query.trim().toLowerCase();
        _filteredItems = widget.filmGroup.items
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
              publishedAt: DateTime.now(),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredItems.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          return ListTile(
            title: Text(item.title),
            trailing: const Icon(Icons.play_arrow),
            onTap: () => _play(item),
          );
        },
      ),
    );
  }
}
