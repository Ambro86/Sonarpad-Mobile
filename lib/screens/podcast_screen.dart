import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/podcast_service.dart';
import 'podcast_episodes_screen.dart';

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
  String _country = 'it';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subs = await _service.loadSubscriptions();
    if (!mounted) return;
    setState(() => _subscriptions = subs);
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    Navigator.push<String>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/search-results'),
        builder: (_) => _PodcastSearchResultsScreen(
          query: query,
          country: _country,
          category: PodcastService.categories.first,
        ),
      ),
    ).then((feedUrl) async {
      if (!mounted || feedUrl == null) return;
      await _load();
      try {
        final sub = _subscriptions.firstWhere((s) => s.feedUrl == feedUrl);
        _openSubscription(sub);
      } catch (_) {}
    });
  }

  Future<void> _openCategories() async {
    final feedUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/categories'),
        builder: (_) => _PodcastCategoryBrowserScreen(country: _country),
      ),
    );
    if (!mounted || feedUrl == null) return;
    await _load();
    try {
      final sub = _subscriptions.firstWhere((s) => s.feedUrl == feedUrl);
      _openSubscription(sub);
    } catch (_) {}
  }

  void _openSubscription(PodcastSubscription subscription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/episodes'),
        builder: (_) => PodcastEpisodesScreen(subscription: subscription),
      ),
    );
  }

  Future<void> _addByUrl() async {
    final l10n = AppLocalizations.of(context);
    final url = _feedController.text.trim();
    if (url.isEmpty) return;
    try {
      await _service.addSubscription(url);
      _feedController.clear();
      await _load();
      try {
        final sub = _subscriptions.firstWhere((s) => s.feedUrl == url);
        _openSubscription(sub);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.podcastSubscriptionError(e))));
    }
  }

  Future<void> _removeSubscription(PodcastSubscription subscription) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _service.removeSubscription(subscription);
      await _load();
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.podcastRemoved,
        TextDirection.ltr,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).errorPrefix}: $e')));
    }
  }

  Future<void> _handleAction(_PodcastAction action, int index) async {
    final list = List<PodcastSubscription>.from(_subscriptions);
    final item = list.removeAt(index);

    if (action == _PodcastAction.moveUp && index > 0) {
      list.insert(index - 1, item);
      await _service.saveSubscriptions(list);
      setState(() => _subscriptions = list);
    } else if (action == _PodcastAction.moveDown && index < list.length) {
      list.insert(index + 1, item);
      await _service.saveSubscriptions(list);
      setState(() => _subscriptions = list);
    } else if (action == _PodcastAction.moveToPosition) {
      list.insert(index, item);
      final newPos = await showDialog<int>(
        context: context,
        builder: (_) => _PodcastPositionSliderDialog(
          currentIndex: index,
          subscriptions: list,
        ),
      );
      if (newPos != null && newPos != index) {
        final toMove = list.removeAt(index);
        list.insert(newPos, toMove);
        await _service.saveSubscriptions(list);
        setState(() => _subscriptions = list);
      }
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
          FilledButton.icon(
            onPressed: _openCategories,
            icon: const Icon(Icons.category),
            label: Text(l10n.browsePodcastCategories),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: Text(l10n.searchPodcasts),
          ),
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
          Text(l10n.subscribedPodcasts,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_subscriptions.isNotEmpty) ...[
            ..._subscriptions.asMap().entries.map((entry) {
              final index = entry.key;
              final subscription = entry.value;
              final isFirst = index == 0;
              final isLast = index == _subscriptions.length - 1;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MergeSemantics(
                  child: Semantics(
                    customSemanticsActions: {
                      CustomSemanticsAction(label: l10n.removePodcast): () =>
                          _removeSubscription(subscription),
                      if (!isFirst)
                        CustomSemanticsAction(label: l10n.moveUp): () =>
                            _handleAction(_PodcastAction.moveUp, index),
                      if (!isLast)
                        CustomSemanticsAction(label: l10n.moveDown): () =>
                            _handleAction(_PodcastAction.moveDown, index),
                      CustomSemanticsAction(label: l10n.moveToPosition): () =>
                          _handleAction(_PodcastAction.moveToPosition, index),
                    },
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => _openSubscription(subscription),
                      icon: const Icon(Icons.podcasts),
                      label: Text(
                        subscription.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ] else
            Text(l10n.noSubscribedPodcasts),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

enum _PodcastAction { moveUp, moveDown, moveToPosition }

class _PodcastPositionSliderDialog extends StatefulWidget {
  final int currentIndex;
  final List<PodcastSubscription> subscriptions;

  const _PodcastPositionSliderDialog(
      {required this.currentIndex, required this.subscriptions});

  @override
  State<_PodcastPositionSliderDialog> createState() =>
      _PodcastPositionSliderDialogState();
}

class _PodcastPositionSliderDialogState
    extends State<_PodcastPositionSliderDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentIndex.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pos = _value.toInt();

    String label;
    if (pos == widget.subscriptions.length - 1) {
      label = l10n.positionLabelLast;
    } else {
      final targetIndex = pos >= widget.currentIndex ? pos + 1 : pos;
      final targetName = targetIndex < widget.subscriptions.length
          ? widget.subscriptions[targetIndex].title
          : '';
      label = l10n.positionLabel(pos + 1, targetName);
    }

    return AlertDialog(
      title: Text(l10n.moveToPosition),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Slider(
            value: _value,
            min: 0,
            max: (widget.subscriptions.length - 1).toDouble(),
            divisions: widget.subscriptions.length > 1
                ? widget.subscriptions.length - 1
                : 1,
            label: (pos + 1).toString(),
            onChanged: (val) {
              setState(() {
                _value = val;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, pos),
          child: Text(AppLocalizations.of(context).ok),
        ),
      ],
    );
  }
}

class _PodcastCategoryBrowserScreen extends StatelessWidget {
  final String country;

  const _PodcastCategoryBrowserScreen({required this.country});

  Future<void> _openCategory(
      BuildContext context, PodcastCategory category) async {
    final feedUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/category-results'),
        builder: (_) => _PodcastSearchResultsScreen(
          query: '',
          country: country,
          category: category,
        ),
      ),
    );
    if (!context.mounted || feedUrl == null) return;
    Navigator.pop(context, feedUrl);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = PodcastService.categories
        .where((category) => category.genreId != null)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.podcastCategories)),
      body: ListView.separated(
        itemCount: categories.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final category = categories[index];
          return ListTile(
            leading: const Icon(Icons.category),
            title: Text(category.nameForLanguage(l10n.locale.languageCode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openCategory(context, category),
          );
        },
      ),
    );
  }
}

class _PodcastSearchResultsScreen extends StatefulWidget {
  final String query;
  final String country;
  final PodcastCategory category;

  const _PodcastSearchResultsScreen({
    required this.query,
    required this.country,
    required this.category,
  });

  @override
  State<_PodcastSearchResultsScreen> createState() =>
      _PodcastSearchResultsScreenState();
}

class _PodcastSearchResultsScreenState
    extends State<_PodcastSearchResultsScreen> {
  final _service = PodcastService();
  late final Future<List<PodcastSearchResult>> _results;

  @override
  void initState() {
    super.initState();
    _results = _service.searchPodcasts(
      widget.query,
      country: widget.country,
      category: widget.category,
    );
  }

  Future<void> _openResult(PodcastSearchResult result) async {
    final feedUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/search-detail'),
        builder: (_) => _PodcastSearchDetailScreen(result: result),
      ),
    );
    if (!mounted || feedUrl == null) return;
    Navigator.pop(context, feedUrl);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchResults)),
      body: FutureBuilder<List<PodcastSearchResult>>(
        future: _results,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.searchInProgress,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(l10n.podcastSearchError(snapshot.error!)));
          }
          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return Center(child: Text(l10n.noPodcastResults));
          }
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = results[index];
              return ListTile(
                leading: ExcludeSemantics(
                  child: result.artworkUrl == null
                      ? const Icon(Icons.podcasts)
                      : Image.network(
                          result.artworkUrl!,
                          width: 48,
                          height: 48,
                        ),
                ),
                title: Text(result.title),
                subtitle: Text(
                  result.author.isEmpty ? result.feedUrl : result.author,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openResult(result),
              );
            },
          );
        },
      ),
    );
  }
}

