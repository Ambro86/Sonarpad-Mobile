import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'radio_player_screen.dart';
import 'radio_screen.dart'; // Per RadioTile
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
  final _service = RadioService();
  List<RadioStation> _favorites = [];

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
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final station = results[index];
              final isFavorite = _favorites
                  .any((item) => item.streamUrl == station.streamUrl);
              return Padding(
                key: ValueKey('radio_search_result_row_${station.streamUrl}'),
                padding: const EdgeInsets.only(bottom: 8.0),
                child: RadioTile(
                  key: ValueKey('radio_search_result_tile_${station.streamUrl}'),
                  station: station,
                  isFavorite: isFavorite,
                  isPlaying: false,
                  onPlay: () => _play(station),
                  onToggleFavorite: () => _toggleFavorite(station),
                ),
              );
            },
          );
        },
      ),
    );
  }
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
