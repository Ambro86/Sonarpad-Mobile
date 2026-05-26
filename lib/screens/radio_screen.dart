import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ui_radio_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'add_radio_screen.dart';
import 'favorite_radios_screen.dart';
import 'radio_player_screen.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final _service = RadioService();
  final _searchController = TextEditingController();

  List<RadioStation> _favorites = [];
  List<RadioStation> _results = [];
  String? _languageCode;
  RadioGenreOption _genre = RadioService.genres.first;
  bool _searching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_languageCode == null) {
      final code = AppLocalizations.of(context).locale.languageCode;
      _languageCode = code == 'es'
          ? 'es'
          : (code == 'fr' ? 'fr' : (code == 'en' ? 'en' : 'it'));
    }
  }

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

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _searching = true;
      _results = [];
    });
    try {
      final results = await _service.searchRadios(
        languageCode: _languageCode!,
        genre: _genre,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() => _results = results);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.radioResultsFound(results.length))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.radioSearchError(e))),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _play(RadioStation station) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/player'),
        builder: (_) => RadioPlayerScreen(station: station),
      ),
    );
  }

  Future<void> _toggleFavorite(RadioStation station) async {
    final l10n = AppLocalizations.of(context);
    final exists =
        _favorites.any((item) => item.streamUrl == station.streamUrl);
    final next = exists
        ? _favorites
            .where((item) => item.streamUrl != station.streamUrl)
            .toList()
        : [..._favorites, station];
    await _service.saveFavorites(next);
    if (!mounted) return;
    setState(() => _favorites = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(exists
            ? l10n.radioFavoriteRemoved(station.name)
            : l10n.radioFavoriteAdded(station.name)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.radioTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/radio/favorites'),
                  builder: (_) => const FavoriteRadiosScreen(),
                ),
              );
              _loadFavorites();
            },
            icon: const Icon(Icons.favorite),
            label: Text(l10n.radioFavoritesButton),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: l10n.radioSearchText,
              hintText: l10n.radioSearchHint,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _languageCode,
            decoration: InputDecoration(labelText: l10n.radioLanguage),
            items: RadioService.languages
                .map((language) => DropdownMenuItem(
                      value: language.code,
                      child: Text(l10n.radioLanguageLabel(language.code)),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _languageCode = value ?? 'it'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<RadioGenreOption>(
            initialValue: _genre,
            decoration: InputDecoration(labelText: l10n.radioGenre),
            items: RadioService.genres
                .map((genre) => DropdownMenuItem(
                      value: genre,
                      child: Text(l10n.radioGenreLabel(genre.value)),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _genre = value ?? RadioService.genres.first),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: const Icon(Icons.radio),
            label: Text(_searching ? l10n.radioSearching : l10n.radioSearch),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.radioSearchResults,
                style: Theme.of(context).textTheme.titleMedium),
            ..._results.map((station) {
              final isFavorite =
                  _favorites.any((item) => item.streamUrl == station.streamUrl);
              return RadioTile(
                station: station,
                isFavorite: isFavorite,
                isPlaying: false,
                onPlay: () => _play(station),
                onToggleFavorite: () => _toggleFavorite(station),
              );
            }),
          ] else if (!_searching) ...[
            const SizedBox(height: 16),
            Text(l10n.radioNoResults),
          ],
          const Divider(height: 32),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/radio/add'),
                  builder: (_) => const AddRadioScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.radioAddCommunity),
          ),
        ],
      ),
    );
  }
}

class RadioTile extends StatelessWidget {
  final RadioStation station;
  final bool isFavorite;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final Map<CustomSemanticsAction, VoidCallback>? extraSemanticsActions;

  const RadioTile({
    super.key,
    required this.station,
    required this.isFavorite,
    required this.isPlaying,
    required this.onPlay,
    required this.onToggleFavorite,
    this.extraSemanticsActions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MergeSemantics(
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(
              label: isFavorite
                  ? l10n.radioRemoveFavorite
                  : l10n.radioAddFavorite): onToggleFavorite,
          ...?extraSemanticsActions,
        },
        child: Card(
          child: ListTile(
            leading: Icon(isPlaying ? Icons.volume_up : Icons.radio),
            title: Text(station.name),
            subtitle: Text(station.streamUrl,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: onPlay,
            trailing: ExcludeSemantics(
              child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: l10n.radioPlay,
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: isFavorite
                        ? l10n.radioRemoveFavorite
                        : l10n.radioAddFavorite,
                    onPressed: onToggleFavorite,
                    icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
