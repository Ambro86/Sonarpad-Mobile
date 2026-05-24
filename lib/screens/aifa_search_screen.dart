import 'package:flutter/material.dart';

import '../services/aifa_service.dart';
import 'aifa_confezioni_screen.dart';

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
