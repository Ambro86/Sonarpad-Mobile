import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../widgets/native_ios_accessible_view.dart';
import '../models/tmdb_movie.dart';
import '../services/tmdb_service.dart';
import 'cinema_detail_screen.dart';

class CinemaUpcomingScreen extends StatefulWidget {
  const CinemaUpcomingScreen({super.key});

  @override
  State<CinemaUpcomingScreen> createState() => _CinemaUpcomingScreenState();
}

class _CinemaUpcomingScreenState extends State<CinemaUpcomingScreen> {
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
      final movies = await _service.getUpcoming(languageCode: localeName);
      
      // Ordina dal più recente al meno recente in base all'uscita (o viceversa per le prossime uscite, mettiamo i più prossimi in cima)
      movies.sort((a, b) => a.releaseDate.compareTo(b.releaseDate));

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

  String _formatDate(String dateStr, String locale) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat.yMMMMd(locale).format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cinemaUpcomingReleases)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('${l10n.cinemaError}\n$_error'))
              : _movies.isEmpty
                  ? Center(child: Text(l10n.cinemaNoMovies))
                  : useNativeIosAccessibleViews
                      ? NativeIosAccessibleList(
                          sections: [
                            NativeIosListSection(
                              rows: _movies.asMap().entries.map((entry) {
                                final formattedDate = _formatDate(entry.value.releaseDate, localeName);
                                bool isFuture = false;
                                try { isFuture = DateTime.parse(entry.value.releaseDate).isAfter(DateTime.now()); } catch (_) {}
                                return NativeIosListRow(
                                  id: 'movie_${entry.key}',
                                  title: entry.value.title,
                                  subtitle: isFuture ? l10n.cinemaWillRelease(formattedDate) : l10n.cinemaReleased(formattedDate),
                                );
                              }).toList(growable: false),
                            ),
                          ],
                          onEvent: (event) {
                            if (event.type != 'activate' || event.id == null) return;
                            final index = int.tryParse(event.id!.replaceFirst('movie_', ''));
                            if (index != null && index >= 0 && index < _movies.length) {
                              Navigator.push(context, MaterialPageRoute(
                                settings: const RouteSettings(name: '/cinema/detail'),
                                builder: (_) => CinemaDetailScreen(movie: _movies[index]),
                              ));
                            }
                          },
                        )
                      : Semantics(
                      explicitChildNodes: true,
                      child: ListView.separated(
                        scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(8),
                      itemCount: _movies.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final movie = _movies[index];
                        final formattedDate = _formatDate(movie.releaseDate, localeName);
                        
                        bool isFuture = false;
                        try {
                          final date = DateTime.parse(movie.releaseDate);
                          if (date.isAfter(DateTime.now())) {
                            isFuture = true;
                          }
                        } catch (_) {}
                        
                        final releaseDateText = isFuture ? l10n.cinemaWillRelease(formattedDate) : l10n.cinemaReleased(formattedDate);
                        
                        return ListTile(
                          title: Text(
                            movie.title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            releaseDateText,
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                settings: const RouteSettings(name: '/cinema/detail'),
                                builder: (_) => CinemaDetailScreen(movie: movie),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
    );
  }
}
