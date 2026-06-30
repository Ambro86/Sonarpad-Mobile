import 'package:flutter/material.dart';

import '../services/aifa_service.dart';
import '../services/parafarmaco_service.dart';
import '../services/recent_searches_service.dart';
import 'aifa_confezioni_screen.dart';
import 'parafarmaco_detail_screen.dart';

class AifaSearchResultsScreen extends StatefulWidget {
  final String query;

  const AifaSearchResultsScreen({super.key, required this.query});

  @override
  State<AifaSearchResultsScreen> createState() =>
      _AifaSearchResultsScreenState();
}

class _AifaSearchResultsScreenState extends State<AifaSearchResultsScreen> {
  static const _recentSearchesDomain = 'farmaci';

  final _service = AifaService();
  final _parafarmacoService = ParafarmacoService();
  bool _loading = true;
  String? _error;
  List<AifaDrugResult> _results = [];
  List<ParafarmacoSearchResult> _parafarmacoResults = [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    String? aifaError;
    String? parafarmacoError;
    List<AifaDrugResult> aifaResults = [];
    List<ParafarmacoSearchResult> parafarmacoResults = [];

    try {
      aifaResults = await _service.searchDrugs(widget.query);
    } catch (e) {
      aifaError = e.toString();
    }

    try {
      parafarmacoResults =
          await _parafarmacoService.searchProducts(widget.query);
    } catch (e) {
      parafarmacoError = e.toString();
    }

    if (aifaResults.isNotEmpty || parafarmacoResults.isNotEmpty) {
      try {
        await RecentSearchesService().addSearch(_recentSearchesDomain, widget.query);
      } catch (e) {
        debugPrint('Errore salvataggio ricerca farmaci/prodotti recente: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _results = aifaResults;
      _parafarmacoResults = parafarmacoResults;
      _loading = false;
      if (_results.isEmpty && _parafarmacoResults.isEmpty) {
        if (aifaError != null && parafarmacoError != null) {
          _error = 'Nessun risultato trovato. Errore AIFA: $aifaError\nErrore altri prodotti: $parafarmacoError';
        } else {
          _error = 'Nessun farmaco o prodotto da farmacia trovato per "${widget.query}"';
        }
      }
    });
  }

  void _openDrugGroup(AifaDrugResult group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AifaConfezioniScreen(drugGroup: group),
      ),
    );
  }

  void _openParafarmaco(ParafarmacoSearchResult product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParafarmacoDetailScreen(product: product),
      ),
    );
  }

  int get _itemCount {
    var count = 0;
    if (_results.isNotEmpty) count += 1 + _results.length;
    if (_parafarmacoResults.isNotEmpty) {
      count += 1 + _parafarmacoResults.length;
    }
    return count;
  }

  Widget _buildItem(BuildContext context, int index) {
    if (_results.isNotEmpty) {
      if (index == 0) {
        return const _SectionHeader(
          title: 'Farmaci AIFA',
          subtitle: 'Medicinali con dati AIFA e foglio illustrativo ufficiale.',
        );
      }
      if (index <= _results.length) {
        final group = _results[index - 1];
        final title =
            '${group.denominazione} - ${group.principiAttivi} - AIC ${group.aic9}';
        return ListTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${group.confezioni.length} confezioni associate'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openDrugGroup(group),
        );
      }
      index -= 1 + _results.length;
    }

    if (_parafarmacoResults.isNotEmpty) {
      if (index == 0) {
        return const _SectionHeader(
          title: 'Parafarmaci e altri prodotti',
          subtitle:
              'Schede prodotto non AIFA: parafarmaci, integratori o dispositivi quando disponibili.',
        );
      }
      final product = _parafarmacoResults[index - 1];
      return ListTile(
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text([
          product.category,
          product.sourceName,
          if (product.snippet != null && product.snippet!.trim().isNotEmpty)
            product.snippet!.trim(),
        ].join(' - ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openParafarmaco(product),
      );
    }

    return const SizedBox.shrink();
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
                    itemCount: _itemCount,
                    itemBuilder: _buildItem,
                  ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
