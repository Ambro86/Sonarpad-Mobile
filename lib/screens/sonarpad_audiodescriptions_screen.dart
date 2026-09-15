import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/sonarpad_audiodescriptions_service.dart';
import '../utils/status_message.dart';
import '../widgets/media_preservation_progress_dialog.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';

const _sonarpadAudiodescriptionsTitle = 'Audiodescrizioni Sonarpad';
const _allSonarpadAudiodescriptionsTitle =
    'Tutte le audiodescrizioni Sonarpad';

class SonarpadAudiodescriptionsScreen extends StatefulWidget {
  const SonarpadAudiodescriptionsScreen({super.key});

  @override
  State<SonarpadAudiodescriptionsScreen> createState() =>
      _SonarpadAudiodescriptionsScreenState();
}

class _SonarpadAudiodescriptionsScreenState
    extends State<SonarpadAudiodescriptionsScreen> {
  final _service = SonarpadAudiodescriptionsService();
  final _settings = AppSettingsService();
  final _searchController = TextEditingController();

  List<SonarpadAudiodescriptionItem> _items = const [];
  bool _loading = true;
  String _error = '';

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

  Future<String> _code() async => (await _settings.getTvSecretCode()).trim();

  Future<void> _load() async {
    try {
      final items = await _service.fetchRecent(await _code());
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(
          name: '/sonarpad_audiodescriptions/search',
        ),
        builder: (_) => SonarpadAudiodescriptionsSearchScreen(query: trimmed),
      ),
    );
  }

  void _openAll() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(
          name: '/sonarpad_audiodescriptions/all',
        ),
        builder: (_) => const SonarpadAudiodescriptionsAllScreen(),
      ),
    );
  }

  Future<void> _open(SonarpadAudiodescriptionItem item) async {
    _openSonarpadAudiodescription(context, item);
  }

  Future<void> _preserve(SonarpadAudiodescriptionItem item) async {
    await _preserveSonarpadAudiodescription(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(_sonarpadAudiodescriptionsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      sections: [
                        AccessibleListSection(
                          rows: [
                            AccessibleListRow(
                              id: 'search_query',
                              title: 'Cerca',
                              kind: 'textField',
                              value: _searchController.text,
                              placeholder:
                                  'Cerca un film, una serie o una puntata',
                              textInputAction: 'search',
                              clearAsSearch: true,
                              onSubmitted: _search,
                            ),
                            const AccessibleListRow(
                              id: 'all',
                              title: _allSonarpadAudiodescriptionsTitle,
                            ),
                            ..._items.asMap().entries.map(
                                  (entry) => _catalogRow(
                                    'recent_${entry.key}',
                                    entry.value,
                                  ),
                                ),
                          ],
                        ),
                      ],
                      onEvent: (event) async {
                        if (event.id == 'search_query' &&
                            event.type == 'textChanged') {
                          _searchController.text =
                              event.value?.toString() ?? '';
                          return;
                        }
                        if (event.id == 'all' && event.type == 'activate') {
                          _openAll();
                          return;
                        }
                        if (event.id?.startsWith('recent_') != true) return;
                        final index =
                            int.tryParse(event.id!.substring('recent_'.length));
                        if (index == null || index >= _items.length) return;
                        final item = _items[index];
                        if (event.type == 'activate' ||
                            (event.type == 'customAction' &&
                                event.action == 'open')) {
                          await _open(item);
                        } else if (event.type == 'customAction' &&
                            event.action == 'preserve_media') {
                          await _preserve(item);
                        }
                      },
                    )
                  : _legacyHome(),
    );
  }

  AccessibleListRow _catalogRow(
    String id,
    SonarpadAudiodescriptionItem item,
  ) {
    return AccessibleListRow(
      id: id,
      title: item.title,
      subtitle: item.dateLabel.isEmpty ? null : item.dateLabel,
      actions: const [
        AccessibleCustomAction(id: 'open', label: 'Apri'),
        AccessibleCustomAction(
          id: 'preserve_media',
          label: 'Conserva file media',
        ),
      ],
      visualActions: const [
        AccessibleVisualAction(id: 'open', label: 'Apri', icon: 'play'),
        AccessibleVisualAction(
          id: 'preserve_media',
          label: 'Scarica',
          icon: 'download',
        ),
      ],
    );
  }

  Widget _legacyHome() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + 2,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        if (index == 0) {
          return TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Cerca',
              hintText: 'Cerca un film, una serie o una puntata',
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
          );
        }
        if (index == 1) {
          return ListTile(
            title: const Text(_allSonarpadAudiodescriptionsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openAll,
          );
        }
        final item = _items[index - 2];
        return _legacyItem(item);
      },
    );
  }

  Widget _legacyItem(SonarpadAudiodescriptionItem item) {
    return Semantics(
      container: true,
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Apri'): () => unawaited(_open(item)),
        CustomSemanticsAction(label: 'Conserva file media'): () =>
            unawaited(_preserve(item)),
      },
      child: ListTile(
        title: Text(item.title),
        subtitle: item.dateLabel.isEmpty ? null : Text(item.dateLabel),
        onTap: () => _open(item),
        trailing: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () => _open(item), child: const Text('Apri')),
              TextButton(
                onPressed: () => _preserve(item),
                child: const Text('Scarica'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SonarpadAudiodescriptionsAllScreen extends StatefulWidget {
  const SonarpadAudiodescriptionsAllScreen({super.key});

  @override
  State<SonarpadAudiodescriptionsAllScreen> createState() =>
      _SonarpadAudiodescriptionsAllScreenState();
}

class _SonarpadAudiodescriptionsAllScreenState
    extends State<SonarpadAudiodescriptionsAllScreen> {
  final _service = SonarpadAudiodescriptionsService();
  final _settings = AppSettingsService();

  List<SonarpadAudiodescriptionItem> _items = const [];
  bool _chronological = false;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final code = (await _settings.getTvSecretCode()).trim();
      final items = await _service.fetchAll(
        code,
        chronological: _chronological,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _changeSort(Object? value) async {
    final chronological = value?.toString() == 'recent';
    if (chronological == _chronological) return;
    setState(() => _chronological = chronological);
    await _load();
  }

  Future<void> _open(SonarpadAudiodescriptionItem item) async {
    _openSonarpadAudiodescription(context, item);
  }

  Future<void> _preserve(SonarpadAudiodescriptionItem item) async {
    await _preserveSonarpadAudiodescription(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(_allSonarpadAudiodescriptionsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      sections: [
                        AccessibleListSection(
                          rows: [
                            AccessibleListRow(
                              id: 'sort',
                              title: 'Ordina per',
                              kind: 'picker',
                              value: _chronological ? 'recent' : 'alpha',
                              valueLabel:
                                  _chronological ? 'Cronologico' : 'Alfabetico',
                              options: const [
                                AccessibleOption(
                                  value: 'alpha',
                                  label: 'Alfabetico',
                                ),
                                AccessibleOption(
                                  value: 'recent',
                                  label: 'Cronologico',
                                ),
                              ],
                              onValueChanged: _changeSort,
                            ),
                            ..._items.asMap().entries.map(
                                  (entry) => _sharedCatalogRow(
                                    'all_${entry.key}',
                                    entry.value,
                                  ),
                                ),
                          ],
                        ),
                      ],
                      onEvent: (event) async {
                        if (event.id?.startsWith('all_') != true) return;
                        final index =
                            int.tryParse(event.id!.substring('all_'.length));
                        if (index == null || index >= _items.length) return;
                        final item = _items[index];
                        if (event.type == 'activate' ||
                            (event.type == 'customAction' &&
                                event.action == 'open')) {
                          await _open(item);
                        } else if (event.type == 'customAction' &&
                            event.action == 'preserve_media') {
                          await _preserve(item);
                        }
                      },
                    )
                  : _legacyAll(),
    );
  }

  Widget _legacyAll() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        if (index == 0) {
          return DropdownButtonFormField<String>(
            initialValue: _chronological ? 'recent' : 'alpha',
            decoration: const InputDecoration(labelText: 'Ordina per'),
            items: const [
              DropdownMenuItem(value: 'alpha', child: Text('Alfabetico')),
              DropdownMenuItem(value: 'recent', child: Text('Cronologico')),
            ],
            onChanged: _changeSort,
          );
        }
        return _legacyCatalogItem(
          _items[index - 1],
          onOpen: _open,
          onPreserve: _preserve,
        );
      },
    );
  }
}

class SonarpadAudiodescriptionsSearchScreen extends StatefulWidget {
  const SonarpadAudiodescriptionsSearchScreen({
    super.key,
    required this.query,
  });

  final String query;

  @override
  State<SonarpadAudiodescriptionsSearchScreen> createState() =>
      _SonarpadAudiodescriptionsSearchScreenState();
}

class _SonarpadAudiodescriptionsSearchScreenState
    extends State<SonarpadAudiodescriptionsSearchScreen> {
  final _service = SonarpadAudiodescriptionsService();
  final _settings = AppSettingsService();

  List<SonarpadAudiodescriptionItem> _items = const [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final code = (await _settings.getTvSecretCode()).trim();
      final items = await _service.search(code, widget.query);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _open(SonarpadAudiodescriptionItem item) async {
    _openSonarpadAudiodescription(context, item);
  }

  Future<void> _preserve(SonarpadAudiodescriptionItem item) async {
    await _preserveSonarpadAudiodescription(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Risultati ricerca')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : _items.isEmpty
                  ? const Center(child: Text('Nessun risultato.'))
                  : useSharedAccessibleViewModel
                      ? UniversalAccessibleList(
                          sections: [
                            AccessibleListSection(
                              rows: _items
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => _sharedCatalogRow(
                                      'search_${entry.key}',
                                      entry.value,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                          onEvent: (event) async {
                            if (event.id?.startsWith('search_') != true) return;
                            final index = int.tryParse(
                              event.id!.substring('search_'.length),
                            );
                            if (index == null || index >= _items.length) return;
                            final item = _items[index];
                            if (event.type == 'activate' ||
                                (event.type == 'customAction' &&
                                    event.action == 'open')) {
                              await _open(item);
                            } else if (event.type == 'customAction' &&
                                event.action == 'preserve_media') {
                              await _preserve(item);
                            }
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) => _legacyCatalogItem(
                            _items[index],
                            onOpen: _open,
                            onPreserve: _preserve,
                          ),
                        ),
    );
  }
}

AccessibleListRow _sharedCatalogRow(
  String id,
  SonarpadAudiodescriptionItem item,
) {
  return AccessibleListRow(
    id: id,
    title: item.title,
    subtitle: item.dateLabel.isEmpty ? null : item.dateLabel,
    actions: const [
      AccessibleCustomAction(id: 'open', label: 'Apri'),
      AccessibleCustomAction(
        id: 'preserve_media',
        label: 'Conserva file media',
      ),
    ],
    visualActions: const [
      AccessibleVisualAction(id: 'open', label: 'Apri', icon: 'play'),
      AccessibleVisualAction(
        id: 'preserve_media',
        label: 'Scarica',
        icon: 'download',
      ),
    ],
  );
}

Widget _legacyCatalogItem(
  SonarpadAudiodescriptionItem item, {
  required Future<void> Function(SonarpadAudiodescriptionItem item) onOpen,
  required Future<void> Function(SonarpadAudiodescriptionItem item) onPreserve,
}) {
  return Semantics(
    container: true,
    customSemanticsActions: {
      CustomSemanticsAction(label: 'Apri'): () => unawaited(onOpen(item)),
      CustomSemanticsAction(label: 'Conserva file media'): () =>
          unawaited(onPreserve(item)),
    },
    child: ListTile(
      title: Text(item.title),
      subtitle: item.dateLabel.isEmpty ? null : Text(item.dateLabel),
      onTap: () => onOpen(item),
      trailing: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => onOpen(item), child: const Text('Apri')),
            TextButton(
              onPressed: () => onPreserve(item),
              child: const Text('Scarica'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _openSonarpadAudiodescription(
  BuildContext context,
  SonarpadAudiodescriptionItem item,
) {
  if (item.streamUrl.isEmpty) {
    showStatusMessage(context, 'Contenuto non disponibile.');
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(
        name: '/sonarpad_audiodescriptions/player',
      ),
      builder: (_) => PodcastEpisodePlayerScreen(
        episode: PodcastEpisode(
          title: item.title,
          description: '',
          audioUrl: item.streamUrl,
          id: item.path,
          publishedAt: item.modifiedAt ?? DateTime.now(),
        ),
        isVideoSupported: item.isVideo,
        startWithVideo: item.isVideo,
        showPreviousEpisodeAction: false,
        showNextEpisodeAction: false,
      ),
    ),
  );
}

Future<void> _preserveSonarpadAudiodescription(
  BuildContext context,
  SonarpadAudiodescriptionItem item,
) async {
  if (item.downloadUrl.isEmpty) {
    showStatusMessage(context, 'Download non disponibile.');
    return;
  }
  await preserveMediaWithProgress(
    context,
    title: item.title,
    fileName: item.downloadFilename.isNotEmpty
        ? item.downloadFilename
        : item.filename,
    resolveUrl: () async => item.downloadUrl,
  );
}
