import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

/// Centralizza tutti i dati rigenerabili nella cache dell'app.
///
/// Su iOS la directory Caches non viene inclusa nel backup del dispositivo.
/// I documenti dell'utente, le registrazioni e le preferenze non passano da
/// questo servizio.
class AppCacheService {
  static const mediaExportsFolder = 'media_exports';
  static const aifaFolder = 'aifa_cache';
  static const parafarmaciFolder = 'parafarmaci_cache';
  static const tvFolder = 'tv_cache';
  static const epubIndexFolder = 'epub_index_cache';
  static const podcastFolder = 'sonarpad_podcast_cache';
  static const audiobookExportsFolder = 'sonarpad_audiobook_exports';

  static Future<Directory> directory(
    String name, {
    bool create = true,
  }) async {
    Directory base;
    try {
      base = await getApplicationCacheDirectory();
    } catch (_) {
      // Fallback per piattaforme/test che non espongono una cache dedicata.
      base = await getTemporaryDirectory();
    }

    final dir = Directory(p.join(base.path, name));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Manutenzione best-effort eseguita a ogni avvio.
  ///
  /// Elimina soltanto file rigenerabili o residui lasciati da versioni
  /// precedenti. Non tocca mai Sonarpad Documents o le registrazioni utente.
  static Future<void> cleanupAtStartup() async {
    var freedBytes = 0;
    try {
      freedBytes += await _cleanupLegacyDocumentsArtifacts();
      freedBytes += await _cleanupLegacySupportCaches();
      freedBytes += await _cleanupLegacyPodcastTemporaryCache();

      // Un export presente a un nuovo avvio è necessariamente un residuo di
      // una sessione precedente: non è ancora stato salvato nei Documenti.
      freedBytes += await _deleteDirectoryEntriesOlderThan(
        await directory(mediaExportsFolder, create: false),
        DateTime.now().subtract(const Duration(minutes: 10)),
      );

      freedBytes += await _trimCache(
        await directory(aifaFolder, create: false),
        maxAge: const Duration(days: 30),
        maxBytes: 100 * 1024 * 1024,
        targetBytes: 60 * 1024 * 1024,
      );
      freedBytes += await _trimCache(
        await directory(parafarmaciFolder, create: false),
        maxAge: const Duration(days: 30),
        maxBytes: 20 * 1024 * 1024,
        targetBytes: 10 * 1024 * 1024,
      );
      freedBytes += await _trimCache(
        await directory(epubIndexFolder, create: false),
        maxAge: const Duration(days: 45),
        maxBytes: 50 * 1024 * 1024,
        targetBytes: 25 * 1024 * 1024,
      );
      freedBytes += await _trimCache(
        await directory(podcastFolder, create: false),
        maxAge: const Duration(days: 14),
        maxBytes: 500 * 1024 * 1024,
        targetBytes: 300 * 1024 * 1024,
      );
      freedBytes += await _trimCache(
        await directory(audiobookExportsFolder, create: false),
        maxAge: const Duration(days: 3),
        maxBytes: 750 * 1024 * 1024,
        targetBytes: 400 * 1024 * 1024,
      );

      if (freedBytes > 0) {
        await AppLogger.log(
          'Storage maintenance: freed $freedBytes bytes of disposable data',
        );
      }
    } catch (error) {
      await AppLogger.log('Storage maintenance failed: $error');
    }
  }

  static Future<int> _cleanupLegacyDocumentsArtifacts() async {
    var freed = 0;
    final documents = await getApplicationDocumentsDirectory();

    for (final folderName in const [aifaFolder, parafarmaciFolder]) {
      freed += await _deleteDirectory(
        Directory(p.join(documents.path, folderName)),
      );
    }

    if (await documents.exists()) {
      await for (final entity in documents.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('Debug_Farmaco_') ||
            !name.toLowerCase().endsWith('.jpg')) {
          continue;
        }
        freed += await _deleteFile(entity);
      }
    }
    return freed;
  }

  static Future<int> _cleanupLegacySupportCaches() async {
    final support = await getApplicationSupportDirectory();
    var freed = 0;
    for (final folderName in const [
      mediaExportsFolder,
      tvFolder,
      epubIndexFolder,
      audiobookExportsFolder,
    ]) {
      freed += await _deleteDirectory(
        Directory(p.join(support.path, folderName)),
      );
    }
    return freed;
  }

  static Future<int> _cleanupLegacyPodcastTemporaryCache() async {
    final temporary = await getTemporaryDirectory();
    final legacy = Directory(p.join(temporary.path, podcastFolder));
    final current = await directory(podcastFolder, create: false);
    if (p.equals(legacy.path, current.path)) return 0;
    return _deleteDirectory(legacy);
  }

  static Future<int> _trimCache(
    Directory dir, {
    required Duration maxAge,
    required int maxBytes,
    required int targetBytes,
  }) async {
    if (!await dir.exists()) return 0;

    final now = DateTime.now();
    var entries = await _fileEntries(dir);
    var freed = 0;

    for (final entry in entries) {
      if (now.difference(entry.modified) <= maxAge) continue;
      freed += await _deleteFile(entry.file);
    }

    entries = await _fileEntries(dir);
    var total = entries.fold<int>(0, (sum, entry) => sum + entry.size);
    if (total <= maxBytes) {
      await _removeEmptyDirectories(dir);
      return freed;
    }

    final safeTarget = targetBytes < maxBytes ? targetBytes : maxBytes;
    entries.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in entries) {
      if (total <= safeTarget) break;
      final deleted = await _deleteFile(entry.file);
      if (deleted <= 0) continue;
      freed += deleted;
      total -= deleted;
    }

    await _removeEmptyDirectories(dir);
    return freed;
  }

  static Future<List<_CacheEntry>> _fileEntries(Directory dir) async {
    final entries = <_CacheEntry>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        entries.add(_CacheEntry(entity, stat.size, stat.modified));
      } catch (_) {}
    }
    return entries;
  }

  static Future<int> _deleteDirectoryEntriesOlderThan(
    Directory dir,
    DateTime cutoff,
  ) async {
    if (!await dir.exists()) return 0;
    var freed = 0;
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      try {
        final stat = await entity.stat();
        if (stat.modified.isAfter(cutoff)) continue;
        if (entity is File) {
          freed += await _deleteFile(entity);
        } else if (entity is Directory) {
          freed += await _deleteDirectory(entity);
        }
      } catch (_) {}
    }
    return freed;
  }

  static Future<int> _deleteDirectory(Directory dir) async {
    if (!await dir.exists()) return 0;
    final size = await _directorySize(dir);
    try {
      await dir.delete(recursive: true);
      return size;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> _deleteFile(File file) async {
    try {
      if (!await file.exists()) return 0;
      final size = await file.length();
      await file.delete();
      return size;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> _directorySize(Directory dir) async {
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        try {
          total += await entity.length();
        } catch (_) {}
      }
    } catch (_) {}
    return total;
  }

  static Future<void> _removeEmptyDirectories(Directory root) async {
    if (!await root.exists()) return;
    final directories = <Directory>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is Directory) directories.add(entity);
    }
    directories.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final dir in directories) {
      try {
        if (await dir.list(followLinks: false).isEmpty) {
          await dir.delete();
        }
      } catch (_) {}
    }
  }
}

class _CacheEntry {
  const _CacheEntry(this.file, this.size, this.modified);

  final File file;
  final int size;
  final DateTime modified;
}
