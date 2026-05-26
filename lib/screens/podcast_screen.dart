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
  List<PodcastSearchResult> _searchResults = [];
  PodcastSearchResult? _selectedSearchResult;
  Future<PodcastDetails>? _selectedSearchDetails;
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
    if (!mounted) return;
    setState(() => _subscriptions = subs);
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
      await _service.addSearchResult(result);
      await _load();
      setState(() {
        _selectedSearchResult = null;
        _selectedSearchDetails = null;
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
      SemanticsService.announce(l10n.podcastRemoved, TextDirection.ltr);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')));
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
                      CustomSemanticsAction(label: l10n.removePodcast): () => _removeSubscription(subscription),
                    },
                    child: Row(
                      children: [
                        Expanded(
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
                        PopupMenuButton<_PodcastAction>(
                          onSelected: (action) => _handleAction(action, index),
                          itemBuilder: (context) => [
                            if (!isFirst)
                              PopupMenuItem(
                                value: _PodcastAction.moveUp,
                                child: Text(l10n.moveUp),
                              ),
                            if (!isLast)
                              PopupMenuItem(
                                value: _PodcastAction.moveDown,
                                child: Text(l10n.moveDown),
                              ),
                            PopupMenuItem(
                              value: _PodcastAction.moveToPosition,
                              child: Text(l10n.moveToPosition),
                            ),
                          ],
                        ),
                      ],
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

  const _PodcastPositionSliderDialog({required this.currentIndex, required this.subscriptions});

  @override
  State<_PodcastPositionSliderDialog> createState() => _PodcastPositionSliderDialogState();
}

class _PodcastPositionSliderDialogState extends State<_PodcastPositionSliderDialog> {
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
      final targetName = targetIndex < widget.subscriptions.length ? widget.subscriptions[targetIndex].title : '';
      label = l10n.positionLabel(pos + 1, targetName);
    }

    return AlertDialog(
      title: Text(l10n.moveToPosition),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Slider(
            value: _value,
            min: 0,
            max: (widget.subscriptions.length - 1).toDouble(),
            divisions: widget.subscriptions.length > 1 ? widget.subscriptions.length - 1 : 1,
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
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, pos),
          child: const Text('Ok'),
        ),
      ],
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
