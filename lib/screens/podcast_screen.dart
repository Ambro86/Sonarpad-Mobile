import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/podcast_service.dart';
import 'podcast_episode_player_screen.dart';
import 'podcast_episodes_screen.dart';
import '../utils/status_message.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  final _settings = AppSettingsService();
  final _service = PodcastService();
  final _feedController = TextEditingController();
  final _searchController = TextEditingController();

  List<PodcastSubscription> _subscriptions = [];
  List<File> _localAudioFiles = [];
  String _country = 'it';
  PodcastCategory _category = PodcastService.categories.first;
  bool _countryLoaded = false;
  bool _categoryLoaded = false;

  static const _localAudioExtensions = {
    '.mp3',
    '.m4a',
    '.m4b',
    '.aac',
    '.wav',
    '.ogg',
    '.flac',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appLanguage = await _settings.loadAppLanguage();
    final savedCountry = await _settings.loadPodcastCountry();
    final savedCategoryGenreId = await _settings.loadPodcastCategoryGenreId();
    final subs = await _service.loadSubscriptions();
    final localAudioFiles = await _scanLocalAudioFiles();
    if (!mounted) return;
    setState(() {
      _subscriptions = subs;
      _localAudioFiles = localAudioFiles;
      if (!_countryLoaded) {
        if (savedCountry != null) {
          _country = savedCountry;
        } else {
          _country = _podcastCountryForAppLanguage(appLanguage);
          _settings.savePodcastCountry(_country);
        }
        _countryLoaded = true;
      }
      if (!_categoryLoaded) {
        _category = PodcastService.categories.firstWhere(
          (category) => category.genreId == savedCategoryGenreId,
          orElse: () => PodcastService.categories.first,
        );
        _categoryLoaded = true;
      }
    });
  }

  Future<List<File>> _scanLocalAudioFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!await dir.exists()) return const [];

    final files = <File>[];
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      if (entity is! File) continue;
      final basename = p.basename(entity.path);
      if (basename.startsWith('.')) continue;
      final ext = p.extension(basename).toLowerCase();
      if (_localAudioExtensions.contains(ext)) {
        files.add(entity);
      }
    }
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  }

  String _podcastCountryForAppLanguage(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'us';
      case 'fr':
        return 'fr';
      case 'es':
        return 'es';
      case 'pt':
        return 'pt';
      case 'pl':
        return 'pl';
      case 'it':
      default:
        return 'it';
    }
  }

  void _search({bool allowEmptyQuery = false}) {
    final query = _searchController.text.trim();
    if (query.isEmpty && !allowEmptyQuery) return;
    // La ricerca libera non eredita nazione o categoria scelte nello sfoglia.
    _openSearchResults(query: query);
  }

  Future<void> _openSearchResults({
    required String query,
    String? country,
    PodcastCategory? category,
    String? title,
  }) async {
    final feedUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/search-results'),
        builder: (_) => _PodcastSearchResultsScreen(
          query: query,
          country: country,
          category: category,
          title: title,
        ),
      ),
    );
    if (!mounted || feedUrl == null) return;
    await _load();
    try {
      final sub = _subscriptions.firstWhere((s) => s.feedUrl == feedUrl);
      _openSubscription(sub);
    } catch (_) {}
  }

  Future<void> _openCountries() async {
    final l10n = AppLocalizations.of(context);
    final countries = List<PodcastCountry>.of(PodcastService.countries)
      ..sort((a, b) {
        if (a.code == _country) return -1;
        if (b.code == _country) return 1;
        return a.name.compareTo(b.name);
      });

    final result = await Navigator.push<PodcastCountry>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/countries'),
        builder: (_) => _PodcastOptionPickerScreen<PodcastCountry>(
          title: l10n.podcastCountries,
          options: countries,
          labelBuilder: (country) => country.name,
          selectedBuilder: (country) => country.code == _country,
          selectedLabel: l10n.selectedRecently,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _country = result.code);
    await _settings.savePodcastCountry(result.code);
    if (!mounted) return;
    _openSearchResults(query: '', country: result.code, title: result.name);
  }

  Future<void> _openCategories() async {
    final l10n = AppLocalizations.of(context);
    final categories = List<PodcastCategory>.of(PodcastService.categories)
      ..sort((a, b) {
        if (a.genreId == _category.genreId) return -1;
        if (b.genreId == _category.genreId) return 1;
        return a
            .nameForLanguage(l10n.localeName)
            .compareTo(b.nameForLanguage(l10n.localeName));
      });

    final result = await Navigator.push<PodcastCategory>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/categories'),
        builder: (_) => _PodcastOptionPickerScreen<PodcastCategory>(
          title: l10n.podcastCategories,
          options: categories,
          labelBuilder: (category) => category.nameForLanguage(l10n.localeName),
          selectedBuilder: (category) => category.genreId == _category.genreId,
          selectedLabel: l10n.selectedRecently,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _category = result);
    await _settings.savePodcastCategoryGenreId(result.genreId);
    if (!mounted) return;
    _openSearchResults(
      query: '',
      country: _country,
      category: result,
      title: result.nameForLanguage(l10n.localeName),
    );
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

  void _openLocalAudioFile(File file) {
    final basename = p.basename(file.path);
    final episode = PodcastEpisode(
      id: basename,
      title: p.basenameWithoutExtension(basename),
      audioUrl: file.uri.toString(),
      publishedAt: DateTime.now(),
      description: '',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/local-audio-player'),
        builder: (_) => PodcastEpisodePlayerScreen(episode: episode),
      ),
    );
  }

  Future<void> _refreshLocalAudioFiles() async {
    final l10n = AppLocalizations.of(context);
    final files = await _scanLocalAudioFiles();
    if (!mounted) return;
    setState(() => _localAudioFiles = files);
        showStatusMessage(context, l10n.localAudioFilesFound(files.length));
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
            showStatusMessage(context, l10n.podcastSubscriptionError(e));
    }
  }

  Future<void> _importFromFile() async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['opml', 'xml'],
      );
      final path = result == null || result.files.isEmpty
          ? null
          : result.files.first.path;
      if (path == null || path.isEmpty) return;

      final added = await _service.importSubscriptionsFromOpml(File(path));
      await _load();
      if (!mounted) return;
            showStatusMessage(context, l10n.podcastImportComplete(added));
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, l10n.podcastImportError(e));
    }
  }

  Future<void> _exportToFile() async {
    final l10n = AppLocalizations.of(context);
    try {
      final opml = await _service.exportSubscriptionsToOpml();
      final bytes = utf8.encode(opml);
      final path = await FilePicker.saveFile(
        dialogTitle: l10n.exportPodcastsToFile,
        fileName: 'Sonarpad Podcasts.opml',
        type: FileType.custom,
        allowedExtensions: const ['opml'],
        bytes: Uint8List.fromList(bytes),
      );
      if (path == null || path.isEmpty) return;

      if (!mounted) return;
            showStatusMessage(context, l10n.podcastExportComplete);
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, l10n.podcastExportError(e));
    }
  }

  Future<void> _removeSubscription(PodcastSubscription subscription) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _service.removeSubscription(subscription);
      await _load();
      if (!mounted) return;
      showStatusMessage(context, l10n.podcastRemoved);
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, '${AppLocalizations.of(context).errorPrefix}: $e');
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
          ListTile(
            title: Text(l10n.browsePodcastCountries),
            subtitle: Text(PodcastService.countries
                .firstWhere(
                  (country) => country.code == _country,
                  orElse: () => PodcastService.countries.first,
                )
                .name),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openCountries,
          ),
          ListTile(
            title: Text(l10n.browsePodcastCategories),
            subtitle: Text(_category.nameForLanguage(l10n.localeName)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openCategories,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _search(),
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
                key: ValueKey('podcast_subscription_row_${subscription.feedUrl}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: MergeSemantics(
                  child: Semantics(
                    key: ValueKey(
                        'podcast_subscription_semantics_${subscription.feedUrl}'),
                    container: true,
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
          Text(l10n.localAudioFiles,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_localAudioFiles.isNotEmpty) ...[
            ..._localAudioFiles.map((file) {
              final basename = p.basename(file.path);
              return Padding(
                key: ValueKey('local_audio_row_${file.path}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.icon(
                  key: ValueKey('local_audio_button_${file.path}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => _openLocalAudioFile(file),
                  icon: const Icon(Icons.audio_file),
                  label: Text(
                    p.basenameWithoutExtension(basename),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                  ),
                ),
              );
            }),
          ] else
            Text(l10n.noLocalAudioFiles),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _refreshLocalAudioFiles,
            icon: const Icon(Icons.sync),
            label: Text(l10n.importAudioFromITunes),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _importFromFile,
            icon: const Icon(Icons.upload_file),
            label: Text(l10n.importPodcastsFromFile),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _exportToFile,
            icon: const Icon(Icons.download),
            label: Text(l10n.exportPodcastsToFile),
          ),
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

class _PodcastOptionPickerScreen<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final String Function(T) labelBuilder;
  final bool Function(T)? selectedBuilder;
  final String? selectedLabel;

  const _PodcastOptionPickerScreen({
    required this.title,
    required this.options,
    required this.labelBuilder,
    this.selectedBuilder,
    this.selectedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: options.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = selectedBuilder?.call(option) ?? false;
          final label = labelBuilder(option);
          final displayLabel = selected && selectedLabel != null
              ? '$label, $selectedLabel'
              : label;
          return ListTile(
            key: ValueKey('podcast_option_$label'),
            leading: Icon(selected ? Icons.check : Icons.podcasts),
            title: Text(displayLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(context, option),
          );
        },
      ),
    );
  }
}

class _PodcastSearchResultsScreen extends StatefulWidget {
  final String query;
  final String? country;
  final PodcastCategory? category;
  final String? title;

  const _PodcastSearchResultsScreen({
    required this.query,
    required this.country,
    required this.category,
    this.title,
  });

  @override
  State<_PodcastSearchResultsScreen> createState() =>
      _PodcastSearchResultsScreenState();
}

class _PodcastSearchResultsScreenState
    extends State<_PodcastSearchResultsScreen> {
  final _service = PodcastService();
  final Set<String> _subscribedFeedUrls = <String>{};
  late final Future<List<PodcastSearchResult>> _results;

  @override
  void initState() {
    super.initState();
    _results = _service.searchPodcasts(
      widget.query,
      country: widget.country,
      category: widget.category,
    );
    _loadSubscribedFeedUrls();
  }

  String _feedKey(String feedUrl) => feedUrl.trim().toLowerCase();

  Future<void> _loadSubscribedFeedUrls() async {
    final subscriptions = await _service.loadSubscriptions();
    if (!mounted) return;
    setState(() {
      _subscribedFeedUrls
        ..clear()
        ..addAll(subscriptions.map((subscription) =>
            _feedKey(subscription.feedUrl)));
    });
  }

  bool _isSubscribed(PodcastSearchResult result) {
    return _subscribedFeedUrls.contains(_feedKey(result.feedUrl));
  }

  Future<void> _subscribeFromResult(PodcastSearchResult result) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _service.addSearchResult(result);
      if (!mounted) return;
      setState(() => _subscribedFeedUrls.add(_feedKey(result.feedUrl)));
            showStatusMessage(context, l10n.subscribedTo(result.title));
      Navigator.pop(context, result.feedUrl);
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, l10n.subscriptionError(e));
    }
  }

  void _openSubscribedResult(PodcastSearchResult result) {
    Navigator.pop(context, result.feedUrl);
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
      appBar: AppBar(title: Text(widget.title ?? l10n.searchResults)),
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
              final isSubscribed = _isSubscribed(result);
              final secondaryActionLabel =
                  isSubscribed ? l10n.openPodcast : l10n.subscribe;
              return Semantics(
                key: ValueKey('podcast_search_result_semantics_${result.feedUrl}'),
                container: true,
                customSemanticsActions: {
                  CustomSemanticsAction(label: secondaryActionLabel): () {
                    if (isSubscribed) {
                      _openSubscribedResult(result);
                    } else {
                      _subscribeFromResult(result);
                    }
                  },
                },
                child: ListTile(
                  key: ValueKey('podcast_search_result_${result.feedUrl}'),
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
                ),
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
            showStatusMessage(context, l10n.subscribedTo(widget.result.title));
      Navigator.pop(context, widget.result.feedUrl);
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, l10n.subscriptionError(e));
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
