import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/route_country_options.dart';

import '../services/italiaonline_service.dart';
import '../l10n/app_localizations.dart';
import 'italiaonline_detail_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class ItaliaOnlineScreen extends StatefulWidget {
  const ItaliaOnlineScreen({super.key});

  @override
  State<ItaliaOnlineScreen> createState() => _ItaliaOnlineScreenState();
}

class _ItaliaOnlineScreenState extends State<ItaliaOnlineScreen> {
  final _whatController = TextEditingController();
  final _whereController = TextEditingController();
  DirectoryKind _kind = DirectoryKind.pagineGialle;
  bool _reverse = false;
  String? _country;
  bool _countryEdited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_country == null) {
      final locale = AppLocalizations.of(context).localeName;
      _country = locale.startsWith('en') ? 'us' : defaultRouteCountry(locale);
      _restoreCountry();
    }
  }

  Future<void> _restoreCountry() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _countryEdited) return;
    final saved = prefs.getString('places_search_country');
    if (routeCountryOptions(
      AppLocalizations.of(context),
    ).any((c) => c.value == saved)) {
      setState(() => _country = saved);
    }
  }

  Future<void> _selectCountry(String country) async {
    setState(() {
      _country = country;
      _countryEdited = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('places_search_country', country);
  }

  @override
  void dispose() {
    _whatController.dispose();
    _whereController.dispose();
    super.dispose();
  }

  bool get _italian => Localizations.localeOf(context).languageCode == 'it';

  void _search() {
    var what = _whatController.text.trim();
    if (what.isEmpty) return;

    if (_reverse) {
      try {
        what = normalizePlacePhone(what);
      } on FormatException {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).placesPhoneInvalid),
          ),
        );
        return;
      }
    }
    FocusScope.of(context).unfocus();
    final query = SearchQuery(
      kind: _kind,
      what: what,
      where: _reverse ? '' : _whereController.text.trim(),
      reverse: _reverse,
      country: _country ?? 'it',
      language: AppLocalizations.of(context).localeName,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItaliaOnlineResultsScreen(
          query: query,
          includeItalianDirectories: _italian,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final countries = routeCountryOptions(l10n);
    return Scaffold(
      appBar: SonarpadAppBar(
        title: Text(AppLocalizations.of(context).homeDirectory),
      ),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'kind_pagine_gialle',
                      title: l10n.homeDirectory,
                      selected:
                          _kind == DirectoryKind.pagineGialle && !_reverse,
                      onActivate: () {
                        if (_kind != DirectoryKind.pagineGialle || _reverse) {
                          setState(() {
                            _kind = DirectoryKind.pagineGialle;
                            _reverse = false;
                          });
                        }
                      },
                    ),
                    if (_italian)
                      AccessibleListRow(
                        id: 'kind_pagine_bianche',
                        title: l10n.placesPeopleSearch,
                        selected:
                            _kind == DirectoryKind.pagineBianche && !_reverse,
                        onActivate: () {
                          if (_kind != DirectoryKind.pagineBianche ||
                              _reverse) {
                            setState(() {
                              _kind = DirectoryKind.pagineBianche;
                              _reverse = false;
                            });
                          }
                        },
                      ),
                    AccessibleListRow(
                      id: 'kind_phone',
                      title: l10n.placesPhoneSearch,
                      selected: _reverse,
                      onActivate: () => setState(() => _reverse = true),
                    ),
                    if (_reverse || _kind == DirectoryKind.pagineGialle)
                      AccessibleListRow(
                        id: 'country',
                        title: l10n.routeCountry,
                        kind: 'picker',
                        value: _country,
                        valueLabel: countries
                            .firstWhere((c) => c.value == _country)
                            .label,
                        options: countries,
                      ),
                    AccessibleListRow(
                      id: 'what',
                      title: _reverse
                          ? l10n.placesPhoneQuery
                          : (_italian
                                ? _kind.primaryFieldLabel
                                : AppLocalizations.of(context).placesQuery),
                      kind: 'textField',
                      value: _whatController.text,
                      keyboardType: _reverse ? 'phone' : null,
                      textInputAction: _reverse ? 'search' : 'next',
                      onSubmitted: (_) {
                        if (_reverse) _search();
                      },
                    ),
                    if (!_reverse)
                      AccessibleListRow(
                        id: 'where',
                        title: _italian
                            ? 'Località, indirizzo (opzionale)'
                            : AppLocalizations.of(context).placesLocation,
                        kind: 'textField',
                        value: _whereController.text,
                        textInputAction: 'search',
                        onSubmitted: (_) => _search(),
                      ),
                    AccessibleListRow(
                      id: 'search',
                      title: AppLocalizations.of(context).search,
                      kind: 'button',
                    ),
                  ],
                ),
              ],
              onEvent: (event) {
                if (event.id == 'country' &&
                    event.type == 'picker' &&
                    event.value != null) {
                  _selectCountry(event.value.toString());
                } else if (event.id == 'what' && event.type == 'textChanged') {
                  _whatController.text = event.value?.toString() ?? '';
                } else if (event.id == 'where' && event.type == 'textChanged') {
                  _whereController.text = event.value?.toString() ?? '';
                } else if (event.id == 'search' && event.type == 'activate') {
                  _search();
                }
              },
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 1, label: Text(l10n.homeDirectory)),
                    if (_italian)
                      ButtonSegment(
                        value: 0,
                        label: Text(l10n.placesPeopleSearch),
                      ),
                    ButtonSegment(
                      value: 2,
                      label: Text(l10n.placesPhoneSearch),
                    ),
                  ],
                  selected: {_reverse ? 2 : _kind.index},
                  onSelectionChanged: (set) {
                    setState(() {
                      _reverse = set.first == 2;
                      if (!_reverse) _kind = DirectoryKind.values[set.first];
                    });
                  },
                ),
                const SizedBox(height: 24),
                if (_reverse || _kind == DirectoryKind.pagineGialle)
                  DropdownButtonFormField<String>(
                    key: ValueKey('places_country_$_country'),
                    initialValue: _country,
                    decoration: InputDecoration(labelText: l10n.routeCountry),
                    items: countries
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.value.toString(),
                            child: Text(c.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _selectCountry(value);
                    },
                  ),
                TextField(
                  controller: _whatController,
                  keyboardType: _reverse
                      ? TextInputType.phone
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: _reverse
                        ? l10n.placesPhoneQuery
                        : (_italian
                              ? _kind.primaryFieldLabel
                              : AppLocalizations.of(context).placesQuery),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: _reverse
                      ? TextInputAction.search
                      : TextInputAction.next,
                  onSubmitted: (_) {
                    if (_reverse) _search();
                  },
                ),
                const SizedBox(height: 16),
                if (!_reverse)
                  TextField(
                    controller: _whereController,
                    decoration: InputDecoration(
                      labelText: _italian
                          ? 'Località, indirizzo (opzionale)'
                          : AppLocalizations.of(context).placesLocation,
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                  label: Text(AppLocalizations.of(context).search),
                ),
              ],
            ),
    );
  }
}

