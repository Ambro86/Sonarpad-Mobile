import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../services/dropbox_service.dart';
import '../services/document_library_service.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class DropboxBrowserScreen extends StatefulWidget {
  final DocumentLibraryService documentService;

  const DropboxBrowserScreen({super.key, required this.documentService});

  @override
  State<DropboxBrowserScreen> createState() => _DropboxBrowserScreenState();
}

class _DropboxBrowserScreenState extends State<DropboxBrowserScreen> {
  final DropboxService _dropbox = DropboxService();
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  String _currentPath = "";
  String _searchQuery = "";
  List<Map<String, dynamic>> _entries = [];
  bool _isAuthenticating = false;

  List<Map<String, dynamic>> get _visibleEntries {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    return _entries
        .where((entry) {
          final name = entry['name'];
          return name is String && name.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    if (_searchQuery.isNotEmpty) {
      setState(() => _searchQuery = "");
    }
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
    final l10n = AppLocalizations.of(context);
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
        _error = l10n.dropboxLoginFailed;
      });
    }
  }

  Future<void> _loadFolder(String path) async {
    final l10n = AppLocalizations.of(context);
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
        _searchController.clear();
        setState(() {
          _currentPath = path;
          _searchQuery = "";
          _entries = filtered;
          _loading = false;
          _isAuthenticating = false;
        });
      }
    } on DropboxAuthRequiredException {
      await _dropbox.logout();
      if (mounted) {
        setState(() {
          _entries = [];
          _currentPath = "";
          _searchController.clear();
          _searchQuery = "";
          _error = l10n.dropboxLoginPrompt;
          _loading = false;
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = l10n.dropboxLoadFolderError(l10n.localizeTechnicalError(e));
          _loading = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _importFile(Map<String, dynamic> entry) async {
    final l10n = AppLocalizations.of(context);
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

      final doc = await widget.documentService.importFile(
        tempFile,
        originalName: name,
      );
      await widget.documentService.add(doc);

      if (mounted) {
        showStatusMessage(context, '${l10n.fileImported}: $name');
        setState(() {
          _loading = false;
        });
      }
    } on DropboxAuthRequiredException {
      await _dropbox.logout();
      if (mounted) {
        setState(() {
          _entries = [];
          _currentPath = "";
          _error = l10n.dropboxLoginPrompt;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = l10n.dropboxImportError(l10n.localizeTechnicalError(e));
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentPath.isEmpty ? 'Dropbox' : p.basename(_currentPath),
        ),
        actions: [
          if (_dropbox.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: AppLocalizations.of(context).logoutFromDropbox,
              onPressed: () async {
                await _dropbox.logout();
                setState(() {
                  _entries = [];
                  _currentPath = "";
                  _searchController.clear();
                  _searchQuery = "";
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    final visibleEntries = _visibleEntries;
    if (_loading || _isAuthenticating) {
      return Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.loading),
      );
    }

    if (!_dropbox.isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            Text(l10n.dropboxLoginPrompt, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: Text(l10n.loginToDropbox),
              onPressed: _login,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadFolder(_currentPath),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (useSharedAccessibleViewModel) {
      final rows = <AccessibleListRow>[
        AccessibleListRow(
          id: 'search',
          title: l10n.search,
          kind: 'textField',
          value: _searchController.text,
        ),
        if (_searchQuery.isNotEmpty)
          AccessibleListRow(id: 'clear_search', title: l10n.clearSearch, kind: 'button'),
        if (_currentPath.isNotEmpty)
          AccessibleListRow(id: 'back', title: l10n.goBack),
        if (visibleEntries.isEmpty)
          AccessibleListRow(
            id: 'empty',
            kind: 'text',
            title: _searchQuery.trim().isEmpty
                ? l10n.noSupportedFilesInFolder
                : l10n.noDocumentSearchResults(_searchQuery.trim()),
          )
        else
          for (var i = 0; i < visibleEntries.length; i++)
            AccessibleListRow(
              id: 'entry_$i',
              title: visibleEntries[i]['name'] as String,
              subtitle: visibleEntries[i]['.tag'] == 'folder'
                  ? l10n.folderTypeLabel
                  : l10n.fileTypeLabel,
            ),
      ];
      return UniversalAccessibleList(
        sections: [AccessibleListSection(rows: rows)],
        onEvent: (event) async {
          if (event.id == 'search' && event.type == 'textChanged') {
            final value = event.value?.toString() ?? '';
            _searchController.text = value;
            setState(() => _searchQuery = value);
          } else if (event.id == 'clear_search' && event.type == 'activate') {
            _clearSearch();
          } else if (event.id == 'back' && event.type == 'activate') {
            final parent = p.dirname(_currentPath);
            await _loadFolder(parent == '/' ? '' : parent);
          } else if (event.type == 'activate' && event.id?.startsWith('entry_') == true) {
            final i = int.tryParse(event.id!.substring(6));
            if (i == null || i >= visibleEntries.length) return;
            final entry = visibleEntries[i];
            if (entry['.tag'] == 'folder') {
              await _loadFolder(entry['path_display'] as String);
            } else {
              await _importFile(entry);
            }
          }
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: l10n.search,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                    ),
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        if (_currentPath.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.drive_folder_upload, size: 40),
            title: Text(l10n.goBack),
            onTap: () {
              final parent = p.dirname(_currentPath);
              _loadFolder(parent == '/' ? '' : parent);
            },
          ),
        Expanded(
          child: visibleEntries.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.trim().isEmpty
                        ? l10n.noSupportedFilesInFolder
                        : l10n.noDocumentSearchResults(_searchQuery.trim()),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: visibleEntries.length,
                  itemBuilder: (context, index) {
                    final entry = visibleEntries[index];
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
