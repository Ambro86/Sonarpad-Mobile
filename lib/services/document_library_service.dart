import 'dart:developer' as dev;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

  /// Risolve il percorso del documento in un file path assoluto valido.
  /// Serve per prevenire errori su iOS quando l'app viene aggiornata
  /// (la directory dei documenti cambia UUID ad ogni aggiornamento).
  Future<String> resolveFilePath(DocumentItem doc) async {
    final appDir = await getApplicationDocumentsDirectory();

    // Se il path salvato è assoluto (documenti salvati prima di questo fix)
    if (p.isAbsolute(doc.path)) {
      final f = File(doc.path);
      if (await f.exists()) return doc.path;

      // Fallback 1: cerchiamo usando il basename nella nuova appDir
      final fallback1 = File(p.join(appDir.path, p.basename(doc.path)));
      if (await fallback1.exists()) return fallback1.path;

      // Fallback 2: cerchiamo usando l'ID
      final fallback2 = File(p.join(appDir.path, doc.id));
      if (await fallback2.exists()) return fallback2.path;
    }

    // Comportamento corretto: doc.path contiene solo l'ID o il filename relativo
    return p.join(appDir.path, doc.path);
  }

  /// Risolve il percorso del file modificato, se presente.
  Future<String?> resolveEditedFilePath(DocumentItem doc) async {
    if (doc.editedTextPath == null) return null;
    final appDir = await getApplicationDocumentsDirectory();

    if (p.isAbsolute(doc.editedTextPath!)) {
      final f = File(doc.editedTextPath!);
      if (await f.exists()) return doc.editedTextPath;
      
      final fallback = File(p.join(appDir.path, p.basename(doc.editedTextPath!)));
      if (await fallback.exists()) return fallback.path;
    }

    return p.join(appDir.path, doc.editedTextPath!);
  }

  /// Aggiorna un documento esistente (es. per salvare il segnalibro).
  Future<void> update(DocumentItem doc) async {
    final index = _documents.indexWhere((d) => d.id == doc.id);
    if (index != -1) {
      _documents[index] = doc;
      await _save();
    }
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
