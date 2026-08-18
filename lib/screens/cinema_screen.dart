import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../widgets/universal_accessible_view.dart';
import '../models/tmdb_movie.dart';
import '../services/tmdb_service.dart';
import 'cinema_detail_screen.dart';
import 'cinema_upcoming_screen.dart';

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
      
      // Ordina dal più recente al meno recente (discendente)
      movies.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));

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
      appBar: AppBar(title: Text(l10n.cinemaTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('${l10n.cinemaError}\n$_error'))
              : _movies.isEmpty
                  ? Center(child: Text(l10n.cinemaNoMovies))
                  : useSharedAccessibleViewModel
                      ? UniversalAccessibleList(
                          sections: [
                            AccessibleListSection(
                              rows: [
                                AccessibleListRow(
                                  id: 'upcoming',
                                  title: l10n.cinemaUpcomingReleases,
                                ),
                                ..._movies.asMap().entries.map((entry) => AccessibleListRow(
                                      id: 'movie_${entry.key}',
                                      title: entry.value.title,
                                      subtitle: l10n.cinemaReleased(_formatDate(entry.value.releaseDate, localeName)),
                                    )),
                              ],
                            ),
                          ],
                          onEvent: (event) {
                            if (event.type != 'activate' || event.id == null) return;
                            if (event.id == 'upcoming') {
                              Navigator.push(context, MaterialPageRoute(
                                settings: const RouteSettings(name: '/cinema/upcoming'),
                                builder: (_) => const CinemaUpcomingScreen(),
                              ));
                            } else if (event.id!.startsWith('movie_')) {
                              final index = int.tryParse(event.id!.substring(6));
                              if (index != null && index >= 0 && index < _movies.length) {
                                Navigator.push(context, MaterialPageRoute(
                                  settings: const RouteSettings(name: '/cinema/detail'),
                                  builder: (_) => CinemaDetailScreen(movie: _movies[index]),
                                ));
                              }
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
                      itemCount: _movies.length + 1,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    settings: const RouteSettings(name: '/cinema/upcoming'),
                                    builder: (_) => const CinemaUpcomingScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.new_releases),
                              label: Text(l10n.cinemaUpcomingReleases, style: const TextStyle(fontSize: 18)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          );
                        }

                        final movie = _movies[index - 1];
                        final formattedDate = _formatDate(movie.releaseDate, localeName);
                        final releaseDateText = l10n.cinemaReleased(formattedDate);
                        
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
