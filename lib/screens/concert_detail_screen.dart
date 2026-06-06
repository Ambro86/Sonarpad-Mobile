import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/concert_event.dart';

class ConcertDetailScreen extends StatelessWidget {
  final ConcertEvent concert;

  const ConcertDetailScreen({super.key, required this.concert});

  String _formatDate(String dateStr, String timeStr, String locale) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final dateFormatted = DateFormat.yMMMMd(locale).format(date);
      if (timeStr.isNotEmpty) {
        // Taglia i secondi se presenti (es 21:00:00 -> 21:00)
        final timeShort = timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr;
        return '$dateFormatted - $timeShort';
      }
      return dateFormatted;
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _buyTickets() async {
    if (concert.url.isEmpty) return;
    final uri = Uri.parse(concert.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final formattedDate = _formatDate(concert.date, concert.time, localeName);

    return Scaffold(
      appBar: AppBar(title: Text(concert.name)),
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
              concert.name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.concertsVenue,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${concert.venueName}, ${concert.city}',
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 32),
            if (concert.url.isNotEmpty)
              FilledButton.icon(
                onPressed: _buyTickets,
                icon: const Icon(Icons.confirmation_number),
                label: Text(l10n.concertsBuyTickets),
              ),
          ],
        ),
      ),
    );
  }
}
