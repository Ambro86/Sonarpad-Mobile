import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/recording_feature_access.dart';
import '../services/tv_service.dart';
import '../utils/app_logger.dart';
import 'favorite_tvs_screen.dart';
import 'tv_channel_screen.dart';
import 'tv_recordings_screen.dart';
import '../utils/status_message.dart';
import '../widgets/tv_recording_schedule_action.dart';
import '../widgets/universal_accessible_view.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  static const _regionalCategoryPrefix = 'Regionali - ';

  final _settings = AppSettingsService();
  final _service = TvService();
  final _searchController = TextEditingController();

  List<TvChannel> _channels = [];
  Map<String, TvProgram> _currentPrograms = {};
  bool _loading = true;
  bool _isRecordingFeatureUnlocked = false;
  String? _error;
  String? _cacheWarning;

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
    final code = await _settings.getTvSecretCode();
    final recordingFeatureUnlocked = RecordingFeatureAccess.isCodeValid(code);
    try {
      final channelResult = await _service.loadChannelsWithCache(code);
      var currentPrograms = <String, TvProgram>{};
      try {
        currentPrograms = await _service.loadCurrentPrograms(
          code,
          channels: channelResult.channels,
        );
      } catch (e) {
        await AppLogger.log(
          'TV: programmi correnti non disponibili, mostro comunque la lista '
          'canali error=$e',
        );
      }
      if (!mounted) return;
      setState(() {
        _channels = channelResult.channels;
        _currentPrograms = currentPrograms;
        _cacheWarning = channelResult.cacheWarning;
        _isRecordingFeatureUnlocked = recordingFeatureUnlocked;
        _loading = false;
      });
      if (channelResult.fromCache && channelResult.cacheWarning != null) {
        showStatusMessage(
          context,
          channelResult.cacheWarning!,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openChannel(
    TvChannel channel, {
    bool autoPlay = false,
    bool autoStartRecording = false,
  }) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tv/channel'),
        builder: (_) => TvChannelScreen(
          channel: channel,
          autoPlay: autoPlay,
          autoStartRecording: autoStartRecording,
        ),
      ),
    );
  }

  Future<void> _openCategory(String category, List<TvChannel> channels) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tv/category'),
        builder: (_) => _TvCategoryScreen(
          category: category,
          channels: channels,
          currentPrograms: _currentPrograms,
          onOpenChannel: _openChannel,
          onPlayAndRecord: (channel) => _openChannel(
            channel,
            autoPlay: true,
            autoStartRecording: true,
          ),
          recordingFeatureUnlocked: _isRecordingFeatureUnlocked,
        ),
      ),
    );
  }

  Future<void> _openRegionalCategories(
    Map<String, List<TvChannel>> regions,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tv/regional'),
        builder: (_) => _TvRegionalScreen(
          regions: regions,
          currentPrograms: _currentPrograms,
          onOpenChannel: _openChannel,
          onPlayAndRecord: (channel) => _openChannel(
            channel,
            autoPlay: true,
            autoStartRecording: true,
          ),
          recordingFeatureUnlocked: _isRecordingFeatureUnlocked,
        ),
      ),
    );
  }

  Future<void> _openSearchResults() async {
    final query = _searchController.text.trim();
    final normalizedQuery = _normalizeTvSearchText(query);
    final results = normalizedQuery.isEmpty
        ? <TvChannel>[]
        : _channels
            .where((channel) => _matchesTvSearch(channel, normalizedQuery))
            .toList();

    final selectedChannel = await showDialog<TvChannel>(
      context: context,
      builder: (_) => _TvSearchResultsDialog(
        query: query,
        channels: results,
        currentPrograms: _currentPrograms,
        onPlayAndRecord: (channel) => _openChannel(
          channel,
          autoPlay: true,
          autoStartRecording: true,
        ),
        recordingFeatureUnlocked: _isRecordingFeatureUnlocked,
      ),
    );

    if (!mounted || selectedChannel == null) return;
    await _openChannel(selectedChannel);
  }

  bool _matchesTvSearch(TvChannel channel, String normalizedQuery) {
    return _normalizeTvSearchText(channel.name).contains(normalizedQuery) ||
        _normalizeTvSearchText(channel.category).contains(normalizedQuery) ||
        _normalizeTvSearchText(channel.tvgName).contains(normalizedQuery) ||
        _normalizeTvSearchText(channel.tvgId).contains(normalizedQuery);
  }

  String _normalizeTvSearchText(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TV in diretta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildList(),
    );
  }

  Widget _buildList() {
    final l10n = AppLocalizations.of(context);

    if (_channels.isEmpty) {
      return const Center(
          child: Text(
              'Nessun canale TV trovato. Controlla il codice inserito nelle impostazioni.'));
    }

    final map = <String, List<TvChannel>>{};
    final regionalMap = <String, List<TvChannel>>{};
    for (var ch in _channels) {
      if (ch.category.startsWith(_regionalCategoryPrefix)) {
        final region = ch.category.substring(_regionalCategoryPrefix.length);
        regionalMap.putIfAbsent(region, () => []).add(ch);
      } else {
        map.putIfAbsent(ch.category, () => []).add(ch);
      }
    }

    final categories = map.keys.toList();

    final listChildren = <Widget>[
      if (_cacheWarning != null)
        Padding(
          key: const ValueKey('tv_cache_warning'),
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _cacheWarning!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ),
        ),
      Padding(
        key: const ValueKey('tv_search_box'),
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: l10n.tvSearchFieldLabel,
                hintText: l10n.tvSearchFieldHint,
              ),
              onSubmitted: (_) => _openSearchResults(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                alignment: Alignment.centerLeft,
              ),
              onPressed: _openSearchResults,
              icon: const Icon(Icons.search),
              label: Text(
                l10n.tvSearchButton,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
      Padding(
        key: const ValueKey('tv_favorites_category'),
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            alignment: Alignment.centerLeft,
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/tv/favorites'),
                builder: (_) => FavoriteTvsScreen(
                  channels: _channels,
                  currentPrograms: _currentPrograms,
                  onOpenChannel: _openChannel,
                  onPlayAndRecord: (channel) => _openChannel(
                    channel,
                    autoPlay: true,
                    autoStartRecording: true,
                  ),
                  recordingFeatureUnlocked: _isRecordingFeatureUnlocked,
                ),
              ),
            );
          },
          icon: const Icon(Icons.favorite),
          label: const Text('TV preferite', style: TextStyle(fontSize: 20)),
        ),
      ),
      if (_isRecordingFeatureUnlocked)
        Padding(
        key: const ValueKey('tv_recordings_category'),
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            alignment: Alignment.centerLeft,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/tv/recordings'),
                builder: (_) => const TvRecordingsScreen(),
              ),
            );
          },
          icon: const Icon(Icons.videocam),
          label: Text(
            AppLocalizations.of(context).recordings,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    ];

    listChildren.addAll(categories.where((c) => map.containsKey(c)).map((c) {
      final channels = map[c]!;
      return Padding(
        key: ValueKey('tv_category_$c'),
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            alignment: Alignment.centerLeft,
          ),
          onPressed: () => _openCategory(c, channels),
          icon: const Icon(Icons.folder_open),
          label: Text(
            c,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );
    }));

    if (regionalMap.isNotEmpty) {
      listChildren.add(
        Padding(
          key: const ValueKey('tv_category_regionali'),
          padding: const EdgeInsets.only(bottom: 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () => _openRegionalCategories(regionalMap),
            icon: const Icon(Icons.folder_open),
            label: const Text(
              'Regionali',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      );
    }

    if (useSharedAccessibleViewModel) {
      final rows = <AccessibleListRow>[
        if (_cacheWarning != null)
          AccessibleListRow(
            id: '__warning__',
            title: _cacheWarning!,
            kind: 'text',
            enabled: false,
          ),
        AccessibleListRow(
          id: '__search_text__',
          title: l10n.tvSearchFieldLabel,
          kind: 'textField',
          value: _searchController.text,
          placeholder: l10n.tvSearchFieldHint,
          textInputAction: 'search',
          onSubmitted: (_) => _openSearchResults(),
        ),
        AccessibleListRow(id: '__search__', title: l10n.tvSearchButton, kind: 'button'),
        const AccessibleListRow(id: '__favorites__', title: 'TV preferite', kind: 'action'),
        if (_isRecordingFeatureUnlocked)
          AccessibleListRow(id: '__recordings__', title: l10n.recordings, kind: 'action'),
        ...categories.where((c) => map.containsKey(c)).map(
          (c) => AccessibleListRow(id: 'category:$c', title: c, kind: 'action'),
        ),
        if (regionalMap.isNotEmpty)
          const AccessibleListRow(id: '__regional__', title: 'Regionali', kind: 'action'),
      ];
      return UniversalAccessibleList(
        key: ValueKey('shared-tv-main-${rows.length}-${_channels.length}'),
        sections: [AccessibleListSection(rows: rows)],
        onEvent: (event) async {
          if (event.type == 'textChanged' && event.id == '__search_text__') {
            final value = event.value?.toString() ?? '';
            _searchController.value = TextEditingValue(
              text: value,
              selection: TextSelection.collapsed(offset: value.length),
            );
            return;
          }
          if (event.type != 'activate' || event.id == null) return;
          final id = event.id!;
          if (id == '__search__') {
            await _openSearchResults();
          } else if (id == '__favorites__') {
            await Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/tv/favorites'),
                builder: (_) => FavoriteTvsScreen(
                  channels: _channels,
                  currentPrograms: _currentPrograms,
                  onOpenChannel: _openChannel,
                  onPlayAndRecord: (channel) => _openChannel(
                    channel,
                    autoPlay: true,
                    autoStartRecording: true,
                  ),
                  recordingFeatureUnlocked: _isRecordingFeatureUnlocked,
                ),
              ),
            );
          } else if (id == '__recordings__' &&
              _isRecordingFeatureUnlocked) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/tv/recordings'),
                builder: (_) => const TvRecordingsScreen(),
              ),
            );
          } else if (id == '__regional__') {
            _openRegionalCategories(regionalMap);
          } else if (id.startsWith('category:')) {
            final category = id.substring('category:'.length);
            final channels = map[category];
            if (channels != null) _openCategory(category, channels);
          }
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: listChildren,
    );
  }
}

