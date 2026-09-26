import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/app_logger.dart';
import 'document_library_service.dart';

/// Final destination handling for locally-generated media exports.
///
/// Media Cutter and Convert Media always render into a private app staging
/// directory first. Only after a valid output exists does the user choose
/// whether to copy it into Sonarpad Documents or hand it to the platform share
/// sheet. This avoids treating iCloud/Dropbox document-provider writes as
/// successful before the provider has really persisted the file.
class MediaExportDestinationService {
  MediaExportDestinationService({DocumentLibraryService? library})
      : _library = library ?? DocumentLibraryService();

  final DocumentLibraryService _library;

  Future<void> saveInSonarpadDocuments(
    String filePath, {
    String? originalName,
  }) async {
    final source = File(filePath);
    if (!await source.exists()) {
      throw FileSystemException('Generated media file is missing', filePath);
    }
    final bytes = await source.length();
    if (bytes <= 0) {
      throw FileSystemException('Generated media file is empty', filePath);
    }

    await _library.load();
    final document = await _library.importFile(
      source,
      originalName: originalName ?? p.basename(filePath),
    );
    try {
      await _library.add(document);
    } catch (error) {
      try {
        final copiedPath = await _library.resolveFilePath(document);
        final copied = File(copiedPath);
        if (await copied.exists()) await copied.delete();
      } catch (_) {
        // Preserve the original persistence error.
      }
      rethrow;
    }

    await AppLogger.log(
      'Media export: saved in Sonarpad Documents '
      'name="${document.name}" path="${document.path}" bytes=$bytes',
    );
  }

  Future<String> _ensureFolder(String name, {String? parentId}) async {
    await _library.load();
    for (final item in _library.documents) {
      if (item.isFolder &&
          item.parentId == parentId &&
          item.displayName.trim().toLowerCase() == name.trim().toLowerCase()) {
        return item.id;
      }
    }
    final folder = await _library.createFolder(name, parentId: parentId);
    return folder.id;
  }

  Future<String> ensureAudiodescriptionsFolder() =>
      _ensureFolder('Audiodescriptions');

  Future<String> ensureAudiodescriptionCatalogsFolder() async {
    final parentId = await ensureAudiodescriptionsFolder();
    return _ensureFolder('Catalogs', parentId: parentId);
  }

  Future<void> _saveInFolder(
    String filePath, {
    required String folderId,
    String? originalName,
    bool replaceSameName = false,
  }) async {
    final source = File(filePath);
    if (!await source.exists() || await source.length() <= 0) {
      throw FileSystemException('Generated media file is missing or empty', filePath);
    }
    await _library.load();
    final requestedName =
        (originalName?.trim().isNotEmpty ?? false) ? originalName!.trim() : p.basename(filePath);
    if (replaceSameName) {
      final matches = _library.documents
          .where((item) =>
              !item.isFolder &&
              item.parentId == folderId &&
              item.name.toLowerCase() == requestedName.toLowerCase())
          .toList(growable: false);
      for (final item in matches) {
        try {
          final oldPath = await _library.resolveFilePath(item);
          final oldFile = File(oldPath);
          if (await oldFile.exists()) await oldFile.delete();
        } catch (_) {}
        await _library.remove(item.id);
      }
    }
    final document = await _library.importFile(
      source,
      originalName: requestedName,
      parentId: folderId,
    );
    await _library.add(document);
    await AppLogger.log(
      'Media export: saved in Sonarpad folder '
      'folderId=$folderId name="${document.name}" path="${document.path}"',
    );
  }

  Future<void> saveInSonarpadAudiodescriptions(
    String filePath, {
    String? originalName,
  }) async {
    final folderId = await ensureAudiodescriptionsFolder();
    await _saveInFolder(
      filePath,
      folderId: folderId,
      originalName: originalName,
    );
  }

  /// Moves an already-indexed Sonarpad document into the Audiodescriptions
  /// virtual folder without copying the underlying file. Returns false when
  /// [filePath] is not currently part of the Sonarpad document library.
  Future<bool> moveExistingDocumentToAudiodescriptions(String filePath) async {
    await _library.load();
    final requested = p.normalize(p.absolute(filePath));
    String? documentId;
    for (final item in _library.documents) {
      if (item.isFolder) continue;
      try {
        final resolved = p.normalize(
          p.absolute(await _library.resolveFilePath(item)),
        );
        if (resolved == requested) {
          documentId = item.id;
          break;
        }
      } catch (_) {
        // Ignore unrelated/unavailable entries while locating the source file.
      }
    }
    final existingDocumentId = documentId;
    if (existingDocumentId == null) return false;
    final folderId = await ensureAudiodescriptionsFolder();
    await _library.moveToFolder(existingDocumentId, folderId);
    await AppLogger.log(
      'Media export: moved existing Sonarpad document into Audiodescriptions '
      'id=$existingDocumentId path="$filePath"',
    );
    return true;
  }

  Future<void> saveInSonarpadAudiodescriptionCatalogs(
    String filePath, {
    String? originalName,
  }) async {
    final folderId = await ensureAudiodescriptionCatalogsFolder();
    await _saveInFolder(
      filePath,
      folderId: folderId,
      originalName: originalName,
      replaceSameName: true,
    );
  }
}
