import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/sonarpad_audiodescriptions_service.dart';
import '../utils/status_message.dart';
import '../widgets/media_preservation_progress_dialog.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';


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
    if (item.isFolder) {
      await _openSonarpadAudiodescriptionFolder(context, item);
      return;
    }
    _openSonarpadAudiodescription(context, item);
  }

  Future<void> _preserve(SonarpadAudiodescriptionItem item) async {
    if (item.isFolder) return;
    await _preserveSonarpadAudiodescription(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).sonarpadAudiodescriptionsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(AppLocalizations.of(context).audiodescriptionError))
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      sections: [
                        AccessibleListSection(
                          rows: [
                            AccessibleListRow(
                              id: 'search_query',
                              title: AppLocalizations.of(context).search,
                              kind: 'textField',
                              value: _searchController.text,
                              placeholder: AppLocalizations.of(context).sonarpadAudiodescriptionsSearchHint,
                              textInputAction: 'search',
                              clearAsSearch: true,
                              onSubmitted: _search,
                            ),
                            AccessibleListRow(
                              id: 'all',
                              title: AppLocalizations.of(context).sonarpadAudiodescriptionsAll,
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
    return _sharedCatalogRow(context, id, item);
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
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).search,
              hintText: AppLocalizations.of(context).sonarpadAudiodescriptionsSearchHint,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
          );
        }
        if (index == 1) {
          return ListTile(
            title: Text(AppLocalizations.of(context).sonarpadAudiodescriptionsAll),
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
    return _legacyCatalogItem(
      context,
      item,
      onOpen: _open,
      onPreserve: _preserve,
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
      final items = await _service.fetchFolder(
        code,
        '',
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
    if (item.isFolder) {
      await _openSonarpadAudiodescriptionFolder(context, item);
      return;
    }
    _openSonarpadAudiodescription(context, item);
  }

  Future<void> _preserve(SonarpadAudiodescriptionItem item) async {
    if (item.isFolder) return;
    await _preserveSonarpadAudiodescription(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).sonarpadAudiodescriptionsAll)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(AppLocalizations.of(context).audiodescriptionError))
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      sections: [
                        AccessibleListSection(
                          rows: [
                            AccessibleListRow(
                              id: 'sort',
                              title: AppLocalizations.of(context).sortBy,
                              kind: 'picker',
                              value: _chronological ? 'recent' : 'alpha',
                              valueLabel:
                                  _chronological
                                  ? AppLocalizations.of(context).sortChronological
                                  : AppLocalizations.of(context).sortAlphabetical,
                              options: [
                                AccessibleOption(
                                  value: 'alpha',
                                  label: AppLocalizations.of(context).sortAlphabetical,
                                ),
                                AccessibleOption(
                                  value: 'recent',
                                  label: AppLocalizations.of(context).sortChronological,
                                ),
                              ],
                              onValueChanged: _changeSort,
                            ),
                            ..._items.asMap().entries.map(
                                  (entry) => _sharedCatalogRow(
                                    context,
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
            decoration: InputDecoration(labelText: AppLocalizations.of(context).sortBy),
            items: [
              DropdownMenuItem(
                value: 'alpha',
                child: Text(AppLocalizations.of(context).sortAlphabetical),
              ),
              DropdownMenuItem(
                value: 'recent',
                child: Text(AppLocalizations.of(context).sortChronological),
              ),
            ],
            onChanged: _changeSort,
          );
        }
        return _legacyCatalogItem(
          context,
          _items[index - 1],
          onOpen: _open,
          onPreserve: _preserve,
        );
      },
    );
  }
}

class SonarpadAudiodescriptionsFolderScreen extends StatefulWidget {
  const SonarpadAudiodescriptionsFolderScreen({
    super.key,
    required this.folderPath,
    required this.title,
    required this.plot,
  });

  final String folderPath;
  final String title;
  final String plot;

  @override
  State<SonarpadAudiodescriptionsFolderScreen> createState() =>
      _SonarpadAudiodescriptionsFolderScreenState();
}

class _SonarpadAudiodescriptionsFolderScreenState
    extends State<SonarpadAudiodescriptionsFolderScreen> {
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
      final items = await _service.fetchFolder(code, widget.folderPath);
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
    if (item.isFolder) {
      await _openSonarpadAudiodescriptionFolder(context, item);
      return;
    }
    _openSonarpadAudiodescription(context, item);
  }

  Future<void> _preserve(SonarpadAudiodescriptionItem item) async {
    if (item.isFolder) return;
    await _preserveSonarpadAudiodescription(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(AppLocalizations.of(context).audiodescriptionError))
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      sections: [
                        AccessibleListSection(
                          rows: [
                            if (widget.plot.isNotEmpty)
                              AccessibleListRow(
                                id: 'folder_plot',
                                kind: 'text',
                                title: AppLocalizations.of(context).cinemaOverviewLabel,
                                valueLabel: widget.plot,
                                accessibilityButtonTrait: false,
                              ),
                            ..._items.asMap().entries.map(
                                  (entry) => _sharedCatalogRow(
                                    context,
                                    'folder_${entry.key}',
                                    entry.value,
                                  ),
                                ),
                          ],
                        ),
                      ],
                      onEvent: (event) async {
                        if (event.id?.startsWith('folder_') != true) return;
                        final index = int.tryParse(
                          event.id!.substring('folder_'.length),
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
                  : _legacyFolder(),
    );
  }

  Widget _legacyFolder() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (widget.plot.isNotEmpty ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        if (widget.plot.isNotEmpty && index == 0) {
          return ListTile(
            title: Text(AppLocalizations.of(context).cinemaOverviewLabel),
            subtitle: Text(widget.plot),
          );
        }
        final itemIndex = index - (widget.plot.isNotEmpty ? 1 : 0);
        return _legacyCatalogItem(
          context,
          _items[itemIndex],
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
      appBar: AppBar(title: Text(AppLocalizations.of(context).searchResults)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(AppLocalizations.of(context).audiodescriptionError))
              : _items.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context).audiodescriptionEmpty))
                  : useSharedAccessibleViewModel
                      ? UniversalAccessibleList(
                          sections: [
                            AccessibleListSection(
                              rows: _items
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => _sharedCatalogRow(
                                      context,
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
                            context,
                            _items[index],
                            onOpen: _open,
                            onPreserve: _preserve,
                          ),
                        ),
    );
  }
}

String? _sonarpadAudiodescriptionSubtitle(
  SonarpadAudiodescriptionItem item,
  AppLocalizations l10n,
) {
  final parts = <String>[];
  if (item.plot.isNotEmpty) {
    parts.add('${l10n.cinemaOverviewLabel} ${item.plot}');
  }
  if (item.dateLabel.isNotEmpty) {
    parts.add(item.dateLabel);
  }
  return parts.isEmpty ? null : parts.join('\n');
}

AccessibleListRow _sharedCatalogRow(
  BuildContext context,
  String id,
  SonarpadAudiodescriptionItem item,
) {
  final l10n = AppLocalizations.of(context);
  return AccessibleListRow(
    id: id,
    title: item.title,
    subtitle: _sonarpadAudiodescriptionSubtitle(item, l10n),
    actions: item.isFolder
        ? [AccessibleCustomAction(id: 'open', label: l10n.openItem)]
        : [
            AccessibleCustomAction(id: 'open', label: l10n.openItem),
            AccessibleCustomAction(
              id: 'preserve_media',
              label: l10n.preserveMedia,
            ),
          ],
    visualActions: item.isFolder
        ? [AccessibleVisualAction(id: 'open', label: l10n.openItem, icon: 'open')]
        : [
            AccessibleVisualAction(id: 'open', label: l10n.openItem, icon: 'play'),
            AccessibleVisualAction(
              id: 'preserve_media',
              label: l10n.download,
              icon: 'download',
            ),
          ],
  );
}

Widget _legacyCatalogItem(
  BuildContext context,
  SonarpadAudiodescriptionItem item, {
  required Future<void> Function(SonarpadAudiodescriptionItem item) onOpen,
  required Future<void> Function(SonarpadAudiodescriptionItem item) onPreserve,
}) {
  final l10n = AppLocalizations.of(context);
  final subtitle = _sonarpadAudiodescriptionSubtitle(item, l10n);
  final actions = <CustomSemanticsAction, VoidCallback>{
    CustomSemanticsAction(label: l10n.openItem): () => unawaited(onOpen(item)),
    if (!item.isFolder)
      CustomSemanticsAction(label: l10n.preserveMedia): () =>
          unawaited(onPreserve(item)),
  };
  return Semantics(
    container: true,
    customSemanticsActions: actions,
    child: ListTile(
      title: Text(item.title),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: () => onOpen(item),
      trailing: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => onOpen(item), child: Text(l10n.openItem)),
            if (!item.isFolder)
              TextButton(
                onPressed: () => onPreserve(item),
                child: Text(l10n.download),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _openSonarpadAudiodescriptionFolder(
  BuildContext context,
  SonarpadAudiodescriptionItem item,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(
        name: '/sonarpad_audiodescriptions/folder',
      ),
      builder: (_) => SonarpadAudiodescriptionsFolderScreen(
        folderPath: item.path,
        title: item.title,
        plot: item.plot,
      ),
    ),
  );
}

void _openSonarpadAudiodescription(
  BuildContext context,
  SonarpadAudiodescriptionItem item,
) {
  if (item.streamUrl.isEmpty) {
    showStatusMessage(context, AppLocalizations.of(context).contentUnavailable);
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
          description: item.plot,
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
    showStatusMessage(context, AppLocalizations.of(context).downloadUnavailable);
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
