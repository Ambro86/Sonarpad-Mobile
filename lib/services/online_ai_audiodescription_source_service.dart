import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

import '../utils/app_logger.dart';
import 'app_cache_service.dart';
import 'document_library_service.dart';
import 'sonartube_media_export_service.dart';
import 'sonartube_service.dart';

/// Prepares online video sources for the AI audio-description workflow.
///
/// The selected media is always copied into Sonarpad Documents first. The
/// returned path therefore remains stable after temporary download/export files
/// are removed and can be passed directly to CreateAiAudiodescriptionScreen.
class OnlineAiAudiodescriptionSourceService {
  OnlineAiAudiodescriptionSourceService({DocumentLibraryService? library})
      : _library = library ?? DocumentLibraryService();

  final DocumentLibraryService _library;

  Future<String> importSonarTubeVideo({
    required SonarTubeService service,
    required SonarTubeItem item,
  }) async {
    if (item.kind != SonarTubeItemKind.video || item.isLive) {
      throw StateError(item.id);
    }

    final exporter = SonarTubeMediaExportService();
    String? stagedPath;
    try {
      stagedPath = await exporter.export(service: service, item: item);
      return await _copyIntoDocuments(
        stagedPath,
        originalName: p.basename(stagedPath),
      );
    } finally {
      if (stagedPath != null) {
        await exporter.cleanup(stagedPath);
      }
    }
  }

  Future<String> importRemoteVideo({
    required String url,
    required String title,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw const FormatException();
    }

    final exportsDir = await AppCacheService.directory(
      AppCacheService.mediaExportsFolder,
    );
    final operationDir = Directory(
      p.join(
        exportsDir.path,
        'ai_source_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await operationDir.create(recursive: true);

    final baseName = _safeFileName(title);
    final mp4Path = p.join(operationDir.path, '$baseName.mp4');
    final mkvPath = p.join(operationDir.path, '$baseName.mkv');

    try {
      final mp4Ok = await _downloadWithFfmpeg(
        url: normalizedUrl,
        outputPath: mp4Path,
        headers: headers,
        mp4: true,
      );
      final stagedPath = mp4Ok
          ? mp4Path
          : (await _downloadWithFfmpeg(
              url: normalizedUrl,
              outputPath: mkvPath,
              headers: headers,
              mp4: false,
            ))
              ? mkvPath
              : null;

      if (stagedPath == null) {
        throw FileSystemException(
          'Unable to create a local video from the selected stream',
        );
      }

      return await _copyIntoDocuments(
        stagedPath,
        originalName: p.basename(stagedPath),
      );
    } finally {
      await _deleteDirectory(operationDir);
    }
  }

  Future<bool> _downloadWithFfmpeg({
    required String url,
    required String outputPath,
    required Map<String, String> headers,
    required bool mp4,
  }) async {
    final args = <String>['-y'];
    final serializedHeaders = _serializeHeaders(headers);
    if (serializedHeaders.isNotEmpty) {
      args.addAll(['-headers', serializedHeaders]);
    }
    args.addAll([
      '-i',
      url,
      '-map',
      '0:v:0?',
      '-map',
      '0:a:0?',
      '-c',
      'copy',
    ]);
    if (mp4) {
      args.addAll(['-movflags', '+faststart']);
    }
    args.add(outputPath);

    await AppLogger.log(
      'Online AI audio description: ffmpeg ${mp4 ? 'mp4' : 'mkv'} '
      'start url="$url" output="$outputPath"',
    );
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    final output = File(outputPath);
    if (!ReturnCode.isSuccess(returnCode) ||
        !await output.exists() ||
        await output.length() <= 0) {
      final logs = await session.getAllLogsAsString() ?? '';
      await AppLogger.log(
        'Online AI audio description: ffmpeg ${mp4 ? 'mp4' : 'mkv'} failed '
        'returnCode=${returnCode?.getValue()} logs="${_compact(logs)}"',
      );
      try {
        if (await output.exists()) await output.delete();
      } catch (_) {}
      return false;
    }

    await AppLogger.log(
      'Online AI audio description: ffmpeg ${mp4 ? 'mp4' : 'mkv'} '
      'completed bytes=${await output.length()}',
    );
    return true;
  }

  Future<String> _copyIntoDocuments(
    String sourcePath, {
    required String originalName,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists() || await source.length() <= 0) {
      throw FileSystemException('Prepared video is missing or empty', sourcePath);
    }

    await _library.load();
    final document = await _library.importFile(
      source,
      originalName: originalName,
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

    final savedPath = await _library.resolveFilePath(document);
    final savedFile = File(savedPath);
    if (!await savedFile.exists() || await savedFile.length() <= 0) {
      throw FileSystemException(
        'Video saved in Sonarpad Documents is missing or empty',
        savedPath,
      );
    }
    await AppLogger.log(
      'Online AI audio description: source saved in Sonarpad Documents '
      'name="${document.name}" path="$savedPath"',
    );
    return savedPath;
  }

  String _serializeHeaders(Map<String, String> headers) {
    if (headers.isEmpty) return '';
    final buffer = StringBuffer();
    for (final entry in headers.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      buffer.write('$key: $value\r\n');
    }
    return buffer.toString();
  }

  String _safeFileName(String value) {
    var safe = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safe.isEmpty) safe = 'Video';
    if (safe.length > 120) safe = safe.substring(0, 120).trim();
    return safe;
  }

  String _compact(String value) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 900) return singleLine;
    return '${singleLine.substring(0, 900)}…';
  }

  Future<void> _deleteDirectory(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {}
  }
}
