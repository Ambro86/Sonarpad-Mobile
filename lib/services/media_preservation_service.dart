import 'dart:async';
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

enum MediaPreservationStage {
  downloading,
  saving,
}

class MediaPreservationProgress {
  const MediaPreservationProgress({
    required this.stage,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final MediaPreservationStage stage;
  final int receivedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0).toDouble();
  }
}

class MediaPreservationCancelled implements Exception {
  const MediaPreservationCancelled();

  @override
  String toString() => 'Media preservation cancelled';
}

/// Lightweight cancellation token for a preservation operation.
///
/// Network and file I/O are streamed asynchronously, so the Flutter UI thread
/// remains free. When Sonarpad owns the HTTP client, cancellation also closes
/// that client to interrupt a pending network read as quickly as possible.
class MediaPreservationCancellationToken {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }

  void _bind(void Function() callback) {
    _onCancel = callback;
    if (_cancelled) callback();
  }

  void _unbind() {
    _onCancel = null;
  }

  void throwIfCancelled() {
    if (_cancelled) throw const MediaPreservationCancelled();
  }
}

/// Downloads a remote MP3 and preserves it using the same Sonarpad Documents
/// destination used by audiobook exports. If the internal library save fails,
/// the already-downloaded temporary file is handed to the platform Share Sheet
/// so the user can save it in Files or share it elsewhere.
///
/// The download is streamed chunk by chunk instead of buffering the media in
/// memory. This keeps long RaiPlay Sound/audiodescription downloads responsive
/// and allows the caller to display progress and cancel the transfer.
class MediaPreservationService {
  MediaPreservationService({
    http.Client? client,
    DocumentLibraryService? library,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _library = library ?? DocumentLibraryService();

  final http.Client _client;
  final bool _ownsClient;
  final DocumentLibraryService _library;

  Future<MediaPreservationResult> preserveMp3({
    required String url,
    required String title,
    void Function(MediaPreservationProgress progress)? onProgress,
    MediaPreservationCancellationToken? cancellationToken,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw const FormatException('Empty media URL');
    }

    cancellationToken?.throwIfCancelled();
    if (_ownsClient) {
      cancellationToken?._bind(_client.close);
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
      cancellationToken?.throwIfCancelled();
      final request = http.Request('GET', Uri.parse(normalizedUrl))
        ..headers['User-Agent'] =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Sonarpad';
      final response = await _client.send(request);
      cancellationToken?.throwIfCancelled();

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

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      onProgress?.call(
        MediaPreservationProgress(
          stage: MediaPreservationStage.downloading,
          receivedBytes: 0,
          totalBytes: totalBytes,
        ),
      );

      final sink = tempFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          cancellationToken?.throwIfCancelled();
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress?.call(
            MediaPreservationProgress(
              stage: MediaPreservationStage.downloading,
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
            ),
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      cancellationToken?.throwIfCancelled();

      final bytes = await tempFile.length();
      if (bytes < 1024) {
        throw FileSystemException(
          'Downloaded media is empty or too small',
          tempFile.path,
        );
      }
      onProgress?.call(
        MediaPreservationProgress(
          stage: MediaPreservationStage.saving,
          receivedBytes: bytes,
          totalBytes: bytes,
        ),
      );
      await AppLogger.log(
        'Media preserve: download completed file="${tempFile.path}" bytes=$bytes',
      );

      cancellationToken?.throwIfCancelled();
      try {
        // The cancellable phase ends with the network transfer. File.copy and
        // SharedPreferences writes are asynchronous platform I/O and are kept
        // atomic from the user's point of view once final saving starts.
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
      } on MediaPreservationCancelled {
        rethrow;
      } catch (error, stack) {
        cancellationToken?.throwIfCancelled();
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
      if (cancellationToken?.isCancelled ?? false) {
        await AppLogger.log('Media preserve: cancelled');
        throw const MediaPreservationCancelled();
      }
      await AppLogger.log('Media preserve: ERROR $error');
      await AppLogger.log('Media preserve: stack $stack');
      rethrow;
    } finally {
      cancellationToken?._unbind();
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      if (_ownsClient) _client.close();
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
