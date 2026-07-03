import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Gestione della cache temporanea usata dai podcast.
///
/// La cache viene messa nella directory temporanea/cache del sistema, non nella
/// cartella Documenti dell'app. Su iOS questo evita che episodi scaricati come
/// cache facciano crescere inutilmente il backup del telefono.
class PodcastCacheService {
  static const _cacheFolderName = 'sonarpad_podcast_cache';

  /// Soglia massima prima della pulizia automatica: 500 MB.
  static const automaticCleanupMaxBytes = 500 * 1024 * 1024;

  /// Obiettivo dopo la pulizia automatica: circa 300 MB.
  static const automaticCleanupTargetBytes = 300 * 1024 * 1024;

  /// I file temporanei non usati da più di 14 giorni vengono eliminati.
  static const automaticCleanupMaxAge = Duration(days: 14);

  Future<Directory> cacheDirectory({bool create = true}) async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, _cacheFolderName));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<int> cacheSizeBytes() async {
    final dir = await cacheDirectory(create: false);
    if (!await dir.exists()) return 0;
    return _directorySize(dir);
  }

  Future<int> clearCache() async {
    final dir = await cacheDirectory(create: false);
    if (!await dir.exists()) return 0;
    final before = await _directorySize(dir);
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // Se un file è temporaneamente in uso, non blocchiamo tutta la pulizia.
      }
    }
    return before;
  }

  /// Pulisce automaticamente solo la cache temporanea dei podcast.
  ///
  /// Non tocca abbonamenti, cronologia, documenti, file audio importati o altri
  /// dati dell'app. La pulizia avviene in due passaggi:
  /// 1. elimina file più vecchi di [maxAge];
  /// 2. se la cache supera [maxBytes], elimina i file meno recenti finché torna
  ///    sotto [targetBytes].
  Future<int> cleanAutomatically({
    int maxBytes = automaticCleanupMaxBytes,
    int targetBytes = automaticCleanupTargetBytes,
    Duration maxAge = automaticCleanupMaxAge,
  }) async {
    final dir = await cacheDirectory(create: false);
    if (!await dir.exists()) return 0;

    final now = DateTime.now();
    var freed = 0;
    var entries = await _fileEntries(dir);

    for (final entry in entries) {
      if (now.difference(entry.modified) <= maxAge) continue;
      freed += await _deleteFile(entry.file, expectedSize: entry.size);
    }

    entries = await _fileEntries(dir);
    var total = entries.fold<int>(0, (sum, entry) => sum + entry.size);
    if (total <= maxBytes) return freed;

    final safeTargetBytes = targetBytes < maxBytes ? targetBytes : maxBytes;
    entries.sort((a, b) => a.modified.compareTo(b.modified));

    for (final entry in entries) {
      if (total <= safeTargetBytes) break;
      final deleted = await _deleteFile(entry.file, expectedSize: entry.size);
      if (deleted > 0) {
        freed += deleted;
        total -= deleted;
      }
    }

    return freed;
  }

  Future<int> _deleteFile(File file, {required int expectedSize}) async {
    try {
      if (!await file.exists()) return 0;
      final actualSize = await file.length();
      await file.delete();
      return actualSize > 0 ? actualSize : expectedSize;
    } catch (_) {
      // Se un file è temporaneamente in uso, lo lasciamo stare.
      return 0;
    }
  }

  Future<List<_PodcastCacheEntry>> _fileEntries(Directory dir) async {
    final entries = <_PodcastCacheEntry>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        entries.add(_PodcastCacheEntry(
          entity,
          stat.size,
          stat.modified,
        ));
      } catch (_) {}
    }
    return entries;
  }

  Future<int> _directorySize(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }
}

class _PodcastCacheEntry {
  const _PodcastCacheEntry(this.file, this.size, this.modified);

  final File file;
  final int size;
  final DateTime modified;
}
