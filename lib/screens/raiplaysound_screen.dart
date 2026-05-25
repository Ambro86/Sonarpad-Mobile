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
  final _searchController = TextEditingController();

  RaiPlaySoundPage? _page;
  bool _loading = true;
  String? _error;
  bool _searching = false;
  String _secretCode = '';
  bool _autoOpenedSingleItem = false;

  bool get _isRoot => widget.url == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final code = await _settings.getTvSecretCode();
      _secretCode = code;
      final url = widget.url ?? _service.getGenresUrl(code);
      if (url == null) {
        throw Exception('Codice non valido o mancante.');
      }

      final page = await _service.loadPage(url, isRootPage: _isRoot);
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
      _openSingleNestedItemIfNeeded(page);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile caricare i contenuti: $e';
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _service.searchContent(query, _secretCode);
      if (!mounted) return;
      setState(() {
        _page = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore nella ricerca: $e';
        _searching = false;
      });
    }
  }

  Future<void> _resetToRoot() async {
    _searchController.clear();
    setState(() {
      _loading = true;
      _error = null;
      _autoOpenedSingleItem = false;
    });
    await _load();
  }

  void _openSingleNestedItemIfNeeded(RaiPlaySoundPage page) {
    if (_isRoot || _autoOpenedSingleItem || page.items.length != 1) return;
    _autoOpenedSingleItem = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openItem(page.items.single);
    });
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
          : _error != null && _page == null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    if (_isRoot)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  labelText: 'Cerca su RaiPlay Sound',
                                  hintText: 'Es. GR, teatro, podcast...',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _search(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_searching)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: 'Cerca',
                                onPressed: _search,
                              ),
                              if (_page?.title.startsWith('Risultati:') == true)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Torna alla home',
                                  onPressed: _resetToRoot,
                                ),
                            ],
                          ],
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _page!.items.length,
                        itemBuilder: (context, index) {
                          final item = _page!.items[index];
                          final isAudio =
                              item.kind == RaiPlaySoundItemKind.audio;

                          return Card(
                            child: ListTile(
                              leading: Icon(
                                isAudio ? Icons.audiotrack : Icons.folder,
                              ),
                              title: Text(item.title),
                              subtitle: item.description.isNotEmpty
                                  ? Text(
                                      item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () => _openItem(item),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
