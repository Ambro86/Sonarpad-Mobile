import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'radio_player_screen.dart';
import 'radio_screen.dart'; // Per RadioTile

class RadioSearchResultsScreen extends StatefulWidget {
  final List<RadioStation> results;

  const RadioSearchResultsScreen({super.key, required this.results});

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.radioSearchResults)),
      body: widget.results.isEmpty
          ? Center(child: Text(l10n.radioNoResults))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.results.length,
              itemBuilder: (context, index) {
                final station = widget.results[index];
                final isFavorite = _favorites
                    .any((item) => item.streamUrl == station.streamUrl);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: RadioTile(
                    station: station,
                    isFavorite: isFavorite,
                    isPlaying: false,
                    onPlay: () => _play(station),
                    onToggleFavorite: () => _toggleFavorite(station),
                  ),
                );
              },
            ),
    );
  }
}
