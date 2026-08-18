import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'radio_player_screen.dart';
import 'radio_screen.dart';
import '../widgets/native_ios_accessible_view.dart'; // Per RadioTile
import '../utils/status_message.dart';

class RadioSearchResultsScreen extends StatefulWidget {
  final Future<List<RadioStation>> resultsFuture;
  final String query;

  const RadioSearchResultsScreen({
    super.key,
    required this.resultsFuture,
    this.query = '',
  });

  @override
  State<RadioSearchResultsScreen> createState() =>
      _RadioSearchResultsScreenState();
}

class _RadioSearchResultsScreenState extends State<RadioSearchResultsScreen> {
  static const _pageSize = 25;

  final _service = RadioService();
  List<RadioStation> _favorites = [];
  int _page = 0;

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

  Future<void> _play(RadioStation station) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/player'),
        builder: (_) => RadioPlayerScreen(station: station),
      ),
    );
    await _loadFavorites();
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
        showStatusMessage(context, exists
            ? l10n.radioFavoriteRemoved(station.name)
            : l10n.radioFavoriteAdded(station.name));
  }

  void _changePage(int page, int totalPages, String localeName) {
    final nextPage = page.clamp(0, totalPages - 1).toInt();
    setState(() => _page = nextPage);
    showStatusMessage(
      context,
      _radioPageLabel(localeName, nextPage + 1, totalPages),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.radioSearchResults)),
      body: FutureBuilder<List<RadioStation>>(
        future: widget.resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.radioSearching),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _radioSearchErrorMessage(
                    l10n.localeName,
                    snapshot.error,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }
          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _radioNoResultsMessage(l10n.localeName, widget.query),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final totalPages = (results.length + _pageSize - 1) ~/ _pageSize;
          final currentPage = _page.clamp(0, totalPages - 1).toInt();
          final start = currentPage * _pageSize;
          final end = start + _pageSize < results.length
              ? start + _pageSize
              : results.length;
          final visibleResults = results.sublist(start, end);
          final pageLabel = _radioPageLabel(
            l10n.localeName,
            currentPage + 1,
            totalPages,
          );

          return Column(
            children: [
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    pageLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Expanded(
                child: useNativeIosAccessibleViews
                    ? NativeIosAccessibleList(
                        key: ValueKey('native-radio-results-$currentPage-${visibleResults.length}'),
                        sections: [
                          NativeIosListSection(
                            rows: visibleResults.map((station) {
                              final isFavorite = _favorites.any((item) => item.streamUrl == station.streamUrl);
                              return NativeIosListRow(
                                id: station.streamUrl,
                                title: station.name,
                                subtitle: station.detailsText,
                                accessibilityLabel: station.accessibilityLabel,
                                kind: 'action',
                                actions: [
                                  NativeIosCustomAction(
                                    id: 'favorite',
                                    label: isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                        onEvent: (event) async {
                          final id = event.id;
                          if (id == null) return;
                          final index = visibleResults.indexWhere((e) => e.streamUrl == id);
                          if (index < 0) return;
                          final station = visibleResults[index];
                          if (event.type == 'activate') {
                            await _play(station);
                          } else if (event.type == 'customAction' && event.action == 'favorite') {
                            await _toggleFavorite(station);
                          }
                        },
                      )
                    : ListView.builder(
                  key: PageStorageKey('radio_results_page_$currentPage'),
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleResults.length,
                  itemBuilder: (context, index) {
                    final station = visibleResults[index];
                    final isFavorite = _favorites
                        .any((item) => item.streamUrl == station.streamUrl);
                    return Padding(
                      key: ValueKey(
                        'radio_search_result_row_${station.streamUrl}',
                      ),
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: RadioTile(
                        key: ValueKey(
                          'radio_search_result_tile_${station.streamUrl}',
                        ),
                        station: station,
                        isFavorite: isFavorite,
                        isPlaying: false,
                        onPlay: () => _play(station),
                        onToggleFavorite: () => _toggleFavorite(station),
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('radio_previous_page'),
                            onPressed: currentPage > 0
                                ? () => _changePage(
                                      currentPage - 1,
                                      totalPages,
                                      l10n.localeName,
                                    )
                                : null,
                            icon: const Icon(Icons.navigate_before),
                            label: Text(
                              _radioPreviousLabel(l10n.localeName),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('radio_next_page'),
                            onPressed: currentPage + 1 < totalPages
                                ? () => _changePage(
                                      currentPage + 1,
                                      totalPages,
                                      l10n.localeName,
                                    )
                                : null,
                            icon: const Icon(Icons.navigate_next),
                            label: Text(_radioNextLabel(l10n.localeName)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _radioPreviousLabel(String localeName) {
  return switch (localeName) {
    'en' => 'Previous',
    'es' => 'Anterior',
    'fr' => 'Précédents',
    'pt' => 'Anteriores',
    'pl' => 'Poprzednie',
    'cs' => 'Předchozí',
    _ => 'Precedenti',
  };
}

String _radioNextLabel(String localeName) {
  return switch (localeName) {
    'en' => 'Next',
    'es' => 'Siguiente',
    'fr' => 'Suivants',
    'pt' => 'Seguintes',
    'pl' => 'Następne',
    'cs' => 'Další',
    _ => 'Successivi',
  };
}

String _radioPageLabel(String localeName, int current, int total) {
  return switch (localeName) {
    'en' => 'Page $current of $total',
    'es' => 'Página $current de $total',
    'fr' => 'Page $current sur $total',
    'pt' => 'Página $current de $total',
    'pl' => 'Strona $current z $total',
    'cs' => 'Stránka $current z $total',
    _ => 'Pagina $current di $total',
  };
}

String _radioNoResultsMessage(String localeName, String query) {
  final hasQuery = query.trim().isNotEmpty;
  if (localeName == 'en') {
    return hasQuery
        ? 'No radios found. Try only the station name, without genre, or change language/country.'
        : 'No radios found. Try another language, country, or genre.';
  }
  if (localeName == 'es') {
    return hasQuery
        ? 'No se encontraron radios. Prueba solo con el nombre de la emisora, sin género, o cambia idioma/país.'
        : 'No se encontraron radios. Prueba con otro idioma, país o género.';
  }
  if (localeName == 'fr') {
    return hasQuery
        ? 'Aucune radio trouvée. Essayez seulement le nom de la station, sans genre, ou changez langue/pays.'
        : 'Aucune radio trouvée. Essayez une autre langue, un autre pays ou un autre genre.';
  }
  if (localeName == 'pt') {
    return hasQuery
        ? 'Nenhuma rádio encontrada. Tente só o nome da estação, sem gênero, ou mude idioma/país.'
        : 'Nenhuma rádio encontrada. Tente outro idioma, país ou gênero.';
  }
  if (localeName == 'pl') {
    return hasQuery
        ? 'Nie znaleziono stacji. Spróbuj wpisać tylko nazwę stacji, bez gatunku, albo zmień język/kraj.'
        : 'Nie znaleziono stacji. Spróbuj innego języka, kraju albo gatunku.';
  }
  return hasQuery
      ? 'Nessuna radio trovata. Prova solo con il nome della stazione, senza genere, oppure cambia lingua o nazione.'
      : 'Nessuna radio trovata. Prova con un’altra lingua, nazione o genere.';
}

String _radioSearchErrorMessage(String localeName, Object? error) {
  final raw = error.toString();
  final normalized = raw.toLowerCase();
  final isRadioBrowserConnectionError =
      normalized.contains('failed host lookup') ||
          normalized.contains('socketexception') ||
          normalized.contains('clientexception') ||
          normalized.contains('timeoutexception') ||
          normalized.contains('connection') ||
          normalized.contains('nodename nor servname') ||
          normalized.contains('radio browser non raggiungibile') ||
          normalized.contains('http 502') ||
          normalized.contains('http 503') ||
          normalized.contains('http 504');

  if (!isRadioBrowserConnectionError) {
    if (localeName == 'en') return 'Radio search error: $raw';
    if (localeName == 'es') return 'Error en la búsqueda de radio: $raw';
    if (localeName == 'fr') return 'Erreur de recherche radio : $raw';
    if (localeName == 'pt') return 'Erro na pesquisa de rádio: $raw';
    if (localeName == 'pl') return 'Błąd wyszukiwania radia: $raw';
    if (localeName == 'cs') return 'Chyba při hledání rádia: $raw';
    return 'Errore ricerca radio: $raw';
  }

  if (localeName == 'en') {
    return 'Connection error with Radio Browser. Please try again later.';
  }
  if (localeName == 'es') {
    return 'Error de conexión con Radio Browser. Inténtalo de nuevo más tarde.';
  }
  if (localeName == 'fr') {
    return 'Erreur de connexion à Radio Browser. Réessayez plus tard.';
  }
  if (localeName == 'pt') {
    return 'Erro de ligação ao Radio Browser. Tente novamente mais tarde.';
  }
  if (localeName == 'pl') {
    return 'Błąd połączenia z Radio Browser. Spróbuj ponownie później.';
  }
  if (localeName == 'cs') {
    return 'Chyba připojení k Radio Browseru. Zkuste to prosím později.';
  }
  return 'Errore di connessione a Radio Browser. Riprova più tardi.';
}
