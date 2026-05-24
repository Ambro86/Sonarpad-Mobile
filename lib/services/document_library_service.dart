import 'dart:developer' as dev;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_item.dart';

/// Gestisce la persistenza della libreria documenti tramite SharedPreferences.
class DocumentLibraryService {
  static const _key = 'document_library_v1';

  List<DocumentItem> _documents = [];

  List<DocumentItem> get documents => List.unmodifiable(_documents);

  /// Carica i documenti salvati. Deve essere chiamato prima di ogni accesso.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _documents = [];
      return;
    }
    try {
      _documents = DocumentItem.listFromJsonString(raw);
    } catch (e) {
      dev.log('DocumentLibraryService: errore decodifica libreria: $e');
      _documents = [];
    }
  }

  /// Aggiunge un documento e salva la libreria aggiornata.
  Future<void> add(DocumentItem doc) async {
    _documents = [doc, ..._documents];
    await _save();
  }

  /// Rimuove un documento tramite [id] e salva la libreria aggiornata.
  Future<void> remove(String id) async {
    _documents = _documents.where((d) => d.id != id).toList();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = DocumentItem.listToJsonString(_documents);
    final ok = await prefs.setString(_key, raw);
    if (!ok) {
      dev.log('DocumentLibraryService: impossibile salvare la libreria.');
    }
  }
}
