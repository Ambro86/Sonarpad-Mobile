import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../services/app_settings_service.dart';
import '../services/tv_service.dart';
import 'favorite_tvs_screen.dart';
import 'tv_channel_screen.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
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
      final channels = _service.loadChannels(code);
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
        _error = 'Errore durante la decodifica dei canali: $e';
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
    for (var ch in _channels) {
      map.putIfAbsent(ch.category, () => []).add(ch);
    }

    final categories = ['Rai', 'Mediaset', 'Regionali', 'Altri'];

    final listChildren = <Widget>[
      Padding(
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
    ];

    listChildren.addAll(categories.where((c) => map.containsKey(c)).map((c) {
      final channels = map[c]!;
      return Padding(
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: listChildren,
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

  Future<void> _addToFavorites(TvChannel channel) async {
    final favs = await _service.loadFavorites();
    if (!favs.any((c) => c.name == channel.name)) {
      favs.add(channel);
      await _service.saveFavorites(favs);
      if (!mounted) return;
      SemanticsService.announce(
          '${channel.name} aggiunto ai preferiti', TextDirection.ltr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${channel.name} aggiunto ai preferiti')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${channel.name} è già nei preferiti')),
      );
    }
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
          final normalizedChannelName =
              TvService().normalizeChannelName(channel.name);
          final currentProgram = widget.currentPrograms[normalizedChannelName];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MergeSemantics(
              child: Semantics(
                label: currentProgram != null
                    ? '${channel.name}. Ora in onda: ${currentProgram.title}'
                    : channel.name,
                customSemanticsActions: {
                  CustomSemanticsAction(label: 'Aggiungi ai preferiti'):
                      () => _addToFavorites(channel),
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
                                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
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
