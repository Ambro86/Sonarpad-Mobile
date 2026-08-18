import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../models/podcast.dart';
import '../services/document_library_service.dart';
import '../services/librivox_service.dart';
import 'podcast_episode_player_screen.dart';
import '../utils/status_message.dart';
import 'package:sonarpad_mobile_starter/utils/accessibility_list_behavior.dart';

class LibrivoxScreen extends StatefulWidget {
  final String? parentId;

  const LibrivoxScreen({super.key, this.parentId});

  @override
  State<LibrivoxScreen> createState() => _LibrivoxScreenState();
}

class LibrivoxSavedBookScreen extends StatelessWidget {
  final LibrivoxBook book;

  const LibrivoxSavedBookScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return _LibrivoxBookScreen(book: book, parentId: null, allowSave: false);
  }
}

class _LibrivoxScreenState extends State<LibrivoxScreen> {
  final _controller = TextEditingController();

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
        settings: const RouteSettings(name: '/librivox/results'),
        builder: (_) => _LibrivoxResultsScreen(
          query: query,
          parentId: widget.parentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('LibriVox')),
      body: ListView(
        scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: l10n.librivoxSearchLabel,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _search,
            child: Text(l10n.search),
          ),
        ],
      ),
    );
  }
}

class _LibrivoxResultsScreen extends StatefulWidget {
  final String query;
  final String? parentId;

  const _LibrivoxResultsScreen({required this.query, required this.parentId});

  @override
  State<_LibrivoxResultsScreen> createState() => _LibrivoxResultsScreenState();
}

class _LibrivoxResultsScreenState extends State<_LibrivoxResultsScreen> {
  final _service = LibrivoxService();
  final _books = <LibrivoxBook>[];
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _offset = 0;
  static const _limit = 50;

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
        _offset = 0;
      }
    });
    try {
      final page = await _service.searchBooks(
        widget.query,
        offset: more ? _offset : 0,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        if (!more) _books.clear();
        _books.addAll(page.books);
        _offset = _books.length;
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

  void _openBook(LibrivoxBook book) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/librivox/book'),
        builder: (_) => _LibrivoxBookScreen(
          book: book,
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
          if (_books.isEmpty) {
            return Center(child: Text(l10n.noLibrivoxAudiobooksFound));
          }
          return ListView.separated(
            scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
            itemCount: _books.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index >= _books.length) {
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
              final book = _books[index];
              return ListTile(
                title: Text(book.title),
                subtitle: Text(book.authorLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openBook(book),
              );
            },
          );
        },
      ),
    );
  }
}

class _LibrivoxBookScreen extends StatefulWidget {
  final LibrivoxBook book;
  final String? parentId;
  final bool allowSave;

  const _LibrivoxBookScreen({
    required this.book,
    required this.parentId,
    this.allowSave = true,
  });

  @override
  State<_LibrivoxBookScreen> createState() => _LibrivoxBookScreenState();
}

class _LibrivoxBookScreenState extends State<_LibrivoxBookScreen> {
  final _service = LibrivoxService();
  late Future<LibrivoxBook> _book;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book.sections.isEmpty
        ? _service.fetchBook(widget.book.id)
        : Future.value(widget.book);
  }

  void _playTrack(LibrivoxBook book, LibrivoxTrack track) {
    final title = track.number > 0
        ? '${track.number}. ${track.title}'
        : track.title;
    final episode = PodcastEpisode(
      title: title,
      description: book.title,
      audioUrl: track.listenUrl,
      id: 'librivox:${book.id}:${track.id}:${track.listenUrl}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/librivox/player'),
        builder: (_) => PodcastEpisodePlayerScreen(episode: episode),
      ),
    );
  }

  Future<void> _saveToLibrary(LibrivoxBook book) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final service = DocumentLibraryService();
      await service.load();
      final doc = DocumentItem(
        id: 'librivox_${book.id}_${DateTime.now().microsecondsSinceEpoch}',
        name: book.title,
        path: book.encodeForLibrary(),
        extension: 'librivox',
        addedAt: DateTime.now(),
        parentId: widget.parentId,
      );
      await service.add(doc);
      if (!mounted) return;
            showStatusMessage(context, AppLocalizations.of(context).librivoxAudiobookSaved);
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
      appBar: AppBar(title: Text(widget.book.title)),
      body: FutureBuilder<LibrivoxBook>(
        future: _book,
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
          final book = snapshot.data ?? widget.book;
          return ListView(
            scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(book.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(book.authorLabel),
              if (book.language.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l10n.sourceLanguageValue(book.language)),
              ],
              if (book.totalTime.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l10n.sourceDurationValue(book.totalTime)),
              ],
              if (book.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(book.description),
              ],
              const SizedBox(height: 16),
              if (widget.allowSave) ...[
                FilledButton.icon(
                  onPressed: _saving ? null : () => _saveToLibrary(book),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.library_add),
                  label: Text(_saving
                      ? l10n.librivoxSaving
                      : l10n.librivoxSaveAudiobook),
                ),
                const SizedBox(height: 16),
              ],
              if (book.sections.isEmpty)
                Text(l10n.librivoxNoAudioTracks)
              else
                for (final track in book.sections)
                  ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: Text(
                      track.number > 0
                          ? '${track.number}. ${track.title}'
                          : track.title,
                    ),
                    subtitle:
                        track.playTime.isEmpty ? null : Text(track.playTime),
                    onTap: () => _playTrack(book, track),
                  ),
            ],
          );
        },
      ),
    );
  }
}
