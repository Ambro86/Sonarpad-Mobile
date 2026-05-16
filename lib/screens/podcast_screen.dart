import 'package:flutter/material.dart';

import '../models/podcast.dart';
import '../services/audio_player_service.dart';
import '../services/podcast_service.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  final _service = PodcastService();
  final _audio = AudioPlayerService();
  final _feedController = TextEditingController();
  final _searchController = TextEditingController();

  List<PodcastSubscription> _subscriptions = [];
  List<PodcastSearchResult> _searchResults = [];
  PodcastSubscription? _selected;
  Future<List<PodcastEpisode>>? _episodes;
  bool _searching = false;
  String _country = 'IT';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subs = await _service.loadSubscriptions();
    setState(() {
      _subscriptions = subs;
      _selected = subs.isEmpty ? null : subs.first;
      _episodes = _selected == null ? null : _service.fetchEpisodes(_selected!);
    });
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchResults = [];
    });
    try {
      final results = await _service.searchPodcasts(query, country: _country);
      if (!mounted) return;
      setState(() => _searchResults = results);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trovati ${results.length} podcast')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore ricerca podcast: $e')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _subscribeResult(PodcastSearchResult result) async {
    try {
      final sub = await _service.addSearchResult(result);
      await _load();
      setState(() {
        _selected = sub;
        _episodes = _service.fetchEpisodes(sub);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Iscritto a ${result.title}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore iscrizione: $e')));
    }
  }

  Future<void> _addByUrl() async {
    final url = _feedController.text.trim();
    if (url.isEmpty) return;
    try {
      final sub = await _service.addSubscription(url);
      _feedController.clear();
      await _load();
      setState(() {
        _selected = sub;
        _episodes = _service.fetchEpisodes(sub);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore iscrizione podcast: $e')));
    }
  }

  @override
  void dispose() {
    _feedController.dispose();
    _searchController.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podcast')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Cerca podcast', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Nome podcast',
              hintText: 'Esempio: tecnologia, storia, il nome del podcast...',
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _country,
            decoration: const InputDecoration(labelText: 'Paese ricerca'),
            items: const [
              DropdownMenuItem(value: 'IT', child: Text('Italia')),
              DropdownMenuItem(value: 'US', child: Text('Stati Uniti / inglese')),
              DropdownMenuItem(value: 'GB', child: Text('Regno Unito')),
              DropdownMenuItem(value: 'ES', child: Text('Spagna')),
              DropdownMenuItem(value: 'FR', child: Text('Francia')),
            ],
            onChanged: (value) => setState(() => _country = value ?? 'IT'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: const Icon(Icons.search),
            label: Text(_searching ? 'Ricerca in corso...' : 'Cerca podcast'),
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Risultati ricerca', style: Theme.of(context).textTheme.titleMedium),
            ..._searchResults.map((result) => Card(
                  child: ListTile(
                    leading: result.artworkUrl == null
                        ? const Icon(Icons.podcasts)
                        : Image.network(result.artworkUrl!, width: 48, height: 48, semanticLabel: 'Copertina podcast'),
                    title: Text(result.title),
                    subtitle: Text(result.author.isEmpty ? result.feedUrl : result.author),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => _subscribeResult(result),
                  ),
                )),
          ],
          const Divider(height: 32),
          ExpansionTile(
            title: const Text('Aggiungi manualmente URL feed RSS'),
            children: [
              TextField(
                controller: _feedController,
                decoration: const InputDecoration(
                  labelText: 'URL feed podcast RSS',
                  hintText: 'https://example.com/feed.xml',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: _addByUrl, child: const Text('Iscriviti da URL')),
            ],
          ),
          const SizedBox(height: 16),
          if (_subscriptions.isNotEmpty)
            DropdownButtonFormField<PodcastSubscription>(
              value: _selected,
              decoration: const InputDecoration(labelText: 'Podcast iscritti'),
              items: _subscriptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.title, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selected = value;
                  _episodes = _service.fetchEpisodes(value);
                });
              },
            )
          else
            const Text('Nessun podcast iscritto. Cerca un podcast e tocca il risultato per iscriverti.'),
          const SizedBox(height: 16),
          if (_episodes != null)
            FutureBuilder<List<PodcastEpisode>>(
              future: _episodes,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(semanticsLabel: 'Caricamento episodi'));
                }
                if (snapshot.hasError) return Text('Errore: ${snapshot.error}');
                final episodes = snapshot.data ?? const [];
                if (episodes.isEmpty) return const Text('Nessun episodio audio trovato nel feed.');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Episodi', style: Theme.of(context).textTheme.titleMedium),
                    ...episodes.map((episode) => Card(
                          child: ListTile(
                            title: Text(episode.title),
                            subtitle: Text(episode.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Azioni episodio',
                              onSelected: (action) async {
                                try {
                                  if (action == 'play') await _audio.playUrl(episode.audioUrl);
                                  if (action == 'download') {
                                    final file = await _service.downloadEpisode(episode);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scaricato: ${file.path}')));
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore episodio: $e')));
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'play', child: Text('Riproduci')),
                                PopupMenuItem(value: 'download', child: Text('Scarica')),
                              ],
                            ),
                            onTap: () => _audio.playUrl(episode.audioUrl),
                          ),
                        )),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
