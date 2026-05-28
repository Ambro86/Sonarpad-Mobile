import 'package:flutter/material.dart';
import '../services/audiodescription_service.dart';
import '../models/podcast.dart';
import 'podcast_episode_player_screen.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.title),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _episodes.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final item = _episodes[index];
          return ListTile(
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: item.description.isNotEmpty ? Text(item.description) : null,
            trailing: const Icon(Icons.play_arrow),
            onTap: () => _play(item),
          );
        },
      ),
    );
  }
}
