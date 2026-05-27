import 'package:flutter/material.dart';

import '../services/aifa_service.dart';
import '../services/recent_searches_service.dart';
import 'aifa_confezioni_screen.dart';
import 'recent_searches_screen.dart';
import 'drug_recognition_screen.dart';

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

  void _openDrugGroup(AifaDrugResult group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AifaConfezioniScreen(drugGroup: group),
      ),
    );
  }

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
      RecentSearchesService().addSearch('farmaci', query);
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
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final drugName = await Navigator.of(context).push<String>(
                      MaterialPageRoute(builder: (_) => const DrugRecognitionScreen()),
                    );
                    if (drugName != null && drugName.isNotEmpty && mounted) {
                      _controller.text = drugName;
                      _search();
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Inquadra / Riconosci il farmaco', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () async {
                    final q = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (ctx) => const RecentSearchesScreen(
                          title: 'Farmaci recenti',
                          domain: 'farmaci',
                        ),
                      ),
                    );
                    if (q != null && mounted) {
                      _controller.text = q;
                      _search();
                    }
                  },
                  child: const Text('Farmaci recenti'),
                ),
              ),
            ),
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
                        final group = _results[index];
                        final title =
                            '${group.denominazione} - ${group.principiAttivi} - AIC ${group.aic9}';
                        return ListTile(
                          title: Text(title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${group.confezioni.length} confezioni associate'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDrugGroup(group),
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
