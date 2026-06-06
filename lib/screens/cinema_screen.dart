import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/tmdb_movie.dart';
import '../services/tmdb_service.dart';
import 'trailer_screen.dart';

class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  final _service = TmdbService();
  List<TmdbMovie> _movies = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final localeName = Localizations.localeOf(context).languageCode;
      final movies = await _service.getNowPlaying(languageCode: localeName);
      if (!mounted) return;
      setState(() {
        _movies = movies;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openTrailer(TmdbMovie movie) async {
    try {
      final localeName = Localizations.localeOf(context).languageCode;
      final trailerUrl = await _service.getTrailerUrl(movie.id, languageCode: localeName);
      if (trailerUrl != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/cinema/trailer'),
            builder: (_) => TrailerScreen(
              videoUrl: trailerUrl,
              title: movie.title,
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cinemaTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('${l10n.cinemaError}\n$_error'))
              : _movies.isEmpty
                  ? Center(child: Text(l10n.cinemaNoMovies))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _movies.length,
                      itemBuilder: (context, index) {
                        final movie = _movies[index];
                        final releaseDateText = l10n.cinemaReleased(movie.releaseDate);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie.title,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    releaseDateText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (movie.overview.isNotEmpty) ...[
                                    Text(
                                      l10n.cinemaOverviewLabel,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      movie.overview,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  FilledButton.icon(
                                    onPressed: () => _openTrailer(movie),
                                    icon: const Icon(Icons.play_arrow),
                                    label: Text(l10n.cinemaOpenTrailer),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
