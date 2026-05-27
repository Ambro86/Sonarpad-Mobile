import 'package:flutter/material.dart';

import '../services/recent_searches_service.dart';
import 'recent_searches_screen.dart';
import 'drug_recognition_screen.dart';

import 'aifa_search_results_screen.dart';

class AifaSearchScreen extends StatefulWidget {
  const AifaSearchScreen({super.key});

  @override
  State<AifaSearchScreen> createState() => _AifaSearchScreenState();
}

class _AifaSearchScreenState extends State<AifaSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    query = query.trim();
    if (query.isEmpty) return;

    RecentSearchesService().addSearch('farmaci', query);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AifaSearchResultsScreen(query: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ricerca Farmaci AIFA'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                        _submitSearch(drugName);
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
                        _submitSearch(q);
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
                        onSubmitted: _submitSearch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _submitSearch(_controller.text),
                      child: const Text('Cerca'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
