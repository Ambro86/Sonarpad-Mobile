import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../models/podcast.dart';
import '../services/document_library_service.dart';
import '../services/internet_archive_service.dart';
import 'podcast_episode_player_screen.dart';

class InternetArchiveScreen extends StatefulWidget {
  final String? parentId;

  const InternetArchiveScreen({super.key, this.parentId});

  @override
  State<InternetArchiveScreen> createState() => _InternetArchiveScreenState();
}

class InternetArchiveSavedItemScreen extends StatelessWidget {
  final InternetArchiveItem item;

  const InternetArchiveSavedItemScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return _InternetArchiveItemScreen(
      item: item,
      parentId: null,
      allowSave: false,
    );
  }
}

class _InternetArchiveScreenState extends State<InternetArchiveScreen> {
  final _controller = TextEditingController();
  InternetArchiveSource _source = InternetArchiveSource.oldTimeRadio;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/internet_archive/results'),
        builder: (_) => _InternetArchiveResultsScreen(
          query: query,
          source: _source,
          parentId: widget.parentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.internetArchiveTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: l10n.internetArchiveSearchLabel,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<InternetArchiveSource>(
            initialValue: _source,
            decoration: InputDecoration(
              labelText: l10n.internetArchiveSourceLabel,
            ),
            items: [
              DropdownMenuItem(
                value: InternetArchiveSource.oldTimeRadio,
                child: Text(l10n.internetArchiveOldTimeRadio),
              ),
              DropdownMenuItem(
                value: InternetArchiveSource.speeches,
                child: Text(l10n.internetArchiveSpeeches),
              ),
              DropdownMenuItem(
                value: InternetArchiveSource.liveMusic,
                child: Text(l10n.internetArchiveLiveMusic),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _source = value);
            },
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _search, child: Text(l10n.search)),
        ],
      ),
    );
  }
}

class _InternetArchiveResultsScreen extends StatefulWidget {
  final String query;
  final InternetArchiveSource source;
  final String? parentId;

  const _InternetArchiveResultsScreen({
    required this.query,
    required this.source,
    required this.parentId,
  });

  @override
  State<_InternetArchiveResultsScreen> createState() =>
      _InternetArchiveResultsScreenState();
}

class _InternetArchiveResultsScreenState
    extends State<_InternetArchiveResultsScreen> {
  final _service = InternetArchiveService();
  final _items = <InternetArchiveItem>[];
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  static const _rows = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _page = 1;
      }
    });
    try {
      final page = await _service.searchItems(
        source: widget.source,
        query: widget.query,
        page: more ? _page + 1 : 1,
        rows: _rows,
      );
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(page.items);
        if (more) _page += 1;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _openItem(InternetArchiveItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/internet_archive/item'),
        builder: (_) => _InternetArchiveItemScreen(
          item: item,
          parentId: widget.parentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchResults)),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.loading,
              ),
            );
          }
          if (_error != null) {
            return Center(child: Text(l10n.error(_error!)));
          }
          if (_items.isEmpty) {
            return Center(child: Text(l10n.internetArchiveNoItemsFound));
          }
          return ListView.separated(
            itemCount: _items.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index >= _items.length) {
                return ListTile(
                  title: Text(_loadingMore ? l10n.loading : l10n.loadMore),
                  trailing: _loadingMore
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(Icons.expand_more),
                  onTap: _loadingMore ? null : () => _load(more: true),
                );
              }
              final item = _items[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.creatorLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openItem(item),
              );
            },
          );
        },
      ),
    );
  }
}

class _InternetArchiveItemScreen extends StatefulWidget {
  final InternetArchiveItem item;
  final String? parentId;
  final bool allowSave;

  const _InternetArchiveItemScreen({
    required this.item,
    required this.parentId,
    this.allowSave = true,
  });

  @override
  State<_InternetArchiveItemScreen> createState() =>
      _InternetArchiveItemScreenState();
}

class _InternetArchiveItemScreenState
    extends State<_InternetArchiveItemScreen> {
  final _service = InternetArchiveService();
  late Future<InternetArchiveItem> _item;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item.tracks.isEmpty
        ? _service.fetchItem(widget.item)
        : Future.value(widget.item);
  }

  void _playTrack(InternetArchiveItem item, InternetArchiveTrack track) {
    final episode = PodcastEpisode(
      title: track.title,
      description: item.title,
      audioUrl: track.audioUrl,
      id: 'archive:${item.identifier}:${track.fileName}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/internet_archive/player'),
        builder: (_) => PodcastEpisodePlayerScreen(episode: episode),
      ),
    );
  }

  Future<void> _saveToLibrary(InternetArchiveItem item) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final library = DocumentLibraryService();
      await library.load();
      final doc = DocumentItem(
        id: 'archive_${item.identifier}_'
            '${DateTime.now().microsecondsSinceEpoch}',
        name: item.title,
        path: item.encodeForLibrary(),
        extension: 'archiveaudio',
        addedAt: DateTime.now(),
        parentId: widget.parentId,
      );
      await library.add(doc);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).audioSavedInDocuments),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).error(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: FutureBuilder<InternetArchiveItem>(
        future: _item,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.loading,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.error(snapshot.error!)));
          }
          final item = snapshot.data ?? widget.item;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
              if (item.creator.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.creator),
              ],
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(item.description),
              ],
              const SizedBox(height: 16),
              if (widget.allowSave) ...[
                FilledButton.icon(
                  onPressed: _saving ? null : () => _saveToLibrary(item),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.library_add),
                  label: Text(_saving
                      ? l10n.librivoxSaving
                      : l10n.saveAudioInDocuments),
                ),
                const SizedBox(height: 16),
              ],
              if (item.tracks.isEmpty)
                Text(l10n.noAudioTracksAvailable)
              else
                for (final track in item.tracks)
                  ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: Text(track.title),
                    subtitle: track.length.isEmpty
                        ? Text(track.format)
                        : Text('${track.format} - ${track.length}'),
                    onTap: () => _playTrack(item, track),
                  ),
            ],
          );
        },
      ),
    );
  }
}
