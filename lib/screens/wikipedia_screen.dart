import 'package:flutter/material.dart';

import '../services/wikipedia_service.dart';

class WikipediaScreen extends StatefulWidget {
  const WikipediaScreen({super.key});

  @override
  State<WikipediaScreen> createState() => _WikipediaScreenState();
}

class _WikipediaScreenState extends State<WikipediaScreen> {
  final _service = WikipediaService();
  final _controller = TextEditingController();
  Future<List<WikipediaSearchResult>>? _results;
  WikipediaArticle? _article;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _article = null;
      _results = _service.search(q, lang: 'it');
    });
  }

  Future<void> _import(WikipediaSearchResult result) async {
    final article = await _service.importArticle(result.pageId, lang: 'it');
    setState(() => _article = article);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importa da Wikipedia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: 'Cerca su Wikipedia'),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _search, child: const Text('Cerca')),
          const SizedBox(height: 16),
          if (_results != null && _article == null)
            FutureBuilder<List<WikipediaSearchResult>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(semanticsLabel: 'Ricerca Wikipedia'));
                }
                if (snapshot.hasError) return Text('Errore: ${snapshot.error}');
                return Column(
                  children: (snapshot.data ?? const [])
                      .map((r) => ListTile(title: Text(r.title), onTap: () => _import(r)))
                      .toList(),
                );
              },
            ),
          if (_article != null) ...[
            Text(_article!.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            SelectableText(_article!.text),
          ],
        ],
      ),
    );
  }
}
