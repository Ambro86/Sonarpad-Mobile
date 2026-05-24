import 'package:flutter/material.dart';

import '../models/document_item.dart';
import '../services/aifa_service.dart';
import 'document_reader_screen.dart';

class AifaSearchScreen extends StatefulWidget {
  const AifaSearchScreen({super.key});

  @override
  State<AifaSearchScreen> createState() => _AifaSearchScreenState();
}

class _AifaSearchScreenState extends State<AifaSearchScreen> {
  final _service = AifaService();
  final _controller = TextEditingController();

  bool _loading = false;
  String? _error;
  List<AifaDrugResult> _results = [];

  // Indica se sta scaricando il PDF di un farmaco specifico
  AifaDrugResult? _downloadingDrug;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final res = await _service.searchDrugs(query);
      if (mounted) {
        setState(() {
          _results = res;
          if (_results.isEmpty) {
            _error = 'Nessun farmaco trovato per "$query"';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openDrugPdf(AifaDrugResult drug) async {
    setState(() {
      _downloadingDrug = drug;
      _error = null;
    });

    try {
      final file = await _service.downloadFoglioIllustrativo(drug);

      if (!mounted) return;

      final docItem = DocumentItem(
        id: 'aifa_${drug.aic6}',
        name: 'FI - ${drug.name}',
        path: file.path,
        extension: 'pdf',
        addedAt: DateTime.now(),
      );

      // Apre la schermata di lettura dei documenti
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentReaderScreen(document: docItem),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Errore apertura PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore download PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingDrug = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ricerca Farmaci AIFA'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Nome farmaco, p. attivo o codice AIC',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _search,
                    child: const Text('Cerca'),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final drug = _results[index];
                        final isDownloading = _downloadingDrug == drug;
                        return ListTile(
                          title: Text(drug.name),
                          subtitle: Text('AIC: ${drug.aic6}'),
                          trailing: isDownloading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          onTap:
                              isDownloading ? null : () => _openDrugPdf(drug),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
