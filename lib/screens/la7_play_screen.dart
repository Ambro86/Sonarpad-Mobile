import 'package:flutter/material.dart';

import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/la7_play_service.dart';
import '../services/recent_searches_service.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';
import 'recent_searches_screen.dart';

class La7PlayScreen extends StatefulWidget {
  const La7PlayScreen({
    super.key,
    this.source,
    this.pageTitle,
    this.searchQuery,
  });

  final String? source;
  final String? pageTitle;
  final String? searchQuery;

  @override
  State<La7PlayScreen> createState() => _La7PlayScreenState();
}

class _La7PlayScreenState extends State<La7PlayScreen> {
  final _settings = AppSettingsService();
  final _service = La7PlayService();

  La7PlayPage? _page;
  bool _loading = true;
  String? _error;

  bool get _isRoot => widget.source == null && widget.searchQuery == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final language = await _settings.loadAppLanguage();
      if (language != 'it') {
        throw Exception('LA7 Play è disponibile solo con interfaccia italiana.');
      }
      final code = await _settings.getTvSecretCode();
      if (!_service.isSecretCodeValid(code)) {
        throw Exception('Codice non valido o mancante.');
      }

      final page = widget.searchQuery != null
          ? await _service.search(widget.searchQuery!)
          : widget.source != null
              ? await _service.loadPage(widget.source!)
              : _service.rootPage();
      if (!mounted) return;
      setState(() {
        _page = page;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _page = null;
        _error = 'Impossibile caricare i contenuti: $error';
        _loading = false;
      });
    }
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/la7play/search-form'),
        builder: (_) => const La7PlaySearchScreen(),
      ),
    );
  }

  void _openItem(La7PlayItem item) {
    if (item.kind == La7PlayItemKind.page) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/la7play/page'),
          builder: (_) => La7PlayScreen(
            source: item.target,
            pageTitle: item.title,
          ),
        ),
      );
      return;
    }
    _openMedia(item);
  }

  Future<void> _openMedia(La7PlayItem item) async {
    setState(() => _loading = true);
    try {
      final mediaUrl = await _service.resolveVod(item.target);
      if (!mounted) return;
      setState(() => _loading = false);
      final episode = PodcastEpisode(
        title: item.title,
        description: item.description ?? '',
        audioUrl: mediaUrl,
        videoUrl: mediaUrl,
        id: 'la7play:${item.target}',
        publishedAt: DateTime.now(),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/la7play/player'),
          builder: (_) => PodcastEpisodePlayerScreen(
            episode: episode,
            isVideoSupported: true,
            startWithVideo: true,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossibile aprire il contenuto: $error';
      });
    }
  }

  Widget _buildSharedBody() {
    final items = _page?.items ?? const <La7PlayItem>[];
    final rows = <AccessibleListRow>[
      if (_isRoot)
        const AccessibleListRow(
          id: 'search',
          title: 'Cerca',
          subtitle: 'Cerca programmi e clip su LA7 Play',
          kind: 'button',
        ),
      if (_error != null)
        AccessibleListRow(id: 'error', title: _error!, kind: 'text'),
      for (var i = 0; i < items.length; i++)
        AccessibleListRow(
          id: 'item_$i',
          title: items[i].title,
          subtitle: items[i].description,
        ),
      if (_error == null && !_loading && items.isEmpty && !_isRoot)
        const AccessibleListRow(
          id: 'empty',
          title: 'Nessun contenuto disponibile.',
          kind: 'text',
        ),
    ];

    return UniversalAccessibleList(
      sections: [AccessibleListSection(rows: rows)],
      onEvent: (event) {
        if (event.type != 'activate') return;
        if (event.id == 'search') {
          _openSearch();
          return;
        }
        if (event.id?.startsWith('item_') != true) return;
        final index = int.tryParse(event.id!.substring(5));
        if (index != null && index >= 0 && index < items.length) {
          _openItem(items[index]);
        }
      },
    );
  }

  Widget _buildFlutterBody() {
    final items = _page?.items ?? const <La7PlayItem>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isRoot)
          Card(
            child: ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Cerca'),
              subtitle: const Text('Cerca programmi e clip su LA7 Play'),
              onTap: _openSearch,
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final item in items)
          Card(
            child: ListTile(
              leading: Icon(
                item.kind == La7PlayItemKind.media
                    ? Icons.play_circle_fill
                    : Icons.folder,
              ),
              title: Text(item.title),
              subtitle:
                  item.description == null ? null : Text(item.description!),
              onTap: () => _openItem(item),
            ),
          ),
        if (_error == null && !_loading && items.isEmpty && !_isRoot)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nessun contenuto disponibile.'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pageTitle ?? _page?.title ?? 'LA7 Play')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : useSharedAccessibleViewModel
              ? _buildSharedBody()
              : _buildFlutterBody(),
    );
  }
}

class La7PlaySearchScreen extends StatefulWidget {
  const La7PlaySearchScreen({super.key});

  @override
  State<La7PlaySearchScreen> createState() => _La7PlaySearchScreenState();
}

class _La7PlaySearchScreenState extends State<La7PlaySearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    await RecentSearchesService().addSearch('la7play', query);
    if (!mounted) return;
    _controller.clear();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/la7play/search-results'),
        builder: (_) => La7PlayScreen(
          searchQuery: query,
          pageTitle: 'Risultati: $query',
        ),
      ),
    );
  }

  Future<void> _openRecentSearches() async {
    final query = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        settings: const RouteSettings(name: '/la7play/recent-searches'),
        builder: (_) => const RecentSearchesScreen(
          title: 'Ricerche recenti',
          domain: 'la7play',
        ),
      ),
    );
    if (query == null || !mounted) return;
    _controller.text = query;
    await _search();
  }

  Widget _buildSharedBody() {
    return UniversalAccessibleList(
      sections: [
        AccessibleListSection(
          rows: [
            AccessibleListRow(
              id: 'query',
              title: 'Cerca su LA7 Play',
              kind: 'textField',
              value: _controller.text,
              placeholder: 'Nome del programma',
              textInputAction: 'search',
              onSubmitted: (_) => _search(),
            ),
            const AccessibleListRow(
              id: 'search',
              title: 'Cerca',
              kind: 'button',
            ),
            const AccessibleListRow(
              id: 'recent',
              title: 'Ricerche recenti',
              kind: 'button',
            ),
          ],
        ),
      ],
      onEvent: (event) async {
        if (event.id == 'query' && event.type == 'textChanged') {
          _controller.value = TextEditingValue(
            text: event.value?.toString() ?? '',
            selection: TextSelection.collapsed(
              offset: (event.value?.toString() ?? '').length,
            ),
          );
        } else if (event.id == 'search' && event.type == 'activate') {
          await _search();
        } else if (event.id == 'recent' && event.type == 'activate') {
          await _openRecentSearches();
        }
      },
    );
  }

  Widget _buildFlutterBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cerca su LA7 Play',
              hintText: 'Nome del programma',
              prefixIcon: Icon(Icons.search),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Text('Cerca'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openRecentSearches,
              icon: const Icon(Icons.history),
              label: const Text('Ricerche recenti'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cerca su LA7 Play')),
      body: useSharedAccessibleViewModel
          ? _buildSharedBody()
          : _buildFlutterBody(),
    );
  }
}
