import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ui_radio_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'package:flutter/semantics.dart';
import 'radio_player_screen.dart';
import 'radio_screen.dart'; // Per RadioTile

class FavoriteRadiosScreen extends StatefulWidget {
  const FavoriteRadiosScreen({super.key});

  @override
  State<FavoriteRadiosScreen> createState() => _FavoriteRadiosScreenState();
}

class _FavoriteRadiosScreenState extends State<FavoriteRadiosScreen> {
  final _service = RadioService();
  List<RadioStation> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    final favorites = await _service.loadFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite(RadioStation station) async {
    final next = _favorites.where((item) => item.streamUrl != station.streamUrl).toList();
    await _service.saveFavorites(next);
    setState(() => _favorites = next);
    
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    SemanticsService.announce(l10n.radioFavoriteRemoved(station.name), TextDirection.ltr);
  }

  void _play(RadioStation station) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/player'),
        builder: (_) => RadioPlayerScreen(station: station),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.radioFavoritesButton),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(semanticsLabel: l10n.loading))
          : _favorites.isEmpty
              ? Center(child: Text(l10n.radioNoFavorites))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final station = _favorites[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RadioTile(
                        station: station,
                        isFavorite: true,
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
