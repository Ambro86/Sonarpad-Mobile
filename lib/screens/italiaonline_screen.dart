import 'package:flutter/material.dart';
import '../services/italiaonline_service.dart';
import '../services/document_library_service.dart';
import 'document_reader_screen.dart';

class ItaliaOnlineScreen extends StatefulWidget {
  const ItaliaOnlineScreen({super.key});

  @override
  State<ItaliaOnlineScreen> createState() => _ItaliaOnlineScreenState();
}

class _ItaliaOnlineScreenState extends State<ItaliaOnlineScreen> {
  final _whatController = TextEditingController();
  final _whereController = TextEditingController();
  DirectoryKind _kind = DirectoryKind.pagineBianche;

  @override
  void dispose() {
    _whatController.dispose();
    _whereController.dispose();
    super.dispose();
  }

  void _search() {
    final what = _whatController.text.trim();
    if (what.isEmpty) return;

    FocusScope.of(context).unfocus();
    final query = SearchQuery(
      kind: _kind,
      what: what,
      where: _whereController.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItaliaOnlineResultsScreen(query: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagine Bianche e Gialle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<DirectoryKind>(
            segments: const [
              ButtonSegment(
                value: DirectoryKind.pagineBianche,
                label: Text('Pagine Bianche'),
              ),
              ButtonSegment(
                value: DirectoryKind.pagineGialle,
                label: Text('Pagine Gialle'),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (set) {
              setState(() {
                _kind = set.first;
              });
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _whatController,
            decoration: InputDecoration(
              labelText: _kind.primaryFieldLabel,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _whereController,
            decoration: const InputDecoration(
              labelText: 'Località, indirizzo (opzionale)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: const Text('Cerca'),
          ),
        ],
      ),
    );
  }
}

class ItaliaOnlineResultsScreen extends StatefulWidget {
  final SearchQuery query;

  const ItaliaOnlineResultsScreen({super.key, required this.query});

  @override
  State<ItaliaOnlineResultsScreen> createState() => _ItaliaOnlineResultsScreenState();
}

class _ItaliaOnlineResultsScreenState extends State<ItaliaOnlineResultsScreen> {
  final _service = ItaliaOnlineService();
  SearchResponse? _response;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _service.search(widget.query);
      if (mounted) {
        setState(() {
          _response = res;
          _loading = false;
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

  Future<void> _openDetail(SearchResult result) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final detail = await _service.loadDetail(widget.query, result.id);
      if (!mounted) return;
      Navigator.of(context).pop(); // Chiudi loading

      final doc = await DocumentLibraryService().createTextDocument(
        name: '${detail.title}.txt',
        content: detail.body,
        isTemporary: true,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentReaderScreen(document: doc),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Chiudi loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.query.kind.label} - Risultati'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    final res = _response;
    if (res == null) return const SizedBox();

    if (res.ambiguousPlaces != null && res.ambiguousPlaces!.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Località ambigua. Scegli tra le seguenti:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...res.ambiguousPlaces!.map((place) => ListTile(
                title: Text(place),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ItaliaOnlineResultsScreen(
                        query: SearchQuery(
                          kind: widget.query.kind,
                          what: widget.query.what,
                          where: place,
                          page: 1,
                        ),
                      ),
                    ),
                  );
                },
              )),
        ],
      );
    }

    if (res.results.isEmpty) {
      return const Center(child: Text('Nessun risultato trovato.'));
    }

    return ListView.builder(
      itemCount: res.results.length,
      itemBuilder: (context, index) {
        final r = res.results[index];
        final subtitle = [
          if (r.category != null) r.category,
          if (r.address != null) r.address,
          if (r.city != null) r.city,
        ].join(' - ');

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(r.name),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDetail(r),
          ),
        );
      },
    );
  }
}