class ItaliaOnlineResultsScreen extends StatefulWidget {
  final SearchQuery query;
  final bool includeItalianDirectories;

  const ItaliaOnlineResultsScreen({
    super.key,
    required this.query,
    this.includeItalianDirectories = true,
  });

  @override
  State<ItaliaOnlineResultsScreen> createState() =>
      _ItaliaOnlineResultsScreenState();
}

class _ItaliaOnlineResultsScreenState extends State<ItaliaOnlineResultsScreen> {
  final _service = ItaliaOnlineService();
  SearchResponse? _response;
  final List<SearchResult> _results = [];
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;

  DirectoryKind get _actualKind => _response?.actualKind ?? widget.query.kind;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.query.page;
    _load();
  }

  Future<void> _load({bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _results.clear();
      });
    }

    try {
      final query = SearchQuery(
        kind: loadMore ? _actualKind : widget.query.kind,
        country: widget.query.country,
        language: widget.query.language,
        what: widget.query.what,
        reverse: widget.query.reverse,
        where: widget.query.where,
        page: _currentPage,
      );
      final res = await (query.reverse
          ? _service.searchPhone(query)
          : _service.searchActivities(
              query,
              includeItalianDirectories: widget.includeItalianDirectories,
            ));
      if (mounted) {
        setState(() {
          _response = res;
          if (!widget.query.reverse &&
              widget.query.kind == DirectoryKind.pagineGialle) {
            _results.addAll(
              res.results.where(
                (item) => !_results.any(
                  (existing) => sameDirectoryPlace(existing, item),
                ),
              ),
            );
          } else {
            _results.addAll(res.results);
          }
          if (loadMore) {
            _loadingMore = false;
          } else {
            _loading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          if (loadMore) {
            _loadingMore = false;
          } else {
            _loading = false;
          }
        });
      }
    }
  }

  void _loadNextPage() {
    if (_loadingMore) return;
    _currentPage++;
    _load(loadMore: true);
  }

  Future<void> _openDetail(SearchResult result) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final detail =
          result.inlineDetail ??
          await _service.loadDetail(
            SearchQuery(
              kind: _actualKind,
              country: widget.query.country,
              language: widget.query.language,
              what: widget.query.what,
              reverse: widget.query.reverse,
              where: widget.query.where,
              page: widget.query.page,
            ),
            result.id,
          );
      if (!mounted) return;
      Navigator.of(context).pop(); // Chiudi loading

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItaliaOnlineDetailScreen(detail: detail),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Chiudi loading
        showStatusMessage(context, 'Errore: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SonarpadAppBar(
        title: Text(
          !widget.includeItalianDirectories
              ? AppLocalizations.of(context).homeDirectory
              : widget.query.reverse
              ? 'Numero di telefono - Risultati'
              : '${widget.query.kind.label} - Risultati',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    final res = _response;
    if (res == null) return const SizedBox();

    if (res.ambiguousPlaces != null && res.ambiguousPlaces!.isNotEmpty) {
      if (useSharedAccessibleViewModel) {
        final places = res.ambiguousPlaces!;
        return UniversalAccessibleList(
          sections: [
            AccessibleListSection(
              header: 'Località ambigua. Scegli tra le seguenti:',
              rows: [
                for (var i = 0; i < places.length; i++)
                  AccessibleListRow(id: 'place_$i', title: places[i]),
              ],
            ),
          ],
          onEvent: (event) {
            if (event.type != 'activate' || event.id == null) return;
            final i = int.tryParse(event.id!.replaceFirst('place_', ''));
            if (i == null || i >= places.length) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ItaliaOnlineResultsScreen(
                  query: SearchQuery(
                    kind: _actualKind,
                    country: widget.query.country,
                    language: widget.query.language,
                    what: widget.query.what,
                    reverse: widget.query.reverse,
                    where: places[i],
                    page: 1,
                  ),
                ),
              ),
            );
          },
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Località ambigua. Scegli tra le seguenti:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...res.ambiguousPlaces!.map(
            (place) => ListTile(
              title: Text(place),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ItaliaOnlineResultsScreen(
                      query: SearchQuery(
                        kind: _actualKind,
                        country: widget.query.country,
                        language: widget.query.language,
                        what: widget.query.what,
                        reverse: widget.query.reverse,
                        where: place,
                        page: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).sonarTubeNoResults),
      );
    }

    if (useSharedAccessibleViewModel) {
      return UniversalAccessibleList(
        sections: [
          AccessibleListSection(
            rows: [
              for (var i = 0; i < _results.length; i++)
                AccessibleListRow(
                  id: 'result_$i',
                  title: _results[i].name,
                  subtitle: [
                    if (_results[i].category != null) _results[i].category!,
                    if (_results[i].address != null) _results[i].address!,
                    if (_results[i].city != null) _results[i].city!,
                    if (_results[i].ratingText != null) _results[i].ratingText!,
                  ].join(' - '),
                ),
              if (!res.isLastPage)
                AccessibleListRow(
                  id: 'more',
                  title: _loadingMore
                      ? AppLocalizations.of(context).loading
                      : AppLocalizations.of(context).loadMore,
                  kind: 'button',
                  enabled: !_loadingMore,
                ),
            ],
          ),
        ],
        onEvent: (event) {
          if (event.type != 'activate' || event.id == null) return;
          if (event.id == 'more') {
            _loadNextPage();
            return;
          }
          final i = int.tryParse(event.id!.replaceFirst('result_', ''));
          if (i != null && i < _results.length) _openDetail(_results[i]);
        },
      );
    }

    return ListView.builder(
      itemCount: _results.length + (res.isLastPage ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _loadingMore
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _loadNextPage,
                    child: Text(AppLocalizations.of(context).loadMore),
                  ),
          );
        }

        final r = _results[index];
        final subtitle = [
          if (r.category != null) r.category,
          if (r.address != null) r.address,
          if (r.city != null) r.city,
          if (r.ratingText != null) r.ratingText,
        ].join(' - ');

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(r.name),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDetail(r),
          ),
        );
      },
    );
  }
}
