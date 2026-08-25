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
}
