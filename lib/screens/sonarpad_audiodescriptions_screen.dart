import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/sonarpad_audiodescriptions_service.dart';
import '../services/sonarpad_audiodescriptions_favorites_service.dart';
import '../utils/status_message.dart';
import '../widgets/media_preservation_progress_dialog.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';


/// Shared by recent, full catalog, folders and search so the action is
/// consistent across UIKit and Flutter and remains current on route return.
mixin _SonarpadAdFavoritesMixin<T extends StatefulWidget> on State<T> {
  final _favoriteStorage = const SonarpadAudiodescriptionsFavoritesService();
  List<SonarpadAudiodescriptionItem> _favorites = const [];
  bool _favoriteOperationPending = false;
  int _favoritesLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshFavorites());
  }

  bool _isFavorite(SonarpadAudiodescriptionItem item) =>
      _favorites.any((favorite) =>
          SonarpadAudiodescriptionsFavoritesService.itemKey(favorite) ==
          SonarpadAudiodescriptionsFavoritesService.itemKey(item));

  Future<void> _refreshFavorites() async {
    final generation = ++_favoritesLoadGeneration;
    final values = await _favoriteStorage.load();
    if (mounted && generation == _favoritesLoadGeneration) {
      setState(() => _favorites = values);
    }
  }

  Future<void> _toggleFavorite(SonarpadAudiodescriptionItem item) async {
    if (_favoriteOperationPending) {
      return;
    }
    _favoriteOperationPending = true;
    try {
      final added = await _favoriteStorage.toggle(item);
      await _refreshFavorites();
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      showStatusMessage(
        context,
        added
            ? l10n.radioFavoriteAdded(item.title)
            : l10n.radioFavoriteRemoved(item.title),
      );
    } catch (_) {
      if (mounted) {
        showStatusMessage(context, AppLocalizations.of(context).technicalErrorGeneric);
      }
    } finally {
      _favoriteOperationPending = false;
    }
  }

  Future<void> _openFavorites() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/sonarpad_audiodescriptions/favorites'),
        builder: (_) => const SonarpadAudiodescriptionsFavoritesScreen(),
      ),
    );
    if (mounted) {
      await _refreshFavorites();
    }
  }
}

class SonarpadAudiodescriptionsScreen extends StatefulWidget {
  const SonarpadAudiodescriptionsScreen({super.key});

  @override
  State<SonarpadAudiodescriptionsScreen> createState() =>
      _SonarpadAudiodescriptionsScreenState();
}

