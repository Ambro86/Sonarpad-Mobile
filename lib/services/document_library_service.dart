import 'dart:developer' as dev;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_item.dart';
import '../utils/app_logger.dart';

/// Gestisce la persistenza della libreria documenti tramite SharedPreferences.
class DocumentLibraryService {
  static const _key = 'document_library_v1';
  static const documentsFolderName = 'Documenti';

  List<DocumentItem> _documents = [];

  List<DocumentItem> get documents => List.unmodifiable(_documents);

  Future<Directory> documentsFolder() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, documentsFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<DocumentItem> importFile(File source, {String? originalName}) async {
    final sourceName = originalName?.trim().isNotEmpty == true
        ? originalName!.trim()
        : p.basename(source.path);
    final documentName = _legacyDisplayName(sourceName);
    final ext = p.extension(documentName).replaceFirst('.', '').toLowerCase();
    final dir = await documentsFolder();
    final fileName = await _uniqueFileName(dir, documentName);
    final relativePath = p.join(documentsFolderName, fileName);
    final target = File(p.join(dir.path, fileName));
    await source.copy(target.path);

    return DocumentItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_$fileName',
      name: fileName,
      path: relativePath,
      extension: ext,
      addedAt: DateTime.now(),
    );
  }

  Future<DocumentItem> createTextDocument({
    required String name,
    required String content,
    bool isTemporary = false,
  }) async {
    final dir = await documentsFolder();
    final fileName = await _uniqueFileName(dir, name);
    final relativePath = p.join(documentsFolderName, fileName);
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content);

    return DocumentItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_$fileName',
      name: fileName,
      path: relativePath,
      extension: p.extension(fileName).replaceFirst('.', '').toLowerCase(),
      addedAt: DateTime.now(),
      isTemporary: isTemporary,
    );
  }

  Future<int> recoverVisibleDocuments(List<String> allowedExtensions) async {
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = await documentsFolder();
    final allowed = allowedExtensions.map((e) => e.toLowerCase()).toSet();
    final existingKeys = <String>{};
    for (final doc in _documents) {
      existingKeys.add(_documentKey(doc.path));
      existingKeys.add(_documentKey(doc.name));
    }

    final recovered = <DocumentItem>[];
    for (final dir in [docsDir, appDir]) {
      if (!await dir.exists()) continue;
      await for (final entity
          in dir.list(recursive: false, followLinks: false)) {
        if (entity is! File) continue;
        final basename = p.basename(entity.path);
        if (_shouldSkipRecoveryFile(basename)) continue;
        final ext = p.extension(basename).replaceFirst('.', '').toLowerCase();
        if (!allowed.contains(ext)) continue;

        final relativePath = p.relative(entity.path, from: appDir.path);
        final displayName = _legacyDisplayName(basename);
        final key = _documentKey(relativePath);
        if (existingKeys.contains(key) ||
            existingKeys.contains(_documentKey(displayName))) {
          continue;
        }

        recovered.add(
          DocumentItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_${recovered.length}_$displayName',
            name: displayName,
            path: relativePath,
            extension: ext,
            addedAt: DateTime.now(),
          ),
        );
        existingKeys.add(key);
        existingKeys.add(_documentKey(displayName));
      }
    }

    if (recovered.isEmpty) return 0;
    _documents = [...recovered, ..._documents];
    await _save();
    return recovered.length;
  }

  Future<int> recoverFromDirectory(
    Directory sourceDir,
    List<String> allowedExtensions,
  ) async {
    await AppLogger.log('Avviato recupero da directory: ${sourceDir.path}');
    if (!await sourceDir.exists()) {
      await AppLogger.log("La directory ${sourceDir.path} non esiste o l'app non ha i permessi (Scoped Storage su Android).");
      throw FileSystemException('Cartella inaccessibile per via delle protezioni di sistema (Android Scoped Storage). Prova ad importare i file singolarmente.', sourceDir.path);
    }

    final allowed = allowedExtensions.map((e) => e.toLowerCase()).toSet();
    final existingKeys = <String>{};
    for (final doc in _documents) {
      existingKeys.add(_documentKey(doc.path));
      existingKeys.add(_documentKey(doc.name));
      existingKeys.add(_documentKey(doc.displayName));
    }

    final recovered = <DocumentItem>[];
    try {
      await for (final entity in sourceDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        await AppLogger.log('Trovato elemento: ${entity.path}');

        final basename = p.basename(entity.path);
        if (_shouldSkipRecoveryFile(basename)) {
          await AppLogger.log('Scartato (skip rule): $basename');
          continue;
        }

        final ext = p.extension(basename).replaceFirst('.', '').toLowerCase();
        if (!allowed.contains(ext)) {
          await AppLogger.log('Scartato (estensione non supportata $ext): $basename');
          continue;
        }

        final displayName = _legacyDisplayName(basename);
        final key = _documentKey(displayName);
        if (existingKeys.contains(key)) {
          await AppLogger.log('Scartato (già presente): $displayName');
          continue;
        }

        try {
          final doc = await importFile(entity, originalName: displayName);
          recovered.add(doc);
          existingKeys.add(_documentKey(doc.path));
          existingKeys.add(_documentKey(doc.name));
          existingKeys.add(_documentKey(doc.displayName));
          await AppLogger.log('Importato con successo: $displayName');
        } catch (e) {
          await AppLogger.log('Errore importazione $basename: $e');
        }
      }
    } catch (e) {
      await AppLogger.log('Errore durante la scansione della cartella: $e');
      throw FileSystemException('Errore di lettura della cartella (potenziali limiti permessi): $e', sourceDir.path);
    }

    await AppLogger.log('Recuperati ${recovered.length} documenti da ${sourceDir.path}.');
    if (recovered.isEmpty) return 0;
    _documents = [...recovered, ..._documents];
    await _save();
    return recovered.length;
  }

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

      final fallback3 =
          File(p.join(appDir.path, documentsFolderName, doc.name));
      if (await fallback3.exists()) return fallback3.path;
    }

    // Comportamento corretto: doc.path contiene solo l'ID o il filename relativo
    final resolved = File(p.join(appDir.path, doc.path));
    if (await resolved.exists()) return resolved.path;

    final fallback = File(p.join(appDir.path, documentsFolderName, doc.name));
    if (await fallback.exists()) return fallback.path;

    return resolved.path;
  }

  /// Risolve il percorso del file modificato, se presente.
  Future<String?> resolveEditedFilePath(DocumentItem doc) async {
    if (doc.editedTextPath == null) return null;
    final appDir = await getApplicationDocumentsDirectory();

    if (p.isAbsolute(doc.editedTextPath!)) {
      final f = File(doc.editedTextPath!);
      if (await f.exists()) return doc.editedTextPath;

      final fallback =
          File(p.join(appDir.path, p.basename(doc.editedTextPath!)));
      if (await fallback.exists()) return fallback.path;

      final docsFallback = File(
        p.join(
            appDir.path, documentsFolderName, p.basename(doc.editedTextPath!)),
      );
      if (await docsFallback.exists()) return docsFallback.path;
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

  /// Sovrascrive l'intera lista di documenti (es. per riordino)
  Future<void> saveAll(List<DocumentItem> docs) async {
    _documents = List.from(docs);
    await _save();
  }

  Future<String> saveEditedText(DocumentItem doc, String text) async {
    final dir = await documentsFolder();
    final editedFileName = await _uniqueFileName(
      dir,
      '${doc.displayName}_modificato.txt',
    );
    final relativePath = p.join(documentsFolderName, editedFileName);
    final file = File(p.join(dir.path, editedFileName));
    await file.writeAsString(text);
    return relativePath;
  }

  Future<String> _uniqueFileName(Directory dir, String requestedName) async {
    final cleanName = _cleanFileName(requestedName);
    final ext = p.extension(cleanName);
    final stem = p.basenameWithoutExtension(cleanName);
    var candidate = cleanName;
    var index = 2;
    while (await File(p.join(dir.path, candidate)).exists()) {
      candidate = '$stem ($index)$ext';
      index++;
    }
    return candidate;
  }

  String _cleanFileName(String value) {
    final cleaned = value
        .replaceAll('/', ' ')
        .replaceAll('\\', ' ')
        .replaceAll(':', ' ')
        .replaceAll('*', ' ')
        .replaceAll('?', ' ')
        .replaceAll('"', ' ')
        .replaceAll('<', ' ')
        .replaceAll('>', ' ')
        .replaceAll('|', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    return cleaned.isEmpty ? 'Documento.txt' : cleaned;
  }

  bool _shouldSkipRecoveryFile(String basename) {
    final lower = basename.toLowerCase();
    return lower == 'sonarpad_database.json' ||
        lower.endsWith('_export.txt') ||
        lower.endsWith('_export.pdf') ||
        lower.startsWith('.');
  }

  String _legacyDisplayName(String basename) {
    final separator = _legacyNameSeparatorIndex(basename);
    if (separator <= 0 || separator == basename.length - 1) return basename;
    final prefix = basename.substring(0, separator);
    if (prefix.length < 12 || prefix.length > 20) return basename;
    if (prefix.codeUnits.every((c) => c >= 48 && c <= 57)) {
      return basename.substring(separator + 1);
    }
    return basename;
  }

  int _legacyNameSeparatorIndex(String basename) {
    final underscore = basename.indexOf('_');
    final dash = basename.indexOf('-');
    if (underscore < 0) return dash;
    if (dash < 0) return underscore;
    return underscore < dash ? underscore : dash;
  }

  String _documentKey(String value) => value.trim().toLowerCase();
}
