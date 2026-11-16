import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:unrar/unrar.dart';

/// Native decompression runs off the UI isolate. Archive paths are never
/// passed to a disk extractor: DocumentLibraryService chooses storage names.
class RarDocumentArchive {
  static Future<Archive> list(String path, {String? password}) => Isolate.run(() {
        final archive = Archive();
        for (final entry in UnrarExtractor().listFiles(path, password: password)) {
          final file = ArchiveFile(entry.name, entry.size, <int>[])
            ..name = entry.name
            ..isFile = !entry.isDirectory
            ..mode = entry.attributes;
          archive.addFile(file);
        }
        return archive;
      });

  static Future<List<int>> read(String path, ArchiveFile entry,
          {String? password}) =>
      Isolate.run(() {
        // The library's per-file API returns bytes in memory.
        if (entry.size > 512 * 1024 * 1024) {
          throw const FormatException('RAR entry exceeds memory extraction limit');
        }
        return UnrarExtractor().extractFile(path, entry.name, password: password);
      });

  static bool needsPassword(Object error) => error is UnrarException &&
      (error.errorCode == UnrarExtractor.ERAR_MISSING_PASSWORD ||
       error.errorCode == UnrarExtractor.ERAR_BAD_PASSWORD);
}
