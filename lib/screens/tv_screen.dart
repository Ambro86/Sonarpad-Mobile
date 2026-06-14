import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/tv_service.dart';
import 'favorite_tvs_screen.dart';
import 'tv_channel_screen.dart';
import 'tv_recordings_screen.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  static const _regionalCategoryPrefix = 'Regionali - ';

  final _settings = AppSettingsService();
  final _service = TvService();

  List<TvChannel> _channels = [];
  Map<String, TvProgram> _currentPrograms = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final code = await _settings.getTvSecretCode();
    try {
      final channels = await _service.loadChannels(code);
      final currentPrograms = await _service.loadCurrentPrograms(code);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _currentPrograms = currentPrograms;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openChannel(TvChannel channel) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tv/channel'),
        builder: (_) => TvChannelScreen(channel: channel),
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
        ),
      ),
    );
  }

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
                  currentPrograms: _currentPrograms,
                  onOpenChannel: _openChannel,
                ),
              ),
            );
          },
          icon: const Icon(Icons.favorite),
          label: const Text('TV preferite', style: TextStyle(fontSize: 20)),
        ),
      ),
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
  });

  final Map<String, List<TvChannel>> regions;
  final Map<String, TvProgram> currentPrograms;
  final ValueChanged<TvChannel> onOpenChannel;

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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regionNames = regions.keys.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Regionali')),
      body: ListView.builder(
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
  });

  final String category;
  final List<TvChannel> channels;
  final Map<String, TvProgram> currentPrograms;
  final ValueChanged<TvChannel> onOpenChannel;

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

  TvProgram? _currentProgramFor(TvChannel channel) {
    for (final key in _service.guideLookupKeys(channel)) {
      final program = widget.currentPrograms[key];
      if (program != null) return program;
    }
    return null;
  }

  String _channelLabel(TvChannel channel, TvProgram? currentProgram) {
    final title = currentProgram?.title.trim();
    if (title != null && title.isNotEmpty) {
      return '${channel.name}. Ora in onda: $title';
    }
    return channel.name;
  }

  bool _isFavorite(TvChannel channel) =>
      _favorites.any((favorite) => favorite.name == channel.name);

  Future<void> _toggleFavorite(TvChannel channel) async {
    final l10n = AppLocalizations.of(context);
    final favs = await _service.loadFavorites();
    final wasFavorite = favs.any((c) => c.name == channel.name);
    final next = wasFavorite
        ? favs.where((c) => c.name != channel.name).toList()
        : [...favs, channel];
    await _service.saveFavorites(next);
    if (!mounted) return;
    setState(() => _favorites = next);
    final message = wasFavorite
        ? l10n.radioFavoriteRemoved(channel.name)
        : l10n.radioFavoriteAdded(channel.name);
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      TextDirection.ltr,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.channels.length,
        itemBuilder: (context, index) {
          final channel = widget.channels[index];
          final currentProgram = _currentProgramFor(channel);
          final semanticsLabel = _channelLabel(channel, currentProgram);
          final isFavorite = _isFavorite(channel);

          return Padding(
            key: ValueKey('tv_channel_row_${channel.name}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: MergeSemantics(
              child: Semantics(
                key: ValueKey('tv_channel_semantics_${channel.name}'),
                container: true,
                button: true,
                enabled: true,
                label: semanticsLabel,
                hint: 'Tocca per aprire il canale TV',
                onTap: () => widget.onOpenChannel(channel),
                customSemanticsActions: {
                  CustomSemanticsAction(
                    label: isFavorite
                        ? AppLocalizations.of(context).radioRemoveFavorite
                        : AppLocalizations.of(context).radioAddFavorite,
                  ): () => _toggleFavorite(channel),
                },
                child: ExcludeSemantics(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    onPressed: () => widget.onOpenChannel(channel),
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
                                  'Ora in onda: ${currentProgram.title}',
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
              ),
            ),
          );
        },
      ),
    );
  }
}
