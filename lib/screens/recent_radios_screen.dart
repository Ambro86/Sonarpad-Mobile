import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'radio_player_screen.dart';
import 'radio_screen.dart';

class RecentRadiosScreen extends StatefulWidget {
  const RecentRadiosScreen({super.key});

  @override
  State<RecentRadiosScreen> createState() => _RecentRadiosScreenState();
}

class _RecentRadiosScreenState extends State<RecentRadiosScreen> {
  final _service = RadioService();
  List<RadioStation> _recent = [];
  List<RadioStation> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRadios();
  }

  Future<void> _loadRadios() async {
    setState(() => _loading = true);
    final recent = await _service.loadRecentRadios();
    final favorites = await _service.loadFavorites();
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _favorites = favorites;
      _loading = false;
    });
  }

  Future<void> _play(RadioStation station) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/player'),
        builder: (_) => RadioPlayerScreen(station: station),
      ),
    );
    await _loadRadios();
  }

  Future<void> _toggleFavorite(RadioStation station) async {
    final l10n = AppLocalizations.of(context);
    final exists = _favorites.any((item) => item.streamUrl == station.streamUrl);
    final next = exists
        ? _favorites.where((item) => item.streamUrl != station.streamUrl).toList()
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

  Future<void> _clearRecent() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.confirmClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.clearRecentRadios();
      await _loadRadios();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_recentRadiosLabel(l10n.localeName)),
        actions: [
          if (_recent.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_sweep,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: l10n.clearHistory,
              onPressed: _clearRecent,
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(semanticsLabel: l10n.loading))
          : _recent.isEmpty
              ? Center(child: Text(_noRecentRadiosLabel(l10n.localeName)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recent.length,
                  itemBuilder: (context, index) {
                    final station = _recent[index];
                    final isFavorite = _favorites
                        .any((item) => item.streamUrl == station.streamUrl);
                    return Padding(
                      key: ValueKey('recent_radio_row_${station.streamUrl}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RadioTile(
                        key: ValueKey('recent_radio_tile_${station.streamUrl}'),
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

String _recentRadiosLabel(String localeName) => switch (localeName) {
      'en' => 'Recent radios',
      'es' => 'Radios recientes',
      'fr' => 'Radios récentes',
      'pt' => 'Rádios recentes',
      'pl' => 'Ostatnie radia',
      _ => 'Radio recenti',
    };

String _noRecentRadiosLabel(String localeName) => switch (localeName) {
      'en' => 'No recent radios.',
      'es' => 'No hay radios recientes.',
      'fr' => 'Aucune radio récente.',
      'pt' => 'Não há rádios recentes.',
      'pl' => 'Brak ostatnich stacji radiowych.',
      _ => 'Nessuna radio recente.',
    };
