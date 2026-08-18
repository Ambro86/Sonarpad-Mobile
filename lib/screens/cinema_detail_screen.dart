import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../widgets/universal_accessible_view.dart';
import '../models/tmdb_movie.dart';
import '../services/tmdb_service.dart';
import 'trailer_screen.dart';
import '../utils/status_message.dart';

class CinemaDetailScreen extends StatefulWidget {
  final TmdbMovie movie;

  const CinemaDetailScreen({super.key, required this.movie});

  @override
  State<CinemaDetailScreen> createState() => _CinemaDetailScreenState();
}

class _CinemaDetailScreenState extends State<CinemaDetailScreen> {
  final _service = TmdbService();
  bool _loadingTrailer = true;
  String? _trailerUrl;

  @override
  void initState() {
    super.initState();
    _loadTrailer();
  }

  Future<void> _loadTrailer() async {
    try {
      final localeName = Localizations.localeOf(context).languageCode;
      final url = await _service.getTrailerUrl(widget.movie.id, languageCode: localeName);
      if (mounted) {
        setState(() {
          _trailerUrl = url;
          _loadingTrailer = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingTrailer = false;
        });
      }
    }
  }

  Future<void> _openTrailer() async {
    try {
      if (_trailerUrl != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/cinema/trailer'),
            builder: (_) => TrailerScreen(
              videoUrl: _trailerUrl!,
              title: widget.movie.title,
            ),
          ),
        );
      } else {
        if (!mounted) return;
                showStatusMessage(context, 'Nessun trailer disponibile per questo film');
      }
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, 'Errore: $e');
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
    final movie = widget.movie;
    final formattedDate = _formatDate(movie.releaseDate, localeName);
    
    bool isFuture = false;
    try {
      final date = DateTime.parse(movie.releaseDate);
      if (date.isAfter(DateTime.now())) {
        isFuture = true;
      }
    } catch (_) {}
    
    final releaseDateText = isFuture ? l10n.cinemaWillRelease(formattedDate) : l10n.cinemaReleased(formattedDate);

    return Scaffold(
      appBar: AppBar(title: Text(movie.title)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(id: 'title', title: movie.title, kind: 'text'),
                    AccessibleListRow(id: 'date', title: releaseDateText, kind: 'text'),
                    if (movie.overview.isNotEmpty)
                      AccessibleListRow(id: 'overview', title: l10n.cinemaOverviewLabel, subtitle: movie.overview, kind: 'text'),
                    if (_loadingTrailer)
                      const AccessibleListRow(id: 'trailer_loading', title: 'Caricamento trailer', kind: 'text')
                    else if (_trailerUrl != null)
                      AccessibleListRow(id: 'trailer', title: l10n.cinemaOpenTrailer, kind: 'button'),
                  ],
                ),
              ],
              onEvent: (event) async {
                if (event.type == 'activate' && event.id == 'trailer') await _openTrailer();
              },
            )
          : Semantics(
        explicitChildNodes: true,
        child: ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.all(16),
        children: [
          ExcludeSemantics(
            child: Text(
              movie.title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
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
          if (_loadingTrailer)
            const Center(child: CircularProgressIndicator())
          else if (_trailerUrl != null)
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
