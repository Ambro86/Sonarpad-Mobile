import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../models/podcast.dart';
import '../services/document_library_service.dart';
import '../services/internet_archive_service.dart';
import 'podcast_episode_player_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

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
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [AccessibleListSection(rows: [
                AccessibleListRow(id: 'query', title: l10n.internetArchiveSearchLabel, kind: 'textField', value: _controller.text),
                AccessibleListRow(
                  id: 'source',
                  title: l10n.internetArchiveSourceLabel,
                  kind: 'picker',
                  value: _source.name,
                  options: [
                    AccessibleOption(value: InternetArchiveSource.oldTimeRadio.name, label: l10n.internetArchiveOldTimeRadio),
                    AccessibleOption(value: InternetArchiveSource.speeches.name, label: l10n.internetArchiveSpeeches),
                    AccessibleOption(value: InternetArchiveSource.liveMusic.name, label: l10n.internetArchiveLiveMusic),
                  ],
                ),
                AccessibleListRow(id: 'search', title: l10n.search, kind: 'button'),
              ])],
              onEvent: (event) {
                if (event.id == 'query' && event.type == 'textChanged') {
                  _controller.text = event.value?.toString() ?? '';
                } else if (event.id == 'source' && event.type == 'picker') {
                  final value = event.value?.toString();
                  final found = InternetArchiveSource.values.where((e) => e.name == value);
                  if (found.isNotEmpty) setState(() => _source = found.first);
                } else if (event.id == 'search' && event.type == 'activate') {
                  _search();
                }
              },
            )
          : ListView(
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
          if (useSharedAccessibleViewModel) {
            return UniversalAccessibleList(
              sections: [AccessibleListSection(rows: [
                for (var i = 0; i < _items.length; i++)
                  AccessibleListRow(id: 'item_$i', title: _items[i].title, subtitle: _items[i].creatorLabel),
                if (_hasMore) AccessibleListRow(id: 'more', title: _loadingMore ? l10n.loading : l10n.loadMore, kind: 'button', enabled: !_loadingMore),
              ])],
              onEvent: (event) {
                if (event.type != 'activate' || event.id == null) return;
                if (event.id == 'more') {
                  if (!_loadingMore) _load(more: true);
                } else {
                  final i = int.tryParse(event.id!.replaceFirst('item_', ''));
                  if (i != null && i < _items.length) _openItem(_items[i]);
                }
              },
            );
          }
          return ListView.separated(
            itemCount: _items.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
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
    _item = _loadItem();
  }

  Future<InternetArchiveItem> _loadItem() async {
    try {
      final refreshed = await _service.fetchItem(widget.item);
      if (refreshed.tracks.isNotEmpty || widget.item.tracks.isEmpty) {
        return refreshed;
      }
    } catch (_) {
      if (widget.item.tracks.isEmpty) rethrow;
    }
    return widget.item;
  }

  void _retryLoad() {
    setState(() => _item = _loadItem());
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
        path: item.metadataOnly().encodeForLibrary(),
        extension: 'archiveaudio',
        addedAt: DateTime.now(),
        parentId: widget.parentId,
      );
      await library.add(doc);
      if (!mounted) return;
      showStatusMessage(
        context,
        AppLocalizations.of(context).audioSavedInDocuments,
      );
    } catch (error) {
      if (!mounted) return;
      showStatusMessage(context, AppLocalizations.of(context).error(error));
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
            if (useSharedAccessibleViewModel) {
              return UniversalAccessibleList(
                sections: [AccessibleListSection(rows: [
                  AccessibleListRow(id: 'error', kind: 'text', title: l10n.error(snapshot.error!)),
                  AccessibleListRow(id: 'retry', title: l10n.retry, kind: 'button'),
                  if (widget.allowSave) AccessibleListRow(id: 'save', title: l10n.saveAudioInDocuments, kind: 'button', enabled: !_saving),
                ])],
                onEvent: (event) {
                  if (event.type != 'activate') return;
                  if (event.id == 'retry') _retryLoad();
                  if (event.id == 'save' && !_saving) _saveToLibrary(widget.item);
                },
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.error(snapshot.error!)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _retryLoad,
                  child: Text(l10n.retry),
                ),
                if (widget.allowSave) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed:
                        _saving ? null : () => _saveToLibrary(widget.item),
                    icon: const Icon(Icons.library_add),
                    label: Text(l10n.saveAudioInDocuments),
                  ),
                ],
              ],
            );
          }
          final item = snapshot.data ?? widget.item;
          if (useSharedAccessibleViewModel) {
            return UniversalAccessibleList(
              sections: [AccessibleListSection(rows: [
                AccessibleListRow(id: 'title', kind: 'header', title: item.title),
                if (item.creator.isNotEmpty) AccessibleListRow(id: 'creator', kind: 'text', title: item.creator),
                if (item.description.isNotEmpty) AccessibleListRow(id: 'description', kind: 'text', title: item.description),
                if (widget.allowSave) AccessibleListRow(id: 'save', title: _saving ? l10n.librivoxSaving : l10n.saveAudioInDocuments, kind: 'button', enabled: !_saving),
                if (item.tracks.isEmpty)
                  AccessibleListRow(id: 'empty', kind: 'text', title: l10n.noAudioTracksAvailable)
                else
                  for (var i = 0; i < item.tracks.length; i++)
                    AccessibleListRow(
                      id: 'track_$i',
                      title: item.tracks[i].title,
                      subtitle: item.tracks[i].length.isEmpty ? item.tracks[i].format : '${item.tracks[i].format} - ${item.tracks[i].length}',
                    ),
              ])],
              onEvent: (event) {
                if (event.type != 'activate' || event.id == null) return;
                if (event.id == 'save') {
                  if (!_saving) _saveToLibrary(item);
                } else if (event.id!.startsWith('track_')) {
                  final i = int.tryParse(event.id!.substring(6));
                  if (i != null && i < item.tracks.length) _playTrack(item, item.tracks[i]);
                }
              },
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item.title,
                  style: Theme.of(context).textTheme.headlineSmall),
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
