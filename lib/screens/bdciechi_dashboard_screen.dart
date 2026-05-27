import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../services/bdciechi_service.dart';
import '../services/document_library_service.dart';
import '../models/document_item.dart';
import 'document_reader_screen.dart';

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
  State<BdCiechiDashboardScreen> createState() => _BdCiechiDashboardScreenState();
}

class _BdCiechiDashboardScreenState extends State<BdCiechiDashboardScreen> {
  final BdCiechiService _service = BdCiechiService();
  
  List<String> _fullCatalog = [];
  List<String> _displayList = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _quotaInfo = '';

  @override
  void initState() {
    super.initState();
    _updateQuotaText(widget.identifyResponse.quota);
    _loadCatalog();
  }

  void _updateQuotaText(BdCiechiQuota? quota) {
    if (quota != null) {
      _quotaInfo = 'Libri ancora disponibili in questo mese: ${quota.remaining} su ${quota.monthlyTotal}';
    } else {
      _quotaInfo = 'Informazioni quota non disponibili.';
    }
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final catalog = await _service.fetchCatalogList(widget.identifyResponse.nprov);
      if (mounted) {
        setState(() {
          _fullCatalog = catalog;
          _displayList = catalog;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore nel caricamento del catalogo: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLatest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final latest = await _service.fetchLatestList(widget.identifyResponse.nprov);
      if (mounted) {
        setState(() {
          _displayList = latest;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ultime novità caricate')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore nel caricamento delle novità: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _displayList = _fullCatalog;
      });
      return;
    }

    final queryLower = _normalize(query);
    final results = _fullCatalog.where((item) {
      return _normalize(item).contains(queryLower);
    }).toList();

    setState(() {
      _displayList = results;
    });
  }

  String _normalize(String s) {
    // Basic normalization for search ignoring accents
    return s.toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ù', 'u');
  }

  String _extractIndex(String record) {
    // Usually record is "INDEX - Author - Title"
    final parts = record.split('-');
    if (parts.isNotEmpty) {
      return parts.first.trim();
    }
    return '';
  }

  String _cleanFileName(String record) {
    // Rimuove index e prende autore e titolo
    final parts = record.split('-');
    String name = record;
    if (parts.length > 1) {
      name = parts.sublist(1).join('-').trim();
    }
    // Sostituisce caratteri non validi per il filesystem
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  Future<void> _handleAction(String record, bool preview) async {
    final index = _extractIndex(record);
    if (index.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile estrarre l\'indice del libro.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final work = await _service.downloadWork(widget.username, widget.password, index, preview);
      final newQuota = _service.parseWorkQuota(work.info);
      if (newQuota != null) {
        _updateQuotaText(newQuota);
      }

      final textContent = work.decodedText;

      if (preview) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showPreviewDialog(record, textContent);
        }
      } else {
        await _saveToLibrary(record, textContent);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore download: $e')),
        );
      }
    }
  }

  void _showPreviewDialog(String record, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Testo d\'assaggio'),
        content: SingleChildScrollView(
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

      final appDir = await getApplicationDocumentsDirectory();
      final id = const Uuid().v4();
      final newPath = p.join(appDir.path, '$id.txt');

      await File(newPath).writeAsString(content);

      final doc = DocumentItem(
        id: id,
        name: fileName,
        path: '$id.txt',
        extension: 'txt',
        addedAt: DateTime.now(),
      );

      final lib = DocumentLibraryService();
      await lib.load();
      await lib.add(doc);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Libro importato nella libreria e salvato in documenti.')),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/documents/reader'),
            builder: (_) => DocumentReaderScreen(document: doc),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio: $e')),
        );
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
              Navigator.pop(context);
              _handleAction(record, true); // Testo d'assaggio
            },
            child: const Text('Testo d\'assaggio'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAction(record, false); // Importa
            },
            child: const Text('Importa nella libreria'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogo BdCiechi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.new_releases),
            tooltip: 'Ultime Novità',
            onPressed: _loadLatest,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              width: double.infinity,
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Cerca nel catalogo...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _displayList.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final record = _displayList[index];
                            return ListTile(
                              title: Text(record),
                              onTap: () => _onWorkTapped(record),
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
