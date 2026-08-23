import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/bdciechi_service.dart';
import '../services/app_settings_service.dart';
import '../services/document_library_service.dart';
import 'document_reader_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class BdCiechiDashboardScreen extends StatefulWidget {
  final String username;
  final String password;
  final BdCiechiIdentifyResponse identifyResponse;

  const BdCiechiDashboardScreen({
    super.key,
    required this.username,
    required this.password,
    required this.identifyResponse,
  });

  @override
  State<BdCiechiDashboardScreen> createState() =>
      _BdCiechiDashboardScreenState();
}

class _BdCiechiDashboardScreenState extends State<BdCiechiDashboardScreen> {
  final BdCiechiService _service = BdCiechiService();

  List<String> _fullCatalog = [];
  bool _isLoadingCatalog = true;
  String _quotaInfo = '';
  String _accessibleSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _updateQuotaText(widget.identifyResponse.quota);
    _loadCatalog();
  }

  void _updateQuotaText(BdCiechiQuota? quota) {
    if (quota != null) {
      setState(() {
        _quotaInfo =
            'Libri ancora disponibili in questo mese: ${quota.remaining} su ${quota.monthlyTotal}';
      });
    } else {
      setState(() {
        _quotaInfo = 'Informazioni quota non disponibili.';
      });
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog =
          await _service.fetchCatalogList(widget.identifyResponse.nprov);
      if (mounted) {
        setState(() {
          _fullCatalog = catalog;
          _isLoadingCatalog = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCatalog = false;
        });
      }
    }
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('å', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _searchTokens(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return const [];
    return normalized
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
  }

  bool _matchesFlexibleSearch(String record, String normalizedQuery,
      List<String> queryTokens) {
    final normalizedRecord = _normalize(record);
    if (normalizedRecord.contains(normalizedQuery)) return true;
    if (queryTokens.isEmpty) return false;

    // Ricerca flessibile: tutte le parole devono comparire nel record,
    // ma possono essere in qualunque ordine. Esempio: "Ellis Peters"
    // trova anche le voci del catalogo scritte come "Peters Ellis".
    return queryTokens.every(normalizedRecord.contains);
  }

  int _searchScore(String record, String normalizedQuery,
      List<String> queryTokens) {
    final normalizedRecord = _normalize(record);
    if (normalizedRecord.startsWith(normalizedQuery)) return 0;
    if (normalizedRecord.contains(normalizedQuery)) return 1;

    final positions = queryTokens
        .map(normalizedRecord.indexOf)
        .where((position) => position >= 0)
        .toList(growable: false);
    if (positions.length != queryTokens.length) return 1000000;

    final first = positions.reduce((a, b) => a < b ? a : b);
    final last = positions.reduce((a, b) => a > b ? a : b);
    return 100 + first + (last - first);
  }

  String _extractIndex(String record) {
    final index = _fullCatalog.indexOf(record);
    return index != -1 ? index.toString() : '0';
  }

  String _cleanFileName(String record) {
    return record.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  Future<void> _handleAction(String record, bool preview) async {
    final index = _extractIndex(record);
    if (index.isEmpty || index == '-1') {
            showStatusMessage(context, 'Impossibile estrarre l\'indice del libro.');
      return;
    }

    // Mostra uno spinner di blocco durante il download
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final work = await _service.downloadWork(
          widget.username, widget.password, index, preview);
      final newQuota = _service.parseWorkQuota(work.info);
      if (newQuota != null) {
        _updateQuotaText(newQuota);
      }

      final textContent = work.decodedText;

      // Chiudi spinner
      if (mounted) Navigator.pop(context);

      if (preview) {
        if (mounted) {
          _showPreviewDialog(record, textContent);
        }
      } else {
        await _saveToLibrary(record, textContent);
      }
    } catch (e) {
      // Chiudi spinner
      if (mounted) Navigator.pop(context);

      if (mounted) {
                showStatusMessage(context, 'Errore download: $e');
      }
    }
  }

  void _showPreviewDialog(String record, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Testo d\'assaggio'),
        content: useSharedAccessibleViewModel
            ? SizedBox(
                width: 520,
                height: 420,
                child: UniversalAccessibleList(
                  sections: [AccessibleListSection(rows: [
                    AccessibleListRow(id: 'preview', kind: 'text', title: content),
                  ])],
                  onEvent: (_) {},
                ),
              )
            : SingleChildScrollView(
                child: Text(content),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          )
        ],
      ),
    );
  }

  Future<void> _saveToLibrary(String record, String content) async {
    try {
      final cleanName = _cleanFileName(record);
      final fileName = '$cleanName.txt';

      final lib = DocumentLibraryService();
      await lib.load();
      final doc =
          await lib.createTextDocument(name: fileName, content: content);
      await lib.add(doc);

      if (mounted) {
                showStatusMessage(context, 'Libro importato nella libreria e salvato in documenti.');
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/documents/reader'),
            builder: (_) => DocumentReaderScreen(document: doc),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
                showStatusMessage(context, 'Errore salvataggio: $e');
      }
    }
  }

  void _onWorkTapped(String record) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Azioni'),
        content: Text('Scegli un\'azione per:\n$record'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // chiude dialog scelte
              _handleAction(record, true); // Testo d'assaggio
            },
            child: const Text('Testo d\'assaggio'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // chiude dialog scelte
              _handleAction(record, false); // Importa
            },
            child: const Text('Importa nella libreria'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final settings = AppSettingsService();
    await settings.setBdCiechiUsername('');
    await settings.setBdCiechiPassword('');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/bdciechi');
    }
  }

  void _performSearch(String query) {
    if (_isLoadingCatalog) {
            showStatusMessage(context, 'Attendere il caricamento del catalogo completo.');
      return;
    }
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      showStatusMessage(context, 'Inserisci almeno una parola da cercare.');
      return;
    }
    final queryTokens = _searchTokens(query);
    final results = _fullCatalog
        .where((item) =>
            _matchesFlexibleSearch(item, normalizedQuery, queryTokens))
        .toList()
      ..sort((a, b) {
        final scoreA = _searchScore(a, normalizedQuery, queryTokens);
        final scoreB = _searchScore(b, normalizedQuery, queryTokens);
        if (scoreA != scoreB) return scoreA.compareTo(scoreB);
        return a.compareTo(b);
      });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BdCiechiListScreen(
          title: 'Risultati di ricerca',
          items: results,
          onWorkTapped: _onWorkTapped,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accesso alla Biblioteca Digitale completato.'),
      ),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                sections: [AccessibleListSection(rows: [
                  AccessibleListRow(id: 'quota', kind: 'text', title: _quotaInfo),
                  const AccessibleListRow(id: 'latest', title: 'Ultime novità'),
                  AccessibleListRow(
                    id: 'search',
                    title: l10n.blindLibrarySearchCatalog,
                    kind: 'textField',
                    textInputAction: 'search',
                    onSubmitted: (value) {
                      final query = value.trim();
                      if (query.isNotEmpty) _performSearch(query);
                    },
                  ),
                  const AccessibleListRow(id: 'search_button', title: 'Cerca', kind: 'button'),
                  AccessibleListRow(id: 'catalog', title: _isLoadingCatalog ? 'Caricamento catalogo in corso...' : 'Visualizza il catalogo completo', enabled: !_isLoadingCatalog),
                  const AccessibleListRow(id: 'logout', title: 'Esci', kind: 'button'),
                ])],
                onEvent: (event) {
                  if (event.id == 'latest' && event.type == 'activate') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BdCiechiListScreen(
                          title: 'Ultime novità',
                          loadItems: () => _service.fetchLatestList(widget.identifyResponse.nprov),
                          onWorkTapped: _onWorkTapped,
                        ),
                      ),
                    );
                  } else if (event.id == 'search' && event.type == 'textChanged') {
                    _accessibleSearchQuery = event.value?.toString() ?? '';
                  } else if (event.id == 'search_button' && event.type == 'activate') {
                    _performSearch(_accessibleSearchQuery.trim());
                  } else if (event.id == 'catalog' && event.type == 'activate' && !_isLoadingCatalog) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BdCiechiListScreen(
                          title: 'Catalogo completo',
                          items: _fullCatalog,
                          onWorkTapped: _onWorkTapped,
                        ),
                      ),
                    );
                  } else if (event.id == 'logout' && event.type == 'activate') {
                    _logout();
                  }
                },
              )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Libri disponibili in questo mese
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  _quotaInfo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // 2. Ultime novità
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BdCiechiListScreen(
                        title: 'Ultime novità',
                        loadItems: () => _service
                            .fetchLatestList(widget.identifyResponse.nprov),
                        onWorkTapped: _onWorkTapped,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.new_releases),
                label:
                    const Text('Ultime novità', style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
              ),
              const SizedBox(height: 16),

              // 3. Cerca nel catalogo
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.blindLibrarySearchCatalog,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (query) {
                  if (query.trim().isNotEmpty) {
                    _performSearch(query.trim());
                  }
                },
              ),
              const SizedBox(height: 16),

              // 4. Visualizza catalogo completo
              FilledButton.icon(
                onPressed: () {
                  if (_isLoadingCatalog) {
                                        showStatusMessage(context, 'Caricamento catalogo in corso...');
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BdCiechiListScreen(
                        title: 'Catalogo completo',
                        items: _fullCatalog,
                        onWorkTapped: _onWorkTapped,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.library_books),
                label: const Text('Visualizza il catalogo completo',
                    style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
              ),
              const SizedBox(height: 32),

              // 5. Esci
              FilledButton.tonal(
                onPressed: _logout,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('Esci', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Nuova schermata generica per mostrare i risultati in una nuova pagina
class BdCiechiListScreen extends StatefulWidget {
  final String title;
  final List<String>? items; // se non nullo usa questi
  final Future<List<String>> Function()? loadItems; // se nullo usa items
  final void Function(String) onWorkTapped;

  const BdCiechiListScreen({
    super.key,
    required this.title,
    this.items,
    this.loadItems,
    required this.onWorkTapped,
  });

  @override
  State<BdCiechiListScreen> createState() => _BdCiechiListScreenState();
}

class _BdCiechiListScreenState extends State<BdCiechiListScreen> {
  List<String> _displayList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.items != null) {
      _displayList = widget.items!;
      _isLoading = false;
    } else if (widget.loadItems != null) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    try {
      final results = await widget.loadItems!();
      if (mounted) {
        setState(() {
          _displayList = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore durante il caricamento: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _displayList.isEmpty
                  ? const Center(child: Text('Nessun risultato trovato.'))
                  : useSharedAccessibleViewModel
                      ? UniversalAccessibleList(
                          sections: [AccessibleListSection(rows: [
                            for (var i = 0; i < _displayList.length; i++)
                              AccessibleListRow(id: 'item_$i', title: _displayList[i]),
                          ])],
                          onEvent: (event) {
                            if (event.type != 'activate' || event.id == null) return;
                            final i = int.tryParse(event.id!.replaceFirst('item_', ''));
                            if (i != null && i < _displayList.length) widget.onWorkTapped(_displayList[i]);
                          },
                        )
                      : ListView.separated(
                      itemCount: _displayList.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final record = _displayList[index];
                        return ListTile(
                          title: Text(record),
                          onTap: () {
                            widget.onWorkTapped(record);
                          },
                        );
                      },
                    ),
    );
  }
}
