import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/app_logger.dart';
import 'document_library_service.dart';

enum MediaPreservationResult {
  savedInSonarpad,
  sharedFallback,
}

/// Downloads a remote MP3 and preserves it using the same Sonarpad Documents
/// destination used by audiobook exports. If the internal library save fails,
/// the already-downloaded temporary file is handed to the platform Share Sheet
/// so the user can save it in Files or share it elsewhere.
class MediaPreservationService {
  MediaPreservationService({
    http.Client? client,
    DocumentLibraryService? library,
  })  : _client = client ?? http.Client(),
        _library = library ?? DocumentLibraryService();

  final http.Client _client;
  final DocumentLibraryService _library;

  Future<MediaPreservationResult> preserveMp3({
    required String url,
    required String title,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw const FormatException('Empty media URL');
    }

    final fileName = _safeMp3FileName(title);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      p.join(
        tempDir.path,
        'sonarpad_preserve_${DateTime.now().microsecondsSinceEpoch}_$fileName',
      ),
    );

    await AppLogger.log(
      'Media preserve: download start title="$title" url="$normalizedUrl"',
    );

    try {
      final request = http.Request('GET', Uri.parse(normalizedUrl))
        ..headers['User-Agent'] =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Sonarpad';
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.tryParse(normalizedUrl),
        );
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.contains('text/html') ||
          contentType.contains('text/xml') ||
          contentType.contains('application/xml')) {
        throw HttpException(
          'Unexpected media content type: $contentType',
          uri: Uri.tryParse(normalizedUrl),
        );
      }

      final sink = tempFile.openWrite();
      await response.stream.pipe(sink);

      final bytes = await tempFile.length();
      if (bytes < 1024) {
        throw FileSystemException(
          'Downloaded media is empty or too small',
          tempFile.path,
        );
      }
      await AppLogger.log(
        'Media preserve: download completed file="${tempFile.path}" bytes=$bytes',
      );

      try {
        await _library.load();
        final document = await _library.importFile(
          tempFile,
          originalName: fileName,
        );
        try {
          await _library.add(document);
        } catch (error) {
          try {
            final copiedPath = await _library.resolveFilePath(document);
            final copied = File(copiedPath);
            if (await copied.exists()) await copied.delete();
          } catch (_) {}
          rethrow;
        }
        await AppLogger.log(
          'Media preserve: saved in Sonarpad Documents name="${document.name}" path="${document.path}"',
        );
        return MediaPreservationResult.savedInSonarpad;
      } catch (error, stack) {
        await AppLogger.log(
          'Media preserve: Sonarpad Documents save failed, Share Sheet fallback error=$error',
        );
        await AppLogger.log('Media preserve: save stack $stack');
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempFile.path)],
            text: fileName,
          ),
        );
        await AppLogger.log('Media preserve: Share Sheet fallback completed');
        return MediaPreservationResult.sharedFallback;
      }
    } catch (error, stack) {
      await AppLogger.log('Media preserve: ERROR $error');
      await AppLogger.log('Media preserve: stack $stack');
      rethrow;
    } finally {
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      _client.close();
    }
  }

  String _safeMp3FileName(String title) {
    var safe = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safe.isEmpty) safe = 'media';
    if (safe.length > 120) safe = safe.substring(0, 120).trim();
    if (safe.toLowerCase().endsWith('.mp3')) return safe;
    return '$safe.mp3';
  }
}
