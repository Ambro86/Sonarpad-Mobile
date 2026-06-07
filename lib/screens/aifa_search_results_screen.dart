import 'package:flutter/material.dart';

import '../services/aifa_service.dart';
import '../services/recent_searches_service.dart';
import 'aifa_confezioni_screen.dart';

class AifaSearchResultsScreen extends StatefulWidget {
  final String query;

  const AifaSearchResultsScreen({super.key, required this.query});

  @override
  State<AifaSearchResultsScreen> createState() =>
      _AifaSearchResultsScreenState();
}

class _AifaSearchResultsScreenState extends State<AifaSearchResultsScreen> {
  final _service = AifaService();
  bool _loading = true;
  String? _error;
  List<AifaDrugResult> _results = [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    try {
      final res = await _service.searchDrugs(widget.query);
      if (res.isNotEmpty) {
        try {
          await RecentSearchesService().addSearch('farmaci', widget.query);
        } catch (e) {
          debugPrint('Errore salvataggio ricerca farmaci recente: $e');
        }
      }
      if (mounted) {
        setState(() {
          _results = res;
          _loading = false;
          if (_results.isEmpty) {
            _error = 'Nessun farmaco trovato per "${widget.query}"';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _openDrugGroup(AifaDrugResult group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AifaConfezioniScreen(drugGroup: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Risultati: ${widget.query}'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final group = _results[index];
                      final title =
                          '${group.denominazione} - ${group.principiAttivi} - AIC ${group.aic9}';
                      return ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${group.confezioni.length} confezioni associate'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openDrugGroup(group),
                      );
                    },
                  ),
      ),
    );
  }
}
