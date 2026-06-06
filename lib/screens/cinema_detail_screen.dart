import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_localizations.dart';
import '../models/tmdb_movie.dart';
import '../services/tmdb_service.dart';
import 'trailer_screen.dart';

class CinemaDetailScreen extends StatefulWidget {
  final TmdbMovie movie;

  const CinemaDetailScreen({super.key, required this.movie});

  @override
  State<CinemaDetailScreen> createState() => _CinemaDetailScreenState();
}

class _CinemaDetailScreenState extends State<CinemaDetailScreen> {
  final _service = TmdbService();

  Future<void> _openTrailer() async {
    try {
      final localeName = Localizations.localeOf(context).languageCode;
      final trailerUrl = await _service.getTrailerUrl(widget.movie.id, languageCode: localeName);
      if (trailerUrl != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/cinema/trailer'),
            builder: (_) => TrailerScreen(
              videoUrl: trailerUrl,
              title: widget.movie.title,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessun trailer disponibile per questo film')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final movie = widget.movie;
    final releaseDateText = l10n.cinemaReleased(movie.releaseDate);

    return Scaffold(
      appBar: AppBar(title: Text(movie.title)),
      body: Semantics(
        explicitChildNodes: true,
        child: ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.all(16),
        children: [
          Text(
            movie.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            releaseDateText,
            style: const TextStyle(
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          if (movie.overview.isNotEmpty) ...[
            Text(
              l10n.cinemaOverviewLabel,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie.overview,
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 32),
          ],
          FilledButton.icon(
            onPressed: _openTrailer,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.cinemaOpenTrailer),
          ),
        ],
      ),
      ),
    );
  }
}
