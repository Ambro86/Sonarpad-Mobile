import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/dropbox_service.dart';
import '../services/document_library_service.dart';

class DropboxBrowserScreen extends StatefulWidget {
  final DocumentLibraryService documentService;

  const DropboxBrowserScreen({super.key, required this.documentService});

  @override
  State<DropboxBrowserScreen> createState() => _DropboxBrowserScreenState();
}

class _DropboxBrowserScreenState extends State<DropboxBrowserScreen> {
  final DropboxService _dropbox = DropboxService();
  bool _loading = true;
  String? _error;
  String _currentPath = "";
  List<Map<String, dynamic>> _entries = [];
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _dropbox.init();
    if (_dropbox.isAuthenticated) {
      await _loadFolder("");
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    final success = await _dropbox.authenticate();
    if (success && mounted) {
      await _loadFolder("");
    } else if (mounted) {
      setState(() {
        _isAuthenticating = false;
        _error = "Accesso fallito o annullato";
      });
    }
  }

  Future<void> _loadFolder(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await _dropbox.listFolder(path);
      // Filtra cartelle o file supportati
      final allowed = ['pdf', 'epub', 'txt', 'rtf', 'docx', 'doc'];
      
      final filtered = entries.where((e) {
        if (e['.tag'] == 'folder') return true;
        final name = (e['name'] as String).toLowerCase();
        final ext = name.split('.').last;
        return allowed.contains(ext);
      }).toList();

      // Ordina cartelle prima, poi file alfabetico
      filtered.sort((a, b) {
        if (a['.tag'] == 'folder' && b['.tag'] != 'folder') return -1;
        if (a['.tag'] != 'folder' && b['.tag'] == 'folder') return 1;
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      if (mounted) {
        setState(() {
          _currentPath = path;
          _entries = filtered;
          _loading = false;
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Errore caricamento cartella: $e";
          _loading = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _importFile(Map<String, dynamic> entry) async {
    setState(() {
      _loading = true;
    });

    try {
      final path = entry['path_display'] as String;
      final name = entry['name'] as String;
      
      final bytes = await _dropbox.downloadFile(path);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, name));
      await tempFile.writeAsBytes(bytes);

      final doc = await widget.documentService.importFile(tempFile, originalName: name);
      await widget.documentService.add(doc);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File importato: $name')));
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Errore importazione: $e";
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath.isEmpty ? 'Dropbox' : p.basename(_currentPath)),
        actions: [
          if (_dropbox.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Disconnetti',
              onPressed: () async {
                await _dropbox.logout();
                setState(() {
                  _entries = [];
                  _currentPath = "";
                });
              },
            )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading || _isAuthenticating) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_dropbox.isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Accedi a Dropbox per importare i tuoi documenti.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Accedi a Dropbox'),
              onPressed: _login,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadFolder(_currentPath),
              child: const Text('Riprova'),
            )
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_currentPath.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.drive_folder_upload, size: 40),
            title: const Text('.. Torna indietro'),
            onTap: () {
              final parent = p.dirname(_currentPath);
              _loadFolder(parent == '/' ? '' : parent);
            },
          ),
        Expanded(
          child: _entries.isEmpty
              ? const Center(child: Text('Nessun file supportato in questa cartella.'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final isFolder = entry['.tag'] == 'folder';
                    final name = entry['name'] as String;

                    return ListTile(
                      leading: Icon(
                        isFolder ? Icons.folder : Icons.insert_drive_file,
                        size: 40,
                        color: isFolder ? Colors.amber : Colors.blue,
                      ),
                      title: Text(name),
                      onTap: () {
                        if (isFolder) {
                          _loadFolder(entry['path_display']);
                        } else {
                          _importFile(entry);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
