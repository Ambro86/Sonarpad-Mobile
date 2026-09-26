import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'package:flutter/semantics.dart';

import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/la7_play_service.dart';
import '../services/recording_feature_access.dart';
import '../services/recent_searches_service.dart';
import '../utils/app_logger.dart';
import '../utils/media_open_guard.dart';
import '../widgets/online_ai_audiodescription_action.dart';
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
  final _searchController = TextEditingController();
  final MediaOpenGuard _mediaOpenGuard = MediaOpenGuard();

  La7PlayPage? _page;
  bool _loading = true;
  String? _error;
  bool _aiAudiodescriptionUnlocked = false;

  bool get _isRoot => widget.source == null && widget.searchQuery == null;

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
      final language = await _settings.loadAppLanguage();
      if (language != 'it') {
        throw Exception('LA7 Play è disponibile solo con interfaccia italiana.');
      }
      final code = await _settings.getTvSecretCode();
      if (!_service.isSecretCodeValid(code)) {
        throw Exception('Codice non valido o mancante.');
      }
      final aiAudiodescriptionUnlocked =
          language == 'it' && RecordingFeatureAccess.isCodeValid(code);

      final page = widget.searchQuery != null
          ? await _service.search(widget.searchQuery!)
          : widget.source != null
              ? await _service.loadPage(widget.source!)
              : _service.rootPage();
      if (!mounted) return;
      setState(() {
        _page = page;
        _error = null;
        _aiAudiodescriptionUnlocked = aiAudiodescriptionUnlocked;
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

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    await RecentSearchesService().addSearch('la7play', query);
    if (!mounted) return;
    _searchController.clear();
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
    _searchController.text = query;
    await _search();
  }

  bool _canCreateAiAudiodescription(La7PlayItem item) =>
      _aiAudiodescriptionUnlocked && item.kind == La7PlayItemKind.media;

  Future<void> _createAiAudiodescription(La7PlayItem item) async {
    if (!mounted || !_canCreateAiAudiodescription(item)) return;
    try {
      final mediaUrl = await _service.resolveVod(item.target);
      if (!mounted) return;
      await createAiAudiodescriptionFromRemoteVideo(
        context,
        url: mediaUrl,
        title: item.title,
        headers: const <String, String>{
          'Referer': 'https://www.la7.it/',
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Sonarpad',
        },
      );
    } catch (error, stack) {
      await AppLogger.log(
        'LA7 Play AI audio description: preparation failed error=$error\n$stack',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).onlineVideoPreparationFailed,
            ),
          ),
        );
      }
    }
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
    final itemKey = 'la7play:${item.target}';
    if (!_mediaOpenGuard.tryAcquire(itemKey)) {
      await AppLogger.log(
        'MEDIA_OPEN_GUARD duplicate ignored source=la7play '
        'active=${_mediaOpenGuard.activeKey} requested=$itemKey',
      );
      return;
    }

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
        id: itemKey,
        publishedAt: DateTime.now(),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/la7play/player'),
          builder: (playerContext) => PodcastEpisodePlayerScreen(
            episode: episode,
            isVideoSupported: true,
            startWithVideo: true,
            extraActions: _canCreateAiAudiodescription(item)
                ? <PodcastPlayerExtraAction>[
                    PodcastPlayerExtraAction(
                      id: 'create_ai_audiodescription',
                      label: () => onlineCreateAiAudiodescriptionLabel,
                      icon: Icons.auto_awesome,
                      pauseBeforeOpen: true,
                      onPressed: () => createAiAudiodescriptionFromRemoteVideo(
                        playerContext,
                        url: mediaUrl,
                        title: item.title,
                        headers: const <String, String>{
                          'Referer': 'https://www.la7.it/',
                          'User-Agent':
                              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Sonarpad',
                        },
                      ),
                    ),
                  ]
                : const <PodcastPlayerExtraAction>[],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossibile aprire il contenuto: $error';
      });
    } finally {
      _mediaOpenGuard.release(itemKey);
    }
  }

  Widget _buildSharedBody() {
    final items = _page?.items ?? const <La7PlayItem>[];
    final rows = <AccessibleListRow>[
      if (_isRoot)
        AccessibleListRow(
          id: 'search_query',
          title: 'Cerca su LA7 Play',
          kind: 'textField',
          value: _searchController.text,
          placeholder: 'Nome del programma',
          textInputAction: 'search',
          onSubmitted: (_) => _search(),
        ),
      if (_isRoot)
        const AccessibleListRow(
          id: 'search',
          title: 'Cerca',
          kind: 'button',
        ),
      if (_isRoot)
        const AccessibleListRow(
          id: 'recent',
          title: 'Ricerche recenti',
          kind: 'button',
        ),
      if (_error != null)
        AccessibleListRow(id: 'error', title: _error!, kind: 'text'),
      for (var i = 0; i < items.length; i++)
        AccessibleListRow(
          id: 'item_$i',
          title: items[i].title,
          subtitle: items[i].description,
          actions: _canCreateAiAudiodescription(items[i])
              ? const <AccessibleCustomAction>[
                  AccessibleCustomAction(
                    id: 'create_ai_audiodescription',
                    label: onlineCreateAiAudiodescriptionLabel,
                  ),
                ]
              : const <AccessibleCustomAction>[],
          visualActions: _canCreateAiAudiodescription(items[i])
              ? const <AccessibleVisualAction>[
                  AccessibleVisualAction(
                    id: 'create_ai_audiodescription',
                    label: onlineCreateAiAudiodescriptionLabel,
                    icon: 'ai',
                  ),
                ]
              : const <AccessibleVisualAction>[],
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
      onEvent: (event) async {
        if (event.id == 'search_query' && event.type == 'textChanged') {
          _searchController.value = TextEditingValue(
            text: event.value?.toString() ?? '',
            selection: TextSelection.collapsed(
              offset: (event.value?.toString() ?? '').length,
            ),
          );
        } else if (event.id == 'search' && event.type == 'activate') {
          await _search();
        } else if (event.id == 'recent' && event.type == 'activate') {
          await _openRecentSearches();
        } else if (event.type == 'customAction' &&
            event.action == 'create_ai_audiodescription' &&
            event.id?.startsWith('item_') == true) {
          final index = int.tryParse(event.id!.substring(5));
          if (index != null && index >= 0 && index < items.length) {
            await _createAiAudiodescription(items[index]);
          }
        } else if (event.type == 'activate' &&
            event.id?.startsWith('item_') == true) {
          final index = int.tryParse(event.id!.substring(5));
          if (index != null && index >= 0 && index < items.length) {
            _openItem(items[index]);
          }
        }
      },
    );
  }

  Widget _buildFlutterBody() {
    final items = _page?.items ?? const <La7PlayItem>[];
    return Column(
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
                      labelText: 'Cerca su LA7 Play',
                      hintText: 'Nome del programma',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Cerca',
                  onPressed: _search,
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: 'Ricerche recenti',
                  onPressed: _openRecentSearches,
                ),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in items)
                Semantics(
                  customSemanticsActions: _canCreateAiAudiodescription(item)
                      ? <CustomSemanticsAction, VoidCallback>{
                          const CustomSemanticsAction(
                            label: onlineCreateAiAudiodescriptionLabel,
                          ): () => _createAiAudiodescription(item),
                        }
                      : null,
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                      item.kind == La7PlayItemKind.media
                          ? Icons.play_circle_fill
                          : Icons.folder,
                    ),
                    title: Text(item.title),
                    subtitle: item.description == null
                        ? null
                        : Text(item.description!),
                    trailing: _canCreateAiAudiodescription(item)
                        ? ExcludeSemantics(
                            child: IconButton(
                              tooltip: onlineCreateAiAudiodescriptionLabel,
                              icon: const Icon(Icons.auto_awesome),
                              onPressed: () => _createAiAudiodescription(item),
                            ),
                          )
                        : null,
                      onTap: () => _openItem(item),
                    ),
                  ),
                ),
              if (_error == null && !_loading && items.isEmpty && !_isRoot)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nessun contenuto disponibile.'),
                ),
            ],
          ),
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
