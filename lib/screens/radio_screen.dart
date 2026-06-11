import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'add_radio_screen.dart';
import 'favorite_radios_screen.dart';
import 'radio_search_results_screen.dart';

enum _RadioBrowseMode { language, country }

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final _service = RadioService();
  final _searchController = TextEditingController();

  String? _languageCode;
  String? _countryCode;
  _RadioBrowseMode _browseMode = _RadioBrowseMode.language;
  RadioGenreOption _genre = RadioService.genres.first;
  bool _searching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_languageCode == null) {
      final code = AppLocalizations.of(context).localeName;
      _languageCode = switch (code) {
        'en' => 'en',
        'es' => 'es',
        'fr' => 'fr',
        'pt' => 'pt',
        'pl' => 'pl',
        _ => 'it',
      };
      _countryCode = switch (code) {
        'en' => 'country:us',
        'es' => 'country:es',
        'fr' => 'country:fr',
        'pt' => 'country:pt',
        'pl' => 'country:pl',
        _ => 'country:it',
      };
    }
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _searching = true;
    });
    try {
      final results = await _service.searchRadios(
        languageCode: _browseMode == _RadioBrowseMode.language
            ? _languageCode!
            : _countryCode!,
        genre: _genre,
        query: _searchController.text,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/radio/search_results'),
          builder: (_) => RadioSearchResultsScreen(results: results),
        ),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final countryItems = RadioService.countries
        .map((country) => MapEntry(
              'country:${country.code}',
              l10n.radioCountryLabel(country.code),
            ))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

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
          Row(
            children: [
              Expanded(
                child: _RadioBrowseButton(
                  selected: _browseMode == _RadioBrowseMode.language,
                  icon: Icons.language,
                  label: l10n.radioBrowseByLanguage,
                  onPressed: () => setState(
                    () => _browseMode = _RadioBrowseMode.language,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RadioBrowseButton(
                  selected: _browseMode == _RadioBrowseMode.country,
                  icon: Icons.public,
                  label: l10n.radioBrowseByCountry,
                  onPressed: () => setState(
                    () => _browseMode = _RadioBrowseMode.country,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_browseMode == _RadioBrowseMode.language)
            DropdownButtonFormField<String>(
              initialValue: _languageCode,
              decoration: InputDecoration(labelText: l10n.radioLanguage),
              items: RadioService.languages
                  .map((language) => DropdownMenuItem(
                        value: language.code,
                        child: Text(l10n.radioLanguageLabel(language.code)),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _languageCode = value ?? 'it'),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _countryCode,
              decoration: InputDecoration(labelText: l10n.radioCountry),
              items: countryItems
                  .map((country) => DropdownMenuItem(
                        value: country.key,
                        child: Text(country.value),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _countryCode = value ?? 'country:it'),
            ),
          ],
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
          // I risultati vengono ora aperti in un'altra schermata tramite Navigator.push
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

class _RadioBrowseButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _RadioBrowseButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    if (selected) {
      return FilledButton(
        onPressed: onPressed,
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      child: child,
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
