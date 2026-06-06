import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../models/concert_event.dart';
import '../services/ticketmaster_service.dart';
import 'concert_detail_screen.dart';

class ConcertsScreen extends StatefulWidget {
  const ConcertsScreen({super.key});

  @override
  State<ConcertsScreen> createState() => _ConcertsScreenState();
}

class _ConcertsScreenState extends State<ConcertsScreen> {
  final _service = TicketmasterService();
  final _searchController = TextEditingController();
  
  List<ConcertEvent> _concerts = [];
  bool _loading = false;
  String? _error;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchConcerts(String city) async {
    if (city.trim().isEmpty) return;
    
    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
    });

    try {
      final concerts = await _service.getConcertsByCity(city.trim());
      if (!mounted) return;
      setState(() {
        _concerts = concerts;
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
    final localeName = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Concerti ed Eventi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Semantics(
              label: 'Cerca concerti per città',
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Inserisci una città (es. Milano, Roma)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _searchConcerts(_searchController.text),
                    tooltip: 'Cerca',
                  ),
                ),
                onSubmitted: _searchConcerts,
              ),
            ),
          ),
          Expanded(
            child: _buildBody(localeName),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(String localeName) {
    if (!_hasSearched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Scrivi il nome della tua città in alto per vedere i concerti musicali in programma.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Errore:\n$_error'));
    }

    if (_concerts.isEmpty) {
      return const Center(
        child: Text(
          'Nessun concerto trovato in questa città.',
          style: TextStyle(fontSize: 18),
        )
      );
    }

    return Semantics(
      explicitChildNodes: true,
      child: ListView.separated(
        scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(8),
        itemCount: _concerts.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final concert = _concerts[index];
          final formattedDate = _formatDate(concert.date, localeName);
          
          return ListTile(
            title: Text(
              concert.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$formattedDate • ${concert.venueName}',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/concerts/detail'),
                  builder: (_) => ConcertDetailScreen(concert: concert),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
