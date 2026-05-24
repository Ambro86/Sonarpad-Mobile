import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/podcast_service.dart';
import 'podcast_episode_player_screen.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  final _service = PodcastService();
  final _feedController = TextEditingController();
  final _searchController = TextEditingController();

  List<PodcastSubscription> _subscriptions = [];
  List<PodcastSearchResult> _searchResults = [];
  PodcastSearchResult? _selectedSearchResult;
  Future<PodcastDetails>? _selectedSearchDetails;
  PodcastSubscription? _selected;
  Future<List<PodcastEpisode>>? _episodes;
  bool _searching = false;
  String _country = 'it';
  PodcastCategory _category = PodcastService.categories.first;

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
    final l10n = AppLocalizations.of(context);
    final query = _searchController.text.trim();
    if (query.isEmpty && _category.genreId == null) return;
    setState(() {
      _searching = true;
      _searchResults = [];
    });
    try {
      final results = await _service.searchPodcasts(
        query,
        country: _country,
        category: _category,
      );
      if (!mounted) return;
      setState(() => _searchResults = results);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.podcastResultsFound(results.length))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.podcastSearchError(e))));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _subscribeResult(PodcastSearchResult result) async {
    final l10n = AppLocalizations.of(context);
    try {
      final sub = await _service.addSearchResult(result);
      await _load();
      setState(() {
        _selectedSearchResult = null;
        _selectedSearchDetails = null;
        _selected = sub;
        _episodes = _service.fetchEpisodes(sub);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.subscribedTo(result.title))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.subscriptionError(e))));
    }
  }

  void _openSearchResult(PodcastSearchResult result) {
    setState(() {
      _selectedSearchResult = result;
      _selectedSearchDetails = _service.fetchPodcastDetails(result);
    });
  }

  void _closeSearchResult() {
    setState(() {
      _selectedSearchResult = null;
      _selectedSearchDetails = null;
    });
  }

  void _openEpisode(PodcastEpisode episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PodcastEpisodePlayerScreen(episode: episode),
      ),
    );
  }

  Future<void> _addByUrl() async {
    final l10n = AppLocalizations.of(context);
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.podcastSubscriptionError(e))));
    }
  }

  @override
  void dispose() {
    _feedController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedSearchResult = _selectedSearchResult;
    final selectedSearchDetails = _selectedSearchDetails;
    if (selectedSearchResult != null && selectedSearchDetails != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.podcastInfo),
          leading: BackButton(onPressed: _closeSearchResult),
        ),
        body: _PodcastSearchDetail(
          result: selectedSearchResult,
          details: selectedSearchDetails,
          onSubscribe: () => _subscribeResult(selectedSearchResult),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.podcasts)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.searchPodcasts,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: l10n.podcastName,
              hintText: l10n.podcastSearchHint,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _country,
            decoration: InputDecoration(labelText: l10n.searchCountry),
            items: PodcastService.countries
                .map((country) => DropdownMenuItem(
                      value: country.code,
                      child: Text(country.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _country = value ?? 'it'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<PodcastCategory>(
            initialValue: _category,
            decoration: InputDecoration(labelText: l10n.podcastCategory),
            items: PodcastService.categories
                .map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.name),
                    ))
                .toList(),
            onChanged: (value) => setState(
              () => _category = value ?? PodcastService.categories.first,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: const Icon(Icons.search),
            label:
                Text(_searching ? l10n.searchInProgress : l10n.searchPodcasts),
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l10n.searchResults,
                style: Theme.of(context).textTheme.titleMedium),
            ..._searchResults.map((result) => Card(
                  child: ListTile(
                    leading: result.artworkUrl == null
                        ? const Icon(Icons.podcasts)
                        : Image.network(result.artworkUrl!,
                            width: 48,
                            height: 48,
                            semanticLabel: l10n.podcastArtwork),
                    title: Text(result.title),
                    subtitle: Text(
                        result.author.isEmpty ? result.feedUrl : result.author),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openSearchResult(result),
                  ),
                )),
          ],
          const Divider(height: 32),
          ExpansionTile(
            title: Text(l10n.addFeedUrlManually),
            children: [
              TextField(
                controller: _feedController,
                decoration: InputDecoration(
                  labelText: l10n.podcastFeedUrl,
                  hintText: 'https://example.com/feed.xml',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: _addByUrl, child: Text(l10n.subscribeFromUrl)),
            ],
          ),
          const SizedBox(height: 16),
          if (_subscriptions.isNotEmpty)
            DropdownButtonFormField<PodcastSubscription>(
              initialValue: _selected,
              decoration: InputDecoration(labelText: l10n.subscribedPodcasts),
              items: _subscriptions
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.title, overflow: TextOverflow.ellipsis)))
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
            Text(l10n.noSubscribedPodcasts),
          const SizedBox(height: 16),
          if (_episodes != null)
            FutureBuilder<List<PodcastEpisode>>(
              future: _episodes,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                      child: CircularProgressIndicator(
                          semanticsLabel: l10n.loadingEpisodes));
                }
                if (snapshot.hasError) return Text(l10n.error(snapshot.error!));
                final episodes = snapshot.data ?? const [];
                if (episodes.isEmpty) return Text(l10n.noAudioEpisodesFound);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.episodes,
                        style: Theme.of(context).textTheme.titleMedium),
                    ...episodes.map((episode) => Card(
                          child: ListTile(
                            title: Text(episode.title),
                            subtitle: Text(episode.description,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: PopupMenuButton<String>(
                              tooltip: l10n.episodeActions,
                              onSelected: (action) async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  if (action == 'play') {
                                    _openEpisode(episode);
                                  }
                                  if (action == 'download') {
                                    final file =
                                        await _service.downloadEpisode(episode);
                                    if (!mounted) return;
                                    messenger.showSnackBar(SnackBar(
                                        content:
                                            Text(l10n.downloaded(file.path))));
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(SnackBar(
                                      content: Text(l10n.episodeError(e))));
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'play', child: Text(l10n.play)),
                                PopupMenuItem(
                                    value: 'download',
                                    child: Text(l10n.download)),
                              ],
                            ),
                            onTap: () => _openEpisode(episode),
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

class _PodcastSearchDetail extends StatelessWidget {
  const _PodcastSearchDetail({
    required this.result,
    required this.details,
    required this.onSubscribe,
  });

  final PodcastSearchResult result;
  final Future<PodcastDetails> details;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<PodcastDetails>(
      future: details,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final title = data?.title ?? result.title;
        final author = data?.author ?? result.author;
        final description = data?.description ?? '';
        final artworkUrl = data?.artworkUrl ?? result.artworkUrl;
        final feedUrl = data?.feedUrl ?? result.feedUrl;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (artworkUrl != null) ...[
              Center(
                child: Image.network(
                  artworkUrl,
                  width: 160,
                  height: 160,
                  semanticLabel: l10n.podcastArtwork,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (author.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${l10n.podcastAuthor}: $author'),
            ],
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.loadingPodcastInfo,
                ),
              )
            else if (snapshot.hasError)
              Text(l10n.error(snapshot.error!))
            else
              Text(description.isEmpty
                  ? l10n.noPodcastDescription
                  : description),
            const SizedBox(height: 16),
            Text(feedUrl),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onSubscribe,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(l10n.subscribe),
            ),
          ],
        );
      },
    );
  }
}
