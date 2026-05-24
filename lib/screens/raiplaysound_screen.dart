import 'package:flutter/material.dart';

import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/raiplay_sound_service.dart';
import 'podcast_episode_player_screen.dart';

class RaiPlaySoundScreen extends StatefulWidget {
  final String? url;

  const RaiPlaySoundScreen({super.key, this.url});

  @override
  State<RaiPlaySoundScreen> createState() => _RaiPlaySoundScreenState();
}

class _RaiPlaySoundScreenState extends State<RaiPlaySoundScreen> {
  final _settings = AppSettingsService();
  final _service = RaiPlaySoundService();

  RaiPlaySoundPage? _page;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final code = await _settings.getTvSecretCode();
      final url = widget.url ?? _service.getGenresUrl(code);
      if (url == null) {
        throw Exception('Codice non valido o mancante.');
      }

      final page = await _service.loadPage(url);
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile caricare i contenuti: $e';
        _loading = false;
      });
    }
  }

  void _openItem(RaiPlaySoundItem item) async {
    final code = await _settings.getTvSecretCode();

    if (item.kind == RaiPlaySoundItemKind.page) {
      final baseUrl = _service.getBaseUrl(code);
      if (baseUrl == null) return;

      var path = item.pathId;
      if (!path.startsWith('/')) path = '/$path';
      if (!path.endsWith('.json')) path = '$path.json';

      final url = '$baseUrl$path';
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/raiplaysound/page'),
          builder: (_) => RaiPlaySoundScreen(url: url),
        ),
      );
    } else {
      final baseUrl = _service.getBaseUrl(code);
      if (baseUrl == null) return;

      var audioPath = item.audioUrl;
      if (!audioPath.startsWith('http')) {
        if (!audioPath.startsWith('/')) audioPath = '/$audioPath';
        audioPath = '$baseUrl$audioPath';
      }

      final episode = PodcastEpisode(
        title: item.title,
        description: item.description,
        audioUrl: audioPath,
        publishedAt: DateTime.now(),
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/raiplaysound/player'),
          builder: (_) => PodcastEpisodePlayerScreen(
            episode: episode,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_page?.title ?? 'RaiPlay Sound')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _page!.items.length,
                  itemBuilder: (context, index) {
                    final item = _page!.items[index];
                    final isAudio = item.kind == RaiPlaySoundItemKind.audio;

                    return Card(
                      child: ListTile(
                        leading:
                            Icon(isAudio ? Icons.audiotrack : Icons.folder),
                        title: Text(item.title),
                        subtitle: item.description.isNotEmpty
                            ? Text(item.description,
                                maxLines: 2, overflow: TextOverflow.ellipsis)
                            : null,
                        onTap: () => _openItem(item),
                        trailing: IconButton(
                          tooltip: isAudio ? 'Riproduci' : 'Apri cartella',
                          onPressed: () => _openItem(item),
                          icon: Icon(
                              isAudio ? Icons.play_arrow : Icons.chevron_right),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