class _TvRegionalScreen extends StatelessWidget {
  const _TvRegionalScreen({
    required this.regions,
    required this.currentPrograms,
    required this.onOpenChannel,
    required this.onPlayAndRecord,
    required this.recordingFeatureUnlocked,
  });

  final Map<String, List<TvChannel>> regions;
  final Map<String, TvProgram> currentPrograms;
  final ValueChanged<TvChannel> onOpenChannel;
  final ValueChanged<TvChannel> onPlayAndRecord;
  final bool recordingFeatureUnlocked;

  void _openRegion(BuildContext context, String region) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tv/regional/category'),
        builder: (_) => _TvCategoryScreen(
          category: region,
          channels: regions[region] ?? const [],
          currentPrograms: currentPrograms,
          onOpenChannel: onOpenChannel,
          onPlayAndRecord: onPlayAndRecord,
          recordingFeatureUnlocked: recordingFeatureUnlocked,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regionNames = regions.keys.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Regionali')),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: regionNames
                      .map((region) => AccessibleListRow(
                            id: region,
                            title: region,
                            kind: 'action',
                          ))
                      .toList(),
                ),
              ],
              onEvent: (event) {
                if (event.type == 'activate' && event.id != null) {
                  _openRegion(context, event.id!);
                }
              },
            )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: regionNames.length,
        itemBuilder: (context, index) {
          final region = regionNames[index];
          return Padding(
            key: ValueKey('tv_region_row_$region'),
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              key: ValueKey('tv_region_button_$region'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                alignment: Alignment.centerLeft,
              ),
              onPressed: () => _openRegion(context, region),
              icon: const Icon(Icons.folder_open),
              label: Text(
                region,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TvCategoryScreen extends StatefulWidget {
  const _TvCategoryScreen({
    required this.category,
    required this.channels,
    required this.currentPrograms,
    required this.onOpenChannel,
    required this.onPlayAndRecord,
    required this.recordingFeatureUnlocked,
  });

  final String category;
  final List<TvChannel> channels;
  final Map<String, TvProgram> currentPrograms;
  final ValueChanged<TvChannel> onOpenChannel;
  final ValueChanged<TvChannel> onPlayAndRecord;
  final bool recordingFeatureUnlocked;

  @override
  State<_TvCategoryScreen> createState() => _TvCategoryScreenState();
}

class _TvCategoryScreenState extends State<_TvCategoryScreen> {
  final _service = TvService();
  List<TvChannel> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _service.loadFavorites();
    if (!mounted) return;
    setState(() => _favorites = favorites);
  }

  TvProgram? _currentProgramFor(TvChannel channel) =>
      _currentProgramForChannel(_service, widget.currentPrograms, channel);

  bool _isFavorite(TvChannel channel) =>
      _favorites.any((favorite) =>
          _service.isSameFavoriteChannel(favorite, channel));

  Future<void> _toggleFavorite(TvChannel channel) async {
    final l10n = AppLocalizations.of(context);
    final favs = await _service.loadFavorites();
    final wasFavorite = favs.any((favorite) =>
        _service.isSameFavoriteChannel(favorite, channel));
    final next = wasFavorite
        ? favs
            .where((favorite) =>
                !_service.isSameFavoriteChannel(favorite, channel))
            .toList()
        : [...favs, channel];
    await _service.saveFavorites(next);
    if (!mounted) return;
    setState(() => _favorites = next);
    final message = wasFavorite
        ? l10n.radioFavoriteRemoved(channel.name)
        : l10n.radioFavoriteAdded(channel.name);
    showStatusMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              key: ValueKey('shared-tv-category-${widget.category}-${widget.channels.length}'),
              sections: [
                AccessibleListSection(
                  rows: widget.channels.map((channel) {
                    final program = _currentProgramFor(channel);
                    final favorite = _isFavorite(channel);
                    final title = program?.title.trim();
                    return AccessibleListRow(
                      id: channel.name,
                      title: channel.name,
                      subtitle: title != null && title.isNotEmpty
                          ? AppLocalizations.of(context).tvNowOnAir(title)
                          : null,
                      accessibilityLabel: title != null && title.isNotEmpty
                          ? '${channel.name}. ${AppLocalizations.of(context).tvNowOnAir(title)}'
                          : channel.name,
                      hint: AppLocalizations.of(context).tvOpenChannelHint,
                      kind: 'action',
                      actions: [
                        AccessibleCustomAction(
                          id: 'favorite',
                          label: favorite
                              ? AppLocalizations.of(context).radioRemoveFavorite
                              : AppLocalizations.of(context).radioAddFavorite,
                        ),
                        if (widget.recordingFeatureUnlocked)
                          AccessibleCustomAction(
                            id: 'play_record',
                            label: AppLocalizations.of(context).playAndRecord,
                          ),
                        if (widget.recordingFeatureUnlocked)
                          AccessibleCustomAction(
                            id: 'schedule_recording',
                            label: AppLocalizations.of(context).radioScheduleDialogTitle,
                          ),
                      ],
                      visualActions: [
                        if (widget.recordingFeatureUnlocked)
                          AccessibleVisualAction(
                            id: 'play_record',
                            label: AppLocalizations.of(context).playAndRecord,
                            icon: 'record',
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ],
              onEvent: (event) async {
                final id = event.id;
                if (id == null) return;
                final index = widget.channels.indexWhere((e) => e.name == id);
                if (index < 0) return;
                final channel = widget.channels[index];
                if (event.type == 'activate') {
                  widget.onOpenChannel(channel);
                } else if (event.type == 'customAction' && event.action == 'favorite') {
                  await _toggleFavorite(channel);
                } else if (event.type == 'customAction' &&
                    event.action == 'play_record' &&
                    widget.recordingFeatureUnlocked) {
                  widget.onPlayAndRecord(channel);
                } else if (event.type == 'customAction' &&
                    event.action == 'schedule_recording' &&
                    widget.recordingFeatureUnlocked) {
                  await showTvScheduleRecordingAction(context, channel);
                }
              },
            )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.channels.length,
        itemBuilder: (context, index) {
          final channel = widget.channels[index];
          return _TvChannelButton(
            key: ValueKey('tv_channel_row_${channel.name}'),
            channel: channel,
            currentProgram: _currentProgramFor(channel),
            isFavorite: _isFavorite(channel),
            onOpen: () => widget.onOpenChannel(channel),
            onToggleFavorite: () => _toggleFavorite(channel),
            onPlayAndRecord: widget.recordingFeatureUnlocked
                ? () => widget.onPlayAndRecord(channel)
                : null,
            onScheduleRecording: widget.recordingFeatureUnlocked
                ? () => showTvScheduleRecordingAction(context, channel)
                : null,
          );
        },
      ),
    );
  }
}

class _TvSearchResultsDialog extends StatefulWidget {
  const _TvSearchResultsDialog({
    required this.query,
    required this.channels,
    required this.currentPrograms,
    required this.onPlayAndRecord,
    required this.recordingFeatureUnlocked,
  });

  final String query;
  final List<TvChannel> channels;
  final Map<String, TvProgram> currentPrograms;
  final ValueChanged<TvChannel> onPlayAndRecord;
  final bool recordingFeatureUnlocked;

  @override
  State<_TvSearchResultsDialog> createState() => _TvSearchResultsDialogState();
}

class _TvSearchResultsDialogState extends State<_TvSearchResultsDialog> {
  final _service = TvService();
  List<TvChannel> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _service.loadFavorites();
    if (!mounted) return;
    setState(() => _favorites = favorites);
  }

  TvProgram? _currentProgramFor(TvChannel channel) =>
      _currentProgramForChannel(_service, widget.currentPrograms, channel);

  bool _isFavorite(TvChannel channel) =>
      _favorites.any((favorite) =>
          _service.isSameFavoriteChannel(favorite, channel));

  Future<void> _toggleFavorite(TvChannel channel) async {
    final l10n = AppLocalizations.of(context);
    final favs = await _service.loadFavorites();
    final wasFavorite = favs.any((favorite) =>
        _service.isSameFavoriteChannel(favorite, channel));
    final next = wasFavorite
        ? favs
            .where((favorite) =>
                !_service.isSameFavoriteChannel(favorite, channel))
            .toList()
        : [...favs, channel];
    await _service.saveFavorites(next);
    if (!mounted) return;
    setState(() => _favorites = next);
    final message = wasFavorite
        ? l10n.radioFavoriteRemoved(channel.name)
        : l10n.radioFavoriteAdded(channel.name);
    showStatusMessage(context, message);
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = widget.query.trim();

    if (query.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(l10n.tvSearchEmptyQuery),
      );
    }

    if (widget.channels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(l10n.tvSearchNoResults(query)),
      );
    }

    return SizedBox(
      height: 420,
      child: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              key: ValueKey('shared-tv-search-${widget.channels.length}'),
              sections: [
                AccessibleListSection(
                  rows: widget.channels.map((channel) {
                    final program = _currentProgramFor(channel);
                    final favorite = _isFavorite(channel);
                    final title = program?.title.trim();
                    return AccessibleListRow(
                      id: channel.name,
                      title: channel.name,
                      subtitle: title != null && title.isNotEmpty
                          ? l10n.tvNowOnAir(title)
                          : null,
                      kind: 'action',
                      actions: [
                        AccessibleCustomAction(
                          id: 'favorite',
                          label: favorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
                        ),
                        if (widget.recordingFeatureUnlocked)
                          AccessibleCustomAction(
                            id: 'play_record',
                            label: l10n.playAndRecord,
                          ),
                        if (widget.recordingFeatureUnlocked)
                          AccessibleCustomAction(
                            id: 'schedule_recording',
                            label: l10n.radioScheduleDialogTitle,
                          ),
                      ],
                      visualActions: [
                        if (widget.recordingFeatureUnlocked)
                          AccessibleVisualAction(
                            id: 'play_record',
                            label: l10n.playAndRecord,
                            icon: 'record',
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ],
              onEvent: (event) async {
                final id = event.id;
                if (id == null) return;
                final index = widget.channels.indexWhere((e) => e.name == id);
                if (index < 0) return;
                final channel = widget.channels[index];
                if (event.type == 'activate') {
                  Navigator.of(context).pop(channel);
                } else if (event.type == 'customAction' && event.action == 'favorite') {
                  await _toggleFavorite(channel);
                } else if (event.type == 'customAction' &&
                    event.action == 'play_record' &&
                    widget.recordingFeatureUnlocked) {
                  Navigator.of(context).pop();
                  widget.onPlayAndRecord(channel);
                } else if (event.type == 'customAction' &&
                    event.action == 'schedule_recording' &&
                    widget.recordingFeatureUnlocked) {
                  await showTvScheduleRecordingAction(context, channel);
                }
              },
            )
          : ListView.builder(
        shrinkWrap: true,
        itemCount: widget.channels.length,
        itemBuilder: (context, index) {
          final channel = widget.channels[index];
          return _TvChannelButton(
            key: ValueKey('tv_search_result_${channel.name}'),
            channel: channel,
            currentProgram: _currentProgramFor(channel),
            isFavorite: _isFavorite(channel),
            onOpen: () => Navigator.of(context).pop(channel),
            onToggleFavorite: () => _toggleFavorite(channel),
            onPlayAndRecord: widget.recordingFeatureUnlocked
                ? () {
                    Navigator.of(context).pop();
                    widget.onPlayAndRecord(channel);
                  }
                : null,
            onScheduleRecording: widget.recordingFeatureUnlocked
                ? () => showTvScheduleRecordingAction(context, channel)
                : null,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.tvSearchResults),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}

class _TvChannelButton extends StatelessWidget {
  const _TvChannelButton({
    super.key,
    required this.channel,
    required this.currentProgram,
    required this.isFavorite,
    required this.onOpen,
    required this.onToggleFavorite,
    this.onPlayAndRecord,
    this.onScheduleRecording,
  });

  final TvChannel channel;
  final TvProgram? currentProgram;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onPlayAndRecord;
  final VoidCallback? onScheduleRecording;

  String _channelLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = currentProgram?.title.trim();
    if (title != null && title.isNotEmpty) {
      return '${channel.name}. ${l10n.tvNowOnAir(title)}';
    }
    return channel.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semanticsLabel = _channelLabel(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MergeSemantics(
        child: Semantics(
          container: true,
          button: true,
          enabled: true,
          label: semanticsLabel,
          hint: l10n.tvOpenChannelHint,
          onTap: onOpen,
          customSemanticsActions: {
            CustomSemanticsAction(
              label: isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
            ): onToggleFavorite,
            CustomSemanticsAction(
              label: l10n.playAndRecord,
            ): ?onPlayAndRecord,
            CustomSemanticsAction(
              label: l10n.radioScheduleDialogTitle,
            ): ?onScheduleRecording,
          },
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onPressed: onOpen,
                    child: Row(
                      children: [
                        const Icon(Icons.tv),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                channel.name,
                                style: const TextStyle(fontSize: 20),
                              ),
                              if (currentProgram != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  l10n.tvNowOnAir(currentProgram!.title),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withValues(alpha: 0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onPlayAndRecord != null)
                  IconButton(
                    tooltip: l10n.playAndRecord,
                    onPressed: onPlayAndRecord,
                    icon: const Icon(Icons.fiber_manual_record),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

TvProgram? _currentProgramForChannel(
  TvService service,
  Map<String, TvProgram> currentPrograms,
  TvChannel channel,
) {
  for (final key in service.guideLookupKeys(channel)) {
    final program = currentPrograms[key];
    if (program != null) return program;
  }
  return null;
}
