import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../models/document_item.dart';

enum FolderExportFailure implements Exception {
  expectedFolder,
  cyclicLibraryTree,
}

class FolderArchiveEntry {
  const FolderArchiveEntry(this.document, this.archivePath);
  final DocumentItem document;
  final String archivePath;
}

/// Exports the virtual library tree, never internal storage IDs or paths.
class DocumentFolderExportService {
  static String safeName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\x00-\x1f/\\:*?"<>|]'), '_')
        .trim();
    return cleaned.isEmpty || cleaned == '.' || cleaned == '..' ? '_' : cleaned;
  }

  static List<FolderArchiveEntry> plan(
    DocumentItem folder,
    List<DocumentItem> documents,
  ) {
    if (!folder.isFolder) throw FolderExportFailure.expectedFolder;
    final entries = <FolderArchiveEntry>[];
    final visited = <String>{};
    void visit(DocumentItem item, String path) {
      if (!visited.add(item.id)) throw FolderExportFailure.cyclicLibraryTree;
      entries.add(FolderArchiveEntry(item, path));
      if (!item.isFolder) return;
      final used = <String>{};
      for (final child in documents.where((d) => d.parentId == item.id)) {
        var name = safeName(child.name);
        if (!child.isFolder &&
            child.extension.isNotEmpty &&
            !name.toLowerCase().endsWith('.${child.extension.toLowerCase()}')) {
          name += '.${safeName(child.extension)}';
        }
        final original = name;
        var suffix = 2;
        while (!used.add(name.toLowerCase())) {
          final ext = child.isFolder ? '' : p.posix.extension(original);
          final base = original.substring(0, original.length - ext.length);
          name = '$base ($suffix)$ext';
          suffix++;
        }
        visit(child, '$path/$name');
      }
    }

    visit(folder, safeName(folder.name));
    return entries;
  }

  /// Null source paths represent directories, including empty ones.
  static Future<void> writeZip(
    String output,
    List<({String name, String? source})> entries,
  ) => Isolate.run(() async {
    final encoder = ZipFileEncoder();
    encoder.create(output);
    try {
      for (final entry in entries) {
        if (entry.source == null) {
          encoder.addArchiveFile(
            ArchiveFile('${entry.name}/', 0, <int>[])..isFile = false,
          );
        } else {
          if (FileSystemEntity.typeSync(entry.source!, followLinks: false) !=
              FileSystemEntityType.file) {
            throw FileSystemException('Missing export source', entry.source);
          }
          await encoder.addFile(File(entry.source!), entry.name);
        }
      }
    } finally {
      await encoder.close();
    }
  });
}
