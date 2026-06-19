import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../services/tv_service.dart';
import '../utils/status_message.dart';

class FavoriteTvsScreen extends StatefulWidget {
  const FavoriteTvsScreen({
    super.key,
    required this.currentPrograms,
    required this.onOpenChannel,
  });

  final Map<String, TvProgram> currentPrograms;
  final ValueChanged<TvChannel> onOpenChannel;

  @override
  State<FavoriteTvsScreen> createState() => _FavoriteTvsScreenState();
}

class _FavoriteTvsScreenState extends State<FavoriteTvsScreen> {
  final _service = TvService();
  List<TvChannel> _favorites = [];
  bool _loading = true;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await _service.loadFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = favs;
      _loading = false;
    });
  }

  Future<void> _removeFromFavorites(TvChannel channel) async {
    final favs = await _service.loadFavorites();
    favs.removeWhere((c) => c.name == channel.name);
    await _service.saveFavorites(favs);
    if (!mounted) return;
    showStatusMessage(context, '${channel.name} rimosso dai preferiti');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TV preferite')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(
                  child: Text(
                    'Nessun canale TV preferito.',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final channel = _favorites[index];
                    final currentProgram = _currentProgramFor(channel);
                    final semanticsLabel = _channelLabel(
                      channel,
                      currentProgram,
                    );

                    return Padding(
                      key: ValueKey('favorite_tv_channel_row_${channel.name}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MergeSemantics(
                        child: Semantics(
                          key: ValueKey(
                              'favorite_tv_channel_semantics_${channel.name}'),
                          container: true,
                          button: true,
                          enabled: true,
                          label: semanticsLabel,
                          hint: 'Tocca per aprire il canale TV',
                          onTap: () => widget.onOpenChannel(channel),
                          customSemanticsActions: {
                            const CustomSemanticsAction(
                                    label: 'Rimuovi dai preferiti'):
                                () => _removeFromFavorites(channel),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