class _PodcastSearchDetailScreen extends StatefulWidget {
  final PodcastSearchResult result;

  const _PodcastSearchDetailScreen({required this.result});

  @override
  State<_PodcastSearchDetailScreen> createState() =>
      _PodcastSearchDetailScreenState();
}

class _PodcastSearchDetailScreenState
    extends State<_PodcastSearchDetailScreen> {
  final _service = PodcastService();
  late final Future<PodcastDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = _service.fetchPodcastDetails(widget.result);
  }

  Future<void> _subscribe() async {
    final l10n = AppLocalizations.of(context);
    try {
      await _service.addSearchResult(widget.result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.subscribedTo(widget.result.title))),
      );
      Navigator.pop(context, widget.result.feedUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.subscriptionError(e))));
    }
  }

  void _previewEpisodes(PodcastSubscription subscription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/search-episodes'),
        builder: (_) => PodcastEpisodesScreen(subscription: subscription),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.podcastInfo)),
      body: _PodcastSearchDetail(
        result: widget.result,
        details: _details,
        onSubscribe: _subscribe,
        onPreviewEpisodes: _previewEpisodes,
      ),
    );
  }
}

class _PodcastSearchDetail extends StatelessWidget {
  const _PodcastSearchDetail({
    required this.result,
    required this.details,
    required this.onSubscribe,
    required this.onPreviewEpisodes,
  });

  final PodcastSearchResult result;
  final Future<PodcastDetails> details;
  final VoidCallback onSubscribe;
  final ValueChanged<PodcastSubscription> onPreviewEpisodes;

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
        final previewSubscription = PodcastSubscription(
          title: title,
          feedUrl: feedUrl,
          artworkUrl: artworkUrl,
        );

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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onPreviewEpisodes(previewSubscription),
              icon: const Icon(Icons.list_alt),
              label: Text(l10n.viewEpisodes),
            ),
          ],
        );
      },
    );
  }
}
