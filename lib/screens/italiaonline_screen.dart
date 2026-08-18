import 'package:flutter/material.dart';
import '../services/italiaonline_service.dart';
import 'italiaonline_detail_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

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
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(rows: [
                  AccessibleListRow(
                    id: 'kind',
                    title: 'Elenco',
                    kind: 'picker',
                    value: _kind.name,
                    options: const [
                      AccessibleOption(value: 'pagineBianche', label: 'Pagine Bianche'),
                      AccessibleOption(value: 'pagineGialle', label: 'Pagine Gialle'),
                    ],
                  ),
                  AccessibleListRow(
                    id: 'what',
                    title: _kind.primaryFieldLabel,
                    kind: 'textField',
                    value: _whatController.text,
                  ),
                  AccessibleListRow(
                    id: 'where',
                    title: 'Località, indirizzo (opzionale)',
                    kind: 'textField',
                    value: _whereController.text,
                  ),
                  const AccessibleListRow(id: 'search', title: 'Cerca', kind: 'button'),
                ]),
              ],
              onEvent: (event) {
                if (event.id == 'kind' && event.type == 'picker') {
                  final v = event.value?.toString();
                  setState(() => _kind = v == 'pagineGialle' ? DirectoryKind.pagineGialle : DirectoryKind.pagineBianche);
                } else if (event.id == 'what' && event.type == 'textChanged') {
                  _whatController.text = event.value?.toString() ?? '';
                } else if (event.id == 'where' && event.type == 'textChanged') {
                  _whereController.text = event.value?.toString() ?? '';
                } else if (event.id == 'search' && event.type == 'activate') {
                  _search();
                }
              },
            )
          : ListView(
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
  State<ItaliaOnlineResultsScreen> createState() =>
      _ItaliaOnlineResultsScreenState();
}

class _ItaliaOnlineResultsScreenState extends State<ItaliaOnlineResultsScreen> {
  final _service = ItaliaOnlineService();
  SearchResponse? _response;
  final List<SearchResult> _results = [];
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;

  DirectoryKind get _actualKind => _response?.actualKind ?? widget.query.kind;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.query.page;
    _load();
  }

  Future<void> _load({bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _results.clear();
      });
    }

    try {
      final query = SearchQuery(
        kind: loadMore ? _actualKind : widget.query.kind,
        what: widget.query.what,
        where: widget.query.where,
        page: _currentPage,
      );
      final res = await _service.search(query);
      if (mounted) {
        setState(() {
          _response = res;
          _results.addAll(res.results);
          if (loadMore) {
            _loadingMore = false;
          } else {
            _loading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          if (loadMore) {
            _loadingMore = false;
          } else {
            _loading = false;
          }
        });
      }
    }
  }

  void _loadNextPage() {
    if (_loadingMore) return;
    _currentPage++;
    _load(loadMore: true);
  }

  Future<void> _openDetail(SearchResult result) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final detail = await _service.loadDetail(
        SearchQuery(
          kind: _actualKind,
          what: widget.query.what,
          where: widget.query.where,
          page: widget.query.page,
        ),
        result.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // Chiudi loading

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItaliaOnlineDetailScreen(detail: detail),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Chiudi loading
                showStatusMessage(context, 'Errore: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_actualKind.label} - Risultati'),
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
      if (useSharedAccessibleViewModel) {
        final places = res.ambiguousPlaces!;
        return UniversalAccessibleList(
          sections: [
            AccessibleListSection(
              header: 'Località ambigua. Scegli tra le seguenti:',
              rows: [
                for (var i = 0; i < places.length; i++)
                  AccessibleListRow(id: 'place_$i', title: places[i]),
              ],
            ),
          ],
          onEvent: (event) {
            if (event.type != 'activate' || event.id == null) return;
            final i = int.tryParse(event.id!.replaceFirst('place_', ''));
            if (i == null || i >= places.length) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ItaliaOnlineResultsScreen(
                  query: SearchQuery(
                    kind: _actualKind,
                    what: widget.query.what,
                    where: places[i],
                    page: 1,
                  ),
                ),
              ),
            );
          },
        );
      }
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
                          kind: _actualKind,
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

    if (_results.isEmpty) {
      return const Center(child: Text('Nessun risultato trovato.'));
    }

    if (useSharedAccessibleViewModel) {
      return UniversalAccessibleList(
        sections: [
          AccessibleListSection(
            rows: [
              for (var i = 0; i < _results.length; i++)
                AccessibleListRow(
                  id: 'result_$i',
                  title: _results[i].name,
                  subtitle: [
                    if (_results[i].category != null) _results[i].category!,
                    if (_results[i].address != null) _results[i].address!,
                    if (_results[i].city != null) _results[i].city!,
                  ].join(' - '),
                ),
              if (!res.isLastPage)
                AccessibleListRow(
                  id: 'more',
                  title: _loadingMore ? 'Caricamento...' : 'Carica altri risultati',
                  kind: 'button',
                  enabled: !_loadingMore,
                ),
            ],
          ),
        ],
        onEvent: (event) {
          if (event.type != 'activate' || event.id == null) return;
          if (event.id == 'more') {
            _loadNextPage();
            return;
          }
          final i = int.tryParse(event.id!.replaceFirst('result_', ''));
          if (i != null && i < _results.length) _openDetail(_results[i]);
        },
      );
    }

    return ListView.builder(
      itemCount: _results.length + (res.isLastPage ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _loadingMore
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _loadNextPage,
                    child: const Text('Carica altri risultati'),
                  ),
          );
        }

        final r = _results[index];
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
