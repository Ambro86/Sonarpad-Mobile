import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'add_radio_screen.dart';
import 'favorite_radios_screen.dart';
import 'radio_search_results_screen.dart';
import 'recent_radios_screen.dart';

enum _RadioBrowseMode { language, country, city }

String _cityLabel(String localeName) => switch (localeName) {
      'en' => 'Browse by city',
      'es' => 'Explorar por ciudad',
      'fr' => 'Parcourir par ville',
      'pt' => 'Explorar por cidade',
      'pl' => 'Przeglądaj według miasta',
      _ => 'Sfoglia per città',
    };

String _cityInputHint(String localeName) => switch (localeName) {
      'en' => 'Enter city name...',
      'es' => 'Introduce la ciudad...',
      'fr' => 'Entrez le nom de la ville...',
      'pt' => 'Digite a cidade...',
      'pl' => 'Wpisz miasto...',
      _ => 'Inserisci il nome della città...',
    };

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
  String? _cityCode;
  _RadioBrowseMode _browseMode = _RadioBrowseMode.language;
  RadioGenreOption _genre = RadioService.genres.first;
  List<RadioLanguageOption> _languageOptions = RadioService.languages;
  List<RadioCountryOption> _countryOptions = RadioService.countries;
  bool _loadingDirectory = false;

  @override
  void initState() {
    super.initState();
    _loadDirectoryOptions();
  }

  Future<void> _loadDirectoryOptions() async {
    setState(() => _loadingDirectory = true);
    try {
      final languages = await _service.loadDirectoryLanguages();
      final countries = await _service.loadDirectoryCountries();
      if (!mounted) return;
      setState(() {
        _languageOptions = languages.isEmpty ? RadioService.languages : languages;
        _countryOptions = countries.isEmpty ? RadioService.countries : countries;
        if (_languageCode != null &&
            !_languageOptions.any((item) => item.code == _languageCode)) {
          _languageCode = _languageOptions.first.code;
        }
        if (_countryCode != null) {
          final countryCode = _countryCode!.replaceFirst('country:', '');
          if (!_countryOptions.any((item) => item.code == countryCode)) {
            _countryCode = 'country:${_countryOptions.first.code}';
          }
        }
      });
    } finally {
      if (mounted) setState(() => _loadingDirectory = false);
    }
  }

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

  void _search() {
    final resultsFuture = _service.searchRadios(
      languageCode: _browseMode == _RadioBrowseMode.language
          ? _languageCode!
          : (_browseMode == _RadioBrowseMode.country ? _countryCode! : 'city:${_cityCode ?? ""}'),
      genre: _genre,
      query: _searchController.text,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/search_results'),
        builder: (_) => RadioSearchResultsScreen(
          resultsFuture: resultsFuture,
          query: _searchController.text,
        ),
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
    final countryItems = _countryOptions
        .map((country) => MapEntry(
              'country:${country.code}',
              _countryOptionLabel(l10n, country),
            ))
        .toList()
      ..sort((a, b) {
        if (a.key == _countryCode) return -1;
        if (b.key == _countryCode) return 1;
        return a.value.compareTo(b.value);
      });

    final languageItems = List.of(_languageOptions)
      ..sort((a, b) {
        if (a.code == _languageCode) return -1;
        if (b.code == _languageCode) return 1;
        return _languageOptionLabel(l10n, a).compareTo(_languageOptionLabel(l10n, b));
      });

    final genreItems = List.of(RadioService.genres)
      ..sort((a, b) {
        if (a.value == _genre.value) return -1;
        if (b.value == _genre.value) return 1;
        return l10n.radioGenreLabel(a.value).compareTo(l10n.radioGenreLabel(b.value));
      });

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
          const SizedBox(height: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/radio/recent'),
                  builder: (_) => const RecentRadiosScreen(),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 8),
                Text(_recentRadiosLabel(l10n.localeName)),
              ],
            ),
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
          if (_loadingDirectory) ...[
            const SizedBox(height: 8),
            Text(_radioDirectoryLoadingLabel(l10n.localeName)),
          ],
          const SizedBox(height: 8),
          ListTile(
            title: Text(l10n.radioBrowseByLanguage),
            subtitle: Text(_languageOptionLabel(l10n, _languageOptions.firstWhere((e) => e.code == _languageCode, orElse: () => _languageOptions.first))),
            trailing: const Icon(Icons.chevron_right),
            selected: _browseMode == _RadioBrowseMode.language,
            onTap: () async {
              final result = await Navigator.push<RadioLanguageOption>(
                context,
                MaterialPageRoute(
                  builder: (_) => _RadioOptionPickerScreen<RadioLanguageOption>(
                    title: l10n.radioBrowseByLanguage,
                    options: languageItems,
                    labelBuilder: (o) => _languageOptionLabel(l10n, o),
                  ),
                ),
              );
              if (result != null) {
                setState(() {
                  _languageCode = result.code;
                  _browseMode = _RadioBrowseMode.language;
                });
                _search();
              }
            },
          ),
          ListTile(
            title: Text(l10n.radioBrowseByCountry),
            subtitle: Text(countryItems.firstWhere((e) => e.key == _countryCode, orElse: () => countryItems.first).value),
            trailing: const Icon(Icons.chevron_right),
            selected: _browseMode == _RadioBrowseMode.country,
            onTap: () async {
              final result = await Navigator.push<MapEntry<String, String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => _RadioOptionPickerScreen<MapEntry<String, String>>(
                    title: l10n.radioBrowseByCountry,
                    options: countryItems,
                    labelBuilder: (o) => o.value,
                  ),
                ),
              );
              if (result != null) {
                setState(() {
                  _countryCode = result.key;
                  _browseMode = _RadioBrowseMode.country;
                });
                _search();
              }
            },
          ),
          ListTile(
            title: Text(_cityLabel(l10n.localeName)),
            subtitle: Text(_browseMode == _RadioBrowseMode.city ? (_cityCode ?? '---') : '---'),
            trailing: const Icon(Icons.chevron_right),
            selected: _browseMode == _RadioBrowseMode.city,
            onTap: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) {
                  final controller = TextEditingController(text: _cityCode);
                  return AlertDialog(
                    title: Text(_cityLabel(l10n.localeName)),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(hintText: _cityInputHint(l10n.localeName)),
                      onSubmitted: (v) => Navigator.pop(context, v),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, controller.text),
                        child: Text(MaterialLocalizations.of(context).okButtonLabel),
                      ),
                    ],
                  );
                },
              );
              if (result != null && result.trim().isNotEmpty) {
                setState(() {
                  _cityCode = result.trim();
                  _browseMode = _RadioBrowseMode.city;
                });
                _search();
              }
            },
          ),
          ListTile(
            title: Text(l10n.radioGenre),
            subtitle: Text(l10n.radioGenreLabel(_genre.value)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push<RadioGenreOption>(
                context,
                MaterialPageRoute(
                  builder: (_) => _RadioOptionPickerScreen<RadioGenreOption>(
                    title: l10n.radioGenre,
                    options: genreItems,
                    labelBuilder: (o) => l10n.radioGenreLabel(o.value),
                  ),
                ),
              );
              if (result != null) {
                setState(() => _genre = result);
                _search();
              }
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.radio),
            label: Text(l10n.radioSearch),
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


String _languageOptionLabel(
  AppLocalizations l10n,
  RadioLanguageOption option,
) {
  final localized = l10n.radioLanguageLabel(option.code);
  if (localized != option.code) return localized;
  final label = option.label.trim();
  if (label.isNotEmpty) return _titleCaseRadioDirectoryLabel(label);
  return option.code;
}

String _countryOptionLabel(
  AppLocalizations l10n,
  RadioCountryOption option,
) {
  final localized = l10n.radioCountryLabel(option.code);
  if (localized != option.code.toUpperCase()) return localized;
  final label = option.label.trim();
  if (label.isNotEmpty) return _titleCaseRadioDirectoryLabel(label);
  return option.code.toUpperCase();
}

String _titleCaseRadioDirectoryLabel(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word.length == 1
          ? word.toUpperCase()
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _radioDirectoryLoadingLabel(String localeName) => switch (localeName) {
      'en' => 'Updating radio countries and languages...',
      'es' => 'Actualizando países e idiomas de radio...',
      'fr' => 'Mise à jour des pays et langues radio...',
      'pt' => 'A atualizar países e idiomas de rádio...',
      'pl' => 'Aktualizuję kraje i języki radia...',
      _ => 'Aggiornamento di paesi e lingue radio...',
    };

String _recentRadiosLabel(String localeName) => switch (localeName) {
      'en' => 'Recent radios',
      'es' => 'Radios recientes',
      'fr' => 'Radios récentes',
      'pt' => 'Rádios recentes',
      'pl' => 'Ostatnie radia',
      _ => 'Radio recenti',
    };

class _RadioOptionPickerScreen<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final String Function(T) labelBuilder;

  const _RadioOptionPickerScreen({
    required this.title,
    required this.options,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          return ListTile(
            key: ValueKey('radio_option_${labelBuilder(option)}'),
            title: Text(labelBuilder(option)),
            onTap: () => Navigator.pop(context, option),
          );
        },
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
        key: ValueKey('radio_tile_semantics_${station.streamUrl}'),
        container: true,
        customSemanticsActions: {
          CustomSemanticsAction(
              label: isFavorite
                  ? l10n.radioRemoveFavorite
                  : l10n.radioAddFavorite): onToggleFavorite,
          ...?extraSemanticsActions,
        },
        label: station.accessibilityLabel,
        child: Card(
          child: ListTile(
            leading: Icon(isPlaying ? Icons.volume_up : Icons.radio),
            title: ExcludeSemantics(child: Text(station.name)),
            subtitle: ExcludeSemantics(
              child: Text(station.detailsText,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
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
