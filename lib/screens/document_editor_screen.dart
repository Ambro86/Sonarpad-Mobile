import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/document_item.dart';
import '../services/document_library_service.dart';

class DocumentEditorScreen extends StatefulWidget {
  final DocumentLibraryService service;

  const DocumentEditorScreen({super.key, required this.service});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il documento è vuoto')),
      );
      return;
    }

    final finalTitle = title.isEmpty ? 'Nuovo_Documento' : title;

    setState(() => _saving = true);
    try {
      final name = '$finalTitle.txt';
      final id = '${DateTime.now().microsecondsSinceEpoch}_$name';

      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File(p.join(appDir.path, id));
      await localFile.writeAsString(content);

      final doc = DocumentItem(
        id: id,
        name: name,
        path: id,
        extension: 'txt',
        addedAt: DateTime.now(),
      );

      await widget.service.add(doc);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento salvato con successo!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrivi Documento'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titolo (opzionale)',
                  hintText: 'Es: Appunti Spesa',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Testo del documento',
                    hintText: 'Inizia a scrivere qui...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Salvataggio...' : 'Salva Documento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