class _SonarpadAudiodescriptionsScreenState
    extends State<SonarpadAudiodescriptionsScreen> with _SonarpadAdFavoritesMixin<SonarpadAudiodescriptionsScreen> {
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
    if (mounted) {
      await _refreshFavorites();
    }
  }

  Future<void> _openAll() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(
          name: '/sonarpad_audiodescriptions/all',
        ),
        builder: (_) => const SonarpadAudiodescriptionsAllScreen(),
      ),
    );
    if (mounted) {
      await _refreshFavorites();
    }
  }


  Future<void> _open(SonarpadAudiodescriptionItem item) async {
    if (item.isFolder) {
      await _openSonarpadAudiodescriptionFolder(context, item);
      if (mounted) {
        await _refreshFavorites();
      }
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
      appBar: SonarpadAppBar(title: Text(AppLocalizations.of(context).sonarpadAudiodescriptionsTitle)),
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
                            AccessibleListRow(
                              id: 'favorites',
                              title: AppLocalizations.of(context).sonarTubeFavorites,
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
                        if (event.id == 'favorites' && event.type == 'activate') {
                          await _openFavorites();
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
                        } else if (event.type == 'customAction' &&
                            event.action == 'favorite') {
                          await _toggleFavorite(item);
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
    return _sharedCatalogRow(context, id, item, isFavorite: _isFavorite(item));
  }

  Widget _legacyHome() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + 3,
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
        if (index == 2) {
          return ListTile(
            title: Text(AppLocalizations.of(context).sonarTubeFavorites),
            trailing: const Icon(Icons.favorite_border),
            onTap: _openFavorites,
          );
        }
        final item = _items[index - 3];
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
      onToggleFavorite: _toggleFavorite,
      isFavorite: _isFavorite(item),
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
    extends State<SonarpadAudiodescriptionsAllScreen> with _SonarpadAdFavoritesMixin<SonarpadAudiodescriptionsAllScreen> {
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
      if (mounted) {
        await _refreshFavorites();
      }
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
      appBar: SonarpadAppBar(title: Text(AppLocalizations.of(context).sonarpadAudiodescriptionsAll)),
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
                                    isFavorite: _isFavorite(entry.value),
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
                        } else if (event.type == 'customAction' &&
                            event.action == 'favorite') {
                          await _toggleFavorite(item);
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
          onToggleFavorite: _toggleFavorite,
          isFavorite: _isFavorite(_items[index - 1]),
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
    extends State<SonarpadAudiodescriptionsFolderScreen> with _SonarpadAdFavoritesMixin<SonarpadAudiodescriptionsFolderScreen> {
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
      if (mounted) {
        await _refreshFavorites();
      }
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
      appBar: SonarpadAppBar(title: Text(widget.title)),
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
                                    isFavorite: _isFavorite(entry.value),
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
                        } else if (event.type == 'customAction' &&
                            event.action == 'favorite') {
                          await _toggleFavorite(item);
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
          onToggleFavorite: _toggleFavorite,
          isFavorite: _isFavorite(_items[itemIndex]),
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
    extends State<SonarpadAudiodescriptionsSearchScreen> with _SonarpadAdFavoritesMixin<SonarpadAudiodescriptionsSearchScreen> {
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
      appBar: SonarpadAppBar(title: Text(AppLocalizations.of(context).searchResults)),
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
                                      isFavorite: _isFavorite(entry.value),
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
                            } else if (event.type == 'customAction' &&
                                event.action == 'favorite') {
                              await _toggleFavorite(item);
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
                            onToggleFavorite: _toggleFavorite,
                            isFavorite: _isFavorite(_items[index]),
                          ),
                        ),
    );
  }
}

/// Personal favorites for whole films, series folders and individual episodes.
/// Items are kept locally, while playable URLs are refreshed on demand.
class SonarpadAudiodescriptionsFavoritesScreen extends StatefulWidget {
  const SonarpadAudiodescriptionsFavoritesScreen({super.key});

  @override
  State<SonarpadAudiodescriptionsFavoritesScreen> createState() =>
      _SonarpadAudiodescriptionsFavoritesScreenState();
}

class _SonarpadAudiodescriptionsFavoritesScreenState
    extends State<SonarpadAudiodescriptionsFavoritesScreen> {
  final _favoritesService = const SonarpadAudiodescriptionsFavoritesService();
  final _service = SonarpadAudiodescriptionsService();
  final _settings = AppSettingsService();
  List<SonarpadAudiodescriptionItem> _items = const [];
  bool _loading = true;
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final items = await _favoritesService.load();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<SonarpadAudiodescriptionItem?> _freshItem(
    SonarpadAudiodescriptionItem favorite,
  ) async {
    if (favorite.isFolder) {
      return favorite;
    }
    try {
      final code = (await _settings.getTvSecretCode()).trim();
      final refreshed = await _service.refreshFavorite(code, favorite);
      if (refreshed != null) {
        return refreshed;
      }
    } catch (_) {
      // Never play an expired URL previously saved in a favorite.
    }
    if (mounted) {
      showStatusMessage(context, AppLocalizations.of(context).contentUnavailable);
    }
    return null;
  }

  Future<void> _open(SonarpadAudiodescriptionItem favorite) async {
    if (favorite.isFolder) {
      await _openSonarpadAudiodescriptionFolder(context, favorite);
      if (mounted) {
        await _load();
      }
      return;
    }
    final item = await _freshItem(favorite);
    if (item == null || !mounted) {
      return;
    }
    _openSonarpadAudiodescription(context, item);
  }

  Future<void> _preserve(SonarpadAudiodescriptionItem favorite) async {
    if (favorite.isFolder) {
      return;
    }
    final item = await _freshItem(favorite);
    if (item == null || !mounted) {
      return;
    }
    await _preserveSonarpadAudiodescription(context, item);
  }

  Future<void> _toggleFavorite(SonarpadAudiodescriptionItem favorite) async {
    if (_changing) {
      return;
    }
    _changing = true;
    try {
      final added = await _favoritesService.toggle(favorite);
      await _load();
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      showStatusMessage(
        context,
        added
            ? l10n.radioFavoriteAdded(favorite.title)
            : l10n.radioFavoriteRemoved(favorite.title),
      );
    } catch (_) {
      if (mounted) {
        showStatusMessage(context, AppLocalizations.of(context).technicalErrorGeneric);
      }
    } finally {
      _changing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.sonarTubeFavorites)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text(l10n.audiodescriptionEmpty))
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      sections: [
                        AccessibleListSection(
                          rows: _items.asMap().entries.map((entry) =>
                            _sharedCatalogRow(
                              context,
                              'favorite_${entry.key}',
                              entry.value,
                              isFavorite: true,
                            ),
                          ).toList(growable: false),
                        ),
                      ],
                      onEvent: (event) async {
                        if (event.id?.startsWith('favorite_') != true) {
                          return;
                        }
                        final index = int.tryParse(
                          event.id!.substring('favorite_'.length),
                        );
                        if (index == null || index < 0 || index >= _items.length) {
                          return;
                        }
                        final item = _items[index];
                        if (event.type == 'activate' ||
                            (event.type == 'customAction' &&
                                event.action == 'open')) {
                          await _open(item);
                        } else if (event.type == 'customAction' &&
                            event.action == 'preserve_media') {
                          await _preserve(item);
                        } else if (event.type == 'customAction' &&
                            event.action == 'favorite') {
                          await _toggleFavorite(item);
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
                        onToggleFavorite: _toggleFavorite,
                        isFavorite: true,
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
  SonarpadAudiodescriptionItem item, {
  required bool isFavorite,
}) {
  final l10n = AppLocalizations.of(context);
  final favoriteLabel = isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite;
  return AccessibleListRow(
    id: id,
    title: item.title,
    subtitle: _sonarpadAudiodescriptionSubtitle(item, l10n),
    actions: item.isFolder
        ? [
            AccessibleCustomAction(id: 'open', label: l10n.openItem),
            AccessibleCustomAction(id: 'favorite', label: favoriteLabel),
          ]
        : [
            AccessibleCustomAction(id: 'open', label: l10n.openItem),
            AccessibleCustomAction(
              id: 'preserve_media',
              label: l10n.preserveMedia,
            ),
            AccessibleCustomAction(id: 'favorite', label: favoriteLabel),
          ],
    visualActions: item.isFolder
        ? [
            AccessibleVisualAction(id: 'open', label: l10n.openItem, icon: 'open'),
            AccessibleVisualAction(
              id: 'favorite', label: favoriteLabel,
              icon: isFavorite ? 'favorite_filled' : 'favorite',
            ),
          ]
        : [
            AccessibleVisualAction(id: 'open', label: l10n.openItem, icon: 'play'),
            AccessibleVisualAction(
              id: 'preserve_media',
              label: l10n.download,
              icon: 'download',
            ),
            AccessibleVisualAction(
              id: 'favorite', label: favoriteLabel,
              icon: isFavorite ? 'favorite_filled' : 'favorite',
            ),
          ],
  );
}

Widget _legacyCatalogItem(
  BuildContext context,
  SonarpadAudiodescriptionItem item, {
  required Future<void> Function(SonarpadAudiodescriptionItem item) onOpen,
  required Future<void> Function(SonarpadAudiodescriptionItem item) onPreserve,
  required Future<void> Function(SonarpadAudiodescriptionItem item) onToggleFavorite,
  required bool isFavorite,
}) {
  final l10n = AppLocalizations.of(context);
  final subtitle = _sonarpadAudiodescriptionSubtitle(item, l10n);
  final actions = <CustomSemanticsAction, VoidCallback>{
    CustomSemanticsAction(label: l10n.openItem): () => unawaited(onOpen(item)),
    CustomSemanticsAction(
      label: isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
    ): () => unawaited(onToggleFavorite(item)),
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
            IconButton(
              onPressed: () => onToggleFavorite(item),
              tooltip: isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
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
